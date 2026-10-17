extends SceneTree
## The Sonnenhafen container crane: real geometry in both LOD tiers, open water
## far from the road, no physics bodies, a moving trolley only on full detail,
## and no effect on any other track.
const WORLD = preload("res://scripts/games/kart_world.gd")
const CRANE = preload("res://scripts/games/kart_harbor_crane.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var totals: Array[int] = []
	for low in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.has_meta("sonnenhafen_crane_site"))
		var frame: Transform3D = world.get_meta("sonnenhafen_crane_frame")
		var parts: int = int(world.get_meta("sonnenhafen_crane_parts"))
		assert(parts > (150 if not low else 90))
		# Pier, ship and boom stand in open water, well clear of the race.
		for f in [-12.0, 0.0, 15.0, CRANE.BOOM_TIP]:
			for s in [-15.0, 0.0, 15.0]:
				var p: Vector3 = CRANE._p(frame, f, 0.0, s)
				assert(not world._near_road(p, CRANE.ROAD_CLEARANCE))
				assert(world._ground_height(p.x, p.z) < -2.9)
		var trolley = world.get_node_or_null("SonnenhafenCraneTrolley")
		if low:
			assert(trolley == null)
		else:
			assert(trolley != null)
			for node in trolley.find_children("*", "CollisionObject3D", true, false):
				assert(false, "crane trolley must not add collision")
			var start: Vector3 = trolley.position
			for _i in range(90):
				await physics_frame
			var travelled: float = (trolley.position - start).length()
			assert(travelled > 0.05)
			var along: float = (trolley.position - frame.origin).dot(frame.basis.z)
			assert(along >= CRANE.TROLLEY_FROM - 0.01 and along <= CRANE.TROLLEY_TO + 0.01)
		totals.append(parts)
		world.queue_free()
		await process_frame
	assert(totals[0] > totals[1])  # Reduced detail removes small parts.
	var other = WORLD.new()
	root.add_child(other)
	other.build(true, "zauberwald", true)
	assert(not other.has_meta("sonnenhafen_crane_site"))
	assert(other.get_node_or_null("SonnenhafenCraneTrolley") == null)
	other.queue_free()
	await process_frame
	print("[SonnenhafenCrane] PASS: crane parts high=%d low=%d, open water, no collision, moving trolley, track isolation" % [totals[0], totals[1]])
	quit(0)
