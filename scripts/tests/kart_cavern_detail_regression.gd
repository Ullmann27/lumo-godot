extends SceneTree
## Imported high/mobile minerals and actual lane/roof bounds inside both race LODs.
const WORLD = preload("res://scripts/games/kart_world.gd")
const GEOLOGY = preload("res://scripts/games/kart_cavern_geology.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless",
		"Actual MultiMesh uploads require a renderer; run with DISPLAY=:96 and --rendering-method gl_compatibility")
	for low in [true, false]:
		var world: LumoRaceWorld = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", false)
		var detail: Node3D = world.get_node_or_null(
			"SonnenhafenBioluminescentDarkride/CavernGeology"
		)
		assert(detail != null, "Cave needs real irregular geology and factory crystals")
		var data: Dictionary = detail.get_meta("production_metrics")
		print("[CavernProduction] " + JSON.stringify(data))
		assert(data.draw_batches == 7, "Cavern kit must remain seven actual material batches")
		assert(data.crystal_triangles == (286 if low else 966))
		assert(data.crystal_clusters >= 18 and data.rock_instances >= 40)
		assert(data.low_detail == low)
		assert(data.asset_variants == 6, "Tactile cavern needs genuinely different silhouettes")
		assert(data.instanced_triangles <= (24000 if low else 120000))
		assert(data.placement_seed == 261018)
		assert(data.min_shoulder_lateral_m >= 5.6, "Scenery intrudes into racing corridor")
		assert(data.minimum_stalactite_tip_m >= 5.8, "Roof decoration loses safe clearance")
		# Check the real transformed mesh bounds, not just the stated budget.
		for name in ["StratifiedBoulders", "MineralSplitLedges", "FactoryCrystalGardens",
				"CrystalSpireGardens", "CrystalRosetteGardens", "MineralWaterChannels"]:
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
		var roof: MultiMeshInstance3D = detail.get_node("StalactiteVault")
		var roof_bounds: AABB = roof.multimesh.mesh.get_aabb()
		var actual_roof_tip: float = INF
		var distances: PackedFloat32Array = roof.get_meta("placement_distances")
		for i in range(roof.multimesh.instance_count):
			var transform: Transform3D = roof.multimesh.get_instance_transform(i)
			var road: Dictionary = world.sample_road(transform.origin, float(distances[i]))
			var frame: Basis = world.frame(float(road.distance))
			var center: Vector3 = world.position_at(float(road.distance))
			for corner in range(8):
				var point: Vector3 = transform * roof_bounds.get_endpoint(corner)
				actual_roof_tip = minf(actual_roof_tip, (point - center).dot(frame.y))
		assert(actual_roof_tip >= 5.8, "Actual imported canopy bounds lose roof clearance")
		assert(absf(actual_roof_tip - float(data.minimum_stalactite_tip_m)) < 0.001)
		var batches: int = 0
		for child in detail.get_children():
			var batch := child as MultiMeshInstance3D
			assert(batch != null, "Cave kit must remain batched")
			batches += batch.multimesh.mesh.get_surface_count()
			var submitted: Array[Transform3D] = batch.get_meta("placement_transforms")
			for i in range(batch.multimesh.instance_count):
				assert(batch.multimesh.get_instance_transform(i).is_equal_approx(submitted[i]),
					"Real renderer buffer differs from submitted mineral placement")
		assert(batches == data.draw_batches, "Reported draw budget must match real imported surfaces")
		# A second build must produce the same transformations and tints exactly.
		var repeat := Node3D.new()
		world.add_child(repeat)
		GEOLOGY.build(repeat, world, world.length * 0.690, world.length * 0.800)
		var repeated: Node3D = repeat.get_node("CavernGeology")
		for child in detail.get_children():
			var original := child as MultiMeshInstance3D
			var duplicate: MultiMeshInstance3D = repeated.get_node(NodePath(str(original.name)))
			assert(original.multimesh.instance_count == duplicate.multimesh.instance_count)
			for i in range(original.multimesh.instance_count):
				assert(original.multimesh.get_instance_transform(i).is_equal_approx(
					duplicate.multimesh.get_instance_transform(i)))
				assert(original.multimesh.get_instance_color(i).is_equal_approx(
					duplicate.multimesh.get_instance_color(i)))
		repeat.free()
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
		"[CavernProduction] PASS: six original high/mobile silhouettes, seven batches, seeded placements, actual shoulder/roof bounds, unchanged physics"
	)
	quit(0)
