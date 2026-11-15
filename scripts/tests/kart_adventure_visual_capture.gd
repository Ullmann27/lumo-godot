extends SceneTree
## Actual engine framebuffer views of the current route and vehicle geometry.
## The optional camera traversal is staged visual QA, not autonomous driving proof.

const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")

var output := "res://exports/kart-adventure/views"
var selected := "crystal_canyon"
var animate := false
var reports: Array[Dictionary] = []
var camera: Camera3D
var stage: Node3D
var hero
var rival


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--track-id="):
			selected = argument.trim_prefix("--track-id=")
		elif argument == "--animate":
			animate = true
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	root.msaa_3d = Viewport.MSAA_2X
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	stage = Node3D.new()
	root.add_child(stage)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 2200.0
	stage.add_child(camera)
	camera.make_current()
	hero = VEHICLE.new()
	hero.configure("fox", Color("76d9ff"), "comet")
	hero.reduced_motion = true
	stage.add_child(hero)
	hero.set_process(false)
	rival = VEHICLE.new()
	rival.configure("rabbit", Color("a696ee"), "glider")
	rival.reduced_motion = true
	stage.add_child(rival)
	rival.set_process(false)
	var ids: Array[String] = []
	if selected == "all":
		for id in TRACKS.IDS:
			if id != "sonnenhafen":
				ids.append(id)
	else:
		assert(selected in TRACKS.IDS)
		ids.append(selected)
	for id in ids:
		await _capture_track(id)
	var report := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({
		"engine": Engine.get_version_info().string,
		"actual_runtime_geometry": true,
		"staged_visual_traversal": animate,
		"renderer": "Godot Compatibility / local Mesa software renderer",
		"physical_android_device": false,
		"captures": reports,
	}, "  "))
	report.close()
	root.world_3d.fallback_environment = null
	stage.free()
	await process_frame
	await create_timer(0.2).timeout
	print("[KartAdventureCapture] PASS: ", reports.size(), " real framebuffer captures")
	quit(0)


func _capture_track(id: String) -> void:
	var world = WORLD.new()
	stage.add_child(world)
	world.build(false, id)
	await process_frame
	var layout: Dictionary = world.adventure_tunnel
	if id == "sonnenhafen":
		layout = {"start": world.length * 0.69, "end": world.length * 0.80, "name": "Sonnenhafen-Referenz"}
	assert(not layout.is_empty(), "Every requested new track must have its tunnel connected")
	var start: float = float(layout.start)
	var finish: float = float(layout.end)
	var middle: float = (start + finish) * 0.5
	for shot in ["approach", "inside", "overview"]:
		var position_on_road: float = start - 7.0 if shot == "approach" else middle
		hero.transform = world.reset_transform(position_on_road, -1.1)
		rival.transform = world.reset_transform(position_on_road + 10.0, 1.3)
		var cam_distance: float = position_on_road - 11.0
		var cam_basis: Basis = world.frame(cam_distance)
		var eye: Vector3 = world.position_at(cam_distance, -0.65) + cam_basis.y * 3.4
		var target: Vector3 = world.position_at(position_on_road + 15.0) + Vector3.UP * 2.3
		camera.fov = 60.0
		if shot == "overview":
			var centre: Vector3 = world.position_at(middle)
			var basis: Basis = world.frame(middle)
			eye = centre + basis.x * 75.0 + basis.z * 80.0 + Vector3.UP * 80.0
			target = centre + Vector3.UP * 2.0
			camera.fov = 54.0
		camera.look_at_from_position(eye, target)
		for warmup in range(4):
			await process_frame
		await _capture(id + "-" + shot + ".png")
		reports.append({
			"track": id, "view": shot, "file": id + "-" + shot + ".png",
			"route_length_m": world.length, "tunnel": layout,
			"camera_m": _vector(eye), "target_m": _vector(target),
		})
	if animate and id == selected:
		root.size = Vector2i(1280, 720)
		var frame_directory := output.path_join(id + "-frames")
		assert(DirAccess.make_dir_recursive_absolute(frame_directory) == OK)
		hero.reduced_motion = false
		rival.reduced_motion = false
		for frame in range(120):
			var fraction: float = float(frame) / 119.0
			var distance: float = lerpf(start - 9.0, finish + 5.0, fraction)
			hero.transform = world.reset_transform(distance, -0.8)
			rival.transform = world.reset_transform(distance + 13.0, 1.4)
			hero.set_motion(18.0, 0.12, false, false)
			rival.set_motion(18.0, 0.10, false, false)
			hero._process(1.0 / 30.0)
			rival._process(1.0 / 30.0)
			var camera_distance: float = distance - 10.0
			var basis: Basis = world.frame(camera_distance)
			camera.fov = 60.0
			camera.look_at_from_position(
				world.position_at(camera_distance, -0.5) + basis.y * 3.0,
				world.position_at(distance + 12.0) + Vector3.UP * 1.8
			)
			await _capture(id + "-frames/frame-%04d.png" % frame)
		root.size = Vector2i(1440, 900)
		hero.reduced_motion = true
		rival.reduced_motion = true
	root.world_3d.fallback_environment = null
	world.free()
	await process_frame


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = root.get_texture().get_image()
	assert(rendered != null and not rendered.is_empty())
	assert(rendered.save_png(output.path_join(filename)) == OK)
	print("[KartAdventureCapture] ", filename)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
