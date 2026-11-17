extends SceneTree
## Exercise save compatibility and the real tabletop's ray picking + touch action.
## PUZZLE_ROTATION_CAPTURE_DIR optionally records genuine rendered frames.
const STATE = preload("res://scripts/creative/puzzle_state.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_warning("[PuzzleRotation] FAIL " + label)


func _run() -> void:
	for count in STATE.COUNTS:
		for motif in range(STATE.MOTIF_COUNT):
			var model = STATE.new()
			model.setup(count, motif, true)
			for id in range(count):
				var original: int = model.pieces[id].turn
				if original != 0:
					_check(
						not model.is_near_target(id, model.target(id)),
						"wrong orientation never promises a match"
					)
					_check(
						not model.try_snap(id, model.target(id)),
						"right position with wrong orientation rejected"
					)
					_check(
						model.rotate_piece(id, -original),
						"piece rotates through real state transition"
					)
				_check(
					model.try_snap(id, model.target(id)),
					"correctly oriented piece accepts its own slot"
				)
				_check(not model.rotate_piece(id), "locked piece cannot rotate")
			_check(model.complete(), "every count and picture remains completable")
			var restored = STATE.new()
			_check(
				(
					restored.restore(JSON.parse_string(JSON.stringify(model.to_data())))
					and restored.complete()
				),
				"JSON round trip preserves rotated completed puzzle"
			)
	var old = STATE.new()
	old.setup(12, 2)
	old.try_snap(0, old.target(0))
	var legacy: Dictionary = old.to_data()
	legacy.erase("rotation_enabled")
	for piece in legacy.pieces:
		piece.erase("turn")
	var restored = STATE.new()
	_check(restored.restore(legacy), "old version-1 shape loads without new fields")
	_check(
		not restored.rotation_enabled and restored.placed() == 1,
		"legacy progress and original difficulty retained"
	)
	_check(not restored.rotate_piece(1), "classic mode retains its original interaction")
	var rotating = STATE.new()
	rotating.setup(12, 0, true)
	rotating.rotate_piece(2)
	rotating.try_snap(2, Vector2(0.7, 1.2))
	var partial: Dictionary = JSON.parse_string(JSON.stringify(rotating.to_data()))
	_check(
		restored.restore(partial) and restored.rotation_enabled, "unfinished rotation mode resumes"
	)
	_check(
		(
			restored.pieces[2].turn == rotating.pieces[2].turn
			and is_equal_approx(restored.pieces[2].x, 0.7)
		),
		"rotation and position survive JSON"
	)
	var before: String = JSON.stringify(restored.to_data())
	for invalid_turn in [-1, 4, 0.5, "right", null]:
		var bad: Dictionary = partial.duplicate(true)
		bad.pieces[2].turn = invalid_turn
		_check(not restored.restore(bad), "corrupt orientation rejected")
		_check(
			JSON.stringify(restored.to_data()) == before,
			"rejected save does not modify open puzzle"
		)
	var bad_locked: Dictionary = partial.duplicate(true)
	bad_locked.pieces[2].locked = true
	bad_locked.pieces[2].turn = 1
	_check(not restored.restore(bad_locked), "misoriented locked piece cannot load")
	var bad_mode: Dictionary = partial.duplicate(true)
	bad_mode.rotation_enabled = "true"
	_check(not restored.restore(bad_mode), "nonboolean mode cannot load")
	_check(
		not rotating.rotate_piece(-1) and not rotating.rotate_piece(99),
		"out-of-range rotation ignored"
	)
	if "--logic-only" not in OS.get_cmdline_user_args():
		await _play_scene()
	if failures.is_empty():
		print(
			(
				"[PuzzleRotation] PASS %d checks: orientation, legacy saves, real picking, touch rotation and resume"
				% checks
			)
		)
		quit(0)
	else:
		print("[PuzzleRotation] FAIL ", failures)
		quit(1)


func _play_scene() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {"childKey": "puzzle_rotation_regression"}
	var game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_count = 6
	game.selected_motif = 3
	game.selected_rotation = true
	game.start()
	await _settle()
	_check_play_area(game, "1280x720 initial table")
	_check(
		(
			game.rotate_button.visible
			and game.rotate_button.custom_minimum_size.x >= 48
			and game.rotate_button.custom_minimum_size.y >= 48
		),
		"live rotation action has a full-size touch target"
	)
	await _capture("puzzle_rotation_table")
	var id := 1
	var point: Vector2 = game.camera.unproject_position(
		game.nodes[id].global_position + Vector3.UP * 0.16
	)
	game._pick(point, 7)
	_check(
		game.dragging == id and game.selected_piece == id, "ray picks the genuinely rotated mesh"
	)
	if game.dragging == id:
		var target: Vector2 = game.model.target(id)
		game._drag(game.camera.unproject_position(Vector3(target.x, 0.35, target.y)))
		_check(not game.matching_hover, "drag refuses misoriented target highlight")
		game._drop()
		_check(
			not game.model.pieces[id].locked and game.selected_piece == id,
			"lift and drop retain selection for single-finger rotation"
		)
		await _capture("puzzle_rotation_hint")
		game.rotate_button.pressed.emit()
		_check(game.model.pieces[id].locked, "touch rotation completes correctly positioned part")
		await _settle()
		_check(
			absf(angle_difference(game.nodes[id].rotation.y, 0.0)) < 0.01,
			"visible quaternion animation reaches correct orientation"
		)
		_check(game._save(), "played rotation state writes successfully")
		game._resume()
		_check(
			game.model.pieces[id].locked and game.model.rotation_enabled,
			"played rotation state resumes through actual scene"
		)
		await _capture("puzzle_rotation_placed")
	game._hint()
	_check(
		game.selected_piece >= 0 and not game.rotate_button.disabled,
		"help selects a visible piece for the same touch control"
	)
	# Every compact layout keeps the action reachable through its existing tool strip.
	for size in [Vector2i(640, 360), Vector2i(412, 915), Vector2i(840, 760)]:
		root.size = size
		await _settle()
		game._resize_ui()
		_check(
			game.rotate_button.size.y >= 48, "rotation target retains minimum height after resize"
		)
		_check_play_area(game, "%dx%d live table" % [size.x, size.y])
		await _capture("puzzle_rotation_%dx%d" % [size.x, size.y])
		game._show_selection()
		await _settle()
		_check(
			root.get_visible_rect().encloses(game.menu.get_global_rect()),
			"mode menu stays inside the small viewport"
		)
		game.menu_scroll.scroll_vertical = int(game.menu_scroll.get_v_scroll_bar().max_value)
		await _settle()
		var last: Control = game.menu_box.get_child(game.menu_box.get_child_count() - 1)
		_check(
			root.get_visible_rect().encloses(last.get_global_rect()),
			"last mode menu action remains reachable by scrolling"
		)
		if size == Vector2i(640, 360):
			await _capture("puzzle_rotation_compact_menu")
		game._continue()
	await _compact_touch_regression(game)
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://lumo_puzzle_puzzle_rotation_regression.json")


func _check_play_area(game: Node3D, label: String) -> void:
	# Check actual projected interaction targets against real HUD rectangles;
	# checking the rotation button alone missed three hidden slots at 640x360.
	var top: float = game.hud_backdrop.get_global_rect().end.y
	var bottom: float = game.tool_scroll.get_global_rect().position.y
	var viewport := root.get_visible_rect()
	for id in range(game.model.count):
		var slot: Vector2 = game.model.target(id)
		var target: Vector2 = game.camera.unproject_position(Vector3(slot.x, 0.35, slot.y))
		_check(
			viewport.has_point(target) and target.y > top + 2.0 and target.y < bottom - 2.0,
			"%s slot %d stays outside the header and footer" % [label, id]
		)
		if game.nodes[id].visible:
			var center: Vector2 = game.camera.unproject_position(
				game.nodes[id].global_position + Vector3.UP * 0.16
			)
			_check(
				viewport.has_point(center) and center.y > top + 2.0 and center.y < bottom - 2.0,
				"%s visible piece %d remains an unobscured touch target" % [label, id]
			)


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 17
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await physics_frame


func _compact_touch_regression(game: Node3D) -> void:
	root.size = Vector2i(1280, 720)
	game.selected_count = 6
	game.selected_motif = 3
	game.start()
	game._resize_ui()
	await _settle()
	var held: Vector2 = game.camera.unproject_position(
		game.nodes[1].global_position + Vector3.UP * 0.16
	)
	await _touch(held, true)
	_check(game.dragging == 1, "landscape resize probe holds an actual selected piece")
	root.size = Vector2i(640, 360)
	await _settle()
	game._resize_ui()
	_check(game.dragging == 1, "window resize retains the current touch owner")
	_check_play_area(game, "640x360 resized while holding a piece")
	await _touch(game.camera.unproject_position(game.nodes[1].global_position), false)
	game.start()
	game._resize_ui()
	await _settle()
	_check_play_area(game, "640x360 fresh six-piece puzzle")
	# Real GUI dispatch used to swallow touches on pieces 0 and 3 at y=140:
	# their centers were inside the progress bar, even though direct _pick passed.
	for id in [0, 3, 1, 4, 2, 5]:
		var point: Vector2 = game.camera.unproject_position(
			game.nodes[id].global_position + Vector3.UP * 0.16
		)
		await _touch(point, true)
		_check(
			game.dragging == id, "640x360 actual touch selects initial piece %d through the UI" % id
		)
		await _touch(point, false)
	# The first upper-row slot must also accept a real drag/release without
	# intercepting the gesture in the header. This piece starts correctly turned.
	var source: Vector2 = game.camera.unproject_position(
		game.nodes[0].global_position + Vector3.UP * 0.16
	)
	await _touch(source, true)
	var slot: Vector2 = game.model.target(0)
	var target: Vector2 = game.camera.unproject_position(Vector3(slot.x, 0.35, slot.y))
	var drag := InputEventScreenDrag.new()
	drag.index = 17
	drag.position = target
	drag.relative = target - source
	Input.parse_input_event(drag)
	await process_frame
	await _touch(target, false)
	_check(
		game.model.pieces[0].locked,
		"640x360 actual touch drag reaches the formerly hidden upper slot"
	)
	for count in STATE.COUNTS:
		for motif in [0, 3]:
			game.selected_count = count
			game.selected_motif = motif
			game.start()
			game._resize_ui()
			await process_frame
			_check_play_area(game, "640x360 %d pieces motif %d" % [count, motif])


func _settle() -> void:
	for frame in range(16):
		await physics_frame
		await process_frame


func _capture(name: String) -> void:
	var folder := OS.get_environment("PUZZLE_ROTATION_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	var result: int = root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	_check(result == OK, "renderer frame written")
