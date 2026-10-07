extends SceneTree
## Exports and re-imports current runtime geometry and the separate authoring-only loop.

const WORLD = preload("res://scripts/games/kart_world.gd")
const LOOP_PREVIEW = preload("res://scripts/games/authoring/track_authoring_loop_preview.gd")

var track_id: String = ""
var output_dir: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	track_id = _track_id_from_args()
	assert(track_id in ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"])
	output_dir = "res://exports/track-pack-geometry/" + track_id
	DirAccess.make_dir_recursive_absolute(output_dir)

	var world = WORLD.new()
	root.add_child(world)
	world.build(false, track_id)
	await process_frame

	var runtime_path := output_dir + "/runtime_world.glb"
	var runtime_inventory := _inventory_world(world)
	_write_and_verify_glb(world, runtime_path, false)
	runtime_inventory["export"] = _file_record(runtime_path)
	runtime_inventory["imported_mesh_nodes"] = _imported_mesh_count(runtime_path)
	assert(
		runtime_inventory["imported_mesh_nodes"] == runtime_inventory["mesh_instances"],
		"Runtime GLB re-import did not preserve every geometry instance: " + track_id
	)
	runtime_inventory["geometry_status"] = "exported_from_current_runtime_world"
	runtime_inventory["planned_modules_included"] = false
	runtime_inventory["collision_authority"] = "runtime collision behavior remains in the existing Godot source"
	_write_json(output_dir + "/runtime_geometry_inventory.json", runtime_inventory)

	var loop_preview = LOOP_PREVIEW.new()
	loop_preview.configure(track_id)
	root.add_child(loop_preview)
	var loop_path := output_dir + "/authoring_full_loop.glb"
	_write_and_verify_glb(loop_preview, loop_path, true)
	var loop_inventory := _inventory_world(loop_preview)
	loop_inventory["export"] = _file_record(loop_path)
	loop_inventory["imported_mesh_nodes"] = _imported_mesh_count(loop_path)
	assert(
		loop_inventory["imported_mesh_nodes"] == loop_inventory["mesh_instances"],
		"Authoring-loop GLB re-import did not preserve every mesh instance: " + track_id
	)
	loop_inventory["geometry_status"] = "authoring_preview_only"
	loop_inventory["runtime_driveable"] = false
	loop_inventory["collision_included"] = false
	loop_inventory["requires_inverted_physics_contract"] = true
	loop_inventory["planned_modules_included"] = false
	_write_json(output_dir + "/authoring_loop_inventory.json", loop_inventory)

	print(
		"[TrackPackGeometry] PASS track=",
		track_id,
		" runtime_mesh_nodes=",
		runtime_inventory["mesh_nodes"],
		" runtime_instances=",
		runtime_inventory["mesh_instances"],
		" loop_mesh_nodes=",
		loop_inventory["mesh_nodes"],
		" loop_runtime_driveable=false"
	)
	quit(0)


func _track_id_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--track-id="):
			return text.trim_prefix("--track-id=")
	return ""


func _inventory_world(source_root: Node3D) -> Dictionary:
	var records: Array[Dictionary] = []
	var collision_objects: Array[Dictionary] = []
	var collision_shapes: Array[Dictionary] = []
	var mesh_instance_count := 0
	var mesh_node_count := 0
	var multimesh_node_count := 0
	var multimesh_instance_count := 0
	for node in source_root.find_children("*", "", true, false):
		if node is CollisionObject3D:
			collision_objects.append(
				{
					"node_path": str(source_root.get_path_to(node)),
					"class": node.get_class(),
					"transform": _transform_record(node.global_transform),
				}
			)
		if node is CollisionShape3D:
			collision_shapes.append(
				{
					"node_path": str(source_root.get_path_to(node)),
					"class": node.get_class(),
					"shape_class": node.shape.get_class() if node.shape else "none",
					"shape_dimensions_m": _shape_dimensions(node.shape),
					"transform": _transform_record(node.global_transform),
				}
			)
		if node is MeshInstance3D and node.mesh:
			mesh_node_count += 1
			mesh_instance_count += 1
			records.append(_mesh_record(source_root, node, node.mesh, node.global_transform, 0, Color.WHITE))
		elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
			multimesh_node_count += 1
			for index in range(node.multimesh.instance_count):
				var instance_transform: Transform3D = (
					node.global_transform * node.multimesh.get_instance_transform(index)
				)
				var instance_color: Color = node.multimesh.get_instance_color(index)
				records.append(
					_mesh_record(
						source_root,
						node,
						node.multimesh.mesh,
						instance_transform,
						index,
						instance_color
					)
				)
				mesh_instance_count += 1
				multimesh_instance_count += 1

	return {
		"schema_version": "1.0.0",
		"track_id": track_id,
		"source": "scripts/games/kart_world.gd",
		"units": "meters",
		"mesh_nodes": mesh_node_count,
		"mesh_instances": mesh_instance_count,
		"multimesh_nodes_expanded": multimesh_node_count,
		"multimesh_instances_expanded": multimesh_instance_count,
		"collision_objects": collision_objects,
		"collision_object_count": collision_objects.size(),
		"collision_shapes": collision_shapes,
		"collision_shape_count": collision_shapes.size(),
		"geometry_instances": records,
	}


func _mesh_record(
	source_root: Node3D,
	node: Node3D,
	mesh: Mesh,
	transform: Transform3D,
	instance_index: int,
	instance_color: Color
) -> Dictionary:
	var materials: Array[Dictionary] = []
	for surface in range(mesh.get_surface_count()):
		var material: Material = null
		if node is GeometryInstance3D:
			material = node.material_override
		if material == null:
			material = mesh.surface_get_material(surface)
		materials.append(_material_record(material))
	return {
		"node_path": str(source_root.get_path_to(node)),
		"node_class": node.get_class(),
		"instance_index": instance_index,
		"mesh_class": mesh.get_class(),
		"mesh_name": mesh.resource_name,
		"mesh_aabb_position_m": _vector_record(mesh.get_aabb().position),
		"mesh_aabb_size_m": _vector_record(mesh.get_aabb().size),
		"world_aabb_size_m": _transformed_aabb_size(mesh.get_aabb(), transform),
		"transform": _transform_record(transform),
		"instance_color": _color_record(instance_color),
		"materials": materials,
		"collision_status": (
			"collision_node"
			if node is CollisionObject3D or node.get_parent() is CollisionObject3D
			else "visual_only_collision_defined_by_runtime_source"
		),
		"authoring_status": "current_runtime_geometry",
	}


func _material_record(material: Material) -> Dictionary:
	if material == null:
		return {"class": "none", "name": ""}
	var record := {"class": material.get_class(), "name": material.resource_name}
	if material is StandardMaterial3D:
		record["albedo_color"] = _color_record(material.albedo_color)
		record["shading_mode"] = material.shading_mode
	elif material is ShaderMaterial and material.shader:
		record["shader"] = material.shader.resource_path
	return record


func _shape_dimensions(shape: Shape3D) -> Dictionary:
	if shape is BoxShape3D:
		return {"size_m": _vector_record(shape.size)}
	if shape is SphereShape3D:
		return {"radius_m": shape.radius}
	if shape is CapsuleShape3D:
		return {"radius_m": shape.radius, "height_m": shape.height}
	if shape is CylinderShape3D:
		return {"radius_m": shape.radius, "height_m": shape.height}
	return {}


func _transformed_aabb_size(aabb: AABB, transform: Transform3D) -> Array[float]:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x in [aabb.position.x, aabb.end.x]:
		for y in [aabb.position.y, aabb.end.y]:
			for z in [aabb.position.z, aabb.end.z]:
				var corner: Vector3 = transform * Vector3(x, y, z)
				minimum.x = minf(minimum.x, corner.x)
				minimum.y = minf(minimum.y, corner.y)
				minimum.z = minf(minimum.z, corner.z)
				maximum.x = maxf(maximum.x, corner.x)
				maximum.y = maxf(maximum.y, corner.y)
				maximum.z = maxf(maximum.z, corner.z)
	return _vector_record(maximum - minimum)


func _write_and_verify_glb(source_root: Node3D, path: String, authoring_loop: bool) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var append_error: Error = document.append_from_scene(source_root, state)
	assert(append_error == OK, "GLB scene export failed: " + path)
	var write_error: Error = document.write_to_filesystem(state, path)
	assert(write_error == OK, "GLB file write failed: " + path)
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null and file.get_length() > 20, "GLB is empty: " + path)
	assert(file.get_buffer(4).get_string_from_ascii() == "glTF", "Invalid GLB header: " + path)
	file.close()

	var import_document := GLTFDocument.new()
	var import_state := GLTFState.new()
	var import_error: Error = import_document.append_from_file(path, import_state)
	assert(import_error == OK, "GLB re-import failed: " + path)
	var imported_scene := import_document.generate_scene(import_state)
	assert(imported_scene != null, "GLB generated no scene: " + path)
	var imported_mesh_count := imported_scene.find_children("*", "MeshInstance3D", true, false).size()
	if not authoring_loop:
		imported_mesh_count += imported_scene.find_children("*", "MultiMeshInstance3D", true, false).size()
	assert(imported_mesh_count > 0, "GLB re-import has no mesh geometry: " + path)
	imported_scene.free()


func _imported_mesh_count(path: String) -> int:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(path, state) == OK)
	var imported_scene := document.generate_scene(state)
	assert(imported_scene != null)
	var count := imported_scene.find_children("*", "MeshInstance3D", true, false).size()
	count += imported_scene.find_children("*", "MultiMeshInstance3D", true, false).size()
	imported_scene.free()
	return count


func _file_record(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK)
	assert(hashing.update(bytes) == OK)
	return {
		"path": path.get_file(),
		"bytes": bytes.size(),
		"sha256": hashing.finish().hex_encode(),
	}


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _transform_record(transform: Transform3D) -> Dictionary:
	return {
		"basis": [
			_vector_record(transform.basis.x),
			_vector_record(transform.basis.y),
			_vector_record(transform.basis.z),
		],
		"origin_m": _vector_record(transform.origin),
	}


func _vector_record(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _color_record(value: Color) -> Array[float]:
	return [value.r, value.g, value.b, value.a]
