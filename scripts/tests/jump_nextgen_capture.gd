extends SceneTree
## Render the production scene and drive the actual screen-touch dispatch path.
## Captures are desktop renderer evidence, never an Android/Fold FPS claim.
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String
var captures: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[JumpNextgenCapture] " + label)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _touch(point: Vector2, index: int, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _drag(point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _capture(name: String, game) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and frame.get_size() == root.size, name + " has actual viewport pixels")
	if frame == null:
		return
	_check(frame.save_png(capture_dir.path_join(name + ".png")) == OK, name + " saved")
	captures.append({
		"file": name + ".png", "width": frame.get_width(), "height": frame.get_height(),
		"actor_position": str(game.actor.position), "velocity": str(game.actor.velocity),
		"grounded": game.actor.is_on_floor(), "animation": game.original_lumo.get_current_behavior(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	})


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[JumpNextgenCapture] Real display required; refusing headless capture")
		quit(1)
		return
	capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
	if capture_dir.is_empty() or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		push_error("[JumpNextgenCapture] LUMO_CAPTURE_DIR must be writable")
		quit(1)
		return
	for sample in [[Vector2i(412, 915), 1.0], [Vector2i(690, 829), 1.0], [Vector2i(1280, 720), 1.0], [Vector2i(2400, 1080), 2.625]]:
		root.size = sample[0]
		root.get_node("HostBridge")._options["displayDensity"] = sample[1]
		root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
		DirAccess.remove_absolute("user://jump_session.cfg")
		var game = load("res://scenes/games/jump_islands.tscn").instantiate()
		root.add_child(game)
		await _frames(35)
		var name: String = "%dx%d" % [root.size.x, root.size.y]
		_check(is_instance_valid(game.original_lumo) and game.original_lumo.is_usable(), name + " original fox loaded")
		if not is_instance_valid(game.original_lumo):
			quit(1)
			return
		await _capture("jump_" + name + "_ready", game)
		var stick: Rect2 = game.movement_stick.get_global_rect()
		var button: Rect2 = game.jump_action.get_global_rect()
		_check(not stick.intersects(button), name + " independent thumb rectangles")
		_check(root.get_visible_rect().encloses(stick) and root.get_visible_rect().encloses(button), name + " controls completely visible")
		var start: Vector3 = game.actor.position
		await _touch(stick.get_center(), 3, true)
		await _drag(stick.get_center() + Vector2(0, -stick.size.y * 0.18), 3)
		await _frames(12)
		_check(game.movement_stick.touch_id == 3 and game.touch_direction.y < -0.4, name + " native input captures left finger")
		_check(game.actor.position.z < start.z - 0.20, name + " stick actually moves CharacterBody")
		await _touch(button.get_center(), 4, true)
		await _frames(7)
		_check(game.jump_action.touch_id == 4 and game.jump_held, name + " second finger holds jump independently")
		_check(game.actor.velocity.y > 0.0 and not game.actor.is_on_floor(), name + " touch press creates actual ascent")
		await _capture("jump_" + name + "_touch_ascent", game)
		await _touch(Vector2(4, 4), 9, false)
		_check(game.jump_held and game.movement_stick.touch_id == 3, name + " unrelated finger cannot release controls")
		await _touch(stick.get_center(), 3, false)
		_check(game.touch_direction == Vector2.ZERO and game.jump_held, name + " releasing stick preserves held jump")
		await _frames(24)
		await _capture("jump_" + name + "_airborne", game)
		await _touch(Vector2(4, 4), 4, false)
		_check(not game.jump_held and not game.jump_action.held, name + " releasing jump outside cancels held state")
		await _frames(60)
		_check(game.falls == 0 and game.actor.is_on_floor(), name + " controlled two-finger jump lands safely")
		await _capture("jump_" + name + "_landed", game)
		game._pause()
		await _frames(3)
		_check(game.touch_direction == Vector2.ZERO and not game.jump_held and game.original_lumo.suspended, name + " pause clears inputs and suspends rig")
		game.abandoned = true
		game.queue_free()
		await _frames(3)
	root.get_node("HostBridge")._options.erase("displayDensity")
	DirAccess.remove_absolute("user://jump_session.cfg")
	var report := FileAccess.open(capture_dir.path_join("jump-nextgen-evidence.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"checks": checks, "failures": failures, "display": DisplayServer.get_name(), "captures": captures, "device_fps_measured": false}, "  "))
		report.close()
	else:
		_check(false, "evidence report writable")
	if failures.is_empty():
		print("[JumpNextgenCapture] PASS %d checks, %d actual renderer frames and native two-finger jumps" % [checks, captures.size()])
		quit(0)
	else:
		print("[JumpNextgenCapture] FAIL ", failures)
		quit(1)
