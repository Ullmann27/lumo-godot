extends SceneTree
## Fixed chase camera on the actual course; measures presented frame intervals
## including game work, the driver and synchronisation in this environment.
## Run with a real renderer, --resolution WIDTHxHEIGHT -- TRACK PROFILE METRES OUTPUT_DIR.
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or args[1] not in LumoQuality.TIERS or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var requested_size := root.size
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	root.size = requested_size
	game.set_physics_process(false)
	await process_frame
	await process_frame
	LumoQuality.set_tier(args[1])
	game.graphics_profile = args[1]
	game.lightweight = args[1] == "low"
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
		"track": args[0], "difficulty": "flott"})
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.distance = args[2].to_float()
	game.previous_road_distance = game.distance
	game.player.transform = game.world.reset_transform(game.distance)
	game.player_heading = game._heading(game.distance)
	game._update_vehicles(1.0 / 60.0)
	game._update_camera(1.0, true)
	game._update_hud()
	var times: Array[float] = []
	var draws: Array[int] = []
	var start := 0
	for frame in range(37):
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if frame >= 7:
			times.append(float(now - start) / 1000.0)
			draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		start = now
	times.sort()
	draws.sort()
	var dir := args[3]
	var ok := DirAccess.make_dir_recursive_absolute(dir) == OK
	var frame_image := root.get_texture().get_image()
	ok = ok and requested_size == frame_image.get_size() and draws[15] > 0
	if ok:
		ok = frame_image.save_webp(dir.path_join("%s_%s_%dx%d.webp" % [args[0], args[1], root.size.x, root.size.y]), true, 0.9) == OK
	print("[KartFrameSample] ", JSON.stringify({"track": args[0], "tier": args[1], "metres": game.distance,
		"width": root.size.x, "height": root.size.y, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "frames": times.size(),
		"median_ms": (times[14] + times[15]) / 2.0, "p95_ms": times[28], "median_draw_calls": draws[15]}))
	game.abandoned = true
	ok = await TEARDOWN.release_scene(self, game, "[KartFrameSample]") and ok
	quit(0 if ok else 1)
