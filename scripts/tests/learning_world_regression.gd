extends SceneTree

const MODEL = preload("res://scripts/learning/learning_activity.gd")
const WORLD := "res://scenes/learning/learning_world.tscn"
var checks := 0
var failures := 0

class SpeechHost extends RefCounted:
	var request: Dictionary = {}
	var state := "preparing"
	var stops := 0

	func speakLearning(payload: String) -> int:
		request = JSON.parse_string(payload)
		state = "preparing"
		return 1

	func getLearningSpeechStatus() -> String:
		return JSON.stringify({"id": request.get("id", 0), "state": state,
			"positionMs": 0, "durationMs": 1000})

	func stopLearningSpeech() -> void:
		stops += 1


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[LearningWorld] FAIL " + message)


func _settle() -> void:
	for i in range(8):
		await process_frame


func _run() -> void:
	var model = MODEL.new()
	_check(model.configure(JSON.parse_string('{"kind":"bridge_ten","a":8,"b":5}')), "native JSON exact integers accepted")
	_check(not model.configure({"kind": "bridge_ten", "a": 8.4, "b": 5}), "fractional operands rejected")
	_check(not model.configure({"kind": "bridge_ten", "a": "8", "b": 5}), "string operands rejected")
	_check(not model.configure({"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na"]}), "mismatched word rejected")
	_check(not model.configure({"kind": "plant_parts", "plantPart": "unsupported"}), "unknown plant part rejected")
	for a in range(2, 10):
		for b in range(2, 10):
			if a + b <= 10:
				continue
			_check(model.configure({"kind": "bridge_ten", "a": a, "b": b}), "reviewed addition accepted")
			for token in range(b):
				_check(not model.place(token, model.target_index() + 1), "cannot skip the next place")
				_check(model.place(token, model.target_index()), "addition object moves once")
				_check(not model.place(token, model.target_index()), "duplicate object cannot inflate quantity")
			_check(model.is_complete() and model.placed.size() + a == a + b, "quantity conserved for each make-ten pair")
	for a in range(1, 21):
		for b in range(1, a + 1):
			_check(model.configure({"kind": "subtract_ten", "a": a, "b": b}), "bounded subtraction accepted")
			if a > 10:
				_check(not model.place(a - 1, 0), "subtraction first reaches ten rather than skipping the crossing")
			for token in range(b):
				_check(model.place(token, model.target_index()), "subtracted object remains conserved in removed tray")
			_check(model.is_complete() and a - model.placed.size() == a - b, "all subtraction results conserve quantity")
	for a in range(1, 7):
		for b in range(1, 7):
			_check(model.configure({"kind": "equal_groups", "a": a, "b": b}), "bounded grouping accepted")
			for token in range(a * b):
				_check(model.place(token, model.target_index()), "every multiplication object is placed once")
			_check(model.is_complete() and model.placed.size() == a * b, "equal groups preserve actual product")
	for denominator in range(2, 13):
		for numerator in range(1, denominator + 1):
			_check(model.configure({"kind": "fraction_parts", "a": numerator, "b": denominator}), "valid fraction partition accepted")
			for token in range(numerator):
				_check(model.place(token, model.target_index()), "fraction never skips equal-size segment")
			_check(model.is_complete() and model.target_index() == numerator, "fraction denominator remains unchanged")
	_check(not model.configure({"kind": "fraction_parts", "a": 3, "b": 4, "extra": 2}), "improper addition cannot overflow this bounded fraction model")
	_check(not model.configure({"kind": "equal_groups", "a": 20, "b": 20}), "unbounded geometry rejected")
	_check(not model.configure({"kind": "addition", "a": 8.5, "b": 4}), "adaptive arithmetic never truncates an operand")
	for a in [180, 260, 390, 890]:
		_check(model.configure({"kind": "bridge_hundred", "a": a, "b": 90}), "real hundred crossing accepted")
		for token in range(9):
			_check(model.place(token, model.target_index()), "one ten moved per action")
		_check(model.is_complete() and a + model.placed.size() * 10 == a + 90, "hundred crossing conserves tens")
	root.size = Vector2i(1280, 720)
	var game = load(WORLD).instantiate()
	game.capture_options = {"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true}
	root.add_child(game)
	await _settle()
	_check(game.activity.kind == "bridge_ten", "actual production scene consumes current lesson")
	_check(game.fox.is_usable(), "original 65-bone fox is actually mounted")
	_check(game.fox.teacher_enabled and game.fox.teacher_pose.has_target, "original fox actually enters teaching mode in production scene")
	_check(game.tokens.size() == 5 and game.targets.size() == 20, "real 3D manipulative count")
	_check(game.find_children("InitialCube*", "MeshInstance3D", true, false).size() == 8, "eight actual starting meshes")
	var token_point: Vector2 = game.camera.unproject_position(game.tokens[0].global_position)
	var touch := InputEventScreenTouch.new()
	touch.position = token_point
	touch.index = 3
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	_check(game.active_drag == 0 and game.drag_finger == 3, "real touch picks 3D object")
	var unrelated := InputEventScreenTouch.new()
	unrelated.position = token_point
	unrelated.index = 4
	unrelated.pressed = false
	Input.parse_input_event(unrelated)
	await process_frame
	_check(game.active_drag == 0, "second finger cannot release owned object")
	touch = InputEventScreenTouch.new()
	touch.position = token_point
	touch.index = 3
	touch.pressed = false
	Input.parse_input_event(touch)
	await _settle()
	_check(game.activity.placed.size() == 1, "tap manipulation reaches current next slot")
	_check(game.tokens[0].position.is_equal_approx(game.targets[8]), "visible object occupies ninth slot")
	var drag_source: Vector2 = game.camera.unproject_position(game.tokens[1].global_position)
	var drag_target: Vector2 = game.camera.unproject_position(game.targets[9])
	for target_point in [game.footer.get_global_rect().get_center(), drag_target]:
		var press := InputEventScreenTouch.new()
		press.index = 2
		press.position = drag_source
		press.pressed = true
		Input.parse_input_event(press)
		await process_frame
		var drag := InputEventScreenDrag.new()
		drag.index = 2
		drag.position = target_point
		drag.relative = target_point - drag_source
		Input.parse_input_event(drag)
		await process_frame
		var release := InputEventScreenTouch.new()
		release.index = 2
		release.position = target_point
		release.pressed = false
		Input.parse_input_event(release)
		await _settle()
		_check(game.active_drag == -1, "drag always releases even across footer")
	_check(game.activity.placed.size() == 2, "actual spatial drag completes ten after an invalid HUD drop")
	_check(game.activity.explanation().contains("Zehn sind voll"), "ten completion explains remaining three")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(not game.move_token(2), "background blocks manipulations")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	for i in range(2, 5):
		_check(game.move_token(i), "remaining object reaches second ten frame")
	_check(game.activity.is_complete(), "child completes eight plus five")
	_check(game.fox.current_behavior == "celebrate", "actual lesson success triggers original celebration")
	_check(game.activity.explanation().contains("10 + 3 = 13"), "actual sum explanation matches current quantities")
	for dimensions in [Vector2i(412, 915), Vector2i(690, 829), Vector2i(2400, 1080)]:
		root.size = dimensions
		await _settle()
		_check(game.header.get_global_rect().end.y < game.footer.get_global_rect().position.y, "header and controls separate")
		_check(game.footer.get_global_rect().end.y <= dimensions.y + 1, "controls inside display %s: %s" % [dimensions, game.footer.get_global_rect()])
		for button in game.actions.get_children():
			_check(button.size.y >= 48, "minimum 48 logical pixel actions")
	game.restart()
	_check(game.activity.placed.is_empty() and game.tokens.size() == 5, "reset rebuilds same lesson without duplicates")
	var speech := SpeechHost.new()
	game._speech_host = speech
	game._speech_enabled = true
	game._speak(game.explanation.text)
	_check(str(speech.request.get("text", "")).contains("8 plus 5"), "native narration uses displayed operands")
	game._tick_speech(0.2)
	_check(not game.fox.teacher_pose.speaking, "synthesis request does not pretend to be audible speech")
	speech.state = "playing"
	game._tick_speech(0.2)
	_check(game.fox.teacher_pose.speaking, "confirmed native playback drives original teacher gesture")
	speech.state = "completed"
	game._tick_speech(0.2)
	_check(not game.fox.teacher_pose.speaking, "actual completion stops speaking gesture")
	game._speak(game.explanation.text)
	game._stop_speech()
	speech.state = "playing"
	game._tick_speech(0.2)
	_check(not game.fox.teacher_pose.speaking, "stale audio result cannot restart a cancelled gesture")
	game._auto_read = false
	game._queue_narration()
	_check(game._speech_wait < 0, "parent automatic-reading preference respected")
	game._auto_read = true
	game._queue_narration()
	_check(game._speech_wait > 0, "automatic narration waits for the current manipulation")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game._speech_wait < 0 and not game.fox.teacher_pose.speaking, "background cancels pending narration and speaking gesture")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.queue_free()
	await _settle()
	root.size = Vector2i(1280, 720)
	game = load(WORLD).instantiate()
	game.capture_options = {"learning": {"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]}, "reduceAnimations": true}
	root.add_child(game)
	await _settle()
	_check(not game.move_token(2), "wrong syllable is not accepted as first")
	for index in range(3):
		_check(game.move_token(index), "correct syllable attaches in order")
	_check(game.activity.is_complete() and game.activity.explanation().contains("3 Silben"), "assembled word has actual syllable count")
	game.queue_free()
	await _settle()
	game = load(WORLD).instantiate()
	game.capture_options = {"learning": {"kind": "plant_parts", "plantPart": "leaf"}, "reduceAnimations": true}
	root.add_child(game)
	await _settle()
	_check(game.part_nodes.size() == 4, "all four plant parts use scene nodes")
	game._give_water()
	game._process(0.1)
	_check(is_equal_approx(game._growth, 0.62), "water alone does not complete growth demonstration")
	game._give_sun()
	game._process(0.1)
	_check(is_equal_approx(game._growth, 1.0), "water plus light changes the living model")
	for part in ["root", "stem", "leaf", "flower"]:
		game._inspect(part)
		_check(not game.explanation.text.is_empty(), "selected plant part has actual explanation")
	_check(game.activity.is_complete(), "plant exploration reaches completion")
	game.restart()
	_check(not game.activity.watered and not game.activity.sunlight and game.activity.inspected.is_empty(), "plant restart resets experiment")
	game.queue_free()
	await _settle()
	for descriptor in [
		{"kind": "addition", "a": 4, "b": 3},
		{"kind": "subtract_ten", "a": 13, "b": 5},
		{"kind": "equal_groups", "a": 3, "b": 4},
		{"kind": "bridge_hundred", "a": 180, "b": 50},
		{"kind": "fraction_parts", "a": 1, "b": 4, "extra": 2}]:
		game = load(WORLD).instantiate()
		game.capture_options = {"learning": descriptor, "reduceAnimations": true}
		root.add_child(game)
		await _settle()
		_check(game.activity.kind == descriptor.kind, "production scene uses exact expanded concept")
		_check(game.tokens.size() == game.activity.token_count(), "expanded activity has real manipulable meshes")
		if descriptor.kind == "fraction_parts":
			_check(game.find_children("EqualPart*", "MeshInstance3D", true, false).size() == 4, "fraction whole has four actual equal partitions")
		if descriptor.kind == "equal_groups":
			_check(game.find_children("GroupPlate*", "MeshInstance3D", true, false).size() == 3, "product represented by three physical groups")
		var count: int = game.activity.goal_count()
		for token in range(count):
			var destination: int = game.activity.target_index()
			_check(game.move_token(token), "expanded current lesson interaction succeeds")
			_check(game.tokens[token].position.is_equal_approx(game.targets[destination]), "expanded object really moved to correct spatial target")
		_check(game.activity.is_complete(), "expanded activity is completable")
		game.queue_free()
		await _settle()
	if failures == 0:
		print("[LearningWorld] PASS checks=%d" % checks)
	else:
		push_error("[LearningWorld] FAIL checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
