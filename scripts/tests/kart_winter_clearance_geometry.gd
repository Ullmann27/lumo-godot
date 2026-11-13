extends RefCounted
## CPU geometry check of the actual submitted decorations, including containment.
## Rendering and the production chase-camera review remain separate gates.

const WINTER = preload("res://scripts/games/kart_winter_alpine_world.gd")
const SWEEP_STEPS := 256


static func inspect(world, landmark: Node3D) -> Dictionary:
	var first := int(landmark.get_meta("first_structure"))
	var last := first + int(landmark.get_meta("structure_count"))
	var assembly := AABB(landmark.get_meta("base_station"), Vector3.ZERO)
	assembly = assembly.expand(landmark.get_meta("summit_station")).grow(16.0)
	var obstacles: Array[Dictionary] = []
	for index in range(world.pieces.size()):
		if index >= first and index < last:
			continue
		var piece: Dictionary = world.pieces[index]
		var mesh: Mesh = world._shape(piece.kind)
		var bounds: AABB = piece.transform * mesh.get_aabb()
		if not bounds.intersects(assembly):
			continue
		var faces := mesh.get_faces()
		for vertex in range(faces.size()):
			faces[vertex] = piece.transform * faces[vertex]
		obstacles.append(
			{"kind": piece.kind, "at": piece.transform.origin, "bounds": bounds, "faces": faces}
		)
	var static_hits: Array[String] = []
	var old_roof_blocked := false
	for index in range(first, last):
		var piece: Dictionary = world.pieces[index]
		var bounds: AABB = piece.transform * world._shape(piece.kind).get_aabb()
		var hit := first_overlap(obstacles, bounds.grow(1.0))
		if not hit.is_empty():
			static_hits.append("%s at %s beside %s" % [piece.kind, piece.transform.origin, hit])
		# This real former station placement was hidden by a roadside snowbank.
		if (
			piece.kind == "roof"
			and piece.transform.origin.distance_to(landmark.get_meta("base_station")) < 10.0
		):
			var former := AABB(bounds.position + Vector3(-17, -16, -46), bounds.size)
			old_roof_blocked = (
				old_roof_blocked or not first_overlap(obstacles, former.grow(1.0)).is_empty()
			)
	var cars = landmark.get_node("WinterCableCars")
	var cabin_hits: Array[String] = []
	var cabin_box: AABB = cars.multimesh.mesh.get_aabb()
	# The sine's second derivative bounds the deviation between each pair of
	# endpoints. This encloses the continuous sweep, not just sampled centres.
	var curve_error := 2.2 * PI * PI / (8.0 * SWEEP_STEPS * SWEEP_STEPS)
	for side in [-1.0, 1.0]:
		for step in range(SWEEP_STEPS):
			var a := WINTER._cable_point(cars._low, cars._high, float(step) / SWEEP_STEPS)
			var b := WINTER._cable_point(cars._low, cars._high, float(step + 1) / SWEEP_STEPS)
			var offset: Vector3 = cars._cross * side * 1.9
			var start_box: AABB = Transform3D(cars._orientation, a + offset) * cabin_box
			var end_box: AABB = Transform3D(cars._orientation, b + offset) * cabin_box
			var hit := first_overlap(obstacles, start_box.merge(end_box).grow(0.75 + curve_error))
			if not hit.is_empty():
				cabin_hits.append("lane %s section %d beside %s" % [side, step, hit])
	return {
		"static_hits": static_hits,
		"cabin_hits": cabin_hits,
		"former_roof_blocked": old_roof_blocked,
		"obstacles": obstacles.size()
	}


static func first_overlap(obstacles: Array[Dictionary], box: AABB) -> String:
	for obstacle: Dictionary in obstacles:
		if not box.intersects(obstacle.bounds):
			continue
		if _surface_in_box(obstacle.faces, box) or _contains_center(obstacle, box.get_center()):
			return "%s at %s" % [obstacle.kind, obstacle.at]
	return ""


static func _surface_in_box(faces: PackedVector3Array, box: AABB) -> bool:
	var center := box.get_center()
	var half := box.size * 0.5
	for index in range(0, faces.size(), 3):
		var a := faces[index] - center
		var b := faces[index + 1] - center
		var c := faces[index + 2] - center
		var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, (b - a).cross(c - a)]
		for edge: Vector3 in [b - a, c - b, a - c]:
			for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
				axes.append(edge.cross(axis))
		var intersects := true
		for axis in axes:
			var radius := half.dot(axis.abs())
			var minimum := minf(minf(a.dot(axis), b.dot(axis)), c.dot(axis))
			var maximum := maxf(maxf(a.dot(axis), b.dot(axis)), c.dot(axis))
			if maximum < -radius or minimum > radius:
				intersects = false
				break
		if intersects:
			return true
	return false


static func _contains_center(obstacle: Dictionary, point: Vector3) -> bool:
	if not obstacle.bounds.has_point(point):
		return false
	var end: Vector3 = obstacle.bounds.end + Vector3(7.13, 11.71, 17.23)
	var faces: PackedVector3Array = obstacle.faces
	var intersections: Array[Vector3] = []
	for index in range(0, faces.size(), 3):
		var hit = Geometry3D.segment_intersects_triangle(
			point, end, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit == null:
			continue
		var duplicate := false
		for existing in intersections:
			if existing.distance_squared_to(hit) < 0.000001:
				duplicate = true
				break
		if not duplicate:
			intersections.append(hit)
	return intersections.size() % 2 == 1
