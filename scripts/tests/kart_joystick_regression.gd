extends SceneTree
## Exercise the real Control input path, including release outside its rectangle.

var stick: Control
var failures: PackedStringArray = []
var emitted: Array[Vector2] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		print("[KartJoystickTests] FAIL: ", label)


func _mouse_button(button: MouseButton, at: Vector2, down: bool, mask: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = down
	event.button_mask = mask
	root.push_input(event, true)


func _mouse_motion(at: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = mask
	root.push_input(event, true)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	root.push_input(event, true)


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	root.push_input(event, true)


func _neutral(label: String) -> void:
	_check(stick.target == Vector2.ZERO, label + ": target cleared")
	_check(stick.touch_id == -1 and not stick.mouse_active, label + ": owner cleared")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	Input.emulate_mouse_from_touch = false
	Input.emulate_touch_from_mouse = false
	stick = load("res://scripts/games/kart_joystick.gd").new()
	root.add_child(stick)
	stick.position = Vector2(80, 60)
	stick.size = Vector2(200, 200)
	stick.axis_changed.connect(func(value: Vector2) -> void: emitted.append(value))
	await process_frame
	var center := stick.position + stick.size * 0.5
	var right := center + Vector2(40, 0)
	var outside := Vector2(700, 500)

	_mouse_motion(right, 0)
	_mouse_button(MOUSE_BUTTON_LEFT, right, true, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_check(stick.mouse_active and stick.target.x > 0.5, "left button acquires and steers")
	var held: Vector2 = stick.target
	var signals_before := emitted.size()
	_mouse_button(MOUSE_BUTTON_RIGHT, right, true, MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)
	_mouse_button(MOUSE_BUTTON_RIGHT, right, false, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_check(stick.mouse_active, "right release preserves held left owner")
	_check(stick.target == held, "right release preserves held steering target")
	_check(emitted.size() == signals_before, "right release emits no steering reset")
	_mouse_button(MOUSE_BUTTON_LEFT, outside, false, 0)
	await process_frame
	_neutral("left release outside")

	_mouse_button(MOUSE_BUTTON_RIGHT, right, true, MOUSE_BUTTON_MASK_RIGHT)
	await process_frame
	_neutral("right button cannot acquire")
	_mouse_button(MOUSE_BUTTON_RIGHT, right, false, 0)

	_touch(1, right, true)
	await process_frame
	_check(stick.touch_id == 1 and stick.target.x > 0.5, "first finger acquires and steers")
	held = stick.target
	signals_before = emitted.size()
	_touch(2, center - Vector2(40, 0), true)
	_drag(2, center - Vector2(60, 0))
	_touch(2, outside, false)
	await process_frame
	_check(stick.touch_id == 1, "second finger does not steal or release owner")
	_check(stick.target == held, "second finger does not change steering")
	_check(emitted.size() == signals_before, "second finger emits no steering change")
	var drag_at := center + Vector2(-300, 0)
	_drag(1, drag_at)
	await process_frame
	_check(stick.target.is_equal_approx(Vector2.LEFT), "owner drag outside clamps in local coordinates")
	_touch(1, outside, false)
	await process_frame
	_neutral("owner finger release outside")

	_touch(3, right, true)
	await process_frame
	_check(stick.touch_id == 3, "touch acquired before disable")
	stick.set_enabled(false)
	_neutral("disable while touch held")
	signals_before = emitted.size()
	_drag(3, center - Vector2(40, 0))
	_touch(3, outside, false)
	_touch(4, right, true)
	_touch(4, right, false)
	_mouse_button(MOUSE_BUTTON_LEFT, right, true, MOUSE_BUTTON_MASK_LEFT)
	_mouse_motion(center - Vector2(40, 0), MOUSE_BUTTON_MASK_LEFT)
	_mouse_button(MOUSE_BUTTON_LEFT, outside, false, 0)
	await process_frame
	_neutral("disabled input ignored")
	_check(emitted.size() == signals_before, "disabled input emits no steering change")

	stick.set_enabled(true)
	_mouse_motion(right, 0)
	_mouse_button(MOUSE_BUTTON_LEFT, right, true, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_check(stick.mouse_active and stick.target.x > 0.5, "new mouse press after reenable works")
	stick.set_enabled(false)
	_neutral("disable while mouse held")
	signals_before = emitted.size()
	_mouse_motion(center - Vector2(40, 0), MOUSE_BUTTON_MASK_LEFT)
	_mouse_button(MOUSE_BUTTON_LEFT, outside, false, 0)
	await process_frame
	_neutral("stale mouse events after disable")
	_check(emitted.size() == signals_before, "stale mouse events emit no steering change")
	stick.set_enabled(true)
	_touch(5, right, true)
	await process_frame
	_check(stick.touch_id == 5 and stick.target.x > 0.5, "new touch after reenable works")
	_touch(5, outside, false)
	await process_frame
	_neutral("final touch release")

	stick.queue_free()
	await process_frame
	if failures.is_empty():
		print("[KartJoystickTests] PASS")
		quit(0)
	else:
		print("[KartJoystickTests] FAILED: ", failures.size(), " checks")
		quit(1)
