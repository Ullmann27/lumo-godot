extends SceneTree
## Production native navigation and preview gestures, plus the retained legacy
## garage's projected actions. Hidden scenery must never navigate the new menu.
var failures: Array[String] = []
var checks := 0
var completed_sections := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[Garage3DTouch] FAIL " + label)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for _frame in range(12):
		await physics_frame
	await _native_actions(game.garage)
	game.queue_free()
	await _settle()
	# The old ray/action contract still belongs to the explicitly retained base
	# garage. Do not require invisible legacy plaques to navigate the native UI.
	var legacy = load("res://scripts/games/kart_garage_menu.gd").new()
	root.add_child(legacy)
	await _settle()
	await _legacy_actions(legacy)
	legacy.queue_free()
	await _settle()
	_check(completed_sections == 2, "both production and legacy pointer suites complete")
	if failures.is_empty():
		print("[Garage3DTouch] PASS %d checks: native input, legacy ray, pointer ownership" % checks)
		quit(0)
	else:
		print("[Garage3DTouch] FAIL ", failures)
		quit(1)


func _settle() -> void:
	for _frame in range(8):
		await process_frame


func _dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _pixels(point: Vector2) -> Vector2:
	return point * Vector2(root.size) / root.get_visible_rect().size


func _touch(point: Vector2, index: int, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _pixels(point)
	event.pressed = pressed
	event.canceled = canceled
	await _dispatch(event)


func _drag(point: Vector2, index: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _pixels(point)
	event.relative = _pixels(relative)
	await _dispatch(event)


func _mouse(point: Vector2, button: MouseButton, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = _pixels(point)
	event.button_index = button
	event.pressed = pressed
	event.device = device
	await _dispatch(event)


func _native_actions(garage) -> void:
	garage.reduced_motion = true
	garage.step = 0
	garage._refresh()
	await _settle()
	_check(garage._garage_targets.is_empty(), "native navigation owns no legacy 3D hit targets")
	for action in garage.garage_buttons:
		var body: Node3D = garage.garage_buttons[action].body
		var projected: Vector2 = garage.preview_camera.unproject_position(body.global_position)
		_check(not body.is_visible_in_tree() and garage._pick_garage_action(projected).is_empty(),
			"native hidden %s plaque cannot activate navigation" % action)
	var preview_rect: Rect2 = garage.preview_container.get_global_rect()
	var point := preview_rect.position + preview_rect.size * Vector2(0.72, 0.52)
	await _touch(point, 4, true)
	_check(garage._preview_touch_index == 4 and garage.rotate_drag,
		"actual preview touch owns the native rotation gesture")
	await _touch(point, 5, false)
	_check(garage._preview_touch_index == 4 and garage.rotate_drag,
		"another finger cannot release the native preview gesture")
	var angle: float = garage.preview_angle
	await _drag(point + Vector2(80, 0), 5, Vector2(80, 0))
	_check(is_equal_approx(garage.preview_angle, angle) and garage._preview_touch_index == 4,
		"another finger cannot rotate or steal the native preview")
	await _drag(point + Vector2(80, 0), 4, Vector2(80, 0))
	_check(garage.preview_angle > angle and garage.step == 0,
		"owner drag rotates the live kart without navigating")
	await _touch(point + Vector2(80, 0), 4, false, true)
	_check(garage._preview_touch_index == -1 and not garage.rotate_drag and garage.step == 0,
		"canceled native touch releases ownership without navigation")
	await _touch(point, 4, false)
	_check(not garage.rotate_drag and garage.step == 0, "duplicate native release stays inert")
	for device in [InputEvent.DEVICE_ID_EMULATION, 0]:
		var button := MOUSE_BUTTON_LEFT if device == InputEvent.DEVICE_ID_EMULATION else MOUSE_BUTTON_RIGHT
		await _mouse(point, button, true, device)
		_check(not garage.rotate_drag and garage.step == 0,
			"emulated/secondary mouse cannot own the native preview (%d)" % device)
		await _mouse(point, button, false, device)
	# Actual native GUI input must reach the production section callbacks. A
	# negative control disables this real button, proving the gate fails closed.
	var track_button: Button = garage.step_buttons[3]
	if "--negative-control" in OS.get_cmdline_user_args():
		track_button.disabled = true
	point = track_button.get_global_rect().get_center()
	_check(track_button.is_visible_in_tree(), "native track action is visible")
	await _touch(point, 4, true)
	await _touch(point, 4, false)
	await _settle()
	_check(garage.step == 3 and is_instance_valid(garage.preview_world),
		"matching native touch opens the actual track section")
	point = garage.step_buttons[0].get_global_rect().get_center()
	await _touch(point, 4, true)
	await _touch(point, 4, false)
	await _settle()
	_check(garage.step == 0, "native touch returns to the actual race section")
	point = track_button.get_global_rect().get_center()
	await _mouse(point, MOUSE_BUTTON_LEFT, true)
	await _mouse(point, MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(garage.step == 3 and is_instance_valid(garage.preview_world),
		"real primary mouse opens the actual native track section")
	completed_sections += 1


func _legacy_actions(garage) -> void:
	garage.step = 0
	garage._refresh()
	for _frame in range(8):
		await physics_frame
	var body: Node3D = garage.garage_buttons.strecke.body
	var point: Vector2 = garage.preview_camera.unproject_position(body.global_position)
	_check(garage._pick_garage_action(point) == "strecke", "real ray hits Strecke plaque")
	var press := InputEventScreenTouch.new()
	press.index = 4
	press.position = point
	press.pressed = true
	garage.preview_container.gui_input.emit(press)
	var other_release := InputEventScreenTouch.new()
	other_release.index = 5
	other_release.position = point
	other_release.pressed = false
	garage.preview_container.gui_input.emit(other_release)
	_check(garage.step == 0, "another finger cannot activate held action")
	var other_drag := InputEventScreenDrag.new()
	other_drag.index = 5
	other_drag.position = point + Vector2(80, 0)
	other_drag.relative = Vector2(80, 0)
	garage.preview_container.gui_input.emit(other_drag)
	_check(not garage.rotate_drag, "another finger cannot steal the pressed plaque")
	var release := InputEventScreenTouch.new()
	release.index = 4
	release.position = point
	release.pressed = false
	garage.preview_container.gui_input.emit(release)
	_check(garage.step == 3, "matching touch release opens actual track step")
	garage.step = 0
	garage._refresh()
	for _frame in range(8):
		await physics_frame
	point = garage.preview_camera.unproject_position(body.global_position)
	press.position = point
	release.position = point
	garage.preview_container.gui_input.emit(press)
	release.canceled = true
	garage.preview_container.gui_input.emit(release)
	_check(garage.step == 0, "canceled touch does not activate action")
	release.canceled = false
	garage.preview_container.gui_input.emit(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = point + Vector2(80, 0)
	drag.relative = Vector2(80, 0)
	var angle: float = garage.preview_angle
	garage.preview_container.gui_input.emit(drag)
	garage.preview_container.gui_input.emit(release)
	_check(
		garage.step == 0 and garage.preview_angle > angle, "drag rotates without accidental action"
	)
	var mouse := InputEventMouseButton.new()
	mouse.position = point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.pressed = true
	garage.preview_container.gui_input.emit(mouse)
	mouse.pressed = false
	garage.preview_container.gui_input.emit(mouse)
	_check(garage.step == 0, "synthesized mouse cannot duplicate touch action")
	mouse.device = 0
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	garage.preview_container.gui_input.emit(mouse)
	mouse.pressed = false
	garage.preview_container.gui_input.emit(mouse)
	_check(garage.step == 0, "secondary mouse button does not activate action")
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	garage.preview_container.gui_input.emit(mouse)
	mouse.pressed = false
	garage.preview_container.gui_input.emit(mouse)
	_check(garage.step == 3, "real primary mouse retains action support")
	completed_sections += 1
