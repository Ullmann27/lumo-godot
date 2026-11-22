extends SceneTree
## Drive the real grid for two full laps. Only the visible controls receive
## inputs. A measured pace below the rivals' cruise lets all five finish first.
const COURSE = preload("res://scripts/games/windwerk/kart_windwerk_course.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0
var shots := OS.get_environment("LUMO_WINDWERK_SHOTS")
var failures: Array[String] = []
var game


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("[WindwerkDrive] " + label)


func _touch(finger: int, control: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _steer(value: float) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	var at: Vector2 = game.joystick.get_global_rect().get_center()
	at.x += game.joystick.size.x * .31 * value
	drag.position = at * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(drag)
	Input.flush_buffered_events()


func capture(id: String) -> void:
	if not shots.is_empty():
		RenderingServer.render_loop_enabled = true
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(shots.path_join("windwerk-" + id + ".png")) == OK, id)
		RenderingServer.render_loop_enabled = false


func _run() -> void:
	var requested_size := root.size
	if not shots.is_empty():
		RenderingServer.render_loop_enabled = false
		root.msaa_3d = Viewport.MSAA_DISABLED
	root.get_node("HostBridge")._options["childKey"] = "windwerk_%d" % Time.get_ticks_usec()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	root.size = requested_size
	await process_frame
	game.auto_gas = false
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
		"track": COURSE.ID, "difficulty": "flott"})
	await process_frame
	await process_frame
	check(game.track_id == COURSE.ID and game.TOTAL_LAPS == 2, "two-lap Windwerk race started")
	check(absf(game.track_length - 3000.0) < .2, "calibrated 3000 m")
	check(game.world.has_node("WindwerkKulissen"), "Blender landmark pack mounted")
	check(game.world.position_at(20).y - game.world.position_at(350).y > 25, "opening descent")
	for i in range(1200):
		game._physics_process(STEP)
		if game.racing:
			break
	await process_frame
	_touch(1, game.joystick, true)
	_touch(2, game.gas_button, true)
	check(game.gas_held and game.joystick.touch_id == 1, "accelerator and joystick active")
	var braking := false
	var next_shot := 0
	var marks := [95, 704, 1280, 2190, 2820]
	var farthest_step := 0.0
	var last_at: Vector3 = game.player.position
	for tick in range(26000):
		var s: float = game.previous_road_distance
		var lane := 0.0
		if s > 620 and s < 950:
			lane = -4.3
		if s > 2120 and s < 2440:
			lane = -3.8 if s < 2212 or s > 2317 else 3.8
		var aim: Vector3 = game.world.position_at(s + 11, lane) - game.player.position
		_steer(clampf(-angle_difference(game.player_heading, atan2(-aim.x, -aim.z)) * 2.5, -1, 1))
		var target := 25.0
		if game.distance > 5600 and float(game.opponent_distances.min()) < 6000:
			target = 3.0
		var brake: bool = not game.airborne and game.speed > target + (0.0 if braking else 1.8)
		if brake != braking:
			braking = brake
			_touch(3, game.brake_button, brake)
		game._physics_process(STEP)
		farthest_step = maxf(farthest_step, last_at.distance_to(game.player.position))
		last_at = game.player.position
		if next_shot < marks.size() and game.distance > marks[next_shot]:
			game._update_camera(STEP, false)
			game._update_hud()
			await capture(str(marks[next_shot]))
			next_shot += 1
		if game.finished:
			break
		if tick % 120 == 0:
			await process_frame
	check(game.finished and game.checkpoint_index == 16, "player completed both laps and 16 checkpoints")
	check(float(game.opponent_distances.min()) >= 6000, "five AI completed both laps")
	check(game.reset_count == 0 and farthest_step < 3, "continuous player travel without reset")
	check(game.action_kicker_jumps >= 6 and game.landing_count >= 6, "three landable flights each lap")
	print("[WindwerkDrive] %.2fm per lap; player %.1fm, checkpoints %d; AI %s; jumps %d, landings %d, rescues %d, max step %.2f" % [
		game.track_length, game.distance, game.checkpoint_index, game.opponent_distances, game.action_kicker_jumps, game.landing_count, game.reset_count, farthest_step])
	check(await TEARDOWN.release_scene(self, game, "[WindwerkDrive]"), "scene and playback released")
	print("[WindwerkDrive] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
