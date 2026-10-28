extends SceneTree
## Real Godot 4.6.3 captures along the live, physically driven Sonnenhafen jump.
const STEP: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _capture(output: String, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.get_width() >= 720 and image.get_height() >= 400)
	assert(image.save_png(output.path_join(name + ".png")) == OK, "Could not save real game frame")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Real GPU render required")
	var output: String = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not output.is_empty(), "Capture path must be provided")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	await process_frame
	game._start_selected_race({
		"mode": "training", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "flott"
	})
	game._end_preview()
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	var kicker: Dictionary = game.world.action.kickers[0]
	var start: float = float(kicker.start)
	game.distance = start - 20.0
	game.previous_road_distance = start - 20.0
	game.player.transform = game.world.reset_transform(start - 20.0)
	game.player_heading = game._heading(start - 20.0)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = 18.0
	game.physical_velocity = Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
	game.steering = 0.0
	game._update_camera(STEP, true)
	game._update_hud()
	await _capture(output, "01_sonnenhafen_ramp_approach")
	var airborne_seen: bool = false
	var landed: bool = false
	for frame in range(330):
		var ahead: Vector3 = game.world.position_at(game.previous_road_distance + 8.0)
		var delta: Vector3 = ahead - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading,
			atan2(-delta.x, -delta.z)) * 2.3, -1.0, 1.0)
		game._physics_process(STEP)
		game._update_camera(STEP)
		game._update_hud()
		if game.airborne and game.air_time >= 0.48 and not airborne_seen:
			airborne_seen = true
			await _capture(output, "02_sonnenhafen_actual_flight")
		if airborne_seen and not game.airborne and not landed:
			landed = true
			await _capture(output, "03_sonnenhafen_landing")
			break
		if frame % 25 == 0:
			await process_frame
	assert(airborne_seen and landed, "Real ramp flight must launch and land")
	assert(game.reset_count == 0, "Captures must not hide a kart reset")
	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[SonnenhafenFlightCapture] PASS: real ramp, airborne and landing screenshots")
	quit(0)
