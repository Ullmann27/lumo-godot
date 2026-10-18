extends SceneTree
## Verify real uploaded berth geometry, tight draw budgets and road clearance.
const WORLD = preload("res://scripts/games/kart_world.gd")
const CRANE = preload("res://scripts/games/kart_harbor_crane.gd")


func _initialize() -> void:
	call_deferred("_run")


func _check_bevel(mesh: ArrayMesh) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 132, "Bevel mesh must contain the budgeted 44 triangles")
	var chamfer_normals: int = 0
	for i in range(0, vertices.size(), 3):
		var normal: Vector3 = normals[i]
		var triangle_normal: Vector3 = (
			(vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		)
		assert(triangle_normal.dot(normal) < -0.99, "Outward normals require clockwise Godot faces")
		if absf(normal.x) > 0.1 and absf(normal.y) > 0.1 and absf(normal.z) > 0.1:
			chamfer_normals += 1
	assert(chamfer_normals == 8, "All eight box corners need actual chamfer geometry")


func _run() -> void:
	var totals: Array[int] = []
	for low in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		var harbor: Node3D = world.get_node_or_null("HarborCinema")
		assert(
			harbor != null, "Latest long-course Sonnenhafen must actually mount the berth finish"
		)
		var stats: Dictionary = harbor.get_meta("production_metrics")
		assert(stats.draw_batches == 4 and harbor.get_child_count() == 4)
		assert(stats.low_detail == low)
		assert(stats.external_assets == 0)
		assert(stats.containers == (17 if low else 24))
		assert(stats.fenders == (3 if low else 5))
		assert(stats.instances < (170 if low else 600), "Berth detail exceeds its bounded budget")
		assert(harbor.transform.is_equal_approx(world.get_meta("sonnenhafen_crane_frame")))
		var instances: int = 0
		var triangles: int = 0
		var minimum_road_distance: float = INF
		for child in harbor.get_children():
			assert(child is MultiMeshInstance3D, "Scenery may only introduce four GPU batches")
			var batch: MultiMeshInstance3D = child
			assert(batch.multimesh.use_colors)
			var bounds: AABB = batch.multimesh.mesh.get_aabb()
			instances += batch.multimesh.instance_count
			var mesh_triangles: int = int(batch.multimesh.mesh.get_faces().size() / 3)
			triangles += mesh_triangles * batch.multimesh.instance_count
			assert(stats.batches[str(batch.name)].mesh_triangles == mesh_triangles)
			assert(stats.batches[str(batch.name)].instances == batch.multimesh.instance_count)
			for i in range(batch.multimesh.instance_count):
				var transform: Transform3D = (
					harbor.transform * batch.multimesh.get_instance_transform(i)
				)
				assert(transform.basis.determinant() > 0.0, "Geometry may not flip winding")
				for corner in range(8):
					var point: Vector3 = transform * bounds.get_endpoint(corner)
					var distance: float = world._nearest_horizontal(point).x
					minimum_road_distance = minf(minimum_road_distance, distance)
					assert(
						distance >= CRANE.ROAD_CLEARANCE, "Real mesh bounds intrude into the race"
					)
			if low:
				assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			if str(batch.name) in ["PaintedContainerShells", "CastMetalHardware"]:
				assert(batch.material_override is ShaderMaterial)
				_check_bevel(batch.multimesh.mesh)
			else:
				assert(batch.material_override is StandardMaterial3D)
		assert(instances == stats.instances, "Budget must match actual uploaded instances")
		assert(triangles == stats.triangles, "Triangle metadata must describe real uploaded meshes")
		assert(world.get_meta("sonnenhafen_visual_finish").contacts == 10)
		assert(world.get_meta("sonnenhafen_visual_finish").seams == 4)
		assert(world.get_meta("sonnenhafen_visual_finish").ribs == (0 if low else 288))
		assert(
			(
				world.get_node_or_null("SonnenhafenCraneTrolley") == null
				if low
				else world.get_node_or_null("SonnenhafenCraneTrolley/SonnenhafenCraneHoist") != null
			)
		)
		totals.append(instances)
		print(
			(
				"[HarborCinema] low=%s batches=4 instances=%d triangles=%d road_clearance=%.2fm"
				% [low, instances, triangles, minimum_road_distance]
			)
		)
		world.queue_free()
		await process_frame
	assert(totals[0] > totals[1])
	var other = WORLD.new()
	root.add_child(other)
	other.build(true, "zauberwald", true)
	assert(other.get_node_or_null("HarborCinema") == null)
	assert(not other.has_meta("sonnenhafen_harbor_cinema"))
	other.queue_free()
	await process_frame
	print("[HarborCinema] PASS: bevels, four batches, nautical detail, clear road, track isolation")
	quit(0)
