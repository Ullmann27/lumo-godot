extends SceneTree
## Real garage/start/pause/resume touches: countdown lights never cover the pause modal.

const STEP: float = 1.0 / 60.0
var game
var output: String
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await _settle()
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)


func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = position * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _tap(control: Control) -> void:
	assert(control.is_visible_in_tree())
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	await _touch(control.get_global_rect().get_center(), true)
	await _touch(control.get_global_rect().get_center(), false)
	await _settle()


func _resume_button() -> Button:
	for child in game.modal_column.get_children():
		if child is Button and child.text == "Weiterfahren":
			return child
	assert(false, "Actual pause menu must expose Weiterfahren")
	return null


func _snapshot() -> Dictionary:
	return {
		"result_id": game.result_id,
		"countdown": game.countdown,
		"green": game.start_green_left,
		"preview": game.preview_left,
		"elapsed": game.elapsed,
		"position": game.player.position,
		"heading": game.player_heading,
		"speed": game.speed,
		"distance": game.distance,
		"checkpoint": game.checkpoint_index,
		"boost": game.boost_time,
		"shield": game.shield_time,
		"hit": game.hit_timer,
		"rivals": game.opponent_distances.duplicate(),
	}


func _pause_resume(label: String, expect_lights: bool) -> void:
	var result_before: String = game.result_id
	var countdown_before: float = game.countdown
	var elapsed_before: float = game.elapsed
	await _tap(game.top_pause_button)
	assert(game.paused and game.modal.visible, "Real touch must open the pause modal")
	assert(game.result_id == result_before)
	assert(game.countdown == countdown_before and game.elapsed == elapsed_before)
	var frozen: Dictionary = _snapshot()
	# Publish the normal paused physics/HUD update, then capture the actual modal.
	game._physics_process(STEP)
	await _capture(label + "-paused")
	assert(not game.start_lights.is_visible_in_tree(), "Paused start lights cover modal heading")
	for frame in range(120):
		game._physics_process(STEP)
	assert(_snapshot() == frozen, "Pause must freeze countdown, green timer, race and identity")
	assert(not game.start_lights.is_visible_in_tree())
	checks += 1
	await _tap(_resume_button())
	assert(not game.paused and not game.modal.visible)
	assert(_snapshot() == frozen, "Real resume touch must retain the exact paused race state")
	game._physics_process(0.0)
	assert(game.start_lights.visible == expect_lights, "Resume restores only applicable lights")
	await _capture(label + "-resumed")
	checks += 1


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "This regression requires real rendered frames")
	root.size = Vector2i(1280, 720)
	output = OS.get_environment("LUMO_QA_DIR")
	if output.is_empty():
		output = "res://exports/countdown-pause"
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	assert(game.menu_active)
	for step in range(5):
		assert(game.garage.step == step)
		await _tap(game.garage.next_button)
	assert(not game.menu_active and game.preview_left > 0.0 and game.countdown > 0.0)
	await _capture("01-preview")
	# Existing policy ends the preview on pause; the untouched countdown resumes.
	await _pause_resume("02-preview", true)
	assert(game.preview_left == 0.0 and not game.racing)
	for frame in range(60):
		game._physics_process(STEP)
	assert(game.countdown > 0.0 and game.start_lights.visible)
	await _pause_resume("03-countdown", true)
	for frame in range(300):
		game._physics_process(STEP)
		if game.racing:
			break
	assert(game.racing and game.countdown == 0.0 and game.start_green_left > 0.0)
	await _pause_resume("04-green", true)
	for frame in range(120):
		game._physics_process(STEP)
	assert(game.racing and game.start_green_left == 0.0 and not game.start_lights.visible)
	await _pause_resume("05-after-green", false)
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	game = null
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(0.5).timeout
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	print(
		"[KartCountdownPause] PASS: %d preview/countdown/green/racing pause-resume checks" % checks
	)
	quit(0)
