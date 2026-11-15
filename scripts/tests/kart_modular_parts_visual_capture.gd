extends SceneTree
## Real Godot 4.6.3 GL Compatibility framebuffer proof, not a conceptual mockup
## and not a screenshot of a physical Android phone.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")

const SIZE := Vector2i(1280, 720)
const PROP_KINDS := ["beacon", "service", "signal", "sculpture"]
const KART_STYLES := ["comet", "glider", "terra", "phantom"]

var output_dir: String = "res://exports/kart-modular-parts"
var stage: Node3D
var camera: Camera3D
var captures: Array[Dictionary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.trim_prefix("--output=")
	call_deferred("_run")


func _make_camera_and_lights() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6c95b6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dcefff")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-43, -34, 0)
	key.light_color = Color("fff1ce")
	key.light_energy = 1.35
	key.shadow_enabled = false
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 128, 0)
	fill.light_color = Color("a3dfff")
	fill.light_energy = 0.7
	fill.shadow_enabled = false
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 2500
	camera.fov = 47.0
	stage.add_child(camera)
	camera.make_current()


func _save_image(filename: String, metadata: Dictionary) -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image != null and image.get_width() == SIZE.x and image.get_height() == SIZE.y)
	var file: String = output_dir.path_join(filename)
	assert(image.save_png(file) == OK, "Cannot write real Godot render: " + file)
	metadata["file"] = filename
	metadata["width"] = image.get_width()
	metadata["height"] = image.get_height()
	metadata["sha256"] = FileAccess.get_sha256(file)
	captures.append(metadata)
	print("[KartModularCapture] ", filename, " sha256=", metadata.sha256)


func _part_target(world, site: Dictionary) -> Vector3:
	var d: float = float(site.distance)
	var lateral: float = float(site.side)
	match str(site.kind):
		"beacon":
			return world.position_at(d, lateral * 9.1) + world.frame(d).y * 2.8
		"service":
			return world.position_at(d, lateral * 13.7) + world.frame(d).y * 1.6
		"signal":
			return world.position_at(d) + world.frame(d).y * 5.1
		_:
			return world.position_at(d, lateral * 11.75) + world.frame(d).y * 2.5


func _view_part(world, site: Dictionary) -> void:
	var basis: Basis = world.frame(float(site.distance))
	var target: Vector3 = _part_target(world, site)
	var side: float = float(site.side)
	var at: Vector3
	if str(site.kind) == "signal":
		at = world.position_at(float(site.distance) - 22.0, 0.0) + basis.y * 4.5
	else:
		at = target + basis.x * side * 8.2 + basis.z * 11.0 + basis.y * 3.0
	camera.fov = 47.0 if str(site.kind) != "signal" else 60.0
	camera.look_at_from_position(at, target, Vector3.UP)


func _capture_parts() -> void:
	for kind in PROP_KINDS:
		var found := false
		for id in TRACKS.IDS:
			var world = WORLD.new()
			stage.add_child(world)
			world.build(true, id, true)
			var info: Dictionary = world.get_meta("kart_modular_parts", {})
			assert(not info.is_empty(), "Modular production hook is absent from " + id)
			var selected: Dictionary = {}
			for site: Dictionary in info.sites:
				if str(site.kind) == kind:
					selected = site
					break
			if not selected.is_empty():
				_view_part(world, selected)
				await _save_image("LUMO_3D_%s_%s.png" % [kind, id], {
					"kind": kind, "track_id": id,
					"location_m": [selected.distance, selected.side],
					"production_scene": true,
					"view": "staged close-up of real runtime world"
				})
				found = true
			world.free()
			await process_frame
			if found:
				break
		assert(found, "No generated runtime placement for 3D part: " + kind)


func _capture_karts() -> void:
	for style in KART_STYLES:
		var kart = VEHICLE.new()
		kart.reduced_motion = true
		kart.configure("fox" if style == "comet" else "rabbit", Color("76c8f2"), style)
		stage.add_child(kart)
		kart.set_process(false)
		var body: Node3D = kart.get_node("AuroraCoachwork")
		assert(int(body.get_meta("modular_aero_count", 0)) >= 20)
		camera.fov = 37.0
		camera.look_at_from_position(Vector3(3.25, 2.18, -4.9), Vector3(0, 0.85, 0))
		await _save_image("LUMO_Kart_%s_AeroKit.png" % style, {
			"kind": "kart", "style": style, "production_scene": true,
			"visible_modular_aero_pieces": body.get_meta("modular_aero_count"),
			"view": "staged close-up of real runtime chassis"
		})
		kart.free()
		await process_frame


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "A real rasterizer is required.")
	assert(DirAccess.make_dir_recursive_absolute(output_dir) == OK)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.msaa_3d = Viewport.MSAA_2X
	stage = Node3D.new()
	stage.name = "GodotRealProductionScreenshotStage"
	root.add_child(stage)
	_make_camera_and_lights()
	await _capture_parts()
	await _capture_karts()
	assert(captures.size() == 8, "Four track parts and four chassis renders required")
	var report := FileAccess.open(output_dir.path_join("capture-manifest.json"), FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({
		"engine": Engine.get_version_info().string,
		"backend": "Godot GL Compatibility / CI software display",
		"physical_android_device": false,
		"actual_production_geometry": true,
		"extra_studio_lighting": true,
		"capture_count": captures.size(),
		"files": captures
	}, "\t"))
	report.close()
	stage.free()
	for frame in range(4):
		await process_frame
	print("[KartModularCapture] PASS: 4 track parts + 4 real kart showroom views")
	quit(0)
