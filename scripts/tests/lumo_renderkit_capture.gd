extends SceneTree
## Real GL frames + render statistics for LumoRenderKit (run under xvfb).
## For each tier: 3D-Jump gameplay camera (island 1 and 4), a hero side shot,
## and Bauwelt (creative_night preset). Writes PNGs and metrics.json to
## LUMO_CAPTURE_DIR. Works on builds without LumoRenderKit (before frames).
## llvmpipe numbers are NOT device performance; draw calls/primitives are
## renderer-independent enough to compare before/after.


func _initialize() -> void:
	call_deferred("_run")


func _stats() -> Dictionary:
	return {
		"draw_calls":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
		"primitives":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		),
		"objects":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}


func _save(dir: String, name: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	await process_frame
	await RenderingServer.frame_post_draw
	var stats: Dictionary = _stats()
	print("[RenderKitCapture] %s %s" % [name, JSON.stringify(stats)])
	return stats


func _run() -> void:
	var dir: String = OS.get_environment("LUMO_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://renderkit_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	var performance: Node = root.get_node("PerformanceManager")
	var metrics: Dictionary = {}
	await process_frame
	for tier in [0, 1, 2]:
		var tier_name: String = ["low", "medium", "high"][tier]
		performance.call("set_profile", tier, false)
		DirAccess.remove_absolute("user://jump_session.cfg")
		root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
		var started: int = Time.get_ticks_usec()
		var game: Node = load("res://scenes/games/jump_islands.tscn").instantiate()
		root.add_child(game)
		var build_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		# PerformanceManager applies tiers to the current scene's environment.
		current_scene = game
		performance.call("set_profile", tier, false)
		for frame in range(45):
			await physics_frame
		game.message.text = ""
		var entry: Dictionary = {"jump_build_ms": build_ms}
		entry["jump_start"] = await _save(dir, "jump_start_" + tier_name)
		game.actor.position = game.islands[3] + Vector3(0, 0.4, 2.0)
		game.actor.velocity = Vector3.ZERO
		game.completed_questions[3] = true
		for frame in range(60):
			await physics_frame
		entry["jump_island4"] = await _save(dir, "jump_island4_" + tier_name)
		game.actor.position = game.islands[1] + Vector3(-1.5, 0.4, 1.5)
		game.actor.velocity = Vector3.ZERO
		for frame in range(30):
			await physics_frame
		game.touch_direction = Vector2(0.3, -1.0).normalized()
		for frame in range(14):
			await physics_frame
		game.set_physics_process(false)
		var hero := Camera3D.new()
		hero.fov = 50
		game.add_child(hero)
		hero.position = game.actor.position + Vector3(5.5, 1.6, 2.5)
		hero.look_at(game.actor.position + Vector3(-0.5, 0.9, -5.0))
		hero.current = true
		entry["jump_hero"] = await _save(dir, "jump_hero_" + tier_name)
		game.queue_free()
		await process_frame
		var build: Node = load("res://scenes/creative/build_world.tscn").instantiate()
		root.add_child(build)
		current_scene = build
		performance.call("set_profile", tier, false)
		for frame in range(30):
			await process_frame
		entry["bauwelt"] = await _save(dir, "bauwelt_" + tier_name)
		build.queue_free()
		await process_frame
		metrics[tier_name] = entry
	var file := FileAccess.open(dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("[RenderKitCapture] PASS %s" % dir)
	quit(0)
