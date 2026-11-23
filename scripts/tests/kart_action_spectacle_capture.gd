extends SceneTree
## Captures actual production KartWorld meshes and shaders with a real renderer.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const SPECTACLE = preload("res://scripts/games/kart_course_spectacle.gd")
var track: String = "sonnenhafen"
var output: String = "/tmp/lumo-kart-views"
var views: PackedStringArray = PackedStringArray(["course", "landscape"])
var world
var camera: Camera3D
var captures: Array = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			track = argument.trim_prefix("--track=")
		elif argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
		elif argument.begins_with("--views="):
			views = argument.trim_prefix("--views=").split(",", false)
	call_deferred("_run")


func _camera_for(view: String) -> bool:
	var report: Dictionary = SPECTACLE.of(world)
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	if view.begins_with("loop_"):
		var data: Dictionary = world.loop_layout
		if data.is_empty():
			printerr("[KartCapture] Requested loop view on a track without a loop")
			return false
		var start: float = float(data.start)
		var radius: float = LOOP.radius_of(data)
		var basis: Basis = world.frame(LOOP.road_distance_at(data, 0.25))
		if view == "loop_approach":
			eye = world.position_at(start - 19.0, float(data.lane) - signf(float(data.lane)) * 2.4) + Vector3.UP * 3.5
			target = LOOP.point(world, data, 0.38) + Vector3.UP * 2.0
		elif view == "loop_side":
			target = LOOP.ring_center(world, data)
			eye = target + basis.x * signf(float(data.lane)) * radius * 3.6 + basis.z * radius * 0.7 + Vector3.UP * 3.2
		elif view == "loop_exit":
			eye = LOOP.point(world, data, 0.84) + Vector3.UP * 5.0 + world.frame(LOOP.road_distance_at(data, 0.84)).z * 13.0
			target = world.position_at(start + LOOP.advance_of(data) + 12.0, LOOP.exit_lane(data)) + Vector3.UP * 1.4
		else:
			return false
	elif view == "landscape":
		var sites: Array = report.get("sites", [])
		if sites.is_empty():
			return false
		var site: Dictionary = sites[mini(2, sites.size() - 1)]
		var d: float = float(site.distance)
		eye = world.position_at(d - 22.0, 0.0) + Vector3.UP * 7.0
		target = site.position + Vector3.UP * 6.0
	elif view == "course":
		var actions: Array = report.get("actions", [])
		if actions.is_empty():
			return false
		var entry: Dictionary = actions[0]
		for candidate in actions:
			if candidate.kind == "crest":
				entry = candidate
				break
		var d: float = float(entry.start)
		eye = world.position_at(d - 28.0, -1.6) + Vector3.UP * 4.5
		target = world.position_at(d + 23.0) + Vector3.UP * 2.0
	else:
		return false
	camera.position = eye
	camera.look_at(target, Vector3.UP)
	camera.fov = 64.0 if view == "loop_side" else 72.0
	captures.append({"track": track, "view": view, "eye": [eye.x, eye.y, eye.z],
		"target": [target.x, target.y, target.z], "fov": camera.fov})
	return true


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not track in TRACKS.IDS:
		printerr("[KartCapture] A real GL/Vulkan display and a production track are required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.msaa_3d = Viewport.MSAA_2X
	world = WORLD.new()
	root.add_child(world)
	world.build(false, track, false)
	camera = Camera3D.new()
	camera.near = 0.15
	camera.far = 1600.0
	root.add_child(camera)
	camera.make_current()
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("[KartCapture] Cannot create output directory")
		quit(1)
		return
	for view in views:
		if not _camera_for(view):
			printerr("[KartCapture] Cannot compose ", track, "/", view)
			quit(1)
			return
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image.is_empty() or image.get_width() != 1280 or image.get_height() != 720:
			printerr("[KartCapture] Invalid viewport image")
			quit(1)
			return
		var filename: String = track + "-" + view + ".png"
		if image.save_png(output.path_join(filename)) != OK:
			quit(1)
			return
		captures[captures.size() - 1]["file"] = filename
		print("[KART_CAPTURE] ", filename)
	var report: Dictionary = {"track": track, "renderer": RenderingServer.get_current_rendering_method(),
		"engine": Engine.get_version_info().string, "captures": captures,
		"source_commit": OS.get_environment("LUMO_PRODUCT_SHA"), "width": 1280, "height": 720}
	var file := FileAccess.open(output.path_join(track + "-capture.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[KartCapture] PASS ", track, " views=", captures.size())
	quit(0)
