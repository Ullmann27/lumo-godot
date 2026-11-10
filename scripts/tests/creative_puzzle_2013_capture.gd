extends SceneTree
## 2013 Puzzle captures + draw-call readout. Works before and after the visual pass.
## PUZZLE_CAPTURE_DIR selects the output folder.


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


func _settle(frames: int = 12) -> void:
	for _i in range(frames):
		await process_frame
		await RenderingServer.frame_post_draw


func _save(dir: String, name: String) -> Dictionary:
	await _settle(6)
	var image: Image = root.get_viewport().get_texture().get_image()
	var path: String = dir.path_join(name + ".png")
	assert(image != null and image.save_png(path) == OK)
	var stats: Dictionary = _stats()
	print("[Puzzle2013Capture] %s %s" % [name, JSON.stringify(stats)])
	return stats


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var dir: String = OS.get_environment("PUZZLE_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://puzzle_2013_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute("user://lumo_puzzle_2013capture.json")
	if root.has_node("SceneRouter"):
		root.get_node("SceneRouter").launch_options = {"childKey": "capture2013"}
	var game: Node = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await _settle(14)
	var metrics: Dictionary = {}
	metrics["start_menu"] = await _save(dir, "puzzle_start_menu")
	game.save_path = "user://lumo_puzzle_2013capture.json"
	game.selected_count = 12
	if "selected_motif" in game:
		game.selected_motif = 0
	game.start()
	for id in [0, 1, 3, 4, 5, 8, 9]:
		game.model.try_snap(id, game.model.target(id))
	game._tray()
	game._labels()
	await _settle(10)
	metrics["overview"] = await _save(dir, "puzzle_overview")
	if game.nodes.size() > 2:
		game._pick(
			game.camera.unproject_position(game.nodes[2].global_position + Vector3.UP * 0.16), 0
		)
	await _settle(8)
	metrics["lift"] = await _save(dir, "puzzle_lift")
	if int(game.dragging) >= 0:
		game._drop()
	if game.has_method("_hint"):
		game._hint()
		await _settle(6)
		metrics["hint"] = await _save(dir, "puzzle_hint")
	var cam: Camera3D = game.camera
	print(
		"[Puzzle2013Capture] camera pos=%s look_target_basis_z=%s"
		% [str(cam.position), str(cam.global_transform.basis.z)]
	)
	print("[Puzzle2013Capture] METRICS " + JSON.stringify(metrics))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_puzzle_2013capture.json")
	print("[Puzzle2013Capture] PASS")
	quit(0)
