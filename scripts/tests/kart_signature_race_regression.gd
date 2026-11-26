extends SceneTree
## Vollständiges Rennen auf einer Signatur-Strecke (Team B1): zwei Runden, fünf KI-Rivalen,
## nur über die sichtbaren Bedienelemente (Gas, Lenkrad, Bremse). Der Testfahrer fährt wie
## ein geübtes Kind: volles Tempo, bremst vor engen Kurven, nimmt in Runde 1 die engen
## Turbo-Linien der Abzweige und in Runde 2 die breiten Wege, weicht an angekündigten
## Hindernissen auf die freie Seite aus. Nach dem Zieleinlauf fahren die Rivalen zu Ende.
##
##   godot --headless --path . --script res://scripts/tests/kart_signature_race_regression.gd \
##     -- --track=<id> [--difficulty=flott] [--mode=race|time_trial] [--shots=<dir>]
const SIGNATURE = preload("res://scripts/games/kart_signature/kart_signature_tracks.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var game
var track := ""
var difficulty := "flott"
var mode := "race"
var shots := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--track="):
			track = text.trim_prefix("--track=")
		elif text.begins_with("--difficulty="):
			difficulty = text.trim_prefix("--difficulty=")
		elif text.begins_with("--mode="):
			mode = text.trim_prefix("--mode=")
		elif text.begins_with("--shots="):
			shots = text.trim_prefix("--shots=")
	if track.is_empty():
		track = SIGNATURE.IDS[0]
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("[SignatureRace] " + label)


func _touch(finger: int, control: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = (
		control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	)
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _steer(value: float) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	var at: Vector2 = game.joystick.get_global_rect().get_center()
	at.x += game.joystick.size.x * .31 * value
	drag.position = at * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(drag)
	Input.flush_buffered_events()


## Wunschspur des Testfahrers an dieser Stelle (Runde 0 eng, Runde 1 breit).
func _lane(world, course, s: float, lap: int) -> float:
	var d: float = fposmod(s, world.length)
	for split in course.SPLITS:
		if d > float(split.start) - 45.0 and d < float(split.end):
			var half: float = world.road_width_at(float(split.start) + 20.0) * 0.5
			var narrow_side: float = signf(float(split.lateral))
			var narrow_mid: float = (
				(float(split.lateral) + narrow_side * (float(split.half) + 0.9 + half - 0.9)) * 0.5
			)
			var wide_mid: float = (
				(float(split.lateral) - narrow_side * (float(split.half) + 0.9 + half - 0.9)) * 0.5
			)
			return narrow_mid if lap == 0 else wide_mid
	for entry in PASSAGES.of(world):
		if str(entry.kind) != "gate":
			continue
		if d > float(entry.wait_start) - 40.0 and d < float(entry.plane) + 6.0:
			var arrive: float = (
				game.elapsed + maxf(0.0, float(entry.plane) - d) / maxf(game.speed, 8.0)
			)
			var state: Dictionary = PASSAGES.swing_state(entry, arrive)
			var band: Vector2 = PASSAGES.gate_band(entry, state)
			return PASSAGES.free_lane(world, entry, state) if band.x < 0.0 or band.y > 0.0 else 0.0
	return 0.0


## Kurventempo: aus der stärksten Richtungsänderung der nächsten 60 m.
func _corner_speed(world, s: float) -> float:
	var sharpest: float = 0.0
	var a: Vector3 = world.forward(s)
	for ahead in [12.0, 24.0, 36.0, 48.0, 60.0]:
		var b: Vector3 = world.forward(s + ahead)
		sharpest = maxf(sharpest, a.angle_to(b) / ahead)
	if sharpest < 0.002:
		return 80.0
	return clampf(sqrt(26.0 / sharpest), 20.0, 80.0)


func _run() -> void:
	var requested_size := root.size
	root.get_node("HostBridge")._options["childKey"] = "signature_%d" % Time.get_ticks_usec()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	root.size = requested_size
	await process_frame
	game.auto_gas = false
	game._start_selected_race(
		{"mode": mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": difficulty}
	)
	await process_frame
	await process_frame
	var world = game.world
	var course = SIGNATURE.course(track)
	check(game.track_id == track and game.TOTAL_LAPS == 2, "Rennen auf %s gestartet" % track)
	check(
		absf(game.track_length - float(course.LENGTH)) < 0.5,
		"Rundenlänge %.2f m" % game.track_length
	)
	check(world.has_node("SignatureEnvironment"), "Welt mit Kulisse")
	for i in range(1200):
		game._physics_process(STEP)
		if game.racing:
			break
	await process_frame
	_touch(1, game.joystick, true)
	_touch(2, game.gas_button, true)
	check(game.gas_held and game.joystick.touch_id == 1, "Gas und Lenkrad aktiv")
	var braking := false
	var farthest_step := 0.0
	var last_at: Vector3 = game.player.position
	var divider_hits := 0
	var split_sides: Dictionary = {}
	var lap_marks: Array[float] = []
	var top_speed := 0.0
	var contact_spots: Dictionary = {}
	var next_shot := 0
	var marks: Array = course.SHOT_MARKS
	for tick in range(30000):
		var s: float = game.previous_road_distance
		var lap: int = int(game.distance / game.track_length)
		var lane: float = _lane(world, course, s, lap)
		var aim: Vector3 = world.position_at(s + 11.0, lane) - game.player.position
		_steer(clampf(-angle_difference(game.player_heading, atan2(-aim.x, -aim.z)) * 2.5, -1, 1))
		var target: float = _corner_speed(world, s + 6.0)
		var brake: bool = not game.airborne and game.speed > target + (0.0 if braking else 2.0)
		if brake != braking:
			braking = brake
			_touch(3, game.brake_button, brake)
		var contacts_before: int = game.wall_contacts
		game._physics_process(STEP)
		if game.wall_contacts > contacts_before:
			var bin: int = int(fposmod(game.previous_road_distance, game.track_length) / 50.0) * 50
			contact_spots[bin] = int(contact_spots.get(bin, 0)) + 1
		top_speed = maxf(top_speed, game.speed)
		farthest_step = maxf(farthest_step, last_at.distance_to(game.player.position))
		last_at = game.player.position
		if lap_marks.size() < int(game.distance / game.track_length):
			lap_marks.append(game.elapsed)
		for i in range(game.opponents.size()):
			var wall: Vector2 = SIGNATURE.divider(track, game.opponent_distances[i])
			if wall.x > 0.3:
				var offset: float = absf(float(game.opponent_lanes[i]) - wall.y)
				if offset < wall.x + 0.4:
					divider_hits += 1
				var key := (
					"%d:%s"
					% [
						int(game.opponent_distances[i] / game.track_length),
						"rechts" if float(game.opponent_lanes[i]) > wall.y else "links"
					]
				)
				split_sides[key] = int(split_sides.get(key, 0)) + 1
		if (
			not shots.is_empty()
			and next_shot < marks.size()
			and game.distance > float(marks[next_shot])
		):
			game._update_camera(STEP, false)
			game._update_hud()
			RenderingServer.render_loop_enabled = true
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(
				shots.path_join("%s_rennen_%04d.jpg" % [track, int(marks[next_shot])]), 0.85
			)
			next_shot += 1
		if game.finished:
			break
		if tick % 240 == 0:
			await process_frame
	var player_time: float = game.elapsed
	var place: int = game._place()
	check(
		game.finished and game.checkpoint_index == 16,
		"Spieler: zwei Runden, 16 Checkpoints (%d)" % game.checkpoint_index
	)
	check(
		game.reset_count == 0 and farthest_step < 3.5,
		"durchgehende Fahrt ohne Rücksetzer (%d, %.2f m)" % [game.reset_count, farthest_step]
	)
	check(
		game.action_kicker_jumps >= 6 and game.landing_count >= 6,
		"Sprünge %d, Landungen %d" % [game.action_kicker_jumps, game.landing_count]
	)
	check(divider_hits == 0, "kein Rivale in einer Trennwand (%d)" % divider_hits)
	var scenery = world.get_node("SignatureEnvironment")
	var events: Dictionary = {}
	for key in ["eruptions", "fountain_bursts", "lightning", "waves"]:
		if scenery.parts.has(key):
			events[key] = scenery.parts[key]
	# Rivalen fahren nach dem Zieleinlauf zu Ende (gleiche KI, gleiche Welt).
	var finish_times: Array = []
	finish_times.resize(game.opponents.size())
	for i in range(game.opponents.size()):
		finish_times[i] = (
			player_time if game.opponent_distances[i] >= game.track_length * 2.0 else -1.0
		)
	var after := player_time
	for tick in range(60 * 150):
		if mode != "race" or game.opponents.is_empty():
			break
		game._drive_opponents(STEP)
		after += STEP
		var done := true
		for i in range(game.opponents.size()):
			if finish_times[i] < 0.0 and game.opponent_distances[i] >= game.track_length * 2.0:
				finish_times[i] = after
			done = done and finish_times[i] >= 0.0
		if done:
			break
		if tick % 600 == 0:
			await process_frame
	if mode == "race":
		check(
			finish_times.all(func(t): return float(t) > 0.0),
			"alle fünf Rivalen beenden beide Runden %s" % str(finish_times)
		)
	print(
		(
			(
				"[SignatureRace] %s %s %s: Platz %d, Zeit %.2f s, Runden %s, Spitze %.1f m/s, "
				+ "Sprünge %d, Landungen %d, Passagen-Stupser %d, Wandkontakte %d"
			)
			% [
				track,
				mode,
				difficulty,
				place,
				player_time,
				str(game.lap_times),
				top_speed,
				game.action_kicker_jumps,
				game.landing_count,
				game.passage_hits,
				game.wall_contacts
			]
		)
	)
	print(
		(
			"[SignatureRace] Rivalen im Ziel nach %s s; Abzweig-Seiten %s; Ereignisse %s"
			% [
				str(finish_times.map(func(t): return snappedf(float(t), 0.01))),
				str(split_sides),
				str(events)
			]
		)
	)
	print("[SignatureRace] Wandkontakte je 50 m: %s" % str(contact_spots))
	check(await TEARDOWN.release_scene(self, game, "[SignatureRace]"), "Szene freigegeben")
	print("[SignatureRace] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
