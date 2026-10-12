extends SceneTree
## Real Godot scene render, isolated location fixture; not a completed playthrough.
var output := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	output = OS.get_environment("LUMO_QA_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	game.player.position = Vector3(-4, 0.1, -65)
	game.camera.position = Vector3(4, 3.5, -70)
	game.camera.look_at(Vector3(0, 0.7, -65))
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join("treasure-chest.png")) == OK)
	var evidence := FileAccess.open(output.path_join("renderer.json"), FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(),
		"surface": str(root.size), "physical_android": false,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"note": "Desktop software-renderer scene counts; not Android FPS or latency"}, "\t"))
	evidence.close()
	game.queue_free()
	for frame in range(3):
		await process_frame
	print("[CreativeObjects] PASS: actual GL scene capture")
	quit(0)
