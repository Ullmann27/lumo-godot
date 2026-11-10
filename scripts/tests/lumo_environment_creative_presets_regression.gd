extends SceneTree
## Preset-Schnittstelle und Bauwelt-Instancing (ohne lumo_environment.gd zu ändern).


func _initialize() -> void:
	call_deferred("_run")


func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found: Node = _find(child, name)
		if found != null:
			return found
	return null


func _run() -> void:
	var empty: Dictionary = LumoEnvironmentCreativePresets.describe("unknown")
	assert(empty.is_empty())
	var spec: Dictionary = LumoEnvironmentCreativePresets.describe("bauwelt_day")
	assert(spec.id == "bauwelt_day")
	assert(spec.shadow_policy == "budget")
	assert(spec.sky.sky_top_color.is_equal_approx(Color("3d8fe0")))
	assert(spec.sun.light_color.is_equal_approx(Color("ffe9c7")))
	assert(is_equal_approx(float(spec.sun.light_energy), 1.25))
	assert(spec.fill.name == "SkyFill")
	assert(spec.fill.shadow_enabled == false)
	assert(is_equal_approx(float(spec.fog.density), 0.0025))
	var holder := Node3D.new()
	root.add_child(holder)
	var applied: Dictionary = LumoEnvironmentCreativePresets.apply(holder, "bauwelt_day", "high")
	assert(applied.world is WorldEnvironment)
	assert(applied.environment is Environment)
	assert(applied.sun is DirectionalLight3D)
	assert(applied.rim == null)
	assert(applied.fill is DirectionalLight3D)
	assert(applied.fill.name == "SkyFill")
	assert(applied.fill.shadow_enabled == false)
	assert(applied.sun.shadow_enabled)
	assert(applied.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY)
	assert(is_equal_approx(applied.sun.light_energy, 1.25))
	var low: Dictionary = LumoEnvironmentCreativePresets.apply(holder, "bauwelt_day", "low")
	assert(low.sun.shadow_enabled == false, "bauwelt_day follows LumoQuality.budget shadows")
	holder.queue_free()
	var sand: Dictionary = {"id": "sand", "shape": "box", "size": Vector3i(1, 1, 1), "color": Color.WHITE}
	assert(BuildVoxelStyle.is_batchable(sand))
	assert(BuildVoxelStyle.kind_for(sand) == "sand")
	assert(BuildVoxelStyle.kind_for({"id": "bridge", "shape": "bridge"}) == "sand")
	assert(BuildVoxelStyle.wall_mesh().get_surface_count() >= 1)
	DirAccess.remove_absolute("user://lumo_build_presetcheck_1.json")
	root.get_node("SceneRouter").launch_options = {"childKey": "presetcheck"}
	var build: Node = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(build)
	await process_frame
	await process_frame
	assert(_find(build, "WorldEnvironment") != null)
	assert(_find(build, "SkyFill") != null)
	assert(_find(build, "DayClouds") is MultiMeshInstance3D)
	assert(_find(build, "RiverRocks") is MultiMeshInstance3D)
	assert(_find(build, "Batch_sand") is MultiMeshInstance3D)
	assert(_find(build, "Batch_wall") is MultiMeshInstance3D)
	var sand_batch: MultiMeshInstance3D = _find(build, "Batch_sand")
	assert(sand_batch.multimesh.instance_count >= 90, "castle towers must instance sand blocks")
	build.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_build_presetcheck_1.json")
	print("[CreativePresets] PASS describe/configure/apply, bauwelt_day fill, MultiMesh batches")
	quit(0)
