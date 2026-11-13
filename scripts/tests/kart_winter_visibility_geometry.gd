extends RefCounted
## Exact-source visibility diagnostic; no rendered-image or art-approval claim.


class ObservedWorld:
	extends "res://scripts/games/kart_world.gd"
	var pieces: Array[Dictionary] = []

	func _prop(
		kind: String,
		at: Vector3,
		size: Vector3,
		color: Color,
		basis: Basis = Basis.IDENTITY,
		glow: bool = false
	) -> void:
		pieces.append({"kind": kind, "transform": Transform3D(basis.scaled_local(size), at)})
		super._prop(kind, at, size, color, basis, glow)


var occluders: Array[Dictionary] = []
var checks := 0
var _base := Vector3.ZERO
var _summit := Vector3.ZERO


func prepare(source: Node3D) -> void:
	var observer := ObservedWorld.new()
	source.get_tree().root.add_child(observer)
	observer.process_mode = Node.PROCESS_MODE_DISABLED
	observer.global_transform = source.global_transform
	observer.build(source.low_detail, "winter_sprint")
	var faces_by_kind: Dictionary = {}
	for piece: Dictionary in observer.pieces:
		var mesh: Mesh = observer._shape(piece.kind)
		if not faces_by_kind.has(piece.kind):
			faces_by_kind[piece.kind] = mesh.get_faces()
		_add(
			piece.kind,
			observer.global_transform * piece.transform,
			mesh.get_aabb(),
			faces_by_kind[piece.kind]
		)
	for node: Node in observer.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null:
			_add(str(node.name), node.global_transform, node.mesh.get_aabb(), node.mesh.get_faces())
	observer.free()
	var landmark := source.get_node("WinterAlpineLandmark")
	_base = source.to_global(landmark.get_meta("base_station"))
	_summit = source.to_global(landmark.get_meta("summit_station"))
	print("[KartWinterVisibility] actual decoration/mesh occluders=%d" % occluders.size())


func _add(label: String, transform: Transform3D, bounds: AABB, faces: PackedVector3Array) -> void:
	occluders.append(
		{
			"label": label,
			"at": transform.origin,
			"inverse": transform.affine_inverse(),
			"bounds": bounds,
			"faces": faces
		}
	)


func check_race_camera(camera: Camera3D, fraction: float) -> String:
	return _check_target(
		camera,
		_base + Vector3(-4.5, 3.5, 0),
		"production chase camera at %.3f: lower station facade" % fraction
	)


func check_landmark(camera: Camera3D, source: Node3D) -> String:
	var targets: Array[Vector3] = [
		_base + Vector3(-4.5, 3.5, 0),
		_summit + Vector3(-4.5, 3.5, 0),
		_base + Vector3(0, 8.25, 0),
		_summit + Vector3(0, 8.25, 0)
	]
	var cars = source.get_node("WinterAlpineLandmark/WinterCableCars")
	for transform: Transform3D in cars.cabin_transforms:
		targets.append(cars.to_global(transform.origin - Vector3.UP * 2.6))
	for sample in range(1, 20):
		var t := float(sample) / 20.0
		for side in [-1.0, 1.0]:
			var at: Vector3 = cars._low.lerp(cars._high, t) - Vector3.UP * sin(t * PI) * 2.2
			targets.append(cars.to_global(at + cars._cross * side * 1.9))
	for index in range(targets.size()):
		var issue := _check_target(camera, targets[index], "overview target %d" % index)
		if not issue.is_empty():
			return issue
	return ""


func _check_target(camera: Camera3D, target: Vector3, label: String) -> String:
	checks += 1
	var local := camera.global_transform.affine_inverse() * target
	if local.z >= -0.1:
		return label + " is behind the camera"
	var pixel := (
		Vector2(640, 360)
		+ Vector2(local.x, -local.y) / -local.z * (360.0 / tan(deg_to_rad(camera.fov) * 0.5))
	)
	if not Rect2(220, 145, 765, 430).has_point(pixel):
		return label + " leaves the free 1280x720 HUD area at " + str(pixel)
	var hit := _first_hit(camera.global_position, target)
	if hit.distance > 1.0:
		var own_station := false
		for station in [_base, _summit]:
			if (
				hit.at.distance_to(station) < 12.0
				and target.distance_to(station) < 13.0
				and hit.label in ["box", "roof", "star", "cylinder", "ball"]
			):
				own_station = true
		if not own_station:
			return (
				"%s hidden by %s at %s, %.2f m before target"
				% [label, hit.label, hit.at, hit.distance]
			)
	return ""


func _first_hit(start: Vector3, end: Vector3) -> Dictionary:
	var closest := 1.0
	var result := {"label": "clear", "at": Vector3.ZERO, "distance": 0.0}
	for piece: Dictionary in occluders:
		var from: Vector3 = piece.inverse * start
		var to: Vector3 = piece.inverse * end
		if piece.bounds.intersects_segment(from, to) == null:
			continue
		var vertices: PackedVector3Array = piece.faces
		for index in range(0, vertices.size(), 3):
			var hit = Geometry3D.segment_intersects_triangle(
				from, to, vertices[index], vertices[index + 1], vertices[index + 2]
			)
			if hit == null:
				continue
			var ratio: float = from.distance_to(hit) / from.distance_to(to)
			if ratio < closest:
				closest = ratio
				result = {
					"label": piece.label,
					"at": piece.at,
					"distance": start.distance_to(end) * (1.0 - ratio)
				}
	return result
