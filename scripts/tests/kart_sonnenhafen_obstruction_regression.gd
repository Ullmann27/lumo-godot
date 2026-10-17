extends SceneTree
## B6: User-reported visual obstruction audit of the actual 1.85km
## Sonnenhafen mesh instances. Not only road centres: the full mountain
## silhouette radius and both low/high-LOD backdrops are inspected.
const WORLD = preload("res://scripts/games/kart_world.gd")
const RACE_MARGIN: float = 5.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var road_length: float = -1.0
	for low in [true, false]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		if road_length < 0.0:
			road_length = world.length
		assert(world.length > 1800.0 and world.length < 1900.0)
		assert(is_equal_approx(world.length, road_length))
		assert(world.checkpoint_positions.size() == 8)
		assert(int(world.get_meta("sonnenhafen_mountains_relocated", 0)) == 12,
			"All twelve huge legacy backdrop mountains must be relocated")
		var found: int = 0
		for item in world.get_children():
			if not item is MultiMeshInstance3D:
				continue
			if not item.name.begins_with("Decor_mountain_"):
				continue
			var mm: MultiMesh = item.multimesh
			assert(mm != null and mm.mesh != null)
			var local: AABB = mm.mesh.get_aabb()
			var local_radius: float = maxf(
				absf(local.position.x), absf(local.end.x)
			)
			local_radius = maxf(local_radius,
				maxf(absf(local.position.z), absf(local.end.z)))
			for i in range(mm.instance_count):
				var pose: Transform3D = item.transform * mm.get_instance_transform(i)
				var radius: float = local_radius * maxf(
					pose.basis.x.length(), pose.basis.z.length()
				)
				var clearance: float = world.RAIL_LATERAL + radius + RACE_MARGIN
				var distance: float = world._nearest_horizontal(pose.origin).x
				assert(distance >= clearance,
					"Background mountain visibly intrudes into lane: %s distance=%.2f need=%.2f" %
					[item.name,distance,clearance])
				found += 1
		assert(found == 12, "Expected all 12 mountain silhouettes in each LOD")
		# Also inspect the actual rock geometry (legacy shoreline boulders,
		# terraced cliffs, waterfall ledges and five original hero foundations).
		# Use 8 transformed AABB corners, including orientation and size, to
		# reject rock volumes that could visually intrude into the racing lane.
		var rocks_checked: int = 0
		for item in world.get_children():
			if not item is MultiMeshInstance3D:
				continue
			if not item.name.begins_with("Decor_rock_"):
				continue
			var rocks: MultiMesh = item.multimesh
			if rocks == null or rocks.mesh == null:
				continue
			var local_box: AABB = rocks.mesh.get_aabb()
			for index in range(rocks.instance_count):
				var pose: Transform3D = item.transform * rocks.get_instance_transform(index)
				var full_radius: float = 0.0
				var min_y: float = INF
				var max_y: float = -INF
				for x in [local_box.position.x, local_box.end.x]:
					for y in [local_box.position.y, local_box.end.y]:
						for z in [local_box.position.z, local_box.end.z]:
							var vertex: Vector3 = pose * Vector3(x,y,z)
							full_radius = maxf(full_radius,
								Vector2(vertex.x-pose.origin.x,vertex.z-pose.origin.z).length())
							min_y = minf(min_y,vertex.y)
							max_y = maxf(max_y,vertex.y)
				var nearest: Vector2 = world._nearest_horizontal(pose.origin)
				var sample_index: int = int(nearest.y)
				var road_y: float = world._road_samples[sample_index].y
				var kart_level: bool = min_y < road_y + 2.6 and max_y > road_y - 1.0
				assert(not kart_level or nearest.x > world.WALL_LATERAL + full_radius,
					"Decorative rock overlaps playable Sonnenhafen kart lane: %s instance=%d centre_dist=%.2f radius=%.2f" %
					[item.name,index,nearest.x,full_radius])
				rocks_checked += 1
		assert(rocks_checked > 100, "Full 1.85km world should retain real rock formations")
		print("[RoadObstruction] inspected_solid_rocks=%d" % rocks_checked)
		var removed_rocks: int = int(world.get_meta(
			"sonnenhafen_legacy_shore_rocks_skipped", 0
		))
		print("[RoadObstruction] %s mountains=%d old_rocks_filtered=%d road=%.2fm" %
			["low" if low else "high",found,removed_rocks,world.length])
		world.queue_free()
		await process_frame
	print("[RoadObstruction] PASS: all 12 full-size mountain silhouettes outside the rail corridor in both LODs")
	quit(0)
