extends SceneTree
## Future-proof coastal world extents without moving legacy racing splines.
## Also exercises the actual adaptive terrain mesh on a synthetic long route.
const WORLD = preload("res://scripts/games/kart_world.gd")
const TRACKS = preload("res://scripts/games/kart_tracks.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original: Dictionary = TRACKS.definition("sonnenhafen")
	var legacy = WORLD.new()
	legacy.track_id = "sonnenhafen"
	legacy.definition = original
	legacy._make_curve()
	assert(legacy.world_extent.is_equal_approx(Vector2(101.0, 91.0)))
	assert(original.points.size() == 17, "Existing coastal control points must remain intact")
	var original_length: float = legacy.length
	legacy.free()

	# Deliberately move points beyond the original terrain: this is not a
	# production track and does not modify the published menu/catalogue.
	var scaled: Dictionary = original.duplicate(true)
	var points := PackedVector3Array()
	for point: Vector3 in original.points:
		points.append(Vector3(point.x * 2.7, point.y, point.z * 2.7))
	scaled["points"] = points
	var extended = WORLD.new()
	extended.track_id = "sonnenhafen"
	extended.definition = scaled
	extended.low_detail = true
	extended._make_curve()
	assert(extended.length > original_length * 2.0)
	assert(extended.world_extent.x > 200.0)
	assert(extended.world_extent.y > 200.0)
	assert(extended._ground_height(200.0, 0.0) > -3.8)
	extended._terrain()
	var land: MeshInstance3D = extended.get_node_or_null("SculptedIslandTerrain")
	assert(is_instance_valid(land))
	assert(land.get_aabb().size.x > 400.0)
	assert(land.get_aabb().size.z > 400.0)
	extended.free()
	print("[KartTerrainExtent] PASS: legacy bounds preserved, future long-course terrain grows")
	quit(0)
