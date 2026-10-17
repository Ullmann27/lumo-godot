extends SceneTree
## Regression: actual Sonnenhafen build in both LODs, unchanged gameplay,
## guaranteed ride-through space, no new physics, and valid emissive geometry.
const WORLD = preload("res://scripts/games/kart_world.gd")
const RIDE = preload("res://scripts/games/kart_sonnenhafen_darkride.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for is_low in [false, true]:
		var world: LumoRaceWorld = WORLD.new()
		root.add_child(world)
		world.build(is_low, "sonnenhafen", false)
		var metrics: Dictionary = world.get_meta("sonnenhafen_darkride", {})
		assert(not metrics.is_empty(), "Full Sonnenhafen race must include the darkride")
		var ride: Node3D = world.get_node_or_null("SonnenhafenBioluminescentDarkride")
		assert(ride != null, "Expected generated playable tunnel in the world")
		assert(world.checkpoint_positions.size() == 8, "Checkpoints must be preserved")
		assert(absf(world.length - 1851.68) < 2.0, "Race length unexpectedly changed")
		assert(float(metrics["length_m"]) > 180.0, "Tunnel must provide a substantial dark ride")
		assert(float(metrics["inside_road_width_m"]) > 10.7, "Road overlay must retain racing width")
		assert(float(metrics["tunnel_clearance_m"]) >= 8.0, "Insufficient headroom")
		assert(int(metrics["collision_bodies_added"]) == 0, "No new physics blockers permitted")
		assert(int(metrics["arch_rib_instances"]) >= 90, "Neon cave ribs missing")
		assert(int(metrics["crystal_instances"]) >= 16, "Glowing lanterns missing")
		assert(int(metrics["shell_sections"]) >= 30, "Tunnel shell cannot be a flat billboard")
		assert(ride.get_child_count() == 4, "Expected shell, road, ribs, crystal batches")
		for name in ["DarkrideRockAndCanopy", "DarkrideIlluminatedRoad"]:
			var node: MeshInstance3D = ride.get_node(name)
			assert(node.mesh.get_surface_count() == 1, "Missing procedural triangle surface")
			assert(node.material_override is ShaderMaterial, "Missing Android-safe cave material")
			var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var minimum_vertices: int = 140 if is_low else 300
			assert(verts.size() > minimum_vertices, "Insufficient geometric detail for selected LOD")
		var ribs: MultiMeshInstance3D = ride.get_node("DarkrideNeonArchRibs")
		var crystals: MultiMeshInstance3D = ride.get_node("DarkrideCrystalLanterns")
		assert(ribs.multimesh.instance_count == int(metrics["arch_rib_instances"]))
		assert(crystals.multimesh.instance_count == int(metrics["crystal_instances"]))
		var stack: Array[Node] = [ride]
		while not stack.is_empty():
			var current: Node = stack.pop_back()
			assert(not current is CollisionObject3D, "Tunnel scenery added a collision body")
			for child in current.get_children():
				stack.append(child)
		var start_m: float = float(metrics["start_m"])
		var end_m: float = float(metrics["end_m"])
		var d: float = start_m + 5.0
		while d < end_m - 5.0:
			for lateral in [-4.8, 0.0, 4.8]:
				var sample: Dictionary = world.sample_road(world.position_at(d, lateral), d)
				assert(sample.on_road, "Tunnel traversal crossed existing road boundary")
				assert(absf(float(sample.lateral) - lateral) < 1.2, "Existing road projection changed")
			d += 8.0
		print("[Darkride] LOD=", ("low" if is_low else "high"),
			" span=", metrics.length_m, " sections=", metrics.shell_sections,
			" neon_instances=", metrics.arch_rib_instances,
			" crystal_instances=", metrics.crystal_instances)
		root.remove_child(world)
		world.queue_free()
		await process_frame

	# Legacy/other worlds must not load the Sonnenhafen tunnel.
	var legacy: LumoRaceWorld = WORLD.new()
	root.add_child(legacy)
	legacy.build(true, "zauberwald", true)
	assert(not legacy.has_meta("sonnenhafen_darkride"), "Tunnel leaked into another track")
	root.remove_child(legacy)
	legacy.queue_free()
	print("[Darkride] PASS: deterministic mobile geometry, road width, eight checkpoints and zero collision changes")
	quit(0)
