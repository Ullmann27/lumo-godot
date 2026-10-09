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
				# Independent reference: enumerate triangle corners explicitly,
				# including authored meshes that have no index array.
				var arrays: Array = child.mesh.surface_get_arrays(0)
				var source_indices: PackedInt32Array = (
					arrays[Mesh.ARRAY_INDEX]
					if arrays[Mesh.ARRAY_INDEX] != null
					else PackedInt32Array()
				)
				if source_indices.is_empty():
					for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
						source_indices.append(index)
					arrays[Mesh.ARRAY_INDEX] = source_indices
				var indexed := ArrayMesh.new()
				indexed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				surfaces[key].append_from(indexed, 0, child.transform)
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


class AuthoredKart:
	extends ReferenceKart

	func _merge_static(_parent: Node3D) -> void:
		# Count actual authored triangles independently of either batching path.
		pass


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


func _align_float_buckets(reference: Dictionary, current: Dictionary) -> void:
	# Baking a rotated fur volume writes float32 vertex positions one step earlier
	# than a retained scene transform. Match only adjacent 0.1 mm buckets; all
	# vertex counts and per-position colour counts remain independently checked.
	for key: String in current.samples.keys():
		if reference.samples.has(key):
			continue
		var parts: PackedStringArray = key.split(",")
		var p := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var destination: String = ""
		for offset in [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0),
			Vector3i(0, -1, 0),
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1)
		]:
			var q: Vector3i = p + offset
			var candidate: String = "%d,%d,%d" % [q.x, q.y, q.z]
			if (
				reference.samples.has(candidate)
				and not current.samples.has(candidate)
				and reference.samples[candidate] == current.samples[key]
			):
				destination = candidate
				break
		if destination.is_empty():
			continue
		current.samples[destination] = current.samples[key]
		current.samples.erase(key)
		current.paint[destination] = current.paint[key]
		current.paint.erase(key)


func _authored_far_index_count(node: Node3D, kart: LumoRaceKart) -> int:
	var count: int = 0
	for child in node.get_children():
		if child is MeshInstance3D:
			if kart.flames.has(child) or kart.sparks.has(child) or child.has_meta("near_only") or child.mesh.has_meta("far_skip"):
				continue
			var geometry: Mesh = kart._far_geometry(child.mesh)
			var arrays: Array = geometry.surface_get_arrays(0)
			var indices: PackedInt32Array = (
				arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			)
			count += indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
		elif child is Node3D:
			count += _authored_far_index_count(child, kart)
	return count


func _paints_match(reference: Dictionary, current: Dictionary) -> bool:
	# Every packed vertex may satisfy only one authored vertex. Summing all
	# colours within the tolerance double-counts adjacent iris/fur pigments.
	var needed: Dictionary = reference.duplicate()
	var available: Dictionary = current.duplicate()
	for color: Color in needed:
		var exact: int = mini(needed[color], available.get(color, 0))
		needed[color] -= exact
		available[color] = available.get(color, 0) - exact
	for color: Color in needed:
		for packed: Color in available:
			if needed[color] == 0:
				break
			# Godot stores mesh vertex colours at 8-bit channel precision.
			if (
				maxf(
					absf(color.r - packed.r),
					maxf(absf(color.g - packed.g), absf(color.b - packed.b))
				)
				<= 1.0 / 255.0 + 0.00001
			):
				var matched: int = mini(needed[color], available[packed])
				needed[color] -= matched
				available[packed] -= matched
		if needed[color] != 0:
			return false
	for count: int in available.values():
		if count != 0:
			return false
	return true


func _run() -> void:
	var close_pigments := {Color8(117, 66, 32): 7, Color8(117, 66, 31): 2}
	assert(
		_paints_match(close_pigments, close_pigments),
		"Adjacent identical pigments must not be double-counted"
	)
	assert(
		not _paints_match(close_pigments, {Color8(117, 66, 32): 7}),
		"Missing coloured vertices must fail"
	)
	assert(not _paints_match(close_pigments, {Color8(10, 10, 10): 9}), "Changed pigments must fail")
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
		var authored := AuthoredKart.new()
		authored.configure(kind, Color("7760ef"))
		root.add_child(authored)
		authored.set_process(false)
		var authored_geometry: Dictionary = _summary(authored)
		var original: Dictionary = _summary(reference)
		var optimized: Dictionary = _summary(kart)
		assert(
			original.triangle_indices == authored_geometry.triangle_indices,
			"Reference must retain every authored triangle, including unindexed badges"
		)
		assert(
			original.vertices == authored_geometry.vertices,
			"Reference must retain all authored vertices"
		)
		assert(
			original.vertices == optimized.vertices,
			"Full-detail vertex count must remain unchanged"
		)
		assert(
			original.triangle_indices == optimized.triangle_indices,
			"Full-detail triangles must remain unchanged"
		)
		_align_float_buckets(original, optimized)
		assert(
			original.samples == optimized.samples, "All full-detail positions must remain unchanged"
		)
		for position in original.paint:
			assert(
				_paints_match(original.paint[position], optimized.paint[position]),
				"Full-detail paints retain their positions and counts within one 8-bit channel step"
			)
		assert(
			optimized.surfaces < original.surfaces * 0.7 and optimized.surfaces <= 64,
			"Vertex colours must meaningfully reduce near material passes"
		)
		assert(kart.far_mesh.mesh.get_surface_count() == 1, "Distant kart draws a single surface")
		var far_vertices: int = kart.far_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		var far_indices: PackedInt32Array = kart.far_mesh.mesh.surface_get_arrays(0)[
			Mesh.ARRAY_INDEX
		]
		assert(
			far_indices.size() == _authored_far_index_count(authored, authored),
			"Distant batching must also retain every reduced triangle and badge"
		)
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
		kart.animation_time = 0.0
		kart._process(0.06)
		assert(not kart.far_detail and not kart.far_mesh.visible)
		assert(
			not kart.wheel_rotors[0].quaternion.is_equal_approx(wheel_before),
			"Near wheels keep rotating"
		)
		assert(absf(kart.wheel_pivots[0].rotation.y) > 0.1, "Near front wheels keep steering")
		# Test an entire blink cycle rather than the timing of a previous animation.
		var minimum_eye_open: float = 1.0
		var maximum_eye_open: float = 0.0
		for frame in range(500):
			kart._process(0.01)
			minimum_eye_open = minf(minimum_eye_open, kart.eyes[0].scale.y)
			maximum_eye_open = maxf(maximum_eye_open, kart.eyes[0].scale.y)
			assert(kart.eyes[0].scale.y >= 0.0 and kart.eyes[0].scale.y <= 1.0)
		assert(
			minimum_eye_open < 0.15 and maximum_eye_open > 0.99,
			"Near driver keeps blinking and reopening eyes"
		)
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
		camera.position.z = kart.detail_distance - kart.DETAIL_HYSTERESIS * 0.5
		kart._update_detail(camera)
		assert(kart.far_detail, "Hysteresis prevents switching every frame at the boundary")
		camera.position.z = kart.detail_distance - kart.DETAIL_HYSTERESIS - 1.0
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
				(
					"[KartVehicle] %s near_surfaces=%d->%d near_vertices=%d "
					+ "far_vertices=%d far_surfaces=1 triangles_preserved=%d"
				)
				% [
					kind,
					original.surfaces,
					optimized.surfaces,
					optimized.vertices,
					far_vertices,
					optimized.triangle_indices / 3
				]
			)
		)
		kart.free()
		reference.free()
		authored.free()
	camera.free()
	print("[KartVehicle] Geometry/colours, shadows, animations, effects, LOD and hysteresis passed")
	quit(0)
