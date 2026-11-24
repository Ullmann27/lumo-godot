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
		var causeway: Dictionary = world.get_meta("sonnenhafen_crane_causeway")
		assert(is_equal_approx(causeway.marina.x, 110.0), "Terminal must connect to actual marina quay")
		assert(causeway.marina.z >= -29.0 and causeway.marina.z <= 34.0)
		# The long-course replacement pier must clear original boats and buoys,
		# not merely satisfy terrain/road checks. Entire slab lies east of them.
		if frame.origin.x > 140.0:
			for f in [-12.0, 8.0]:
				for side in [-13.0, 13.0]:
					assert(CRANE._p(frame, f, 0.0, side).x > 130.8)
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
			assert(not world.has_meta("sonnenhafen_crane_hoist"))
		else:
			assert(trolley != null)
			var hoist: Node3D = trolley.get_node_or_null("SonnenhafenCraneHoist")
			assert(hoist != null)
			assert(world.get_meta("sonnenhafen_crane_hoist") == hoist.name)
			var ropes: Array[MeshInstance3D] = []
			for i in range(4):
				var rope: MeshInstance3D = trolley.get_node("SonnenhafenCraneCable%d" % i)
				assert(rope != null)
				assert(rope.mesh is BoxMesh)
				ropes.append(rope)
			for node in trolley.find_children("*", "CollisionObject3D", true, false):
				assert(false, "crane trolley and hoist must not add collision")
			var original_rope: MeshInstance3D = ropes[0]
			var original_mesh: BoxMesh = original_rope.mesh
			var rope_anchor: float = original_rope.position.y + original_mesh.size.y * original_rope.scale.y * 0.5
			var start: Vector3 = trolley.position
			for _i in range(90):
				await physics_frame
			var travelled: float = (trolley.position - start).length()
			assert(travelled > 0.05)
			var along: float = (trolley.position - frame.origin).dot(frame.basis.z)
			assert(along >= CRANE.TROLLEY_FROM - 0.01 and along <= CRANE.TROLLEY_TO + 0.01)
			assert(hoist.position.y < -0.1, "high-detail container must move vertically")
			for rope in ropes:
				assert(rope.scale.y > 1.0, "ropes must lengthen with the lowering container")
				var cable_mesh: BoxMesh = rope.mesh
				var anchor: float = rope.position.y + cable_mesh.size.y * rope.scale.y * 0.5
				assert(absf(anchor - rope_anchor) < 0.01, "rope upper attachments must not drift")
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
	print("[SonnenhafenCrane] PASS: crane parts high=%d low=%d, open water, no collision, moving trolley and hoist, anchored ropes, track isolation" % [totals[0], totals[1]])
	quit(0)
