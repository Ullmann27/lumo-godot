extends SceneTree
## Genuine GUI touch dragging; no ScrollContainer value or race progress is assigned.
## Desktop-only touch frontend emulation is restored at teardown, never persisted.
# Each failed expectation exits the asynchronous test immediately after retaining proof.
# gdlint: disable=max-returns

const STEP := 1.0 / 60.0
var game
var output := ""
var checks: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var captures: Array[String] = []
var case_results: Array[Dictionary] = []
var taps: Array[Dictionary] = []
var gui_events: Array[Dictionary] = []
var presses: Dictionary = {}
var previous_touch_emulation := false
var phase := "setup"


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _pixels(control: Control) -> Rect2:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var rectangle := control.get_global_rect()
	return Rect2(rectangle.position * factor, rectangle.size * factor)


func _button(prefix: String) -> Button:
	for child in game.modal_column.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
	return null


func _watch_buttons() -> void:
	for child in game.modal_column.get_children():
		if child is Button:
			var id: int = child.get_instance_id()
			presses[id] = 0
			child.pressed.connect(func(): presses[id] = int(presses[id]) + 1)
			child.gui_input.connect(
				func(event: InputEvent):
					if phase == "normal-settings-taps":
						gui_events.append(
							{
								"id": id,
								"event": event.as_text(),
								"scroll": game.modal_scroll.scroll_vertical,
								"milliseconds": Time.get_ticks_msec()
							}
						)
			)


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	inputs.append(
		{
			"phase": phase,
			"type": "touch",
			"index": index,
			"point": [point.x, point.y],
			"pressed": pressed,
			"milliseconds": Time.get_ticks_msec()
		}
	)
	Input.parse_input_event(event)
	await process_frame


func _tap(control: Control) -> void:
	var id := control.get_instance_id()
	var point := _pixels(control).get_center()
	var before := {
		"id": id,
		"bounds": str(_pixels(control)),
		"scroll": game.modal_scroll.scroll_vertical,
		"presses": presses.duplicate(),
		"muted": game.muted,
		"milliseconds": Time.get_ticks_msec()
	}
	await _touch(0, point, true)
	await _touch(0, point, false)
	await _settle()
	taps.append(
		{
			"phase": phase,
			"before": before,
			"after":
			{
				"valid": is_instance_valid(control),
				"bounds": str(_pixels(control)) if is_instance_valid(control) else "freed",
				"scroll": game.modal_scroll.scroll_vertical,
				"presses": presses.duplicate(),
				"muted": game.muted,
				"milliseconds": Time.get_ticks_msec()
			}
		}
	)


func _drag(index: int, start: Vector2, end: Vector2) -> void:
	await _touch(index, start, true)
	var previous := start
	for step in range(1, 9):
		var point := start.lerp(end, float(step) / 8.0)
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = point
		event.relative = point - previous
		event.screen_relative = event.relative
		event.velocity = (end - start) / 0.45
		event.screen_velocity = event.velocity
		inputs.append(
			{
				"phase": phase,
				"type": "drag",
				"index": index,
				"point": [point.x, point.y],
				"milliseconds": Time.get_ticks_msec()
			}
		)
		Input.parse_input_event(event)
		previous = point
		await process_frame
	await _touch(index, end, false)
	await create_timer(0.15).timeout
	await _settle()


func _wheel(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = _pixels(game.modal_scroll).get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	Input.parse_input_event(event)
	# A wheel is a complete button transition; leaving it held retains GUI mouse focus.
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()


func _visible(control: Control) -> bool:
	return game.modal_scroll.get_global_rect().encloses(control.get_global_rect())


func _reveal(control: Control) -> bool:
	# Real wheel input only prepares a specific control; touch-drag is tested separately.
	for attempt in range(12):
		if _visible(control):
			return true
		await _wheel(control.get_global_rect().end.y > game.modal_scroll.get_global_rect().end.y)
	return _visible(control)


func _top() -> void:
	for attempt in range(12):
		if game.modal_scroll.scroll_vertical == 0:
			return
		await _wheel(false)


func _capture(name: String) -> void:
	await _settle()
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	captures.append(name + ".png")


func _expect(condition: bool, label: String) -> bool:
	checks.append({"phase": phase, "label": label, "pass": condition})
	if not condition:
		print("[KartModalTouch] FAIL: " + label)
		await _finish(1, label)
		return false
	return true


func _snapshot() -> Dictionary:
	return {
		"paused": game.paused,
		"muted": game.muted,
		"auto_gas": game.auto_gas,
		"gas_held": game.gas_held,
		"brake": game.brake,
		"control_brake": game.control_brake,
		"drifting": game.drifting,
		"steering": game.steering,
		"joystick_touch_id": game.joystick.touch_id,
		"action_touch_ids":
		[
			game.gas_button.touch_id,
			game.brake_button.touch_id,
			game.drift_button.touch_id,
			game.boost_button.touch_id,
			game.item_button.touch_id
		],
		"action_held":
		[
			game.gas_button.held,
			game.brake_button.held,
			game.drift_button.held,
			game.boost_button.held,
			game.item_button.held
		],
		"distance": game.distance,
		"checkpoint": game.checkpoint_index,
		"result_id": game.result_id,
		"music": game.music_volume,
		"effects": game.effects_volume,
		"games_filter": game.pause_navigation.get_node("ReturnToGames").mouse_filter,
		"learn_filter": game.pause_navigation.get_node("ReturnToLearning").mouse_filter,
		"games_rect": str(game.pause_navigation.get_node("ReturnToGames").get_global_rect()),
		"learn_rect": str(game.pause_navigation.get_node("ReturnToLearning").get_global_rect())
	}


func _button_drag(button: Button, upward: bool, capture_name: String) -> bool:
	if not await _expect(
		await _reveal(button), "Actual drag button is fully inside ScrollContainer"
	):
		return false
	var clip := _pixels(game.modal_scroll)
	var start := _pixels(button).get_center()
	var end := Vector2(start.x, clip.position.y + 16 if upward else clip.end.y - 16)
	var before := _snapshot()
	var prior_presses := presses.duplicate()
	var prior_scroll: int = game.modal_scroll.scroll_vertical
	await _drag(0, start, end)
	await _capture(capture_name)
	case_results.append(
		{
			"phase": phase,
			"caption": button.text,
			"png": capture_name + ".png",
			"scroll_before": prior_scroll,
			"scroll_after": game.modal_scroll.scroll_vertical,
			"actions_before": prior_presses,
			"actions_after": presses.duplicate(),
			"state_before": before,
			"state_after": _snapshot(),
			"clip_pixels": str(clip),
			"window_pixels": str(DisplayServer.window_get_size()),
			"root_pixels": str(root.size),
			"logical_viewport": str(root.get_visible_rect()),
			"start_pixels": str(start),
			"end_pixels": str(end)
		}
	)
	if not await _expect(
		game.modal_scroll.scroll_vertical != prior_scroll,
		"Touch drag beginning on a Button moves actual scroll content"
	):
		return false
	if not await _expect(
		presses == prior_presses and _snapshot() == before,
		"Drag causes no setting/action press and preserves paused race/footer geometry"
	):
		return false
	return true


func _pause() -> void:
	await _tap(game.top_pause_button)
	await _settle()
	_watch_buttons()


func _resize(size: Vector2i) -> void:
	root.size = size
	await _settle()
	game._apply_safe_area(Rect2(0, 32, 0, 24), Vector2(size))
	await _settle()
	game._apply_responsive_layout()
	await _settle()


func _run() -> void:
	output = OS.get_environment("LUMO_QA_DIR")
	if output.is_empty():
		output = "res://exports/modal-touch"
	DirAccess.make_dir_recursive_absolute(output)
	if not await _expect(
		DisplayServer.get_name() != "headless", "Actual desktop GL window required"
	):
		return
	previous_touch_emulation = Input.emulate_touch_from_mouse
	# Exact 4.6.3 DisplayServer's desktop gate requires this isolated frontend fixture.
	# Android already reports touchscreen=true; no project setting is changed.
	if not OS.has_feature("android"):
		Input.emulate_touch_from_mouse = true
	if not await _expect(
		DisplayServer.is_touchscreen_available() and Input.emulate_mouse_from_touch,
		"Touchscreen frontend and existing touch-to-mouse propagation available"
	):
		return
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	await _resize(Vector2i(1280, 720))
	for step in range(5):
		await _tap(game.garage.next_button)
	await _pause()
	if not await _expect(
		(
			(
				game.pause_navigation.get_node("ReturnToGames").mouse_filter
				== Control.MOUSE_FILTER_STOP
			)
			and (
				game.pause_navigation.get_node("ReturnToLearning").mouse_filter
				== Control.MOUSE_FILTER_STOP
			)
		),
		"Fixed pause footer buttons retain their original capture filters"
	):
		return
	phase = "phone-button-drag"
	await _capture("01-phone-pause-before")
	if not await _button_drag(_button("Ton:"), true, "02-phone-pause-after-ton-drag"):
		return
	var gas := _button("Gas:")
	if not await _expect(
		_visible(gas), "Touch scrolling reveals complete actual Gas caption/button"
	):
		return
	if not await _button_drag(gas, true, "03-phone-gas-after-drag"):
		return
	await _top()
	if not await _button_drag(_button("Weiterfahren"), true, "04-phone-after-continue-drag"):
		return
	phase = "normal-settings-taps"
	await _reveal(_button("Ton:"))
	var ton := _button("Ton:")
	var id := ton.get_instance_id()
	var muted_before: bool = game.muted
	var count_before: int = presses[id]
	await _tap(ton)
	if not await _expect(
		game.muted != muted_before and presses[id] == count_before + 1,
		"Normal Ton tap changes setting exactly once"
	):
		return
	await _tap(ton)
	await _reveal(gas)
	id = gas.get_instance_id()
	count_before = presses[id]
	var gas_before: bool = game.auto_gas
	await _tap(gas)
	if not await _expect(
		game.auto_gas != gas_before and presses[id] == count_before + 1,
		"Normal Gas tap changes setting exactly once"
	):
		return
	await _tap(gas)
	phase = "volume-touch"
	var slider: HSlider = game.modal_column.get_node("VolumeMusik/Slider")
	if not await _expect(
		await _reveal(slider), "Real wheel preparation reveals complete music slider"
	):
		return
	var prior_scroll: int = game.modal_scroll.scroll_vertical
	var volume: float = game.music_volume
	var effects: float = game.effects_volume
	var rectangle := _pixels(slider)
	await _drag(
		0,
		Vector2(rectangle.position.x + rectangle.size.x * 0.35, rectangle.get_center().y),
		Vector2(rectangle.position.x + rectangle.size.x * 0.8, rectangle.get_center().y)
	)
	await _capture("05-phone-volume-after-touch")
	if not await _expect(
		(
			game.music_volume != volume
			and game.effects_volume == effects
			and game.modal_scroll.scroll_vertical == prior_scroll
			and slider.mouse_filter == Control.MOUSE_FILTER_STOP
		),
		"Horizontal volume touch changes only music, never scrolls or changes slider capture"
	):
		return
	for entry in [
		[Vector2i(2176, 1812), "inner", "06-inner-pause-before", "07-inner-pause-after-drag"],
		[Vector2i(2316, 904), "cover", "08-cover-pause-before", "09-cover-pause-after-drag"]
	]:
		phase = "resize-" + entry[1]
		var before := _snapshot()
		await _resize(entry[0])
		await _top()
		await _capture(entry[2])
		if not await _expect(
			(
				game.paused
				and game.result_id == before.result_id
				and game.distance == before.distance
				and game.checkpoint_index == before.checkpoint
			),
			"Actual resize preserves the paused race identity and progress"
		):
			return
		if not await _button_drag(_button("Ton:"), true, entry[3]):
			return
	phase = "racing-multitouch"
	await _resize(Vector2i(1280, 720))
	await _top()
	await _capture("10-phone-restored-pause")
	await _reveal(_button("Gas:"))
	await _tap(_button("Gas:"))
	await _top()
	var resume := _button("Weiterfahren")
	id = resume.get_instance_id()
	count_before = presses[id]
	await _tap(resume)
	if not await _expect(
		not game.paused and presses[id] == count_before + 1,
		"Normal Weiterfahren tap resumes exactly once"
	):
		return
	for frame in range(1000):
		game._physics_process(STEP)
		if game.racing:
			break
	game._physics_process(STEP)
	await _settle()
	var stick := _pixels(game.joystick)
	await _touch(1, stick.get_center() + Vector2(stick.size.x * 0.22, 0), true)
	await _touch(2, _pixels(game.gas_button).get_center(), true)
	game._physics_process(STEP)
	await _capture("11-racing-multitouch")
	if not await _expect(
		(
			game.joystick.touch_id == 1
			and game.gas_button.touch_id == 2
			and game.gas_held
			and game.steering > 0.4
			and game.joystick.mouse_filter == Control.MOUSE_FILTER_STOP
			and game.gas_button.mouse_filter == Control.MOUSE_FILTER_STOP
		),
		"Distinct race fingers still own simultaneous stick/gas; capture filters retained"
	):
		return
	await _touch(1, Vector2(1, 1), false)
	await _touch(2, Vector2(1, 1), false)
	if not await _expect(
		game.steering == 0 and not game.gas_held, "Race fingers release outside their controls"
	):
		return
	await _pause()
	await _reveal(_button("Gas:"))
	await _tap(_button("Gas:"))
	await _top()
	await _tap(_button("Weiterfahren"))
	for frame in range(10000):
		game._physics_process(STEP)
		if frame % 120 == 0:
			await process_frame
		if game.finished:
			break
	if not await _expect(
		game.finished and game.checkpoint_index == 16,
		"Untouched neutral AutoGas completes actual physical two-lap race for result UI"
	):
		return
	for frame in range(300):
		game._physics_process(STEP)
		if game.finish_cine_left <= 0:
			break
	await _settle()
	_watch_buttons()
	phase = "result-button-drag"
	await _capture("12-result-before-drag")
	var new_drive := _button("Neue Fahrt auswählen")
	# The action may already be visible at the top; prepare room for a downward drag.
	await _wheel(true)
	await _reveal(new_drive)
	if not await _expect(
		game.modal_scroll.scroll_vertical > 0,
		"Actual result action preparation has scroll room above"
	):
		return
	if not await _button_drag(new_drive, false, "13-result-after-drag"):
		return
	if not await _expect(
		game.finished and game.checkpoint_index == 16 and not game.menu_active,
		"Result drag cannot restart/leave the actual completed race"
	):
		return
	await _reveal(new_drive)
	id = new_drive.get_instance_id()
	count_before = presses[id]
	await _tap(new_drive)
	await _capture("14-public-new-garage")
	if not await _expect(
		game.menu_active and presses[id] == count_before + 1,
		"Normal result action tap opens the garage exactly once"
	):
		return
	await _finish(0, "")


func _finish(code: int, failure: String) -> void:
	var report := {
		"status": "PASS" if code == 0 else "FAIL",
		"failure": failure,
		"checks": checks,
		"cases": case_results,
		"taps": taps,
		"gui_events": gui_events,
		"inputs": inputs,
		"captures": captures,
		"scope":
		(
			"engine frontend ScreenTouch/ScreenDrag, software GL; isolated touch emulation; "
			+ "no scroll or race-progress assignment"
		),
		"physical_android_or_fold": "PHYSICAL_ANDROID_NOT_EXECUTED",
		"actual_gesture_latency_or_duration": "NOT MEASURED",
		"engine": Engine.get_version_info(),
		"display": DisplayServer.get_name(),
		"touchscreen_available": DisplayServer.is_touchscreen_available()
	}
	FileAccess.open(output.path_join("evidence.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "  ")
	)
	if is_instance_valid(game):
		game.abandoned = true
		game.queue_free()
		await _settle()
	Input.emulate_touch_from_mouse = previous_touch_emulation
	root.world_3d.fallback_environment = null
	await create_timer(0.6).timeout
	if code == 0:
		print(
			(
				"[KartModalTouch] PASS: real pause/result drag, cancelled actions, exact taps, "
				+ "volume, resize and race multitouch"
			)
		)
	quit(code)
