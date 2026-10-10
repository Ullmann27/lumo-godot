extends SceneTree

# Standalone GLB import and render check. Never loads or edits the learning app.
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _collect(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect(child, meshes)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var render := "--render" in args
	var paths: Array[String] = []
	for arg in args:
		if arg.ends_with(".glb"):
			paths.append(arg)
	_check(not paths.is_empty(), "Supply the original and/or mobile GLB path.")
	var report: Array[Dictionary] = []
	for path in paths:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var status := document.append_from_file(path, state)
		_check(status == OK, "GLTF import failed: %s (%s)" % [path.get_file(), status])
		if status != OK:
			continue
		var scene := document.generate_scene(state)
		_check(scene != null, "Imported scene missing.")
		if scene == null:
			continue
		var stage := Node3D.new()
		root.add_child(stage)
		stage.add_child(scene)
		var meshes: Array[MeshInstance3D] = []
		_collect(scene, meshes)
		_check(not meshes.is_empty(), "Imported mesh missing.")
		var triangles := 0
		var surfaces := 0
		var uv_present := true
		var albedo_present := true
		var textures: Dictionary = {}
		var bounds := AABB()
		var first := true
		for instance in meshes:
			var current := instance.global_transform * instance.get_aabb()
			bounds = current if first else bounds.merge(current)
			first = false
			for index in range(instance.mesh.get_surface_count()):
				surfaces += 1
				var arrays := instance.mesh.surface_get_arrays(index)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += int(indices.size() / 3.0) if not indices.is_empty() else int(vertices.size() / 3.0)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				uv_present = uv_present and not uv.is_empty()
				var material := instance.mesh.surface_get_material(index)
				_check(material is BaseMaterial3D, "Expected a glTF PBR material.")
				if material is BaseMaterial3D:
					var albedo: Texture2D = material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
					albedo_present = albedo_present and albedo != null
					for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_ORM]:
						var texture: Texture2D = material.get_texture(slot)
						if texture:
							textures[str(texture.get_instance_id())] = {
								"width": texture.get_width(),
								"height": texture.get_height(),
							}
		_check(triangles > 0 and uv_present and albedo_present, "Incomplete geometry, UVs or albedo texture.")
		_check(bounds.size.is_finite() and bounds.size.y > 0, "Invalid model dimensions.")
		var item := {
			"file": path.get_file(),
			"triangles": triangles,
			"surfaces": surfaces,
			"uv_present": uv_present,
			"albedo_present": albedo_present,
			"textures": textures.values(),
			"dimensions": [bounds.size.x, bounds.size.y, bounds.size.z],
			"isolated_scene": true,
			"production_runtime_replaced": false,
		}
		if render and not failed:
			var camera := _add_studio(stage, bounds)
			var images: Array[String] = []
			for view in [{"name": "front", "angle": 0.0}, {"name": "quarter", "angle": 35.0}, {"name": "back", "angle": 180.0}]:
				var angle: float = deg_to_rad(view.angle)
				var height := bounds.size.y
				camera.position = bounds.get_center() + Vector3(sin(angle) * height * 2.1, height * 0.1, cos(angle) * height * 2.1)
				camera.look_at(bounds.get_center(), Vector3.UP)
				for frame in range(3):
					await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				_check(image != null and not image.is_empty(), "Rendered image missing.")
				if image and not image.is_empty():
					var filename := path.get_basename() + "-godot-" + str(view.name) + ".png"
					_check(image.save_png(filename) == OK, "Could not save render.")
					images.append(filename.get_file())
			item["renders"] = images
			item["renderer"] = "gl_compatibility"
		report.append(item)
		stage.free()
		await process_frame
	print("LUMO_GODOT_IMPORT=" + JSON.stringify({"engine": Engine.get_version_info().string, "passed": not failed, "models": report}))
	await create_timer(0.1).timeout
	quit(1 if failed else 0)


func _add_studio(stage: Node3D, bounds: AABB) -> Camera3D:
	var center := bounds.get_center()
	var height := bounds.size.y
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce8ff")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 150, 0)
	key.light_energy = 1.3
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -50, 0)
	fill.light_energy = 0.4
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height * 1.19
	camera.position = center + Vector3(0, height * 0.1, height * 2.1)
	stage.add_child(camera)
	camera.look_at(center, Vector3.UP)
	camera.current = true
	return camera
