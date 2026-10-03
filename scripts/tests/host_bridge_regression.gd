extends SceneTree
# Native Java API method names intentionally match the actual plugin contract.
# gdlint: disable=function-name
## Contract/lifecycle regression for Flutter's native LumoHost plugin.


class FakeHost:
	extends Node
	var rewards: Array[Dictionary] = []
	var returns: Array[Dictionary] = []
	var accept_rewards: bool = true

	func getLaunchOptions() -> String:
		return JSON.stringify(
			{"game": "kart", "grade": 4, "subject": "Logik", "sessionId": "host-test", "stars": 31}
		)

	func reward(payload: String) -> bool:
		if not accept_rewards:
			return false
		rewards.append(JSON.parse_string(payload))
		return true

	func returnToApp(destination: String, payload: String) -> void:
		returns.append({"destination": destination, "payload": JSON.parse_string(payload)})


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	var bridge = root.get_node("HostBridge")
	assert(not bridge.is_embedded(), "Standalone has no native host")
	assert(not bridge.return_to_app("games"))
	var fake := FakeHost.new()
	root.add_child(fake)
	bridge._host = fake
	bridge._options = bridge.validated_options(JSON.parse_string(fake.getLaunchOptions()))
	assert(bridge.is_embedded())
	root.get_node("ProgressStore").synchronize_host_wallet()
	assert(root.get_node("ProgressStore").total_stars() == 31)
	fake.accept_rewards = false
	assert(not bridge.reward({"resultId": "retry-test", "stars": 3}))
	assert(not bridge._result_ids.has("retry-test"))
	fake.accept_rewards = true
	assert(bridge.reward({"resultId": "retry-test", "stars": 3}))
	assert(fake.rewards.size() == 1)
	fake.rewards.clear()
	assert(bridge.launch_options().scene == "kart")
	assert(bridge.launch_options().grade == 4 and bridge.launch_options().subject == "Logik")
	var invalid: Dictionary = bridge.validated_options(
		{"grade": 99, "stars": -2, "game": "unknown", "subject": "unknown"}
	)
	assert(
		(
			invalid.grade == 4
			and invalid.stars == 0
			and invalid.scene == "kart"
			and invalid.subject == "Mathematik"
		)
	)
	root.get_node("SceneRouter").launch_options = bridge.launch_options()
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.countdown = 0
	game.racing = true
	assert(game.grade == 4 and game.subject == "Logik")
	var first_id: String = game.result_id
	game._physics_process(1.0)
	var before: float = game.distance
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(game.paused and FileAccess.file_exists(game.SESSION))
	game._physics_process(1.0)
	assert(game.distance == before)
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(fake.returns.size() == 1 and fake.returns[0].destination == "games")
	assert(fake.returns[0].payload.status == "paused" and fake.rewards.is_empty())
	game.abandoned = true
	game.queue_free()
	await process_frame
	bridge._return_pending = false
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.paused and game.result_id == first_id, "Resume preserves reward identity")
	game._resume()
	game.correct_count = 3
	game._finish()
	assert(fake.rewards.size() == 1 and fake.rewards[0].stars == 9)
	assert(fake.rewards[0].resultId == first_id and fake.rewards[0].status == "completed")
	game._finish()
	bridge.reward(game.result_payload)
	assert(fake.rewards.size() == 1, "Completed reward must be idempotent")
	game._return_to_app("learn")
	assert(fake.returns.size() == 2 and fake.returns[1].destination == "learn")
	assert(fake.returns[1].payload.resultId == first_id and fake.returns[1].payload.stars == 9)
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.result_id != first_id, "Restart creates a fresh reward identity")
	game.abandoned = true
	game.queue_free()
	await process_frame
	print(
		(
			"[HostBridgeTests] PASS: native options, lifecycle save/pause, Back, resume identity, "
			+ "reward retry/once, games/learn return, fresh restart"
		)
	)
	bridge._return_pending = false
	DirAccess.remove_absolute("user://jump_session.cfg")
	var jump_scene = load("res://scenes/games/jump_islands.tscn")
	game = jump_scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.checkpoint = 3
	game._open_question()
	var question: String = game.active_question.answer
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(game.paused and game.question_open)
	game._resume()
	assert(game.active_question.answer == question)
	game._answer(question)
	game._answer(question)
	assert(game.completed_questions.size() == 1)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var jump_id: String = game.result_id
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = jump_scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.paused and game.checkpoint == 3 and game.result_id == jump_id)
	game._finish()
	assert(fake.rewards.size() == 2 and fake.rewards[1].game == "jump")
	assert(fake.rewards[1].resultId == jump_id and fake.rewards[1].solved == 1)
	game._finish()
	assert(fake.rewards.size() == 2)
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(fake.returns.size() == 3 and fake.returns[2].destination == "games")
	assert(fake.returns[2].payload.game == "jump" and fake.returns[2].payload.status == "completed")
	game.queue_free()
	await process_frame
	print(
		"[HostBridgeTests] PASS: jump native reward, question pause, save/resume identity, Back to games"
	)
	quit(0)
