extends SceneTree
## Inspect the geometry actually installed by World.build, including every
## distinct projected vertex against the complete course's road clearance.
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for low in [true, false]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		var kit: Node3D = world.get_node("SonnenhafenStreetfronts")
		var metrics: Dictionary = kit.get_meta("production_metrics")
		assert(metrics.houses >= 2 and metrics.houses <= 16)
		assert(metrics.triangles <= 100000, "Street quarter has a hard real-geometry budget")
		assert(metrics.material_surfaces <= 32, "At most eight culled cells, four materials")
		assert(metrics.windows >= metrics.houses * 10)
		assert(kit.find_children("*", "CollisionObject3D", true, false).is_empty())
		var points: Dictionary = {}
		for child in kit.get_children():
			if not child is MeshInstance3D:
				continue
			for point in child.mesh.get_faces():
				var world_point: Vector3 = child.transform * point
				points[Vector2(world_point.x, world_point.z)] = true
		var minimum := INF
		for point: Vector2 in points:
			var distance: float = world._nearest_horizontal(Vector3(point.x, 0, point.y)).x
			minimum = minf(minimum, distance)
			assert(distance >= 7.0, "All facade/awning/paving vertices stay beyond the road envelope")
		assert(points.size() >= 200)
		assert(world.get_meta("sonnenhafen_streetfronts") == metrics)
		print("[StreetfrontsWorld] ", "LOW" if low else "HIGH", " min road distance ", minimum,
			" projected vertices ", points.size(), " ", JSON.stringify(metrics))
		world.queue_free()
		await process_frame
	print("[StreetfrontsWorld] PASS: integrated opaque kit, hard geometry budget, complete road clearance")
	quit(0)
