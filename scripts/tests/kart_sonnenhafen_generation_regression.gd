extends SceneTree
## Generation-leap scenery stays on Sonnenhafen, keeps the road clear, and
## uses a richer HIGH tier than LOW without touching other tracks.
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parts: Array[int] = []
	for low in [true, false]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.has_meta("sonnenhafen_generation_parts"), "Generation module must run inside World.build")
		var count: int = int(world.get_meta("sonnenhafen_generation_parts"))
		assert(count >= 40, "Generation leap must add substantial scenery, got %d" % count)
		assert(count <= 1400, "Generation scenery must stay inside a mobile-safe MultiMesh budget, got %d" % count)
		var sites: Array = world.get_meta("sonnenhafen_generation_sites")
		assert(sites.size() >= 8, "Town, arcade, palms or sails must actually place")
		for site in sites:
			var at: Vector3 = site["position"]
			assert(at.is_finite())
			if str(site["kind"]) == "bay_sail":
				continue
			var kind := str(site["kind"])
			var radius: float = 6.8 if kind == "villa" else (3.2 if kind == "arcade" else 2.4)
			assert(
				not world._near_road(at, radius + 6.9),
				"Generation mesh must stay off the race road"
			)
		parts.append(count)
		world.queue_free()
		await process_frame
	assert(parts[1] > parts[0] + 15, "HIGH must add visible extra detail over LOW")
	for other in ["zauberwald", "holo_city"]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(true, other, true)
		assert(not world.has_meta("sonnenhafen_generation_parts"), "Generation scenery must not leak into %s" % other)
		world.queue_free()
		await process_frame
	print("[SonnenhafenGeneration] PASS: LOW/HIGH scenery, clear road, other tracks untouched")
	quit(0)
