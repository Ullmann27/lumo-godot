extends SceneTree
## Exercise Godot's actual GUI dispatch, in addition to unit-level input checks.

var game


func _initialize() -> void:
	call_deferred("_run")


func _touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	Input.parse_input_event(event)


func _assert_inside(control: Control, bounds: Rect2) -> void:
	var rect: Rect2 = control.get_global_rect()
	assert(rect.position.x >= bounds.position.x - 1 and rect.position.y >= bounds.position.y - 1)
	assert(rect.end.x <= bounds.end.x + 1 and rect.end.y <= bounds.end.y + 1)


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.modal.hide()
	game._physics_process(0)
	await process_frame
	await process_frame
	assert(game.safe_ui.get_global_rect() == Rect2(0, 0, 1280, 720))
	var landscape: Rect2 = game._scaled_safe_insets(
		Rect2(96, 48, 32, 80), Vector2(2560, 1440), Vector2(1280, 720)
	)
	assert(landscape == Rect2(48, 24, 16, 40), "Physical cutouts must scale into UI units")
	var portrait: Rect2 = game._scaled_safe_insets(
		Rect2(0, 96, 0, 112), Vector2(1440, 2560), Vector2(720, 1280)
	)
	assert(portrait == Rect2(0, 48, 0, 56), "Portrait insets must retain their correct edges")
	var stick_at: Vector2 = game.joystick.get_global_rect().get_center() + Vector2(40, 0)
	_touch(1, stick_at, true)
	await process_frame
	assert(game.steering > 0.5, "Real GUI touch must reach the analogue stick")
	var action_at: Vector2 = game.boost_button.get_global_rect().get_center()
	game.boosts = 1
	_touch(2, action_at, true)
	await process_frame
	assert(game.boosts == 0 and game.boost_time > 0)
	assert(game.steering > 0.5)
	_touch(2, action_at, false)
	await process_frame
	assert(game.steering > 0.5)
	_touch(1, Vector2(600, 400), false)
	await process_frame
	assert(game.steering == 0)
	game._open_question()
	await process_frame
	await process_frame
	var title: Label = game.lesson_column.get_child(0).get_child(0)
	assert(title.size.x > 300 and title.size.y < 60, "Lesson heading must remain horizontal")
	assert(game.lesson.size.y < 300, "Lesson card must not cover the whole race")
	game._pause()
	await process_frame
	await process_frame
	assert(game.modal.get_global_rect().end.y <= root.size.y)
	game._apply_safe_area(Rect2(96, 48, 32, 80), Vector2(2560, 1440))
	await process_frame
	await process_frame
	var safe_bounds: Rect2 = game.safe_ui.get_global_rect()
	assert(safe_bounds == Rect2(48, 24, 1216, 656))
	for control in [game.joystick, game.boost_button, game.drift_button, game.lesson, game.modal]:
		_assert_inside(control, safe_bounds)
	# A Fold/orientation resize can change both canvas scale and the cutout edges.
	root.size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	game._apply_safe_area(Rect2(0, 96, 0, 112), Vector2(720, 1280))
	await process_frame
	await process_frame
	safe_bounds = game.safe_ui.get_global_rect()
	for control in [game.joystick, game.boost_button, game.drift_button, game.lesson, game.modal]:
		_assert_inside(control, safe_bounds)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(game.paused and game.steering == 0)
	DirAccess.remove_absolute(game.SESSION)
	game.abandoned = true
	game.queue_free()
	await process_frame
	print(
		"[KartTouchTests] PASS: real two-finger GUI, release outside, learning/pause, scaled safe areas"
	)
	quit(0)
