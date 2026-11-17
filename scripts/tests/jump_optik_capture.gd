extends SceneTree
## Screenshots + Draw-Call-Messung für Wolkeninseln / 3D-Jump.
## JUMP_CAPTURE_DIR, sonst user://jump_optik_capture.


func _initialize() -> void:
	call_deferred("_run")


func _stats() -> Dictionary:
	return {
		"draw_calls":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}


func _save(dir: String, name: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	await process_frame
	await RenderingServer.frame_post_draw
	var stats: Dictionary = _stats()
	print("[JumpCapture] %s %s" % [name, JSON.stringify(stats)])
	return stats


func _settle(frames: int = 20) -> void:
	for _i in range(frames):
		await physics_frame


func _run() -> void:
	var dir: String = OS.get_environment("JUMP_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://jump_optik_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
	await process_frame
	var game: Node = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	await _settle(45)
	if game.get("message") != null:
		game.message.text = ""
	var metrics: Dictionary = {"overview": await _save(dir, "jump_overview")}
	game.actor.position = game.islands[3] + Vector3(0, 0.4, 2.0)
	game.actor.velocity = Vector3.ZERO
	game.completed_questions[3] = true
	await _settle(50)
	metrics["island4"] = await _save(dir, "jump_island4")
	game.set_physics_process(false)
	var cam: Camera3D = game.camera
	cam.current = true
	cam.fov = 50
	cam.position = game.islands[0] + Vector3(-6.5, 3.4, 6.5)
	cam.look_at(game.islands[0] + Vector3(0.4, 0.6, -0.2))
	await _settle(12)
	metrics["closeup"] = await _save(dir, "jump_closeup")
	var file := FileAccess.open(dir.path_join("jump_metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("[JumpCapture] PASS %s" % dir)
	quit(0)
