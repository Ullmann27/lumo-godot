extends SceneTree
## Exercises the actual combined architecture and GPU-backed fabric animation.
## Integration/complete route regression remains in the existing world suites.
const KIT = preload("res://scripts/games/visual/kart_sonnenhafen_streetfronts.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var triangle_counts: Array[int] = []
	for low in [true, false]:
		var kit = KIT.new()
		root.add_child(kit)
		kit.configure(low)
		kit.add_villa(Vector3.ZERO, Basis.IDENTITY, 9.0, 10.2, 5.6, 4, 1.0)
		kit.add_villa(Vector3(70, 0, 0), Basis(Vector3.UP, 0.65), 7.4, 6.8, 5.6, 5, -1.0)
		kit.finish()
		assert(kit.metrics.houses == 2 and kit.metrics.windows == 25)
		assert(kit.metrics.materials == 4, "Four reusable opaque surface families")
		assert(kit.metrics.material_surfaces == 8, "Two spatial cells, four surfaces each")
		assert(kit.metrics.banner_instances == 2 and kit.metrics.banner_draw_batches == 1)
		assert(kit.find_children("*", "CollisionObject3D", true, false).is_empty())
		var measured_triangles := 0
		var material_ids: Dictionary = {}
		for child in kit.get_children():
			if not child is MeshInstance3D:
				continue
			assert(child.visibility_range_end <= 220.0)
			var mesh: ArrayMesh = child.mesh
			for surface_index in range(mesh.get_surface_count()):
				var material: StandardMaterial3D = mesh.surface_get_material(surface_index)
				assert(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
				assert(material.albedo_texture == null, "No additional texture residency")
				material_ids[material.get_instance_id()] = true
				var data: Array = mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
				assert(vertices.size() % 3 == 0)
				for i in range(vertices.size()):
					assert(vertices[i].is_finite() and normals[i].is_finite())
					assert(absf(normals[i].length() - 1.0) < 0.001)
				measured_triangles += vertices.size() / 3
		assert(material_ids.size() == 4, "Cells must share material resources")
		assert(measured_triangles == kit.metrics.triangles)
		assert(measured_triangles < 22000, "Bounded real geometry, not merely scene-node count")
		triangle_counts.append(measured_triangles)
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			var rest: Transform3D = kit._banners.get_instance_transform(0)
			var racer := Vector3(0, 1, 10)
			for i in range(60):
				kit.advance(1.0 / 60.0, racer, true, false)
			var moved: Transform3D = kit._banners.get_instance_transform(0)
			assert(not moved.is_equal_approx(rest), "Actual pennant transform must move")
			assert(kit.trigger_count == 1, "One welcome per approach")
			kit.advance(0.1, racer, false, false)
			kit.advance(0.1, racer, true, true)
			assert(kit._banners.get_instance_transform(0).is_equal_approx(moved), "Pause and reduced motion freeze")
			kit.advance(NAN, racer, true, false)
			kit.advance(0.1, Vector3.INF, true, false)
			assert(kit._banners.get_instance_transform(0).is_equal_approx(moved))
			kit.advance(0.1, Vector3(300, 0, 300), true, false)
			kit.advance(0.1, racer, true, false)
			assert(kit.trigger_count == 2, "Exit hysteresis rearms welcome")
			for i in range(150):
				kit.advance(1.0 / 60.0, racer, true, false)
			assert(float(kit._banner_states[0].reaction) == 0.0, "Welcome returns to idle")
		print("[Streetfronts] ", "LOW" if low else "HIGH", " ", JSON.stringify(kit.metrics))
		kit.queue_free()
		await process_frame
	assert(triangle_counts[1] > triangle_counts[0], "LOW retains identity with less real geometry")
	print("[Streetfronts] PASS: opaque materials, actual geometry budgets, spatial cells, optional GL motion")
	quit(0)
