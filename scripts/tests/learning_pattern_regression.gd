extends SceneTree
## Independent bounded-pattern contract and actual proposal/confirmation state.
## This exercises the production model; it is not an Android or renderer test.

const MODEL = preload("res://scripts/learning/learning_activity.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		if failures.size() <= 20:
			push_error("[LearningPattern] " + label)


func _payload() -> Dictionary:
	return {
		"kind": "pattern",
		"sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck", "Kreis"],
		"choices": ["Dreieck", "Stern", "Kreis"],
		"period": 2,
	}


func _run() -> void:
	_test_interaction()
	_test_boundaries()
	_test_all_binary_sequences()
	print(
		(
			"[LearningPattern] %s checks=%d failures=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)


func _test_interaction() -> void:
	var model = MODEL.new()
	var input := _payload()
	_check(model.configure(JSON.parse_string(JSON.stringify(input))), "native JSON accepted")
	_check(model.pattern_period == 2, "smallest group is retained")
	_check(model.pattern_sequence == input.sequence, "actual visible sequence is retained")
	_check(model.token_count() == 3 and model.goal_count() == 1, "choice count and one local goal")
	_check(not model.confirm_pattern_candidate(), "no answer exists before selection")
	_check(model.pattern_attempts == 0, "empty confirmation never counts a try")
	for level in range(1, 7):
		var hint: String = model.pattern_hint()
		_check(not hint.is_empty() and hint.length() <= 220, "bounded readable spoken hint")
		_check(model.pattern_hint_level == mini(level, 3), "hint level stops at three")
		_check(
			(
				model.pattern_candidate == -1
				and model.pattern_attempts == 0
				and not model.is_complete()
			),
			"a hint before an answer does not select, judge or complete"
		)
		_check(not hint.contains("Dreieck"), "hint names the group position, not the answer token")
	_check(
		model.explanation() == model.pattern_hint(), "the displayed explanation follows the hint"
	)
	_check(model.select_pattern_candidate(2), "a wrong candidate is a legal proposal")
	_check(model.pattern_attempts == 0 and not model.is_complete(), "selection is not evaluation")
	_check(not model.select_pattern_candidate(-1), "negative choice rejected")
	_check(not model.select_pattern_candidate(3), "outside choice rejected")
	_check(model.pattern_candidate == 2, "invalid input does not replace a proposal")
	_check(model.select_pattern_candidate(0), "a candidate can be corrected before confirmation")
	_check(model.pattern_attempts == 0, "unconfirmed correction creates no attempt")
	_check(not model.place(0, 0), "generic token placement cannot bypass pattern confirmation")
	_check(model.confirm_pattern_candidate(), "explicit confirmation accepts the actual next token")
	_check(
		model.is_complete() and model.pattern_attempts == 1,
		"only the confirmed local action completes"
	)
	_check(
		not model.confirm_pattern_candidate(), "duplicate callback does not signal another success"
	)
	_check(model.pattern_attempts == 1, "duplicate confirmation does not count twice")
	_check(
		not model.select_pattern_candidate(1), "completed illustration rejects further selections"
	)
	_check(model.pattern_hint().is_empty(), "completed illustration does not advance hints")
	_check(model.placed.is_empty(), "pattern never writes manipulative progress")
	model.reset()
	_check(
		model.pattern_sequence == input.sequence and model.pattern_period == 2,
		"reset keeps the current question and its smallest group"
	)
	_check(
		(
			model.pattern_candidate == -1
			and model.pattern_attempts == 0
			and model.pattern_hint_level == 0
			and not model.is_complete()
		),
		"reset discards the proposal, local attempts and hints"
	)
	_check(model.select_pattern_candidate(1), "wrong visible choice selected")
	_check(not model.confirm_pattern_candidate(), "wrong confirmation remains incomplete")
	_check(
		model.pattern_attempts == 1 and not model.is_complete(), "wrong answer counts exactly once"
	)
	_check(model.select_pattern_candidate(1), "duplicate selection is harmless")
	_check(
		not model.confirm_pattern_candidate() and model.pattern_attempts == 1,
		"duplicate input cannot reopen its confirmation"
	)
	_check(not model.pattern_hint().is_empty(), "help remains available after a wrong proposal")
	_check(model.pattern_attempts == 1, "help after an error never adds a try")
	model.clear_pattern_candidate()
	_check(model.pattern_candidate == -1, "stop can discard the pending candidate")
	_check(not model.confirm_pattern_candidate(), "late confirmation after clear has no candidate")
	_check(
		model.select_pattern_candidate(0) and model.confirm_pattern_candidate(),
		"new explicit correction succeeds"
	)
	_check(model.pattern_attempts == 2, "only the new confirmation creates the second attempt")
	_check(model.configure(input), "same source can be configured again")
	input.sequence[0] = "Changed"
	input.choices[0] = "Changed"
	_check(
		model.pattern_sequence[0] == "Kreis", "caller cannot mutate the retained visible sequence"
	)
	_check(model.pattern_choices[0] == "Dreieck", "caller cannot mutate retained choices")
	var group: Array[String] = model.pattern_group()
	group[0] = "Changed"
	_check(
		model.pattern_group() == ["Kreis", "Dreieck"],
		"group getter cannot corrupt the actual model"
	)
	_check(model.select_pattern_candidate(0), "proposal exists before task change")
	_check(
		model.configure({"kind": "addition", "a": 8, "b": 5}), "existing addition remains accepted"
	)
	_check(
		model.pattern_sequence.is_empty() and model.pattern_period == 0,
		"task change clears old pattern data"
	)
	_check(
		not model.confirm_pattern_candidate() and model.pattern_hint().is_empty(),
		"old pattern actions cannot affect another kind"
	)


func _test_boundaries() -> void:
	var model = MODEL.new()
	for payload: Dictionary in [
		{"kind": "pattern", "sequence": ["A", "A", "A", "A"], "choices": ["B", "A"], "period": 1},
		{
			"kind": "pattern",
			"sequence": ["A", "B", "C", "A", "B", "C"],
			"choices": ["B", "A"],
			"period": 3
		},
		{
			"kind": "pattern",
			"sequence": ["A", "B", "C", "D", "A", "B", "C", "D"],
			"choices": ["B", "A"],
			"period": 4
		},
		{"kind": "pattern", "sequence": ["🔵", "🔺", "🔵", "🔺"], "choices": ["🔵", "🔺"], "period": 2},
	]:
		_check(
			model.configure(payload),
			"primitive groups one through four and Unicode tokens accepted"
		)
	var invalid: Array[Dictionary] = []
	for field: String in ["sequence", "choices", "period"]:
		var missing := _payload()
		missing.erase(field)
		invalid.append(missing)
	for value: Variant in [null, false, "2", 0, 5, 1.5, NAN, INF, -1, 1, 3, 4]:
		var bad_period := _payload()
		bad_period.period = value
		invalid.append(bad_period)
	for value: Variant in [
		null,
		"ABAB",
		[],
		["A", "B", "A"],
		["A", "B", "C", "D"],
		["A", "B", "A", "C"],
		["A", 1, "A", 1]
	]:
		var bad_sequence := _payload()
		bad_sequence.sequence = value
		invalid.append(bad_sequence)
	for value: Variant in [
		null,
		"AB",
		[],
		["Dreieck"],
		["Dreieck", "Dreieck"],
		["Stern", "Kreis"],
		["A", "B", "C", "D", "E", "F", "G"],
		[1, "Dreieck"]
	]:
		var bad_choices := _payload()
		bad_choices.choices = value
		invalid.append(bad_choices)
	for token: String in [
		"", " A", "A ", "A\nB", "\u0085", "\u2028", "\u2029", "abcdefghijklmnopqrstuvwxy"
	]:
		var bad_token := {
			"kind": "pattern",
			"sequence": [token, "B", token, "B"],
			"choices": [token, "B"],
			"period": 2
		}
		invalid.append(bad_token)
	invalid.append(
		{
			"kind": "pattern",
			"sequence": ["A", "B", "A", "B", "A", "B", "A", "B"],
			"choices": ["A", "B"],
			"period": 4
		}
	)
	invalid.append(
		{
			"kind": "pattern",
			"sequence": ["A", "B", "C", "D", "A", "B", "C"],
			"choices": ["D", "A"],
			"period": 4
		}
	)
	var too_long := _payload()
	too_long.sequence = ["A", "B", "A", "B", "A", "B", "A", "B", "A", "B", "A", "B", "A"]
	invalid.append(too_long)
	for payload: Dictionary in invalid:
		model.configure(_payload())
		model.select_pattern_candidate(0)
		_check(
			not model.configure(payload), "malformed/nonminimal/underdetermined pattern rejected"
		)
		_check(model.kind == "invalid", "invalid contract does not fall back to an unrelated task")
		_check(
			(
				model.pattern_sequence.is_empty()
				and model.pattern_choices.is_empty()
				and model.pattern_period == 0
				and model.pattern_candidate == -1
			),
			"failed reconfiguration cannot retain an old pattern or proposal"
		)
		_check(not model.confirm_pattern_candidate(), "invalid model cannot confirm")


func _test_all_binary_sequences() -> void:
	# An independent tiling oracle constructs repeated prefixes, rather than
	# using the model's periodic-index comparison. All 4..12-token binary
	# sequences and every declared period 1..4 are checked, including prefixes.
	var model = MODEL.new()
	for size in range(4, 13):
		for bits in range(1 << size):
			var sequence: Array[String] = []
			for index in range(size):
				sequence.append("A" if (bits & (1 << index)) == 0 else "B")
			var expected_period := 0
			for group_size in range(1, 5):
				if size < group_size * 2:
					continue
				var tiled: Array[String] = []
				while tiled.size() < size:
					tiled.append_array(sequence.slice(0, group_size))
				if tiled.slice(0, size) == sequence:
					expected_period = group_size
					break
			for declared in range(1, 5):
				var accepted: bool = model.configure(
					{
						"kind": "pattern",
						"sequence": sequence,
						"choices": ["A", "B"],
						"period": declared
					}
				)
				_check(
					accepted == (declared == expected_period),
					"bounded tiling oracle agrees with declared smallest period"
				)
				if accepted:
					var expected_next := sequence[size % declared]
					model.select_pattern_candidate(0 if expected_next == "A" else 1)
					_check(
						model.confirm_pattern_candidate(),
						"accepted periodic prefix continues at the actual next position"
					)
