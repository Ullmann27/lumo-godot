extends SceneTree
## Race-only host bridge: pause/return/resume keep one result identity, the finish is rewarded
## exactly once, failed native ACKs keep the save, and old learning-cup saves still finish.
# gdlint: disable=function-name
class Host:
	extends Node
	var returns: Array[Dictionary] = []
	var rewards: Array[Dictionary] = []
	var raw: Array[String] = []
	var return_ack: int = 0
	func returnToApp(_destination: String, value: String) -> int:
		raw.append(value)
		returns.append(JSON.parse_string(value))
		return return_ack
	func reward(value: String) -> int:
		raw.append(value)
		rewards.append(JSON.parse_string(value))
		return 1

const LEARNING_FIELDS: Array[String] = ["learning_events", "grade", "subject", "question_open"]
var scene: PackedScene


func _initialize() -> void:
	call_deferred("_run")


func _no_learning_data(payload: Dictionary) -> void:
	for field in LEARNING_FIELDS:
		assert(not payload.has(field), "Kart payload must not carry learning data: " + field)
	# Godot's JSON parser reads every number as float; the engine-side payload must hold an int.
	assert(payload.solved == 0, "Kart reports no solved learning tasks")


func _host_json_is_integer(host) -> void:
	# Dart's jsonDecode only yields an int for "0", not "0.0" (embedded_game_service.dart).
	for value in host.raw:
		var integer: bool = '"solved":0' in value and '"solved":0.0' not in value
		assert(integer, "Host JSON needs an integer solved: " + value)


func _fresh_game():
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	return game


func _drop(game) -> void:
	game.abandoned = true
	game.queue_free()
	await process_frame


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	DirAccess.remove_absolute("user://lumo_host_pending_rewards.cfg")
	var bridge = root.get_node("HostBridge")
	var host := Host.new()
	root.add_child(host)
	bridge._host = host
	# grade/subject still arrive from the host (Jump uses them); Kart must ignore them.
	bridge._options = {
		"sessionId": "kart-race-bridge-test", "soundEnabled": false, "grade": 3, "subject": "Deutsch"
	}
	scene = load("res://scenes/games/kart_island.tscn")
	var game = await _fresh_game()
	for entry in game.CATALOG.MODES:
		assert(str(entry.id) != "learn_cup", "No learning cup in the mode list")
	# 1) Race, pause, failed native return: the save and the identity survive.
	game._start_selected_race({"mode": "race", "track": "sonnenhafen"})
	game.countdown = 0
	game.racing = true
	game._physics_process(0.5)
	var race_id: String = game.result_id
	game._pause()
	var paused_payload: Dictionary = game._host_return_payload()
	assert(paused_payload.status == "paused" and paused_payload.resultId == race_id)
	_no_learning_data(paused_payload)
	game._return_to_app("games")
	assert(host.returns.size() == 1 and host.returns[0].status == "paused")
	assert(FileAccess.file_exists(game.SESSION), "Failed native ACK must keep the race save")
	bridge._return_pending = false
	await _drop(game)
	# 2) Resume keeps the identity, the finish is rewarded once, the return succeeds.
	game = await _fresh_game()
	assert(game.menu_active and game.saved_session_available)
	game._resume_saved_race()
	assert(game.paused and game.result_id == race_id and not game.finished)
	game._resume()
	assert(not game.paused and game.racing)
	game.distance = game.track_length * 2
	game.checkpoint_index = 16
	game._finish()
	assert(game.finished and game.result_payload.status == "completed")
	assert(game.result_payload.resultId == race_id and game.result_payload.stars == 3)
	_no_learning_data(game.result_payload)
	assert(game.result_payload.solved is int, "The engine-side result keeps an integer solved")
	assert(host.rewards.size() == 1 and host.rewards[0].resultId == race_id)
	game._finish()
	assert(host.rewards.size() == 1, "A finished race is rewarded once")
	host.return_ack = 1
	game._return_to_app("learn")
	assert(host.returns[-1].status == "completed" and host.returns[-1].resultId == race_id)
	DirAccess.make_dir_recursive_absolute("res://exports/holographic-proof")
	var example := FileAccess.open(
		"res://exports/holographic-proof/kart-race-result-example.json", FileAccess.WRITE
	)
	# Exact bytes the native host received for the completed race.
	example.store_string(host.raw[-1])
	example.close()
	bridge._return_pending = false
	await _drop(game)
	# 3) Star cup: no task between races, every race starts with one boost, the cup save stays.
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = await _fresh_game()
	game._start_selected_race({"mode": "cup", "track": "zauberwald"})
	assert(game.mode == "cup" and game.track_id == game.CATALOG.TRACKS[0].id)
	for round_index in range(2):
		game.countdown = 0
		game.racing = true
		game.distance = game.track_length * 2
		game.checkpoint_index = 16
		game._finish()
		assert(game.finished and game.pending_cup_next and game.cup_results.size() == round_index + 1)
		_no_learning_data(game.result_payload)
		game._next_cup_race()
		await process_frame
		assert(game.boosts == 1 and not game.finished and game.cup_index == round_index + 1)
	# 4) Abandon with a failed ACK keeps the save; the confirmed retry removes it.
	game.countdown = 0
	game.racing = true
	game._pause()
	host.return_ack = 0
	game._abandon()
	assert(FileAccess.file_exists(game.SESSION), "Failed abandonment ACK keeps the save")
	assert(host.returns[-1].status == "abandoned" and host.returns[-1].resultId == game.result_id)
	_no_learning_data(host.returns[-1])
	host.return_ack = 1
	game._return_to_app("games")
	assert(host.returns[-1].status == "abandoned")
	assert(not FileAccess.file_exists(game.SESSION))
	bridge._return_pending = false
	await _drop(game)
	# 5) A version-3 save from the removed learning cup, stored after the finish line while its
	#    question was open, resumes as a plain star-cup result instead of a stuck task.
	game = await _fresh_game()
	game._start_selected_race({"mode": "cup", "track": "sonnenhafen"})
	game.countdown = 0
	game.racing = true
	game._save_session()
	var legacy_id: String = game.result_id
	var legacy := ConfigFile.new()
	assert(legacy.load(game.SESSION) == OK)
	legacy.set_value("race", "version", 3)
	legacy.set_value("race", "mode", "learn_cup")
	legacy.set_value("race", "grade", 2)
	legacy.set_value("race", "subject", "Deutsch")
	legacy.set_value("race", "question_open", true)
	legacy.set_value("race", "completed_race", true)
	legacy.set_value("race", "distance", game.track_length * 2)
	legacy.set_value("race", "checkpoint_index", 16)
	legacy.set_value("race", "learning_events", [{"id": legacy_id + "_learning_1", "type": "started"}])
	assert(legacy.save(game.SESSION) == OK)
	await _drop(game)
	var rewards_before: int = host.rewards.size()
	game = await _fresh_game()
	assert(game.saved_session_available, "A version-3 save is still offered")
	game._resume_saved_race()
	assert(game.mode == "cup" and game.finished and game.result_id == legacy_id)
	assert(game.modal.visible and host.rewards.size() == rewards_before + 1)
	_no_learning_data(game.result_payload)
	await _drop(game)
	_host_json_is_integer(host)
	assert(host.raw.size() >= 8, "Every pause, return, reward and abandonment reached the host")
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	bridge._host = null
	bridge._options = {}
	host.queue_free()
	scene = null
	# Five scenes played garage music; the audio mix thread releases those playbacks late.
	await create_timer(0.5).timeout
	print(
		(
			"[KartRaceBridge] PASS: no learning data, stable pause/return/resume ID, one reward, "
			+ "solved int, failed ACK keeps save, star cup without tasks, "
			+ "legacy learning-cup save finishes"
		)
	)
	quit(0)
