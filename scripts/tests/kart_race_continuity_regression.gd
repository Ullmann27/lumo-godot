extends SceneTree
## Consumed pickups, bounded rival states and an airborne reset survive real race transitions.


class LapHost:
	extends Node
	var reward_calls := 0
	var rewards: Dictionary = {}
	var returns: Array[Dictionary] = []
	var return_ack := 0

	# gdlint: disable=function-name
	func reward(value: String) -> int:
		reward_calls += 1
		var payload: Dictionary = JSON.parse_string(value)
		rewards[str(payload.resultId)] = payload.duplicate(true)
		return 1

	func returnToApp(_destination: String, value: String) -> int:
		returns.append(JSON.parse_string(value))
		return return_ack


const HANDOFF_FIXTURES = preload("res://scripts/tests/kart_handoff_lifecycle_fixtures.gd")
const LAP_FIXTURES = preload("res://scripts/tests/kart_lap_session_fixtures.gd")
const STEP: float = 1.0 / 60.0
var game
var scene: PackedScene
var lap_checks: Array[Dictionary] = []
var lap_evidence: Dictionary = {}
var lap_host: LapHost
var lap_output := "res://exports/race-continuity"
# Hold the actual startup resource until all draws and natural fixture frees finish.
var startup_environment: Environment = null


func _initialize() -> void:
	startup_environment = root.world_3d.fallback_environment
	call_deferred("_run")


func _drop_game() -> void:
	# Finish pending render uploads before releasing the scene, then drain the
	# deferred frees before a new instance claims its viewports and textures.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	game = null
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _fresh(mode: String = "race", track: String = "sonnenhafen") -> void:
	if is_instance_valid(game):
		await _drop_game()
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await process_frame
	game._start_selected_race(
		{"mode": mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game._update_hud()
	await process_frame


func _collect_first_box() -> void:
	game.distance = game.item_box_distances[0]
	game.previous_road_distance = game.distance
	game.checkpoint_index = int(game.distance / (game.track_length / 8.0))
	game.player.position = game.item_boxes[0].position
	game._track_events()
	game._physics_process(0.0)
	assert(game.item_box_collected.has(0), "The actual pickup is consumed in lap one")
	assert(not game.item_boxes[0].visible, "Consumed pickup is hidden by the race runtime")
	assert(not game.item.is_empty(), "The pickup actually awarded an item")
	game._use_item()
	assert(game.item.is_empty(), "The granted item was used before attempting recollection")


func _cannot_recollect() -> void:
	assert(game.item_box_collected.has(0), "Consumed pickup identity must survive the transition")
	assert(not game.item_boxes[0].visible, "A consumed prism must stay invisible immediately")
	game.player.position = game.item_boxes[0].position
	game._track_events()
	assert(game.item.is_empty(), "The same lap cannot award the same prism again")


func _quality_change() -> void:
	game._pause()
	# A real menu tap follows a rendered frame. Let a freshly restored world
	# finish its texture uploads before the callback rebuilds that world.
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var found: bool = false
	for control in game.modal_column.get_children():
		if control is Button and control.text.begins_with("Grafik:"):
			control.pressed.emit()
			found = true
			break
	assert(found, "The real pause menu exposes the quality setting")
	assert(game.paused, "The quality change leaves the race paused")
	await process_frame


func _test_rebuild() -> void:
	await _fresh()
	_collect_first_box()
	var position_before: Vector3 = game.player.position
	var distance_before: float = game.distance
	var result_before: String = game.result_id
	await _quality_change()
	assert(game.player.position == position_before and game.distance == distance_before)
	assert(game.result_id == result_before, "Quality change keeps the result identity")
	_cannot_recollect()
	game._resume()
	game._physics_process(0.0)
	_cannot_recollect()
	# The per-lap key permits the next legitimate lap to use this pickup again.
	game.player.position = game.world.position_at(game.item_box_distances[0] + 20.0)
	game.distance += game.track_length
	game._physics_process(0.0)
	assert(game.item_boxes[0].visible, "A new lap releases the pickup normally")
	game.player.position = game.item_boxes[0].position
	game._track_events()
	assert(not game.item.is_empty() and game.item_box_collected.has(game.item_boxes.size()))
	print("[KartContinuity] rebuild: consumed prism stays hidden; next lap releases it")


func _test_reopen() -> void:
	await _fresh()
	_collect_first_box()
	var result_before: String = game.result_id
	game._pause()
	game._save_session()
	var saved := ConfigFile.new()
	assert(saved.load(game.SESSION) == OK, "The actual atomic ConfigFile save exists")
	assert(
		saved.get_value("race", "item_box_collected", {}).has(0), "Save contains the consumed key"
	)
	await _drop_game()
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	assert(game.saved_session_available, "The garage offers the saved race")
	game._resume_saved_race()
	assert(game.paused and game.result_id == result_before)
	_cannot_recollect()
	game._resume()
	game._physics_process(0.0)
	_cannot_recollect()
	print("[KartContinuity] reopen: ConfigFile round-trip preserves prism and result ID")


func _rival_states() -> Dictionary:
	var state: Dictionary = {}
	for key in [
		"opponent_items",
		"opponent_stuns",
		"opponent_item_cooldowns",
		"opponent_boost_times",
		"opponent_shield_times",
		"opponent_pulse_warning_times"
	]:
		state[key] = game.get(key).duplicate()
	return state


func _test_rival_reopen() -> void:
	await _fresh()
	game.opponent_items[0] = "pulse"
	game._update_rival_item_tactics(0, Vector3.RIGHT * 4.0, STEP)
	game.opponent_items[1] = "shield"
	game._update_rival_item_tactics(1, Vector3.RIGHT * 3.0, STEP)
	game.distance = 12.0
	game.opponent_distances[2] = 0.0
	game.opponent_items[2] = "boost"
	game._update_rival_item_tactics(2, Vector3.RIGHT * 15.0, STEP)
	game.opponent_items[3] = "shield"
	game.opponent_stuns[4] = 2.3
	game.opponent_item_cooldowns[4] = 1.8
	game._pause()
	var expected: Dictionary = _rival_states()
	game._save_session()
	await _drop_game()
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._resume_saved_race()
	assert(
		_rival_states() == expected,
		"Rival warning, shield, boost, stun and item timers survive reopen"
	)
	assert(
		game.opponent_item_fx[0].visual_state().warning_visible,
		"Restored pulse is still telegraphed"
	)
	assert(
		game.opponent_item_fx[1].visual_state().shield_visible,
		"Restored rival shield stays visible"
	)
	assert(game.opponent_item_fx[3].visual_state().item_visible, "Restored held item stays visible")
	assert(game.opponent_item_fx[4].visual_state().stun_visible, "Restored stun stays visible")
	game._physics_process(0.5)
	assert(_rival_states() == expected, "Paused race cannot advance restored rival durations")
	await _quality_change()
	assert(_rival_states() == expected, "Quality rebuild preserves restored rival durations")
	print(
		"[KartContinuity] rivals: real item effects remain bounded, visible and paused after reopen"
	)


func _test_save_compatibility() -> void:
	for version in [1, 2, 3, 4]:
		await _fresh()
		game._pause()
		game._save_session()
		var legacy := ConfigFile.new()
		assert(legacy.load(game.SESSION) == OK)
		legacy.set_value("race", "version", version)
		for key in _rival_states():
			legacy.erase_section_key("race", key)
		legacy.erase_section_key("race", "item_box_collected")
		assert(legacy.save(game.SESSION) == OK)
		assert(
			game._restore_session(), "Existing ConfigFile session version %d still loads" % version
		)
		assert(game.item_box_collected.is_empty())
		for held_item in game.opponent_items:
			assert(held_item.is_empty(), "Missing legacy rival items default to neutral")
		for key in game.RIVAL_SESSION_TIMERS:
			for seconds in game.get(key):
				assert(seconds == 0.0, "Missing legacy timers default to neutral")
	# Only the newly introduced fields are normalized here; unrelated old session fields are unchanged.
	var malformed := ConfigFile.new()
	assert(malformed.load(game.SESSION) == OK)
	malformed.set_value("race", "item_box_collected", {0: true, -1: true, "0": true, 1: false})
	malformed.set_value("race", "opponent_items", ["pulse", "unknown", 42])
	for key in game.RIVAL_SESSION_TIMERS:
		malformed.set_value("race", key, [INF, -1.0, 999.0, "bad"])
	assert(malformed.save(game.SESSION) == OK)
	assert(game._restore_session(), "Malformed optional item fields cannot break valid race state")
	assert(
		game.item_box_collected == {0: true}, "Only consumed nonnegative integer keys are accepted"
	)
	assert(
		game.opponent_items == ["pulse", "", "", "", ""], "Only known rival item IDs are accepted"
	)
	for key in game.RIVAL_SESSION_TIMERS:
		var timers: Array = game.get(key)
		assert(timers == [0.0, 0.0, float(game.RIVAL_SESSION_TIMERS[key]), 0.0, 0.0])
	malformed.set_value("race", "item_box_collected", "wrong type")
	malformed.set_value("race", "opponent_items", "wrong type")
	for key in game.RIVAL_SESSION_TIMERS:
		malformed.set_value("race", key, "wrong type")
	assert(malformed.save(game.SESSION) == OK)
	assert(game._restore_session())
	assert(game.item_box_collected.is_empty())
	for key in game.RIVAL_SESSION_TIMERS:
		assert(game.get(key) == [0.0, 0.0, 0.0, 0.0, 0.0])
	print(
		"[KartContinuity] compatibility: v1–v4 missing fields and malformed optional values load safely"
	)


func _test_flight_reset() -> void:
	await _fresh("training", "bergwelt")
	var jump: Dictionary = game.world.jump
	var at: float = float(jump.ramp_start) - 25.0
	game.player.transform = game.world.reset_transform(at)
	game.distance = at
	game.previous_road_distance = at
	game.player_heading = game._heading(at)
	game.checkpoint_index = 3
	game.speed = 17.0
	game.auto_gas = true
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
	)
	for frame in range(240):
		var direction: Vector3 = (
			game.world.position_at(game.previous_road_distance + 10.0) - game.player.position
		)
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
		game._physics_process(STEP)
		if game.airborne and game.air_time > 0.36:
			break
	assert(game.airborne and game.air_time > 0.36, "The fixture reaches a real ramp flight")
	var landings_before: int = game.landing_count
	var resets_before: int = game.reset_count
	game.boost_time = 0.0
	game._reset_kart()
	assert(not game.airborne, "Manual reset ends the interrupted flight")
	assert(
		game.vertical_speed == 0.0 and game.air_time == 0.0, "Reset clears vertical flight state"
	)
	assert(game.physical_velocity == Vector3.ZERO and game.speed == 0.0)
	assert(game.reset_count == resets_before + 1)
	game.auto_gas = false
	game._physics_process(STEP)
	assert(game.landing_count == landings_before, "Reset is not a successful landing")
	assert(game.boost_time == 0.0, "An interrupted flight cannot award a landing turbo")
	assert(not game.world.in_gap(game.previous_road_distance), "Reset chooses actual safe road")
	print("[KartContinuity] reset: genuine ramp flight ends safely without landing turbo")


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/games/kart_island.tscn")
	var lap_ok := true
	var probe: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--red-probe="):
			probe = arg.trim_prefix("--red-probe=")
	if probe == "laps":
		lap_ok = await _lap_suite()
	elif probe == "rebuild":
		await _test_rebuild()
	elif probe == "reopen":
		await _test_reopen()
	elif probe == "reset":
		await _test_flight_reset()
	elif probe == "rivals":
		await _test_rival_reopen()
	else:
		await _test_rebuild()
		await _test_reopen()
		await _test_rival_reopen()
		await _test_save_compatibility()
		await _test_flight_reset()
		lap_ok = await _lap_suite()
	await _drop_game()
	scene = null
	if probe in ["", "laps"]:
		var handoff_report: Dictionary = await HANDOFF_FIXTURES.new().run(self)
		lap_ok = lap_ok and handoff_report.status == "PASS"
	for frame in range(8):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	# Only tear down the original unused fallback after all captures and fixtures.
	# Reloading this path would allocate a different resource, not release this one.
	root.world_3d.environment = null
	root.world_3d.fallback_environment = null
	if startup_environment != null:
		startup_environment.sky = null
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	startup_environment = null
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	await create_timer(0.5).timeout
	if not lap_ok:
		quit(1)
		return
	print(
		(
			"[KartContinuity] PASS: quality change, save/reopen, next lap, "
			+ "rival states, legacy saves and flight reset"
		)
	)
	quit(0)


func _lap_snapshot(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


func _lap_check(condition: bool, name: String, expected: Variant, actual: Variant) -> void:
	(
		lap_checks
		. append(
			{
				"name": name,
				"passed": condition,
				"expected": _lap_snapshot(expected),
				"actual": _lap_snapshot(actual),
			}
		)
	)
	if not condition:
		print("[KartLapContinuity] FAIL: " + name)


func _lap_state() -> Dictionary:
	return {
		"lap_times": game.lap_times.duplicate(),
		"lap_started_at": game.lap_started_at,
		"elapsed": game.elapsed,
		"checkpoint_index": game.checkpoint_index,
		"distance": game.distance,
		"result_id": game.result_id,
	}


func _lap_pair_close(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.lap_times.size() != expected.lap_times.size():
		return false
	for i in range(actual.lap_times.size()):
		if absf(float(actual.lap_times[i]) - float(expected.lap_times[i])) > 0.000000001:
			return false
	return absf(float(actual.lap_started_at) - float(expected.lap_started_at)) <= 0.000000001


func _lap_reopen() -> void:
	await _drop_game()
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await process_frame


func _lap_drive_step() -> void:
	var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
	var heading: float = game._heading(float(road.distance) + 7.0)
	game.steering = clampf(
		-angle_difference(game.player_heading, heading) * 1.8 - float(road.lateral) * 0.12,
		-1.0,
		1.0
	)
	game._physics_process(STEP)


func _lap_ui_state() -> Dictionary:
	var speed_pattern := RegEx.new()
	speed_pattern.compile("(\\d+) km/h")
	var speed_match: RegExMatch = speed_pattern.search(game.hud.text)
	return {
		"controls_visible": game.controls_row.is_visible_in_tree(),
		"message_text": game.message.text,
		"expected_message_text":
		game._place_title(int(game.result_payload.get("place", 1))) if game._ranked() else "Ziel!",
		"action_disabled":
		{
			"gas": game.gas_button.disabled,
			"brake": game.brake_button.disabled,
			"drift": game.drift_button.disabled,
			"boost": game.boost_button.disabled,
			"item": game.item_button.disabled,
		},
		"hud_text": game.hud.text,
		"displayed_speed_kmh": int(speed_match.get_string(1)) if speed_match else -1,
		"raw_speed": game.speed,
	}


func _lap_check_result_ui(prefix: String) -> Dictionary:
	var before: Dictionary = _lap_ui_state()
	game._physics_process(STEP)
	var after: Dictionary = _lap_ui_state()
	var expected_disabled := {
		"gas": true, "brake": true, "drift": true, "boost": true, "item": true
	}
	_lap_check(
		not before.controls_visible and not after.controls_visible,
		prefix + " hides driving controls immediately and after tick",
		[false, false],
		[before.controls_visible, after.controls_visible]
	)
	_lap_check(
		(
			before.message_text == before.expected_message_text
			and after.message_text == after.expected_message_text
		),
		prefix + " shows the result heading immediately and after tick",
		[before.expected_message_text, after.expected_message_text],
		[before.message_text, after.message_text]
	)
	_lap_check(
		(
			before.action_disabled == expected_disabled
			and after.action_disabled == expected_disabled
			and before.displayed_speed_kmh == 0
			and after.displayed_speed_kmh == 0
		),
		prefix + " disables every driving action and displays stopped speed immediately",
		{"action_disabled": expected_disabled, "displayed_speed_kmh": 0},
		{"immediate": before, "after_tick": after}
	)
	before["after_tick"] = after.duplicate(true)
	return before


func _test_lap_driven_reopen() -> void:
	var bridge = root.get_node("HostBridge")
	lap_host = LapHost.new()
	root.add_child(lap_host)
	bridge._host = lap_host
	bridge._options = {"sessionId": "recovered-lap-continuity", "soundEnabled": false}
	await _fresh()
	var expected_id: String = game.result_id
	_lap_check(
		game.lap_times.is_empty() and game.lap_started_at == 0.0,
		"new race starts with empty known lap timing",
		{"lap_times": [], "lap_started_at": 0.0},
		_lap_state()
	)
	game.auto_gas = true
	var gates: Array[Dictionary] = []
	var last_gate := 0
	var frames := 0
	while game.checkpoint_index < 10 and not game.finished and frames < 6000:
		_lap_drive_step()
		frames += 1
		if game.checkpoint_index != last_gate:
			last_gate = game.checkpoint_index
			gates.append({"gate": last_gate, "seconds": game.elapsed, "distance": game.distance})
		if frames % 120 == 0:
			await process_frame
	_lap_check(gates.size() >= 8, "physical driving reaches the first lap boundary", true, gates)
	_lap_check(
		game.checkpoint_index == 10 and not game.finished,
		"physical driving reaches lap two before saving",
		{"checkpoint_index": 10, "finished": false},
		{"checkpoint_index": game.checkpoint_index, "finished": game.finished}
	)
	var first_lap: float = float(gates[7].seconds) if gates.size() >= 8 else -1.0
	_lap_check(
		game.lap_times == [first_lap],
		"the first completed lap is measured from gate eight",
		[first_lap],
		game.lap_times
	)
	_lap_check(
		game.lap_started_at == first_lap,
		"the current lap starts exactly at gate eight",
		first_lap,
		game.lap_started_at
	)
	game._pause()
	var before: Dictionary = _lap_state()
	game._physics_process(0.5)
	_lap_check(
		_lap_state() == before, "pause freezes both lap timing and race state", before, _lap_state()
	)
	await _quality_change()
	_lap_check(
		_lap_pair_close(_lap_state(), before),
		"quality rebuild preserves lap timing",
		before,
		_lap_state()
	)
	_lap_check(
		game.result_id == expected_id,
		"quality rebuild preserves race result ID",
		expected_id,
		game.result_id
	)
	game._save_session()
	var saved := ConfigFile.new()
	var save_error: Error = saved.load(game.SESSION)
	_lap_check(save_error == OK, "lap-two atomic ConfigFile exists", OK, save_error)
	var saved_pair := {
		"lap_times": saved.get_value("race", "lap_times", []),
		"lap_started_at": saved.get_value("race", "lap_started_at", -1.0),
	}
	_lap_check(
		_lap_pair_close(saved_pair, before),
		"ConfigFile stores completed laps and current start",
		before,
		saved_pair
	)
	_lap_check(
		(
			str(saved.get_value("race", "result_id", "")) == expected_id
			and int(saved.get_value("race", "checkpoint_index", -1)) == 10
		),
		"lap-two save retains legitimate gate progress and identity",
		{"result_id": expected_id, "checkpoint_index": 10},
		{
			"result_id": saved.get_value("race", "result_id", ""),
			"checkpoint_index": saved.get_value("race", "checkpoint_index", -1)
		}
	)
	await _lap_reopen()
	_lap_check(
		game.saved_session_available,
		"a new instance offers the saved lap-two race",
		true,
		game.saved_session_available
	)
	game._resume_saved_race()
	var restored: Dictionary = _lap_state()
	lap_evidence["lap2_before"] = before.duplicate(true)
	lap_evidence["lap2_restored"] = restored.duplicate(true)
	_lap_check(
		(
			game.paused
			and game.result_id == expected_id
			and game.checkpoint_index == 10
			and absf(game.elapsed - float(before.elapsed)) <= 0.000000001
			and absf(game.distance - float(before.distance)) <= 0.000000001
		),
		"new-instance resume restores frozen progress and identity",
		before,
		restored
	)
	_lap_check(
		_lap_pair_close(restored, before),
		"new-instance resume restores both lap timing fields",
		before,
		restored
	)
	_lap_check(
		lap_host.reward_calls == 0,
		"a paused resume never awards a result",
		0,
		lap_host.reward_calls
	)
	game.auto_gas = true
	game._resume()
	_lap_check(
		game.elapsed == float(restored.elapsed),
		"resume itself does not advance elapsed time",
		restored.elapsed,
		game.elapsed
	)
	while not game.finished and frames < 12000:
		_lap_drive_step()
		frames += 1
		if game.checkpoint_index != last_gate:
			last_gate = game.checkpoint_index
			gates.append({"gate": last_gate, "seconds": game.elapsed, "distance": game.distance})
		if frames % 120 == 0:
			await process_frame
	_lap_check(
		game.finished and game.checkpoint_index == 16,
		"resumed physical driving completes sixteen gates",
		16,
		game.checkpoint_index
	)
	var ordered := gates.size() == 16
	for i in range(gates.size()):
		ordered = ordered and int(gates[i].gate) == i + 1
		if i > 0:
			ordered = ordered and float(gates[i].seconds) > float(gates[i - 1].seconds)
			ordered = ordered and float(gates[i].distance) > float(gates[i - 1].distance)
	_lap_check(ordered, "all physically crossed gates are ordered and monotonic", true, gates)
	var final_seconds: float = float(gates[-1].seconds) if not gates.is_empty() else -1.0
	var expected_laps: Array[float] = [first_lap, final_seconds - first_lap]
	var laps_match: bool = game.lap_times.size() == 2
	if laps_match:
		for i in range(2):
			laps_match = laps_match and absf(game.lap_times[i] - expected_laps[i]) <= 0.000000001
	_lap_check(
		laps_match,
		"two completed laps equal independently measured gate intervals",
		expected_laps,
		game.lap_times
	)
	var expected_best: float = snappedf(minf(expected_laps[0], expected_laps[1]), 0.001)
	_lap_check(
		float(game.result_payload.get("bestLapSeconds", -1.0)) == expected_best,
		"published best lap agrees with the two measured laps",
		expected_best,
		game.result_payload.get("bestLapSeconds")
	)
	var expected_total: float = snappedf(final_seconds, 0.001)
	_lap_check(
		(
			float(game.result_payload.elapsedSeconds) == expected_total
			and game._result_stats_text().contains(
				"Gesamtzeit   " + game._format_time(expected_total)
			)
		),
		"published milliseconds and the visible total agree with gate sixteen",
		{
			"elapsedSeconds": expected_total,
			"line": "Gesamtzeit   " + game._format_time(expected_total)
		},
		{"elapsedSeconds": game.result_payload.elapsedSeconds, "text": game._result_stats_text()}
	)
	_lap_check(
		(
			game.result_payload.resultId == expected_id
			and game.result_payload.stars == 3
			and game.result_payload.solved is int
			and game.result_payload.solved == 0
			and game.reset_count == 0
		),
		"the legitimate race keeps ID, integer solved zero, three stars and zero resets",
		{"resultId": expected_id, "stars": 3, "solved": 0, "resets": 0},
		game.result_payload
	)
	_lap_check(
		(
			lap_host.reward_calls == 1
			and lap_host.rewards.size() == 1
			and lap_host.rewards.has(expected_id)
		),
		"the driven race awards exactly one host reward",
		1,
		lap_host.reward_calls
	)
	var finished_pair: Dictionary = _lap_state()
	var finished_payload: Dictionary = game.result_payload.duplicate(true)
	var finished_elapsed: float = game.elapsed
	game._save_session()
	saved.load(game.SESSION)
	saved_pair = {
		"lap_times": saved.get_value("race", "lap_times", []),
		"lap_started_at": saved.get_value("race", "lap_started_at", -1.0),
	}
	_lap_check(
		_lap_pair_close(saved_pair, finished_pair),
		"finished ConfigFile retains both completed laps",
		finished_pair,
		saved_pair
	)
	var stars_before: int = root.get_node("ProgressStore").total_stars()
	await _lap_reopen()
	game._resume_saved_race()
	var reopened_payload: Dictionary = game.result_payload.duplicate(true)
	_lap_check(
		JSON.stringify(reopened_payload) == JSON.stringify(finished_payload),
		"finished reopen retains the original public payload",
		finished_payload,
		reopened_payload
	)
	var stats: Label = game.modal_column.get_node("ResultStats")
	var stats_text: String = stats.text
	var stats_visible: bool = stats.is_visible_in_tree()
	_lap_check(
		(
			stats_visible
			and stats_text.contains("Beste Runde   " + game._format_time(expected_best))
			and stats_text.contains("Gesamtzeit   " + game._format_time(expected_total))
		),
		"finished reopen visibly retains both best and total result lines",
		{
			"best": game._format_time(expected_best),
			"total": game._format_time(expected_total),
			"visible": true
		},
		{"text": stats_text, "visible": stats_visible}
	)
	_lap_check(
		lap_host.reward_calls == 1 and root.get_node("ProgressStore").total_stars() == stars_before,
		"finished reopen never awards another local or host reward",
		{"host_rewards": 1, "local_stars": stars_before},
		{
			"host_rewards": lap_host.reward_calls,
			"local_stars": root.get_node("ProgressStore").total_stars()
		}
	)
	lap_evidence["reopened_result_ui"] = await _lap_check_result_ui("saved finished result")
	var screenshot := ""
	var screenshot_sha := ""
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		screenshot = "result_reopen.png"
		assert(root.get_texture().get_image().save_png(lap_output.path_join(screenshot)) == OK)
		screenshot_sha = FileAccess.get_sha256(lap_output.path_join(screenshot))
	(
		lap_evidence
		. merge(
			{
				"ordered_gates": gates.duplicate(true),
				"expected_laps": expected_laps.duplicate(),
				"finished_elapsed_seconds": finished_elapsed,
				"reopened_result_elapsed_seconds": game.elapsed,
				"finished_payload": finished_payload.duplicate(true),
				"reopened_result_payload": reopened_payload.duplicate(true),
				"reopened_result_stats_text": stats_text,
				"reopened_result_stats_visible": stats_visible,
				"reward_calls": lap_host.reward_calls,
				"result_reopen_png": screenshot,
				"result_reopen_png_sha256": screenshot_sha,
				"driven_frames": frames,
			},
			true
		)
	)
	lap_host.return_ack = 1
	game._return_to_app("games")
	_lap_check(
		(
			not FileAccess.file_exists(game.SESSION)
			and not lap_host.returns.is_empty()
			and lap_host.returns[-1].status == "completed"
			and lap_host.returns[-1].resultId == expected_id
		),
		"completed ACK removes the durable save without a duplicate award",
		{"status": "completed", "resultId": expected_id, "save_exists": false},
		{
			"returns": lap_host.returns.duplicate(true),
			"save_exists": FileAccess.file_exists(game.SESSION)
		}
	)
	bridge._return_pending = false
	bridge._host = null
	bridge._options = {}
	lap_host.queue_free()
	lap_host = null


func _lap_seed_config(
	checkpoint: int = 10, seconds: float = 55.0, fixture_mode: String = "race"
) -> ConfigFile:
	game.mode = fixture_mode
	game.elapsed = seconds
	game.distance = game.track_length * float(checkpoint) / 8.0
	game.previous_road_distance = fposmod(game.distance, game.track_length)
	game.checkpoint_index = checkpoint
	game.finished = false
	game.completed_race = false
	game.result_payload = {}
	game._save_session()
	var config := ConfigFile.new()
	assert(config.load(game.SESSION) == OK)
	return config


func _lap_erase(config: ConfigFile, key: String) -> void:
	if config.has_section_key("race", key):
		config.erase_section_key("race", key)


func _test_lap_payload_best() -> void:
	await _fresh()
	game._pause()
	for best in [28.0, 0.0, -1.0, "28", true, INF, NAN, 1000.0, 1.0e308]:
		var config: ConfigFile = _lap_seed_config(16, 58.0)
		_lap_erase(config, "lap_times")
		_lap_erase(config, "lap_started_at")
		config.set_value("race", "finished", true)
		config.set_value("race", "completed_race", true)
		config.set_value("race", "result_payload", {"place": 1, "stars": 3, "bestLapSeconds": best})
		assert(config.save(game.SESSION) == OK)
		game._restore_session()
		var text: String = game.modal_column.get_node("ResultStats").text
		var expected_best := (
			typeof(best) == TYPE_FLOAT and is_finite(float(best)) and float(best) == 28.0
		)
		_lap_check(
			(
				text.contains("Beste Runde   00:28.000")
				if expected_best
				else not text.contains("Beste Runde")
			),
			"legacy result displays only a valid known payload best: " + str(best),
			{"has_best": expected_best, "line": "00:28.000" if expected_best else ""},
			{"text": text, "lap_times": game.lap_times.duplicate()}
		)


func _test_lap_positive_edges() -> void:
	await _fresh()
	game._pause()
	var config: ConfigFile = _lap_seed_config(3, 20.0)
	_lap_erase(config, "lap_times")
	_lap_erase(config, "lap_started_at")
	assert(config.save(game.SESSION) == OK)
	game._restore_session()
	_lap_check(
		game.lap_times.is_empty() and game.lap_started_at == 0.0,
		"first-lap legacy retains the known original start",
		[[], 0.0],
		[game.lap_times, game.lap_started_at]
	)
	config = _lap_seed_config(16, 70.0, "training")
	config.set_value("race", "lap_times", [30.0])
	config.set_value("race", "lap_started_at", 60.0)
	assert(config.save(game.SESSION) == OK)
	game._restore_session()
	_lap_check(
		game.lap_times == [30.0] and game.lap_started_at == 60.0,
		"known later start accepts shorter history after legacy gaps",
		[[30.0], 60.0],
		[game.lap_times, game.lap_started_at]
	)
	config = _lap_seed_config(8, 50.0, "training")
	config.set_value("race", "finished", true)
	config.set_value("race", "completed_race", true)
	config.set_value("race", "lap_times", [30.0, 20.0])
	config.set_value("race", "lap_started_at", 30.0)
	assert(config.save(game.SESSION) == OK)
	game._restore_session()
	_lap_check(
		game.lap_times == [30.0, 20.0] and game.lap_started_at == 30.0,
		"finished training retains its deliberately completed partial lap",
		[[30.0, 20.0], 30.0],
		[game.lap_times, game.lap_started_at]
	)
	await _fresh("time_trial")
	game.speed = 12.0
	game._update_hud()
	var driving: Dictionary = _lap_ui_state()
	game._pause()
	game._update_hud()
	var paused_ui: Dictionary = _lap_ui_state()
	game._finish(false)
	var finished_ui: Dictionary = _lap_ui_state()
	game._physics_process(STEP)
	var after_tick: Dictionary = _lap_ui_state()
	_lap_check(
		(
			driving.displayed_speed_kmh == 43
			and paused_ui.displayed_speed_kmh == 43
			and finished_ui.displayed_speed_kmh == 0
			and after_tick.displayed_speed_kmh == 0
			and game.speed == 12.0
		),
		"time-trial HUD only changes finished display without mutating speed",
		{"driving": 43, "paused": 43, "finished": 0, "after_tick": 0, "raw_speed": 12.0},
		{"driving": driving, "paused": paused_ui, "finished": finished_ui, "after_tick": after_tick}
	)


func _test_direct_result_ui() -> void:
	await _fresh("training")
	game.auto_gas = true
	for frame in range(60):
		_lap_drive_step()
	game._finish(false)
	lap_evidence["direct_result_ui"] = await _lap_check_result_ui("direct noncinematic result")


func _lap_suite() -> bool:
	var requested_output: String = OS.get_environment("LUMO_QA_DIR")
	if not requested_output.is_empty():
		lap_output = requested_output
	DirAccess.make_dir_recursive_absolute(lap_output)
	await _test_lap_driven_reopen()
	await LAP_FIXTURES.legacy_pairs(self)
	await LAP_FIXTURES.unknown_durability(self)
	await LAP_FIXTURES.unknown_finish(self)
	await LAP_FIXTURES.versions(self)
	await _test_lap_payload_best()
	await _test_lap_positive_edges()
	await _test_direct_result_ui()
	var failures := 0
	for check in lap_checks:
		if not check.passed:
			failures += 1
	(
		lap_evidence
		. merge(
			{
				"status": "PASS" if failures == 0 else "FAIL",
				"check_count": lap_checks.size(),
				"failed_checks": failures,
				"checks": lap_checks.duplicate(true),
				"provenance": "NEW_TEST_IMPLEMENTATION_AFTER_WORKSPACE_LOSS",
				"historical_unrecovered_probe_sha256":
				"a6f17131675e84a7576e8db770a02823f66623b062164287908866b802a4e8a3",
				"engine": Engine.get_version_info().string,
				"display_server": DisplayServer.get_name(),
				"rendering_method": RenderingServer.get_current_rendering_method(),
				"renderer_setting":
				ProjectSettings.get_setting("rendering/renderer/rendering_method"),
				"source_sha256": FileAccess.get_sha256("res://scripts/games/kart_island.gd"),
				"fixture_probe_sha256":
				FileAccess.get_sha256("res://scripts/tests/kart_lap_session_fixtures.gd"),
				"probe_sha256":
				FileAccess.get_sha256("res://scripts/tests/kart_race_continuity_regression.gd"),
				"fixture_scope":
				(
					"20 ConfigFile pair fixtures and legacy/UI state fixtures are assigned; "
					+ "ordered_gates alone records actual driven progress"
				),
				"physical_device_performance": "NOT EXECUTED",
			},
			true
		)
	)
	(
		FileAccess
		. open(lap_output.path_join("lap-session-evidence.json"), FileAccess.WRITE)
		. store_string(JSON.stringify(lap_evidence, "  "))
	)
	if lap_checks.size() != 104:
		push_error("New lap continuity contract requires 104 checks, got %d" % lap_checks.size())
		return false
	print(
		(
			"[KartLapContinuity] %s: %d checks, %d failures"
			% [lap_evidence.status, lap_checks.size(), failures]
		)
	)
	return failures == 0
