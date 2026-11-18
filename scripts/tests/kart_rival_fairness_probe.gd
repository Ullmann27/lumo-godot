extends SceneTree
## Messgeschirr „Gegner fairer“: ein Kind-Fahrer fährt echte Rennen gegen die fünf Rivalen.
## Kopflos, fester 60-Hz-Takt, fester Zufalls-Seed (kart_island.race_seed), gleiche Aufstellung.
## Der Kind-Fahrer lenkt vernünftig, aber nicht perfekt: 0,18 s Reaktionszeit, begrenzte
## Daumengeschwindigkeit am Stick, leichtes Schlingern, kein Drift, hält GAS gedrückt
## (Touch-Standard ohne Auto-Gas), bremst kurz vor sehr engen Kurven, benutzt ein Item
## zwei Sekunden nach dem Einsammeln. Szenarien:
##   clean   – saubere Fahrt
##   mistake – in Runde 1 wird die engste Kurve verpasst (Lenkung bleibt gerade, bis das
##             Kart am Rand/an der Planke ist oder 2 s vergangen sind)
##   halt    – in Runde 1 vor der engsten Stelle bis zum Stillstand bremsen, 2 s warten
## Je Lauf eine JSON-Zeile (an --out= angehängt): Platz, Zeiten, Rückstand, Abstandsverlauf,
## Ereignisse (Treffer, Rücksetzer, Rempler) mit Streckenmeter, Aufholhilfe und Gummiband.
## Aufruf: --script res://scripts/tests/kart_rival_fairness_probe.gd -- --track=winter_sprint
##   --levels=gemuetlich,flott,pro --scenarios=clean,mistake,halt --seed=7 --out=/abs/datei.jsonl
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const RACECRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const STEP := 1.0 / 60.0
const REACTION_FRAMES := 11
const THUMB_RATE := 5.0
const MARK := 25.0
const MAX_FRAMES := 32000
const POST_FINISH_LIMIT := 45.0

var game
var track: String = "winter_sprint"
var levels: Array[String] = ["gemuetlich", "flott", "pro"]
var scenarios: Array[String] = ["clean", "mistake", "halt"]
var seeds: Array[int] = [7]
var out_path: String = ""
var label: String = ""
## Kind-Fahrer-Parameter (über Argumente einstellbar, Standard = gemessene Wahl).
var gain: float = 1.4
var reaction_frames: int = REACTION_FRAMES
var look_k: float = 0.6
var wander_m: float = 0.9
var max_seconds: float = 1.0e9
var diag_rival: int = -1
var diag_from: float = 0.0
var diag_to: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		var text: String = str(argument)
		if text.begins_with("--track="):
			track = text.trim_prefix("--track=")
		elif text.begins_with("--levels="):
			levels.assign(text.trim_prefix("--levels=").split(","))
		elif text.begins_with("--scenarios="):
			scenarios.assign(text.trim_prefix("--scenarios=").split(","))
		elif text.begins_with("--seed="):
			seeds.clear()
			for value in text.trim_prefix("--seed=").split(","):
				seeds.append(int(value))
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
		elif text.begins_with("--gain="):
			gain = float(text.trim_prefix("--gain="))
		elif text.begins_with("--delay="):
			reaction_frames = int(text.trim_prefix("--delay="))
		elif text.begins_with("--look="):
			look_k = float(text.trim_prefix("--look="))
		elif text.begins_with("--wander="):
			wander_m = float(text.trim_prefix("--wander="))
		elif text.begins_with("--max-seconds="):
			max_seconds = float(text.trim_prefix("--max-seconds="))
		elif text.begins_with("--diag="):
			var parts: PackedStringArray = text.trim_prefix("--diag=").split(":")
			diag_rival = int(parts[0])
			diag_from = float(parts[1])
			diag_to = float(parts[2])
		elif text.begins_with("--label="):
			label = text.trim_prefix("--label=")


func _run() -> void:
	_parse_args()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await process_frame
	var failures: int = 0
	for level in levels:
		for scenario in scenarios:
			for race_seed in seeds:
				var started: int = Time.get_ticks_msec()
				var row: Dictionary = await _race(level, scenario, race_seed)
				row["wall_ms"] = Time.get_ticks_msec() - started
				if not bool(row.get("finished", false)):
					failures += 1
				_write(row)
				print(
					(
						"[RivalFairness] %s %s %s seed=%d place=%d time=%.2f gap=%.2f resets=%d hits=%d"
						% [
							track,
							level,
							scenario,
							race_seed,
							int(row.place),
							float(row.player_time),
							float(row.gap_to_winner),
							int(row.resets),
							int(row.hits_taken)
						]
					)
				)
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	print(
		(
			"[RivalFairness] DONE %s races=%d unfinished=%d"
			% [track, levels.size() * scenarios.size() * seeds.size(), failures]
		)
	)
	quit(0 if failures == 0 else 1)


func _write(row: Dictionary) -> void:
	if out_path.is_empty():
		return
	var file := FileAccess.open(out_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("[RivalFairness] cannot write %s" % out_path)
		return
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()


## Kurvigste Stelle (rad/m) einer Runde zwischen 30 und 70 Prozent, für den Fehler.
func _sharpest_bend(length: float) -> float:
	var best: float = length * 0.4
	var best_bend: float = 0.0
	var at: float = length * 0.3
	while at < length * 0.7:
		var bend: float = absf(RACECRAFT.curvature(game.world, at))
		if bend > best_bend:
			best_bend = bend
			best = at
		at += 5.0
	return best


## Engste Stelle einer Runde (kleinste Fahrbahnbreite) zwischen 15 und 85 Prozent.
## Bei überall gleicher Breite: die kurvigste Stelle.
func _narrowest(length: float) -> Dictionary:
	var best: float = length * 0.5
	var width: float = INF
	var widest: float = 0.0
	var at: float = length * 0.15
	while at < length * 0.85:
		var here: float = game._road_width_at(at)
		widest = maxf(widest, here)
		if here < width - 0.01:
			width = here
			best = at
		at += 5.0
	if widest - width < 0.2:
		return {
			"at": _sharpest_bend(length), "width": width, "kind": "kurve (Breite überall gleich)"
		}
	return {"at": best, "width": width, "kind": "engste Fahrbahn"}


func _race(level: String, scenario: String, race_seed: int) -> Dictionary:
	game.race_seed = race_seed
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": level}
	)
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.gas_held = true
	var length: float = float(game.track_length)
	var total: float = length * float(game.TOTAL_LAPS)
	var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, level)
	var mistake_at: float = _sharpest_bend(length) - 28.0
	var narrow: Dictionary = _narrowest(length)
	var halt_at: float = float(narrow.at) - 30.0
	var buffer: Array[float] = []
	var axis: float = 0.0
	var t: float = 0.0
	var frames: int = 0
	var marks_player: Array[float] = []
	var marks_rivals: Array = []
	var rival_done: Array[float] = []
	for _i in range(game.opponents.size()):
		marks_rivals.append([] as Array[float])
		rival_done.append(-1.0)
	var events: Array[Dictionary] = []
	var phase: String = "drive"
	var phase_time: float = 0.0
	var mistake_outcome: Dictionary = {}
	var halt_outcome: Dictionary = {}
	var item_hold: float = 0.0
	var last_reset: int = 0
	var last_walls: int = 0
	var last_spin: float = 0.0
	var last_hit: float = 0.0
	var last_contact: float = 0.0
	var last_boost: Array[float] = []
	var drift_boosts: Array[int] = []
	var item_boosts: Array[int] = []
	var band_sum: Array[float] = []
	var band_active: Array[float] = []
	var band_push_time: Array[float] = []
	var band_push_peak: Array[float] = []
	for _i in range(game.opponents.size()):
		last_boost.append(0.0)
		drift_boosts.append(0)
		item_boosts.append(0)
		band_sum.append(0.0)
		band_active.append(0.0)
		band_push_time.append(0.0)
		band_push_peak.append(1.0)
	var catch_sum: float = 0.0
	var catch_active: float = 0.0
	var speed_straight: Array[float] = [0.0, 0.0]
	var speed_bend: Array[float] = [0.0, 0.0]
	var rival_straight: Array[float] = [0.0, 0.0]
	var rival_curve: Array[float] = [0.0, 0.0]
	var places: Array[int] = []
	var progress_trace: Array = []
	var overtakes: Array[Dictionary] = []
	var last_place: int = 6
	while not game.finished and frames < MAX_FRAMES and t < max_seconds:
		var progress: float = float(game.distance)
		var lap_m: float = fposmod(progress, length)
		var lap: int = int(progress / length)
		var road_d: float = float(game.previous_road_distance)
		var speed: float = float(game.speed)
		# --- Kind-Fahrer -------------------------------------------------------------
		var look: float = clampf(absf(speed) * look_k, 7.0, 26.0)
		var wander: float = sin(t * 0.23 + 0.7) * wander_m
		var aim: Vector3 = game.world.position_at(road_d + look, wander)
		var to_aim: Vector3 = aim - game.player.position
		var wanted: float = atan2(-to_aim.x, -to_aim.z)
		var command: float = clampf(
			-angle_difference(game.player_heading, wanted) * gain + sin(t * 1.7) * 0.06, -1.0, 1.0
		)
		buffer.append(command)
		var delayed: float = buffer[0] if buffer.size() > reaction_frames else 0.0
		if buffer.size() > reaction_frames:
			buffer.pop_front()
		var bend: float = absf(RACECRAFT.curvature(game.world, road_d))
		var capacity: float = 1.42 * float(game._factor("turn")) * 2.0
		var brake: float = 0.0
		if speed > 14.0 and bend * speed > capacity * 0.8:
			brake = 0.35
		var gas: bool = true
		match phase:
			"drive":
				if (
					scenario == "mistake"
					and lap == 0
					and lap_m >= mistake_at
					and mistake_outcome.is_empty()
				):
					phase = "mistake"
					phase_time = 0.0
					mistake_outcome = {
						"lap_m": snappedf(lap_m, 0.1),
						"bend_at": snappedf(mistake_at + 28.0, 0.1),
						"speed_before": snappedf(speed, 0.01),
						"walls_before": int(game.wall_contacts),
						"resets_before": int(game.reset_count),
						"t": snappedf(t, 0.01)
					}
				elif (
					scenario == "halt" and lap == 0 and lap_m >= halt_at and halt_outcome.is_empty()
				):
					phase = "halt_brake"
					phase_time = 0.0
					halt_outcome = {
						"lap_m": snappedf(lap_m, 0.1),
						"narrow_at": snappedf(float(narrow.at), 0.1),
						"narrow_width": snappedf(float(narrow.width), 0.01),
						"kind": narrow.kind,
						"t": snappedf(t, 0.01),
						"resets_before": int(game.reset_count),
						"place_before": int(game._place())
					}
			"mistake":
				delayed = 0.0
				axis = 0.0
				var off: bool = absf(float(game.lane)) > game._road_width_at(road_d) * 0.5
				if (
					off
					or int(game.wall_contacts) > int(mistake_outcome.walls_before)
					or phase_time > 2.0
				):
					mistake_outcome["trigger"] = (
						"rand" if off else "planke" if phase_time <= 2.0 else "2s gerade"
					)
					mistake_outcome["straight_s"] = snappedf(phase_time, 0.01)
					phase = "mistake_recover"
					phase_time = 0.0
			"mistake_recover":
				# Kurz erschrocken: 0,4 s noch gerade, dann wie vorher weiterfahren.
				if phase_time < 0.4:
					delayed = 0.0
				else:
					phase = "drive"
					mistake_outcome["recovered_t"] = snappedf(t, 0.01)
			"halt_brake":
				gas = false
				brake = 1.0 if speed > 1.0 else 0.0
				if speed <= 1.0:
					phase = "halt_wait"
					phase_time = 0.0
					halt_outcome["stopped_lap_m"] = snappedf(
						fposmod(float(game.distance), length), 0.1
					)
			"halt_wait":
				gas = false
				brake = 0.0
				if phase_time >= 2.0:
					phase = "drive"
					halt_outcome["wait_s"] = snappedf(phase_time, 0.01)
					halt_outcome["moved_while_waiting_m"] = snappedf(
						fposmod(float(game.distance), length) - float(halt_outcome.stopped_lap_m),
						0.01
					)
					halt_outcome["place_after_wait"] = int(game._place())
					halt_outcome["resets_during"] = (
						int(game.reset_count) - int(halt_outcome.resets_before)
					)
		phase_time += STEP
		if phase not in ["mistake"]:
			axis = move_toward(axis, delayed, THUMB_RATE * STEP)
		game.steering = axis
		game.brake = brake
		game.gas_held = gas
		if scenario == "centre":
			# Genau der Mittellinienfahrer aus kart_courses_driving_regression.gd (Auto-Gas).
			var centre: Vector3 = game.world.position_at(road_d + 9.0, 0)
			var centre_dir: Vector3 = centre - game.player.position
			game.steering = clampf(
				-angle_difference(game.player_heading, atan2(-centre_dir.x, -centre_dir.z)) * 2.3,
				-1,
				1
			)
			game.brake = 0.0
			game.gas_held = false
			game.auto_gas = true
		# Items: zwei Sekunden nach dem Einsammeln drücken (Rakete: zielen + feuern).
		if not str(game.item).is_empty() and scenario != "centre":
			item_hold += STEP
			if item_hold >= 2.0 and int(roundf(item_hold * 60.0)) % 30 == 0:
				game._use_item()
		else:
			item_hold = 0.0
		# --- Telemetrie --------------------------------------------------------------
		var leader: float = game._leader_progress()
		var catch_factor: float = RACE_RULES.player_catch_up(leader - progress, level)
		catch_sum += catch_factor * STEP
		if catch_factor > 1.0001:
			catch_active += STEP
		var straight: bool = bend < 0.004
		if straight:
			speed_straight[0] += speed * STEP
			speed_straight[1] += STEP
		else:
			speed_bend[0] += speed * STEP
			speed_bend[1] += STEP
		for i in range(game.opponents.size()):
			var lead: float = float(game.opponent_distances[i]) - progress
			var band: float = RACE_RULES.rival_rubber_band(lead, level)
			band_sum[i] += band * STEP
			if absf(band - 1.0) > 0.0001:
				band_active[i] += STEP
			if band > 1.0001:
				band_push_time[i] += STEP
				band_push_peak[i] = maxf(band_push_peak[i], band)
			var boost: float = float(game.opponent_boost_times[i])
			if boost > last_boost[i] + 0.05:
				if boost > 2.0:
					item_boosts[i] += 1
				else:
					drift_boosts[i] += 1
			last_boost[i] = boost
			var rival_road: float = fposmod(float(game.opponent_distances[i]), length)
			var rival_bend: float = absf(RACECRAFT.curvature(game.world, rival_road))
			var rival_speed: float = absf(float(game.opponents[i].motion_speed))
			if rival_bend < 0.004:
				rival_straight[0] += rival_speed * STEP
				rival_straight[1] += STEP
			else:
				rival_curve[0] += rival_speed * STEP
				rival_curve[1] += STEP
		game._physics_process(STEP)
		t += STEP
		frames += 1
		var now_progress: float = float(game.distance)
		while marks_player.size() * MARK <= now_progress and marks_player.size() * MARK <= total:
			marks_player.append(t)
		for i in range(game.opponents.size()):
			var rival_marks: Array = marks_rivals[i]
			var rival_progress: float = float(game.opponent_distances[i])
			while (
				rival_marks.size() * MARK <= rival_progress and rival_marks.size() * MARK <= total
			):
				rival_marks.append(t)
			if rival_done[i] < 0.0 and rival_progress >= total:
				rival_done[i] = t
		var at_m: float = snappedf(fposmod(now_progress, length), 0.1)
		if int(game.reset_count) > last_reset:
			events.append(
				{
					"t": snappedf(t, 0.01),
					"race_m": snappedf(now_progress, 0.1),
					"lap_m": at_m,
					"kind": "ruecksetzer",
					"phase": phase
				}
			)
		if int(game.wall_contacts) > last_walls:
			events.append(
				{
					"t": snappedf(t, 0.01),
					"race_m": snappedf(now_progress, 0.1),
					"lap_m": at_m,
					"kind": "planke",
					"phase": phase
				}
			)
		if float(game.player_spin_time) > last_spin + 0.05:
			events.append(
				{
					"t": snappedf(t, 0.01),
					"race_m": snappedf(now_progress, 0.1),
					"lap_m": at_m,
					"kind": "dreher",
					"phase": phase
				}
			)
		elif float(game.hit_timer) > last_hit + 0.05:
			var hit_kind: String = "treffer"
			if float(game.rival_contact_timer) > last_contact + 0.05:
				hit_kind = "rempler"
			events.append(
				{
					"t": snappedf(t, 0.01),
					"race_m": snappedf(now_progress, 0.1),
					"lap_m": at_m,
					"kind": hit_kind,
					"phase": phase
				}
			)
		elif float(game.rival_contact_timer) > last_contact + 0.05:
			events.append(
				{
					"t": snappedf(t, 0.01),
					"race_m": snappedf(now_progress, 0.1),
					"lap_m": at_m,
					"kind": "beruehrung_schild",
					"phase": phase
				}
			)
		last_reset = int(game.reset_count)
		last_walls = int(game.wall_contacts)
		last_spin = float(game.player_spin_time)
		last_hit = float(game.hit_timer)
		last_contact = float(game.rival_contact_timer)
		var place_now: int = int(game._place())
		if frames % 30 == 0:
			places.append(place_now)
		if diag_rival >= 0 and t >= diag_from and t <= diag_to and frames % 6 == 0:
			var r = game.opponents[diag_rival]
			var flight = (
				r.get_meta(&"lumo_ballistic_flight")
				if r.has_meta(&"lumo_ballistic_flight")
				else null
			)
			var loop = (
				r.get_meta(&"lumo_physical_loop") if r.has_meta(&"lumo_physical_loop") else null
			)
			print(
				(
					(
						"[Diag] t=%.2f prog=%.1f lap_m=%.1f pos=%s v=%.1f flight=%s loop=%s"
						+ " boost=%.2f stun=%.2f lane=%.2f"
					)
					% [
						t,
						float(game.opponent_distances[diag_rival]),
						fposmod(float(game.opponent_distances[diag_rival]), length),
						r.position.snapped(Vector3.ONE * 0.1),
						float(r.motion_speed),
						str(flight.active) if flight != null else "-",
						str(loop.active) if loop != null else "-",
						float(game.opponent_boost_times[diag_rival]),
						float(game.opponent_stuns[diag_rival]),
						float(game.opponent_lanes[diag_rival])
					]
				)
			)
		if frames % 60 == 0:
			var sample: Array = [snappedf(t, 0.1), snappedf(now_progress, 0.1)]
			for i in range(game.opponents.size()):
				sample.append(snappedf(float(game.opponent_distances[i]), 0.1))
			progress_trace.append(sample)
		if place_now != last_place and frames > 60:
			overtakes.append(
				{
					"t": snappedf(t, 0.01),
					"race_m": snappedf(now_progress, 0.1),
					"from": last_place,
					"to": place_now
				}
			)
		last_place = place_now
		if frames % 240 == 0:
			await process_frame
	var player_time: float = t if game.finished else -1.0
	var place: int = int(game.result_payload.get("place", game._place()))
	# Nach dem Ziel des Kindes fahren die Rivalen weiter, bis alle im Ziel sind.
	var post: float = 0.0
	var post_frames: int = 0
	while game.finished and post < POST_FINISH_LIMIT and rival_done.has(-1.0):
		game.elapsed += STEP
		game._drive_opponents(STEP)
		t += STEP
		post += STEP
		post_frames += 1
		for i in range(game.opponents.size()):
			var rival_marks: Array = marks_rivals[i]
			var rival_progress: float = float(game.opponent_distances[i])
			while (
				rival_marks.size() * MARK <= rival_progress and rival_marks.size() * MARK <= total
			):
				rival_marks.append(t)
			if rival_done[i] < 0.0 and rival_progress >= total:
				rival_done[i] = t
		if post_frames % 240 == 0:
			await process_frame
	var winner_rival: int = -1
	var winner_time: float = INF
	var second_time: float = INF
	for i in range(rival_done.size()):
		var value: float = rival_done[i]
		if value >= 0.0 and value < winner_time:
			second_time = winner_time
			winner_time = value
			winner_rival = i
		elif value >= 0.0 and value < second_time:
			second_time = value
	# Rückstand zum Sieger (positiv) bzw. Vorsprung vor dem besten Rivalen (negativ).
	var gap: float = player_time - winner_time if winner_time < INF else -999.0
	# Abstandsverlauf zum schnellsten Rivalen alle 100 m Rennstrecke.
	var curve: Array = []
	var losses: Array[Dictionary] = []
	if winner_rival >= 0:
		var best_marks: Array = marks_rivals[winner_rival]
		var previous_gap: float = 0.0
		var step_marks: int = int(100.0 / MARK)
		var index: int = step_marks
		while index < mini(marks_player.size(), best_marks.size()):
			var gap_here: float = marks_player[index] - float(best_marks[index])
			curve.append([index * MARK, snappedf(gap_here, 0.01)])
			losses.append(
				{
					"race_m": index * MARK,
					"lap_m": snappedf(fposmod(index * MARK, length), 1.0),
					"lap": int(index * MARK / length) + 1,
					"delta_s": snappedf(gap_here - previous_gap, 0.01)
				}
			)
			previous_gap = gap_here
			index += step_marks
	var top_losses: Array[Dictionary] = losses.duplicate()
	top_losses.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a.delta_s) > float(b.delta_s)
	)
	top_losses = top_losses.slice(0, 4)
	var hits: int = 0
	for event in events:
		if str(event.kind) in ["dreher", "treffer", "rempler"]:
			hits += 1
	var rival_times: Array = []
	for value in rival_done:
		rival_times.append(snappedf(value, 0.01))
	var band_means: Array = []
	var band_shares: Array = []
	var push_shares: Array = []
	var push_peaks: Array = []
	for i in range(band_sum.size()):
		band_means.append(snappedf(band_sum[i] / maxf(player_time, 0.01), 0.0001))
		band_shares.append(snappedf(band_active[i] / maxf(player_time, 0.01), 0.001))
		push_shares.append(snappedf(band_push_time[i] / maxf(player_time, 0.01), 0.001))
		push_peaks.append(snappedf(band_push_peak[i], 0.0001))
	return {
		"label": label,
		"driver":
		{"gain": gain, "reaction_frames": reaction_frames, "look_k": look_k, "wander_m": wander_m},
		"track": track,
		"track_length_m": snappedf(length, 0.1),
		"level": level,
		"speed_factor": float(rules.speed),
		"rival_factor": float(rules.rival),
		"scenario": scenario,
		"seed": race_seed,
		"finished": player_time > 0.0,
		"player_time": snappedf(player_time, 0.01),
		"place": place,
		"rival_times": rival_times,
		"winner_rival": winner_rival,
		"winner_kart": str(game.opponents[winner_rival].kart_style) if winner_rival >= 0 else "",
		"gap_to_winner": snappedf(gap, 0.01),
		"second_rival_time": snappedf(second_time, 0.01) if second_time < INF else -1.0,
		"gap_curve": curve,
		"top_losses": top_losses,
		"events": events,
		"hits_taken": hits,
		"resets": int(game.reset_count),
		"wall_contacts": int(game.wall_contacts),
		"mistake": mistake_outcome,
		"halt": halt_outcome,
		"player_mean_speed_straight":
		snappedf(speed_straight[0] / maxf(speed_straight[1], 0.01), 0.01),
		"player_mean_speed_bend": snappedf(speed_bend[0] / maxf(speed_bend[1], 0.01), 0.01),
		"rival_mean_speed_straight":
		snappedf(rival_straight[0] / maxf(rival_straight[1], 0.01), 0.01),
		"rival_mean_speed_bend": snappedf(rival_curve[0] / maxf(rival_curve[1], 0.01), 0.01),
		"player_catch_up_mean": snappedf(catch_sum / maxf(player_time, 0.01), 0.0001),
		"player_catch_up_share": snappedf(catch_active / maxf(player_time, 0.01), 0.001),
		"rival_band_mean": band_means,
		"rival_band_share": band_shares,
		"rival_push_share": push_shares,
		"rival_push_peak": push_peaks,
		"rival_drift_boosts": drift_boosts,
		"rival_item_boosts": item_boosts,
		"gameplay_stats": game.gameplay_stats.duplicate(true),
		"overtakes": overtakes,
		"place_trace_0_5s": places,
		"progress_trace_1s": progress_trace,
		"post_finish_s": snappedf(post, 0.01),
		"player_kart_top_speed":
		snappedf(
			preload("res://scripts/games/kart_powertrain.gd").top_speed(
				game.kart_factors, float(rules.speed)
			),
			0.01
		),
	}
