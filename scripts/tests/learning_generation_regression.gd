extends SceneTree
const SCOPE = preload("res://scripts/learning/learning_companion_scope.gd")
const MODEL = preload("res://scripts/learning/learning_activity.gd")
const WORLD := "res://scenes/learning/learning_world.tscn"
var checks := 0
var failures: Array[String] = []


class Host:
	extends RefCounted
	var context: Dictionary = {}
	var question: Dictionary = {}
	var response: Dictionary = {}
	var audio: Dictionary = {}
	var audio_state := "preparing"
	var stops := 0

	func updateLearningContext(payload: String) -> int:
		context = JSON.parse_string(payload)
		return 1

	func requestLearningConversation(payload: String) -> int:
		question = JSON.parse_string(payload)
		return 1

	func getLearningConversationStatus() -> String:
		return JSON.stringify(response)

	func stopLearningConversation() -> void:
		stops += 1

	func speakLearning(payload: String) -> int:
		audio = JSON.parse_string(payload)
		audio_state = "preparing"
		return 1

	func stopLearningSpeech() -> void:
		stops += 1

	func getLearningSpeechStatus() -> String:
		var result := audio.duplicate(true)
		result.merge(
			{
				"state": audio_state,
				"positionMs": 250,
				"durationMs": 1000,
				"audible": audio_state == "playing",
				"envelopeAvailable": true,
				"envelope": 0.8
			},
			true
		)
		return JSON.stringify(result)


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[LearningGeneration] " + label)


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _scene(payload: Dictionary, task: String) -> Node3D:
	var game := load(WORLD).instantiate() as Node3D
	var scoped := payload.duplicate(true)
	scoped["allowedActions"] = ["explain", "repeat", "slower", "hint", "stop", "proposeAnswer"]
	scoped["scope"] = {
		"protocolVersion": 1,
		"sessionId": "test-session",
		"taskId": task,
		"revision": 3,
		"cancelEpoch": 0
	}
	game.capture_options = {
		"learning": scoped,
		"sessionId": "native-session",
		"reduceAnimations": true,
		"learningVoiceEnabled": true,
		"localVoiceLicenseAccepted": true,
		"learningAutoRead": false
	}
	root.add_child(game)
	return game


func _run() -> void:
	var scope = SCOPE.new()
	_check(
		scope.configure(
			{
				"protocolVersion": 1,
				"sessionId": "s",
				"taskId": "t",
				"revision": 1,
				"cancelEpoch": 0,
				"allowedActions": ["point", "explain", "hint", "repeat", "slower", "stop"]
			},
			"",
			""
		),
		"valid v1 context accepted"
	)
	scope.object_ids.assign(["ten_frame"])
	var response: Dictionary = scope.envelope(1)
	response.merge(
		{"reply": "Schau auf das Zehnerfeld.", "action": "point", "objectId": "ten_frame"}
	)
	_check(scope.permits_reply(response, 1), "checked current object accepted")
	var invented := response.duplicate(true)
	invented.objectId = "invented-reward"
	_check(not scope.permits_reply(invented, 1), "unknown object rejected")
	invented = response.duplicate(true)
	invented.action = "grantReward"
	_check(not scope.permits_reply(invented, 1), "reward commands rejected")
	for key in ["sessionId", "taskId", "revision", "cancelEpoch"]:
		var stale := response.duplicate(true)
		stale[key] = "old" if key in ["sessionId", "taskId"] else 99
		_check(not scope.permits_reply(stale, 1), "stale " + key + " rejected")
	scope.cancel()
	_check(not scope.permits_reply(response, 1), "stop invalidates pending reply")
	_check(
		not scope.configure({"protocolVersion": 2}, "s", "t") and not scope.valid,
		"unsupported protocol invalidates previous context"
	)
	var model = MODEL.new()
	var pattern := {
		"kind": "pattern",
		"period": 2,
		"sequence": ["red_circle", "blue_square", "red_circle", "blue_square"],
		"choices": ["red_circle", "blue_square", "yellow_triangle"]
	}
	_check(model.configure(pattern), "real repeated pattern validates")
	var broken := pattern.duplicate(true)
	broken.sequence[3] = "yellow_triangle"
	_check(not model.configure(broken), "incorrect declared pattern rejected")
	broken = pattern.duplicate(true)
	broken.patternChoices = ["blue_square", "yellow_triangle"]
	_check(not model.configure(broken), "pattern without possible next choice rejected")
	var game := _scene({"kind": "bridge_ten", "a": 8, "b": 5}, "eight-plus-five")
	await _settle()
	var host := Host.new()
	game._speech_host = host
	game._sync_companion_context()
	_check(
		game.companion_scope.session_id == "native-session",
		"native launch session replaces caller transport identity"
	)
	_check(game.fox.is_usable(), "original 65-bone teacher available in actual scene")
	_check(
		game.companion_objects.has_all(["ten_frame", "addend", "bridge_two", "remainder_three"]),
		"required 8+5 objects bound to actual scene"
	)
	game._request_conversation("Warum zuerst zwei?", "explain")
	host.response = host.question.duplicate(true)
	host.response.merge(
		{
			"state": "ready",
			"reply": "Zehn minus acht ist zwei. Von fünf bleiben drei übrig.",
			"action": "explain",
			"objectId": "bridge_two"
		},
		true
	)
	game._tick_conversation(0.11)
	await _settle()
	_check(
		game.activity.placed.size() == 2 and game.tokens.size() - game.activity.placed.size() == 3,
		"why explanation moves exactly two and leaves three"
	)
	_check(
		host.audio.get("text", "").contains("zwei"), "current explanation reaches actual audio API"
	)
	host.audio_state = "playing"
	game.fox.set_reduced_motion(false)
	game._tick_speech(0.06)
	game.fox._process(0.06)
	_check(
		game.fox.audio_active and game.fox.facial_pose.jaw > 0.0,
		"real playback sample drives actual mouth morph"
	)
	var old_response := host.response.duplicate(true)
	game._explicit_stop()
	_check(
		(
			game.fox.current_behavior == "idle"
			and not game.fox.teacher_pose.has_target
			and not game.fox.facial_pose.has_target
			and not game.fox.audio_active
			and game.fox.facial_pose.jaw == 0.0
		),
		"stop jointly neutralizes gesture gaze and mouth"
	)
	_check(
		not game._apply_conversation_reply(old_response),
		"cancelled response cannot reopen old gesture"
	)
	_check(game.activity.placed.size() == 2, "stop preserves learning manipulation")
	var preserved: Array = game.activity.placed.duplicate()
	for dimensions in [Vector2i(412, 915), Vector2i(384, 832), Vector2i(900, 720)]:
		root.size = dimensions
		game._layout()
		await _settle()
		_check(
			game.activity.placed == preserved, "resize preserves current task " + str(dimensions)
		)
		for button: Button in game.actions.get_children():
			_check(
				button.size.x >= 48.0 and button.size.y >= 48.0, "48dp action target " + button.text
			)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(
		game.suspended and game.fox.current_behavior == "idle", "app interruption cancels gesture"
	)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(
		not game.suspended and not game.fox.audio_active, "resume does not replay cancelled audio"
	)
	game.queue_free()
	await _settle()
	game = _scene(
		{"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]}, "banana"
	)
	await _settle()
	game._speech_host = host
	game._request_conversation("", "slower")
	host.response = host.question.duplicate(true)
	host.response.merge(
		{
			"state": "ready",
			"reply": "Banane: Ba – na – ne.",
			"action": "point",
			"objectId": "syllable_0"
		},
		true
	)
	game._tick_conversation(0.11)
	_check(
		game._speech_segments == ["Banane", "Ba", "na", "ne"] and host.audio.rate == 0.75,
		"slower syllables preserve checked text with separate actual utterances"
	)
	host.audio_state = "completed"
	game._tick_speech(0.06)
	_check(host.audio.text == "Ba", "next syllable starts only on actual audio completion")
	host.audio_state = "playing"
	game._tick_speech(0.06)
	_check(
		game._focus_id == "syllable_0", "matching real syllable playback highlights matching object"
	)
	game.queue_free()
	await _settle()
	game = _scene(pattern, "pattern-task")
	await _settle()
	_check(
		game.pattern_nodes.size() == 4 and game._pattern_next != null,
		"pattern is actual 3D geometry"
	)
	game._pattern_hint()
	_check(
		game._pattern_group_outline.visible and game.activity.pattern_choice == -1,
		"hint exposes group without submitting a child's answer"
	)
	game._choose_pattern(1)
	_check(
		game.activity.pattern_choice == 1 and not game.activity.is_complete(),
		"even wrong proposal remains unscored for original task"
	)
	game.queue_free()
	await _settle()
	game = _scene(
		{
			"kind": "task_card",
			"prompt": "Welche Zahl liegt zwischen 20 und 22?",
			"subject": "Mathematik",
			"unit": "Zahlenraum",
			"explanation": "Suche den direkten Nachbarn.",
			"answerChoices": ["19", "21", "23"]
		},
		"native-generic"
	)
	await _settle()
	_check(
		is_instance_valid(game._task_card) and game.companion_scope.object_ids.has("answer_1"),
		"generic current task has real card and addressable choices"
	)
	game._choose_task_answer(1)
	_check(
		game.activity.task_choice == 1 and not game.activity.is_complete(),
		"generic answer remains proposal only"
	)
	game.queue_free()
	await _settle()
	if failures.is_empty():
		print(
			"LEARNING_GENERATION_PASS checks=",
			checks,
			" environment=headless-desktop actual_microphone=false"
		)
		quit(0)
	else:
		print("LEARNING_GENERATION_FAIL checks=", checks, " failures=", failures)
		quit(1)
