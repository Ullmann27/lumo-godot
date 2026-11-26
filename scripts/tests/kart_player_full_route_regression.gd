extends SceneTree
## Two real Sonnenhafen laps from the grid, driven through visible touch controls.
## Only the initial menu selection is assigned. No pose, progress, speed, item,
## flight, loop or countdown state is injected into the running game.
const STEP := 1.0 / 60.0
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RAMP_PLAN = preload("res://scripts/games/kart_rival_ramp_plan.gd")
const LASSO_RULES = preload("res://scripts/games/kart_lasso_rules.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const TRACK_PASS = preload("res://scripts/games/kart_track_pass.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const TAKEOFF_TOLERANCE_M := 1.5
var game
var output := "res://exports/player-full-route"
var recording := false
var braking := false
var failed := false
var events: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var max_step := 0.0
var inverted_frames := 0
var recording_frame := 0
var lasso_hold := 0.0
var longest_lasso_hold := 0.0
var test_child := ""
var protected_lasso: Dictionary = {}
var exposed_lasso: Dictionary = {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--record":
			recording = true
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("_run")


func _touch(index: int, control: Control, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = (
		control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	)
	event.pressed = pressed
	# Apply the real event before the next fixed physics tick; otherwise
	# rendering every 120 ticks coalesces two seconds of steering commands.
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _steer(value: float) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 1
	var point: Vector2 = game.joystick.get_global_rect().get_center()
	point.x += game.joystick.size.x * 0.31 * value
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	# Apply the real event before the next fixed physics tick; otherwise
	# rendering every 120 ticks coalesces two seconds of steering commands.
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _snapshot() -> Dictionary:
	return {
		"seconds": game.elapsed,
		"distance": game.distance,
		"road_distance": game.previous_road_distance,
		"lane": game.lane,
		"speed": game.speed,
		"steering": game.steering,
		"brake": game.control_brake,
		"airborne": game.airborne,
		"loop_active": game.loop_state.active,
		"loops": game.loop_count,
		"jumps": game.action_kicker_jumps,
		"landings": game.landing_count,
		"resets": game.reset_count,
		"precision_results": game.precision_results.duplicate(),
		"checkpoints": game.checkpoint_index,
		"lasso_catches": game.roadside_lasso.catches,
		"lasso_dodges": game.roadside_lasso.dodges,
		"lasso_factor": float(game.player.get_meta("roadside_speed_factor", 1.0)),
		"lasso_clock_seconds": game.roadside_lasso.clock,
	}


func _record_event(kind: String) -> void:
	var entry := _snapshot()
	entry["event"] = kind
	events.append(entry)
	print("[PlayerFullRoute] EVENT ", JSON.stringify(entry))


func _capture(name: String) -> void:
	if not recording:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_jpg(output.path_join(name + ".jpg"), 0.86) == OK)


func _select_lassos() -> bool:
	var loop: Dictionary = game.world.loop_layout
	if loop.is_empty():
		return false
	var loop_exit: float = float(loop.start) + LOOP.advance_of(loop)
	var boosted_speed: float = (
		POWERTRAIN.top_speed(game.kart_factors, POWERTRAIN.race_pace())
		* POWERTRAIN.boost_scale(game.kart_factors)
	)
	var maximum_boost_travel: float = game._boost_for(1.5) * boosted_speed
	for encounter in game.roadside_lasso.layout:
		var after_loop: float = float(encounter.distance) - loop_exit
		if protected_lasso.is_empty() and after_loop >= 0.0 and after_loop < maximum_boost_travel:
			protected_lasso = encounter
		elif exposed_lasso.is_empty() and after_loop > maximum_boost_travel + 30.0:
			exposed_lasso = encounter
	return not protected_lasso.is_empty() and not exposed_lasso.is_empty()


func _crossed(before: float, encounter: Dictionary) -> bool:
	if encounter.is_empty():
		return false
	var line: float = float(encounter.distance)
	return before < line and game.distance >= line


func _drive_controls() -> void:
	var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
	var at: float = float(road.distance)
	var layout: Dictionary = game.world.loop_layout
	var loop_lead: float = float(layout.start) - at
	# Line up before the panorama ramp; its landing leaves little room to move
	# across the road before the optional loop. This changes steering only.
	var target_lane: float = (
		float(layout.lane) if loop_lead >= -36.0 and loop_lead <= 130.0 else 0.0
	)
	# Meet both warned crews on lap one: one with the loop reward still active,
	# the other after it expires. Both are avoided in the centre on lap two.
	if game.distance < game.track_length:
		for encounter in [protected_lasso, exposed_lasso]:
			if encounter.is_empty():
				continue
			var lasso_lead: float = float(encounter.distance) - at
			if lasso_lead > -8.0 and lasso_lead < 100.0:
				target_lane = float(encounter.lateral)
	var target: Vector3 = game.world.position_at(at + 9.0, target_lane)
	var direction: Vector3 = target - game.player.position
	var heading: float = atan2(-direction.x, -direction.z)
	var turn: float = clampf(-angle_difference(game.player_heading, heading) * 2.2, -1.0, 1.0)
	if game.loop_state.active:
		turn = 0.0
	_steer(turn)
	# Drive the actual new road pace. Keep the mandatory gap and optional loop
	# by braking through the real pedal according to the published flight model.
	var target_speed: float = POWERTRAIN.top_speed(game.kart_factors)
	for kicker in game.world.action.get("kickers", []):
		var lead: float = float(kicker.take_off) - at
		var launch_speed: float = RAMP_PLAN.launch_speed(game.world, kicker)
		if launch_speed > 0.0 and lead > 0.0 and lead < 55.0:
			target_speed = launch_speed
	var should_brake: bool = (
		not game.airborne
		and not game.loop_state.active
		and game.speed > target_speed + (0.1 if braking else 0.45)
	)
	if braking != should_brake:
		braking = should_brake
		_touch(3, game.brake_button, braking)


func _run() -> void:
	if recording:
		assert(DisplayServer.get_name() != "headless", "Recording requires the actual renderer")
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(output)
	var host = root.get_node("HostBridge")
	var previous_host_options: Dictionary = host._options.duplicate(true)
	test_child = "kart_full_route_%d" % Time.get_ticks_usec()
	host._options["childKey"] = test_child
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.auto_gas = false
	(
		game
		. _start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": "sonnenhafen",
				"difficulty": "flott",
			}
		)
	)
	await process_frame
	await process_frame
	failed = not _select_lassos()
	var expected_lips: Array[float] = []
	for kicker in game.world.action.kickers:
		expected_lips.append(float(kicker.take_off))
	expected_lips.sort()
	var expected_jumps: int = expected_lips.size() * game.TOTAL_LAPS
	failed = failed or expected_lips.size() != 5
	await _capture("start-grid")
	for frame in range(1200):
		game._physics_process(STEP)
		if game.racing:
			break
	assert(game.racing, "Normal preview and countdown must reach the race")
	await process_frame
	_touch(1, game.joystick, true)
	await process_frame
	_touch(2, game.gas_button, true)
	await process_frame
	print(
		"[PlayerFullRoute] controls ",
		JSON.stringify(
			{
				"gas": game.gas_held,
				"stick": game.joystick.touch_id,
				"gas_rect": str(game.gas_button.get_global_rect()),
				"stick_rect": str(game.joystick.get_global_rect()),
				"visible": game.gas_button.is_visible_in_tree(),
				"enabled": not game.gas_button.disabled,
				"auto_gas": game.auto_gas,
				"root": str(root.size),
				"viewport": str(root.get_visible_rect())
			}
		)
	)
	if not game.gas_held or game.joystick.touch_id != 1:
		quit(1)
		return
	var previous_position: Vector3 = game.player.position
	var previous_airborne: bool = game.airborne
	var previous_loop: bool = game.loop_state.active
	var last_checkpoint: int = game.checkpoint_index
	var checked_lips := 0
	var saw_turbo_protection := false
	var saw_exposed_catch := false
	var saw_turbo_release := false
	for frame in range(30000):
		var before_distance: float = game.distance
		var before_speed: float = game.speed
		var previous_catches: int = game.roadside_lasso.catches
		_drive_controls()
		game._physics_process(STEP)
		var lasso_factor: float = float(game.player.get_meta("roadside_speed_factor", 1.0))
		if _crossed(before_distance, protected_lasso):
			saw_turbo_protection = (
				game.boost_time > 0.0 and game.shield_time <= 0.0
				and is_equal_approx(lasso_factor, 1.0)
				and game.roadside_lasso.catches == previous_catches
				and game.message.text == "Lasso abgewehrt!"
			)
			_record_event("lasso-protected")
		if _crossed(before_distance, exposed_lasso):
			saw_exposed_catch = (
				game.roadside_lasso.catches == previous_catches + 1
				and is_equal_approx(lasso_factor, LASSO_RULES.SPEED_FACTOR)
				and game.speed < before_speed
			)
			_record_event("lasso-caught")
		if lasso_factor < 1.0:
			if not is_equal_approx(lasso_factor, LASSO_RULES.SPEED_FACTOR):
				failed = true
			lasso_hold += STEP
			longest_lasso_hold = maxf(longest_lasso_hold, lasso_hold)
		else:
			if lasso_hold > 0.0 and lasso_hold < LASSO_RULES.HOLD_SECONDS - STEP:
				# The marked outside line can reach a real pad before the hold
				# expires. Early release is valid only when turbo freed the kart.
				saw_turbo_release = (
					game.boost_time > 0.0 and game.shield_time <= 0.0
					and game.message.text == "Lasso abgewehrt!"
				)
				_record_event("lasso-turbo-release")
			lasso_hold = 0.0
		var displacement: float = previous_position.distance_to(game.player.position)
		max_step = maxf(max_step, displacement)
		previous_position = game.player.position
		if game.airborne != previous_airborne:
			if game.airborne:
				var jump_index: int = game.action_kicker_jumps - 1
				if jump_index >= 0 and jump_index < expected_jumps:
					var lap: int = floori(game.distance / game.track_length)
					var expected_lap: int = floori(float(jump_index) / expected_lips.size())
					var lip: float = expected_lips[jump_index % expected_lips.size()]
					if lap == expected_lap and absf(game.previous_road_distance - lip) <= TAKEOFF_TOLERANCE_M:
						checked_lips += 1
			_record_event("takeoff" if game.airborne else "landing")
			previous_airborne = game.airborne
		if game.loop_state.active != previous_loop:
			_record_event("loop-entry" if game.loop_state.active else "loop-exit")
			previous_loop = game.loop_state.active
		if game.loop_state.active and game.player.basis.y.dot(Vector3.UP) < -0.95:
			inverted_frames += 1
		if game.checkpoint_index != last_checkpoint:
			if game.checkpoint_index != last_checkpoint + 1:
				failed = true
			last_checkpoint = game.checkpoint_index
			_record_event("checkpoint")
		if frame % 60 == 0:
			trace.append(_snapshot())
		if frame % 600 == 0:
			print("[PlayerFullRoute] TRACE ", JSON.stringify(_snapshot()))
		if recording and frame % 600 == 0:
			await _capture("route-%05d" % (frame / 600))
		if (
			recording
			and frame % 6 == 0
			and game.previous_road_distance > float(game.world.loop_layout.start) - 12.0
			and game.previous_road_distance < float(game.world.loop_layout.start) + 45.0
			and game.distance < game.track_length
		):
			await _capture("loop-%05d" % recording_frame)
			recording_frame += 1
		if game.reset_count > 0 or displacement > 1.5:
			_record_event("discontinuity-or-rescue")
			failed = true
			break
		if game.finished:
			break
		if frame % 120 == 0:
			await process_frame
	failed = (
		failed
		or not game.finished
		or game.checkpoint_index != 16
		or game.loop_count != 2
		or game.action_kicker_jumps != expected_jumps
		or game.landing_count != expected_jumps
		or checked_lips != expected_jumps
		or int(game.precision_results.get("ziel", 0)) != game.TOTAL_LAPS
		or inverted_frames == 0
		or not saw_turbo_protection
		or not saw_exposed_catch
		or game.roadside_lasso.catches != 1
		or game.roadside_lasso.dodges < 1
		or longest_lasso_hold < 0.25
		or (longest_lasso_hold < LASSO_RULES.HOLD_SECONDS - STEP and not saw_turbo_release)
		or longest_lasso_hold > LASSO_RULES.HOLD_SECONDS + STEP
	)
	# This is the actual touch-driven finish above. No lap, pose, gate or
	# progress injection is used to obtain the new permanent objective.
	var mastery: Dictionary = game.result_payload.get("trackPass", {})
	var achieved := 1
	if int(game.result_payload.get("place", 6)) <= 3:
		achieved = 2
	if int(game.result_payload.get("place", 6)) == 1 and game.reset_count == 0:
		achieved = 3
	var reloaded_pass = TRACK_PASS.new(test_child)
	var other_child = TRACK_PASS.new(test_child + "_other")
	failed = failed or not bool(mastery.get("eligible", false)) or not bool(mastery.get("saved", false))
	failed = failed or reloaded_pass.stage("sonnenhafen", "flott") != achieved
	failed = failed or reloaded_pass.stage("sonnenhafen", "pro") != 0 or other_child.total("flott") != 0
	await _capture("finish" if game.finished else "failed")
	var report := _snapshot()
	(
		report
		. merge(
			{
				"status": "FAIL" if failed else "PASS",
				"max_step_m": max_step,
				"inverted_frames": inverted_frames,
				"longest_lasso_hold_seconds": longest_lasso_hold,
				"planned_takeoff_distances_m": expected_lips,
				"verified_takeoffs": checked_lips,
				"lasso_turbo_protection": saw_turbo_protection,
				"lasso_exposed_catch": saw_exposed_catch,
				"lasso_turbo_release": saw_turbo_release,
				"events": events,
				"trace": trace,
				"input":
				"Real screen touch/drag gas, steering and brake; fixed 60 Hz production physics",
				"fixture_baseline_sha": "c27d621",
				"production_script_sha256":
				FileAccess.get_sha256("res://scripts/games/kart_island.gd"),
				"probe_sha256":
				FileAccess.get_sha256("res://scripts/tests/kart_player_full_route_regression.gd"),
				"display_server": DisplayServer.get_name(),
				"physical_device_performance": "NOT TESTED",
				"position_or_progress_injection": false,
				"track_pass": mastery,
				"track_pass_persistent_stage": reloaded_pass.stage("sonnenhafen", "flott"),
				"track_pass_other_child_total": other_child.total("flott"),
			}
		)
	)
	var final_snapshot := _snapshot()
	game.abandoned = true
	root.world_3d.fallback_environment = null
	var released := await TEARDOWN.release_scene(self, game, "[PlayerFullRoute]")
	game = null
	host._options = previous_host_options
	DirAccess.remove_absolute(TRACK_PASS.path_for(test_child))
	failed = failed or not released
	report.status = "FAIL" if failed else "PASS"
	FileAccess.open(output.path_join("player-route.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "  ")
	)
	print(
		"[PlayerFullRoute] ",
		report.status,
		" ",
		JSON.stringify(final_snapshot),
		" max_step=",
		max_step
	)
	if not released:
		push_error("[PlayerFullRoute] FAIL: scene teardown did not complete")
	quit(1 if failed else 0)
