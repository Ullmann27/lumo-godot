extends SceneTree
## Exact authored CH-2 content: dialogue variants, mission order, travel mode,
## card prerequisites, duplicate rewards, and transactional legacy/save restore.
const QUESTS = preload("res://scripts/creative/lumo_world_quests.gd")
const DIALOG = preload("res://scripts/creative/lumo_world_dialog.gd")

var checks := 0
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("[LumoWorldQuestIntegrity] " + label)


func _run() -> void:
	var model = QUESTS.new()
	_check(model.ready(), "authored content is valid: " + ", ".join(model.errors))
	if not model.ready():
		_finish()
		return
	_check(model.content.places.size() == 7, "all seven authored places")
	_check(model.content.figures.size() == 9, "all nine authored figures")
	_check(model.mission_ids().size() == 4, "all four authored mission chains")
	_check(model.cards().is_empty(), "new profile receives no unearned cards")

	# Every school-grade question must accept the independently calculated
	# correct answer and permit retry without completing on a wrong answer.
	_question_variants(model, "badger_baskets", ["5", "20", "8", "375"])
	_question_variants(model, "squirrel_count", ["8", "23", "63", "40"])
	_question_variants(model, "turtle_bottle_read", ["BUCH", "Zur Bücherei", "Der Eule", "Ein Buch"])

	var card_dialog = DIALOG.new(model.dialog("cat_show_card"), 2, [])
	_check(not bool(card_dialog.view().choices[0].enabled), "locked card choice is disabled")
	_check(card_dialog.choose(0).is_empty(), "locked card cannot be shown")
	_check(card_dialog.active(), "rejected choice does not close the dialog")
	var near_cat: Vector3 = model.figure("cat").position
	_check(not model.can_complete("kartenclub", "show_turtle", near_cat, false), "card prerequisite is enforced in the mission model")

	# Finish the authored chains in dependency order. The dialog runner and
	# model are tested separately: only the UI is allowed to link completion
	# of the validated dialogue with the model's location-bound step.
	var mission_order := ["flaschenpost", "kartenclub", "kart_kurier", "markt_aepfel"]
	for mission_id in mission_order:
		var steps: Array = model.mission(mission_id).steps
		for index in range(steps.size()):
			var step: Dictionary = steps[index]
			var step_id := str(step.id)
			var at: Vector3 = model.step_target(step)
			var driving: bool = str(step.kind) == "drive"
			_check(str(model.current_step(mission_id).id) == step_id, "step order " + mission_id + ":" + step_id)
			_check(not model.can_complete(mission_id, step_id, at + Vector3(1000, 0, 1000), driving), "remote completion rejected " + step_id)
			if index + 1 < steps.size():
				_check(not model.can_complete(mission_id, str(steps[index + 1].id), at, driving), "cannot skip " + step_id)
			if driving:
				_check(not model.can_complete(mission_id, step_id, at, false), "drive cannot be completed on foot")
			elif str(step.kind) in ["talk", "show_card"]:
				_check(not model.can_complete(mission_id, step_id, at, true), "talk requires leaving kart")
			var result: Dictionary = model.complete(mission_id, step_id, at, driving)
			_check(bool(result.ok), "current step completes at its authored target " + step_id)
			_check(not bool(model.complete(mission_id, step_id, at, driving).ok), "cannot complete the same step twice " + step_id)
		_check(model.state(mission_id) == "done", "complete mission " + mission_id)

	_check(model.cards().size() == 9, "all nine unique cards earned")
	var saved: Dictionary = model.to_data()
	var restored = QUESTS.new()
	_check(restored.restore(saved), "completed save accepted")
	_check(restored.to_data() == saved, "completed save round-trips exactly")
	var damaged: Dictionary = saved.duplicate(true)
	damaged.cards[1] = damaged.cards[0]
	_check(not restored.restore(damaged), "duplicate card cannot substitute for another earned card")
	_check(restored.to_data() == saved, "invalid card save leaves progress unchanged")
	damaged = saved.duplicate(true)
	damaged.progress["flaschenpost"] = INF
	_check(not restored.restore(damaged), "non-finite progress rejected")
	_check(restored.to_data() == saved, "invalid progress leaves state unchanged")
	damaged = saved.duplicate(true)
	damaged.progress["flaschenpost"] = 0
	damaged.cards.erase("card_turtle")
	damaged.cards.erase("card_owl")
	_check(not restored.restore(damaged), "completed card-dependent chain cannot lose its prerequisite")
	_check(restored.to_data() == saved, "invalid prerequisite save leaves state unchanged")
	_check(restored.restore({}), "legacy World without this section stays readable")
	_check(restored.cards().is_empty(), "legacy save receives no fictitious cards")

	# Broken authoring content must be rejected without a script exception.
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QUESTS.CONTENT_PATH))
	for field in ["places", "paths", "figures", "cards", "missions", "dialogs", "smalltalk"]:
		var broken: Dictionary = original.duplicate(true)
		broken[field] = 42
		_check(not QUESTS.validate_content(broken).is_empty(), "invalid content container: " + field)
	var broken: Dictionary = original.duplicate(true)
	broken.missions[0].steps[0] = 42
	_check(not QUESTS.validate_content(broken).is_empty(), "invalid first step rejected without dereferencing")
	broken = original.duplicate(true)
	broken.missions[0].steps[0].rewardCards = 42
	_check(not QUESTS.validate_content(broken).is_empty(), "invalid reward container rejected")

	_finish()


func _question_variants(model, dialog_id: String, answers: Array) -> void:
	for grade in range(1, 5):
		var runner = DIALOG.new(model.dialog(dialog_id), grade, [])
		_check(runner.choose(0) == "next", dialog_id + " opens question")
		var view: Dictionary = runner.view()
		var correct := -1
		var wrong := -1
		var complete_count := 0
		for choice in view.get("choices", []):
			if str(choice.label) == str(answers[grade - 1]):
				correct = int(choice.index)
			else:
				wrong = int(choice.index)
			var fresh = DIALOG.new(model.dialog(dialog_id), grade, [])
			fresh.choose(0)
			if fresh.choose(int(choice.index)) == "complete":
				complete_count += 1
		_check(correct >= 0 and wrong >= 0 and complete_count == 1, "%s grade %d has exactly one solution" % [dialog_id, grade])
		if correct < 0 or wrong < 0:
			continue
		_check(runner.choose(wrong) == "next", "%s grade %d wrong answer opens help" % [dialog_id, grade])
		_check(runner.active(), "wrong answer does not finish the mission")
		_check(runner.choose(0) == "next", "retry returns to question")
		_check(runner.choose(correct) == "complete", "%s grade %d independently verified answer completes" % [dialog_id, grade])
		_check(not runner.active(), "completed dialogue is closed")


func _finish() -> void:
	print("[LumoWorldQuestIntegrity] %s %d checks" % ["FAIL" if failed else "PASS", checks])
	quit(1 if failed else 0)
