extends SceneTree
## Gegner-KI auf allen Strecken: fünf Rivalen fahren zwei echte Runden mit der
## Produktionsphysik (game._physics_process), das Kind-Kart parkt am Rand der
## Startgeraden. Damit kein Gummiband die Zeiten verfälscht, zählt der
## Fortschritt des Kindes jeden Takt als gleichauf mit dem führenden Rivalen.
## Geprüft je Strecke und Stufe:
##   alle fünf kommen ins Ziel, kein 15-s-Fenster ohne Fortschritt (Hängenbleiben),
##   kein Sprung > 1,5 m je Takt, kein Tempo-Sprung über die Antriebsgrenze,
##   Stufen klar getrennt (mittlere Rundenzeit Entdecken > Abenteuer > Extrem),
##   Überholvorgänge zwischen Rivalen, Item-Einsatz, kleine Fehler, Windschatten.
## Eine JSON-Zeile je Lauf mit --out=/abs/datei.jsonl.
## godot --headless --path . --script res://scripts/tests/kart_rival_ai_regression.gd \
##     -- --tracks=sonnenhafen,zauberwald
const STEP := 1.0 / 60.0
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const CRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const STALL_WINDOW := 15.0
const STALL_METRES := 8.0
const MAX_STEP_M := 1.5
## Minimum separation of mean rival lap times between neighbouring levels.
const MIN_LEVEL_GAP := 0.03

var tracks: Array[String] = []
var levels: Array[String] = ["gemuetlich", "flott", "pro"]
var out_path: String = ""
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var text: String = str(argument)
		if text.begins_with("--tracks="):
			tracks.assign(text.trim_prefix("--tracks=").split(","))
		elif text.begins_with("--levels="):
			levels.assign(text.trim_prefix("--levels=").split(","))
		elif text.begins_with("--out="):
			out_path = text.trim_prefix("--out=")
	if tracks.is_empty():
		tracks.assign(TRACKS.IDS)
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[KartRivalAI] FAIL " + label)


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "rival-ai-regression"}
	var totals: Dictionary = {}
	for level in levels:
		totals[level] = {
			"overtakes": 0, "items": 0, "mistakes": 0, "slipstreams": 0, "yields": 0, "races": 0
		}
	for track in tracks:
		var means: Dictionary = {}
		for level in levels:
			var row: Dictionary = await _race(track, level)
			means[level] = float(row.mean_finish)
			var sums: Dictionary = totals[level]
			sums.overtakes += int(row.overtakes)
			sums.items += int(row.items)
			sums.mistakes += int(row.mistakes)
			sums.slipstreams += int(row.slipstreams)
			sums.races += 1
			_write(row)
			print(
				(
					(
						"[KartRivalAI] %s %s: Ziel %s s (Mittel %.2f), Überholen %d, Items %d,"
						+ " Fehler %d, Windschatten %d, Stillstand %d, max Schritt %.2f m,"
						+ " max Schub %.1f m/s²"
					)
					% [
						track,
						level,
						str(row.finish),
						row.mean_finish,
						row.overtakes,
						row.items,
						row.mistakes,
						row.slipstreams,
						row.stalls,
						row.max_step,
						row.max_accel
					]
				)
			)
		for pair in [["gemuetlich", "flott"], ["flott", "pro"]]:
			if means.has(pair[0]) and means.has(pair[1]):
				var slower: float = float(means[pair[0]])
				var faster: float = float(means[pair[1]])
				_check(
					slower > faster * (1.0 + MIN_LEVEL_GAP),
					(
						"%s: %s (%.2f s) clearly slower than %s (%.2f s)"
						% [track, pair[0], slower, pair[1], faster]
					)
				)
	for level in levels:
		var sums: Dictionary = totals[level]
		print("[KartRivalAI] SUMME %s: %s" % [level, JSON.stringify(sums)])
		if int(sums.races) >= 3:
			_check(int(sums.overtakes) > 0, "%s: rivals overtake each other" % level)
			_check(int(sums.items) > 0, "%s: rivals use items" % level)
			_check(
				int(sums.mistakes) > 0 or level == "pro", "%s: rivals make small mistakes" % level
			)
			if level != "gemuetlich":
				_check(int(sums.slipstreams) > 0, "%s: rivals use the slipstream" % level)
	if totals.has("gemuetlich") and totals.has("pro") and int(totals.gemuetlich.races) >= 3:
		_check(
			int(totals.gemuetlich.mistakes) > int(totals.pro.mistakes),
			"Entdecken rivals make more mistakes than Extrem rivals"
		)
	if failures.is_empty():
		print(
			(
				"[KartRivalAI] PASS %d checks on %d tracks x %d levels"
				% [checks, tracks.size(), levels.size()]
			)
		)
		quit(0)
	else:
		print("[KartRivalAI] FAIL ", failures)
		quit(1)


func _write(row: Dictionary) -> void:
	if out_path.is_empty():
		return
	var file := FileAccess.open(out_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()


func _race(track: String, level: String) -> Dictionary:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.race_seed = 7
	await process_frame
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": level}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.gas_held = false
	game.speed = 0.0
	game.player.transform = Transform3D(game.world.frame(0.0), game.world.position_at(0.0, -4.6))
	await process_frame
	var count: int = game.opponents.size()
	var length: float = float(game.track_length)
	var goal: float = length * 2.0
	var max_seconds: float = maxf(240.0, goal / 12.0)
	var finish: Array[float] = []
	var last_window: Array[float] = []
	var previous_position: Array[Vector3] = []
	var previous_speed: Array[float] = []
	var stalls: int = 0
	var max_step: float = 0.0
	var max_accel: float = 0.0
	var order: Array[int] = []
	var overtakes: int = 0
	for i in range(count):
		finish.append(-1.0)
		last_window.append(game.opponent_distances[i])
		previous_position.append(game.opponents[i].position)
		previous_speed.append(absf(game.opponents[i].motion_speed))
	var seconds: float = 0.0
	var frame: int = 0
	while seconds < max_seconds:
		var leader: float = -INF
		for i in range(count):
			leader = maxf(leader, float(game.opponent_distances[i]))
		# Level with the leader, but never at the line: the child's race must not end.
		game.distance = clampf(leader, 0.0, goal - 40.0)
		game._physics_process(STEP)
		seconds += STEP
		frame += 1
		var done: int = 0
		for i in range(count):
			var rival = game.opponents[i]
			if finish[i] >= 0.0:
				done += 1
				continue
			var moved: float = rival.position.distance_to(previous_position[i])
			var free: bool = (
				not rival.has_meta(&"lumo_ballistic_flight")
				or not rival.get_meta(&"lumo_ballistic_flight").active
			)
			var looping: bool = (
				rival.has_meta(&"lumo_physical_loop")
				and rival.get_meta(&"lumo_physical_loop").active
			)
			if free and not looping:
				max_step = maxf(max_step, moved)
				var speed_now: float = absf(rival.motion_speed)
				if frame > 2:
					max_accel = maxf(max_accel, (speed_now - previous_speed[i]) / STEP)
				previous_speed[i] = speed_now
			else:
				previous_speed[i] = absf(rival.motion_speed)
			previous_position[i] = rival.position
			if game.opponent_distances[i] >= goal:
				finish[i] = seconds
		if frame % int(STALL_WINDOW / STEP) == 0:
			for i in range(count):
				if finish[i] < 0.0 and game.opponent_distances[i] - last_window[i] < STALL_METRES:
					stalls += 1
					print(
						(
							"[KartRivalAI] STILLSTAND %s %s rival%d bei %.1f m (t=%.0f s)"
							% [track, level, i, game.opponent_distances[i], seconds]
						)
					)
				last_window[i] = game.opponent_distances[i]
		if frame % 30 == 0 and seconds > 5.0:
			var now_order: Array[int] = _order(game)
			if not order.is_empty():
				overtakes += _swaps(order, now_order, finish)
			order = now_order
		if done == count:
			break
		if frame % 240 == 0:
			await process_frame
	var stats: Dictionary = game.gameplay_stats.duplicate(true)
	var finished_times: Array[float] = []
	for value in finish:
		if value >= 0.0:
			finished_times.append(value)
	var mean: float = 0.0
	for value in finished_times:
		mean += value
	mean = mean / maxf(1.0, float(finished_times.size()))
	var mistakes: int = 0
	var slipstreams: int = 0
	var braking: int = 0
	for rival in game.opponents:
		mistakes += int(rival.get_meta(&"mistakes", 0))
		slipstreams += int(rival.get_meta(&"slipstreams", 0))
	var top: float = POWERTRAIN.top_speed(game.kart_factors, 1.17)
	var thrust_cap: float = POWERTRAIN.acceleration({"accel": 1.35}, false) * 1.02
	_check(
		finished_times.size() == count,
		"%s %s: all rivals finish two laps (%d/%d)" % [track, level, finished_times.size(), count]
	)
	_check(stalls == 0, "%s %s: no rival gets stuck (%d stalled windows)" % [track, level, stalls])
	_check(
		max_step <= MAX_STEP_M, "%s %s: no rival jumps (%.2f m per tick)" % [track, level, max_step]
	)
	_check(
		max_accel <= thrust_cap,
		"%s %s: rivals accelerate with their drivetrain (%.1f m/s²)" % [track, level, max_accel]
	)
	var row := {
		"track": track,
		"level": level,
		"track_length_m": snappedf(length, 0.1),
		"finish": finish.map(func(v: float) -> float: return snappedf(v, 0.01)),
		"mean_finish": snappedf(mean, 0.01),
		"mean_lap": snappedf(mean * 0.5, 0.01),
		"spread":
		(
			snappedf(finished_times.max() - finished_times.min(), 0.01)
			if not finished_times.is_empty()
			else -1.0
		),
		"overtakes": overtakes,
		"items": int(stats.get("rival_items_used", 0)),
		"mistakes": mistakes,
		"slipstreams": slipstreams,
		"stalls": stalls,
		"max_step": snappedf(max_step, 0.001),
		"max_accel": snappedf(max_accel, 0.1),
		"child_top_speed": snappedf(top, 0.01),
		"stats": stats,
	}
	game.abandoned = true
	game.queue_free()
	await process_frame
	await process_frame
	return row


## Rival indices in race order (front first).
func _order(game) -> Array[int]:
	var indices: Array[int] = []
	for i in range(game.opponents.size()):
		indices.append(i)
	indices.sort_custom(
		func(a: int, b: int) -> bool: return game.opponent_distances[a] > game.opponent_distances[b]
	)
	return indices


## Pairwise order changes between two samples among rivals still racing.
func _swaps(before: Array[int], after: Array[int], finish: Array[float]) -> int:
	var swaps: int = 0
	for a in range(before.size()):
		for b in range(a + 1, before.size()):
			var front: int = before[a]
			var back: int = before[b]
			if finish[front] >= 0.0 or finish[back] >= 0.0:
				continue
			if after.find(back) < after.find(front):
				swaps += 1
	return swaps
