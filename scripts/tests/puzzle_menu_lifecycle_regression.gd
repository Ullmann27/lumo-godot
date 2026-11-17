extends SceneTree
## Real root-viewport touch dispatch through the production Puzzle menu.
## The companion strict runner also rejects every native ERROR in the log.
var checks := 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var captures: Array[String] = []
var game
var evidence_dir := ""
var previous_point := Vector2.ZERO


func _initialize() -> void:
	evidence_dir = OS.get_environment("LUMO_PUZZLE_MENU_EVIDENCE_DIR")
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("[PuzzleMenuLifecycle] " + message)


func _frames(count: int = 3) -> void:
	for _frame in range(count):
		await process_frame


func _touch(point: Vector2, pressed: bool, label: String) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 21
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	events.append({"kind": "touch", "pressed": pressed, "label": label,
		"physical_position": [event.position.x, event.position.y],
		"process_frame": Engine.get_process_frames()})
	previous_point = point


func _drag(point: Vector2) -> void:
	var scale := Vector2(root.size) / root.get_visible_rect().size
	var event := InputEventScreenDrag.new()
	event.index = 21
	event.position = point * scale
	event.relative = (point - previous_point) * scale
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	events.append({"kind": "drag", "physical_position": [event.position.x, event.position.y],
		"process_frame": Engine.get_process_frames()})
	previous_point = point


func _button(label: String) -> Button:
	for child in game.find_children("*", "Button", true, false):
		if not child.is_visible_in_tree() or child.is_queued_for_deletion():
			continue
		if (label == "count" and game.menu_box.is_ancestor_of(child) and child.text.ends_with(" Teile")) or child.text.begins_with(label):
			return child
	return null


func _tap(label: String, held_frames: int = 0) -> bool:
	var button := _button(label)
	_check(is_instance_valid(button), "visible production button: " + label)
	if button == null:
		return false
	if game.menu_box.is_ancestor_of(button):
		# Only reveal a clipped target; this helper is not a scroll-gesture test.
		if not game.menu_scroll.get_global_rect().encloses(button.get_global_rect()):
			game.menu_scroll.ensure_control_visible(button)
			await _frames(3)
	var rect: Rect2 = button.get_global_rect()
	_check(root.get_visible_rect().encloses(rect), "target inside viewport: " + label)
	if game.menu_box.is_ancestor_of(button):
		_check(game.menu_scroll.get_global_rect().grow(1.0).encloses(rect),
			"target inside menu scroll viewport: " + label)
	print("[PuzzleMenuLifecycle] tap ", label, " frame=", Engine.get_process_frames())
	_touch(rect.get_center(), true, label)
	await _frames(held_frames)
	_touch(rect.get_center(), false, label)
	await _frames(3)
	return true


func _menu_is_settled(label: String) -> void:
	var labels: Array[String] = []
	for child in game.menu_box.get_children():
		_check(not child.is_queued_for_deletion(), label + " obsolete child freed after dispatch")
		if child is Button and child.is_visible_in_tree():
			_check(not labels.has(child.text), label + " no duplicate visible menu action")
			labels.append(child.text)
	samples.append({"label": label, "count": game.selected_count,
		"motif": game.selected_motif, "rotation": game.selected_rotation,
		"visible_actions": labels})


func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var file := "%dx%d-%s.png" % [root.size.x, root.size.y, label]
	var picture := root.get_texture().get_image()
	_check(picture != null and picture.get_size() == root.size, "actual viewport raster: " + file)
	if picture != null:
		_check(picture.save_png(evidence_dir.path_join(file)) == OK, "saved actual capture: " + file)
		captures.append(file)


func _select_piece(id: int) -> void:
	await physics_frame
	var point: Vector2 = game.camera.unproject_position(game.nodes[id].global_position + Vector3.UP * 0.16)
	_touch(point, true, "select real piece")
	await _frames(2)
	_check(game.dragging == id and game.selected_piece == id, "root touch picks requested actual mesh")
	_touch(point, false, "release selection")
	await _frames(2)
	_check(game.selected_piece == id, "real release retains piece selection")


func _exercise(size: Vector2i) -> void:
	root.size = size
	root.get_node("HostBridge")._options["displayDensity"] = 1.0
	root.get_node("SceneRouter").launch_options = {"childKey": "puzzle_menu_lifecycle_%dx%d" % [size.x, size.y]}
	game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await _frames(12)
	# X11 needs real OS pointer entry before emulated touch-to-mouse button dispatch.
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(root.get_visible_rect().size * 0.5)
		await _frames(3)
	_check(not FileAccess.file_exists(game.save_path), "fresh isolated profile has no existing save")
	_check(game.selected_count == 12 and game.selected_motif == 3 and not game.selected_rotation,
		"unmodified production defaults")
	for expected in [24, 48, 96, 6]:
		await _tap("count", 2)
		_check(game.selected_count == expected, "each released count button advances exactly once")
		_menu_is_settled("count " + str(expected))
	# Quick presses have no artificial hold delay, only normal frame/layout completion.
	for index in range(6):
		await _tap("Modus:")
		_check(game.selected_rotation == (index % 2 == 0), "rapid mode press toggles exactly once")
		_check(game.selected_count == 6 and game.selected_motif == 3, "mode preserves other selections")
		_menu_is_settled("rapid mode " + str(index))
	for expected in [4, 0, 1, 2, 3]:
		await _tap("Bild:")
		_check(game.selected_motif == expected, "rapid motif release advances exactly once")
		_menu_is_settled("rapid motif " + str(expected))
	for expected in [12, 24, 48, 96, 6]:
		await _tap("count")
		_check(game.selected_count == expected, "rapid count release advances exactly once")
		_menu_is_settled("rapid count " + str(expected))
	await _tap("Modus:")
	_check(game.selected_rotation, "rotation mode selected by actual menu touch")
	await _capture("rotation-menu")
	await _tap("Neues Puzzle beginnen")
	await _frames(4)
	_check(not game.paused and not game.menu.visible and game.model.count == 6,
		"actual start creates playable six-piece game")
	_check(game.model.rotation_enabled and game.model.placed() == 0 and game.model.moves == 0,
		"rotation mode begins without manufactured progress")
	await _select_piece(2)
	var old_turn: int = game.model.pieces[2].turn
	await _tap("↻ Drehen")
	_check(game.model.pieces[2].turn == (old_turn + 1) % 4, "gameplay rotation button works after menu churn")
	await _capture("rotation-play")
	await _tap("Ⅱ")
	_check(game.paused and game.menu.visible, "real header touch opens pause menu")
	var saved_state: String = JSON.stringify(game.model.to_data())
	await _tap("Anderes Puzzle")
	_menu_is_settled("pause to selection")
	_check(JSON.stringify(game.model.to_data()) == saved_state,
		"selection menu preserves played puzzle data")
	await _tap("Modus:")
	_check(not game.selected_rotation, "classic mode selected by actual touch")
	await _tap("Neues Puzzle beginnen")
	await _frames(4)
	_check(not game.paused and not game.menu.visible and not game.model.rotation_enabled,
		"classic start still works after pause and replacement")
	_check(not game.rotate_button.visible, "classic mode hides rotation action")
	await physics_frame
	var point: Vector2 = game.camera.unproject_position(game.nodes[0].global_position + Vector3.UP * 0.16)
	_touch(point, true, "classic piece pick")
	await _frames(2)
	_check(game.dragging == 0, "classic mode accepts real touch picking")
	if game.dragging == 0:
		var target: Vector2 = game.model.target(0) - game.drag_offset
		var end: Vector2 = game.camera.unproject_position(Vector3(target.x, 0.35, target.y))
		for step in range(1, 9):
			_drag(point.lerp(end, float(step) / 8.0))
			await process_frame
		_touch(end, false, "classic matching slot release")
		await _frames(4)
		_check(game.model.pieces[0].locked and game.model.placed() == 1,
			"actual classic drag and release places exactly one piece")
	await _capture("classic-play")
	await _tap("Ⅱ")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	_check(saved is Dictionary and saved.pieces[0].locked, "real pause saves the played placement")
	await _tap("Weiterpuzzeln")
	_check(not game.paused and not game.menu.visible and game.model.pieces[0].locked,
		"actual resume retains the played placement")
	game.queue_free()
	await _frames(4)
	game = null


func _run() -> void:
	if evidence_dir.is_empty() or DirAccess.make_dir_recursive_absolute(evidence_dir) != OK:
		push_error("[PuzzleMenuLifecycle] writable LUMO_PUZZLE_MENU_EVIDENCE_DIR required")
		quit(1)
		return
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() == "headless":
		push_error("[PuzzleMenuLifecycle] real renderer required for capture")
		quit(1)
		return
	var previous_emulation := Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	for size in [Vector2i(960, 540), Vector2i(640, 360)]:
		await _exercise(size)
	Input.emulate_mouse_from_touch = previous_emulation
	root.get_node("HostBridge")._options.erase("displayDensity")
	var report := {"checks": checks, "failures": failures, "display": DisplayServer.get_name(),
		"production_scene": "res://scenes/creative/puzzle_world.tscn", "events": events,
		"menu_samples": samples, "captures": captures, "device_fps_measured": false,
		"state_or_piece_position_injection_used": false,
		"strict_native_error_log_gate_required": true}
	var file := FileAccess.open(evidence_dir.path_join("puzzle-menu-lifecycle.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		failures.append("evidence report could not be saved")
	if failures.is_empty():
		print("[PuzzleMenuLifecycle] PASS ", checks, " behavioral checks; strict native log gate still required")
		quit(0)
	else:
		print("[PuzzleMenuLifecycle] FAIL ", failures)
		quit(1)
