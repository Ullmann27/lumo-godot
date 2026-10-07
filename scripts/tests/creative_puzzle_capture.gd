extends SceneTree
const STATE = preload("res://scripts/creative/puzzle_state.gd")
const PIECE = preload("res://scripts/creative/puzzle_piece.gd")
var out_dir := "res://exports/creative-build"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model = STATE.new()
	for count in STATE.COUNTS:
		model.setup(count, 0)
		assert(model.pieces.size() == count)
		for id in range(count):
			var outline: PackedVector2Array = model.outline(id)
			assert(
				Geometry2D.triangulate_polygon(outline).size() >= 6,
				"Every actual piece has triangulatable jigsaw geometry"
			)
			if id % model.columns < model.columns - 1:
				assert(model.edge_sign(id, 1) == -model.edge_sign(id + 1, 3))
			if id / model.columns < model.rows - 1:
				assert(model.edge_sign(id, 2) == -model.edge_sign(id + model.columns, 0))
		assert(not model.try_snap(0, model.target(1)), "A piece cannot snap into the wrong slot")
		for id in range(count):
			assert(model.try_snap(id, model.target(id)))
		assert(model.complete())
		var restored = STATE.new()
		assert(restored.restore(model.to_data()) and restored.complete())
		var bad: Dictionary = model.to_data()
		bad.pieces[1].id = bad.pieces[0].id
		assert(not restored.restore(bad) and restored.complete())
	print(
		"[Puzzle] PASS 12/24/48/96 outlines, matching neighbors, wrong-slot rejection, snapping and transactional resume"
	)
	if "--logic-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://lumo_puzzle_qa.json"
	game.selected_count = 12
	game.start()
	for id in [0, 1, 3, 4, 5, 8, 9]:
		game.model.try_snap(id, game.model.target(id))
	game._tray()
	game._labels()
	await _capture("10_puzzle_12_parts")
	# Actual ray picking and mouse-to-plane drag, not model-only snapping.
	var picked_id: int = 2
	game.tray_page = 0
	game._tray()
	await physics_frame
	var origin: Vector2 = game.camera.unproject_position(
		game.nodes[picked_id].global_position + Vector3.UP * 0.16
	)
	game._pick(origin, 0)
	assert(game.dragging == picked_id and game.nodes[picked_id].position.y > 0.5)
	var target: Vector2 = game.model.target(picked_id)
	var point: Vector2 = game.camera.unproject_position(Vector3(target.x, 0.35, target.y))
	game._drag(point)
	game._drop()
	assert(game.model.pieces[picked_id].locked, "The real projected drag snaps the picked mesh")
	assert(game._save())
	game._resume()
	assert(game.model.placed() == 8)
	game.selected_count = 96
	game.selected_motif = 1
	game.start()
	for id in range(45):
		game.model.try_snap(id, game.model.target(id))
	game._tray()
	game._labels()
	await _capture("11_puzzle_96_parts")
	game._hint()
	await _capture("12_puzzle_hint")
	game.queue_free()
	await process_frame
	print("[Puzzle] PASS actual picking, lift, drag, snap, JSON resume and 3 screenshots")
	quit(0)


func _capture(name: String) -> void:
	for _i in range(8):
		await process_frame
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and frame.save_png(out_dir + "/" + name + ".png") == OK)
	print("[Puzzle] screenshot: ", name)
