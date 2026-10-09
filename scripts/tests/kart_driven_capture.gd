extends SceneTree
## Proof footage: real touch events and stepped game physics, with no race teleporting.
const OUTPUT := "res://exports/reference-design/driven"
var game
var evidence: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _steer(value: float) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 1
	var point: Vector2 = game.joystick.get_global_rect().get_center()
	point.x += game.joystick.size.x * 0.31 * value
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(event)


func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	for i in range(4):
		await process_frame
	game.set_physics_process(false)
	for track in ["sonnenhafen", "candy_cloud", "volcano_night"]:
		game._start_selected_race(
			{
				"mode": "training",
				"driver": "fox",
				"kart": "comet",
				"track": track,
				"difficulty": "gemuetlich"
			}
		)
		game._end_preview()
		game.set_physics_process(false)
		game.auto_gas = false
		game.countdown = 0
		game.racing = true
		game.modal.hide()
		game.message.text = "Lenken · GAS halten · SPEED für Turbo"
		game._update_hud()
		for i in range(4):
			await process_frame
		var origin: Vector3 = game.player.position
		await _touch(1, game.joystick.get_global_rect().get_center(), true)
		await _touch(2, game.gas_button.get_global_rect().get_center(), true)
		assert(game.gas_held and game.joystick.touch_id == 1)
		var trace: Array = []
		var peak_speed := 0.0
		for step in range(480):
			var road: Dictionary = game.world.sample_road(
				game.player.position, game.previous_road_distance
			)
			var target: float = game._heading(float(road.distance) + 7.0)
			var turn: float = clampf(
				-angle_difference(game.player_heading, target) * 1.8 - float(road.lateral) * 0.12,
				-1,
				1
			)
			_steer(turn)
			game._physics_process(1.0 / 60.0)
			peak_speed = maxf(peak_speed, game.speed)
			if step == 180:
				await _touch(3, game.boost_button.get_global_rect().get_center(), true)
				assert(game.boost_time > 0 and game.gas_held and game.joystick.touch_id == 1)
				await _touch(3, Vector2(420, 250), false)
			if step % 2 == 0:
				await process_frame
			if step % 60 == 59:
				trace.append(
					{
						"seconds": (step + 1) / 60.0,
						"distance_m": game.distance,
						"speed_m_s": game.speed,
						"lane_m": game.lane,
						"steering": game.steering
					}
				)
			if step in [59, 179, 239, 359, 479]:
				await _save("%s-driven-%03d" % [track, step + 1])
		assert(game.player.position.distance_to(origin) > 40.0, "Real driving must move the kart")
		assert(
			game.distance > 50.0 and peak_speed > 20.0,
			"Gas and speed action must produce actual progress"
		)
		await _touch(2, Vector2(420, 250), false)
		await _touch(1, Vector2(420, 250), false)
		assert(not game.gas_held and game.steering == 0)
		var before_brake: float = game.speed
		await _touch(4, game.brake_button.get_global_rect().get_center(), true)
		for step in range(60):
			game._physics_process(1.0 / 60.0)
			if step % 2 == 0:
				await process_frame
		assert(absf(game.speed) < before_brake * 0.35, "Actual brake must slow the kart")
		await _touch(4, Vector2(420, 250), false)
		evidence.append(
			{
				"track": track,
				"physics_step_seconds": 1.0 / 60.0,
				"elapsed_seconds": game.elapsed,
				"distance_m": game.distance,
				"peak_speed_m_s": peak_speed,
				"speed_after_brake_m_s": game.speed,
				"wall_contacts": game.wall_contacts,
				"reset_count": game.reset_count,
				"trace": trace
			}
		)
		print(
			"[DrivenCapture] ",
			track,
			" progress=",
			game.distance,
			" peak=",
			peak_speed,
			" brake=",
			game.speed
		)
	FileAccess.open(OUTPUT.path_join("driving-evidence.json"), FileAccess.WRITE).store_string(
		JSON.stringify(evidence, "  ")
	)
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	await process_frame
	await create_timer(0.8).timeout
	print(
		"[DrivenCapture] PASS: three worlds driven by gas, analogue touch and speed; ",
		"release and physical braking"
	)
	quit(0)
