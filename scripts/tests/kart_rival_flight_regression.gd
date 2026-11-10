extends "res://scripts/tests/kart_sonnenhafen_stunt_regression.gd"
const FLIGHT = preload("res://scripts/games/kart_rival_flight.gd")


func _race(track: String = "sonnenhafen") -> void:
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	game._end_preview()
	await _settle()
	game.countdown = 0
	game.racing = true


func _launch_at_speed(ramp: Dictionary, momentum: float, lap: int = 0) -> Dictionary:
	var rival = game.opponents[0]
	if rival.has_meta(FLIGHT.STATE_KEY):
		rival.remove_meta(FLIGHT.STATE_KEY)
	var edge: float = float(ramp.take_off)
	var before: Dictionary = game.world.sample_road(game.world.position_at(edge - 0.1), edge - 0.1)
	var after: Dictionary = game.world.sample_road(game.world.position_at(edge + 0.05), edge + 0.05)
	rival.transform = game.world.reset_transform(edge + 0.05)
	game.opponent_headings[0] = game._heading(edge)
	game.opponent_distances[0] = float(lap) * game.track_length + edge + 0.05
	game.opponent_lanes[0] = 0.0
	game.opponent_boost_times[0] = 0.0
	game.opponent_stuns[0] = 0.0
	assert(
		FLIGHT.try_launch(game, 0, before, after, momentum), "Crossing the actual ramp lip launches"
	)
	var state = rival.get_meta(FLIGHT.STATE_KEY)
	var initial_distance: float = game.opponent_distances[0]
	var peak: float = 0.0
	var saved: bool = false
	for frame in range(300):
		var previous: Vector3 = rival.position
		var previous_distance: float = game.opponent_distances[0]
		game._drive_opponents(STEP)
		if not state.active:
			break
		assert(is_equal_approx(state.speed, momentum), "No canned speed/boost change in flight")
		assert(game.opponent_distances[0] >= previous_distance - 0.01, "No backward lap progress")
		assert(
			(
				rival.position.distance_to(previous)
				< momentum * STEP + absf(state.vertical_speed) * STEP + 0.05
			),
			"Ballistic flight has no teleport"
		)
		peak = maxf(peak, rival.position.y - float(after.height))
		if state.elapsed > 0.2 and not saved:
			game._save_session()
			var cfg := ConfigFile.new()
			assert(cfg.load(game.SESSION) == OK)
			var positions: Array = cfg.get_value("race", "opponent_positions")
			var distances: Array = cfg.get_value("race", "opponent_distances")
			assert(
				(
					positions[0].distance_to(game.world.reset_transform(float(ramp.start)).origin)
					< 0.01
				),
				"Airborne snapshot returns to ramp entry"
			)
			assert(
				distances[0] <= initial_distance and distances[0] >= float(lap) * game.track_length,
				"Snapshot retains lap and grants no shortcut"
			)
			saved = true
	assert(not state.active and saved, "Flight finishes and was safely saved")
	return {
		"result": rival.get_meta(&"lumo_flight_result"),
		"distance": rival.get_meta(&"lumo_flight_distance", 0.0),
		"peak": peak,
		"end_speed": rival.motion_speed,
		"progress": game.opponent_distances[0],
		"boost": game.opponent_boost_times[0]
	}


func _check_precision_flight() -> void:
	await _race()
	var ramp: Dictionary = game.world.action.kickers[1]
	assert(bool(ramp.get("precision_jump", false)))
	var slow: Dictionary = _launch_at_speed(ramp, 12.0, 1)
	assert(slow.result == PRECISION.LANDING_SHORT, "Slow rival really falls short")
	assert(slow.end_speed == 8.0, "Cloud rescue uses the player's recovery speed")
	assert(
		(
			slow.progress > game.track_length
			and slow.progress < game.track_length + float(ramp.gap_end) + 10.0
		),
		"Recovery retains lap and stays just past the gap"
	)
	for frame in range(20):
		game._drive_opponents(STEP)
		var recovered: Dictionary = game.world.sample_road(
			game.opponents[0].position, fposmod(game.opponent_distances[0], game.track_length)
		)
		assert(
			absf(game.opponents[0].position.y - float(recovered.height)) < 0.1,
			"A rescued rival cannot re-enter the old canned arc"
		)
	var good: Dictionary = _launch_at_speed(ramp, float(ramp.rival_speed), 1)
	assert(
		good.result == PRECISION.LANDING_ZONE and good.boost > 0.0,
		"Good real speed lands in zone and rewards boost"
	)
	assert(
		absf(good.distance - PRECISION.landing_distance(float(ramp.rival_speed), ramp)) < 1.0,
		"Rival flight agrees with shared model"
	)
	var fast: Dictionary = _launch_at_speed(ramp, 30.0, 1)
	assert(
		fast.result == PRECISION.LANDING_LONG and fast.end_speed < 19.0,
		"Fast rival overshoots and loses speed"
	)
	assert(
		fast.peak > good.peak and good.peak > slow.peak, "Real launch speed changes flight height"
	)
	completed_checks += 1
	print(
		(
			"[RivalFlight] slow=%s good=%s %.2fm fast=%s %.2fm; real speed-dependent peaks %.2f/%.2f/%.2f"
			% [
				slow.result,
				good.result,
				good.distance,
				fast.result,
				fast.distance,
				slow.peak,
				good.peak,
				fast.peak
			]
		)
	)


func _check_controller_launch(track: String, use_sky_jump: bool) -> void:
	await _race(track)
	var ramp: Dictionary = game.world.jump if use_sky_jump else game.world.action.kickers[0]
	var start: float = float(ramp.ramp_start if use_sky_jump else ramp.start) - 8.0
	game.opponent_distances[0] = start
	game.opponent_headings[0] = game._heading(start)
	game.opponents[0].transform = game.world.reset_transform(start)
	var entered: bool = false
	for frame in range(600):
		game._drive_opponents(STEP)
		var rival = game.opponents[0]
		if rival.has_meta(FLIGHT.STATE_KEY):
			entered = true
			if not rival.get_meta(FLIGHT.STATE_KEY).active:
				break
	assert(entered, "%s: controller automatically triggers real take-off" % track)
	assert(
		game.opponents[0].get_meta(&"lumo_flight_landings", 0) == 1,
		"%s: automatic approach really lands" % track
	)
	completed_checks += 1
	print("[RivalFlight] %s: automatic AI approach, take-off and landing PASS" % track)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _check_precision_flight()
	await _check_controller_launch("sonnenhafen", false)
	await _check_controller_launch("bergwelt", true)
	if completed_checks != 3:
		quit(1)
		return
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	print(
		"[RivalFlight] PASS: launch-speed physics, real misses, safe snapshots and automatic ramps"
	)
	quit(0)
