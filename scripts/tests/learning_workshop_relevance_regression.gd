extends SceneTree
## Native learning-world regression: no dummy numbered cards, no missing clock.
const MODEL = preload("res://scripts/learning/learning_activity.gd")
const WORLD := "res://scenes/learning/learning_world.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(result: bool, message: String) -> void:
	checks += 1
	if not result:
		failures += 1
		push_error("[LearningWorkshop] " + message)


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _open(payload: Dictionary) -> Node3D:
	var game: Node3D = load(WORLD).instantiate()
	game.capture_options = {"learning": payload, "reduceAnimations": true}
	root.add_child(game)
	return game


func _run() -> void:
	var invalid = MODEL.new()
	_check(
		not invalid.configure({"kind": "clock", "hour": 5, "minute": 60, "prompt": "Zeit"}),
		"clock rejects impossible minutes"
	)
	_check(
		not invalid.configure({"kind": "clock", "hour": 0, "minute": 15, "prompt": "Zeit"}),
		"clock rejects impossible hour"
	)
	var data := {
		"kind": "clock",
		"hour": 3,
		"minute": 30,
		"subject": "Mathematik",
		"unit": "Uhrzeit",
		"prompt": "Wie spät ist es auf der gezeigten Uhr?",
		"explanation": "Beachte die beiden Zeiger.",
		"answerChoices": ["3:00 Uhr", "3:30 Uhr", "4:00 Uhr", "4:30 Uhr"]
	}
	var model = MODEL.new()
	_check(model.configure(data), "actual clock payload is accepted")
	_check(model.kind == "clock" and model.clock_hour == 3 and model.clock_minute == 30,
		"validated time survives model")
	_check(not model.is_complete(), "3D support never claims to have graded the task")
	var game := _open(data)
	await _settle()
	_check(game.activity.kind == "clock", "the clock gets a dedicated native activity")
	_check(is_instance_valid(game._clock_dial), "clock face exists")
	_check(game._clock_dial.get_node_or_null("HourHand") != null, "hour hand exists")
	_check(game._clock_dial.get_node_or_null("MinuteHand") != null, "minute hand exists")
	var tick_count := 0
	for node: Node in game._clock_dial.get_children():
		if node is MeshInstance3D and node.name.begins_with("ClockTick"):
			tick_count += 1
	_check(tick_count == 12,
		"twelve clock ticks are actual geometry, observed=%d" % tick_count)
	_check(game.choice_buttons.size() == 4, "four visible answer controls exist")
	_check(game.choice_buttons[1].text == "3:30 Uhr", "real answer text replaces 1 to 4 labels")
	_check(is_equal_approx(game._clock_dial.get_node("MinuteHand").rotation.z, -PI),
		"minute hand points exactly to six")
	_check(is_equal_approx(game._clock_dial.get_node("HourHand").rotation.z,
		-TAU * 3.5 / 12.0), "hour hand sits between three and four")
	game._clock_hint()
	_check(game.explanation.text.contains("Zeiger"), "clock hint explains actual hands")
	game._choose_task_answer(1)
	_check(game.activity.task_choice == 1 and not game.activity.is_complete(),
		"selecting a visible answer only proposes it; grading remains in Flutter")
	_check(game.choice_buttons[1].button_pressed, "chosen time is highlighted")
	game.restart()
	_check(game.activity.task_choice == -1 and game.choice_buttons.size() == 4,
		"restart keeps the time and restores accessible choices")
	game.queue_free()
	await _settle()
	game = _open({
		"kind": "task_card",
		"subject": "Deutsch",
		"unit": "Wortarten",
		"prompt": "Welches Wort ist ein Tunwort?",
		"answerChoices": ["laufen", "Haus", "rot", "schnell"]
	})
	await _settle()
	_check(game.choice_buttons.size() == 4, "fallback task also exposes actual answer controls")
	_check(game.choice_buttons[0].text == "laufen", "unrelated fallback no longer renders only digits")
	game._choose_task_answer(0)
	_check(game.activity.task_choice == 0 and not game.activity.is_complete(),
		"fallback choice is safely ungraded")
	game.queue_free()
	await _settle()
	if failures == 0:
		print("[LearningWorkshop] PASS checks=%d" % checks)
	else:
		push_error("[LearningWorkshop] FAIL checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
