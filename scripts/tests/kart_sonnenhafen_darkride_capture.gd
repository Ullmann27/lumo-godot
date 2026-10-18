extends SceneTree
## Deterministic real-renderer evidence: legacy cave views plus optional cinema views.
## -- --output=/absolute/folder --cinema [--low-detail] [--no-flat-reference]
const WORLD = preload("res://scripts/games/kart_world.gd")
const RIDE = preload("res://scripts/games/kart_sonnenhafen_darkride.gd")
const KART = preload("res://scripts/games/kart_vehicle.gd")
const CRANE = preload("res://scripts/games/kart_harbor_crane.gd")
const OUTPUT: String = "res://artifacts/sonnenhafen-darkride"
var folder: String = OUTPUT
var cinema := false
var low_detail := false
var flat_enabled := true
var frozen_shaders: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			folder = argument.trim_prefix("--output=")
		cinema = cinema or argument == "--cinema"
		low_detail = low_detail or argument == "--low-detail"
		flat_enabled = flat_enabled and argument != "--no-flat-reference"
	root.size = Vector2i(1280, 720)
	var world: LumoRaceWorld = WORLD.new()
	root.add_child(world)
	world.build(low_detail, "sonnenhafen", false)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	assert(world.has_node("SonnenhafenBioluminescentDarkride"))
	var cave: MeshInstance3D = world.get_node(
		"SonnenhafenBioluminescentDarkride/DarkrideRockAndCanopy"
	)
	var cave_material: ShaderMaterial = cave.material_override
	# Freeze every material clock, including water and harbor shaders. No real-time
	# trolley, driver or daylight changes may contaminate the A/B comparison.
	_freeze_materials(world)
	var info: Dictionary = world.get_meta("sonnenhafen_darkride")
	var start_m: float = float(info["start_m"])
	var end_m: float = float(info["end_m"])
	var camera := Camera3D.new()
	camera.fov = 73.0
	camera.near = 0.08
	camera.far = 450.0
	root.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var views: Array[Dictionary] = [
		{"name": "entrance", "distance": start_m - 23.0, "height": 3.2, "look": start_m + 27.0},
		{
			"name": "deep_neon",
			"distance": start_m + (end_m - start_m) * 0.42,
			"height": 2.2,
			"look": start_m + (end_m - start_m) * 0.42 + 26.0
		},
		{"name": "exit", "distance": end_m - 35.0, "height": 2.9, "look": end_m + 12.0}
	]
	var kart: LumoRaceKart = null
	if cinema:
		views.append({"name": "harbor_overview", "distance": 0.0, "height": 0.0, "look": 0.0})
		views.append({"name": "driver_camera", "distance": start_m + 62.0, "height": 2.2, "look": start_m + 86.0})
		views.append({"name": "kart_closeup", "distance": 245.0, "height": 2.2, "look": 250.0})
		kart = KART.new()
		world.add_child(kart)
		kart.configure("fox", Color("f08a2c"), "comet")
		kart.set_animated_lumo_enabled(true)
		kart.set_graphics_quality("low" if low_detail else "high")
		kart.set_motion(0.0, 0.0, false, false)
		_freeze_materials(kart)
		kart.hide()
	var evidence: Array[Dictionary] = []
	for view in views:
		var d: float = float(view["distance"])
		var ahead: float = float(view["look"])
		camera.global_position = world.position_at(d) + world.frame(d).y * float(view["height"])
		camera.look_at(world.position_at(ahead) + world.frame(ahead).y * 2.7)
		camera.fov = 73.0
		if kart != null:
			kart.hide()
		if str(view.name) == "harbor_overview":
			# Fixed world-space terminal camera also documents the pre-fix empty
			# site: old crane candidates no longer fit the extended island.
			var berth: Transform3D = CRANE._frame(Vector3(130.0, 0.0, 38.0))
			camera.global_position = berth * Vector3(46.0, 24.0, -46.0)
			camera.look_at(berth * Vector3(0.0, 9.0, 5.0))
			camera.fov = 60.0
		elif str(view.name) == "driver_camera":
			kart.transform = Transform3D(world.frame(d), world.position_at(d))
			kart.show()
			camera.global_position = world.position_at(d - 6.2) + Vector3.UP * 2.9
			camera.look_at(world.position_at(d + 17.0) + Vector3.UP * 1.2)
		elif str(view.name) == "kart_closeup":
			kart.transform = Transform3D(world.frame(d), world.position_at(d))
			kart.show()
			camera.global_position = kart.transform * Vector3(-3.8, 2.1, -4.5)
			camera.look_at(kart.position + Vector3.UP * 0.95)
			camera.fov = 36.0
		var flat_reference: Image = null
		if str(view.name) == "deep_neon" and flat_enabled:
			cave_material.set_shader_parameter("rock_detail_strength", 0.0)
			for _baseline_frame in range(26):
				await process_frame
			await RenderingServer.frame_post_draw
			flat_reference = root.get_texture().get_image()
			assert(flat_reference != null and not flat_reference.is_empty())
			var baseline_path: String = ProjectSettings.globalize_path(folder).path_join(
				"deep_neon_flat_baseline.png"
			)
			assert(flat_reference.save_png(baseline_path) == OK)
			cave_material.set_shader_parameter("rock_detail_strength", 1.0)
		var frame_durations: Array[float] = []
		for _frame in range(12 if cinema else 26):
			var frame_start: int = Time.get_ticks_usec()
			await process_frame
			frame_durations.append(float(Time.get_ticks_usec() - frame_start) / 1000.0)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img == null or img.is_empty() or img.get_width() != 1280 or img.get_height() != 720:
			printerr("[DarkrideRender] Invalid real GPU frame for ", view.name)
			quit(1)
			return
		var file: String = ProjectSettings.globalize_path(folder).path_join(str(view.name) + ".png")
		if img.save_png(file) != OK:
			printerr("[DarkrideRender] Could not save ", file)
			quit(1)
			return
		print("[DarkrideRender] real 1280x720: ", file)
		evidence.append({
			"view": view.name, "camera": _transform(camera.global_transform), "fov": camera.fov,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"frame_intervals_ms": frame_durations,
		})
		if flat_reference != null:
			var altered_pixels: int = 0
			for py in range(64, 400, 8):
				for px in range(64, 1216, 8):
					var before: Color = flat_reference.get_pixel(px, py)
					var after: Color = img.get_pixel(px, py)
					var difference: float = (
						absf(before.r - after.r)
						+ absf(before.g - after.g)
						+ absf(before.b - after.b)
					)
					if difference > 0.025:
						altered_pixels += 1
			assert(altered_pixels > 120, "Mineral strata must visibly affect the real cave camera")
			print(
				"[DarkrideArtPass] PASS: same-camera real GPU baseline/detail pixels=",
				altered_pixels
			)
	print("[DarkrideRender] PASS: entrance, deep_neon, exit photographed in Godot")
	var manifest := FileAccess.open(ProjectSettings.globalize_path(folder).path_join("capture.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(), "low_detail": low_detail,
		"source_commit": OS.get_environment("LUMO_CAPTURE_COMMIT"), "size": [1280, 720],
		"animation_time": 0.0, "views": evidence,
		"measurement_scope": "Offscreen host render intervals; not Android device FPS or GPU timing."}, "\t"))
	manifest.close()
	if cinema:
		print("[KartCinemaCapture] PASS: six fixed cameras, frozen animation, real Compatibility frames")
	quit(0)


func _transform(value: Transform3D) -> Array:
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z]


func _freeze_material(material: Material) -> void:
	if not material is ShaderMaterial:
		return
	var shader: Shader = material.shader
	if shader == null:
		return
	var key: int = shader.get_instance_id()
	if not frozen_shaders.has(key):
		var frozen := Shader.new()
		frozen.code = shader.code.replace("TIME", "0.0")
		frozen_shaders[key] = frozen
	material.shader = frozen_shaders[key]
	material.set_shader_parameter("animation_time", 0.0)


func _freeze_materials(node: Node) -> void:
	if node is GeometryInstance3D:
		_freeze_material(node.material_override)
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			_freeze_material(node.get_active_material(surface))
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		for surface in range(node.multimesh.mesh.get_surface_count()):
			_freeze_material(node.multimesh.mesh.surface_get_material(surface))
	for child in node.get_children():
		_freeze_materials(child)
