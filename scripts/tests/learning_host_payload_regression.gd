extends SceneTree
## Consume actual serialized launch3D learning payloads exported by the Host test.
## Caller task identity stays in Host metadata; Native never invents a task ID.
const MODEL = preload("res://scripts/learning/learning_activity.gd")
const DEFAULT_FIXTURE := "res://scripts/tests/fixtures/learning_host_payloads.json"
const REQUIRED_CASES := [
	"equal_sharing:12:3:0",
	"equal_groups:3:4:0",
	"equal_groups:4:3:0",
	"fraction_parts:1:4:2",
	"fraction_parts:1:4:1",
]
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("[LearningHostPayload] FAIL " + message)
	return condition


func _run() -> void:
	var path := DEFAULT_FIXTURE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			path = argument.trim_prefix("--fixture=")
	if not _check(FileAccess.file_exists(path), "actual Host export fixture exists"):
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(parsed is Dictionary, "Host export is a JSON object"):
		quit(1)
		return
	var fixture: Dictionary = parsed
	if not _check(fixture.get("schema") == 1 and fixture.get("cases") is Array,
		"supported Host export schema and cases"):
		quit(1)
		return
	var covered: Array[String] = []
	var names: Array[String] = []
	for entry: Variant in fixture.cases:
		if not _check(entry is Dictionary, "Host case is an object"):
			continue
		var label: String = str(entry.get("name", ""))
		if not _check(not label.is_empty() and label not in names, "unique named Host case"):
			continue
		names.append(label)
		if not _check(entry.get("serialized_payload") is String and entry.get("expected") is Dictionary,
			label + " has an actual serialized payload and independently asserted expectation"):
			continue
		var incoming: Variant = JSON.parse_string(entry.serialized_payload)
		if not _check(incoming is Dictionary, label + " payload survives Godot JSON parsing"):
			continue
		var raw: Dictionary = incoming
		var expected: Dictionary = entry.expected
		var original: String = JSON.stringify(raw)
		var valid := true
		for field in ["a", "b"]:
			valid = _check(raw.has(field) and expected.has(field), label + " contains " + field) and valid
			if not valid:
				break
			valid = _check(typeof(raw[field]) == TYPE_FLOAT and is_finite(raw[field])
				and raw[field] == floorf(raw[field]) and raw[field] == expected[field],
				label + " keeps exact integral " + field + " through JSON float decoding") and valid
		if not valid:
			continue
		if expected.has("extra"):
			if not _check(raw.has("extra") and typeof(raw.extra) == TYPE_FLOAT
				and is_finite(raw.extra) and raw.extra == floorf(raw.extra)
				and raw.extra == expected.extra, label + " preserves the second fraction numerator"):
				continue
		var model = MODEL.new()
		if not _check(model.configure(raw), label + " configures the production Native model"):
			continue
		_check(model.kind == expected.get("kind") and model.a == expected.a and model.b == expected.b
			and model.extra == expected.get("extra", 0), label + " retains exact kind and operands")
		_check(typeof(model.a) == TYPE_INT and typeof(model.b) == TYPE_INT,
			label + " model stores validated integers without truncation")
		_check(not raw.has("taskInstanceId"), label + " leaves task identity with the Host caller")
		var signature := "%s:%d:%d:%d" % [model.kind, model.a, model.b, model.extra]
		covered.append(signature)
		match model.kind:
			"equal_sharing":
				_check(model.token_count() == 12 and model.group_count() == 3 and model.group_size() == 4,
					label + " renders the actual dividend, divisor and quotient")
			"equal_groups":
				_check(model.token_count() == int(expected.a) * int(expected.b)
					and model.group_count() == expected.a and model.group_size() == expected.b,
					label + " keeps asymmetric multiplication operands in their original order")
			"fraction_parts":
				_check(model.initial_count() == expected.a and model.token_count() == expected.extra
					and model.b == expected.b, label + " retains both numerators and original denominator")
			_:
				_check(false, label + " is outside this bridge contract")
		var targets: Array[int] = []
		for token in range(model.goal_count()):
			targets.append(model.target_index())
			_check(model.place(token, targets[-1]), label + " accepts each original object once")
		_check(model.is_complete(), label + " reaches completion using the parsed operands")
		if model.kind == "equal_sharing":
			_check(targets == [0, 4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11],
				label + " distributes one object to each group before repeating")
			for group in range(3):
				_check(model.count_in_group(group) == 4, label + " conserves all twelve objects")
		elif model.kind == "fraction_parts":
			_check(targets[0] == expected.a and targets[-1] + 1 == expected.a + expected.extra,
				label + " adds the second numerator without replacing the initial fraction")
		model.reset()
		_check(model.placed.is_empty() and model.a == expected.a and model.b == expected.b
			and model.extra == expected.get("extra", 0), label + " restart preserves the original task")
		_check(JSON.stringify(raw) == original, label + " model never mutates the Host input")
	for signature in REQUIRED_CASES:
		_check(signature in covered, "required asymmetric and fraction case covered: " + signature)
	print("[LearningHostPayload] %s cases=%d checks=%d host=%s" % [
		"PASS" if failures == 0 else "FAIL", names.size(), checks, str(fixture.get("host_revision", ""))])
	quit(0 if failures == 0 else 1)
