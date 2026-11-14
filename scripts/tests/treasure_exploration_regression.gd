extends SceneTree
## The two playable middle routes share the original rules, saves and reward path.
const STATE = preload("res://scripts/creative/treasure_state.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_warning("[TreasureExploration] FAIL " + label)


func _run() -> void:
	for route in [[0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 4, 3, 5, 6]]:
		var model = STATE.new()
		_check(not model.can_interact(STATE.CLUES[4].at), "garden cannot bypass bridge prerequisites")
		for index in route:
			var clue: Dictionary = STATE.CLUES[index]
			_check(model.answer(int(clue.correct), clue.at), "both complete exploration orders are playable")
		_check(model.completed and model.reward_xp() == 48, "both routes preserve original seven-clue perfect reward")
		_check(not model.answer(STATE.CLUES[6].correct, STATE.CLUES[6].at), "completed treasure cannot be claimed by answering again")
	var branch = STATE.new()
	for index in range(3):
		branch.answer(STATE.CLUES[index].correct, STATE.CLUES[index].at)
	_check(branch.available_clues().size() == 2, "bridge opens both real locations")
	_check(branch.clue_at(STATE.CLUES[4].at).id == "garden", "actual visited location selects its question")
	_check(branch.answer(STATE.CLUES[4].correct, STATE.CLUES[4].at), "garden can be solved before crystals")
	_check(branch.chapter == 3 and branch.found.size() == 4, "legacy chapter remains a truthful contiguous prefix")
	_check(not branch.can_interact(STATE.CLUES[5].at), "castle still requires both branch keys")
	_check(not branch.can_interact(STATE.CLUES[4].at), "completed branch cannot duplicate items")
	var data: Dictionary = JSON.parse_string(JSON.stringify(branch.to_data()))
	var restored = STATE.new()
	_check(restored.restore(data), "branch order survives real JSON decoding")
	_check(restored.inventory.has("Mondblüte") and not restored.inventory.has("Kristallstern"), "resume preserves the actual collected branch item")
	_check(restored.current().id == "crystals", "resume guides toward the remaining route")
	var before: String = JSON.stringify(restored.to_data())
	for solved in [
		["tree", "waterfall", "bridge", "garden", "garden"],
		["tree", "waterfall", "garden"],
		["tree", "waterfall", "bridge", "castle"],
		["tree", "waterfall", "bridge", "unknown"],
		["tree", "waterfall", "bridge", 4],
		"garden"
	]:
		var bad: Dictionary = data.duplicate(true)
		bad.solved_clues = solved
		_check(not restored.restore(bad), "malformed or dependency-breaking route is rejected")
		_check(JSON.stringify(restored.to_data()) == before, "invalid branch save leaves current game untouched")
	var mismatch: Dictionary = data.duplicate(true)
	mismatch.chapter = 4
	_check(not restored.restore(mismatch), "conflicting legacy prefix is rejected")
	for count in range(8):
		var legacy := {"version": 1, "chapter": count, "position": [0.0, 0.05, 6.0], "result_id": "legacy"}
		_check(restored.restore(legacy), "all original chapter-only saves still load")
		_check(restored.found.size() == count and restored.chapter == count, "old progress remains exact")
	await _play_scene()
	if failures.is_empty():
		print("[TreasureExploration] PASS %d checks: branching, actual location questions, movement, legacy saves and original rewards" % checks)
		quit(0)
	else:
		print("[TreasureExploration] FAIL ", failures)
		quit(1)


func _play_scene() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute("user://lumo_treasure_exploration_regression.json")
	root.get_node("SceneRouter").launch_options = {"childKey": "exploration_regression"}
	var game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await _settle(4)
	var wonder = game.get_node("MagicalGuidance")
	_check(wonder.route_count() == 1, "magical trail follows the first real clue")
	_check(wonder.get_node("GuideGold") is MultiMeshInstance3D, "real instanced 3D wayfinding exists")
	for index in range(3):
		await _answer_at(game, index)
	_check(game.available_goals.size() == 2 and game.alternate_marker.visible, "real scene displays both unlocked goals")
	_check(wonder.route_count() == 2, "two magic trails guide both unlocked branches")
	_check(game.has_node("TreasureBranchPaths/Path_crystals") and game.has_node("TreasureBranchPaths/Path_garden"), "both choices have real instanced 3D trail geometry")
	game.player.position = Vector3(0, 0.05, -33)
	game.player.velocity = Vector3.ZERO
	var from: Vector3 = game.player.position
	var press := InputEventScreenTouch.new()
	press.index = 8
	press.pressed = true
	press.position = game.joystick.size * 0.5 + Vector2(0.65, -0.75) * game.joystick.size.x * 0.31
	game.joystick._gui_input(press)
	await _settle(40)
	var release := InputEventScreenTouch.new()
	release.index = 8
	release.pressed = false
	release.position = press.position
	game.joystick._gui_input(release)
	_check(game.player.position.distance_to(from) > 1.8, "live joystick and character collision move along the choice area")
	await _capture("treasure_choose_route")
	await _answer_at(game, 4)
	_check(game.model.inventory.has("Mondblüte") and not game.model.inventory.has("Kristallstern"), "native question UI accepts garden as first route")
	_check(not game.alternate_marker.visible and game.available_goals[0].id == "crystals", "scene removes completed goal and keeps remaining objective")
	_check(wonder.route_count() == 1, "solved route no longer shows stars")
	_check(game._save(), "chosen branch saves through live world")
	var recovered = STATE.new()
	_check(recovered.restore(JSON.parse_string(FileAccess.get_file_as_string(game.save_path))) and recovered.found.has("garden"), "live world save resumes chosen branch")
	await _capture("treasure_garden_first")
	for index in [3, 5, 6]:
		await _answer_at(game, index)
	_check(game.model.completed and game.model.inventory.has("Sternenschatz"), "alternative route reaches the original treasure completion")
	_check(wonder.route_count() == 0, "completed quest clears magic routes")
	await _capture("treasure_route_complete")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_treasure_exploration_regression.json")


func _answer_at(game: Node, index: int) -> void:
	var clue: Dictionary = STATE.CLUES[index]
	game.player.position = clue.at + Vector3.UP * 0.05
	game.player.velocity = Vector3.ZERO
	game._interact()
	_check(game.paused and game.modal.visible, "real location opens the question dialog")
	if not game.paused or not game.modal.visible:
		return
	var title: Label = game.modal_box.get_child(0)
	_check(title.text == str(clue.name), "dialog question belongs to visited location")
	var answer: Button = game.modal_box.get_child(2 + int(clue.correct))
	answer.pressed.emit()
	_check(game.model.found.has(str(clue.id)), "actual answer button grants that location's item")
	await _settle(3)


func _settle(frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		await process_frame


func _capture(name: String) -> void:
	var folder := OS.get_environment("TREASURE_EXPLORATION_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "renderer image written")
