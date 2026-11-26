extends SceneTree
## Exercise Godot's actual GUI dispatch, in addition to unit-level input checks.

const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0
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


func _touch_turn(difficulty: String, deflection: float, pace: float) -> float:
	# Reset the car to the same point and pace, then measure real yaw from a
	# physical screen press. The HUD and normal physics process see the touch.
	var start := 70.0
	game.difficulty = difficulty
	game.speed = pace
	game.distance = start
	game.previous_road_distance = start
	game.player.transform = game.world.reset_transform(start)
	game.player_heading = game._heading(start)
	game.physical_velocity = game.world.forward(start) * pace
	game.boost_time = 0.0
	game.auto_gas = true
	var heading: float = game.player_heading
	var stick: Rect2 = game.joystick.get_global_rect()
	var aim: Vector2 = stick.get_center() + Vector2(stick.size.x * 0.31 * deflection, 0.0)
	var physical: Vector2 = aim * Vector2(root.size) / root.get_visible_rect().size
	_touch(5, physical, true)
	await process_frame
	assert(is_equal_approx(game.steering, deflection), "Analog input reached the actual racing controls")
	for frame in range(6):
		game._physics_process(STEP)
	var yaw: float = absf(angle_difference(heading, game.player_heading))
	_touch(5, physical, false)
	await process_frame
	assert(is_zero_approx(game.steering), "Releasing the touch leaves the stick neutral")
	return yaw


func _cover_steering(display: Vector2i) -> void:
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	root.size = display
	await process_frame
	await process_frame
	var insets := Rect2(38, 0, 42, 26) if display.x > display.y else Rect2(0, 38, 0, 42)
	game._apply_safe_area(insets, Vector2(display))
	game._apply_responsive_layout()
	game.paused = false
	game.modal.hide()
	game._update_hud()
	await process_frame
	var light: float = await _touch_turn("gemuetlich", 0.10, 40.0)
	var expert_light: float = await _touch_turn("pro", 0.10, 40.0)
	assert(light <= 0.0001 and expert_light > 0.02, "Thumb jitter leaves Entdecken neutral")
	var slower: float = await _touch_turn("gemuetlich", 0.45, 14.0)
	var beginner: float = await _touch_turn("gemuetlich", 0.45, 40.0)
	var adventure: float = await _touch_turn("flott", 0.45, 40.0)
	var expert: float = await _touch_turn("pro", 0.45, 40.0)
	assert(beginner > 0.035 and beginner < expert * 0.55, "Small high-speed corrections remain useful and gentle")
	assert(beginner < adventure and adventure < expert, "The three touch responses remain distinct")
	assert(slower > beginner, "Slow travel keeps more steering response")
	var full_beginner: float = await _touch_turn("gemuetlich", 1.0, 40.0)
	var full_expert: float = await _touch_turn("pro", 1.0, 40.0)
	assert(is_equal_approx(full_beginner, full_expert), "Full stick throw retains turning authority")
	print("[KartTouchSteering] %s @2.625 PASS. Yaw in 100 ms at high pace, 45%% throw: %.2f° / %.2f° / %.2f°." % [display, rad_to_deg(beginner), rad_to_deg(adventure), rad_to_deg(expert)])


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
	await _cover_steering(Vector2i(2520, 1080))
	await _cover_steering(Vector2i(1080, 2520))
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(game.paused and game.steering == 0)
	DirAccess.remove_absolute(game.SESSION)
	game.abandoned = true
	if not (await SCENE_TEARDOWN.release_scene(self, game, "[KartTouchTests]")):
		push_error("[KartTouchTests] FAIL: scene/audio teardown incomplete")
		quit(1)
		return
	print(
		(
			"[KartTouchTests] PASS: real two-finger GUI, window Back countdown/race pause, "
			+ "touch resume, simultaneous steering+BREMSE, release outside, no learning panel, scaled safe areas"
		)
	)
	quit(0)
