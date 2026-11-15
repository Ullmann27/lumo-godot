extends RefCounted
## Seat an affine guidance instance against the unchanged visible floor once.
## Every floor/sole intersection is clipped; overlapping triangles cannot hide
## an uncovered footprint. Distances are measured along the instance's Y axis.

const TARGET_EMBED_M: float = 0.020
const MAX_EMBED_M: float = 0.025
const MAX_GAP_M: float = 0.002
const AREA_EPSILON: float = 1.0e-10
# Allow only Float32 world/local boundary rounding, not a physical floor gap.
const COVERAGE_EPSILON: float = 1.0e-5
const HEIGHT_EPSILON_M: float = 1.0e-6
const BASIS_EPSILON: float = 1.0e-8


static func fit(pose: Transform3D, sole_bounds: Rect2, sole_height: float, floor_faces: PackedVector3Array) -> Dictionary:
	var result: Dictionary = {"passed": false, "pose": pose, "adjustment_m": null,
		"min_embed_m": null, "max_embed_m": null, "coverage": null, "reason": ""}
	if not pose.origin.is_finite() or not pose.basis.x.is_finite() or not pose.basis.y.is_finite() or not pose.basis.z.is_finite():
		return _fail(result, "Non-finite guidance pose")
	var determinant: float = pose.basis.determinant()
	var up_length: float = pose.basis.y.length()
	if not is_finite(determinant) or not is_finite(up_length) or determinant <= BASIS_EPSILON or up_length <= BASIS_EPSILON:
		return _fail(result, "Singular or negative guidance basis")
	if not sole_bounds.position.is_finite() or not sole_bounds.size.is_finite() or not is_finite(sole_height) or sole_bounds.size.x <= 0.0 or sole_bounds.size.y <= 0.0:
		return _fail(result, "Invalid sole rectangle or height")
	var total_area: float = sole_bounds.size.x * sole_bounds.size.y
	if not is_finite(total_area) or total_area <= AREA_EPSILON:
		return _fail(result, "Degenerate sole rectangle")
	if floor_faces.is_empty() or floor_faces.size() % 3 != 0:
		return _fail(result, "Missing or incomplete original floor triangles")
	var inverse_basis: Basis = pose.basis.inverse()
	var left: float = sole_bounds.position.x
	var right: float = sole_bounds.end.x
	var near: float = sole_bounds.position.y
	var far: float = sole_bounds.end.y
	var uncovered: Array[PackedVector2Array] = [PackedVector2Array([
		Vector2(left, near), Vector2(right, near), Vector2(right, far), Vector2(left, far)])]
	var lowest: float = INF
	var highest: float = -INF
	var intersecting_triangles: int = 0
	for offset in range(0, floor_faces.size(), 3):
		var polygon := PackedVector3Array()
		for corner in range(3):
			var world_point: Vector3 = floor_faces[offset + corner]
			if not world_point.is_finite():
				return _fail(result, "Non-finite original floor vertex")
			# Subtract the nearby origin first to reduce Float32 cancellation.
			var local_point: Vector3 = inverse_basis * (world_point - pose.origin)
			if not local_point.is_finite():
				return _fail(result, "Non-finite floor vertex after inverse transform")
			polygon.append(local_point)
		polygon = _clip_rectangle(polygon, left, right, near, far)
		if polygon.size() < 3:
			continue
		var footprint := PackedVector2Array()
		for point in polygon:
			footprint.append(Vector2(point.x, point.z))
		var signed_area: float = _signed_area(footprint)
		if absf(signed_area) <= AREA_EPSILON:
			continue
		if signed_area < 0.0:
			footprint.reverse()
		for point in polygon:
			lowest = minf(lowest, point.y)
			highest = maxf(highest, point.y)
		intersecting_triangles += 1
		# Subtract the union from the rectangle, rather than summing triangle
		# areas: duplicate/overlapping floor faces must never cover a real hole.
		var remaining: Array[PackedVector2Array] = []
		for part in uncovered:
			remaining.append_array(_subtract_convex(part, footprint))
		uncovered = remaining
	var missing_area: float = 0.0
	for part in uncovered:
		missing_area += absf(_signed_area(part))
	var coverage: float = clampf(1.0 - missing_area / total_area, 0.0, 1.0)
	result.coverage = coverage
	result.intersecting_triangles = intersecting_triangles
	if intersecting_triangles == 0 or coverage < 1.0 - COVERAGE_EPSILON:
		return _fail(result, "Original floor does not cover the complete sole")
	# Local floor height minus the sole height is the insertion depth. Move
	# only along the existing Y basis; X/Z projections and coverage stay fixed.
	var adjustment_local: float = highest - sole_height - TARGET_EMBED_M / up_length
	var adjustment_m: float = adjustment_local * up_length
	var minimum_embed: float = (lowest - sole_height - adjustment_local) * up_length
	var maximum_embed: float = (highest - sole_height - adjustment_local) * up_length
	if not is_finite(adjustment_m) or not is_finite(minimum_embed) or not is_finite(maximum_embed):
		return _fail(result, "Non-finite floor-fit result")
	if minimum_embed < -MAX_GAP_M - HEIGHT_EPSILON_M or maximum_embed > MAX_EMBED_M + HEIGHT_EPSILON_M:
		result.candidate_adjustment_m = adjustment_m
		result.candidate_min_embed_m = minimum_embed
		result.candidate_max_embed_m = maximum_embed
		return _fail(result, "Original floor is too uneven for a uniform sole adjustment")
	var adjusted: Transform3D = pose
	adjusted.origin += pose.basis.y * adjustment_local
	if not adjusted.origin.is_finite():
		return _fail(result, "Non-finite adjusted guidance origin")
	result.passed = true
	result.pose = adjusted
	result.adjustment_m = adjustment_m
	result.min_embed_m = minimum_embed
	result.max_embed_m = maximum_embed
	return result


static func _fail(result: Dictionary, reason: String) -> Dictionary:
	result.reason = reason
	return result


static func _clip_rectangle(polygon: PackedVector3Array, left: float, right: float, near: float, far: float) -> PackedVector3Array:
	var clipped: PackedVector3Array = _clip_axis(polygon, 0, left, true)
	clipped = _clip_axis(clipped, 0, right, false)
	clipped = _clip_axis(clipped, 2, near, true)
	return _clip_axis(clipped, 2, far, false)


static func _clip_axis(polygon: PackedVector3Array, axis: int, boundary: float, keep_greater: bool) -> PackedVector3Array:
	var clipped := PackedVector3Array()
	if polygon.is_empty():
		return clipped
	var previous: Vector3 = polygon[polygon.size() - 1]
	var previous_inside: bool = previous[axis] >= boundary if keep_greater else previous[axis] <= boundary
	for current in polygon:
		var current_inside: bool = current[axis] >= boundary if keep_greater else current[axis] <= boundary
		if current_inside != previous_inside:
			var weight: float = (boundary - previous[axis]) / (current[axis] - previous[axis])
			var crossing: Vector3 = previous.lerp(current, clampf(weight, 0.0, 1.0))
			crossing[axis] = boundary
			clipped.append(crossing)
		if current_inside:
			clipped.append(current)
		previous = current
		previous_inside = current_inside
	return clipped


static func _signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area: float = 0.0
	var previous: Vector2 = polygon[polygon.size() - 1]
	for point in polygon:
		twice_area += previous.cross(point)
		previous = point
	return twice_area * 0.5


static func _subtract_convex(subject: PackedVector2Array, clip: PackedVector2Array) -> Array[PackedVector2Array]:
	var outside: Array[PackedVector2Array] = []
	var remainder: PackedVector2Array = subject
	for edge in clip.size():
		if remainder.size() < 3:
			break
		var a: Vector2 = clip[edge]
		var b: Vector2 = clip[(edge + 1) % clip.size()]
		if a == b:
			continue
		var piece: PackedVector2Array = _clip_edge(remainder, a, b, false)
		if absf(_signed_area(piece)) > AREA_EPSILON:
			outside.append(piece)
		remainder = _clip_edge(remainder, a, b, true)
	return outside


static func _clip_edge(polygon: PackedVector2Array, a: Vector2, b: Vector2, keep_left: bool) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	if polygon.is_empty():
		return clipped
	var direction: Vector2 = b - a
	var previous: Vector2 = polygon[polygon.size() - 1]
	var previous_side: float = direction.cross(previous - a)
	var previous_inside: bool = previous_side >= 0.0 if keep_left else previous_side <= 0.0
	for current in polygon:
		var current_side: float = direction.cross(current - a)
		var current_inside: bool = current_side >= 0.0 if keep_left else current_side <= 0.0
		if current_inside != previous_inside:
			var weight: float = previous_side / (previous_side - current_side)
			clipped.append(previous.lerp(current, clampf(weight, 0.0, 1.0)))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_side = current_side
		previous_inside = current_inside
	return clipped
