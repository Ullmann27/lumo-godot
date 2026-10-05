extends SceneTree
## Compares the full-detail model to its original unmerged geometry and tests LOD.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")


class ReferenceKart:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(parent: Node3D) -> void:
		# The previous implementation batched rigid pieces only by identical paint.
		var surfaces: Dictionary = {}
		for child in parent.get_children():
			if child is MeshInstance3D and not flames.has(child) and not sparks.has(child):
				var material: Material = child.material_override
				var key: int = material.get_instance_id()
				if not surfaces.has(key):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tool.set_material(material)
					surfaces[key] = tool
				surfaces[key].append_from(child.mesh, 0, child.transform)
				child.free()
			elif child is Node3D:
				_merge_static(child)
		if not surfaces.is_empty():
			var mesh := ArrayMesh.new()
			for tool in surfaces.values():
				tool.commit(mesh)
			var node := MeshInstance3D.new()
			node.mesh = mesh
			parent.add_child(node)


func _initialize() -> void:
	call_deferred("_run")


func _geometry(
	node: Node3D, transform_from_kart: Transform3D, kart: LumoRaceKart, result: Dictionary
) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			if child == kart.far_mesh or kart.flames.has(child) or kart.sparks.has(child):
				continue
			var transform_to_kart: Transform3D = transform_from_kart * child.transform
			for surface in range(child.mesh.get_surface_count()):
				result.surfaces += 1
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var material: StandardMaterial3D = child.material_override
				if not material:
					material = child.mesh.surface_get_material(surface)
				var colors: PackedColorArray = (
					arrays[Mesh.ARRAY_COLOR]
					if arrays[Mesh.ARRAY_COLOR] != null
					else PackedColorArray()
				)
				result.vertices += positions.size()
				var indices: PackedInt32Array = (
					arrays[Mesh.ARRAY_INDEX]
					if arrays[Mesh.ARRAY_INDEX] != null
					else PackedInt32Array()
				)
				result.triangle_indices += (
					indices.size() if not indices.is_empty() else positions.size()
				)
				for i in range(positions.size()):
					var at: Vector3 = transform_to_kart * positions[i]
					var color: Color = colors[i] if not colors.is_empty() else material.albedo_color
					var key: String = (
						"%d,%d,%d"
						% [roundi(at.x * 10000), roundi(at.y * 10000), roundi(at.z * 10000)]
					)
					result.samples[key] = result.samples.get(key, 0) + 1
					if not result.paint.has(key):
						result.paint[key] = {}
					result.paint[key][color] = result.paint[key].get(color, 0) + 1
		elif child is Node3D:
			_geometry(child, transform_from_kart * child.transform, kart, result)


func _summary(kart: LumoRaceKart) -> Dictionary:
	var result := {"vertices": 0, "surfaces": 0, "triangle_indices": 0, "samples": {}, "paint": {}}
	_geometry(kart, Transform3D.IDENTITY, kart, result)
	return result


func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 0, 6)
	camera.look_at(Vector3.UP)
	camera.make_current()
	for kind in ["fox", "otter", "rabbit", "badger", "cat"]:
		var reference := ReferenceKart.new()
		reference.configure(kind, Color("7760ef"))
		root.add_child(reference)
		reference.set_process(false)
		var kart: LumoRaceKart = VEHICLE.new()
		kart.configure(kind, Color("7760ef"))
		root.add_child(kart)
		kart.set_process(false)
		var original: Dictionary = _summary(reference)
		var optimized: Dictionary = _summary(kart)
		assert(
			original.vertices == optimized.vertices,
			"Full-detail vertex count must remain unchanged"
		)
		assert(
			original.triangle_indices == optimized.triangle_indices,
			"Full-detail triangles must remain unchanged"
		)
		assert(
			original.samples == optimized.samples, "All full-detail positions must remain unchanged"
		)
		for position in original.paint:
			for color: Color in original.paint[position]:
				var matches: int = 0
				for packed_color: Color in optimized.paint[position]:
					# Godot stores mesh vertex colours at 8-bit channel precision.
					if (
						absf(color.r - packed_color.r) <= 1.0 / 255.0 + 0.00001
						and absf(color.g - packed_color.g) <= 1.0 / 255.0 + 0.00001
						and absf(color.b - packed_color.b) <= 1.0 / 255.0 + 0.00001
					):
						matches += optimized.paint[position][packed_color]
				assert(
					matches == original.paint[position][color],
					"Full-detail paints retain their positions within one 8-bit channel step"
				)
		assert(
			optimized.surfaces < original.surfaces * 0.7,
			"Vertex colours must meaningfully reduce near material passes"
		)
		assert(kart.far_mesh.mesh.get_surface_count() == 1, "Distant kart draws a single surface")
		var far_vertices: int = kart.far_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert(
			far_vertices < optimized.vertices * 0.5,
			"Distant geometry must be substantially cheaper"
		)
		for mesh_node in kart.near_meshes:
			var mesh: ArrayMesh = mesh_node.mesh
			assert(
				mesh.shadow_mesh.get_surface_count() == mesh.get_surface_count(),
				"GLES3 shadow surfaces must match each visible material surface"
			)
			for surface in range(mesh.get_surface_count()):
				var source_arrays: Array = mesh.surface_get_arrays(surface)
				var shadow_arrays: Array = mesh.shadow_mesh.surface_get_arrays(surface)
				assert(source_arrays[Mesh.ARRAY_VERTEX] == shadow_arrays[Mesh.ARRAY_VERTEX])
				assert(source_arrays[Mesh.ARRAY_INDEX] == shadow_arrays[Mesh.ARRAY_INDEX])
				var material: StandardMaterial3D = mesh.surface_get_material(surface)
				assert(material.vertex_color_use_as_albedo and material.vertex_color_is_srgb)
			if (
				kart.eyes.has(mesh_node.get_parent())
				or mesh_node.get_parent() == kart.steering_wheel
			):
				assert(mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert(kart.wheel_rotors.size() == 4 and kart.wheel_pivots.size() == 4)
		assert(
			(
				kart.eyes.size() == 2
				and is_instance_valid(kart.head)
				and is_instance_valid(kart.steering_wheel)
			)
		)
		kart.set_motion(16, 0.5, true, true)
		var wheel_before: Quaternion = kart.wheel_rotors[0].quaternion
		kart.animation_time = 4.26
		kart._process(0.06)
		assert(not kart.far_detail and not kart.far_mesh.visible)
		assert(
			not kart.wheel_rotors[0].quaternion.is_equal_approx(wheel_before),
			"Near wheels keep rotating"
		)
		assert(absf(kart.wheel_pivots[0].rotation.y) > 0.1, "Near front wheels keep steering")
		assert(is_equal_approx(kart.eyes[0].scale.y, 0.08), "Near driver keeps blinking")
		assert(absf(kart.head.rotation.y) > 0.001 and absf(kart.steering_wheel.rotation.z) > 0.1)
		if kart.tail:
			assert(absf(kart.tail.rotation.y) > 0.001, "Near tails keep moving")
		for effect in kart.flames + kart.sparks:
			assert(
				(
					effect.visible
					and effect.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				)
			)
		camera.position = Vector3(0, 0, 40)
		kart.detail_check_time = 0
		kart._process(0.1)
		assert(kart.far_detail and kart.far_mesh.visible)
		for mesh_node in kart.near_meshes:
			assert(not mesh_node.visible)
		wheel_before = kart.wheel_rotors[0].quaternion
		var phase_before: float = kart.wheel_spin_phase
		kart._process(0.1)
		assert(
			kart.wheel_rotors[0].quaternion.is_equal_approx(wheel_before),
			"Distant joints stop unnecessary transform work"
		)
		assert(
			not is_equal_approx(kart.wheel_spin_phase, phase_before),
			"Wheel phase continues across LOD transitions"
		)
		for effect in kart.flames + kart.sparks:
			assert(effect.visible, "Boost/drift feedback remains visible in distant LOD")
		camera.position.z = 27
		kart._update_detail(camera)
		assert(kart.far_detail, "Hysteresis prevents switching every frame at the boundary")
		camera.position.z = 24
		kart._update_detail(camera)
		assert(not kart.far_detail)
		for mesh_node in kart.near_meshes:
			assert(mesh_node.visible)
		camera.position = Vector3(0, 0, 6)
		kart._process(0.02)
		assert(
			not kart.wheel_rotors[0].quaternion.is_equal_approx(wheel_before),
			"Returning near restores animated wheel phase"
		)
		kart.set_motion(0, 0, false, false)
		kart._process(0.02)
		for effect in kart.flames + kart.sparks:
			assert(not effect.visible, "Stopping clears all effects")
		print(
			(
				"[KartVehicle] %s near_surfaces=%d->%d near_vertices=%d far_vertices=%d far_surfaces=1"
				% [kind, original.surfaces, optimized.surfaces, optimized.vertices, far_vertices]
			)
		)
		kart.free()
		reference.free()
	camera.free()
	print("[KartVehicle] Geometry/colours, shadows, animations, effects, LOD and hysteresis passed")
	quit(0)
