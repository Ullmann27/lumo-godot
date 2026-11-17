extends SceneTree
## Matched stills of the production race scene and its actual chase-camera code.
## Poses are deliberately staged for a repeatable visual comparison. These
## stills do not prove driving: kart_player_full_route_regression does that.

var game
var output := ""
var quality := "high"
var views: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int = 3) -> void:
	for _frame in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(distance_m: float) -> void:
	game.distance = distance_m
	game.previous_road_distance = distance_m
	game.player.transform = game.world.reset_transform(distance_m, 0.0)
	game.player_heading = game._heading(distance_m)
	game.player.rotation.y = game.player_heading
	game._update_camera(0.0, true)
	game._update_hud()
	await _frames()
	var filename := "race-%03dm.png" % int(distance_m)
	var raster: Image = root.get_texture().get_image()
	if raster.is_empty() or raster.get_size() != Vector2i(1280, 720):
		push_error("Technical-art capture requires a real 1280x720 raster")
		quit(1)
		return
	if raster.save_png(output.path_join(filename)) != OK:
		push_error("Technical-art raster could not be saved")
		quit(1)
		return
	views.append({
		"file": filename,
		"distance_m": distance_m,
		"camera_transform": str(game.camera.global_transform),
		"camera_fov": game.camera.fov,
		"player_transform": str(game.player.global_transform),
		"draw_calls": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"render_objects": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	})
	print("[TechnicalArtCapture] captured ", filename)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real rendering display is required")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass an output directory after --")
		quit(2)
		return
	output = args[0]
	if args.size() > 1:
		quality = args[1]
	if quality not in ["low", "medium", "high"]:
		quit(2)
		return
	seed(2014)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.graphics_profile = quality
	game.lightweight = quality == "low"
	game.reduced_motion = true
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "flott",
	})
	game.countdown = 0.0
	game.preview_left = 0.0
	game.racing = true
	game.speed = 0.0
	if is_instance_valid(game.start_lights):
		game.start_lights.hide()
	game.message.text = ""
	game.player.set_process(false)
	for opponent in game.opponents:
		opponent.set_process(false)
	for child in game.world.get_children():
		if child is GPUParticles3D:
			child.emitting = false
	root.get_node("PerformanceManager").set_profile(
		{"low": 0, "medium": 1, "high": 2}[quality], false)
	await _frames(2)
	for distance_m in [18.0, 60.0, 110.0, 160.0]:
		await _capture(distance_m)
	var record := {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"quality": quality,
		"resolution": [1280, 720],
		"seed": 2014,
		"reduced_motion": true,
		"source_sha": OS.get_environment("LUMO_SOURCE_SHA"),
		"capture_script_sha256": FileAccess.get_sha256(get_script().resource_path),
		"race_script_sha256": FileAccess.get_sha256("res://scripts/games/kart_island.gd"),
		"proof_scope": "Staged real race scene; production chase camera; no driving or hardware FPS claim",
		"views": views,
	}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("[TechnicalArtCapture] PASS four production race-camera views")
	quit(0)
