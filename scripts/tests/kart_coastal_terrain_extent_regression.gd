extends SceneTree
## Meilenstein B2: published 1.85km terrain AND original 1972 route both verified.
## The 17-point original is an immutable test fixture, NOT the active catalog.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")

var _original_1972_points := PackedVector3Array([
	Vector3(0, 1.8, 72), Vector3(42, 2.2, 69), Vector3(77, 3.8, 49),
	Vector3(94, 7.0, 19), Vector3(78, 12.5, -8), Vector3(94, 15.5, -43),
	Vector3(67, 13.0, -78), Vector3(31, 8.0, -91), Vector3(2, 5.5, -70),
	Vector3(-24, 7.0, -86), Vector3(-61, 10.0, -77),
	Vector3(-89, 14.5, -48), Vector3(-84, 18.0, -13),
	Vector3(-55, 19.0, 12), Vector3(-78, 13.0, 43),
	Vector3(-50, 7.5, 70), Vector3(-18, 3.2, 80)
])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(_original_1972_points.size() == 17)
	# The old playable track remains a first-class reproducible geometry
	# fixture even though the new 23-point layout is the experimental catalog.
	var original: Dictionary = TRACKS.definition("sonnenhafen")
	assert(original.points.size() == 23,
		"The current experimental catalog must reference the new route")
	var legacy_definition: Dictionary = original.duplicate(true)
	legacy_definition["points"] = _original_1972_points
	var legacy = WORLD.new()
	legacy.track_id = "sonnenhafen"
	legacy.definition = legacy_definition
	legacy._make_curve()
	assert(legacy.world_extent.is_equal_approx(Vector2(101.0, 91.0)),
		"Original 1972 coastal bounds must remain reproducible")
	var legacy_length: float = legacy.length
	assert(legacy_length > 340.0 and legacy_length < 900.0)
	legacy.free()

	# The published B2 route must expand terrain and keep the preexisting
	# marina IN WATER: the east tidal inlet is an intentional coast carve.
	var published = WORLD.new()
	published.track_id = "sonnenhafen"
	published.definition = original
	published._make_curve()
	assert(published.length > 1800.0 and published.length < 1900.0)
	assert(published.world_extent.x > 300.0)
	assert(published.world_extent.y > 275.0)
	assert(published._ground_height(200.0, 0.0) < -3.8,
		"Marina tidal channel must remain marine, never become inland")
	assert(published._ground_height(200.0, 145.0) > -3.8,
		"Extended coastal inland land must not be replaced by ocean")
	published.free()

	# Deliberately scale the EXACT 17-point original test fixture. This test
	# still proves the historic adaptive mesh works for future long routes.
	var scaled: Dictionary = legacy_definition.duplicate(true)
	var points := PackedVector3Array()
	for point: Vector3 in _original_1972_points:
		points.append(Vector3(point.x * 2.7, point.y, point.z * 2.7))
	scaled["points"] = points
	var extended = WORLD.new()
	extended.track_id = "sonnenhafen"
	extended.definition = scaled
	extended.low_detail = true
	extended._make_curve()
	assert(extended.length > legacy_length * 2.0)
	assert(extended.world_extent.x > 200.0)
	assert(extended.world_extent.y > 200.0)
	assert(extended._ground_height(200.0, 125.0) > -3.8,
		"Scaled original adaptive terrain must still contain real land")
	extended._terrain()
	var land: MeshInstance3D = extended.get_node_or_null("SculptedIslandTerrain")
	assert(is_instance_valid(land))
	assert(land.get_aabb().size.x > 400.0)
	assert(land.get_aabb().size.z > 400.0)
	extended.free()
	print("[KartTerrainExtent] PASS: immutable 17-point 1972 track, approved 23-point route, tidal inlet, adaptive terrain")
	quit(0)
