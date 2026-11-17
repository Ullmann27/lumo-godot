extends SceneTree
## Preserve every old save shape and exercise the two new complete picture worlds.
const STATE = preload("res://scripts/creative/puzzle_state.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[PuzzleExpansion] FAIL " + label)


func _run() -> void:
	for motif in range(5):
		for count in STATE.COUNTS:
			var model = STATE.new()
			model.setup(count, motif)
			_check(model.count == count and model.motif == motif, "requested picture and count")
			_check(not model.try_snap(0, model.target(1)), "wrong-slot rejection")
			for id in range(count):
				_check(model.try_snap(id, model.target(id)), "piece snaps only into its own slot")
			var snapshot: Dictionary = model.to_data()
			_check(int(snapshot.version) == 1, "version-1 save format retained")
			var restored = STATE.new()
			_check(
				restored.restore(snapshot) and restored.complete(), "completed picture round trip"
			)
			_check(restored.motif == motif, "saved picture identity retained")
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {"childKey": "expansion_regression"}
	DirAccess.remove_absolute("user://lumo_puzzle_expansion_regression.json")
	var game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for motif in [3, 4]:
		game.selected_count = 6
		game.selected_motif = motif
		game.start()
		_check(not game.picture_alive, "new puzzle clears previous celebration")
		# Six real ray-picked drags through the game's normal input handlers.
		for id in range(6):
			game._tray()
			await physics_frame
			await physics_frame
			var point: Vector2 = game.camera.unproject_position(
				game.nodes[id].global_position + Vector3.UP * 0.16
			)
			game._pick(point, 0)
			_check(game.dragging == id, "ray selects actual tray piece")
			if game.dragging != id:
				continue
			var target: Vector2 = game.model.target(id)
			game._drag(game.camera.unproject_position(Vector3(target.x, 0.35, target.y)))
			_check(game.matching_hover, "matching target highlights before drop")
			game._drop()
			_check(game.model.pieces[id].locked, "projected drag locks selected piece")
		_check(game.model.complete(), "six-piece round is playable through real picking")
		_check(game.picture_alive and game.alive_picture.visible, "completed picture animates")
		_check(
			game.alive_picture.position.y > game.nodes[0].position.y + 0.16,
			"completion animation is above the opaque piece surface"
		)
		_check(game.model.motif == motif, "new motif identity used by completed round")
		game._resume()
		_check(game.model.complete() and game.picture_alive, "completed saved round resumes")
		var captures := OS.get_environment("PUZZLE_EXPANSION_CAPTURE_DIR")
		if not captures.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(captures)
			game._continue()
			for _frame in range(12):
				await process_frame
			await RenderingServer.frame_post_draw
			var captured := root.get_texture().get_image().save_png(
				captures.path_join("puzzle_completed_%d.png" % motif)
			)
			_check(captured == OK, "completed round renderer capture written")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_puzzle_expansion_regression.json")
	if failures.is_empty():
		print(
			(
				"[PuzzleExpansion] PASS %d checks: all motifs/counts, saves and two played rounds"
				% checks
			)
		)
		quit(0)
	else:
		print("[PuzzleExpansion] FAIL ", failures)
		quit(1)
