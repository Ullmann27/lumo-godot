extends SceneTree
## Native renderer evidence from the same scene and controller used by the APK.
const TRACKS := ["zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple",
	"candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway", "desert_drift", "learning_lab"]
const DESTINATION := "res://evidence/lumo_kart_runtime/review/"
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var game
var frames: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _capture(track: String, view: String, at: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at)
	game.player_heading = game._heading(at)
	game.speed = 18.0
	game.physical_velocity = game.world.forward(at) * game.speed
	game.airborne = false
	game.vertical_speed = 0.0
	game.steering = 0.0
	for i in game.opponents.size():
		var ahead: float = at + 7.0 + float(i) * 2.5
		game.opponents[i].transform = game.world.reset_transform(ahead, -2.8 + float(i) * 1.4)
		game.opponent_distances[i] = ahead
		game.opponents[i].set_motion(16.0 + i, 0.0, false, false)
	game._update_vehicles(1.0 / 60.0)
	game._update_camera(1.0, true)
	game._update_hud()
	game.world.production_tunnels.update_light_focus(game.camera.position)
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var file := DESTINATION + track + "_" + view + ".png"
	var frame := root.get_texture().get_image()
	if frame.save_png(file) != OK:
		printerr("[ProductionCapture] Cannot save " + file)
		quit(1)
		return
	frames.append({"track": track, "view": view, "path": file.trim_prefix("res://"),
		"width": frame.get_width(), "height": frame.get_height(),
		"road_distance": at, "source_scene": "scenes/games/kart_island.tscn",
		"tunnel": game.world.production_tunnels.statistics.duplicate(true)})
	print("[ProductionCapture] " + file)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[ProductionCapture] Requires an actual native rendering window")
		quit(1)
		return
	root.size = Vector2i(1200, 750)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINATION))
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	game.graphics_profile = "high"
	game.reduced_motion = false
	await process_frame
	await process_frame
	var selected: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in TRACKS:
			selected.append(argument)
	if selected.is_empty():
		selected.assign(TRACKS)
	for track in selected:
		game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
			"track": track, "difficulty": "flott"})
		game._end_preview()
		await physics_frame
		await physics_frame
		game.countdown = 0.0
		game.racing = true
		if not is_instance_valid(game.world.production_tunnels):
			printerr("[ProductionCapture] Missing real tunnel for " + track)
			quit(1)
			return
		var layout: Dictionary = game.world.production_tunnel_layout
		await _capture(track, "entry", float(layout.start) - 8.0)
		await _capture(track, "inside", float(layout.start) + float(layout.length) * 0.5)
	var released: bool = await TEARDOWN.release_scene(self, game, "[ProductionCapture]")
	var current_count: int = frames.size()
	var index_path := DESTINATION + "runtime_visual_index.json"
	if selected.size() < TRACKS.size() and FileAccess.file_exists(index_path):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
		if previous is Dictionary:
			for record in previous.get("frames", []):
				if record is Dictionary and str(record.get("track", "")) not in selected:
					frames.append(record)
	var report := {"status": "PASS" if released and current_count == selected.size() * 2 else "FAIL",
		"engine": Engine.get_version_info().string, "display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"physical_android_test": false, "last_captured_tracks": selected, "frames": frames}
	var out := FileAccess.open(index_path, FileAccess.WRITE)
	if out == null:
		quit(1)
		return
	out.store_string(JSON.stringify(report, "\t") + "\n")
	out.close()
	print("[ProductionCapture] %s: %d actual game screenshots" % [report.status, frames.size()])
	quit(0 if report.status == "PASS" else 1)
