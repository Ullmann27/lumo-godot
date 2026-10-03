extends SceneTree
## Real question events survive engine restart; pause snapshots cannot consume a finish ID.
# gdlint: disable=function-name
class Host:
	extends Node
	var returns: Array[Dictionary] = []
	var rewards: Array[Dictionary] = []
	var return_ack: int = 0
	func returnToApp(_destination: String, value: String) -> int:
		returns.append(JSON.parse_string(value))
		return return_ack
	func reward(value: String) -> int:
		rewards.append(JSON.parse_string(value))
		return 1

func _initialize() -> void:
	call_deferred("_run")

func _ids(events: Array) -> Array:
	return events.map(func(event: Dictionary): return str(event.id))

func _run() -> void:
	var bridge = root.get_node("HostBridge")
	var host := Host.new()
	root.add_child(host)
	bridge._host = host
	bridge._options = {"sessionId": "kart-learning-bridge-test", "soundEnabled": false}
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race({"mode": "learn_cup", "track": "sonnenhafen"})
	game.distance = game.track_length * 2
	game.checkpoint_index = 16
	game._finish()
	assert(game.question_open and game.lesson.visible and game.learning_events.size() == 1)
	assert(game.learning_events[0].type == "started")
	assert(game.learning_events[0].prompt == game.active_question.prompt)
	assert(game.learning_events[0].occurred_at.ends_with("Z"))
	assert("bis 10" in str(game.learning_events[0].unit))
	var correct: String = game.active_question.answer
	var wrong: String = game.active_question.options.filter(func(value): return value != correct)[0]
	game._answer(wrong)
	assert(game.learning_events.size() == 3)
	assert(game.learning_events[1].type == "answered" and not game.learning_events[1].correct)
	assert(game.learning_events[1].answer == wrong and not game.learning_events[1].hint_used)
	assert(game.learning_events[2].type == "hint" and game.learning_events[2].hint == game.lesson_hint.text)
	var visible_hint: String = game.lesson_hint.text
	game._answer(wrong)
	assert(game.learning_events.size() == 4, "An already-visible identical hint is not counted twice")
	assert(game.learning_events[3].hint_used)
	game._pause()
	game._pause()
	assert(game.learning_events.size() == 5)
	var original_race_id: String = game.result_id
	var first_ids: Array = _ids(game.learning_events)
	var paused_payload: Dictionary = game._host_return_payload()
	assert(paused_payload.resultId == original_race_id + "_activity_5")
	game._return_to_app("games")
	assert(host.returns.size() == 1 and host.returns[0].learning_events.size() == 5)
	assert(FileAccess.file_exists(game.SESSION), "Failed native ACK must preserve the question events")
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	assert(_ids(game.learning_events) == first_ids, "Pending events preload even before choosing Resume")
	game._resume_saved_race()
	assert(game.result_id == original_race_id and _ids(game.learning_events) == first_ids)
	assert(game._host_return_payload().resultId == paused_payload.resultId)
	game._resume()
	assert(game.lesson_hint.text == visible_hint)
	assert(game.learning_events.size() == 6 and game.learning_events[5].resumed)
	game._answer(correct)
	assert(game.finished and game.learning_events.size() == 8)
	assert(game.learning_events[6].correct and game.learning_events[7].type == "completed")
	assert(_ids(game.learning_events).slice(0, 5) == first_ids)
	assert(game.result_payload.resultId == original_race_id)
	assert(game.result_payload.learning_events.size() == 8)
	assert(host.rewards.size() == 1 and host.rewards[0].resultId == original_race_id)
	host.return_ack = 1
	game._return_to_app("learn")
	assert(host.returns[-1].status == "completed" and host.returns[-1].resultId == original_race_id)
	DirAccess.make_dir_recursive_absolute("res://exports/holographic-proof")
	var example := FileAccess.open("res://exports/holographic-proof/kart-learning-event-example.json", FileAccess.WRITE)
	example.store_string(JSON.stringify(host.returns[-1], "  "))
	example.close()
	bridge._return_pending = false
	game._next_cup_race()
	await process_frame
	game.distance = game.track_length * 2
	game.checkpoint_index = 16
	game._finish()
	game._skip_question()
	assert(game.finished and game.learning_events.size() == 10)
	assert(game.learning_events[-1].type == "paused" and game.learning_events[-1].reason == "skipped")
	assert(game.learning_events[-1].task_id != game.learning_events[0].task_id)
	assert(_ids(game.learning_events).slice(0, 8) == _ids(host.rewards[0].learning_events))
	game._next_cup_race()
	await process_frame
	game.distance = game.track_length * 2
	game.checkpoint_index = 16
	game._finish()
	game._pause()
	host.return_ack = 0
	game._abandon()
	assert(FileAccess.file_exists(game.SESSION), "Failed abandonment ACK must not erase unsent learning evidence")
	var abandoned_id: String = host.returns[-1].resultId
	assert(host.returns[-1].status == "abandoned" and abandoned_id != game.result_id)
	host.return_ack = 1
	game._return_to_app("games")
	assert(host.returns[-1].resultId == abandoned_id)
	assert(not FileAccess.file_exists(game.SESSION))
	game.abandoned = true
	game.queue_free()
	await process_frame
	bridge._host = null
	bridge._options = {}
	host.queue_free()
	await create_timer(.12).timeout
	print("[KartLearningBridge] PASS: exact start/answer/hint/end, competencies, UTC time, stable resume IDs, distinct snapshot/finish IDs, durable failed return/abandonment, unchanged repeated cup events")
	quit(0)
