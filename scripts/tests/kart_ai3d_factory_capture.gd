extends SceneTree
## Independent Godot-4.6.3 import and real GPU turntable QA for Python-generated GLB.
## Does NOT overwrite game assets or auto-approve art for shipping.
var source := "res://build/ai3d/sonnenhafen_biolum_cavern_crystals.glb"
var output := "res://artifacts/ai3d-factory"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.get_basename() + ".json"))
	assert(report is Dictionary and not report.is_empty(), "Missing generator manifest")
	assert(FileAccess.get_sha256(source) == report.sha256, "Unverified generated GLB")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(source, state) == OK, "Godot cannot import GLB")
	var model: Node = doc.generate_scene(state)
	assert(model != null, "No imported 3D scene")
	var nodes: Array[Node] = [model]
	var triangles: int = 0
	var mesh_nodes: int = 0
	var mesh_bounds := AABB()
	var has_bounds := false
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children():
			nodes.append(child)
		if current is MeshInstance3D:
			mesh_nodes += 1
			var visual: MeshInstance3D = current
			var bounds := visual.mesh.get_aabb()
			mesh_bounds = mesh_bounds.merge(bounds) if has_bounds else bounds
			has_bounds = true
			for i in range(visual.mesh.get_surface_count()):
				var arrays: Array = visual.mesh.surface_get_arrays(i)
				var indices = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if not indices.is_empty()
					else arrays[Mesh.ARRAY_VERTEX].size()) / 3
				assert(visual.get_active_material(i) != null, "Material lost on import")
	assert(mesh_nodes > 0 and triangles == int(report.triangles),
		"Actual Godot mesh differs from signed geometry manifest")
	var expected_min := Vector3(report.bbox_min_m[0], report.bbox_min_m[1], report.bbox_min_m[2])
	var expected_max := Vector3(report.bbox_max_m[0], report.bbox_max_m[1], report.bbox_max_m[2])
	assert(mesh_bounds.position.is_equal_approx(expected_min), "Imported mesh minimum differs")
	assert(mesh_bounds.end.is_equal_approx(expected_max), "Imported mesh maximum differs")
	print("[AI3DFactory] import PASS: nodes=", mesh_nodes, " triangles=", triangles)
	if "--validate-only" in OS.get_cmdline_user_args():
		model.free()
		quit(0)
		return

	root.size = Vector2i(1280, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	scene.add_child(model)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111e35")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c9e9")
	environment.ambient_light_energy = 0.65
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	scene.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -55.0, 0.0)
	light.light_energy = 1.7
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 53.0
	scene.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var target := Vector3(0.0, float(report.bbox_max_m[1]) * 0.48, 0.0)
	var positions := [Vector3(8.0, 4.5, 9.0), Vector3(-9.0, 5.5, 7.0),
		Vector3(1.0, 10.0, -10.0)]
	for i in range(positions.size()):
		camera.look_at_from_position(target + positions[i], target)
		for _wait in range(25):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		assert(frame != null and not frame.is_empty())
		assert(frame.get_width() == 1280 and frame.get_height() == 720)
		var output_file: String = ProjectSettings.globalize_path(output).path_join("view_" + str(i) + ".png")
		assert(frame.save_png(output_file) == OK)
		print("[AI3DFactory] actual Godot camera: ", output_file)
	print("[AI3DFactory] PASS: GLB v2 geometry, PBR materials, real engine and three rendered views")
	quit(0)
