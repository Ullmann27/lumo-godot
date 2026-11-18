extends SceneTree
## LUMO-Passagen in der echten Rennphysik (Winter-Sprint, Dschungelherz und jede weitere
## Strecke mit Passage): Deckbreite ≥ 1,6 × breitestes Kart (aus den Kartmodellen gemessen),
## zehn Durchfahrten aus dem Stand mit Touch-Eingaben und Fahrhilfe, langsamstes Kart nach
## vollem Halt durch das bewegte Hindernis, Wartezone ohne Rücksetzer und ohne Rückwärtsrollen,
## zwei Karts nebeneinander vor dem Eingang, Treffer beim Warten, Rücksetzer direkt danach,
## Sturz → Rücksetzpunkt vor der Passage mit richtiger Rundenzählung, KI-Feld zwei Runden,
## Rundenlänge Dschungelherz 3.600 m ± 1 m, Minikarte und Geisterschlüssel.
## Argumente: -- [track_id ...] (ohne Angabe: alle Strecken mit Passagen). "quick" lässt die
## KI-Zwei-Runden-Fahrt weg.
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const FLEET_EXTREMES = preload("res://scripts/tests/helpers/kart_passage_fleet.gd")
const RIVAL_CHECKS = preload("res://scripts/tests/helpers/kart_passage_rival_checks.gd")
const STEP: float = 1.0 / 60.0
var game
var failures: int = 0
var checks: int = 0
var report: Array[String] = []
var hold_rivals_from: int = 99
var _noise_seed: int = 1


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("[Passage] FAIL: ", message)


func _note(text: String) -> void:
	report.append(text)
	print("[Passage] ", text)


func _settle() -> void:
	await process_frame
	await process_frame


func _start(track: String, difficulty: String, kart: String, mode: String = "training") -> void:
	game._start_selected_race(
		{"mode": mode, "driver": "fox", "kart": kart, "track": track, "difficulty": difficulty}
	)
	game._end_preview()
	await _settle()
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	game.gas_held = false
	game.brake = 0.0
	game.steering = 0.0
	for i in range(game.opponents.size()):
		_park_rival(i, -600.0 - float(i) * 30.0)


func _park_rival(index: int, at: float) -> void:
	game.opponent_distances[index] = at
	var local: float = fposmod(at, game.track_length)
	game.opponents[index].position = game.world.position_at(local, -3.0)
	game.opponent_headings[index] = game._heading(local)


func _place(at: float, lateral: float, speed: float, heading_error: float = 0.0) -> void:
	game.distance = at
	game.previous_road_distance = fposmod(at, game.track_length)
	game.checkpoint_index = int(at / (game.track_length / 8.0))
	game.player.transform = game.world.reset_transform(fposmod(at, game.track_length), lateral)
	game.player.position = (
		game.world.position_at(fposmod(at, game.track_length), lateral)
		+ game.world.frame(fposmod(at, game.track_length)).y * 0.035
	)
	game.player_heading = game._heading(fposmod(at, game.track_length)) + heading_error
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = speed
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	)
	game.airborne = false
	game.open_edge_fall = false
	game.offroad_seconds = 0.0
	game.boost_time = 0.0
	game.hit_timer = 0.0
	game.shield_time = 0.0
	game.player_spin_time = 0.0
	game.passage_creep = ""
	game.lane = lateral
	game.brake = 0.0
	game.steering = 0.0


func _noise() -> float:
	_noise_seed = (_noise_seed * 1103515245 + 12345) % 2147483648
	return float(_noise_seed % 1000) / 1000.0 - 0.5


## A child on the touch stick: aims at the centre line a few metres ahead, with a
## little hand noise. Brake only where the caller asks for it.
func _touch_steer(target_lane: float, wobble: float = 0.12) -> void:
	var local: float = fposmod(game.previous_road_distance, game.track_length)
	var target: Vector3 = game.world.position_at(local + 6.0, target_lane)
	var direction: Vector3 = target - game.player.position
	var axis: float = (
		-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.0
	)
	game.steering = clampf(axis + _noise() * wobble * 2.0, -1.0, 1.0)


func _tick(seconds: float = STEP) -> void:
	for _i in range(maxi(1, roundi(seconds / STEP))):
		game._physics_process(STEP)
		for i in range(hold_rivals_from, game.opponents.size()):
			_park_rival(i, -600.0 - float(i) * 30.0)


func _local() -> float:
	return fposmod(game.previous_road_distance, game.track_length)


# ------------------------------------------------------------------ widths


func _widest_kart() -> float:
	var vehicle_script: Script = load("res://scripts/games/kart_vehicle.gd")
	var widest: float = 0.0
	for id in FLEET.ids():
		var kart: Node3D = vehicle_script.new()
		root.add_child(kart)
		kart.configure("fox", Color("76d9ff"), id)
		await process_frame
		var inverse: Transform3D = kart.global_transform.affine_inverse()
		var box := AABB()
		var first: bool = true
		for child in kart.find_children("*", "VisualInstance3D", true, false):
			var visual: VisualInstance3D = child
			if (
				not visual.is_visible_in_tree()
				or visual is GPUParticles3D
				or visual is CPUParticles3D
			):
				continue
			var local: AABB = (inverse * visual.global_transform) * visual.get_aabb()
			box = local if first else box.merge(local)
			first = false
		widest = maxf(widest, box.size.x)
		kart.queue_free()
		await process_frame
	return widest


## Upper edge: full own pace (catalog speed 1.17, "pro") with the fastest kart. The child
## sees the first sign, reacts after 1.0 s and brakes fully: it must stop before the danger.
## Then the brave line: ten runs at full pace straight through with touch noise.
func _full_pace(track: String, entry: Dictionary) -> void:
	var kart: String = FLEET_EXTREMES.fastest_kart()
	await _start(track, "pro", kart)
	var top: float = game.POWERTRAIN.top_speed(game.kart_factors, 1.17)
	var bridge: bool = str(entry.kind) == "bridge"
	var danger: float = float(entry.deck_start) if bridge else float(entry.wait_line)
	# Cumulative race metres from lap 1, so a sign before the start line wraps correctly.
	var base: float = game.track_length
	var sign_at: float = float(entry.zone_start) - PASSAGES.SIGN_LEAD_M
	_place(base + sign_at - 60.0, 0.0, top)
	while game.distance < base + sign_at:
		_touch_steer(0.0, 0.0)
		_tick()
	var seen_speed: float = game.speed
	_tick(1.0)
	var resets: int = game.reset_count
	game.brake = 1.0
	var guard: float = 0.0
	var braked: float = 0.0
	while game.speed > 0.2 and guard < 8.0:
		_touch_steer(0.0, 0.0)
		_tick()
		braked += maxf(0.0, game.speed) * STEP
		guard += STEP
	var before_danger: float = fposmod(danger - _local(), game.track_length)
	game.brake = 0.0
	_check(
		before_danger > 1.0 and before_danger < 400.0 and game.reset_count == resets,
		"%s: full pace stops before the danger (%.1f m before)" % [entry.id, before_danger]
	)
	var lead_s: float = (danger - sign_at) / maxf(seen_speed, 1.0)
	_note(
		(
			(
				"%s volles Tempo (%s, %.1f m/s): erstes Schild %.0f m = %.1f s vor der Gefahr;"
				+ " nach 1,0 s Reaktion Bremsweg %.1f m, steht %.1f m vor der Gefahr"
			)
			% [entry.id, kart, seen_speed, danger - sign_at, lead_s, braked, before_danger]
		)
	)
	if not bridge:
		return
	var made: int = 0
	for run in range(10):
		_place(float(entry.deck_start) - 90.0, -1.0 + float(run) * 0.22, top)
		var falls: int = game.passage_falls
		var t: float = 0.0
		while _local() < float(entry.deck_end) + 5.0 and t < 6.0 and game.passage_falls == falls:
			_touch_steer(0.0, 0.10)
			_tick()
			t += STEP
		if game.passage_falls == falls and _local() >= float(entry.deck_end) + 5.0:
			made += 1
	_check(made >= 8, "%s: the brave line is drivable at full pace (%d/10)" % [entry.id, made])
	_note(
		(
			"%s mutige Linie mit vollem Tempo %.1f m/s ohne Bremsen, Touch mit Handzittern: %d/10"
			% [entry.id, top, made]
		)
	)


# ------------------------------------------------------------------ bridge checks


func _bridge_checks(track: String, entry: Dictionary, widest: float) -> void:
	var deck: float = float(entry.deck_width)
	_check(
		deck >= widest * PASSAGES.PRECISION_FACTOR - 0.001,
		"%s deck %.2f m ≥ 1.6 × %.2f m" % [entry.id, deck, widest]
	)
	_check(
		is_equal_approx(
			game.world.road_width_at((float(entry.deck_start) + float(entry.deck_end)) * 0.5), deck
		),
		"%s road width is the deck" % entry.id
	)
	_check(
		game.world.road_width_at(float(entry.plaza_start) + 2.0) > deck * 2.0,
		"%s plaza is full width" % entry.id
	)
	# Level plaza: grade measured on the finished curve.
	var worst_grade: float = 0.0
	var d: float = float(entry.plaza_start)
	while d < float(entry.deck_start):
		var rise: float = game.world.position_at(d + 2.0).y - game.world.position_at(d - 2.0).y
		worst_grade = maxf(worst_grade, absf(rise / 4.0))
		d += 2.0
	_check(worst_grade <= 0.035, "%s plaza is level (%.1f %%)" % [entry.id, worst_grade * 100.0])
	# Physical: the visible asphalt has no triangles over the gap (expansion roads).
	var road_node: MeshInstance3D = game.world.get_node_or_null("BankedRoad")
	if road_node != null:
		var covered: bool = false
		var middle: Vector3 = game.world.position_at(
			(float(entry.deck_start) + float(entry.deck_end)) * 0.5, 4.0
		)
		var faces: PackedVector3Array = road_node.mesh.get_faces()
		for k in range(0, faces.size(), 3):
			var centroid: Vector3 = (faces[k] + faces[k + 1] + faces[k + 2]) / 3.0
			if centroid.distance_to(middle) < 1.0:
				covered = true
		_check(not covered, "%s: no asphalt beside the deck" % entry.id)
	_note(
		(
			(
				"%s %s: deck %.2f m = %.2f × widest kart %.2f m; plaza grade max %.1f"
				+ " %%; deck %.0f–%.0f m"
			)
			% [
				track,
				entry.id,
				deck,
				deck / widest,
				widest,
				worst_grade * 100.0,
				float(entry.deck_start),
				float(entry.deck_end)
			]
		)
	)
	await _ten_from_standstill(track, entry, "gemuetlich")
	await _ten_from_standstill(track, entry, "flott")
	for difficulty in ["gemuetlich", "flott", "pro"]:
		await RIVAL_CHECKS.bridge_queue(self, track, entry, difficulty)
	await _wait_zone(entry)
	await _side_by_side(entry)
	await _hit_then_reset(entry)
	await _fall_and_lap(track, entry)
	await _full_pace(track, entry)


## Ten real starts from a full stop on the plaza: different stop points, lateral offsets and
## heading errors, touch stick with hand noise, Auto-Gas on, brake released after a pause.
func _ten_from_standstill(track: String, entry: Dictionary, difficulty: String) -> void:
	await _start(track, difficulty, "turbo")
	var passed: int = 0
	var worst_lane: float = 0.0
	var times: Array[float] = []
	for run in range(10):
		var stop_d: float = float(entry.deck_start) - 9.0 - float(run % 4) * 2.0
		var lateral: float = -3.0 + float(run) * 0.66
		_place(stop_d, lateral, 0.0, (float(run % 3) - 1.0) * 0.18)
		var resets: int = game.reset_count
		game.brake = 1.0
		_tick(0.8)
		game.brake = 0.0
		var t: float = 0.0
		var crossed: bool = false
		var max_lane: float = 0.0
		while t < 14.0:
			_touch_steer(0.0)
			_tick()
			t += STEP
			var local: float = _local()
			if local >= float(entry.deck_start) and local <= float(entry.deck_end):
				max_lane = maxf(max_lane, absf(game.lane))
			if local > float(entry.deck_end) + 3.0 and local < float(entry.deck_end) + 40.0:
				crossed = true
				break
		if crossed and game.reset_count == resets:
			passed += 1
			times.append(t)
		worst_lane = maxf(worst_lane, max_lane)
	_check(
		passed == 10,
		"%s %s: 10 of 10 crossings from standstill (%d)" % [entry.id, difficulty, passed]
	)
	var average: float = 0.0
	for value in times:
		average += value / maxf(1.0, float(times.size()))
	_note(
		(
			(
				"%s %s: %d/10 aus dem Stand, max. Querabweichung auf dem Deck %.2f m"
				+ " (Absturz ab %.2f m), Ø %.1f s bis hinter das Deck"
			)
			% [
				entry.id,
				difficulty,
				passed,
				worst_lane,
				PASSAGES.fall_lateral(game.world, float(entry.deck_start) + 1.0),
				average
			]
		)
	)


## Waiting with the brake held: no automatic reset, no reverse, no rolling into the gap.
func _wait_zone(entry: Dictionary) -> void:
	var at: float = (
		float(entry.deck_start) - 6.0
		if str(entry.kind) == "bridge"
		else float(entry.wait_line) - 1.5
	)
	_place(at, 0.4, 0.0)
	var resets: int = game.reset_count
	var before: float = game.distance
	game.brake = 1.0
	_tick(10.0)
	_check(game.reset_count == resets, "%s: 10 s waiting causes no reset" % entry.id)
	_check(
		absf(game.distance - before) < 0.3,
		"%s: held brake does not reverse (%.2f m)" % [entry.id, game.distance - before]
	)
	_check(game.speed >= -0.01, "%s: no reverse speed while waiting" % entry.id)
	game.brake = 0.0
	_note(
		(
			"%s: 10 s Warten mit gehaltener Bremse: %d Rücksetzer, %.2f m Weg"
			% [entry.id, game.reset_count - resets, game.distance - before]
		)
	)


## Child and one rival side by side in front of the entrance. The rival must yield; the child
## is never shoved sideways off the deck.
func _side_by_side(entry: Dictionary) -> void:
	await _start(str(game.track_id), str(game.difficulty), "comet", "race")
	var at: float = (
		(float(entry.deck_start) - 14.0)
		if str(entry.kind) == "bridge"
		else float(entry.wait_line) - 6.0
	)
	var lap_base: float = game.track_length * 0.0
	hold_rivals_from = 1
	_place(lap_base + at, -1.9, 0.0)
	game.opponent_distances[0] = lap_base + at
	game.opponents[0].position = game.world.position_at(at, 1.9)
	game.opponent_headings[0] = game._heading(at)
	game.opponents[0].set_motion(0.0, 0.0, false, false)
	var resets: int = game.reset_count
	var player_max_lane: float = 0.0
	var rival_max_lane: float = 0.0
	var rival_crossed: bool = false
	var player_crossed: bool = false
	var gap_order_ok: bool = true
	var end: float = (
		(
			float(entry.deck_end)
			if str(entry.kind) == "bridge"
			else float(entry.plane) + float(entry.band)
		)
		+ 6.0
	)
	var t: float = 0.0
	while t < 25.0 and not (rival_crossed and player_crossed):
		if str(entry.kind) == "swing":
			var state: Dictionary = PASSAGES.swing_state(entry, game.elapsed)
			game.brake = (
				1.0 if (str(state.phase) != "open" and _local() < float(entry.wait_line)) else 0.0
			)
		_touch_steer(0.0)
		_tick()
		t += STEP
		var local: float = _local()
		var rival_local: float = fposmod(game.opponent_distances[0], game.track_length)
		if str(entry.kind) == "bridge":
			if local >= float(entry.deck_start) and local <= float(entry.deck_end):
				player_max_lane = maxf(player_max_lane, absf(game.lane))
			if rival_local >= float(entry.deck_start) and rival_local <= float(entry.deck_end):
				rival_max_lane = maxf(rival_max_lane, absf(game.opponent_lanes[0]))
				# Single file: rival on the deck only when the child is not beside it.
				if (
					local >= float(entry.deck_start)
					and local <= float(entry.deck_end)
					and absf(local - rival_local) < 2.2
				):
					gap_order_ok = false
		player_crossed = player_crossed or (local > end and local < end + 60.0)
		rival_crossed = rival_crossed or (rival_local > end and rival_local < end + 60.0)
	game.brake = 0.0
	_check(game.reset_count == resets, "%s: side-by-side start without a fall" % entry.id)
	_check(
		player_crossed and rival_crossed,
		"%s: child and rival both pass (%s/%s)" % [entry.id, player_crossed, rival_crossed]
	)
	if str(entry.kind) == "bridge":
		_check(
			player_max_lane < PASSAGES.fall_lateral(game.world, float(entry.deck_start) + 1.0),
			"%s: child stays on the deck beside a rival" % entry.id
		)
		_check(
			rival_max_lane <= float(entry.deck_width) * 0.5 - PASSAGES.RIVAL_DECK_MARGIN + 0.01,
			"%s: rival keeps its line on the deck" % entry.id
		)
		_check(gap_order_ok, "%s: no side-by-side on the deck" % entry.id)
	_note(
		(
			(
				"%s: nebeneinander vor dem Eingang – Kind max. %.2f m, Rivale max."
				+ " %.2f m quer, beide durch: %s"
			)
			% [entry.id, player_max_lane, rival_max_lane, player_crossed and rival_crossed]
		)
	)
	_park_rival(0, -600.0)
	hold_rivals_from = 99


## A hit while waiting, then a reset straight afterwards.
func _hit_then_reset(entry: Dictionary) -> void:
	var at: float = (
		float(entry.deck_start) - 5.0
		if str(entry.kind) == "bridge"
		else float(entry.wait_line) - 1.0
	)
	_place(at, 0.8, 0.0)
	game.brake = 1.0
	_tick(0.5)
	game.player_grace_time = 0.0
	game._apply_item_event(
		{"type": "hit", "target": -1, "source": 1, "spin": 1.2, "position": game.player.position}
	)
	var resets: int = game.reset_count
	var falls: int = game.passage_falls
	var hits: int = game.passage_hits
	_tick(2.0)
	_check(
		game.reset_count == resets and game.passage_falls == falls,
		"%s: hit while waiting does not throw the kart into the gap" % entry.id
	)
	_check(game.passage_hits == hits, "%s: hit while waiting is no vine hit" % entry.id)
	var danger: float = (
		float(entry.deck_start)
		if str(entry.kind) == "bridge"
		else float(entry.plane) - float(entry.band) - PASSAGES.KART_HALF_LENGTH
	)
	_check(
		_local() < danger,
		(
			"%s: still in front of the danger after the hit (%.1f < %.1f)"
			% [entry.id, _local(), danger]
		)
	)
	var checkpoint: int = game.checkpoint_index
	game._reset_kart()
	_check(game.checkpoint_index == checkpoint, "%s: reset keeps the checkpoint" % entry.id)
	_check(
		_local() < danger and absf(game.lane) < 0.05 and absf(game.speed) < 0.01,
		"%s: reset right after the hit lands centred and still before the passage" % entry.id
	)
	# A reset while ON the deck goes back to the plaza respawn point.
	if str(entry.kind) == "bridge":
		_place(float(entry.deck_start) + 6.0, 0.0, 4.0)
		game._reset_kart()
		_check(
			absf(_local() - float(entry.respawn)) < 0.6,
			"%s: reset on the deck returns to the plaza (%.1f)" % [entry.id, _local()]
		)
	game.brake = 0.0
	_note(
		(
			(
				"%s: Treffer beim Warten → steht weiter vor der Gefahr; Rücksetzer"
				+ " danach → %.1f m, mittig, Stillstand"
			)
			% [entry.id, _local()]
		)
	)


## Steering off the deck: the kart falls, the Lumo cloud sets it on the plaza; the lap is
## still counted correctly at the line.
func _fall_and_lap(track: String, entry: Dictionary) -> void:
	await _start(track, "flott", "comet", "race")
	_place(float(entry.deck_start) - 30.0, 0.0, 20.0)
	var falls: int = game.passage_falls
	var t: float = 0.0
	while game.passage_falls == falls and t < 8.0:
		var local: float = _local()
		_touch_steer(4.0 if local > float(entry.deck_start) - 2.0 else 0.0, 0.0)
		_tick()
		t += STEP
	_check(game.passage_falls == falls + 1, "%s: steering off the deck is a fall" % entry.id)
	_check(
		absf(_local() - float(entry.respawn)) < 0.6,
		"%s: fall resets to the plaza (%.1f m)" % [entry.id, _local()]
	)
	_check(
		absf(game.lane) < 0.05 and absf(game.speed) < 0.01,
		"%s: calm restart, centred and standing" % entry.id
	)
	_check(
		game.checkpoint_index == int(float(entry.respawn) / (game.track_length / 8.0)),
		"%s: checkpoint after the fall" % entry.id
	)
	# Drive on to the line: eight ordered checkpoints and one lap time.
	var start_laps: int = game.lap_times.size()
	t = 0.0
	while game.checkpoint_index < 8 and t < 150.0:
		var local: float = _local()
		_touch_steer(0.0, 0.0)
		var deck_ahead: float = float(entry.deck_start) - local
		game.brake = 1.0 if deck_ahead > 0.0 and deck_ahead < 40.0 and game.speed > 14.0 else 0.0
		_tick()
		t += STEP
	game.brake = 0.0
	_check(
		game.checkpoint_index == 8,
		"%s: lap completes after the fall (checkpoint %d)" % [entry.id, game.checkpoint_index]
	)
	_note(
		(
			"%s: Sturz → Vorplatz %.0f m, danach Runde vollständig (Checkpoint %d, Zeit %.0f s)"
			% [entry.id, float(entry.respawn), game.checkpoint_index, t]
		)
	)
	_check(game.lap_times.size() >= start_laps, "%s: lap timing intact" % entry.id)


# ------------------------------------------------------------------ swing checks


func _swing_checks(track: String, entry: Dictionary) -> void:
	var slow: Dictionary = FLEET_EXTREMES.slowest_karts()
	for kart in [str(slow.accel), str(slow.top)]:
		await _start(track, "gemuetlich", kart)
		# Full stop at the waiting line while Kiri swings; go 1.0 s after green (reaction).
		var worst: float = 0.0
		var hits: int = 0
		for run in range(10):
			_place(float(entry.wait_line) - 0.8 - float(run % 3) * 1.2, _run_lane(entry, run), 0.0)
			game.brake = 1.0
			var guard: float = 0.0
			while str(PASSAGES.swing_state(entry, game.elapsed).phase) != "swing" and guard < 12.0:
				_tick()
				guard += STEP
			while str(PASSAGES.swing_state(entry, game.elapsed).phase) == "swing":
				_tick()
			var green_at: float = game.elapsed
			_tick(1.0)
			game.brake = 0.0
			var before_hits: int = game.passage_hits
			var clear: float = float(entry.plane) + float(entry.band) + PASSAGES.KART_HALF_LENGTH
			var t: float = 0.0
			while _local() < clear and t < 8.0:
				_touch_steer(_run_lane(entry, run))
				_tick()
				t += STEP
			var used: float = game.elapsed - green_at
			worst = maxf(worst, used)
			hits += game.passage_hits - before_hits
			_check(_local() >= clear, "%s %s run %d passes" % [entry.id, kart, run])
		var window: float = float(entry.open)
		_check(hits == 0, "%s %s: no vine hit after a full stop (%d)" % [entry.id, kart, hits])
		_check(
			worst < window,
			(
				"%s %s: through within the green window (%.2f s < %.1f s)"
				% [entry.id, kart, worst, window]
			)
		)
		_note(
			(
				(
					"%s %s: aus vollem Halt + 1,0 s Reaktion bis hinter das Band max. %.2f"
					+ " s; Grün %.1f s (+ %.1f s Ruf); Reserve %.2f s; Treffer %d"
				)
				% [entry.id, kart, worst, window, float(entry.warn), window - worst, hits]
			)
		)
	for difficulty in ["gemuetlich", "flott", "pro"]:
		if str(entry.kind) == "gate":
			await _rival_outer_lane(track, entry, difficulty)
			await RIVAL_CHECKS.gate_wait(self, track, entry, difficulty)
		else:
			await _rival_waits(track, entry, difficulty)
	await _full_pace(track, entry)
	await _start(track, "flott", "comet")
	await _wait_zone(entry)
	await _side_by_side(entry)
	await _hit_then_reset(entry)
	# Arriving while Kiri swings without braking: a friendly nudge, never a reset.
	# Hold far back until Kiri will be over the centre lane in 1.5 s, then arrive at top speed.
	# The real race pace (catalog "speed", 1,17 on every level since 18.11.2026), not 1.0:
	# with 1.0 the kart reached the plane 0.2 s early and slipped past Kiri's nose.
	var pace: float = float(game.CATALOG.entry(game.CATALOG.DIFFICULTIES, game.difficulty).speed)
	var cruise: float = game.POWERTRAIN.top_speed(game.kart_factors, pace)
	var resets: int = game.reset_count
	var falls_before: int = game.passage_falls
	var hit_before: int = game.passage_hits
	var into_lane: float = 0.0
	var guard2: float = 0.0
	var slow_lava: bool = entry.has("min_speed")
	# Lava: arrive mid-pulse just before the hot zone, too slow (55 % of the minimum speed).
	var lead: float = 0.15 if slow_lava else 1.5
	while guard2 < 20.0:
		_place(float(entry.wait_line) - 150.0, 0.0, 0.0)
		_tick()
		guard2 += STEP
		var state: Dictionary = PASSAGES.swing_state(entry, game.elapsed)
		var until_centre: float = float(state.until_swing) + PASSAGES._blocking_seconds(entry) * 0.5
		var mid_pulse: bool = (
			slow_lava and str(state.phase) == "swing" and absf(float(state.progress) - 0.3) < 0.02
		)
		if mid_pulse or (str(state.phase) != "swing" and absf(until_centre - lead) < STEP):
			if str(entry.kind) == "gate":
				var future: Dictionary = PASSAGES.swing_state(
					entry, game.elapsed + (0.0 if slow_lava else lead)
				)
				var band: Vector2 = PASSAGES.gate_band(entry, future)
				into_lane = (band.x + band.y) * 0.5
			break
	var arrive: float = float(entry.get("min_speed", 0.0)) * 0.55 if slow_lava else cruise
	var before_plane: float = (
		float(entry.band) + PASSAGES.KART_HALF_LENGTH + 1.0 if slow_lava else cruise * lead
	)
	_place(float(entry.plane) - before_plane, into_lane, arrive)
	var t2: float = 0.0
	while _local() < float(entry.plane) + 8.0 and t2 < 6.0 and game.passage_falls == falls_before:
		_touch_steer(into_lane, 0.0)
		_tick()
		t2 += STEP
	_check(
		game.passage_hits == hit_before + 1,
		"%s: driving into the swing is a vine hit (%d)" % [entry.id, game.passage_hits - hit_before]
	)
	if str(entry.get("effect", "bump")) == "reset":
		var fall_wait: float = 0.0
		while game.passage_falls == falls_before and fall_wait < 3.0:
			_tick()
			fall_wait += STEP
		_check(game.passage_falls == falls_before + 1, "%s: the hot stream is a fall" % entry.id)
		_check(
			absf(_local() - float(entry.respawn)) < 0.6,
			"%s: back before the stream (%.1f m)" % [entry.id, _local()]
		)
	else:
		_check(game.reset_count == resets, "%s: a vine hit is no reset" % entry.id)
	if slow_lava:
		await RIVAL_CHECKS.lava_fast(self, entry, cruise)
	if str(entry.kind) == "gate":
		await _gate_outer_lane(entry)
	_note(
		(
			"%s: ungebremst in den Schwung → %d Stupser, %d Rücksetzer"
			% [entry.id, game.passage_hits - hit_before, game.reset_count - resets]
		)
	)


func _run_lane(entry: Dictionary, run: int) -> float:
	if str(entry.kind) == "gate":
		return (float(entry.lat_min) + float(entry.lat_max)) * 0.5 + float(run % 3 - 1) * 0.7
	return -2.6 + float(run) * 0.55


## The open outer lane stays drivable while the gate is closed (no hit, no waiting).
func _gate_outer_lane(entry: Dictionary) -> void:
	var guard: float = 0.0
	while guard < 15.0:
		_place(float(entry.wait_line) - 150.0, 0.0, 0.0)
		_tick()
		guard += STEP
		var state: Dictionary = PASSAGES.swing_state(entry, game.elapsed)
		if str(state.phase) == "warn" and float(state.progress) > 0.9:
			break
	var state2: Dictionary = PASSAGES.swing_state(entry, game.elapsed + 1.0)
	var lane_free: float = PASSAGES.free_lane(game.world, entry, state2)
	_place(float(entry.wait_line) - 20.0, lane_free, 22.0)
	var hits: int = game.passage_hits
	var falls: int = game.passage_falls
	var t: float = 0.0
	while _local() < float(entry.plane) + 10.0 and t < 6.0:
		_touch_steer(lane_free, 0.05)
		_tick()
		t += STEP
	_check(
		game.passage_hits == hits and game.passage_falls == falls,
		"%s: the open outer lane passes while the gate is closed" % entry.id
	)
	_note(
		"%s: Außenspur (%.1f m quer) bei geschlossenem Tor frei befahrbar" % [entry.id, lane_free]
	)


## A rival arrives while the gate is about to close: it uses the open outer lane (no stop
## needed, no hit) – at the rival pace of this difficulty.
func _rival_outer_lane(track: String, entry: Dictionary, difficulty: String) -> void:
	await _start(track, difficulty, "comet", "race")
	hold_rivals_from = 1
	var guard: float = 0.0
	while str(PASSAGES.swing_state(entry, game.elapsed).phase) != "warn" and guard < 12.0:
		_place(float(entry.wait_line) - 400.0, -4.6, 0.0)
		_tick()
		guard += STEP
	var at: float = float(entry.wait_line) - 70.0
	var band0: Vector2 = Vector2(float(entry.lat_min), float(entry.lat_max))
	var start_lane: float = (band0.x + band0.y) * 0.5
	game.opponent_distances[0] = at
	game.opponents[0].position = game.world.position_at(at, start_lane)
	game.opponent_headings[0] = game._heading(at)
	var rules: Dictionary = game.CATALOG.entry(game.CATALOG.DIFFICULTIES, difficulty)
	var cruise: float = game.RIVAL_RACECRAFT.cruise_speed(game.opponents[0].kart_style, rules)
	game.opponents[0].set_motion(cruise, 0.0, false, false)
	var stunned: bool = false
	var passed: bool = false
	var lane_at_plane: float = INF
	var t: float = 0.0
	while t < 12.0 and not passed:
		_place(float(entry.wait_line) - 400.0, -4.6, 0.0)
		_tick()
		t += STEP
		var road: Dictionary = game.world.sample_road(
			game.opponents[0].position, fposmod(game.opponent_distances[0], game.track_length)
		)
		if absf(float(road.distance) - float(entry.plane)) < 1.0:
			lane_at_plane = float(road.lateral)
		stunned = stunned or game.opponent_stuns[0] > 0.7
		passed = float(road.distance) > float(entry.plane) + float(entry.band) + 3.0
	_check(passed and not stunned, "%s %s: rival passes without a hit" % [entry.id, difficulty])
	_note(
		(
			"%s %s: KI mit %.1f m/s kurz vor dem Schließen → quer %.1f m an der Sperre, Treffer: %s"
			% [entry.id, difficulty, cruise, lane_at_plane, stunned]
		)
	)
	_park_rival(0, -600.0)
	hold_rivals_from = 99


# ------------------------------------------------------------------ rivals


## One rival arrives at full speed just as Kiri starts calling: it must brake, stop in front
## of the waiting line, wait for green and pull away again without being hit.
func _rival_waits(track: String, entry: Dictionary, difficulty: String = "flott") -> void:
	await _start(track, difficulty, "comet", "race")
	hold_rivals_from = 1
	_place(float(entry.wait_line) - 400.0, -4.6, 0.0)
	var guard: float = 0.0
	while str(PASSAGES.swing_state(entry, game.elapsed).phase) != "warn" and guard < 12.0:
		_place(float(entry.wait_line) - 400.0, -4.6, 0.0)
		_tick()
		guard += STEP
	var at: float = float(entry.wait_line) - 60.0
	game.opponent_distances[0] = at
	game.opponents[0].position = game.world.position_at(at, 0.0)
	game.opponent_headings[0] = game._heading(at)
	var rules: Dictionary = game.CATALOG.entry(game.CATALOG.DIFFICULTIES, difficulty)
	var cruise: float = game.RIVAL_RACECRAFT.cruise_speed(game.opponents[0].kart_style, rules)
	game.opponents[0].set_motion(cruise, 0.0, false, false)
	var stopped_at: float = -1.0
	var min_speed: float = INF
	var passed: bool = false
	var t: float = 0.0
	var waited: float = 0.0
	while t < 20.0 and not passed:
		_place(float(entry.wait_line) - 400.0, -4.6, 0.0)
		_tick()
		t += STEP
		var local: float = float(
			(
				game
				. world
				. sample_road(
					game.opponents[0].position,
					fposmod(game.opponent_distances[0], game.track_length)
				)
				. distance
			)
		)
		var speed: float = absf(game.opponents[0].motion_speed)
		if local < float(entry.wait_line) + 0.5:
			min_speed = minf(min_speed, speed)
			if speed < 0.3:
				waited += STEP
				if stopped_at < 0.0:
					stopped_at = local
		passed = local > float(entry.plane) + float(entry.band) + 3.0
	_check(
		min_speed < 0.3 and stopped_at >= 0.0 and stopped_at <= float(entry.wait_line) + 0.5,
		"%s: rival brakes to a stop before the line (%.1f m)" % [entry.id, stopped_at]
	)
	_check(passed, "%s: rival pulls away again and passes" % entry.id)
	_check(game.opponent_stuns[0] < 0.7, "%s: waiting rival is not hit" % entry.id)
	_note(
		(
			(
				"%s %s: KI kommt mit %.1f m/s beim Ruf an → hält bei %.1f m (Linie %.0f m),"
				+ " wartet %.1f s, fährt bei Grün durch: %s"
			)
			% [entry.id, difficulty, cruise, stopped_at, float(entry.wait_line), waited, passed]
		)
	)
	_park_rival(0, -600.0)
	hold_rivals_from = 99


# ------------------------------------------------------------------ run


func _run() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var quick: bool = args.has("quick")
	args.erase("quick")
	var field_only: bool = args.has("field")
	args.erase("field")
	var tracks: Array = args if not args.is_empty() else PASSAGES.SPEC_DATA.SPECS.keys()
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	if is_instance_valid(game.kart_audio):
		game.kart_audio.set_muted(true)  # The test drives minutes of race time; no audio needed.
	var widest: float = await _widest_kart()
	_check(
		absf(widest - PASSAGES.WIDEST_KART_M) < 0.05,
		(
			"documented widest kart %.2f m matches the models (%.2f m)"
			% [PASSAGES.WIDEST_KART_M, widest]
		)
	)
	for track in tracks:
		await _start(str(track), "flott", "comet")
		var entries: Array = PASSAGES.of(game.world)
		_check(not entries.is_empty(), "%s has passages" % track)
		if str(track) == "jungle_emerald_3600":
			_check(
				absf(game.track_length - 3600.0) <= 1.0,
				"Dschungelherz stays 3600 m ± 1 m (%.2f)" % game.track_length
			)
			_note("Dschungelherz Rundenlänge %.2f m" % game.track_length)
		var marks: int = 0
		for entry in entries:
			if str(entry.kind) in ["bridge", "swing"]:
				marks += 1
		_check(
			game.map.passage_marks.size() == marks, "%s: minimap shows %d passages" % [track, marks]
		)
		_check(
			game.records.record_key.contains("_p1") or game.mode != "time_trial",
			"%s ghost key" % track
		)
		_check(PASSAGES.ghost_suffix(str(track)) == "_p1", "%s ghosts are versioned" % track)
		for entry in [] if field_only else entries:
			match str(entry.kind):
				"bridge":
					await _bridge_checks(str(track), entry, widest)
				"swing", "gate":
					await _swing_checks(str(track), entry)
				"flow":
					if entry.has("arches"):
						RIVAL_CHECKS.chicane(self, entry, widest)
			await _start(str(track), "flott", "comet")
		if not quick:
			# Rival factors 0,86 / 0,96 / 1,00 with the full own pace 1,17 on every level.
			for difficulty in ["gemuetlich", "flott", "pro"]:
				await RIVAL_CHECKS.field(self, str(track), difficulty)
	game.abandoned = true
	# Long race simulations leave Ogg playbacks in their fade: stop them before the release check.
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	var soundscape: Node = root.get_node_or_null("GameSoundscape")
	if soundscape != null and soundscape.has_method("release_audio"):
		soundscape.release_audio()
	await create_timer(0.4).timeout
	_check(await TEARDOWN.release_scene(self, game, "[Passage]"), "scene released")
	print("[Passage] checks=%d failures=%d" % [checks, failures])
	for line in report:
		print("[Passage] REPORT ", line)
	if failures > 0:
		quit(1)
		return
	print("[Passage] PASS ", checks, " checks")
	quit(0)
