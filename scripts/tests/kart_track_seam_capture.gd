extends SceneTree
## Real OpenGL close-ups of every place where stunt geometry meets the road:
## loop entry, loop exit, loop axis, precision ramp foot, lip and landing on
## Sonnenhafen, the generic loop of an expansion track and an action kicker.
## Cameras are placed from track metres, so before/after frames are comparable.
## Output: LUMO_CAPTURE_DIR/<track>_<shot>.png.
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var output: String
var shots: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _capture(game, name: String) -> void:
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(name + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	assert(error == OK, "Capture saved")
	shots += 1
	var calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("[SeamCapture] saved %s (draw calls %d)" % [path, calls])


func _look(game, from: Vector3, at: Vector3, fov: float = 58.0) -> void:
	var camera: Camera3D = game.camera
	camera.far = 1500.0
	camera.near = 0.05
	camera.fov = fov
	camera.position = from
	camera.look_at(at, Vector3.UP)


func _start(track: String):
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.lightweight = false
	await process_frame
	game._start_selected_race(
		{"mode": "training", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	game._end_preview()
	await process_frame
	game.countdown = 0.0
	game.racing = false
	game.safe_ui.visible = false
	# Park the player kart far behind the camera positions.
	game.player.transform = game.world.reset_transform(2.0, -3.0)
	return game


func _loop_shots(game, prefix: String) -> void:
	var world = game.world
	var layout: Dictionary = world.loop_layout
	var start: float = float(layout.start)
	var entry_lane: float = float(layout.lane)
	var exit_lane: float = entry_lane + float(layout.get("exit_shift", 0.0))
	var radius: float = LOOP.radius_of(layout)
	var up: Vector3 = world.frame(start).y
	# Entry: low chase-height view onto the join of road and deck.
	_look(
		game,
		world.position_at(start - 7.0, entry_lane - 2.6) + up * 1.5,
		world.position_at(start + 1.5, entry_lane) + up * 0.4
	)
	await _capture(game, prefix + "_loop_entry_closeup")
	# Exit: look back onto the descending deck where it meets the road.
	_look(
		game,
		world.position_at(start + LOOP.ADVANCE + 8.0, exit_lane - 2.8) + up * 1.5,
		world.position_at(start + LOOP.ADVANCE - 1.0, exit_lane) + up * 0.5
	)
	await _capture(game, prefix + "_loop_exit_closeup")
	# Side: the whole ring from the opposite road edge, shows any self-crossing.
	var middle: float = start + LOOP.ADVANCE * 0.5
	_look(
		game,
		world.position_at(middle, -15.0) + up * 3.0,
		world.position_at(middle, (entry_lane + exit_lane) * 0.5) + up * radius * 0.7,
		62.0
	)
	await _capture(game, prefix + "_loop_side")
	# Axis: straight down the road through the ring (symmetry with the road).
	_look(
		game,
		world.position_at(start - 26.0, 0.0) + up * 3.2,
		world.position_at(middle, (entry_lane + exit_lane) * 0.5) + up * radius,
		56.0
	)
	await _capture(game, prefix + "_loop_axis")


func _kicker_shots(game, prefix: String, kicker: Dictionary) -> void:
	var world = game.world
	var start: float = float(kicker.start)
	var take_off: float = float(kicker.take_off)
	var up: Vector3 = world.frame(start).y
	_look(
		game,
		world.position_at(start - 6.0, -3.5) + up * 1.4,
		world.position_at(start + 1.5, 0.0) + up * 0.2
	)
	await _capture(game, prefix + "_ramp_foot_closeup")
	_look(
		game,
		world.position_at(take_off - 3.0, -9.0) + up * 3.0,
		world.position_at(take_off, 0.0) + up * float(kicker.height) * 0.6
	)
	await _capture(game, prefix + "_ramp_lip")
	if kicker.has("landing_min"):
		var landing: float = take_off + float(kicker.landing_min)
		_look(
			game,
			world.position_at(landing - 7.0, -7.5) + up * 2.2,
			world.position_at(landing + 1.0, 0.0)
		)
		await _capture(game, prefix + "_landing_join")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Real OpenGL render required")
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not output.is_empty(), "LUMO_CAPTURE_DIR required")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	for track in ["sonnenhafen", "candy_cloud", "zauberwald"]:
		var game = await _start(track)
		if not game.world.loop_layout.is_empty():
			await _loop_shots(game, track)
		var kickers: Array = game.world.action.get("kickers", [])
		if not kickers.is_empty():
			var chosen: Dictionary = kickers[0]
			for candidate in kickers:
				if bool(candidate.get("precision_jump", false)):
					chosen = candidate
			await _kicker_shots(game, track, chosen)
		game.abandoned = true
		assert(await TEARDOWN.release_scene(self, game, "[SeamCapture]"), "Scene released")
		await process_frame
	print("[SeamCapture] PASS: %d frames" % shots)
	quit(0)
