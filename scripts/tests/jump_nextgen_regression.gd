extends SceneTree
## Actual CharacterBody dynamics and original skeleton, not a formula mirror.
var failures: Array[String] = []
var checks: int = 0
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[JumpNextgen] " + message)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _place(at: Vector3 = Vector3(0, 0.4, 1.5)) -> void:
	game._stop_input()
	game.actor.position = at
	game.actor.velocity = Vector3.ZERO
	await _frames(30)
	_check(game.actor.is_on_floor(), "fixture stands on unchanged first island collider")


func _jump(release_after: int) -> Dictionary:
	await _place()
	var start_y: float = game.actor.position.y
	var model_origin: Vector3 = game.original_lumo.position
	var peak: float = start_y
	var rise_seen: bool = false
	var fall_seen: bool = false
	var land_seen: bool = false
	var knee_motion: float = 0.0
	game._set_jump_pressed(true)
	await _frames(2)
	_check(game.actor.velocity.y > 7.0, "jump starts while button is still held, before release")
	for frame in range(110):
		if frame == release_after:
			game._set_jump_pressed(false)
		await physics_frame
		peak = maxf(peak, game.actor.position.y)
		var pose = game.original_lumo.platform_pose
		var state: String = game.original_lumo.get_current_behavior()
		rise_seen = rise_seen or state == "jump_rise"
		fall_seen = fall_seen or state == "jump_fall"
		land_seen = land_seen or state == "land"
		if state == "jump_rise":
			var knee: int = game.original_lumo.skeleton.find_bone("Shin.L")
			knee_motion = maxf(
				knee_motion,
				game.original_lumo.skeleton.get_bone_pose_rotation(knee).angle_to(
					pose.rotations["Shin.L"]
				)
			)
	_check(game.actor.is_on_floor(), "jump lands on real collider without a floor teleport")
	_check(
		rise_seen and fall_seen and land_seen,
		"original visible rig transitions rise, fall and landing"
	)
	_check(knee_motion > 0.25, "original skinned knee actually bends during jump")
	_check(
		game.original_lumo.position == model_origin,
		"animation does not shift actor or collider origin"
	)
	_check(
		not game.original_lumo.platform_active and game.original_lumo.player.is_playing(),
		"authored breathing idle resumes after landing pose settles"
	)
	game._set_jump_pressed(false)
	return {"height": peak - start_y, "knee_angle": knee_motion}


func _open_session(options: Dictionary) -> void:
	root.get_node("SceneRouter").launch_options = options
	game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	await _frames(3)


func _close_session() -> void:
	game.abandoned = true
	game.queue_free()
	await _frames(3)


func _session_isolation() -> void:
	var child_a: String = "jump_nextgen_%d_A" % Time.get_ticks_usec()
	var child_b: String = child_a + "_B"
	var paths: Array[String] = ["user://jump_session.cfg"]
	await _open_session({"grade": 1, "subject": "Mathematik"})
	game.checkpoint = 2
	game._save_session()
	var old_bytes: String = FileAccess.get_file_as_string(game.session_path)
	await _close_session()
	await _open_session({"childKey": child_a, "grade": 1, "subject": "Mathematik"})
	paths.append(game.session_path)
	_check(
		not game.paused and game.checkpoint == 0,
		"named child never inherits unattributed old standalone save"
	)
	game.checkpoint = 3
	game.completed_questions[3] = true
	var child_a_id: String = game.result_id
	game._save_session()
	await _close_session()
	await _open_session({"childKey": child_b, "grade": 1, "subject": "Mathematik"})
	paths.append(game.session_path)
	_check(game.checkpoint == 0 and not game.paused, "child B cannot resume child A progress")
	game.checkpoint = 6
	game._save_session()
	await _close_session()
	await _open_session({"childKey": child_a, "grade": 2, "subject": "Mathematik"})
	paths.append(game.session_path)
	_check(game.checkpoint == 0 and not game.paused, "grade uses independent continuation")
	game.checkpoint = 4
	game._save_session()
	await _close_session()
	await _open_session({"childKey": child_a, "grade": 1, "subject": "Deutsch"})
	paths.append(game.session_path)
	_check(game.checkpoint == 0 and not game.paused, "subject uses independent continuation")
	game._save_session()
	await _close_session()
	await _open_session({"childKey": child_a, "grade": 1, "subject": "Mathematik"})
	_check(
		game.checkpoint == 3 and game.paused and game.result_id == child_a_id,
		"child A resumes its exact result identity and checkpoint"
	)
	_check(game.completed_questions.has(3), "child A learning stops survive all switches")
	_check(
		FileAccess.get_file_as_string("user://jump_session.cfg") == old_bytes,
		"legacy unscoped save remains byte-for-byte intact"
	)
	# Exercise the production restart route, including deferred scene replacement.
	current_scene = game
	game._restart()
	await _frames(10)
	game = current_scene
	_check(
		game != null and game.checkpoint == 0 and not game.paused,
		"real restart creates a fresh adventure only for current scope"
	)
	await _close_session()
	await _open_session({"childKey": child_b, "grade": 1, "subject": "Mathematik"})
	_check(game.checkpoint == 6 and game.paused, "restarting A never deletes B checkpoint")
	await _close_session()
	await _open_session({"childKey": child_a, "grade": 2, "subject": "Mathematik"})
	_check(game.checkpoint == 4 and game.paused, "restarting one grade preserves another grade")
	await _close_session()
	await _open_session({"grade": 1, "subject": "Mathematik"})
	_check(game.checkpoint == 2 and game.paused, "anonymous old scope is still resumable")
	await _close_session()
	for path in paths:
		DirAccess.remove_absolute(path)


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 1, "subject": "Mathematik"}
	game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	await _frames(35)
	_check(
		is_instance_valid(game.original_lumo) and game.original_lumo.is_usable(),
		"production scene uses original imported 65-bone fox"
	)
	if not is_instance_valid(game.original_lumo):
		quit(1)
		return
	var high: Dictionary = await _jump(90)
	var short: Dictionary = await _jump(1)
	_check(
		float(high.height) > 1.7 and float(high.height) < 2.3,
		"held jump has controllable two-metre arc"
	)
	_check(float(short.height) > 0.5 and float(short.height) < 1.2, "tap gives a useful short hop")
	_check(
		float(high.height) - float(short.height) > 0.7,
		"input duration changes actual apex, not only animation"
	)
	print("[JumpNextgen] measured jump heights: ", JSON.stringify({"held": high, "tap": short}))

	await _place()
	game.touch_direction = Vector2(0.4, 0)
	await _frames(24)
	_check(
		absf(game.actor.velocity.x - 2.2) < 0.12, "analogue partial stick produces partial speed"
	)
	_check(
		game.original_lumo.get_current_behavior() == "walk_loop",
		"real low-speed motion selects walk"
	)
	game.touch_direction = Vector2.ZERO
	await _frames(12)
	_check(
		Vector2(game.actor.velocity.x, game.actor.velocity.z).length() < 0.01,
		"releasing stick brakes without residual drift"
	)

	# Leave a real collision edge. A late press in grace time must still jump.
	await _place(Vector3(2.8, 0.4, 1.5))
	game.touch_direction = Vector2.RIGHT
	var guard: int = 0
	while game.actor.is_on_floor() and guard < 50:
		await physics_frame
		guard += 1
	_check(not game.actor.is_on_floor(), "coyote fixture really left the platform")
	await _frames(2)
	game._set_jump_pressed(true)
	await _frames(2)
	_check(game.actor.velocity.y > 7.0, "press just after edge receives coyote jump")

	# The same press after grace expiry must not create an aerial jump.
	await _place(Vector3(2.8, 0.4, 1.5))
	game.touch_direction = Vector2.RIGHT
	guard = 0
	while game.actor.is_on_floor() and guard < 50:
		await physics_frame
		guard += 1
	await _frames(11)
	game._set_jump_pressed(true)
	await _frames(2)
	_check(game.actor.velocity.y < 0.0, "expired coyote cannot become unlimited mid-air jumps")

	# Request the next jump shortly before a genuine landing, then release.
	await _place()
	var ground_y: float = game.actor.position.y
	game._set_jump_pressed(true)
	await _frames(35)
	game._set_jump_pressed(false)
	guard = 0
	while (game.actor.position.y - ground_y > 0.43 or game.actor.velocity.y >= 0.0) and guard < 100:
		await physics_frame
		guard += 1
	_check(not game.actor.is_on_floor() and guard < 100, "buffer press happens before contact")
	game._set_jump_pressed(true)
	var buffered_lift: bool = false
	for _frame in range(12):
		await physics_frame
		buffered_lift = buffered_lift or game.actor.velocity.y > 7.0
	_check(buffered_lift, "pre-landing press is consumed by next grounded physics frame")
	game._set_jump_pressed(false)

	# Independent touch ownership: a third finger cannot release the action.
	await _place()
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = game.jump_action.size * 0.5
	game.jump_action._gui_input(press)
	var unrelated := InputEventScreenTouch.new()
	unrelated.index = 8
	unrelated.pressed = false
	game.jump_action._input(unrelated)
	_check(
		game.jump_action.held and game.jump_action.touch_id == 7,
		"unrelated touch release does not drop held jump"
	)
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = Vector2(-600, -600)
	release.pressed = false
	game.jump_action._input(release)
	_check(
		not game.jump_action.held and game.jump_action.touch_id == -1,
		"captured finger releases outside action rectangle"
	)
	game.movement_stick._move(game.movement_stick.size)
	game.jump_action._gui_input(press)
	game._pause()
	_check(
		game.touch_direction == Vector2.ZERO and not game.jump_held,
		"pause clears stick and buffered action"
	)
	_check(
		not game.movement_stick.enabled and not game.jump_action.enabled,
		"modal blocks both control owners"
	)
	await _frames(3)
	_check(game.original_lumo.suspended, "pause suspends original platform pose")
	game._resume()
	_check(
		game.movement_stick.enabled and game.jump_action.enabled,
		"resume re-enables controls without held input"
	)

	for sample in [
		[Vector2i(412, 915), 1.0],
		[Vector2i(690, 829), 1.0],
		[Vector2i(2400, 1080), 2.625],
		[Vector2i(1236, 2745), 3.0]
	]:
		root.get_node("HostBridge")._options["displayDensity"] = sample[1]
		root.size = sample[0]
		game._layout_ui()
		await _frames(6)
		var physical_scale := Vector2(root.size) / root.get_visible_rect().size
		for control in [game.movement_stick, game.jump_action] + game.header_buttons:
			var dp: Vector2 = control.size * physical_scale / float(sample[1])
			_check(dp.x >= 48.0 and dp.y >= 48.0, "all native targets >=48dp at " + str(sample))
			_check(
				root.get_visible_rect().encloses(control.get_global_rect()),
				(
					"control fully reachable at %s (%s %s in %s)"
					% [
						str(sample),
						control.name,
						control.get_global_rect(),
						root.get_visible_rect()
					]
				)
			)
		_check(
			not game.movement_stick.get_global_rect().intersects(
				game.jump_action.get_global_rect()
			),
			"thumb controls never overlap at " + str(sample)
		)
	root.get_node("HostBridge")._options.erase("displayDensity")
	game.abandoned = true
	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute("user://jump_session.cfg")
	await _session_isolation()
	if failures.is_empty():
		print(
			(
				"[JumpNextgen] PASS %d checks: actual variable jumps, coyote, buffer, original rig, pause, dp layouts and isolated saves"
				% checks
			)
		)
		quit(0)
	else:
		print("[JumpNextgen] FAIL ", failures)
		quit(1)
