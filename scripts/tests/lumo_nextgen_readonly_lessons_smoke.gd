extends SceneTree
## Deterministic native domain smoke for all new read-only preview types.
const ACTIVITY = preload("res://scripts/learning/learning_activity.gd")


func _fail(message: String) -> void:
	push_error("[NextGenReadOnly] " + message)
	quit(1)


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	var card = ACTIVITY.new()
	if not card.configure({
		"kind": "task_card",
		"sourceTaskId": "retained-flutter-task",
		"prompt": "Welche Antwort passt zur Aufgabe?",
		"explanation": "Sieh dir alle Möglichkeiten an.",
		"answerChoices": ["Drei", "Vier", "Fünf"]
	}):
		_fail("A valid ungraded task card is rejected")
		return
	if card.kind != "task_card" or card.is_complete() or card.place(0, 0):
		_fail("A preview must not silently complete, grade or move task tokens")
		return
	var pattern = ACTIVITY.new()
	if not pattern.configure({
		"kind": "pattern",
		"sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck"],
		"choices": ["Dreieck", "Kreis", "Quadrat"],
		"period": 2
	}):
		_fail("A valid checked repeated pattern is rejected")
		return
	if pattern.pattern_period != 2 or pattern.is_complete() or pattern.place(0, 0):
		_fail("A pattern display is incorrectly grading its child's answer")
		return
	var bad = ACTIVITY.new()
	if bad.configure({
		"kind": "pattern",
		"sequence": ["Kreis", "Dreieck", "Kreis", "Quadrat"],
		"choices": ["Kreis", "Dreieck"],
		"period": 2
	}):
		_fail("A mathematically invalid repetition was accepted")
		return
	var ten = ACTIVITY.new()
	if not ten.configure({"kind": "bridge_ten", "a": 8, "b": 5}):
		_fail("Existing eight plus five lesson regressed")
		return
	if ten.goal_count() != 5 or ten.initial_count() != 8 or ten.is_complete():
		_fail("Original ten-frame invariants lost")
		return
	var syllables = ACTIVITY.new()
	if not syllables.configure({
		"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]
	}):
		_fail("Existing three-syllable learning task regressed")
		return
	if syllables.goal_count() != 3 or syllables.is_complete():
		_fail("Original syllable scoring contract changed")
		return
	print("[NextGenReadOnly] PASS: preview no-grade, repeated pattern, 8+5, Ba-na-ne")
	quit(0)
