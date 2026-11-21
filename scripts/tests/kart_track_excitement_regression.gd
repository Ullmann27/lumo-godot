extends SceneTree
## Strecken 2.0: Mindestwerte aus dem Streckenprofil (kart_track_profile.gd) je umgebauter
## Strecke, gemessen durch die echte Rennphysik.
##   - zwei Runden ohne Rücksetzer, längste Phase ohne Höhepunkt ≤ Grenze, genug Flüge und
##     Entscheidungen (Spalt-Schanze mit sicherer Umfahrung);
##   - jede Spalt-Schanze: volles Tempo auf der mutigen Linie fliegt sicher hinüber, zu
##     langsam fällt man und die Wolke setzt hinter dem Spalt ab, die sichere Linie fliegt nie
##     und fällt nie; Mindesttempo und Reserve wie im Kopf von kart_track_thrills.gd gerechnet;
##   - das Rivalenfeld fährt bei 0,86 / 0,96 / 1,00 zwei Runden ohne Hängenbleiben.
## Aufruf: godot --headless --path . --script
##   res://scripts/tests/kart_track_excitement_regression.gd -- [track_id ...] [quick]
const PROFILE = preload("res://scripts/tests/helpers/kart_track_profile.gd")
const THRILLS = preload("res://scripts/games/kart_track_thrills.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP: float = 1.0 / 60.0
## Langsamstes Kart (boru_rally) Spitze, Container-Messung kart_passage_survey 19.11.2026.
const SLOWEST_TOP_M_S: float = 46.5
## Grenzwerte je umgebauter Strecke (vorher gemessen → nachher Mindestwert).
const LIMITS: Dictionary = {
	"zauberwald": {"gap": 8.0, "decisions": 1, "takeoffs": 10},
	"bergwelt": {"gap": 8.0, "decisions": 2, "takeoffs": 10},
	"holo_city": {"gap": 8.0, "decisions": 2, "takeoffs": 10},
	"crystal_canyon": {"gap": 8.0, "decisions": 1, "takeoffs": 10},
	"jungle_temple": {"gap": 8.0, "decisions": 2, "takeoffs": 10},
	"candy_cloud": {"gap": 8.0, "decisions": 2, "takeoffs": 8},
	"volcano_night": {"gap": 8.0, "decisions": 4, "takeoffs": 10},
	"winter_sprint": {"gap": 8.0, "decisions": 2, "takeoffs": 10},
	"galaxy_ringway": {"gap": 8.0, "decisions": 2, "takeoffs": 8},
	"desert_drift": {"gap": 8.0, "decisions": 1, "takeoffs": 10},
	"learning_lab": {"gap": 8.0, "decisions": 2, "takeoffs": 8},
	"jungle_emerald_3600": {"gap": 8.5, "decisions": 2, "takeoffs": 14},
}
var game
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error("[KartExcitement] FAIL " + text)


func _start(track: String, difficulty: String) -> void:
	game.race_seed = 20261119
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": difficulty}
	)
	await process_frame
	game.countdown = 0
	game.racing = true
	game.auto_gas = true


func _place(at: float, lane: float, speed: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.checkpoint_index = int(at / (game.track_length / 8.0))
	game.player.transform = game.world.reset_transform(at, lane)
	game.player_heading = game._heading(at)
	game.lane = lane
	game.airborne = false
	game.vertical_speed = 0.0
	game.speed = speed
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	)
	for i in range(game.opponents.size()):
		game.opponent_distances[i] = at - 600.0


## Drives along a fixed lane until `until`; returns what happened.
func _ride(lane: float, until: float, max_speed: float) -> Dictionary:
	var took_off: bool = false
	var take_off_d: float = -1.0
	var landing_d: float = -1.0
	var resets_before: int = game.reset_count
	var falls_before: int = game.gap_falls
	var guard: int = 0
	var was_air: bool = false
	while fposmod(game.previous_road_distance, game.track_length) < until and guard < 1200:
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, lane)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(
			-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
		)
		game.brake = 1.0 if game.speed > max_speed else 0.0
		game._physics_process(STEP)
		if game.airborne and not was_air:
			took_off = true
			take_off_d = fposmod(game.previous_road_distance, game.track_length)
		if was_air and not game.airborne:
			landing_d = fposmod(game.previous_road_distance, game.track_length)
		was_air = game.airborne
		guard += 1
	return {
		"took_off": took_off,
		"take_off_d": take_off_d,
		"landing_d": landing_d,
		"resets": game.reset_count - resets_before,
		"falls": game.gap_falls - falls_before,
	}


func _leaps(track: String) -> void:
	for entry in THRILLS.of(game.world):
		if str(entry.kind) != "leap":
			continue
		var id: String = "%s/%s" % [track, entry.id]
		# Gerätefund 19.11.: keine Sturz-Stelle in den ersten 350 m; Rettung der Wolke
		# (gap_exit) im selben Checkpoint-Abschnitt wie der Sturz.
		var section: float = game.track_length / 8.0
		var rescue: float = fposmod(
			game.world.gap_exit_distance(float(entry.take_off)), game.track_length
		)
		_check(float(entry.take_off) >= 350.0, "%s take-off %.0f m >= 350 m" % [id, entry.take_off])
		_check(
			floori((float(entry.take_off) - 0.5) / section) == floori((rescue + 1.0) / section),
			(
				"%s fall %.0f m and rescue %.0f m in one checkpoint section (%.0f m)"
				% [id, entry.take_off, rescue, section]
			)
		)
		var need: float = (
			float(entry.gap_end)
			- float(entry.take_off)
			+ THRILLS.KART_HALF_LENGTH
			+ THRILLS.LANDING_RESERVE_M
		)
		var minimum: float = float(entry.min_speed)
		_check(
			minimum >= 18.0 and minimum <= 30.0, "%s min speed %.1f m/s in 18..30" % [id, minimum]
		)
		_check(
			THRILLS.flight_distance(entry, SLOWEST_TOP_M_S) >= need * 1.8,
			(
				"%s slowest kart at top speed flies %.1f m >= 1.8 x %.1f m"
				% [id, THRILLS.flight_distance(entry, SLOWEST_TOP_M_S), need]
			)
		)
		var side: float = float(entry.side)
		var brave: float = side * (float(entry.inner) + float(entry.outer)) * 0.5
		var after: float = float(entry.gap_end) + 30.0
		# 1. Full pace on the brave line: real take-off, landing beyond the far edge.
		_place(float(entry.start) - 70.0, brave, 44.0)
		var fast: Dictionary = _ride(brave, after, 99.0)
		_check(
			fast.took_off and fast.resets == 0 and fast.falls == 0,
			"%s full pace jumps without a fall %s" % [id, fast]
		)
		_check(
			float(fast.landing_d) >= float(entry.gap_end) + 1.0,
			"%s lands behind the gap (%.1f > %.1f)" % [id, fast.landing_d, entry.gap_end]
		)
		# 2. Too slow on the brave line: falls, the cloud sets the kart down behind the gap.
		_place(float(entry.start) - 70.0, brave, 14.0)
		var slow: Dictionary = _ride(brave, after, 14.0)
		_check(slow.falls == 1, "%s too slow (14 m/s) falls once into the gap %s" % [id, slow])
		_check(
			fposmod(game.previous_road_distance, game.track_length) >= float(entry.gap_end),
			"%s rescue sets down behind the gap" % id
		)
		# 3. Safe line at full pace: never flies here, never falls.
		_place(float(entry.start) - 70.0, -side * 2.0, 44.0)
		var safe: Dictionary = _ride(-side * 2.0, after, 99.0)
		var leap_flight: bool = (
			safe.took_off
			and float(safe.take_off_d) >= float(entry.start)
			and float(safe.take_off_d) <= float(entry.gap_end)
		)
		_check(
			not leap_flight and safe.resets == 0 and safe.falls == 0,
			"%s safe line rolls past %s" % [id, safe]
		)
		# 4. Just above the computed minimum: clears.
		_place(float(entry.start) - 70.0, brave, minimum + 1.5)
		var edge: Dictionary = _ride(brave, after, minimum + 1.5)
		_check(
			edge.took_off and edge.falls == 0,
			"%s at %.1f m/s (minimum + 1.5) clears %s" % [id, minimum + 1.5, edge]
		)


func _run() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var quick: bool = args.has("quick")
	args.erase("quick")
	var tracks: Array = args if not args.is_empty() else LIMITS.keys()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	if is_instance_valid(game.kart_audio):
		game.kart_audio.set_muted(true)
	for track in tracks:
		var limit: Dictionary = LIMITS.get(str(track), {})
		_check(not limit.is_empty(), "%s has excitement limits" % track)
		await _start(str(track), "flott")
		var profile: Dictionary = await PROFILE.drive(self, game)
		_check(
			profile.finished and profile.resets == 0,
			"%s two laps, no reset %s" % [track, [profile.finished, profile.resets]]
		)
		_check(
			float(profile.highlight_gap_s) <= float(limit.get("gap", 0.0)),
			(
				"%s longest stretch without highlight %.1f s <= %.1f s (at %.0f m)"
				% [track, profile.highlight_gap_s, limit.get("gap", 0.0), profile.highlight_gap_at]
			)
		)
		_check(
			int(profile.decisions) >= int(limit.get("decisions", 0)),
			"%s decisions %d >= %d" % [track, profile.decisions, limit.get("decisions", 0)]
		)
		_check(
			int(profile.takeoffs) >= int(limit.get("takeoffs", 0)),
			(
				"%s take-offs in two laps %d >= %d"
				% [track, profile.takeoffs, limit.get("takeoffs", 0)]
			)
		)
		print(
			(
				"[KartExcitement] %s gap %.1fs dec %d takeoffs %d air %.1fs rival_stall %.1fs rescues %d"
				% [
					track,
					profile.highlight_gap_s,
					profile.decisions,
					profile.takeoffs,
					profile.air_s,
					profile.rival_stall_s,
					profile.rival_rescues
				]
			)
		)
		await _start(str(track), "flott")
		_leaps(str(track))
		var difficulties: Array = ["flott"] if quick else ["gemuetlich", "flott", "pro"]
		for difficulty in difficulties:
			await _start(str(track), difficulty)
			var field: Dictionary = await PROFILE.drive(self, game)
			_check(
				float(field.rival_stall_s) <= 2.0,
				"%s %s rivals never stall (%.1f s)" % [track, difficulty, field.rival_stall_s]
			)
			for i in range(field.rival_progress.size()):
				_check(
					float(field.rival_progress[i]) >= float(game.track_length) * 1.2,
					(
						"%s %s rival %d drives on (%.0f m)"
						% [track, difficulty, i, field.rival_progress[i]]
					)
				)
	game.abandoned = true
	await TEARDOWN.release_scene(self, game, "[KartExcitement]")
	if failures.is_empty():
		print("[KartExcitement] PASS: %d checks on %d tracks" % [checks, tracks.size()])
		quit(0)
	else:
		print("[KartExcitement] FAIL: %d of %d checks" % [failures.size(), checks])
		for failure in failures:
			print("  - ", failure)
		quit(1)
