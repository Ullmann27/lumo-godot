extends SceneTree


## Physical two-lap race through actual menu/touch input, saved continuation and host ACK.
## Fixed physics steps prove behaviour; desktop software rendering proves no device FPS.
class Host:
	extends Node
	var rewards: Dictionary = {}
	var reward_calls := 0
	var returns: Array[Dictionary] = []
	var return_ack := 0

	# gdlint: disable=function-name
	func reward(value: String) -> int:
		reward_calls += 1
		var payload: Dictionary = JSON.parse_string(value)
		rewards[str(payload.resultId)] = payload
		return 1

	func returnToApp(_destination: String, value: String) -> int:
		returns.append(JSON.parse_string(value))
		return return_ack


const OUTPUT := "res://exports/complete-flow"
const STEP := 1.0 / 60.0
var game
var host: Host
var trace: Array[Dictionary] = []
var expected_id := ""


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await _settle()
	assert(root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var input := InputEventScreenTouch.new()
	input.index = index
	input.position = at * Vector2(root.size) / root.get_visible_rect().size
	input.pressed = pressed
	Input.parse_input_event(input)
	await process_frame


func _tap(control: Control) -> void:
	assert(control.is_visible_in_tree())
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	await _touch(4, control.get_global_rect().get_center(), true)
	await _touch(4, control.get_global_rect().get_center(), false)
	await _settle()


func _button(text: String) -> Button:
	for child in game.modal_column.get_children():
		if child is Button and child.text == text:
			return child
	assert(false, "Expected actual modal action: " + text)
	return null


func _steer(value: float) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 1
	var point: Vector2 = game.joystick.get_global_rect().get_center()
	point.x += game.joystick.size.x * 0.31 * value
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(event)


func _hold_controls() -> void:
	# This fixture steps physics manually. Let the next normal step publish
	# resumed action availability before issuing fresh touches.
	game._physics_process(STEP)
	await _settle()
	await _touch(1, game.joystick.get_global_rect().get_center(), true)
	await _touch(2, game.gas_button.get_global_rect().get_center(), true)
	assert(
		game.gas_held and game.joystick.touch_id == 1, "Resumed pedals/stick accept fresh fingers"
	)


func _fresh():
	var instance = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(instance)
	instance.set_physics_process(false)
	await _settle()
	return instance


func _drop() -> void:
	game.abandoned = true
	game.queue_free()
	await _settle()


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	DirAccess.remove_absolute("user://lumo_host_pending_rewards.cfg")
	var bridge = root.get_node("HostBridge")
	host = Host.new()
	root.add_child(host)
	bridge._host = host
	bridge._options = {"sessionId": "complete-touch-race", "soundEnabled": false}
	game = await _fresh()
	assert(game.menu_active)
	for step in range(5):
		assert(game.garage.step == step)
		await _tap(game.garage.next_button)
	assert(not game.menu_active and game.mode == "race" and game.track_id == "sonnenhafen")
	expected_id = game.result_id
	game.auto_gas = false
	game._update_hud()
	await _capture("01-start-grid")
	# Run the real preview and countdown. No distance/checkpoint/finish state is assigned.
	for frame in range(1000):
		game._physics_process(STEP)
		if game.racing:
			break
	assert(game.racing)
	await _hold_controls()
	var resumed := false
	var frames := 0
	var last_gate := 0
	while not game.finished and frames < 12000:
		var road: Dictionary = game.world.sample_road(
			game.player.position, game.previous_road_distance
		)
		var heading: float = game._heading(float(road.distance) + 7.0)
		var turn := clampf(
			-angle_difference(game.player_heading, heading) * 1.8 - float(road.lateral) * 0.12,
			-1.0,
			1.0
		)
		_steer(turn)
		game._physics_process(STEP)
		frames += 1
		if game.checkpoint_index != last_gate:
			assert(game.checkpoint_index == last_gate + 1, "Ordered gates cannot be skipped")
			last_gate = game.checkpoint_index
			trace.append({"gate": last_gate, "seconds": game.elapsed, "distance": game.distance})
		if last_gate >= 4 and not resumed:
			await _touch(2, Vector2(420, 250), false)
			await _touch(1, Vector2(420, 250), false)
			await _tap(game.top_pause_button)
			assert(game.paused and not game.gas_held and game.steering == 0.0)
			await _capture("02-paused-mid-race")
			var progress: float = game.distance
			game._return_to_app("games")
			assert(host.returns[-1].status == "paused" and FileAccess.file_exists(game.SESSION))
			bridge._return_pending = false
			await _drop()
			game = await _fresh()
			assert(game.saved_session_available)
			await _tap(game.garage.find_child("ResumeRace", true, false))
			assert(game.paused and game.result_id == expected_id and game.distance == progress)
			game.auto_gas = false
			game._update_hud()
			await _tap(_button("Weiterfahren"))
			await _hold_controls()
			resumed = true
			await _capture("03-restored-race")
		if frames % 120 == 0:
			await process_frame
	assert(game.finished and resumed, "Real driving must finish after a saved continuation")
	await _touch(2, Vector2(420, 250), false)
	await _touch(1, Vector2(420, 250), false)
	assert(game.checkpoint_index == 16 and game.reset_count == 0)
	assert(game.result_payload.resultId == expected_id and game.result_payload.stars == 3)
	assert(game.result_payload.solved is int and game.result_payload.solved == 0)
	assert(host.reward_calls == 1 and host.rewards.size() == 1 and host.rewards.has(expected_id))
	for frame in range(250):
		game._physics_process(STEP)
		if game.finish_cine_left <= 0:
			break
	assert(game.modal.visible)
	await _capture("04-result")
	var report := {
		"result": game.result_payload.duplicate(true),
		"ordered_gates": trace,
		"actual_menu_touch_steps": 5,
		"save_reopen_resume": resumed,
		"input": "screen touch/drag; physics stepped at 1/60; no teleport or forced finish",
		"physical_device_performance": "NOT EXECUTED"
	}
	host.return_ack = 1
	await _tap(_button("Zur Spieleauswahl"))
	assert(host.returns[-1].status == "completed" and host.returns[-1].resultId == expected_id)
	assert(not FileAccess.file_exists(game.SESSION), "Durable ACK removes completed save")
	bridge._return_pending = false
	await _drop()
	game = await _fresh()
	assert(not game.saved_session_available and host.reward_calls == 1 and host.rewards.size() == 1)
	await _capture("05-reopened-garage")
	FileAccess.open(OUTPUT.path_join("evidence.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "  ")
	)
	await _drop()
	bridge._host = null
	bridge._options = {}
	host.queue_free()
	root.world_3d.fallback_environment = null
	await create_timer(0.6).timeout
	print(
		"[KartCompleteFlow] PASS: actual menu/touch, 16 gates, saved resume, result, ACK, one reward"
	)
	quit(0)
