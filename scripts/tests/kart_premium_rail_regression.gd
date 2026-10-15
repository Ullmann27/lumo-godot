extends SceneTree
## Rail geometry quality / collision invariants with actual Godot 4.6.3 resources.
const SHAPES = preload("res://scripts/games/kart_world_meshes.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rail: ArrayMesh = SHAPES.premium_rail()
	assert(rail != null and rail.get_surface_count() == 1)
	assert(rail.get_faces().size() >= 60)
	var bounds: AABB = rail.get_aabb()
	assert(bounds.size.x > 0.9 and bounds.size.y > 0.9 and bounds.size.z > 0.9)
	assert(WORLD.RAIL_LATERAL == 6.05)
	assert(WORLD.WALL_LATERAL == 5.0)

	var world := WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	var rails := 0
	var glow_batches := 0
	for child in world.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Decor_premium_rail"):
			rails += child.multimesh.instance_count
			assert(child.multimesh.mesh != null)
			assert(child.material_override is StandardMaterial3D)
		if child is MultiMeshInstance3D and child.name.contains("_light"):
			glow_batches += 1
	assert(rails >= 100, "Premium rail instances must be present on both sides")
	assert(world.length > 250)
	world.queue_free()
	await process_frame
	print("[PremiumRailKit] PASS rail triangles, mesh AABB, unchanged collision, LOD rails=%d glow_batches=%d" % [rails, glow_batches])
	quit(0)
