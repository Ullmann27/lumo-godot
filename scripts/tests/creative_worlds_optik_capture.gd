extends SceneTree
## Screenshots + Draw-Call-Messung für Puzzle, Rhythm und Schatzsuche.
## CREATIVE_CAPTURE_DIR, CREATIVE_CAPTURE_GAMES (Komma-Liste: puzzle,rhythm,treasure).


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
	print("[CreativeWorldsCapture] %s %s" % [name, JSON.stringify(stats)])
	return stats


func _settle(frames: int = 12) -> void:
	for _i in range(frames):
		await process_frame


func _capture_puzzle(dir: String) -> Dictionary:
	DirAccess.remove_absolute("user://lumo_puzzle_optikcapture.json")
	root.get_node("SceneRouter").launch_options = {"childKey": "optikcapture"}
	var game: Node = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await _settle(8)
	game.selected_count = 12
	game.selected_motif = 0
	game.start()
	for id in [0, 1, 3, 4, 5, 8, 9]:
		game.model.try_snap(id, game.model.target(id))
	game._tray()
	game._labels()
	await _settle(10)
	var entry: Dictionary = {"overview": await _save(dir, "puzzle_overview")}
	if game.nodes.size() > 2:
		game._pick(game.camera.unproject_position(game.nodes[2].global_position + Vector3.UP * 0.16), 0)
	await _settle(8)
	entry["lift"] = await _save(dir, "puzzle_lift")
	if game.dragging >= 0:
		game._drop()
	entry["pieces"] = game.model.pieces.size()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_puzzle_optikcapture.json")
	return entry


func _capture_rhythm(dir: String) -> Dictionary:
	root.get_node("SceneRouter").launch_options = {"childKey": "optikcapture"}
	var game: Node = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await _settle(8)
	game.start()
	game.model.time = 0.55
	if game.has_node("AudioStreamPlayer") or game.get("audio") != null:
		game.audio.stop()
	for i in game.note_nodes:
		var note: Dictionary = game.model.notes[int(i)]
		var node: Node3D = game.note_nodes[i]
		node.position.z = 3.0 - (float(note.time) - game.model.time) * 8
		node.position.y = 0.38
		node.visible = (
			int(note.state) in [0, 1, 4] and node.position.z >= -33 and node.position.z <= 6
		)
	game.running = false
	await _settle(10)
	var entry: Dictionary = {"overview": await _save(dir, "rhythm_overview")}
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	if cam != null:
		cam.position = Vector3(0, 7.5, 8.5)
		cam.look_at(Vector3(0, 0.4, -2))
	await _settle(8)
	entry["closeup"] = await _save(dir, "rhythm_closeup")
	entry["notes"] = game.model.notes.size()
	game.queue_free()
	await process_frame
	return entry


func _capture_treasure(dir: String) -> Dictionary:
	DirAccess.remove_absolute("user://lumo_treasure_optikcapture.json")
	root.get_node("SceneRouter").launch_options = {"childKey": "optikcapture"}
	var game: Node = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await _settle(14)
	if game.has_method("_update"):
		game._update()
	var cam: Camera3D = game.camera
	cam.position = Vector3(14, 16, 18)
	cam.look_at(Vector3(0, 1.2, -26))
	await _settle(10)
	var entry: Dictionary = {"overview": await _save(dir, "treasure_overview")}
	# Follow-Kamera sonst während des Settles zurück auf den Startpfad.
	game.set_physics_process(false)
	cam.current = true
	cam.position = Vector3(8, 8, -18)
	cam.look_at(Vector3(0, 2.2, -38))
	await _settle(8)
	entry["closeup"] = await _save(dir, "treasure_closeup")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_treasure_optikcapture.json")
	return entry


func _run() -> void:
	var dir: String = OS.get_environment("CREATIVE_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://creative_worlds_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	var requested: String = OS.get_environment("CREATIVE_CAPTURE_GAMES")
	if requested.is_empty():
		requested = "puzzle,rhythm,treasure"
	var metrics: Dictionary = {}
	await process_frame
	for name in requested.split(",", false):
		match str(name).strip_edges():
			"puzzle":
				metrics["puzzle"] = await _capture_puzzle(dir)
			"rhythm":
				metrics["rhythm"] = await _capture_rhythm(dir)
			"treasure":
				metrics["treasure"] = await _capture_treasure(dir)
			_:
				push_warning("[CreativeWorldsCapture] unknown game %s" % name)
	var file := FileAccess.open(dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("[CreativeWorldsCapture] PASS %s" % dir)
	quit(0)
