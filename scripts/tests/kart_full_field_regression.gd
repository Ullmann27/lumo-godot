extends SceneTree
## Continuous two-lap production AI drive. Only initial placement is controlled;
## no transforms, progress, items, drift or stunt states are injected thereafter.
const STEP: float = 1.0 / 60.0
const MAX_SECONDS: float = 420.0
const LOOP_KEY: StringName = &"lumo_physical_loop"
const LASSO_RULES = preload("res://scripts/games/kart_lasso_rules.gd")
var game
var failed: bool = false
var selected_level: String = ""
var stopped_player: bool = false
var selected_scenario: String = ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--stopped-player":
			selected_scenario = "stopped"
		if arg == "--clear-player":
			selected_scenario = "clear"
		if arg.begins_with("--level="):
			selected_level = arg.trim_prefix("--level=")
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[KartFullField] " + message)


func _run() -> void:
	var results: Array[Dictionary] = []
	for blocked in [false, true]:
		if selected_scenario == "stopped" and not blocked:
			continue
		if selected_scenario == "clear" and blocked:
			continue
		stopped_player = blocked
		for level in ["gemuetlich", "flott", "pro"]:
			if not selected_level.is_empty() and level != selected_level:
				continue
			results.append(await _drive(level))
	_check(not results.is_empty(), "No matching full-field scenario was selected")
	print("[KartFullField] RESULTS " + JSON.stringify(results))
	if not failed:
		print("[KartFullField] PASS: continuous field two-lap drive with bounded movement")
	quit(1 if failed else 0)


func _drive(level: String) -> Dictionary:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": level
		}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.speed = 0.0
	# The production player physics also runs. Place the clear-course player on
	# the shoulder inside the rail, or stopped in the outside racing lane once.
	# Opponents retain their real grid, kart roster, item gates and obstacles.
	game.player.transform = Transform3D(
		game.world.frame(0.0), game.world.position_at(0.0, 3.5 if stopped_player else -5.0)
	)
	game.distance = 0.0
	await process_frame
	var previous_positions: Array[Vector3] = []
	var previous_progress: Array[float] = []
	var finish_times: Array[float] = []
	var minimum_player_clearances: Array[float] = []
	var minimum_speeds: Array[float] = []
	var maximum_speeds: Array[float] = []
	var maximum_steps: Array[float] = []
	var minimum_progress_steps: Array[float] = []
	var last_window_progress: Array[float] = []
	var stalled_windows: Array[int] = []
	var failed_loops: Array[int] = []
	var lasso_catches: Array[int] = []
	var lasso_hold: Array[float] = []
	var longest_lasso_hold: Array[float] = []
	var lasso_crossings: Array[Dictionary] = []
	var seen_failed_states: Dictionary = {}
	var seen_flights: Dictionary = {}
	var invalid_motion: bool = false
	_check(is_instance_valid(game.roadside_lasso), "Live race must create roadside encounters")
	_check(game.roadside_lasso.layout.size() == 2, "Sonnenhafen must contain both roadside crews")
	for i in range(game.opponents.size()):
		previous_positions.append(game.opponents[i].position)
		previous_progress.append(game.opponent_distances[i])
		last_window_progress.append(game.opponent_distances[i])
		finish_times.append(-1.0)
		minimum_player_clearances.append(INF)
		minimum_speeds.append(INF)
		maximum_speeds.append(0.0)
		maximum_steps.append(0.0)
		minimum_progress_steps.append(0.0)
		stalled_windows.append(0)
		failed_loops.append(0)
		lasso_catches.append(0)
		lasso_hold.append(0.0)
		longest_lasso_hold.append(0.0)
		lasso_crossings.append({})
	var seconds: float = 0.0
	for frame in range(int(MAX_SECONDS / STEP)):
		game._physics_process(STEP)
		seconds = (frame + 1) * STEP
		var finished_count: int = 0
		for i in range(game.opponents.size()):
			if finish_times[i] >= 0.0:
				finished_count += 1
				continue
			var rival = game.opponents[i]
			# Rules intentionally prune old laps. Retain observed crossings here
			# instead of confusing bounded runtime memory with a missed encounter.
			var live_lasso: Dictionary = game.roadside_lasso.rules.racers.get("rival_%d" % i, {})
			for key in live_lasso.get("used", {}):
				lasso_crossings[i][key] = true
			var factor: float = float(rival.get_meta("roadside_speed_factor", 1.0))
			if factor < 1.0:
				_check(is_equal_approx(factor, LASSO_RULES.SPEED_FACTOR), "Lasso must use its bounded drive factor")
				if lasso_hold[i] == 0.0:
					lasso_catches[i] += 1
				lasso_hold[i] += STEP
				longest_lasso_hold[i] = maxf(longest_lasso_hold[i], lasso_hold[i])
			else:
				lasso_hold[i] = 0.0
			var gap_to_player: Vector3 = rival.position - game.player.position
			gap_to_player.y = 0.0
			minimum_player_clearances[i] = minf(
				minimum_player_clearances[i], gap_to_player.length()
			)
			var actual_step: float = rival.position.distance_to(previous_positions[i])
			var progress_step: float = game.opponent_distances[i] - previous_progress[i]
			minimum_speeds[i] = minf(minimum_speeds[i], float(rival.motion_speed))
			maximum_speeds[i] = maxf(maximum_speeds[i], float(rival.motion_speed))
			maximum_steps[i] = maxf(maximum_steps[i], actual_step)
			minimum_progress_steps[i] = minf(minimum_progress_steps[i], progress_step)
			if not rival.position.is_finite() or actual_step > 1.5 or progress_step < -2.0:
				_check(
					false,
					(
						"%s rival%d discontinuity at %.2fs d=%.2f step=%.3f progress=%.3f"
						% [
							level,
							i,
							seconds,
							game.opponent_distances[i],
							actual_step,
							progress_step
						]
					)
				)
				invalid_motion = not rival.position.is_finite()
			previous_positions[i] = rival.position
			previous_progress[i] = game.opponent_distances[i]
			if rival.has_meta(&"lumo_ballistic_flight"):
				var flight = rival.get_meta(&"lumo_ballistic_flight")
				if not seen_flights.has(flight.get_instance_id()):
					seen_flights[flight.get_instance_id()] = true
					print(
						(
							"[KartFullField] LAUNCH "
							+ JSON.stringify(
								{
									"difficulty": level,
									"rival": i,
									"t": seconds,
									"speed": flight.speed,
									"lane": flight.launch_lane,
									"at": game.opponent_distances[i],
									"take_off": flight.kicker.take_off,
									"precision": flight.kicker.get("precision_jump", false),
									"stunned": game.opponent_stuns[i]
								}
							)
						)
					)
			if rival.has_meta(LOOP_KEY):
				var state = rival.get_meta(LOOP_KEY)
				if state.failed and not seen_failed_states.has(state.get_instance_id()):
					seen_failed_states[state.get_instance_id()] = true
					failed_loops[i] += 1
			if game.opponent_distances[i] >= game.track_length * 2.0 and finish_times[i] < 0.0:
				finish_times[i] = seconds
			if finish_times[i] >= 0.0:
				finished_count += 1
			if frame % 900 == 899:
				if game.opponent_distances[i] - last_window_progress[i] < 8.0:
					stalled_windows[i] += 1
					if stalled_windows[i] == 1:
						var road: Dictionary = game.world.sample_road(
							rival.position, fposmod(game.opponent_distances[i], game.track_length)
						)
						print(
							(
								"[KartFullField] FIRST_STALL "
								+ JSON.stringify(
									{
										"rival": i,
										"at": game.opponent_distances[i],
										"position": str(rival.position),
										"lane": road.lateral,
										"speed": rival.motion_speed,
										"heading": game.opponent_headings[i],
										"traffic": str(game._rival_traffic(i, road)),
										"player": str(game.player.position)
									}
								)
							)
						)
				last_window_progress[i] = game.opponent_distances[i]
		if frame % 900 == 899:
			print(
				(
					"[KartFullField] %s t=%.0f progress=%s completed=%d"
					% [level, seconds, game.opponent_distances, finished_count]
				)
			)
		if invalid_motion or finished_count == game.opponents.size():
			break
		if frame % 120 == 119:
			await process_frame
	var rows: Array[Dictionary] = []
	var completed: int = 0
	for i in range(game.opponents.size()):
		var rival = game.opponents[i]
		var loops: int = int(rival.get_meta(&"lumo_completed_loops", 0))
		if finish_times[i] >= 0.0:
			completed += 1
		_check(
			finish_times[i] > 0.0,
			(
				"%s rival%d failed two laps: progress %.2f / %.2f"
				% [level, i, game.opponent_distances[i], game.track_length * 2.0]
			)
		)
		_check(
			stalled_windows[i] == 0,
			"%s rival%d stalled in %d fifteen-second windows" % [level, i, stalled_windows[i]]
		)
		if stopped_player:
			_check(
				minimum_player_clearances[i] >= 1.45,
				(
					"%s rival%d touched stopped player (%.3fm)"
					% [level, i, minimum_player_clearances[i]]
				)
			)
		_check(failed_loops[i] == 0, "%s rival%d failed %d loops" % [level, i, failed_loops[i]])
		_check(
			int(rival.get_meta(&"lumo_flight_rescues", 0)) == 0,
			"%s rival%d needed a gap rescue" % [level, i]
		)
		_check(
			int(rival.get_meta(&"lumo_flight_landings", 0)) >= 8,
			"%s rival%d missed a mandatory ramp" % [level, i]
		)
		_check(
			longest_lasso_hold[i] <= LASSO_RULES.HOLD_SECONDS + STEP,
			"%s rival%d remained caught beyond the bounded hold" % [level, i]
		)
		var lasso_state: Dictionary = game.roadside_lasso.rules.racers.get("rival_%d" % i, {})
		_check(not lasso_state.is_empty(), "Rival must pass through the live lasso state machine")
		_check(lasso_crossings[i].size() == 4, "Each rival must physically cross both crews on both laps")
		if level != "gemuetlich" and i % 2 == 1:
			_check(
				loops >= 2,
				"%s adventurous rival%d missed the loop on a lap (%d completed)" % [level, i, loops]
			)
		rows.append(
			{
				"rival": i,
				"kart": rival.kart_style,
				"finish_seconds": finish_times[i],
				"progress_m": game.opponent_distances[i],
				"min_speed_mps": minimum_speeds[i],
				"minimum_player_clearance_m": minimum_player_clearances[i],
				"max_speed_mps": maximum_speeds[i],
				"max_frame_step_m": maximum_steps[i],
				"min_progress_step_m": minimum_progress_steps[i],
				"loops": loops,
				"failed_loops": failed_loops[i],
				"flight_rescues": int(rival.get_meta(&"lumo_flight_rescues", 0)),
				"flight_landings": int(rival.get_meta(&"lumo_flight_landings", 0)),
				"stalled_windows": stalled_windows[i],
				"lasso_catches": lasso_catches[i],
				"longest_lasso_hold_seconds": longest_lasso_hold[i],
				"lasso_crossings": lasso_crossings[i].size(),
			}
		)
	var report: Dictionary = {
		"difficulty": level,
		"stopped_player": stopped_player,
		"completed": completed,
		"track_length_m": game.track_length,
		"simulated_seconds": seconds,
		"racers": rows,
		"production_physics": true,
		"lasso_clock_seconds": game.roadside_lasso.clock,
	}
	_check(absf(game.roadside_lasso.clock - seconds) < STEP, "Lasso clock must run once per production physics tick")
	print("[KartFullField] REPORT " + JSON.stringify(report))
	var playbacks: Array[WeakRef] = []
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	var scene: WeakRef = weakref(game)
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = null
	_check(await _release_audio(scene, playbacks), "Scene or audio playback retained after teardown")
	return report


func _release_audio(scene: WeakRef, playbacks: Array[WeakRef]) -> bool:
	# A freed scene can leave mixer-side Ogg fadeout alive beyond one frame.
	# Observe real owners without retaining them; simulation time is not a deadline.
	var started := Time.get_ticks_msec()
	while true:
		var pending := 0
		for playback: WeakRef in playbacks:
			if playback.get_ref() != null:
				pending += 1
		var scene_retained := scene.get_ref() != null
		var elapsed := Time.get_ticks_msec() - started
		if elapsed >= 2000:
			printerr(
				"[KartFullField] retained_scene=%s retained_audio_playbacks=%d elapsed_ms=%d"
				% [scene_retained, pending, elapsed]
			)
			return false
		if not scene_retained and pending == 0:
			print("[KartFullField] audio_release tracked=%d scene_released=true elapsed_ms=%d" % [playbacks.size(), elapsed])
			return true
		OS.delay_msec(2)
		await process_frame
	return false
