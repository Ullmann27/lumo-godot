extends SceneTree
## The actual preview GUI signal, camera projection and physics ray select a 3D action.
var failures: Array[String] = []
var checks := 0


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
	var garage = game.garage
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
	game.queue_free()
	for _frame in range(4):
		await process_frame
	if failures.is_empty():
		print("[Garage3DTouch] PASS %d checks: ray, touch action, pointer ownership" % checks)
		quit(0)
	else:
		print("[Garage3DTouch] FAIL ", failures)
		quit(1)
