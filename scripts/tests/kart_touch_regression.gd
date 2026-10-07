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


func _android_back() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	root.go_back_requested.emit()
	await create_timer(0.05).timeout


func _resume_touch() -> void:
	var button: Button = game.modal_column.get_child(2)
	assert(button.text == "Weiterfahren")
	var at: Vector2 = button.get_global_rect().get_center()
	_touch(4, at, true)
	await process_frame
	_touch(4, at, false)
	await process_frame
	assert(not game.paused, "Real GUI touch resumes the paused race")


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"})
	game.set_physics_process(false)
	game.countdown = 3
	await process_frame
	await _android_back()
	await process_frame
	await process_frame
	assert(game.paused and game.countdown == 3 and not quit_on_go_back)
	await _resume_touch()
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
	# A second right-thumb finger can hold BREMSE without stealing the steering finger.
	var brake_at: Vector2 = game.brake_button.get_global_rect().get_center()
	_touch(3, brake_at, true)
	await process_frame
	assert(game.control_brake == 1.0, "Independent brake touch reaches the pedal")
	assert(game.steering > 0.5, "Steering stays captured while BREMSE is held")
	_touch(3, brake_at, false)
	await process_frame
	assert(game.control_brake == 0.0)
	assert(game.steering > 0.5, "Releasing BREMSE does not release the steering finger")
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
	await _android_back()
	await process_frame
	await process_frame
	assert(game.paused and game.modal.visible, "Back pauses the running race")
	await _resume_touch()
	assert(not game.modal.visible and game.racing, "Touch resumes the race, no task panel")
	assert("lesson" not in game and "question_open" not in game, "Kart has no learning panel")
	await _android_back()
	await process_frame
	await process_frame
	assert(game.modal.get_global_rect().end.y <= root.size.y)
	game._apply_safe_area(Rect2(96, 48, 32, 80), Vector2(2560, 1440))
	await process_frame
	await process_frame
	var safe_bounds: Rect2 = game.safe_ui.get_global_rect()
	assert(safe_bounds == Rect2(48, 24, 1216, 656))
	for control in [game.joystick, game.boost_button, game.drift_button, game.modal]:
		_assert_inside(control, safe_bounds)
	# A Fold/orientation resize can change both canvas scale and the cutout edges.
	root.size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	game._apply_safe_area(Rect2(0, 96, 0, 112), Vector2(720, 1280))
	await process_frame
	await process_frame
	safe_bounds = game.safe_ui.get_global_rect()
	for control in [game.joystick, game.boost_button, game.drift_button, game.modal]:
		_assert_inside(control, safe_bounds)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(game.paused and game.steering == 0)
	DirAccess.remove_absolute(game.SESSION)
	game.abandoned = true
	game.queue_free()
	await process_frame
	print(
		(
			"[KartTouchTests] PASS: real two-finger GUI, window Back countdown/race pause, "
			+ "touch resume, simultaneous steering+BREMSE, release outside, no learning panel, scaled safe areas"
		)
	)
	await create_timer(0.12).timeout
	quit(0)
