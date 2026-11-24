extends SceneTree
const WORLD = preload("res://scripts/games/kart_world.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var totals: Array[int] = []
	for low in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.has_meta("sonnenhafen_lookouts"))
		var locations: Array = world.get_meta("sonnenhafen_lookouts")
		assert(locations.size() == 3)
		var parts: int = int(world.get_meta("sonnenhafen_lookout_parts"))
		assert(parts > 55)
		for point in locations:
			assert(not world._near_road(point, 12.0))
			assert(is_finite(point.x) and is_finite(point.y) and is_finite(point.z))
		totals.append(parts)
		world.queue_free()
		await process_frame
	assert(totals[0] > totals[1]) # low-detail LOD removes small geometry.
	var other = WORLD.new()
	root.add_child(other)
	other.build(true, "zauberwald", true)
	assert(not other.has_meta("sonnenhafen_lookouts"))
	other.queue_free()
	await process_frame
	print("[SonnenhafenLookouts] PASS: 3 new 3D landmarks, clear road, both LOD tiers, track isolation")
	quit(0)
