extends SceneTree
## Runde 3: flachere Startkamera, Entdeckungen, Hinweis-Serie.
## Bestehende Saves, Hinweise und Reward-Schlüssel bleiben gültig.

const STATE = preload("res://scripts/creative/treasure_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_legacy_clues_and_saves()
	_streak_bonus()
	_discoveries()
	await _world_camera_and_reward()
	print("[TreasureIsland] PASS flatter camera, discoveries, streak, save/reward compatibility")
	quit(0)


func _legacy_clues_and_saves() -> void:
	var adventure := STATE.new()
	assert(not adventure.answer(0, Vector3.ZERO), "Clues require approaching the actual location")
	for clue in STATE.CLUES:
		assert(not adventure.answer((int(clue.correct) + 1) % 3, clue.at))
		assert(adventure.answer(int(clue.correct), clue.at))
	assert(adventure.completed and adventure.inventory.has("Sternenschatz"))
	assert(adventure.reward_xp() == 40, "Wrong-then-right run keeps base XP")
	var recovered := STATE.new()
	assert(recovered.restore(adventure.to_data()) and recovered.completed)
	var invalid: Dictionary = adventure.to_data()
	invalid.chapter = 20
	assert(not recovered.restore(invalid) and recovered.completed)
	var old_save := {
		"version": 1,
		"chapter": 2,
		"position": [0.0, 0.05, -10.0],
		"result_id": "legacy-treasure",
		"wrong_attempts": 1
	}
	var loaded := STATE.new()
	assert(loaded.restore(old_save))
	assert(loaded.chapter == 2)
	assert(loaded.inventory.has("Blattschlüssel") and loaded.inventory.has("Sonnenkompass"))
	assert(loaded.discoveries.is_empty())
	assert(loaded.streak == 0 and loaded.best_streak == 0)
	assert(loaded.reward_xp() == 40)
	assert(int(old_save.chapter) == 2)


func _streak_bonus() -> void:
	var model := STATE.new()
	for i in range(3):
		var clue: Dictionary = STATE.CLUES[i]
		assert(model.answer(int(clue.correct), clue.at))
	assert(model.streak == 3 and model.best_streak == 3)
	assert(model.last_cheer == 3)
	assert(model.streak_xp() == 3)
	assert(model.reward_xp() == 43)
	assert(not model.answer((int(STATE.CLUES[3].correct) + 1) % 3, STATE.CLUES[3].at))
	assert(model.streak == 0)
	assert(model.best_streak == 3)
	assert(model.reward_xp() == 43)
	var perfect := STATE.new()
	for clue in STATE.CLUES:
		assert(perfect.answer(int(clue.correct), clue.at))
	assert(perfect.completed)
	assert(perfect.best_streak == 7)
	assert(perfect.last_cheer == 7)
	assert(perfect.streak_xp() == 8)
	assert(perfect.reward_xp() == 48)


func _discoveries() -> void:
	var model := STATE.new()
	assert(model.try_discover(Vector3(0, 0.05, 6)) == "", "Spawn does not auto-collect the nearby compass")
	assert(model.try_discover(Vector3(2.45, 0, 4.55)) == "Kompass-Sockel")
	assert(model.discoveries == ["compass"])
	assert(model.try_discover(Vector3(2.45, 0, 4.55)) == "", "Discoveries are granted once")
	assert(model.try_discover(Vector3(0, 0, 1.35)) == "Willkommensbogen")
	assert(model.try_discover(Vector3(-12.5, 0, 2.2)) == "Start-Wasserfall")
	assert(model.discoveries.size() == 3)
	assert(model.discovery_xp() == 6)
	assert(model.chapter == 0 and model.inventory.is_empty())
	assert(model.reward_xp() == 46)
	var data: Dictionary = model.to_data()
	var restored := STATE.new()
	assert(restored.restore(data))
	assert(restored.discoveries.size() == 3)
	assert(restored.discovery_xp() == 6)


func _world_camera_and_reward() -> void:
	var game: Node = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.get_node("SceneRouter").launch_options = {"childKey": "treasureregession"}
	root.add_child(game)
	for _i in range(6):
		await process_frame
	assert(game.CAMERA_OFFSET.y <= 8.0, "Start camera is flatter than the R2 steep view")
	assert(game.CAMERA_OFFSET.y < 14.0)
	assert(game.camera.position.y < game.player.position.y + 9.0)
	game.player.position = Vector3(2.45, 0.05, 4.55)
	assert(game.model.try_discover(game.player.position) == "Kompass-Sockel")
	var seed_path := "user://lumo_treasure_treasureregession.json"
	game.save_path = seed_path
	for clue in STATE.CLUES:
		assert(game.model.answer(int(clue.correct), clue.at))
	assert(game.model.completed)
	assert(game.model.reward_xp() == 40 + 8 + 2)
	var seen: Dictionary = {}
	var bridge: Node = root.get_node("HostBridge")
	var on_reward := func(payload: Dictionary) -> void:
		seen.clear()
		for key in payload:
			seen[key] = payload[key]
	bridge.reward_reported.connect(on_reward)
	game._win()
	if seen.is_empty():
		push_error("[TreasureIsland] Reward wallet emitted no payload")
		quit(1)
		return
	assert(seen.get("game", "") == "treasure")
	assert(seen.get("status", "") == "completed")
	assert(int(seen.get("stars", 0)) == 3)
	assert(int(seen.get("xp", 0)) == game.model.reward_xp())
	assert(seen.has("resultId") and str(seen.get("resultId", "")) != "")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(seed_path))
	assert(saved is Dictionary)
	assert(int(saved.get("chapter", 0)) == STATE.CLUES.size())
	assert(saved.get("discoveries", []) is Array)
	DirAccess.remove_absolute(seed_path)
	if bridge.reward_reported.is_connected(on_reward):
		bridge.reward_reported.disconnect(on_reward)
	game.queue_free()
	await process_frame
