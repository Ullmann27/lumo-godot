extends RefCounted
## Exact-source visibility diagnostic; no rendered-image or art-approval claim.

const WINTER = preload("res://scripts/games/kart_winter_alpine_world.gd")
const CLEARANCE = preload("res://scripts/tests/kart_winter_clearance_geometry.gd")


class StationParts:
	extends RefCounted
	var low_detail := false
	var pieces: Array[Dictionary] = []

	func _prop(
		kind: String,
		at: Vector3,
		size: Vector3,
		_color: Color,
		basis: Basis = Basis.IDENTITY,
		_glow: bool = false
	) -> void:
		pieces.append({"kind": kind, "transform": Transform3D(basis.scaled_local(size), at)})


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


func prepare(source: Node3D) -> String:
	var observer := ObservedWorld.new()
	source.get_tree().root.add_child(observer)
	observer.process_mode = Node.PROCESS_MODE_DISABLED
	observer.global_transform = source.global_transform
	observer.build(source.low_detail, "winter_sprint")
	var owners := _station_owners(observer)
	if owners.is_empty():
		observer.free()
		return "Station submissions do not match their exact production index ranges"
	var faces_by_kind: Dictionary = {}
	for index in range(observer.pieces.size()):
		var piece: Dictionary = observer.pieces[index]
		var mesh: Mesh = observer._shape(piece.kind)
		if not faces_by_kind.has(piece.kind):
			faces_by_kind[piece.kind] = mesh.get_faces()
		_add(
			piece.kind,
			observer.global_transform * piece.transform,
			mesh.get_aabb(),
			faces_by_kind[piece.kind],
			owners[index]
		)
	for node: Node in observer.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null:
			_add(str(node.name), node.global_transform, node.mesh.get_aabb(), node.mesh.get_faces())
	observer.free()
	var landmark := source.get_node("WinterAlpineLandmark")
	_base = source.to_global(landmark.get_meta("base_station"))
	_summit = source.to_global(landmark.get_meta("summit_station"))
	print("[KartWinterVisibility] actual decoration/mesh occluders=%d" % occluders.size())
	return ""


func _station_owners(observer: ObservedWorld) -> PackedInt32Array:
	var marker := observer.get_node("WinterAlpineLandmark")
	var expected := StationParts.new()
	expected.low_detail = observer.low_detail
	WINTER._station(expected, marker.get_meta("base_station"), false)
	var lower_count := expected.pieces.size()
	WINTER._station(expected, marker.get_meta("summit_station"), true)
	var first := int(marker.get_meta("first_structure"))
	if first < 0 or first + expected.pieces.size() > observer.pieces.size():
		return PackedInt32Array()
	if expected.pieces.size() > int(marker.get_meta("structure_count")):
		return PackedInt32Array()
	var owners := PackedInt32Array()
	owners.resize(observer.pieces.size())
	owners.fill(-1)
	for offset in range(expected.pieces.size()):
		var actual: Dictionary = observer.pieces[first + offset]
		var station: Dictionary = expected.pieces[offset]
		if actual.kind != station.kind or not actual.transform.is_equal_approx(station.transform):
			return PackedInt32Array()
		owners[first + offset] = 0 if offset < lower_count else 1
	for offset in range(expected.pieces.size(), int(marker.get_meta("structure_count"))):
		owners[first + offset] = 2  # The remaining new submission range is the cableway.
	return owners


func _add(
	label: String,
	transform: Transform3D,
	bounds: AABB,
	faces: PackedVector3Array,
	station_owner: int = -1
) -> void:
	occluders.append(
		{
			"label": label,
			"at": transform.origin,
			"inverse": transform.affine_inverse(),
			"bounds": bounds,
			"faces": faces,
			"station_owner": station_owner
		}
	)


func check_race_camera(camera: Camera3D, fraction: float) -> String:
	return _check_target(
		camera,
		_base + Vector3(-4.5, 3.5, 0),
		"production chase camera at %.3f: lower station facade" % fraction,
		0
	)


func check_landmark(camera: Camera3D, source: Node3D) -> String:
	var targets: Array[Vector3] = [
		_base + Vector3(-4.5, 3.5, 0),
		_summit + Vector3(-4.5, 3.5, 0),
		_base + Vector3(0, 8.25, 0),
		_summit + Vector3(0, 8.25, 0)
	]
	var owners: Array[int] = [0, 1, 0, 1]
	var cars = source.get_node("WinterAlpineLandmark/WinterCableCars")
	for transform: Transform3D in cars.cabin_transforms:
		targets.append(cars.to_global(transform.origin - Vector3.UP * 2.6))
		owners.append(-1)
	for sample in range(1, 20):
		var t := float(sample) / 20.0
		for side in [-1.0, 1.0]:
			var at: Vector3 = cars._low.lerp(cars._high, t) - Vector3.UP * sin(t * PI) * 2.2
			targets.append(cars.to_global(at + cars._cross * side * 1.9))
			# Only the actual station can cover its cable entry/exit point.
			owners.append(0 if sample == 1 else 1 if sample == 19 else -1)
	for index in range(targets.size()):
		var issue := _check_target(
			camera, targets[index], "overview target %d" % index, owners[index], index >= 8
		)
		if not issue.is_empty():
			return issue
	return ""


func check_foreign_obstruction(camera: Camera3D) -> String:
	var target := _base + Vector3(-4.5, 3.5, 0)
	var at := target + (camera.global_position - target).normalized() * 5.0
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.1
	var station_parts: Array[Dictionary] = []
	for piece: Dictionary in occluders:
		if piece.station_owner < 0:
			continue
		var transform: Transform3D = piece.inverse.affine_inverse()
		var faces: PackedVector3Array = piece.faces.duplicate()
		for index in range(faces.size()):
			faces[index] = transform * faces[index]
		station_parts.append(
			{
				"kind": piece.label,
				"at": piece.at,
				"bounds": transform * piece.bounds,
				"faces": faces
			}
		)
	var bounds := AABB(at - box.size * 0.5, box.size).grow(1.0)
	if not CLEARANCE.first_overlap(station_parts, bounds).is_empty():
		return "Foreign-box fixture must itself respect the 1 m station clearance"
	# This foreign box has the old accepted kind and lies inside the former
	# 12 m radius, yet belongs to neither exact station submission range.
	_add("box", Transform3D(Basis.IDENTITY, at), box.get_aabb(), box.get_faces())
	var issue := _check_target(camera, target, "foreign-box negative fixture", 0)
	occluders.pop_back()
	if not issue.contains("hidden by box"):
		return "Foreign box was not rejected by the exact station-ownership check: " + issue
	print("[KartWinterVisibility] foreign box rejected with 1 m station clearance")
	return ""


func _check_target(
	camera: Camera3D,
	target: Vector3,
	label: String,
	station_owner: int = -1,
	cable_target: bool = false
) -> String:
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
	if hit.label != "clear":
		var own_station: bool = station_owner >= 0 and hit.station_owner == station_owner
		var own_cable: bool = cable_target and hit.station_owner == 2 and hit.distance <= 1.0
		if not own_station and not own_cable:
			return (
				"%s hidden by %s at %s, %.2f m before target"
				% [label, hit.label, hit.at, hit.distance]
			)
	return ""


func _first_hit(start: Vector3, end: Vector3) -> Dictionary:
	var closest := 1.0
	var result := {"label": "clear", "at": Vector3.ZERO, "distance": 0.0, "station_owner": -1}
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
					"distance": start.distance_to(end) * (1.0 - ratio),
					"station_owner": piece.station_owner
				}
	return result
