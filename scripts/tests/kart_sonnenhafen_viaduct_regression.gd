extends SceneTree
## Genuine Sonnenhafen viaduct geometry: placement, QA, LOD and other-track isolation.
## Existing racing geometry, physics, checkpoint positions and save format untouched.
const WORLD = preload("res://scripts/games/kart_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var totals: Array[int] = []
	var route_length: float = -1.0
	for low in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.has_meta("sonnenhafen_viaduct_sites"),
			"Sonnenhafen must expose real 3D viaduct placements")
		var sites: Array = world.get_meta("sonnenhafen_viaduct_sites")
		assert(sites.size() == 2, "Exactly two coastal viaduct setpieces")
		var count: int = int(world.get_meta("sonnenhafen_viaduct_parts"))
		assert(count >= 100 if not low else count >= 70,
			"Instanced geometry is missing")
		assert(world.checkpoint_positions.size() == 8)
		if route_length < 0.0:
			route_length = world.length
		else:
			assert(is_equal_approx(world.length, route_length),
				"LOD must never change race geometry")
		for site in sites:
			var feet: Array = site["feet"]
			var anchors: Array = site["anchors"]
			assert(feet.size() == 7 and anchors.size() == 7)
			for i in range(feet.size()):
				var foot: Vector3 = feet[i]
				var crown: Vector3 = anchors[i]
				assert(not world._near_road(foot, 9.2),
					"Actual viaduct pillar could obstruct racing clearance")
				assert(is_finite(foot.x) and is_finite(foot.y) and is_finite(foot.z))
				assert(crown.y > foot.y + 7.0)
			var start: float = float(site["fraction"]) * world.length
			for offset in [-16.0, 0.0, 16.0]:
				var d: float = start + offset
				for lateral in [-4.0, 0.0, 4.0]:
					var p: Vector3 = world.position_at(d, lateral)
					var sampled: Dictionary = world.sample_road(p, d)
					assert(sampled.on_road)
					assert(absf(float(sampled.lateral) - lateral) < 0.12)
		totals.append(count)
		world.queue_free()
		await process_frame
	assert(totals[0] > totals[1], "High LOD must show more actual 3D than mobile low")
	assert(totals[0] < 260, "Viaduct detail must remain under mobile batch budget")

	for other_id in ["zauberwald", "bergwelt", "holo_city"]:
		var other = WORLD.new()
		root.add_child(other)
		other.build(true, other_id, true)
		assert(not other.has_meta("sonnenhafen_viaduct_sites"),
			"Coastal viaduct must never leak into other worlds")
		other.queue_free()
		await process_frame
	print("[CoastalViaduct] PASS: two real 3D landmarks, 14 clear piers, 2 LODs, unchanged road, track isolation")
	quit(0)
