extends SceneTree


## Physical two-lap race through actual menu/touch input, saved continuation and host ACK.
## Fixed physics steps prove behaviour; desktop software rendering proves no device FPS.
class Host:
	extends Node
	var rewards: Dictionary = {}
	var reward_calls := 0
	var returns: Array[Dictionary] = []
	var return_ack := 0

	# gdlint: disable=function-name
	func reward(value: String) -> int:
		reward_calls += 1
		var payload: Dictionary = JSON.parse_string(value)
		rewards[str(payload.resultId)] = payload
		return 1

	func returnToApp(_destination: String, value: String) -> int:
		returns.append(JSON.parse_string(value))
		return return_ack


const OUTPUT := "res://exports/complete-flow"
const STEP := 1.0 / 60.0
const CHOICE = preload("res://scripts/games/kart_menu_choice.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RAMP_PLAN = preload("res://scripts/games/kart_rival_ramp_plan.gd")
var game
var host: Host
var trace: Array[Dictionary] = []
var expected_id := ""
var flow_checks: Array[Dictionary] = []
var menu_touch_actions: Array[String] = []
var capture := false
var braking := false


func _initialize() -> void:
	capture = DisplayServer.get_name() != "headless"
	if "--capture" in OS.get_cmdline_user_args() and not capture:
		push_error("[KartCompleteFlow] Captures require an actual renderer")
		quit(1)
		return
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await _settle()
	if capture:
		assert(root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png")) == OK)


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	_input_touch(index, at, pressed)
	await process_frame


func _input_touch(index: int, at: Vector2, pressed: bool) -> void:
	var input := InputEventScreenTouch.new()
	input.index = index
	input.position = at * Vector2(root.size) / root.get_visible_rect().size
	input.pressed = pressed
	Input.parse_input_event(input)
	Input.flush_buffered_events()


func _tap(control: Control) -> void:
	assert(is_instance_valid(control), "Expected a live native touch control")
	assert(control.is_visible_in_tree())
	assert(root.get_visible_rect().encloses(control.get_global_rect()))
	var point: Vector2 = control.get_global_rect().get_center()
	await _touch(4, point, true)
	await _touch(4, point, false)
	await _settle()


func _choice(title: String) -> Control:
	for child in game.garage.choices.find_children("*", "Button", true, false):
		if child is CHOICE and child.title == title:
			return child
	assert(false, "Expected visible native selection: " + title)
	return null


func _start_from_native_tabs() -> void:
	# Direct, nonsequential tabs replace the removed five-step NEXT wizard.
	# Only the final START action is allowed to consume and free the menu.
	for selection in [[3, "Sonnenhafen"], [4, "Abenteuer"], [0, "Einzelrennen"]]:
		var index: int = int(selection[0])
		var title: String = str(selection[1])
		menu_touch_actions.append("tab:" + str(index))
		await _tap(game.garage.step_buttons[index])
		assert(game.menu_active and game.garage.step == index, "Native tab switches without starting")
		menu_touch_actions.append("choice:" + title)
		await _tap(_choice(title))
	assert(game.garage.setup.mode == "race" and game.garage.setup.track == "sonnenhafen")
	assert(game.garage.setup.difficulty == "flott", "Actual tempo card selects doubled race pace")
	menu_touch_actions.append("START")
	await _tap(game.garage.next_button)


func _button(text: String) -> Button:
	for child in game.modal_column.get_children():
		if child is Button and child.text == text:
			return child
	assert(false, "Expected actual modal action: " + text)
	return null


func _steer(value: float) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 1
	var point: Vector2 = game.joystick.get_global_rect().get_center()
	point.x += game.joystick.size.x * 0.31 * value
	event.position = point * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drive_controls() -> void:
	var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
	var at: float = float(road.distance)
	var layout: Dictionary = game.world.loop_layout
	var loop_lead: float = float(layout.start) - at
	var target_lane: float = float(layout.lane) if loop_lead >= -36.0 and loop_lead <= 130.0 else 0.0
	var target: Vector3 = game.world.position_at(at + 9.0, target_lane)
	var direction: Vector3 = target - game.player.position
	var heading: float = atan2(-direction.x, -direction.z)
	var turn: float = clampf(-angle_difference(game.player_heading, heading) * 2.2, -1.0, 1.0)
	_steer(0.0 if game.loop_state.active else turn)
	# Same published ramp approach as the full-route probe, using only the
	# actual brake pedal. No velocity, pose or progress is assigned in the race.
	var target_speed: float = POWERTRAIN.top_speed(game.kart_factors)
	for kicker in game.world.action.get("kickers", []):
		var lead: float = float(kicker.take_off) - at
		var launch_speed: float = RAMP_PLAN.launch_speed(game.world, kicker)
		if launch_speed > 0.0 and lead > 0.0 and lead < 55.0:
			target_speed = launch_speed
	var should_brake: bool = (
		not game.airborne and not game.loop_state.active
		and game.speed > target_speed + (0.1 if braking else 0.45)
	)
	if braking != should_brake:
		braking = should_brake
		_input_touch(3, game.brake_button.get_global_rect().get_center(), braking)


func _release_controls() -> void:
	for index in [3, 2, 1]:
		await _touch(index, Vector2(420, 250), false)
	braking = false


func _hold_controls() -> void:
	# This fixture steps physics manually. Let the next normal step publish
	# resumed action availability before issuing fresh touches.
	game._physics_process(STEP)
	await _settle()
	braking = false
	await _touch(1, game.joystick.get_global_rect().get_center(), true)
	await _touch(2, game.gas_button.get_global_rect().get_center(), true)
	assert(
		game.gas_held and game.joystick.touch_id == 1, "Resumed pedals/stick accept fresh fingers"
	)


func _fresh():
	var instance = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(instance)
	instance.set_physics_process(false)
	await _settle()
	return instance


func _drop() -> void:
	game.abandoned = true
	game.queue_free()
	await _settle()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	DirAccess.remove_absolute("user://lumo_host_pending_rewards.cfg")
	var bridge = root.get_node("HostBridge")
	host = Host.new()
	root.add_child(host)
	bridge._host = host
	bridge._options = {"sessionId": "complete-touch-race", "soundEnabled": false}
	game = await _fresh()
	assert(game.menu_active)
	await _start_from_native_tabs()
	assert(not game.menu_active and game.mode == "race" and game.track_id == "sonnenhafen")
	assert(game.difficulty == "flott")
	expected_id = game.result_id
	game.auto_gas = false
	game._update_hud()
	await _capture("01-start-grid")
	# Run the real preview and countdown. No distance/checkpoint/finish state is assigned.
	for frame in range(1000):
		game._physics_process(STEP)
		if game.racing:
			break
	assert(game.racing)
	await _hold_controls()
	var resumed := false
	var lap2_resumed := false
	var lap2_before: Dictionary = {}
	var lap2_restored: Dictionary = {}
	var frames := 0
	var last_gate := 0
	# Preserve a bounded complete two-lap run, including both saved reopens.
	while not game.finished and frames < 30000:
		_drive_controls()
		game._physics_process(STEP)
		frames += 1
		if game.checkpoint_index != last_gate:
			assert(game.checkpoint_index == last_gate + 1, "Ordered gates cannot be skipped")
			last_gate = game.checkpoint_index
			trace.append({"gate": last_gate, "seconds": game.elapsed, "distance": game.distance})
			print("[KartCompleteFlowGate] ", JSON.stringify(trace[-1]))
		if last_gate >= 4 and not resumed:
			await _release_controls()
			await _tap(game.top_pause_button)
			assert(game.paused and not game.gas_held and game.steering == 0.0)
			await _capture("02-paused-mid-race")
			var progress: float = game.distance
			game._return_to_app("games")
			assert(host.returns[-1].status == "paused" and FileAccess.file_exists(game.SESSION))
			bridge._return_pending = false
			await _drop()
			game = await _fresh()
			assert(game.saved_session_available)
			await _tap(game.garage.find_child("ResumeRace", true, false))
			# ConfigFile serializes float values as text. On reload the last bit of
			# the numeric distance may differ (~1.1e-13 m measured), without any
			# actual loss of checkpoint, identity, paused state or position.
			# Use the same strict 1e-9 m ABSOLUTE tolerance as the separately
			# passing kart_race_continuity_regression.gd. Never alter game physics.
			assert(
				game.paused
				and game.result_id == expected_id
				and is_finite(game.distance)
				and absf(game.distance - progress) <= 0.000000001,
				"Paused resume must preserve distance within a nanometer, result ID and pause"
			)
			game.auto_gas = false
			game._update_hud()
			await _tap(_button("Weiterfahren"))
			await _hold_controls()
			resumed = true
			await _capture("03-restored-race")
		if last_gate >= 12 and not lap2_resumed:
			await _release_controls()
			await _tap(game.top_pause_button)
			lap2_before = _flow_lap_state().duplicate(true)
			game._return_to_app("games")
			_flow_check(
				game.paused and host.returns[-1].status == "paused",
				"gate-twelve touch pause saves a paused race",
				true,
				host.returns[-1]
			)
			bridge._return_pending = false
			await _drop()
			game = await _fresh()
			await _tap(game.garage.find_child("ResumeRace", true, false))
			lap2_restored = _flow_lap_state().duplicate(true)
			_flow_check(
				_flow_lap_pair_equal(lap2_before, lap2_restored),
				"second-lap touch reopen retains completed lap timing",
				lap2_before,
				lap2_restored
			)
			_flow_check(
				(
					game.paused
					and game.result_id == expected_id
					and game.checkpoint_index == 12
					and absf(game.elapsed - float(lap2_before.elapsed)) <= 0.000000001
					and absf(game.distance - float(lap2_before.distance)) <= 0.000000001
				),
				"second-lap touch reopen keeps paused progress and identity",
				lap2_before,
				lap2_restored
			)
			game.auto_gas = false
			game._update_hud()
			await _tap(_button("Weiterfahren"))
			await _hold_controls()
			lap2_resumed = true
		if frames % 120 == 0:
			await process_frame
	if not game.finished:
		# Diagnostic evidence only; never inject distance, checkpoints or results.
		var position_on_road: Dictionary = game.world.sample_road(
			game.player.position, game.previous_road_distance
		)
		print("[KartCompleteFlowDiagnostic] ", JSON.stringify({
			"frames": frames,
			"checkpoint_index": game.checkpoint_index,
			"last_gate": last_gate,
			"resumed": resumed,
			"lap2_resumed": lap2_resumed,
			"race_distance": game.distance,
			"track_length": game.track_length,
			"speed": game.speed,
			"gas_held": game.gas_held,
			"auto_gas": game.auto_gas,
			"steering": game.steering,
			"paused": game.paused,
			"racing": game.racing,
			"road_distance": position_on_road.get("distance", -1),
			"lateral": position_on_road.get("lateral", -1),
			"reset_count": game.reset_count
		}))
	assert(game.finished and resumed, "Real driving must finish after a saved continuation")
	await _release_controls()
	assert(game.checkpoint_index == 16 and game.reset_count == 0)
	assert(game.result_payload.resultId == expected_id and game.result_payload.stars == 3)
	assert(game.result_payload.solved is int and game.result_payload.solved == 0)
	assert(host.reward_calls == 1 and host.rewards.size() == 1 and host.rewards.has(expected_id))
	for frame in range(250):
		game._physics_process(STEP)
		if game.finish_cine_left <= 0:
			break
	assert(game.modal.visible)
	var actual_stats_label: Label = game.modal_column.get_node("ResultStats")
	assert(actual_stats_label.is_visible_in_tree())
	var actual_stats: String = actual_stats_label.text
	assert(
		actual_stats.contains(
			"Beste Runde   " + game._format_time(float(game.result_payload.bestLapSeconds))
		),
		"Actual displayed best lap agrees with the rounded result payload"
	)
	await _capture("04-result")
	var report := {
		"result": game.result_payload.duplicate(true),
		"actual_result_stats_text": actual_stats,
		"result_stats_visible": actual_stats_label.is_visible_in_tree(),
		"best_lap_seconds_unrounded": game._best_lap(),
		"ordered_gates": trace,
		"actual_menu_touch_steps": menu_touch_actions.size(),
		"actual_menu_touch_actions": menu_touch_actions.duplicate(),
		"save_reopen_resume": resumed,
		"input": "screen touch/drag; physics stepped at 1/60; no teleport or forced finish",
		"physical_device_performance": "NOT EXECUTED"
	}
	var expected_laps: Array[float] = [
		float(trace[7].seconds), float(trace[15].seconds) - float(trace[7].seconds)
	]
	var completed_laps_match: bool = game.lap_times.size() == 2
	if completed_laps_match:
		for i in range(2):
			completed_laps_match = (
				completed_laps_match and absf(game.lap_times[i] - expected_laps[i]) <= 0.000000001
			)
	_flow_check(
		lap2_resumed and completed_laps_match,
		"full touch race retains two independently measured lap intervals",
		expected_laps,
		game.lap_times
	)
	var expected_best: float = snappedf(minf(expected_laps[0], expected_laps[1]), 0.001)
	var expected_total: float = snappedf(float(trace[15].seconds), 0.001)
	_flow_check(
		(
			float(game.result_payload.bestLapSeconds) == expected_best
			and float(game.result_payload.elapsedSeconds) == expected_total
		),
		"public best and total equal measured gate milliseconds",
		{"bestLapSeconds": expected_best, "elapsedSeconds": expected_total},
		game.result_payload
	)
	var finished_payload: Dictionary = game.result_payload.duplicate(true)
	var finished_elapsed: float = game.elapsed
	var stars_before: int = root.get_node("ProgressStore").total_stars()
	game._save_session()
	await _drop()
	game = await _fresh()
	await _tap(game.garage.find_child("ResumeRace", true, false))
	var reopened_payload: Dictionary = game.result_payload.duplicate(true)
	var reopened_stats_label: Label = game.modal_column.get_node("ResultStats")
	var reopened_stats: String = reopened_stats_label.text
	var reopened_ui: Dictionary = _flow_result_ui()
	game._physics_process(STEP)
	var after_tick: Dictionary = _flow_result_ui()
	_flow_check(
		JSON.stringify(reopened_payload) == JSON.stringify(finished_payload),
		"finished touch reopen keeps the original public payload",
		finished_payload,
		reopened_payload
	)
	_flow_check(
		reopened_stats_label.is_visible_in_tree() and reopened_stats == actual_stats,
		"finished touch reopen visibly retains original result lines",
		{"text": actual_stats, "visible": true},
		{"text": reopened_stats, "visible": reopened_stats_label.is_visible_in_tree()}
	)
	_flow_check(
		_flow_ui_finished(reopened_ui) and _flow_ui_finished(after_tick),
		"finished touch reopen hides controls and immediately displays stopped HUD",
		{"controls_visible": false, "displayed_speed_kmh": 0, "all_actions_disabled": true},
		{"immediate": reopened_ui, "after_tick": after_tick}
	)
	_flow_check(
		host.reward_calls == 1 and root.get_node("ProgressStore").total_stars() == stars_before,
		"finished touch reopen cannot award twice",
		{"host_rewards": 1, "local_stars": stars_before},
		{
			"host_rewards": host.reward_calls,
			"local_stars": root.get_node("ProgressStore").total_stars()
		}
	)
	await _capture("06-reopened-result")
	reopened_ui["after_tick"] = after_tick.duplicate(true)
	(
		report
		. merge(
			{
				"lap2_save_reopen_resume": lap2_resumed,
				"lap2_before": lap2_before.duplicate(true),
				"lap2_restored": lap2_restored.duplicate(true),
				"lap_times": game.lap_times.duplicate(),
				"expected_laps": expected_laps.duplicate(),
				"finished_elapsed_seconds": finished_elapsed,
				"reopened_result_elapsed_seconds": game.elapsed,
				"reopened_result_payload": reopened_payload.duplicate(true),
				"reopened_result_stats_text": reopened_stats,
				"reopened_result_stats_visible": reopened_stats_label.is_visible_in_tree(),
				"reopened_result_ui": reopened_ui.duplicate(true),
				"reward_calls": host.reward_calls,
			},
			true
		)
	)
	host.return_ack = 1
	await _tap(_button("Zur Spieleauswahl"))
	assert(host.returns[-1].status == "completed" and host.returns[-1].resultId == expected_id)
	assert(not FileAccess.file_exists(game.SESSION), "Durable ACK removes completed save")
	bridge._return_pending = false
	await _drop()
	game = await _fresh()
	assert(not game.saved_session_available and host.reward_calls == 1 and host.rewards.size() == 1)
	await _capture("05-reopened-garage")
	var screenshot_sha256: Dictionary = {}
	var screenshot_names: Array[String] = [
		"01-start-grid.png",
		"02-paused-mid-race.png",
		"03-restored-race.png",
		"04-result.png",
		"05-reopened-garage.png",
		"06-reopened-result.png"
	]
	if capture:
		for name in screenshot_names:
			screenshot_sha256[name] = FileAccess.get_sha256(OUTPUT.path_join(name))
	var failures := 0
	for check in flow_checks:
		if not check.passed:
			failures += 1
	(
		report
		. merge(
			{
				"status": "PASS" if failures == 0 else "FAIL",
				"check_count": flow_checks.size(),
				"failed_checks": failures,
				"checks": flow_checks.duplicate(true),
				"provenance": "NATIVE_TABS_DIRECT_START_PHYSICAL_RACE",
				"historical_unrecovered_probe_sha256":
				"a260568656f2c4b5d6501b71e511cdfde3fb2d03e1f9f14c6dabc1e5dbbfd917",
				"engine": Engine.get_version_info().string,
				"display_server": DisplayServer.get_name(),
				"rendering_method": RenderingServer.get_current_rendering_method(),
				"renderer_setting":
				ProjectSettings.get_setting("rendering/renderer/rendering_method"),
				"source_sha256": FileAccess.get_sha256("res://scripts/games/kart_island.gd"),
				"probe_sha256":
				FileAccess.get_sha256("res://scripts/tests/kart_complete_flow_regression.gd"),
				"screenshot_sha256": screenshot_sha256,
				"visual_capture_status": "RENDERED" if capture else "NOT_EXECUTED_HEADLESS",
				"reopened_result_screenshot": "06-reopened-result.png" if capture else "",
				"reopened_result_screenshot_sha256": screenshot_sha256.get("06-reopened-result.png", ""),
			},
			true
		)
	)
	FileAccess.open(OUTPUT.path_join("evidence.json"), FileAccess.WRITE).store_string(
		JSON.stringify(report, "  ")
	)
	await _drop()
	bridge._host = null
	bridge._options = {}
	host.queue_free()
	root.world_3d.fallback_environment = null
	await create_timer(0.6).timeout
	if failures > 0:
		print("[KartCompleteFlow] FAIL: %d new checks failed" % failures)
		quit(1)
		return
	print(
		"[KartCompleteFlow] PASS: actual menu/touch, 16 gates, saved resume, result, ACK, one reward"
	)
	quit(0)


func _flow_lap_state() -> Dictionary:
	return {
		"lap_times": game.lap_times.duplicate(),
		"lap_started_at": game.lap_started_at,
		"elapsed": game.elapsed,
		"checkpoint_index": game.checkpoint_index,
		"distance": game.distance,
		"result_id": game.result_id,
	}


func _flow_snapshot(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


func _flow_check(condition: bool, name: String, expected: Variant, actual: Variant) -> void:
	(
		flow_checks
		. append(
			{
				"name": name,
				"passed": condition,
				"expected": _flow_snapshot(expected),
				"actual": _flow_snapshot(actual),
			}
		)
	)
	if not condition:
		print("[KartCompleteFlowCheck] FAIL: " + name)


func _flow_lap_pair_equal(before: Dictionary, after: Dictionary) -> bool:
	if before.lap_times.size() != after.lap_times.size():
		return false
	for i in range(before.lap_times.size()):
		if absf(float(before.lap_times[i]) - float(after.lap_times[i])) > 0.000000001:
			return false
	return absf(float(before.lap_started_at) - float(after.lap_started_at)) <= 0.000000001


func _flow_result_ui() -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile("(\\d+) km/h")
	var speed_match: RegExMatch = pattern.search(game.hud.text)
	return {
		"controls_visible": game.controls_row.is_visible_in_tree(),
		"message_text": game.message.text,
		"expected_message_text": game._place_title(int(game.result_payload.get("place", 1))),
		"hud_text": game.hud.text,
		"displayed_speed_kmh": int(speed_match.get_string(1)) if speed_match else -1,
		"raw_speed": game.speed,
		"action_disabled":
		{
			"gas": game.gas_button.disabled,
			"brake": game.brake_button.disabled,
			"drift": game.drift_button.disabled,
			"boost": game.boost_button.disabled,
			"item": game.item_button.disabled,
		},
	}


func _flow_ui_finished(state: Dictionary) -> bool:
	return (
		not state.controls_visible
		and state.displayed_speed_kmh == 0
		and state.message_text == state.expected_message_text
		and (
			state.action_disabled
			== {"gas": true, "brake": true, "drift": true, "boost": true, "item": true}
		)
	)
