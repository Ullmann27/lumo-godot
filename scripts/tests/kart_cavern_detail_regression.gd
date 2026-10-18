extends SceneTree
## Real high/mobile factory meshes and lane clearance inside both race LODs.
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for low in [true, false]:
		var world: LumoRaceWorld = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", false)
		var detail: Node3D = world.get_node_or_null(
			"SonnenhafenBioluminescentDarkride/CavernGeology"
		)
		assert(detail != null, "Cave needs real irregular geology and factory crystals")
		var data: Dictionary = detail.get_meta("production_metrics")
		assert(data.draw_batches <= 5, "Android cavern draw budget exceeded")
		assert(data.crystal_triangles == (144 if low else 324))
		assert(data.crystal_clusters >= 18 and data.rock_instances >= 40)
		assert(data.low_detail == low)
		assert(data.min_shoulder_lateral_m >= 5.6, "Scenery intrudes into racing corridor")
		assert(data.minimum_stalactite_tip_m >= 5.8, "Roof decoration loses safe clearance")
		# Check the real transformed mesh bounds, not just the stated budget.
		for name in ["StratifiedBoulders", "FactoryCrystalGardens", "MineralWaterChannels"]:
			var node: MultiMeshInstance3D = detail.get_node(name)
			var bounds: AABB = node.multimesh.mesh.get_aabb()
			for i in range(node.multimesh.instance_count):
				var transform: Transform3D = node.multimesh.get_instance_transform(i)
				var road: Dictionary = world.sample_road(transform.origin)
				var frame: Basis = world.frame(float(road.distance))
				var center: Vector3 = world.position_at(float(road.distance))
				for corner in range(8):
					var point: Vector3 = transform * bounds.get_endpoint(corner)
					assert(
						absf((point - center).dot(frame.x)) >= 5.6,
						"Actual mesh bounds cross the shoulder: " + name
					)
		var stack: Array[Node] = [detail]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			assert(not n is CollisionObject3D, "Art must preserve existing driving physics")
			for child in n.get_children():
				stack.append(child)
		for fraction in [0.701, 0.735, 0.77, 0.792]:
			for lateral in [-4.8, 0.0, 4.8]:
				var d: float = world.length * fraction
				assert(world.sample_road(world.position_at(d, lateral), d).on_road)
		world.queue_free()
		await process_frame
	print(
		"[CavernProduction] PASS: imported high/mobile clusters, five draw batches, clear lane, unchanged physics"
	)
	quit(0)
