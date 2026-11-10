extends RefCounted
## Geometric contact from real mesh vertices and generated support surfaces.
## Gaps are signed: positive above a surface, negative below it, INF if absent.
## Coverage concerns the selected foundation only, not a complete support chain.

const CONTACT_TOLERANCE: float = 0.35
const POINT_EPSILON: float = 0.0001
const AREA_EPSILON: float = 0.000001


static func surface(mesh: Mesh, transform: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	return {
		"faces": mesh.get_faces(), "transform": transform, "bounds": transform * mesh.get_aabb()
	}


static func assess(
	foundation_mesh: Mesh,
	foundation_transform: Transform3D,
	supports: Array[Dictionary],
	tolerance: float = CONTACT_TOLERANCE
) -> Dictionary:
	var result: Dictionary = {
		"supported": false,
		"coverage": "incomplete",
		"reason": "invalid_foundation",
		"method": "none",
		"points": [],
		"gaps": [],
		"support_heights": [],
		"probe_count": 0,
		"contact_count": 0,
		"invalid_supports": 0,
	}
	if foundation_mesh == null or not is_finite(tolerance) or tolerance < 0.0:
		return result
	var faces: PackedVector3Array = foundation_mesh.get_faces()
	if faces.is_empty() or faces.size() % 3 != 0:
		result.reason = "no_foundation_triangles"
		return result
	var vertices: PackedVector3Array = foundation_transform * faces
	var minimum_y: float = INF
	for vertex in vertices:
		if not vertex.is_finite():
			result.reason = "non_finite_foundation"
			return result
		minimum_y = minf(minimum_y, vertex.y)
	var points: Array[Vector3] = []
	var seen: Dictionary = {}
	for vertex in vertices:
		if vertex.y > minimum_y + POINT_EPSILON:
			continue
		var key: Vector3i = _vertex_key(vertex)
		if not seen.has(key):
			seen[key] = true
			points.append(vertex)
	if _has_area(points):
		result.method = "planar_lower_vertices"
	elif _is_closed(faces):
		points = _underside_points(foundation_mesh.get_aabb(), foundation_transform, vertices)
		result.method = "underside_rays"
	else:
		result.points = points
		result.probe_count = points.size()
		result.reason = "open_mesh_without_planar_lower_contact"
		return result
	result.points = points
	result.probe_count = points.size()
	if not _has_area(points):
		result.reason = "insufficient_contact_probes"
		return result
	var valid_supports: Array[Dictionary] = []
	for support in supports:
		if _valid_surface(support):
			valid_supports.append(support)
		else:
			result.invalid_supports = int(result.invalid_supports) + 1
	var gaps: Array[float] = []
	var heights: Array[float] = []
	var contacts: int = 0
	for point in points:
		var nearest_gap: float = INF
		var nearest_height: float = NAN
		for support in valid_supports:
			var bounds: AABB = support.bounds
			if (
				point.x < bounds.position.x - POINT_EPSILON
				or point.x > bounds.end.x + POINT_EPSILON
			):
				continue
			if (
				point.z < bounds.position.z - POINT_EPSILON
				or point.z > bounds.end.z + POINT_EPSILON
			):
				continue
			var support_faces: PackedVector3Array = support.faces
			var support_transform: Transform3D = support.transform
			var surface_top: float = -INF
			for index in range(0, support_faces.size(), 3):
				var hit: float = _vertical_hit(
					point,
					support_transform * support_faces[index],
					support_transform * support_faces[index + 1],
					support_transform * support_faces[index + 2]
				)
				if is_finite(hit):
					surface_top = maxf(surface_top, hit)
			if is_finite(surface_top) and absf(point.y - surface_top) < absf(nearest_gap):
				nearest_gap = point.y - surface_top
				nearest_height = surface_top
		gaps.append(nearest_gap)
		heights.append(nearest_height)
		if absf(nearest_gap) <= tolerance:
			contacts += 1
	result.gaps = gaps
	result.support_heights = heights
	result.contact_count = contacts
	if int(result.invalid_supports) > 0:
		result.reason = "invalid_support_geometry"
		return result
	result.coverage = "complete"
	result.supported = contacts == points.size()
	result.reason = "contact_observed" if result.supported else "missing_support_contact"
	return result


static func _valid_surface(value: Dictionary) -> bool:
	if not value.has_all(["faces", "transform", "bounds"]):
		return false
	if typeof(value.faces) != TYPE_PACKED_VECTOR3_ARRAY:
		return false
	if typeof(value.transform) != TYPE_TRANSFORM3D or typeof(value.bounds) != TYPE_AABB:
		return false
	var faces: PackedVector3Array = value.faces
	return not faces.is_empty() and faces.size() % 3 == 0


static func _vertex_key(point: Vector3) -> Vector3i:
	return Vector3i(
		roundi(point.x / POINT_EPSILON),
		roundi(point.y / POINT_EPSILON),
		roundi(point.z / POINT_EPSILON)
	)


static func _has_area(points: Array[Vector3]) -> bool:
	if points.size() < 3:
		return false
	var origin: Vector3 = points[0]
	for first in range(1, points.size()):
		var a: Vector2 = Vector2(points[first].x - origin.x, points[first].z - origin.z)
		if a.length_squared() <= POINT_EPSILON * POINT_EPSILON:
			continue
		for second in range(first + 1, points.size()):
			var b: Vector2 = Vector2(points[second].x - origin.x, points[second].z - origin.z)
			if absf(a.cross(b)) > AREA_EPSILON:
				return true
	return false


static func _is_closed(faces: PackedVector3Array) -> bool:
	# Shared positions may be duplicated for face normals or texture seams.
	var vertex_ids: Dictionary = {}
	var edges: Dictionary = {}
	for index in range(0, faces.size(), 3):
		var triangle: Array[int] = []
		for offset in range(3):
			var key: Vector3i = _vertex_key(faces[index + offset])
			if not vertex_ids.has(key):
				vertex_ids[key] = vertex_ids.size()
			triangle.append(int(vertex_ids[key]))
		if triangle[0] == triangle[1] or triangle[1] == triangle[2] or triangle[2] == triangle[0]:
			continue
		for offset in range(3):
			var a: int = triangle[offset]
			var b: int = triangle[(offset + 1) % 3]
			var edge: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			edges[edge] = int(edges.get(edge, 0)) + 1
	if edges.is_empty():
		return false
	for count in edges.values():
		if int(count) != 2:
			return false
	return true


static func _underside_points(
	bounds: AABB, transform: Transform3D, vertices: PackedVector3Array
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var offsets: Array[Vector2] = [
		Vector2.ZERO, Vector2(0.2, 0), Vector2(-0.2, 0), Vector2(0, 0.2), Vector2(0, -0.2)
	]
	for offset in offsets:
		var probe: Vector3 = (
			transform
			* (
				bounds.get_center()
				+ Vector3(offset.x * bounds.size.x, 0.0, offset.y * bounds.size.z)
			)
		)
		var underside: float = INF
		for index in range(0, vertices.size(), 3):
			var hit: float = _vertical_hit(
				probe, vertices[index], vertices[index + 1], vertices[index + 2]
			)
			if is_finite(hit):
				underside = minf(underside, hit)
		if is_finite(underside):
			result.append(Vector3(probe.x, underside, probe.z))
	return result


static func _vertical_hit(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var denominator: float = (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(denominator) < AREA_EPSILON:
		return NAN
	var u: float = ((b.z - c.z) * (point.x - c.x) + (c.x - b.x) * (point.z - c.z)) / denominator
	var v: float = ((c.z - a.z) * (point.x - c.x) + (a.x - c.x) * (point.z - c.z)) / denominator
	if u < -POINT_EPSILON or v < -POINT_EPSILON or u + v > 1.0 + POINT_EPSILON:
		return NAN
	return u * a.y + v * b.y + (1.0 - u - v) * c.y
