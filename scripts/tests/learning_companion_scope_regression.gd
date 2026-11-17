extends SceneTree
const Scope = preload("res://scripts/learning/learning_companion_scope.gd")
var checks := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _initialize() -> void:
	var wire := {
		"protocolVersion": 1,
		"sessionId": "session-1",
		"taskId": "task-1",
		"revision": 3,
		"cancelEpoch": 2,
		"allowedActions": ["repeat", "slower", "stop"]
	}
	for optional_step: Variant in [null, "answer", "explain-2"]:
		var input := wire.duplicate(true)
		input["stepId"] = optional_step
		# Android/Godot JSON numbers are floats; use the actual JSON boundary.
		input = JSON.parse_string(JSON.stringify(input))
		var scope = Scope.new()
		check(scope.configure(input, "fallback", "fallback"), "configure nullable step")
		check(scope.matches(input), "same JSON scope")
		check(scope.matches(scope.envelope()), "envelope roundtrip")
		var missing := input.duplicate(true)
		missing.erase("stepId")
		check(scope.matches(missing) == (optional_step == null), "missing step is null only")
		for other: Variant in [null, "answer", "explain-2", "unknown"]:
			var changed := input.duplicate(true)
			changed["stepId"] = other
			check(scope.matches(changed) == (other == optional_step), "different step rejected")
		for field in ["sessionId", "taskId", "revision", "cancelEpoch", "protocolVersion"]:
			var changed := input.duplicate(true)
			changed[field] = "other" if field in ["sessionId", "taskId"] else 99
			check(not scope.matches(changed), "changed identity rejected: " + field)
		var reply := scope.envelope(7)
		reply["action"] = "repeat"
		check(scope.permits_reply(reply, 7), "allowed repeat")
		reply["action"] = "hint"
		check(not scope.permits_reply(reply, 7), "unallowed hint rejected")
		scope.cancel()
		check(not scope.matches(input), "old scope rejected after stop")
	for malformed: Variant in ["", 1, [], {}, " padded "]:
		var input := wire.duplicate(true)
		input["stepId"] = malformed
		check(not Scope.new().configure(input, "fallback", "fallback"), "invalid explicit step")
	var legacy = Scope.new()
	check(legacy.configure({}, "legacy-session", "legacy-task"), "legacy checked descriptor")
	check(legacy.step_id == null, "legacy does not invent step")
	check(legacy.allowed_actions == ["stop"], "legacy missing actions permits only stop")
	print(
		JSON.stringify(
			{
				"test": "learning_companion_scope",
				"checks": checks,
				"failures": failures,
				"status": "PASS" if failures.is_empty() else "FAIL"
			}
		)
	)
	quit(0 if failures.is_empty() else 1)
