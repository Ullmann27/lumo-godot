extends SceneTree
## Real host options pass through production boot and retain their lesson.
## Android admission is checked by the generated-host contract in lumo-lernen.
const BRIDGE = preload("res://scripts/systems/host_bridge.gd")
const HOLO = preload("res://scripts/tests/holo_lesson_fixtures.gd")
const HOLO_PLAN = preload("res://scripts/learning/holo/holo_lesson_plan.gd")
const TUTOR_PLAN = preload("res://scripts/learning/tutor/tutor_plan.gd")
const TUTOR_FIXTURES := "res://scripts/tests/fixtures/tutor_payloads.json"
const ROUTES := {
	"addition": ["learning", "res://scenes/learning/learning_world.tscn", "LUMO LERNWERKSTATT"],
	"tutor": ["tutor", "res://scenes/learning/tutor_world.tscn", "NACHHILFE MIT LUMO"],
	"holo_word_problem": ["holo", "res://scenes/learning/holo_lesson.tscn", "LUMOS HOLO-LERNRAUM"],
	"holo_sentence": ["holo", "res://scenes/learning/holo_lesson.tscn", "LUMOS HOLO-LERNRAUM"],
}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[NativeLearningBoot] FAIL " + message)


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TUTOR_FIXTURES))
	var lessons := {
		"addition": {"kind": "addition", "a": 8, "b": 5},
		"tutor": fixture.cases[0].learning.duplicate(true),
		"holo_word_problem": HOLO.math(),
		"holo_sentence": HOLO.verb(),
	}
	var bridge := root.get_node("HostBridge")
	var router := root.get_node("SceneRouter")
	var original_options: Dictionary = bridge.get("_options").duplicate(true)
	var original_host: Object = bridge.get("_host")
	var original_router_options: Dictionary = router.get("launch_options").duplicate(true)
	var transport := Node.new()
	root.add_child(transport)
	bridge.set("_host", transport)
	var packed := load("res://scenes/app/boot.tscn") as PackedScene
	for kind: String in lessons:
		var lesson: Dictionary = lessons[kind]
		var task_id := "learning-boot-" + kind
		var session := "session-" + kind
		lesson["sourceTaskId"] = task_id
		lesson["scope"] = {
			"protocolVersion": 1, "sessionId": session, "taskId": task_id,
			"revision": 0, "cancelEpoch": 0,
		}
		if kind != "addition":
			var plan = TUTOR_PLAN.new() if kind == "tutor" else HOLO_PLAN.new()
			_check(plan.configure(lesson), kind + " retains its valid checked plan")
			var malformed := lesson.duplicate(true)
			malformed.erase("plaene" if kind == "tutor" else "twin")
			_check(not plan.configure(malformed), kind + " rejects an incomplete checked plan")
			malformed = lesson.duplicate(true)
			malformed["kind"] = "unknown_learning"
			_check(not plan.configure(malformed), kind + " rejects unknown lesson kinds")
		var options := BRIDGE.validated_options({
			"game": "learning", "learning": lesson, "sessionId": session,
			"childKey": "learning-boot-child", "grade": 2, "subject": "Mathematik",
			"reduceAnimations": true, "learningVoiceEnabled": false,
		})
		bridge.set("_options", options)
		var boot := packed.instantiate()
		boot.set("auto_transition", false)
		root.add_child(boot)
		await process_frame
		await process_frame
		var deadline := Time.get_ticks_msec() + 30000
		while boot.get("load_phase") not in ["ready", "error"] and Time.get_ticks_msec() < deadline:
			await create_timer(0.01).timeout
		_check(boot.get("target_scene") == ROUTES[kind][0], kind + " selects its actual scene")
		_check(boot.get("load_phase") == "ready", kind + " loads its production resource")
		_check(boot.get_node("Layer/Title").text == ROUTES[kind][2], kind + " shows its learning title")
		_check(not boot.get_node("Layer/Background").visible, kind + " uses the learning cover")
		var resources: Dictionary = boot.get("_resources")
		_check(resources.has(ROUTES[kind][1]), kind + " resolves the intended PackedScene")
		var routed: Dictionary = router.get("launch_options")
		_check(routed.get("learning") == lesson, kind + " preserves all checked lesson fields")
		_check(routed.get("childKey") == options.childKey, kind + " preserves its child")
		_check(routed.get("sessionId") == session, kind + " preserves its host session")
		boot.queue_free()
		await process_frame
		await process_frame
	bridge.set("_host", original_host)
	bridge.set("_options", original_options)
	router.set("launch_options", original_router_options)
	transport.queue_free()
	await process_frame
	if failures.is_empty():
		print("[NativeLearningBoot] PASS %d actual boot, plan and task-context checks" % checks)
	quit(0 if failures.is_empty() else 1)
