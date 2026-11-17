extends SceneTree
## Real scene-switch regression for Android's persistent Kart quality selection.
## Unlike a signal-connection assertion, this checks a new scene's live Environment.
## No saved settings are changed, no game or player progress is written.

func _initialize() -> void:
	call_deferred("_run")


func _make_environment_scene(name: String) -> Dictionary:
	var scene := Node3D.new()
	scene.name = name
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.glow_enabled = true
	world.environment = environment
	scene.add_child(world)
	return {"scene": scene, "environment": environment}


func _run() -> void:
	await process_frame
	await process_frame
	var performance: Node = root.get_node_or_null("PerformanceManager")
	assert(performance != null, "PerformanceManager autoload was not created")
	assert(scene_changed.is_connected(Callable(performance, "_on_scene_changed")),
		"Quality manager must listen to the actual SceneTree.scene_changed signal")
	var previous_profile: int = int(performance.get("current_profile"))
	performance.call("set_profile", 0, false)  # LOW, never persist test preferences
	assert(str(performance.call("get_profile_name")) == "low")

	var first: Dictionary = _make_environment_scene("QualityFirst")
	assert(change_scene_to_node(first["scene"]) == OK, "Initial quality test scene failed")
	await scene_changed
	await process_frame
	assert(current_scene == first["scene"], "Initial scene did not become active")
	assert(not (first["environment"] as Environment).glow_enabled,
		"LOW profile was not reapplied when the first real scene loaded")

	var second: Dictionary = _make_environment_scene("QualitySecond")
	assert((second["environment"] as Environment).glow_enabled,
		"Second scene must begin with a distinct, expensive environment")
	assert(change_scene_to_node(second["scene"]) == OK, "Second quality test scene failed")
	await scene_changed
	await process_frame
	assert(current_scene == second["scene"], "Second scene did not become active")
	assert(not (second["environment"] as Environment).glow_enabled,
		"LOW profile leaked away after navigating into another scene")
	assert(str(performance.call("get_profile_name")) == "low")
	performance.call("set_profile", previous_profile, false)
	print("[KartQualitySceneSwitch] PASS: live SceneTree transitions reapply LOW without saving")
	quit(0)
