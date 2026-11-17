extends SceneTree
## Exercises the production sharing model, rendered nodes and actual touch route.
const MODEL = preload("res://scripts/learning/learning_activity.gd")
const WORLD := "res://scenes/learning/learning_world.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[LearningSharing] FAIL " + message)


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _run() -> void:
	var model = MODEL.new()
	_check(
		model.configure(JSON.parse_string('{"kind":"equal_sharing","a":12,"b":3}')),
		"native JSON sharing contract accepted"
	)
	var destinations: Array[int] = []
	for item in range(12):
		destinations.append(model.target_index())
		_check(model.place(item, model.target_index()), "each original object accepted once")
	_check(
		destinations == [0, 4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11],
		"12 divided by 3 visits all groups before repeating a group"
	)
	_check(
		model.is_complete() and model.explanation().contains("Jede hat 4"),
		"completed explanation states the actual quotient"
	)
	for invalid in [
		{"kind": "equal_sharing", "a": 13, "b": 3},
		{"kind": "equal_sharing", "a": 12, "b": 0},
		{"kind": "equal_sharing", "a": 12, "b": 1},
		{"kind": "equal_sharing", "a": 42, "b": 6},
		{"kind": "equal_sharing", "a": 12.4, "b": 3},
		{"kind": "equal_sharing", "a": "12", "b": 3},
		{"kind": "equal_sharing", "a": 6, "b": 7},
	]:
		_check(not model.configure(invalid), "unsupported quantity cannot silently change the task")
	for groups in range(2, 7):
		for per_group in range(1, 7):
			var total := groups * per_group
			_check(
				model.configure({"kind": "equal_sharing", "a": total, "b": groups}),
				"bounded exact division accepted"
			)
			for item in range(total):
				_check(not model.place(item, -1), "wrong destination does not consume an object")
				_check(model.place(item, model.target_index()), "each distribution action succeeds")
				_check(
					not model.place(item, model.target_index()),
					"duplicate object never increases the quantity"
				)
				var counts: Array[int] = []
				var counted := 0
				for group in range(groups):
					counts.append(model.count_in_group(group))
					counted += counts[-1]
				_check(
					counted == item + 1 and counts.max() - counts.min() <= 1,
					"quantity is conserved and groups differ by at most one"
				)
			_check(model.is_complete(), "every supported division completes")
			model.reset()
			_check(
				model.placed.is_empty() and not model.is_complete(),
				"restart preserves the current question but empties all groups"
			)
	root.size = Vector2i(1280, 720)
	var game = (load(WORLD) as PackedScene).instantiate()
	game.capture_options = {
		"learning": {"kind": "equal_sharing", "a": 12, "b": 3}, "reduceAnimations": true
	}
	root.add_child(game)
	await _settle()
	_check(
		game.tokens.size() == 12 and game._group_plates.size() == 3,
		"production world contains every object and group"
	)
	_check(
		game.main_button.text == "Einen Würfel verteilen", "actual child-facing action is connected"
	)
	_check(game.main_button.custom_minimum_size.y >= 48, "touch action retains accessible size")
	# Exercise spatial object picking, then the equivalent accessible action.
	await _tap(game.camera.unproject_position(game.tokens[0].global_position))
	_check(game.activity.placed.size() == 1, "spatial touch distributes one original cube")
	for step in range(3):
		await _tap(game.main_button.get_global_rect().get_center())
	_check(game.activity.placed.size() == 4, "real button touches advance the production model")
	for group in range(3):
		_check(
			game._group_labels[group].mesh.text == str([2, 1, 1][group]),
			"3D group label follows the actual objects"
		)
	root.size = Vector2i(412, 915)
	game._layout()
	await _settle()
	for step in range(game.activity.placed.size()):
		var item: int = game.activity.placed[step]
		_check(
			game.tokens[item].position.is_equal_approx(
				game.targets[game.activity.target_for_step(step)]
			),
			"rotation keeps already placed cubes in their original groups"
		)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(
		not game.move_token(11) and game.activity.placed.size() == 4,
		"background application cannot distribute objects"
	)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	for step in range(8):
		await _tap(game.main_button.get_global_rect().get_center())
	_check(game.activity.is_complete(), "all twelve actual touches complete the activity")
	for group in range(3):
		_check(game._group_labels[group].mesh.text == "4", "all completed group labels show four")
	_check(
		game.activity.a == 12 and game.activity.b == 3,
		"interaction never substitutes another question"
	)
	game.restart()
	await _settle()
	_check(
		game.activity.placed.is_empty() and game.tokens.size() == 12,
		"restart restores every original 3D object"
	)
	game.queue_free()
	await _settle()
	print("[LearningSharing] %s checks=%d" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
