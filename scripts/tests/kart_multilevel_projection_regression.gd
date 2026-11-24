extends SceneTree
## Real Godot Curve3D fixture with two projected crossings at the same X/Z
## but on separate decks (Y=2m and Y=16m). No gameplay or user saves.
const WORLD = preload("res://scripts/games/kart_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = WORLD.new()
	var path := Curve3D.new()
	path.bake_interval = 0.25
	# Both diagonal segments cross X=0, Z=0 at their midpoints.
	# Lower leg goes NE; upper leg goes SW, with 14 metres separation.
	for p in [
		Vector3(-85, 2, -36),
		Vector3(85, 2, 36),
		Vector3(100, 6, 70),
		Vector3(80, 16, 90),
		Vector3(-80, 16, -90),
		Vector3(-100, 10, -90),
		Vector3(-85, 2, -36),
	]:
		path.add_point(p)
	world.curve = path
	world.length = path.get_baked_length()
	world._road_samples.clear()
	world._road_distances.clear()
	var count: int = ceili(world.length / 5.0)
	for i in range(count):
		var d: float = float(i) * world.length / float(count)
		world._road_samples.append(path.sample_baked(d, true))
		world._road_distances.append(d)

	var lower: Dictionary = world.sample_road(Vector3(0, 2, 0))
	var upper: Dictionary = world.sample_road(Vector3(0, 16, 0))
	assert(lower.on_road, "Lower deck must remain driveable")
	assert(upper.on_road, "Upper deck must remain driveable")
	assert(absf(float(lower.height) - 2.0) < 0.8,
		"Lower deck incorrectly snapped onto the bridge")
	assert(absf(float(upper.height) - 16.0) < 0.8,
		"Upper bridge incorrectly snapped onto the road below")
	assert(absf(float(upper.height) - float(lower.height)) > 12.0,
		"Multi-level roads collapsed onto the same Y height")
	assert(absf(float(lower.lateral)) < 0.9 and absf(float(upper.lateral)) < 0.9)
	var low_basis: Basis = lower.basis
	var high_basis: Basis = upper.basis
	assert(absf(low_basis.determinant() - 1.0) < 0.001)
	assert(absf(high_basis.determinant() - 1.0) < 0.001)
	print("[MultilevelProjection] PASS: two independent intersecting road decks with 14m clearance")
	world.free()
	quit(0)
