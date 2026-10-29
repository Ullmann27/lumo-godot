extends SceneTree
## Release 2003 read-only bird's-eye visual QA of the EXACT published Godot source.
## Rendered under real Godot 4.6.3 OpenGL, not a drawn design mockup.
const STEP: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _capture(output: String, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	assert(frame.get_width() >= 1280 and frame.get_height() >= 720)
	assert(frame.save_png(output.path_join(name + ".png")) == OK,
		"Cannot save actual Godot bird's-eye frame")


func _point_camera(game, at: Vector3, altitude: float, overview: bool = false) -> void:
	var cam: Camera3D = game.camera
	cam.far = 3200.0
	cam.fov = 68.0 if overview else 62.0
	if overview:
		cam.position = at + Vector3(0, altitude, 0.01)
		cam.look_at(at, Vector3.FORWARD)
	else:
		# Off-center aerial perspective: keeps the coastal surroundings and
		# jump trajectory visible rather than hiding under a vertical camera.
		cam.position = at + Vector3(altitude * 0.20, altitude, altitude * 0.22)
		cam.look_at(at, Vector3.UP)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Real OpenGL render required")
	var output: String = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not output.is_empty())
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
	var world = game.world
	assert(str(world.track_id) == "sonnenhafen")
	assert(world.length > 1000.0)
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for i in range(96):
		var at: Vector3 = world.position_at(float(i) * world.length / 96.0)
		min_x = minf(min_x, at.x)
		max_x = maxf(max_x, at.x)
		min_z = minf(min_z, at.z)
		max_z = maxf(max_z, at.z)
	var center: Vector3 = Vector3((min_x + max_x) / 2.0, 0.0,
		(min_z + max_z) / 2.0)
	var footprint: float = maxf(max_x - min_x, max_z - min_z)
	assert(footprint > 80 and footprint < 2000,
		"Unexpected Sonnenhafen track bounding box")
	_point_camera(game, center, footprint * 1.4 + 80.0, true)
	await _capture(output, "01_sonnenhafen_full_track_bird_eye")
	var kicker: Dictionary = world.action.kickers[0]
	assert(bool(kicker.get("hero_flight", false)), "Not the panoramic hero ramp")
	var start: float = float(kicker.start)
	game.distance = start - 20.0
	game.previous_road_distance = start - 20.0
	game.player.transform = world.reset_transform(start - 20.0)
	game.player_heading = game._heading(start - 20.0)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = 18.0
	game.physical_velocity = Vector3(-sin(game.player_heading), 0,
		-cos(game.player_heading)) * game.speed
	game.steering = 0.0
	_point_camera(game, world.position_at(start), 96.0)
	await _capture(output, "02_sonnenhafen_ramp_bird_eye")
	var airborne: bool = false
	var landed: bool = false
	var peak_height: float = 0.0
	for frame in range(330):
		var target: Vector3 = world.position_at(game.previous_road_distance + 8.0)
		var delta: Vector3 = target - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading,
			atan2(-delta.x, -delta.z)) * 2.3, -1.0, 1.0)
		game._physics_process(STEP)
		var road_height: float = world.position_at(game.previous_road_distance).y
		peak_height = maxf(peak_height, game.player.position.y - road_height)
		if game.airborne and game.air_time >= 0.48 and not airborne:
			airborne = true
			_point_camera(game, game.player.position, 108.0)
			await _capture(output, "03_sonnenhafen_actual_flight_bird_eye")
		if airborne and not game.airborne and not landed:
			landed = true
			_point_camera(game, game.player.position, 95.0)
			await _capture(output, "04_sonnenhafen_landing_bird_eye")
			break
		if frame % 25 == 0:
			await process_frame
	assert(airborne and landed, "Actual accelerated driving must launch and land")
	assert(game.reset_count == 0, "The flight must not disguise a respawn")
	assert(peak_height > 3.0, "Panorama flight must be visibly elevated")
	print("[SonnenhafenAerial] PASS: full aerial course + takeoff + real flight + landing; no resets; peak %.2fm" % peak_height)
	game.abandoned = true
	game.queue_free()
	await process_frame
	quit(0)
