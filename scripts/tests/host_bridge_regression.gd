extends SceneTree
# Native Java API method names intentionally match the actual plugin contract.
# gdlint: disable=function-name
## Contract/lifecycle regression for Flutter's native LumoHost plugin.


class FakeHost:
	extends Node
	var rewards: Array[Dictionary] = []
	var returns: Array[Dictionary] = []
	var accept_rewards: bool = true
	var accept_returns: bool = true

	func getLaunchOptions() -> String:
		return JSON.stringify(
			{"game": "kart", "grade": 4, "subject": "Logik", "sessionId": "host-test", "stars": 31}
		)

	func reward(payload: String) -> bool:
		if not accept_rewards:
			return false
		rewards.append(JSON.parse_string(payload))
		return true

	func returnToApp(destination: String, payload: String) -> bool:
		if not accept_returns:
			return false
		returns.append({"destination": destination, "payload": JSON.parse_string(payload)})
		return true


func _initialize() -> void:
	call_deferred("_run")


func _android_back() -> void:
	# Match Godot Window::_event_callback: notify the scene first, then emit
	# the actual signal connected to SceneTree's independent auto-quit handler.
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	root.go_back_requested.emit()
	# A SceneTree quit is applied at the end of the frame; survive that frame.
	await create_timer(0.05).timeout


func _run() -> void:
	var original_auto_quit: bool = auto_accept_quit
	var original_back_quit: bool = quit_on_go_back
	assert(original_back_quit, "Exercise the real default Android Back auto-quit")
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	DirAccess.remove_absolute("user://lumo_host_pending_rewards.cfg")
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
	var retry_payload := {
		"resultId": "retry-test", "status": "completed", "game": "kart", "stars": 3, "solved": 0
	}
	assert(not bridge.reward(retry_payload))
	assert(not bridge._result_ids.has("retry-test"))
	fake.accept_rewards = true
	assert(bridge.reward(retry_payload))
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
	assert(not auto_accept_quit and not quit_on_go_back)
	# The KVM failure occurred during the real countdown, before racing began.
	game.countdown = 3.0
	await _android_back()
	assert(game.paused and game.countdown == 3.0 and fake.returns.is_empty())
	await process_frame
	game._resume()
	game._open_question()
	var kart_question: String = game.active_question.answer
	await _android_back()
	assert(game.paused and game.question_open and fake.returns.is_empty())
	await process_frame
	game._resume()
	assert(game.question_open and game.active_question.answer == kart_question)
	game._skip_question()
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
	await _android_back()
	assert(fake.returns.size() == 1 and fake.returns[0].destination == "games")
	assert(fake.returns[0].payload.status == "paused" and fake.rewards.is_empty())
	game.abandoned = true
	game.queue_free()
	await process_frame
	assert(auto_accept_quit == original_auto_quit and quit_on_go_back == original_back_quit)
	bridge._return_pending = false
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.paused and game.result_id == first_id, "Resume preserves reward identity")
	game._resume()
	game.correct_count = 3
	fake.accept_rewards = false
	game._finish()
	assert(fake.rewards.is_empty())
	assert(
		bridge.reward_is_recoverable(first_id), "Failed host reward has a durable completed backup"
	)
	assert(FileAccess.file_exists(bridge.PENDING_REWARDS))
	var recovered = bridge.get_script().new()
	root.add_child(recovered)
	recovered._host = fake
	recovered._options = bridge.launch_options()
	recovered._load_pending_rewards()
	assert(recovered._pending_rewards[first_id].status == "completed")
	assert(recovered._pending_rewards[first_id].stars == 9)
	assert(not recovered.retry_pending_rewards(), "Another failed host write keeps the backup")
	recovered.queue_free()
	await process_frame
	game._return_to_app("learn")
	assert(fake.returns.size() == 1 and not bridge._return_pending)
	assert(game.finished and game.modal.visible and game.message.text == bridge.SAVE_FAILURE)
	assert(game.modal_column.has_node("HostSaveFailure"))
	fake.accept_rewards = true
	fake.accept_returns = false
	game._return_to_app("learn")
	assert(fake.returns.size() == 1 and not bridge._return_pending)
	assert(
		game.finished and game.modal.visible,
		"Failed native final return leaves result and engine usable"
	)
	assert(fake.rewards.size() == 1 and fake.rewards[0].stars == 9)
	assert(fake.rewards[0].resultId == first_id and fake.rewards[0].status == "completed")
	game._finish()
	bridge.reward(game.result_payload)
	assert(fake.rewards.size() == 1, "Completed reward must be idempotent")
	fake.accept_returns = true
	game._return_to_app("learn")
	assert(not FileAccess.file_exists(bridge.PENDING_REWARDS))
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
	await _android_back()
	assert(game.paused and game.question_open)
	assert(not auto_accept_quit and not quit_on_go_back)
	await process_frame
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
	await _android_back()
	assert(fake.returns.size() == 3 and fake.returns[2].destination == "games")
	assert(fake.returns[2].payload.game == "jump" and fake.returns[2].payload.status == "completed")
	game.queue_free()
	await process_frame
	assert(auto_accept_quit == original_auto_quit and quit_on_go_back == original_back_quit)
	print(
		"[HostBridgeTests] PASS: jump native reward, question pause, save/resume identity, Back to games"
	)
	quit(0)
