extends RefCounted
## Rivalen an LUMO-Passagen (aus kart_track_passage_regression ausgelagert): Einreihen hinter
## dem wartenden Kind an der Brücke und das KI-Feld über zwei Runden, je Schwierigkeitsstufe.
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const STEP: float = 1.0 / 60.0


## A rival arrives at full race pace while the child waits on the line before the deck:
## it brakes, waits behind the child (never pushes), pulls away after the child and crosses
## the deck at the bridge speed. Also the child waiting aside does not hold the rival.
static func bridge_queue(test, track: String, entry: Dictionary, difficulty: String) -> void:
	for aside in [false, true]:
		await test._start(track, difficulty, "comet", "race")
		test.hold_rivals_from = 1
		var wait_at: float = float(entry.deck_start) - 7.0
		var child_lane: float = -5.0 if aside else 0.0
		var start_at: float = float(entry.deck_start) - 130.0
		test.game.opponent_distances[0] = start_at
		test.game.opponents[0].position = test.game.world.position_at(start_at, 0.0)
		test.game.opponent_headings[0] = test.game._heading(start_at)
		var rules: Dictionary = test.game.CATALOG.entry(test.game.CATALOG.DIFFICULTIES, difficulty)
		var cruise: float = test.game.RIVAL_RACECRAFT.cruise_speed(
			test.game.opponents[0].kart_style, rules
		)
		test.game.opponents[0].set_motion(cruise, 0.0, false, false)
		test._place(wait_at, child_lane, 0.0)
		var hold: float = 7.0
		var t: float = 0.0
		var min_gap: float = INF
		var rival_stopped: bool = false
		var stop_gap: float = -1.0
		var child_shoved: float = 0.0
		var deck_speed: float = 0.0
		var rival_crossed: bool = false
		var child_first: bool = true
		while t < 30.0 and not rival_crossed:
			if t < hold:
				# Child waits with the brake held, exactly where it stopped.
				test.game.brake = 1.0
				var before: float = test.game.distance
				test._tick()
				child_shoved = maxf(child_shoved, absf(test.game.distance - before))
				child_shoved = maxf(child_shoved, absf(test.game.lane - child_lane))
			else:
				test.game.brake = 0.0
				test._touch_steer(child_lane if aside else 0.0)
				test._tick()
			t += STEP
			var rival_local: float = fposmod(
				test.game.opponent_distances[0], test.game.track_length
			)
			var speed: float = absf(test.game.opponents[0].motion_speed)
			# Nose-to-nose gap to the child while the rival is behind it on the approach.
			var child_local: float = test._local()
			if not aside and rival_local < child_local and child_local < float(entry.deck_end):
				min_gap = minf(min_gap, child_local - rival_local)
			if not aside and t < hold and speed < 0.3 and not rival_stopped:
				rival_stopped = true
				stop_gap = wait_at - rival_local
			if rival_local >= float(entry.deck_start) and rival_local <= float(entry.deck_end):
				deck_speed = maxf(deck_speed, speed)
				if not aside and test._local() < float(entry.deck_start):
					child_first = false
			rival_crossed = (
				rival_local > float(entry.deck_end) + 10.0
				and rival_local < float(entry.deck_end) + 80.0
			)
		test.game.brake = 0.0
		var tag: String = "%s %s %s" % [entry.id, difficulty, "aside" if aside else "on the line"]
		test._check(rival_crossed, "%s: rival crosses the deck (%.0f s)" % [tag, t])
		test._check(
			deck_speed <= PASSAGES.RIVAL_BRIDGE_SPEED * 1.05 + 0.5,
			"%s: rival brakes for the deck (%.1f m/s)" % [tag, deck_speed]
		)
		test._check(
			child_shoved < 0.3, "%s: the waiting child is not pushed (%.2f m)" % [tag, child_shoved]
		)
		if aside:
			test._check(
				t < hold, "%s: a child waiting aside does not hold the rival (%.1f s)" % [tag, t]
			)
		else:
			test._check(rival_stopped, "%s: rival stops behind the waiting child" % tag)
			test._check(min_gap >= 3.4, "%s: rival keeps a kart length (%.1f m)" % [tag, min_gap])
			test._check(child_first, "%s: the child goes first" % tag)
		(
			test
			. _note(
				(
					(
						"%s: KI %.1f m/s Anfahrt, hält %.1f m hinter dem Kind, kleinster Abstand %.1f m,"
						+ " max. %.1f m/s auf dem Deck, durch nach %.1f s"
					)
					% [tag, cruise, stop_gap, min_gap, deck_speed, t]
				)
			)
		)
		test._park_rival(0, -600.0)
		test.hold_rivals_from = 99


static func field(test, track: String, difficulty: String = "flott") -> void:
	await test._start(track, difficulty, "comet", "race")
	for i in range(test.game.opponents.size()):
		test.game.opponent_distances[i] = -4.0 - float(i) * 3.0
		test.game.opponents[i].position = test.game.world.position_at(
			fposmod(test.game.opponent_distances[i], test.game.track_length), -2.8 + float(i) * 1.35
		)
		test.game.opponent_headings[i] = test.game._heading(0.0)
	var target: float = test.game.track_length * 2.0
	var stationary: Array[float] = []
	var worst_stationary: Array[float] = []
	var last: Array[float] = []
	var waits: int = 0
	var deck_speed: float = 0.0
	var vine_hits: int = 0
	var hits_seen: Array[bool] = [false, false, false, false, false]
	for i in range(test.game.opponents.size()):
		stationary.append(0.0)
		worst_stationary.append(0.0)
		last.append(test.game.opponent_distances[i])
	var t: float = 0.0
	var limit: float = target / 14.0 + 60.0
	var all_done: bool = false
	while t < limit and not all_done:
		# The child waits safely aside at the start so the field races alone.
		test._place(30.0, -4.6, 0.0)
		test._tick()
		t += STEP
		all_done = true
		for i in range(test.game.opponents.size()):
			var d: float = test.game.opponent_distances[i]
			if d < target:
				all_done = false
			var moved: float = d - last[i]
			last[i] = d
			stationary[i] = stationary[i] + STEP if moved < 0.02 else 0.0
			worst_stationary[i] = maxf(worst_stationary[i], stationary[i])
			if stationary[i] > 0.4 and stationary[i] < 0.4 + STEP * 1.5:
				waits += 1
			# The race itself judges walls and gaps from the sampled road position.
			var local: float = float(
				(
					test
					. game
					. world
					. sample_road(
						test.game.opponents[i].position, fposmod(d, test.game.track_length)
					)
					. distance
				)
			)
			var stunned: bool = test.game.opponent_stuns[i] > 0.7
			if stunned and not hits_seen[i]:
				vine_hits += 1
			hits_seen[i] = stunned
			if not PASSAGES.bridge_at(test.game.world, local).is_empty():
				deck_speed = maxf(deck_speed, absf(test.game.opponents[i].motion_speed))
	var slowest: float = INF
	var longest_halt: float = 0.0
	for i in range(test.game.opponents.size()):
		slowest = minf(slowest, test.game.opponent_distances[i])
		longest_halt = maxf(longest_halt, worst_stationary[i])
	test._check(
		all_done,
		(
			"%s %s: all rivals finish two laps (slowest %.0f of %.0f m in %.0f s)"
			% [track, difficulty, slowest, target, t]
		)
	)
	test._check(
		longest_halt < 9.0,
		(
			"%s %s: no rival stands still longer than a swing cycle (%.1f s)"
			% [track, difficulty, longest_halt]
		)
	)
	var has_bridge: bool = false
	var has_swing: bool = false
	for entry in PASSAGES.of(test.game.world):
		has_bridge = has_bridge or str(entry.kind) == "bridge"
		has_swing = has_swing or str(entry.kind) in ["swing", "gate"]
	if has_bridge:
		test._check(
			deck_speed <= PASSAGES.RIVAL_BRIDGE_SPEED * 1.05 + 0.5,
			"%s %s: rivals brake for the deck (%.1f m/s)" % [track, difficulty, deck_speed]
		)
	if has_swing:
		test._check(
			vine_hits == 0, "%s %s: no rival runs into Kiri (%d)" % [track, difficulty, vine_hits]
		)
	test._note(
		(
			(
				"%s %s: KI-Feld 2 Runden in %.0f s, längster Halt %.1f s, Halte %d, max."
				+ " Tempo auf dem Deck %.1f m/s, Kiri-Treffer %d"
			)
			% [track, difficulty, t, longest_halt, waits, deck_speed, vine_hits]
		)
	)


## A rival in the closing band shortly before the line has no room to change lanes: it
## brakes, stops before the waiting line, waits for green and passes without a hit.
static func gate_wait(test, track: String, entry: Dictionary, difficulty: String) -> void:
	await test._start(track, difficulty, "comet", "race")
	test.hold_rivals_from = 1
	var guard: float = 0.0
	while str(PASSAGES.swing_state(entry, test.game.elapsed).phase) != "warn" and guard < 12.0:
		test._place(float(entry.wait_line) - 400.0, -4.6, 0.0)
		test._tick()
		guard += STEP
	var state: Dictionary = PASSAGES.swing_state(entry, test.game.elapsed)
	var band: Vector2 = PASSAGES.gate_band(entry, state)
	var lane: float = (band.x + band.y) * 0.5
	var at: float = float(entry.wait_line) - 36.0
	test.game.opponent_distances[0] = at
	test.game.opponents[0].position = test.game.world.position_at(at, lane)
	test.game.opponent_headings[0] = test.game._heading(at)
	var rules: Dictionary = test.game.CATALOG.entry(test.game.CATALOG.DIFFICULTIES, difficulty)
	var cruise: float = test.game.RIVAL_RACECRAFT.cruise_speed(
		test.game.opponents[0].kart_style, rules
	)
	test.game.opponents[0].set_motion(cruise, 0.0, false, false)
	var stopped_at: float = -1.0
	var waited: float = 0.0
	var stunned: bool = false
	var passed: bool = false
	var t: float = 0.0
	while t < 16.0 and not passed:
		test._place(float(entry.wait_line) - 400.0, -4.6, 0.0)
		test._tick()
		t += STEP
		var road: Dictionary = test.game.world.sample_road(
			test.game.opponents[0].position,
			fposmod(test.game.opponent_distances[0], test.game.track_length)
		)
		var local: float = float(road.distance)
		var speed: float = absf(test.game.opponents[0].motion_speed)
		var inside: bool = (
			float(road.lateral) > band.x - PASSAGES.GATE_LANE_MARGIN
			and float(road.lateral) < band.y + PASSAGES.GATE_LANE_MARGIN
		)
		if local < float(entry.wait_line) + 0.5 and speed < 0.3 and inside:
			waited += STEP
			if stopped_at < 0.0:
				stopped_at = local
		stunned = stunned or test.game.opponent_stuns[0] > 0.7
		passed = local > float(entry.plane) + float(entry.band) + 3.0
	var tag: String = "%s %s" % [entry.id, difficulty]
	# Either it stopped in front of the band, or it found room in the open lane – never a hit.
	test._check(passed and not stunned, "%s: rival in the band passes without a hit" % tag)
	test._check(
		stopped_at < 0.0 or stopped_at <= float(entry.wait_line) + 0.5,
		"%s: a waiting rival stops before the line (%.1f m)" % [tag, stopped_at]
	)
	test._note(
		(
			(
				"%s: KI %.1f m/s im Sperrband 36 m vor der Linie → hält bei %.1f m, wartet %.1f s,"
				+ " durch: %s, Treffer: %s"
			)
			% [tag, cruise, stopped_at, waited, passed, stunned]
		)
	)
	test._park_rival(0, -600.0)
	test.hold_rivals_from = 99


## Lava pulse with momentum: arriving at race pace while the stream glows is no fall
## (heiße Zone 7,5 m in < 0,4 s), and the measured entry speed is above min_speed.
static func lava_fast(test, entry: Dictionary, cruise: float) -> void:
	var guard: float = 0.0
	while guard < 20.0:
		test._place(float(entry.wait_line) - 150.0, 0.0, 0.0)
		test._tick()
		guard += STEP
		var state: Dictionary = PASSAGES.swing_state(entry, test.game.elapsed)
		if str(state.phase) == "swing" and float(state.progress) < 0.1:
			break
	var band: Vector2 = PASSAGES.gate_band(entry, PASSAGES.swing_state(entry, test.game.elapsed))
	var lane: float = (band.x + band.y) * 0.5
	test._place(float(entry.plane) - cruise * 0.7, lane, cruise)
	var falls: int = test.game.passage_falls
	var hits: int = test.game.passage_hits
	var entry_speed: float = -1.0
	var t: float = 0.0
	while test._local() < float(entry.plane) + 8.0 and t < 4.0:
		test._touch_steer(lane, 0.0)
		test._tick()
		t += STEP
		var hot: bool = (
			absf(test._local() - float(entry.plane))
			<= float(entry.band) + PASSAGES.KART_HALF_LENGTH
		)
		if hot and entry_speed < 0.0:
			entry_speed = test.game.speed
			test._check(
				str(PASSAGES.swing_state(entry, test.game.elapsed).phase) == "swing",
				"%s: the fast kart meets the glowing stream" % entry.id
			)
	test._check(
		test.game.passage_falls == falls and test.game.passage_hits == hits,
		"%s: with momentum (%.1f m/s) over the lava" % [entry.id, entry_speed]
	)
	test._note(
		(
			"%s: mit Schwung %.1f m/s über den Lavapuls (Mindesttempo %.1f m/s) → kein Sturz"
			% [entry.id, entry_speed, float(entry.min_speed)]
		)
	)
