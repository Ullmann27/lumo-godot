extends SceneTree
## Inspect the actual production world, every new triangle, and the complete road.

const WORLD = preload("res://scripts/games/kart_world.gd")
const WINTER = preload("res://scripts/games/kart_winter_alpine_world.gd")
const CANYON = preload("res://scripts/games/kart_crystal_resonance_world.gd")
const IDS: Array[String] = ["winter_sprint", "crystal_canyon"]
const ROAD_MARGIN := Vector3(8.5, 6.0, 8.5)


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


class RaceHost:
	extends Node3D
	var paused := false
	var reduced_motion := false


var checks := 0
var failures := 0
var triangles_checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var selected := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			selected = argument.trim_prefix("--track=")
		else:
			push_error("Unknown argument: " + argument)
			quit(2)
			return
	if selected != "all" and selected not in IDS:
		push_error("Unknown expansion track: " + selected)
		quit(2)
		return
	for track in IDS:
		if selected != "all" and selected != track:
			continue
		for low in [true, false]:
			await _check_world(track, low)
	var untouched := WORLD.new()
	untouched.track_id = "sonnenhafen"
	WINTER.build(untouched)
	CANYON.build(untouched)
	_check(
		untouched.decoration_count == 0 and untouched.get_child_count() == 0,
		"unrelated world receives no alpine geometry"
	)
	untouched.free()
	print(
		(
			"[KartWorldExpansion] %s checks=%d triangles=%d failures=%d"
			% ["PASS" if failures == 0 else "FAIL", checks, triangles_checked, failures]
		)
	)
	quit(0 if failures == 0 else 1)


func _check_world(track: String, low: bool) -> void:
	var host := RaceHost.new()
	root.add_child(host)
	var world := ObservedWorld.new()
	host.add_child(world)
	world.build(low, track)
	var label := "%s/%s" % [track, "low" if low else "full"]
	var marker_name := (
		"WinterAlpineLandmark" if track == "winter_sprint" else "CrystalResonanceLandmark"
	)
	var landmark := world.get_node_or_null(marker_name)
	_check(landmark != null, label + ": production call creates connected alpine landmark")
	if landmark == null:
		host.free()
		return
	var start := int(landmark.get_meta("first_piece", -1))
	var count := int(landmark.get_meta("piece_count", 0))
	_check(
		count >= (160 if track == "winter_sprint" else 70) and count <= 400,
		label + ": bounded substantial geometry"
	)
	if track == "winter_sprint":
		_check(int(landmark.get_meta("gallery_count", 0)) >= 3, label + ": connected ice gallery")
		_check(
			int(landmark.get_meta("peak_count", 0)) == (6 if low else 9), label + ": ridge layers"
		)
	else:
		_check(int(landmark.get_meta("wall_count", 0)) >= 6, label + ": connected gorge walls")
		_check(int(landmark.get_meta("overlook_count", 0)) >= 2, label + ": open crystal reveal")
	_check(start >= 0 and start + count <= world.pieces.size(), label + ": actual piece range")
	_check(world.groups.is_empty(), label + ": parts submitted to production renderer batches")
	var road: PackedVector3Array = world.curve.get_baked_points()
	if track == "winter_sprint":
		_check(landmark.get_child_count() == 1, label + ": one shared moving-cabin batch")
		_check_cable_cars(landmark.get_node_or_null("WinterCableCars"), host, road, label)
	else:
		_check(landmark.get_child_count() == 0, label + ": no per-piece render nodes or lights")
	var geometry_clear := true
	var overlapping_parts := 0
	if start >= 0 and start + count <= world.pieces.size():
		for index in range(start, start + count):
			var piece: Dictionary = world.pieces[index]
			var mesh: Mesh = world._shape(piece.kind)
			var transform: Transform3D = piece.transform
			var bounds := transform * mesh.get_aabb()
			var candidates := _road_candidates(bounds, road)
			if candidates.is_empty():
				continue
			if not _triangles_clear(mesh, transform, road, candidates):
				geometry_clear = false
				overlapping_parts += 1
				if overlapping_parts < 5:
					push_error(
						(
							label
							+ (
								": road intrusion piece=%d kind=%s position=%s"
								% [index - start, piece.kind, str(transform.origin)]
							)
						)
					)
	_check(geometry_clear, label + ": all new mesh triangles clear every road segment")
	_check(world.jump.size() > 0 and world.length > 400, label + ": existing road and jump remain")
	var before_rebuild := world.get_child_count()
	world.pieces.clear()
	world.build(low, track)
	await process_frame
	_check(
		world.get_child_count() == before_rebuild,
		label + ": scene rebuild replaces geometry without growing node count"
	)
	world.build(true, "learning_lab")
	await process_frame
	_check(
		world.get_node_or_null(marker_name) == null,
		label + ": changing track removes the alpine set"
	)
	host.queue_free()
	await process_frame
	print("[KartWorldExpansion] %s pieces=%d road_segments=%d" % [label, count, road.size() - 1])


func _check_cable_cars(cars, host: RaceHost, road: PackedVector3Array, label: String) -> void:
	_check(cars is MultiMeshInstance3D, label + ": actual instanced cabin renderer")
	if not cars is MultiMeshInstance3D:
		return
	_check(
		cars.multimesh.instance_count == 4 and cars.multimesh.mesh.get_surface_count() == 1,
		label + ": four cabins share one surface"
	)
	var start: Transform3D = cars.cabin_transforms[0]
	var other_start: Transform3D = cars.cabin_transforms[2]
	cars._process(1.0)
	var moved: Transform3D = cars.cabin_transforms[0]
	var other_moved: Transform3D = cars.cabin_transforms[2]
	var delta_a := moved.origin - start.origin
	var delta_b := other_moved.origin - other_start.origin
	_check(
		delta_a.length() > 2.0 and delta_a.dot(delta_b) < 0.0,
		label + ": visible continuous counter-moving cable traffic"
	)
	_check(moved.basis.y.is_equal_approx(Vector3.UP), label + ": cabins stay upright on the slope")
	host.paused = true
	cars._process(1.0)
	_check(
		cars.cabin_transforms[0].is_equal_approx(moved), label + ": race pause freezes the cableway"
	)
	host.paused = false
	host.reduced_motion = true
	cars._process(1.0)
	_check(
		cars.cabin_transforms[0].is_equal_approx(moved),
		label + ": reduced-motion preference freezes the cableway"
	)
	host.reduced_motion = false
	cars.hide()
	cars._process(1.0)
	_check(
		cars.cabin_transforms[0].is_equal_approx(moved),
		label + ": hidden cableway performs no animation updates"
	)
	cars.show()
	var maximum_road_x := -INF
	for point in road:
		maximum_road_x = maxf(maximum_road_x, point.x)
	var clear := true
	var uploaded := true
	for frame in range(120):
		cars._process(0.5)
		for index in range(4):
			var transform: Transform3D = cars.cabin_transforms[index]
			var bounds: AABB = transform * cars.multimesh.mesh.get_aabb()
			clear = clear and bounds.position.x > maximum_road_x + ROAD_MARGIN.x
			if DisplayServer.get_name() != "headless":
				uploaded = (
					uploaded
					and cars.multimesh.get_instance_transform(index).is_equal_approx(transform)
				)
	_check(clear, label + ": complete moving cabin bounds remain beyond every road segment")
	if DisplayServer.get_name() != "headless":
		_check(uploaded, label + ": real renderer readback matches all 480 animated cabin uploads")
	else:
		print("[KartWorldExpansion] CPU cabin-upload state checked; renderer readback requires X11")


func _road_candidates(bounds: AABB, road: PackedVector3Array) -> PackedInt32Array:
	# Full 17 m corridor and 6 m overhead clearance: road, rails, kart and camera.
	var expanded := AABB(
		bounds.position - ROAD_MARGIN,
		bounds.size + Vector3(ROAD_MARGIN.x * 2.0, ROAD_MARGIN.y, ROAD_MARGIN.z * 2.0)
	)
	var candidates := PackedInt32Array()
	for index in range(road.size() - 1):
		if expanded.intersects_segment(road[index], road[index + 1]) != null:
			candidates.append(index)
	return candidates


func _triangles_clear(
	mesh: Mesh, transform: Transform3D, road: PackedVector3Array, candidates: PackedInt32Array
) -> bool:
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var count := vertices.size() if indices.is_empty() else indices.size()
		for triangle in range(0, count - 2, 3):
			var a: Vector3 = (
				transform * vertices[triangle if indices.is_empty() else indices[triangle]]
			)
			var b: Vector3 = (
				transform * vertices[triangle + 1 if indices.is_empty() else indices[triangle + 1]]
			)
			var c: Vector3 = (
				transform * vertices[triangle + 2 if indices.is_empty() else indices[triangle + 2]]
			)
			var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c).grow(0.001)
			var expanded := AABB(
				bounds.position - ROAD_MARGIN,
				bounds.size + Vector3(ROAD_MARGIN.x * 2.0, ROAD_MARGIN.y, ROAD_MARGIN.z * 2.0)
			)
			triangles_checked += 1
			for index in candidates:
				if expanded.intersects_segment(road[index], road[index + 1]) != null:
					return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[KartWorldExpansion] " + message)
