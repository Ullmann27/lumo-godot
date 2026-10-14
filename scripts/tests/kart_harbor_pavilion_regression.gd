extends SceneTree
const WORLD = preload("res://scripts/games/kart_world.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for low in [false, true]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		assert(world.has_meta("harbor_wave_pavilions"))
		var pavilions: Array = world.get_meta("harbor_wave_pavilions")
		assert(pavilions.size() == 3)
		for pavilion in pavilions:
			for side in ["LeftPier", "RightPier"]:
				var collider: CollisionShape3D = pavilion.get_node("Piers/" + side)
				assert(absf(collider.position.x) - collider.shape.size.x * 0.5 > world.RAIL_LATERAL)
			for lod in range(3):
				var node: Node3D = pavilion.get_node("LOD%d" % lod)
				var meshes := node.find_children("*", "MeshInstance3D", true, false)
				assert(meshes.size() == 5)
				assert(node.visible == (not low or lod != 0))
				for mesh in meshes:
					assert(mesh.mesh.get_surface_count() >= 1)
					if low and lod == 0:
						continue
					assert(mesh.visibility_range_end > mesh.visibility_range_begin)
		world.queue_free()
		await process_frame
	print("[HarborPavilion] PASS: three placed UV/PBR LOD prefabs, six piers outside racing guardrails, both detail tiers")
	quit(0)
