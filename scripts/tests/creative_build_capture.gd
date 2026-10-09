extends SceneTree
## Actual frame captures plus collision/support/undo/save checks for Bauwelt.
const STATE = preload("res://scripts/creative/build_state.gd")
var out_dir: String = "res://exports/creative-build"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state = STATE.new()
	assert(not state.place("stone", Vector3i(0, 0, 0)).is_empty(), "Blocks cannot float over water")
	assert(state.place("stone", Vector3i(-4, 0, 0)).is_empty())
	assert(not state.place("wood", Vector3i(-4, 0, 0)).is_empty(), "Overlapping volumes rejected")
	assert(state.place("stone", Vector3i(-4, 1, 0)).is_empty())
	assert(
		not state.remove(int(state.pieces[0].uid)),
		"A load-bearing part cannot leave floating blocks"
	)
	assert(state.undo() and state.pieces.size() == 1)
	assert(state.redo() and state.pieces.size() == 2)
	state.template("bridge")
	assert(state.challenge_passes("bridge"), "Continuous river crossing is traversable")
	assert(state.bridge_path().size() >= 6)
	state.remove(int(state.pieces[1].uid))
	assert(not state.challenge_passes("bridge"), "Incomplete river crossing is not a goal")
	state.template("house")
	assert(state.challenge_passes("house"))
	for piece in state.pieces.duplicate(true):
		if piece.part == "door":
			state.remove(int(piece.uid))
	assert(not state.challenge_passes("house"), "Walls and roof without a door are not a house")
	state.template("castle")
	assert(state.challenge_passes("castle"))
	assert(state.pieces.size() > 140)
	state.template("village")
	assert(state.challenge_passes("village"))
	state.template("tower")
	assert(state.challenge_passes("tower"))
	var restored = STATE.new()
	assert(restored.restore(state.to_data()))
	assert(restored.challenge_passes("tower"))
	var bad: Dictionary = state.to_data()
	bad.pieces.append(bad.pieces[0].duplicate(true))
	assert(not restored.restore(bad), "Malformed reload cannot duplicate overlapping objects")
	assert(restored.challenge_passes("tower"), "Rejected reload preserves open world")
	print(
		"[CreativeBuild] PASS: support, collision, crossing, meaningful goals, undo/redo, rejected corrupt save"
	)
	if "--logic-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = "user://creative_build_qa.json"
	game.model.template("castle")
	game.model.place("tree", Vector3i(-11, 0, 3))
	game.model.place("lantern", Vector3i(-4, 0, -4))
	game.model.place("flowers", Vector3i(-7, 0, 1))
	game._rebuild()
	game.focus = Vector3(-6, 2, -4)
	game.radius = 29
	game._camera_update()
	await _capture("01_bauwelt_house")
	game.model.place("bridge", Vector3i(-1, 0, 2))
	game.model.place("bridge", Vector3i(2, 0, 2))
	game._rebuild()
	assert(game.save_world(false))
	var expected: int = game.model.pieces.size()
	game.model.clear()
	assert(game.load_world(false))
	assert(game.model.pieces.size() == expected and game.model.challenge_passes("bridge"))
	game._test_challenge()
	await _capture("02_bauwelt_bridge_test")
	game.model.template("tower")
	game.goal = "tower"
	game.focus = Vector3(-6, 2, 1)
	game.radius = 16
	game._rebuild()
	game._camera_update()
	await _capture("03_bauwelt_tower")
	game._pause(true)
	await _capture("04_bauwelt_pause")
	assert(game.paused)
	game._pause(false)
	assert(not game.paused)
	game.queue_free()
	await process_frame
	print(
		"[CreativeBuild] PASS: actual world, successful JSON reload, pause, 4 rendered screenshots"
	)
	quit(0)


func _capture(name: String) -> void:
	for _i in range(8):
		await process_frame
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and frame.get_width() == 1280 and frame.get_height() == 720)
	assert(frame.save_png(out_dir + "/" + name + ".png") == OK)
	print("[CreativeBuild] screenshot:", name)
