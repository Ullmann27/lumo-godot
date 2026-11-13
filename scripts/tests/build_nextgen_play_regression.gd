extends SceneTree
## Drive the shipped Bauwelt through real pointer routing, physics, original rig
## and v1 disk persistence. Capture mode refuses headless rendering.
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var game
const TEST_CHILD := "nextgen_build_play_regression"


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[BuildNextgen] " + message)


func _frames(count: int = 6) -> void:
	for _i in range(count):
		await physics_frame


func _dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _pixels(point: Vector2) -> Vector2:
	return point * Vector2(root.size) / root.get_visible_rect().size


func _touch(point: Vector2, finger: int, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = _pixels(point)
	event.pressed = pressed
	event.canceled = canceled
	await _dispatch(event)


func _tap(point: Vector2) -> void:
	await _touch(point, 4, true)
	await _touch(point, 4, false)
	await _frames(2)


func _drag(point: Vector2, finger: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = _pixels(point)
	event.relative = _pixels(relative)
	await _dispatch(event)


func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null:
			return found
	return null


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(
		frame != null and frame.get_size() == Vector2i(1280, 720),
		"True renderer frame dimensions: " + name
	)
	if frame != null:
		_check(
			frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture persisted: " + name
		)


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			push_error("[BuildNextgen] Capture requires an actual rendering server")
			quit(1)
			return
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		if capture_dir.is_empty():
			push_error("[BuildNextgen] LUMO_CAPTURE_DIR is required")
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {"childKey": TEST_CHILD}
	DirAccess.remove_absolute("user://lumo_build_" + TEST_CHILD + "_1.json")
	game = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(game)
	await _frames(10)
	# An isolated child's construction fixture. All operations being verified
	# below use the actual scene, hit testing, GUI dispatch and disk path.
	game.model.clear()
	_check(
		game.model.place("bridge", Vector3i(-16, 0, 9)).is_empty(),
		"Grounded editable part prepared"
	)
	var uid := int(game.model.pieces[-1].uid)
	_check(
		game.model.place("wall", Vector3i(-12, 0, 14)).is_empty(),
		"Real collision obstacle prepared"
	)
	var wall_uid := int(game.model.pieces[-1].uid)
	game._rebuild()
	game.focus = Vector3(-14, 0.3, 11)
	game.radius = 18
	game.orbit = 0.0
	game.tilt = 0.63
	game._camera_update()
	await _frames(5)
	var move := _button(game, "Verschieben")
	_check(
		move != null and move.is_visible_in_tree(), "Move action is reachable in production toolbar"
	)
	if move == null:
		quit(1)
		return
	if "--negative-control" in OS.get_cmdline_user_args():
		move.disabled = true
	await _tap(move.get_global_rect().get_center())
	_check(game.move_mode, "Actual touch enables Move")
	var source: Vector2 = game.camera.unproject_position(Vector3(-14.5, 0.65, 9.5))
	await _touch(source, 4, true)
	_check(game.selected_uid == uid and game.object_drag, "Actual ray captures the selected body")
	await _touch(source, 4, false)
	_check(game.selected_uid == uid and not game.object_drag, "Tap keeps selection without moving")
	_check(
		is_instance_valid(game.selection_ghost) and game.selection_grid.visible,
		"Real ghost geometry and placement grid are visible"
	)
	await _capture("01_build_selection")
	var rotate := _button(game, "Drehen ↻")
	await _tap(rotate.get_global_rect().get_center())
	if game.turn != 1:
		print(
			"[BuildNextgenDiag] rotate tap: turn=", game.turn,
			" selected=", game.selected_uid,
			" viewport=", root.get_visible_rect(),
			" control=", rotate.get_global_rect()
		)
	_check(
		game.turn == 1 and game.model.piece_by_id(uid).turn == 0,
		"Rotation remains a preview until committed"
	)
	var target: Vector2 = game.camera.unproject_position(Vector3(-17.5, 0, 10.5))
	await _tap(target)
	var moved: Dictionary = game.model.piece_by_id(uid)
	_check(
		moved.x == -18 and moved.z == 10 and moved.turn == 1,
		"Touch commits exact snapped position and rotation"
	)
	_check(game.selected_uid == -1, "Successful placement releases the selection")
	await _capture("02_build_moved")
	var moved_state: Dictionary = game.model.to_data()
	_check(game.save_world(false), "Actual v1 project saved to disk")
	await _tap(_button(game, "Rückgängig").get_global_rect().get_center())
	var undone: Dictionary = game.model.piece_by_id(uid)
	_check(
		undone.x == -16 and undone.z == 9 and undone.turn == 0,
		"Actual Undo restores source transform"
	)
	await _tap(_button(game, "Wiederholen").get_global_rect().get_center())
	_check(game.model.to_data() == moved_state, "Actual Redo restores exact saved state")
	_check(game.load_world(false), "Same child's disk save reloads")
	_check(game.model.to_data() == moved_state, "Reload preserves all pieces and identities")
	# Captured object cancellation must never modify the world.
	var moved_point: Vector2 = game.camera.unproject_position(Vector3(-17.5, 0.65, 11.5))
	await _touch(moved_point, 7, true)
	var offset := Vector2(45, 20)
	await _drag(moved_point + offset, 7, offset)
	await _touch(moved_point + offset, 7, false, true)
	_check(game.model.to_data() == moved_state, "Canceled drag preserves disk-equivalent project")
	_check(
		not game.object_drag and game.pointer_id == -1,
		"Canceled gesture relinquishes pointer ownership"
	)
	game._cancel_selection()
	game.focus = Vector3(-15, 0, 11)
	await _tap(game.mode_button.get_global_rect().get_center())
	await _frames(25)
	_check(game.exploring and game.explore_ui.visible, "Actual mode button enters playable Bauwelt")
	_check(
		game.explorer.original_lumo.is_usable(), "Existing original 65-bone Lumo rig is rendered"
	)
	_check(
		game.explorer.original_lumo.skeleton.get_bone_count() == 65,
		"Original character identity retained"
	)
	_check(game.explorer.is_on_floor(), "Lumo stands on existing bank collision")
	var start: Vector3 = game.explorer.position
	var stick_center: Vector2 = game.walk_stick.get_global_rect().get_center()
	var stick_right := stick_center + Vector2(game.walk_stick.size.x * 0.32, 0)
	await _touch(stick_right, 1, true)
	await _frames(20)
	_check(
		game.explorer.position.x > start.x + 0.55,
		"Real held stick drives CharacterBody across bank"
	)
	_check(
		game.explorer.original_lumo.get_current_behavior() in ["walk_loop", "run_loop"],
		"Measured movement drives original skeleton locomotion"
	)
	await _capture("03_build_walking")
	await _frames(75)
	if game.explorer.position.x >= -12.20:
		var wall_body: Node3D = game.placed_nodes.get(wall_uid)
		print(
			"[BuildNextgenDiag] wall: start=", start,
			" current=", game.explorer.position, " velocity=", game.explorer.velocity,
			" wall=", wall_body.global_position if wall_body != null else "<missing>",
			" mask=", game.explorer.collision_mask,
			" body_children=", wall_body.get_child_count() if wall_body != null else -1
		)
	_check(
		game.explorer.position.x < -12.20, "Placed two-cell wall blocks the actual collision body"
	)
	await _touch(stick_right, 1, false)
	await _frames(20)
	var stopped: Vector3 = game.explorer.position
	await _frames(10)
	_check(game.explorer.position.distance_to(stopped) < 0.03, "Released stick brakes to rest")
	var jump_at: Vector2 = game.jump_button.get_global_rect().get_center()
	await _touch(stick_right, 1, true)
	await _touch(jump_at, 2, true)
	_check(
		game.walk_stick.touch_id == 1 and game.jump_button.touch_id == 2,
		"Independent fingers own movement and jump simultaneously"
	)
	await _frames(15)
	_check(
		game.explorer.position.y > stopped.y + 0.55 and game.explorer.jump_count == 1,
		"Real jump button creates a ballistic jump"
	)
	await _capture("04_build_jump")
	await _touch(jump_at, 2, false)
	_check(
		game.walk_stick.touch_id == 1 and game.jump_button.touch_id == -1,
		"Jump release cannot release movement finger"
	)
	await _touch(stick_right, 1, false)
	await _frames(55)
	_check(
		game.explorer.is_on_floor() and game.explorer.landing_count >= 1,
		"Jump lands on real bank collision"
	)
	_check(game.explorer.rescue_count == 0, "Playable sequence needs no rescue teleport")
	await _tap(game.interaction_button.get_global_rect().get_center())
	_check(game.walk_notice.text.contains("Mauer"), "Nearby built wall can actually be inspected")
	game._pause(true)
	var paused_position: Vector3 = game.explorer.position
	await _frames(20)
	_check(
		game.explorer.position.is_equal_approx(paused_position), "Pause freezes explorer physics"
	)
	_check(game.explorer.original_lumo.suspended, "Pause suspends original animation")
	game._pause(false)
	await _tap(game.mode_button.get_global_rect().get_center())
	_check(
		not game.exploring and not game.explorer.active,
		"Return to building shuts down movement input"
	)
	_check(
		game.model.to_data() == moved_state,
		"Walking/jumping/inspection preserve the actual saved construction"
	)
	for sample in [Vector2i(412, 915), Vector2i(690, 829), Vector2i(914, 411)]:
		root.size = sample
		await _frames(5)
		game._toggle_explore()
		await _frames(5)
		var bounds := root.get_visible_rect()
		for control in [
			game.walk_stick, game.jump_button, game.interaction_button, game.mode_button
		]:
			_check(
				bounds.encloses(control.get_global_rect()),
				"Walk control stays in viewport " + str(sample)
			)
			_check(
				control.size.x >= 48 and control.size.y >= 48,
				"Walk touch target >=48dp " + str(sample)
			)
		_check(
			not game.walk_stick.get_global_rect().intersects(game.jump_button.get_global_rect()),
			"Thumb targets never overlap " + str(sample)
		)
		game._toggle_explore()
	game.queue_free()
	await _frames(3)
	DirAccess.remove_absolute("user://lumo_build_" + TEST_CHILD + "_1.json")
	if failures.is_empty():
		print(
			"[BuildNextgen] PASS checks=",
			checks,
			": real touch, move/rotate/history/save, original Lumo walk/jump/collision/pause/layout"
		)
		quit(0)
	else:
		print("[BuildNextgen] FAIL checks=", checks, " failures=", failures)
		quit(1)
