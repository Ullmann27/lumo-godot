extends SceneTree
## Original contacts/ribs retain their box batches and metadata contracts.
## Dedicated cinema batches are checked by kart_harbor_cinema_regression.gd.
const WORLD = preload("res://scripts/games/kart_world.gd")
const CRANE = preload("res://scripts/games/kart_harbor_crane.gd")
const FINISH = preload("res://scripts/games/kart_harbor_visual_finish.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var counts: Array[int] = []
	for low in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.has_meta("sonnenhafen_crane_site"))
		assert(world.has_meta("sonnenhafen_visual_finish"))
		var stats: Dictionary = world.get_meta("sonnenhafen_visual_finish")
		assert(bool(stats["high_detail"]) == not low)
		assert(int(stats["contacts"]) == 10, "four crane feet + six stack foundations")
		assert(int(stats["seams"]) == 4, "real quay concrete expansion grooves")
		assert(int(stats["ribs"]) == (0 if low else 288),
			"12 pier + 12 ship full-detail containers; 12 ribs each")
		var frame: Transform3D = world.get_meta("sonnenhafen_crane_frame")
		var finish_pos: Vector3 = FINISH._p(frame, -8.2, 0.068, -7.0)
		var expected: Vector3 = CRANE._p(frame, -8.2, 0.068, -7.0)
		assert(finish_pos.distance_to(expected) < 0.0001)
		assert(not world._near_road(finish_pos, CRANE.ROAD_CLEARANCE))
		assert(world._ground_height(finish_pos.x, finish_pos.z) < -2.9)
		counts.append(world.decoration_count)
		world.queue_free()
		await process_frame
	assert(counts[0] > counts[1], "full detail may not cost less than low detail")
	var other = WORLD.new()
	root.add_child(other)
	other.build(true, "zauberwald", true)
	assert(not other.has_meta("sonnenhafen_visual_finish"),
		"other courses must not receive harbor geometry")
	other.queue_free()
	await process_frame
	print("[HarborVisualFinish] PASS: 10 opaque contacts, 4 joints, 288 high-only corrugation ribs, no gameplay changes")
	quit(0)
