extends SceneTree
## Independent coordinate audit against the immutable Lumo 1971 Godot source.
## QA only: does not change physics, track geometry, reward state or Android pins.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var verified: int = 0
	for track_id in TRACKS.IDS:
		var world = WORLD.new()
		world.track_id = track_id
		world.definition = TRACKS.definition(track_id)
		world._make_curve()
		assert(world.length > 340.0, "Track length contracted: " + track_id)
		assert(world.curve.get_point_count() >= 4, "Insufficient curve control points")
		# The original file ALREADY uses (-tangent, +tangent).
		# This protects against reintroducing Argon's mistaken D1 premise.
		for index in range(world.curve.get_point_count()):
			var control_in: Vector3 = world.curve.get_point_in(index)
			var control_out: Vector3 = world.curve.get_point_out(index)
			assert((control_in + control_out).length() < 0.0001,
				"Broken signed Bezier control handles on " + track_id)
		for sample_index in range(64):
			var d: float = world.length * float(sample_index) / 64.0
			var basis: Basis = world.frame(d)
			var determinant: float = basis.determinant()
			assert(is_finite(determinant) and absf(determinant - 1.0) < 0.0001,
				"Non-right-handed road frame on " + track_id)
			assert((-basis.z).dot(world.forward(d)) > 0.999,
				"Forward direction must remain -basis.z on " + track_id)
			for offset in [-4.0, 0.0, 4.0]:
				var target: Vector3 = world.position_at(d, offset)
				var result: Dictionary = world.sample_road(target, d)
				assert(result.on_road, "Road projection falsely rejected a valid lane")
				assert(absf(float(result.lateral) - offset) < 0.12,
					"Road projection lateral drift on " + track_id)
				assert(absf(float(result.height) - target.y) < 0.08,
					"Road projection height drift on " + track_id)
		verified += 1
		world.free()
	assert(verified == 12, "Expected four core and eight expansion tracks")

	# Real loop functions also ALREADY use -basis.z and a positive determinant.
	var world = WORLD.new()
	world.track_id = "sonnenhafen"
	world.definition = TRACKS.definition("sonnenhafen")
	world._make_curve()
	var data: Dictionary = {"start": world.length * 0.72, "lane": 2.9}
	for u in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
		var basis: Basis = LOOP.frame_at(world, data, u)
		assert(is_finite(basis.determinant()))
		assert(absf(basis.determinant() - 1.0) < 0.0001,
			"Looping basis must be a proper rotation")
		var a: float = maxf(0.0, u - 0.001)
		var b: float = minf(1.0, u + 0.001)
		var tangent: Vector3 = (LOOP.point(world, data, b) - LOOP.point(world, data, a)).normalized()
		assert((-basis.z).dot(tangent) > 0.999,
			"Looping -Z must point forward")
	assert(LOOP.frame_at(world, data, 0.5).y.y < -0.90,
		"Loop roof must invert the local up axis")
	world.free()

	# Known gap not falsely labelled fixed: sample_road() still searches in X/Z.
	# An elevated crossing needs a separate test-first 3D-projection patch.
	print("[ArgonCoordinateAudit] PASS: %d tracks, signed Bezier handles, right-handed frames, loop axes; elevated crossing remains a documented gap" % verified)
	quit(0)
