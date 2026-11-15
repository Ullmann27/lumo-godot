extends Node3D
## Authored Blender guidance on the existing tunnel shoulder. No gameplay bodies,
## extra lights or per-frame updates; two static mesh batches share four materials.

const FLOOR_FIT = preload("res://scripts/games/kart_guidance_floor_fit.gd")
const LATERAL: float = 6.50
const CLEAR_HALF_WIDTH: float = 5.90
const ROLES: Array[String] = ["guide_body", "guide_trim", "guide_inset", "guide_signal"]
const ASSET_ROOT: String = "res://assets/kart/production/details/"
const PALETTES: Dictionary = {
	"zauberwald": ["536c59", "d0ad65", "263d34", "a5f0ca"],
	"bergwelt": ["626582", "d7a646", "303648", "ffd17a"],
	"holo_city": ["233951", "c6a46b", "101c29", "72e6ed"],
	"crystal_canyon": ["665c85", "d4b0da", "29243e", "7ce0ee"],
	"jungle_temple": ["806945", "cbab70", "354534", "c8e6b4"],
	"candy_cloud": ["b69bdc", "ed94b4", "51466b", "ffd17e"],
	"volcano_night": ["242a3d", "947462", "171c2d", "ee9548"],
	"winter_sprint": ["6d7a8d", "cbdced", "344d7e", "ffc570"],
	"galaxy_ringway": ["263452", "d6ab58", "152b52", "b5a2f5"],
	"desert_drift": ["b88950", "edc681", "245a9b", "ffe0a0"],
	"learning_lab": ["397db4", "edf2fa", "243959", "6ddcec"],
}

var batches: Array[MeshInstance3D] = []
var placements: Array[Dictionary] = []
var statistics: Dictionary = {}
var _materials: Dictionary = {}


func build(world, layout: Dictionary, curve_map, floor_faces: PackedVector3Array) -> bool:
	name = "BlenderShoulderGuidance"
	if not PALETTES.has(str(world.track_id)) or not batches.is_empty():
		push_error("Invalid production guidance theme or repeated build")
		return false
	var poses: Dictionary = {"beacon": [], "ribbon": []}
	# These stations were checked against the original GLB triangles in both
	# LODs and on both shoulders. Simple rib midpoints intersect forest ferns.
	var ribbon_station: float = 6.40 if str(world.track_id) == "volcano_night" else 6.50
	for module in layout.modules:
		if str(module.kind) != "straight_12m":
			continue
		for station in [{"kind": "beacon", "distance": 2.80}, {"kind": "ribbon", "distance": ribbon_station}]:
			var distance: float = float(module.start) + float(station.distance)
			var kind: String = str(station.kind)
			var road_frame: Transform3D = curve_map.sample(distance)
			for side in [-1.0, 1.0]:
				# Offset shoulders stretch and tilt as the road curves and banks.
				# Use the same floor derivative as the warped tunnel geometry;
				# a rigid centreline frame leaves long strips crossing decorations.
				var shoulder_basis: Basis = curve_map.jacobian(Vector3(LATERAL * side, -0.32, 0.0), distance)
				var pose := Transform3D(shoulder_basis,
					road_frame.origin + road_frame.basis.x * LATERAL * side)
				poses[kind].append(pose)
				placements.append({"kind": kind, "road_distance": distance,
					"lateral_m": LATERAL * side, "module_start": float(module.start)})
	statistics = {"theme": str(world.track_id), "lod": 1 if world.low_detail else 0,
		"instances": placements.size(), "beacons": poses.beacon.size(),
		"ribbons": poses.ribbon.size(), "lateral_m": LATERAL,
		"reserved_clear_half_width_m": CLEAR_HALF_WIDTH,
		"surface_batches": 0, "triangles": 0, "dynamic_lights": 0,
		"collision_objects": 0, "per_frame_updates": false,
		"placement_basis": "tunnel shoulder floor Jacobian",
		"normal_transform": "explicit inverse transpose baked once",
		"vertices": 0, "maximum_floor_adjustment_m": 0.0,
		"minimum_embed_m": INF, "maximum_embed_m": 0.0}
	if placements.is_empty():
		push_error("Production tunnel has no usable shoulder-guidance stations")
		return false
	for kind in ["beacon", "ribbon"]:
		if not _build_batch(kind, poses[kind], str(world.track_id), bool(world.low_detail), floor_faces):
			return false
	statistics["shared_materials"] = _materials.size()
	set_meta("production_guidance", statistics.duplicate(true))
	return true


func _build_batch(kind: String, poses: Array, theme: String, low_detail: bool, floor_faces: PackedVector3Array) -> bool:
	var stem: String = "lumo_guide_beacon" if kind == "beacon" else "lumo_guide_ribbon_2m"
	var path: String = ASSET_ROOT + stem + ("_lod1" if low_detail else "") + ".glb"
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("Missing imported Blender guidance: " + path)
		return false
	var source: Node3D = scene.instantiate() as Node3D
	var pieces: Array[Dictionary] = []
	_collect_meshes(source, Transform3D.IDENTITY, pieces)
	if pieces.size() != 1:
		push_error("Blender guidance must retain exactly one mesh per LOD: " + path)
		source.free()
		return false
	var original: Mesh = pieces[0].mesh
	var local: Transform3D = pieces[0].transform
	if not local.origin.is_finite() or not local.basis.x.is_finite() or not local.basis.y.is_finite() or not local.basis.z.is_finite() or local.basis.determinant() <= 0.0001:
		push_error("Blender guidance has an invalid imported transform: " + path)
		source.free()
		return false
	var bounds: AABB = local * original.get_aabb()
	var half_width: float = 0.24 if kind == "beacon" else 0.14
	var height: float = 1.32 if kind == "beacon" else 0.22
	var half_length: float = 0.34 if kind == "beacon" else 1.0
	# The tunnel shoulder floor is at -0.32 m. The authored support reaches
	# -0.34 m to seat the module without moving its visible navigation band.
	var envelope := AABB(Vector3(-half_width, -0.34, -half_length),
		Vector3(half_width * 2.0, height + 0.34, half_length * 2.0))
	if not bounds.position.is_finite() or not bounds.size.is_finite() or not envelope.grow(0.001).encloses(bounds):
		push_error("Blender guidance exceeds its measured shoulder envelope: " + path)
		source.free()
		return false
	if original.get_surface_count() != ROLES.size():
		push_error("Blender guidance lost its four material surfaces: " + path)
		source.free()
		return false
	var sole: Dictionary = _sole_rectangle(original, local)
	if sole.is_empty():
		push_error("Blender guidance must retain its authored rectangular footing: " + path)
		source.free()
		return false
	var fitted_poses: Array[Transform3D] = []
	for pose in poses:
		var fitted: Dictionary = FLOOR_FIT.fit(pose as Transform3D, sole.bounds, float(sole.height), floor_faces)
		if not bool(fitted.get("passed", false)):
			push_error("Blender guidance has no verified floor support: " + str(fitted.get("reason", "unknown")))
			source.free()
			return false
		fitted_poses.append(fitted.pose as Transform3D)
		statistics.maximum_floor_adjustment_m = maxf(float(statistics.maximum_floor_adjustment_m), absf(float(fitted.adjustment_m)))
		statistics.minimum_embed_m = minf(float(statistics.minimum_embed_m), float(fitted.min_embed_m))
		statistics.maximum_embed_m = maxf(float(statistics.maximum_embed_m), float(fitted.max_embed_m))
	var mesh := ArrayMesh.new()
	for surface in original.get_surface_count():
		var imported: StandardMaterial3D = original.surface_get_material(surface) as StandardMaterial3D
		if imported == null or not imported.resource_name in ROLES:
			push_error("Unrecognized Blender guidance material in " + path)
			source.free()
			return false
		var arrays: Array = original.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(positions.size())
			for index in positions.size():
				indices[index] = index
		if positions.is_empty() or normals.size() != positions.size() or uv.size() != positions.size() or indices.size() % 3 != 0 or (not tangents.is_empty() and tangents.size() != positions.size() * 4):
			push_error("Blender guidance has incomplete surface attributes: " + path)
			source.free()
			return false
		var combined_positions := PackedVector3Array()
		var combined_normals := PackedVector3Array()
		var combined_uv := PackedVector2Array()
		var combined_tangents := PackedFloat32Array()
		var combined_indices := PackedInt32Array()
		combined_positions.resize(positions.size() * fitted_poses.size())
		combined_normals.resize(combined_positions.size())
		combined_uv.resize(combined_positions.size())
		combined_indices.resize(indices.size() * fitted_poses.size())
		if not tangents.is_empty():
			combined_tangents.resize(combined_positions.size() * 4)
		for instance in fitted_poses.size():
			var transform: Transform3D = fitted_poses[instance] * local
			var normal_basis: Basis = transform.basis.inverse().transposed()
			var base: int = instance * positions.size()
			for index in positions.size():
				var target: int = base + index
				combined_positions[target] = transform * positions[index]
				var normal: Vector3 = (normal_basis * normals[index]).normalized()
				combined_normals[target] = normal
				combined_uv[target] = uv[index]
				if not tangents.is_empty():
					var tangent := transform.basis * Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
					tangent = (tangent - normal * normal.dot(tangent)).normalized()
					combined_tangents[target * 4] = tangent.x
					combined_tangents[target * 4 + 1] = tangent.y
					combined_tangents[target * 4 + 2] = tangent.z
					combined_tangents[target * 4 + 3] = tangents[index * 4 + 3]
			for index in indices.size():
				combined_indices[instance * indices.size() + index] = base + indices[index]
		var combined: Array = []
		combined.resize(Mesh.ARRAY_MAX)
		combined[Mesh.ARRAY_VERTEX] = combined_positions
		combined[Mesh.ARRAY_NORMAL] = combined_normals
		combined[Mesh.ARRAY_TEX_UV] = combined_uv
		combined[Mesh.ARRAY_INDEX] = combined_indices
		if not combined_tangents.is_empty():
			combined[Mesh.ARRAY_TANGENT] = combined_tangents
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
		mesh.surface_set_material(surface, _material(imported, theme))
		statistics.triangles += int(combined_indices.size() / 3)
		statistics.vertices += combined_positions.size()
	var batch := MeshInstance3D.new()
	batch.name = "Guidance_" + kind
	batch.mesh = mesh
	batch.visibility_range_end = 145.0 if low_detail else 185.0
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low_detail else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta("source_asset", path.trim_prefix("res://"))
	batch.set_meta("instance_kind", kind)
	batch.set_meta("baked_instance_count", fitted_poses.size())
	batch.set_meta("instance_poses", fitted_poses)
	batch.set_meta("source_transform", local)
	add_child(batch)
	batches.append(batch)
	statistics.surface_batches += mesh.get_surface_count()
	source.free()
	return true


func _sole_rectangle(mesh: Mesh, local: Transform3D) -> Dictionary:
	var corners: Dictionary = {}
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var sole_height: float = INF
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = local * (vertex as Vector3)
			if absf(point.y + 0.34) > 0.0001:
				continue
			var xz := Vector2(point.x, point.z)
			minimum = minimum.min(xz)
			maximum = maximum.max(xz)
			sole_height = minf(sole_height, point.y)
			corners[Vector2(roundf(point.x * 100000.0), roundf(point.z * 100000.0))] = xz
	if corners.size() != 4 or not minimum.is_finite() or not maximum.is_finite():
		return {}
	for point in corners.values():
		var xz: Vector2 = point
		if minf(absf(xz.x - minimum.x), absf(xz.x - maximum.x)) > 0.0001 or minf(absf(xz.y - minimum.y), absf(xz.y - maximum.y)) > 0.0001:
			return {}
	return {"bounds": Rect2(minimum, maximum - minimum), "height": sole_height}


func _material(imported: StandardMaterial3D, theme: String) -> StandardMaterial3D:
	var role: String = imported.resource_name
	if not _materials.has(role):
		var copy: StandardMaterial3D = imported.duplicate(false) as StandardMaterial3D
		var color := Color(str(PALETTES[theme][ROLES.find(role)]))
		copy.albedo_color = color
		if role == "guide_signal":
			copy.emission_enabled = true
			copy.emission = color
			copy.emission_energy_multiplier = 1.1
		_materials[role] = copy
	return _materials[role] as StandardMaterial3D


func _collect_meshes(node: Node, inherited: Transform3D, pieces: Array[Dictionary]) -> void:
	var local: Transform3D = inherited
	if node is Node3D:
		local = inherited * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		pieces.append({"mesh": (node as MeshInstance3D).mesh, "transform": local})
	for child in node.get_children():
		_collect_meshes(child, local, pieces)
