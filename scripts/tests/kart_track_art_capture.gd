extends SceneTree
## Real rasterizer proof: same world, same camera, original lights, frozen time.
## These are desktop engine frames, not physical Android or performance evidence.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
var track_id := "sonnenhafen"
var output := "res://exports/track-art"
var camera: Camera3D
var shots: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_id = arg.trim_prefix("--track=")
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	call_deferred("_run")

func _save(tag: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image != null and image.get_width() == 1280)
	var filename: String = track_id + "_" + tag + ".png"
	var path: String = output.path_join(filename)
	assert(image.save_png(path) == OK)
	shots.append({"file": filename, "sha256": FileAccess.get_sha256(path),
		"camera": [camera.position.x, camera.position.y, camera.position.z]})

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Actual GL rasterizer required")
	assert(track_id in TRACKS.IDS)
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_2X
	var world = WORLD.new()
	root.add_child(world)
	world.build(false, track_id)
	await process_frame
	var finish = world.get_node("TrackVisualFinish")
	assert(finish.applied and not finish.records.is_empty())
	# Freeze shader TIME as well as scripted movement; preserve original lighting.
	Engine.time_scale = 0.0
	world.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	camera.near = 0.12
	camera.far = 1800.0
	camera.fov = 55.0
	root.add_child(camera)
	camera.make_current()
	var sites: Array = world.get_meta("reference_detail_sites", [])
	var selected: Dictionary = {}
	for site: Dictionary in sites:
		if selected.is_empty() or float(site.radius) > float(selected.radius):
			selected = site
	var d: float = float(selected.get("distance", world.length * 0.08))
	var basis: Basis = world.frame(d)
	var centre: Vector3 = world.position_at(d)
	var target: Vector3 = selected.get("position", centre + basis.x * 14.0)
	var side: float = 1.0 if (target - centre).dot(basis.x) >= 0.0 else -1.0
	for view in ["road", "detail"]:
		if view == "road":
			camera.fov = 60.0
			camera.look_at_from_position(world.position_at(d - 24.0) + Vector3.UP * 4.2,
				world.position_at(d + 16.0) + Vector3.UP * 2.0)
		else:
			camera.fov = 44.0
			var eye: Vector3 = target - basis.x * side * 12.0 + basis.z * 17.0 + Vector3.UP * 9.0
			# These two production worlds have an elevated road or a large foreground
			# tower at the old inspection position. Inspect from the outer shoulder;
			# never hide a world mesh or alter the real game camera for a prettier shot.
			if track_id in ["zauberwald", "learning_lab"]:
				eye = target + basis.x * side * 11.0 - basis.z * 12.0
				eye.y = maxf(target.y + 10.0, centre.y + 6.0)
				camera.fov = 50.0
			camera.look_at_from_position(eye, target + Vector3.UP * 2.8)
		finish.set_enabled(false)
		await _save(view + "_before")
		finish.set_enabled(true)
		await _save(view + "_after")
	var report := FileAccess.open(output.path_join(track_id + "_manifest.json"), FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"track": track_id, "engine": Engine.get_version_info().string,
		"actual_production_world": true, "scene_lighting": "original",
		"high_detail": true, "time_frozen": true, "physical_android_device": false,
		"finish": world.get_meta("track_art_finish"), "shots": shots}, "\t"))
	report.close()
	camera.free()
	world.free()
	Engine.time_scale = 1.0
	await process_frame
	print("[KartTrackArtCapture] PASS track=", track_id, " original_vs_finished_frames=4")
	quit(0)
