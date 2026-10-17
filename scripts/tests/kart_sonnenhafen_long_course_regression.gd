extends SceneTree
## Experimental B2: genuinely long Sonnenhafen curve and unchanged game contracts.
## The source remains unpinned to Flutter/Android until real scene+race tests pass.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const ROUTE = preload("res://scripts/games/kart_sonnenhafen_long_course.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.track_id = "sonnenhafen"
	world.definition = TRACKS.definition("sonnenhafen")
	assert(world.definition.points.size() == 23,
		"New course needs 23 individually authored control points")
	assert(world.definition.points == ROUTE.points(),
		"Race catalog must point at tested experimental route")
	world._make_curve()
	assert(world.length >= 1800.0 and world.length <= 1900.0,
		"Course must be a measured ~1.85 km, not a globally scaled illusion")
	assert(world.checkpoint_positions.size() == 8)
	assert(world.position_at(0).distance_to(world.position_at(world.length)) < 0.001)
	var radius_min: float = INF
	var worst_grade: float = 0.0
	for i in range(700):
		var d: float = float(i) * world.length / 700.0
		var next: float = d + 2.0
		var bend: float = world.forward(d).angle_to(world.forward(next))
		if bend > 0.001:
			radius_min = minf(radius_min, 2.0 / bend)
		var a: Vector3 = world.position_at(d)
		var b: Vector3 = world.position_at(next)
		var horizontal: float = Vector2(a.x - b.x, a.z - b.z).length()
		assert(horizontal > 0.01)
		worst_grade = maxf(worst_grade, absf(b.y - a.y) / horizontal)
		for lateral in [-4.0, 0.0, 4.0]:
			var at: Vector3 = world.position_at(d, lateral)
			var probe: Dictionary = world.sample_road(at, d)
			assert(probe.on_road and absf(float(probe.lateral) - lateral) < 0.13)
			assert(absf(float(probe.height) - at.y) < 0.09)
			assert(absf((probe.basis as Basis).determinant() - 1.0) < 0.0001)
	assert(radius_min >= 18.0, "Route contains a curve radius too tight for the original rail contract")
	assert(worst_grade <= 0.09, "Course grade exceeds 9% and will destabilize physics")
	var clearance: float = INF
	for i in range(125):
		for j in range(i + 1, 125):
			var separation: float = minf(float(j - i), float(125 - j + i)) * world.length / 125.0
			if separation < 25.0:
				continue
			var a: Vector3 = world.position_at(float(i) * world.length / 125.0)
			var b: Vector3 = world.position_at(float(j) * world.length / 125.0)
			clearance = minf(clearance, Vector2(a.x - b.x, a.z - b.z).length())
	assert(clearance > world.WIDTH + 2.0, "Unintended road self-intersection")
	print("[SonnenhafenLong] checked curve %.2fm, radius %.2fm, grade %.3f, clearance %.2fm" %
		[world.length, radius_min, worst_grade, clearance])
	world.queue_free()
	await process_frame

	# The actual production world must import geometry, coastal dressing,
	# harbor crane/boats and both level-of-detail tiers on this full-length track.
	for low in [true, false]:
		var scene = WORLD.new()
		root.add_child(scene)
		scene.build(low, "sonnenhafen", true)
		assert(scene.length >= 1800.0)
		assert(scene.checkpoint_positions.size() == 8)
		assert(scene.has_meta("sonnenhafen_viaduct_sites"))
		assert(scene.has_meta("harbor_boats"))
		assert(scene.has_meta("sonnenhafen_lookouts"))
		print("[SonnenhafenLong] full 3D world LOD low=%s decorations=%d" % [
			str(low), scene.decoration_count
		])
		scene.queue_free()
		await process_frame
	print("[SonnenhafenLong] PASS: real 1.85km curve and both full 3D scene LODs")
	quit(0)
