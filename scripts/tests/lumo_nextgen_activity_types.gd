extends SceneTree
## Native production learning-activity contract: 8+5, Banane and both
## Flutter pattern formats. No score, answer or reward leaves the activity.
const ACTIVITY = preload("res://scripts/learning/learning_activity.gd")


func _assert(condition: bool, reason: String) -> bool:
	if condition:
		return true
	push_error("[NextGenActivity] FAIL: " + reason)
	quit(1)
	return false


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var task = ACTIVITY.new()
	if not _assert(task.configure({"kind": "bridge_ten", "a": 8, "b": 5}),
			"8+5 accepted as existing teaching manipulative"):
		return
	if not _assert(task.initial_count() == 8 and task.token_count() == 5,
			"exact initial 8 plus 5 extra objects"):
		return
	if not _assert(task.place(0, 8) and task.place(1, 9),
			"two tokens occupy the two empty ten-frame cells"):
		return
	if not _assert(task.placed.size() == 2 and not task.is_complete(),
			"remaining three objects have not been falsely booked"):
		return
	if not _assert(task.configure({"kind": "syllables", "word": "Banane",
			"syllables": ["Ba", "na", "ne"]}), "Banane syllables accept"):
		return
	if not _assert(task.token_count() == 3 and task.explanation().contains("Ba"),
			"three pieces for Banane"):
		return
	var canonical = {"kind": "pattern",
		"patternUnit": ["circle", "triangle"],
		"patternSequence": ["circle", "triangle", "circle", "triangle"],
		"patternChoices": ["circle", "triangle", "square"]}
	if not _assert(task.configure(canonical), "checked shape-pattern accepted"):
		return
	if not _assert(task.pattern_period == 2 and not task.is_complete() and
			not task.place(0, 0), "pattern never self-grades or moves answer"):
		return
	task.pattern_hint_level = 1
	if not _assert(task.explanation().contains("Wiederholung"),
			"pattern group hint is a teaching aid"):
		return
	task.reset()
	if not _assert(task.pattern_hint_level == 0, "hint reset on new exercise"):
		return
	if not _assert(task.configure({"kind": "pattern",
			"sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck"],
			"choices": ["Kreis", "Dreieck", "Quadrat"], "period": 2}),
			"existing domain pattern also accepted"):
		return
	if not _assert(not task.configure({"kind": "pattern",
			"sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck"],
			"choices": ["Kreis", "Dreieck"], "period": 4}),
			"misleading/nonminimal pattern rejected"):
		return
	if not _assert(not task.configure({"kind": "pattern",
			"sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck"],
			"choices": ["Dreieck", "Quadrat"], "period": 2}),
			"missing expected option rejected"):
		return
	if not _assert(task.configure({"kind": "task_card",
			"sourceTaskId": "existing-id-from-flutter",
			"subject": "Deutsch", "unit": "Silben",
			"prompt": "Wie viele Silben hat Banane?",
			"explanation": "",
			"answerChoices": ["2", "3", "4"],
			"objectIds": ["task_prompt", "task_model", "answer_0", "answer_1", "answer_2"]}),
			"read-only original task card accepted"):
		return
	if not _assert(not task.is_complete() and not task.place(0, 0),
			"card never books learning progress"):
		return
	if not _assert(not task.configure({"kind": "task_card",
			"sourceTaskId": "anonymous", "prompt": "bad",
			"subject": "Deutsch", "unit": "",
			"answerChoices": ["2", "3"], "childId": "should-not-pass"}),
			"incomplete required UI contract rejected"):
		return
	print("[NextGenActivity] PASS: 8+5, Banane, both reviewed patterns, no native scoring, task-card fallback")
	quit(0)
