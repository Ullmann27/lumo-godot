extends RefCounted
## Copy imported Blender surfaces into a road-following instance at build time.
## Frozen PackedScenes, meshes, materials and source files are never mutated.

class CurveMap:
	extends RefCounted
	const STEP: float = 0.25
	var first: float = 0.0
	var frames: Array[Transform3D] = []

	func setup(world, start: float, finish: float) -> void:
		first = floorf((start - 3.0) / STEP) * STEP
		var count: int = ceili((finish + 3.0 - first) / STEP)
		for index in range(count + 1):
			var distance: float = first + float(index) * STEP
			frames.append(Transform3D(world.frame(distance), world.position_at(distance)))

	func sample(distance: float) -> Transform3D:
		var cursor: float = clampf((distance - first) / STEP, 0.0, float(frames.size() - 1))
		var index: int = mini(int(floorf(cursor)), frames.size() - 2)
		var weight: float = cursor - index
		return Transform3D(frames[index].basis.slerp(frames[index + 1].basis, weight), frames[index].origin.lerp(frames[index + 1].origin, weight))

	func point(source: Vector3, module_start: float) -> Vector3:
		var frame: Transform3D = sample(module_start - source.z)
		return frame.origin + frame.basis.x * source.x + frame.basis.y * source.y

	func jacobian(source: Vector3, module_start: float) -> Basis:
		var distance: float = module_start - source.z
		var frame: Transform3D = sample(distance)
		var before: Transform3D = sample(distance - 0.125)
		var after: Transform3D = sample(distance + 0.125)
		var longitudinal: Vector3 = (
			after.origin - before.origin + (after.basis.x - before.basis.x) * source.x
			+ (after.basis.y - before.basis.y) * source.y
		) / 0.25
		return Basis(frame.basis.x, frame.basis.y, -longitudinal)


static func make_visible(scene: PackedScene, curve_map: CurveMap, module_start: float, shared_materials: Dictionary) -> Dictionary:
	var source: Node3D = scene.instantiate() as Node3D
	var result := Node3D.new()
	var origin: Vector3 = curve_map.sample(module_start).origin
	result.position = origin
	var record: Dictionary = {"node": result, "triangles": 0, "markers": [], "meshes": []}
	_copy_tree(source, Transform3D.IDENTITY, result, curve_map, module_start, origin, shared_materials, record)
	source.free()
	return record


static func make_collision(scene: PackedScene, curve_map: CurveMap, module_start: float, layer: int) -> StaticBody3D:
	var source: Node3D = scene.instantiate() as Node3D
	var body := StaticBody3D.new()
	body.name = "ProductionTunnelCollision"
	body.position = curve_map.sample(module_start).origin
	body.collision_layer = layer
	body.collision_mask = 0
	var points := PackedVector3Array()
	_collision_faces(source, Transform3D.IDENTITY, curve_map, module_start, body.position, points)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(points)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.name = "HollowConcaveShell"
	collision.shape = shape
	body.add_child(collision)
	body.set_meta("triangle_count", points.size() / 3)
	source.free()
	return body


static func _copy_tree(node: Node, inherited: Transform3D, target: Node3D, curve_map: CurveMap, module_start: float, origin: Vector3, shared_materials: Dictionary, record: Dictionary) -> void:
	var local: Transform3D = inherited
	if node is Node3D:
		local = inherited * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var source_mesh: Mesh = (node as MeshInstance3D).mesh
		var geometry := ArrayMesh.new()
		for surface in source_mesh.get_surface_count():
			var arrays: Array = source_mesh.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var source_normal_basis: Basis = local.basis.inverse().transposed()
			for index in vertices.size():
				var point: Vector3 = local * vertices[index]
				var jacobian: Basis = curve_map.jacobian(point, module_start)
				vertices[index] = curve_map.point(point, module_start) - origin
				if normals.size() == vertices.size():
					normals[index] = (jacobian.inverse().transposed() * source_normal_basis * normals[index]).normalized()
				if tangents.size() == vertices.size() * 4:
					var offset: int = index * 4
					var tangent: Vector3 = Vector3(tangents[offset], tangents[offset + 1], tangents[offset + 2])
					tangent = (jacobian * local.basis * tangent).normalized()
					tangents[offset] = tangent.x
					tangents[offset + 1] = tangent.y
					tangents[offset + 2] = tangent.z
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			if not tangents.is_empty():
				arrays[Mesh.ARRAY_TANGENT] = tangents
			geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material: Material = source_mesh.surface_get_material(surface)
			if material != null:
				var key: String = material.resource_name
				if key.is_empty():
					key = str(material.get_instance_id())
				if not shared_materials.has(key):
					shared_materials[key] = material
				geometry.surface_set_material(surface, shared_materials[key])
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			record.triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		var visible := MeshInstance3D.new()
		visible.name = node.name
		visible.mesh = geometry
		target.add_child(visible)
		record.meshes.append(visible)
	elif node is Node3D:
		var extras: Dictionary = node.get_meta("extras", {})
		var role: String = str(node.get_meta("lumo_socket", extras.get("lumo_socket", "")))
		var light_socket: bool = String(node.name).contains("LightSocket") or node.has_meta("lumo_light_socket") or extras.has("lumo_light_socket")
		if role.is_empty() and String(node.name) in ["SocketIn", "SocketOut"]:
			role = "in" if String(node.name) == "SocketIn" else "out"
		if not role.is_empty() or light_socket:
			var marker := Marker3D.new()
			marker.name = node.name
			var at: Transform3D = curve_map.sample(module_start - local.origin.z)
			marker.transform = Transform3D(at.basis * local.basis, curve_map.point(local.origin, module_start) - origin)
			marker.set_meta("lumo_socket", role)
			marker.set_meta("lumo_light_socket", light_socket)
			var color_value: Variant = node.get_meta("light_color_srgb", extras.get("light_color_srgb", "d8eadf"))
			marker.set_meta("light_color_srgb", color_value)
			target.add_child(marker)
			record.markers.append(marker)
	for child in node.get_children():
		_copy_tree(child, local, target, curve_map, module_start, origin, shared_materials, record)


static func _collision_faces(node: Node, inherited: Transform3D, curve_map: CurveMap, module_start: float, origin: Vector3, points: PackedVector3Array) -> void:
	var local: Transform3D = inherited
	if node is Node3D:
		local = inherited * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var faces: PackedVector3Array = (node as MeshInstance3D).mesh.get_faces()
		for vertex in faces:
			points.append(curve_map.point(local * vertex, module_start) - origin)
	for child in node.get_children():
		_collision_faces(child, local, curve_map, module_start, origin, points)
