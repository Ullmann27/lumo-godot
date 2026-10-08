extends SceneTree
## Consumed pickups, bounded rival states and an airborne reset survive real race transitions.

const STEP: float = 1.0 / 60.0
var game
var scene: PackedScene


func _initialize() -> void:
	call_deferred("_run")


func _fresh(mode: String = "race", track: String = "sonnenhafen") -> void:
	if is_instance_valid(game):
		game.abandoned = true
		game.queue_free()
		await process_frame
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
	game.abandoned = true
	game.queue_free()
	await process_frame
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
	game.abandoned = true
	game.queue_free()
	await process_frame
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
	var probe: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--red-probe="):
			probe = arg.trim_prefix("--red-probe=")
	if probe == "rebuild":
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
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	await create_timer(0.5).timeout
	print(
		(
			"[KartContinuity] PASS: quality change, save/reopen, next lap, "
			+ "rival states, legacy saves and flight reset"
		)
	)
	quit(0)
