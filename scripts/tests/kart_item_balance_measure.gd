extends SceneTree
## Balance-Messung der Zufallsprismen (headless, feste Startwerte, volle Rennen).
## Je Strecke × Stufe × Startwert ein echtes Rennen über zwei Runden mit fünf Rivalen.
## Das Test-Kind lenkt physikalisch: mit leerem Item-Feld auf das nächste sichtbare
## Prisma voraus, sonst auf die Mitte; Items nutzt es nach kurzer Pause (Raketen:
## scharf schalten, nach Zielerfassung feuern). Gemessen wird aus dem Item-Protokoll
## (kart_item_telemetry.gd): Zonen und Prismen je Runde, Ziehungen je Fahrer und
## Runde, Item-Verteilung je Platz, Raketensalven (Kind/Rivalen), Treffer auf das Kind,
## längste Zeit ohne Item.
## Argumente: --tracks=a,b  --difficulties=gemuetlich,flott,pro  --seeds=1,2
##            --report=<json>  --max-seconds=260
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const STEP := 1.0 / 60.0
const ROCKET := "star_rocket"

var game
var rows: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--%s=" % name):
			return str(argument).trim_prefix("--%s=" % name)
	return fallback


func _zone_count() -> int:
	var seen: Dictionary = {}
	for d in game.catalog_box_distances:
		seen[snappedi(roundi(float(d)), 4)] = true
	var keys: Array = seen.keys()
	keys.sort()
	# Prismen einer Reihe liegen innerhalb weniger Meter: Nachbarn zusammenfassen.
	var zones := 0
	var last := -1000.0
	for key in keys:
		if float(key) - last > 12.0:
			zones += 1
		last = float(key)
	return zones


func _target_lane() -> float:
	var here: float = fposmod(game.previous_road_distance, game.track_length)
	var lap: int = int(game.distance / game.track_length)
	var best := INF
	var lane := 0.0
	if str(game.item).is_empty():
		for i in range(game.catalog_boxes.size()):
			if game.catalog_box_collected.has(lap * game.catalog_boxes.size() + i):
				continue
			var ahead: float = fposmod(
				float(game.catalog_box_distances[i]) - here, game.track_length
			)
			if ahead < 3.0 or ahead > 55.0:
				continue
			var score: float = (
				ahead + absf(float(game.catalog_box_laterals[i]) - float(game.lane)) * 4.0
			)
			if score < best:
				best = score
				lane = float(game.catalog_box_laterals[i])
	var wall: float = float(game._wall_lateral_at(here)) - 1.3
	return clampf(lane, -maxf(0.0, wall), maxf(0.0, wall))


func _race(track: String, difficulty: String, race_seed: int, max_seconds: float) -> Dictionary:
	game.race_seed = race_seed
	game._start_selected_race(
		{"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": difficulty}
	)
	await process_frame
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.auto_gas = true
	var frames := 0
	var hold := 0.0
	var armed_for := 0.0
	var empty_run := 0.0
	var longest_empty := 0.0
	var lane_goal := 0.0
	while not game.finished and frames < int(max_seconds * 60.0):
		if frames % 6 == 0:
			lane_goal = _target_lane()
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, lane_goal)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.3, -1, 1)
		# Item-Verhalten des Test-Kinds.
		if str(game.item).is_empty():
			hold = 0.0
			armed_for = 0.0
			empty_run += STEP
			longest_empty = maxf(longest_empty, empty_run)
		else:
			empty_run = 0.0
			if game.item_roulette_time <= 0.0:
				hold += STEP
				if str(game.item) == ROCKET and game.rocket_phase == "armed":
					armed_for += STEP
					if game.lock_progress >= 1.0 or armed_for > 3.0:
						game._use_item()
						armed_for = 0.0
				elif hold > 1.2:
					game._use_item()
					hold = 0.0
		game._physics_process(STEP)
		frames += 1
		if frames % 120 == 0:
			await process_frame
	var t = game.item_telemetry
	var laps: float = clampf(game.distance / game.track_length, 0.01, 2.0)
	var row := {
		"track": track,
		"difficulty": difficulty,
		"seed": race_seed,
		"length_m": roundi(game.track_length),
		"finished": bool(game.finished),
		"seconds": snappedf(game.elapsed, 0.1),
		"laps": snappedf(laps, 0.01),
		"zones_per_lap": _zone_count(),
		"prisms_per_lap": game.catalog_boxes.size(),
		"resets": int(game.reset_count),
		"place": int(game.result_payload.get("place", game._place())),
		"longest_empty_s": snappedf(longest_empty, 0.1),
	}
	var child_draws := 0
	var rival_draws := 0
	var by_place: Dictionary = {}
	var by_who: Dictionary = {}
	for draw in t.draws:
		if int(draw.who) == -1:
			child_draws += 1
		else:
			rival_draws += 1
		var key := str(int(draw.place))
		if not by_place.has(key):
			by_place[key] = {}
		by_place[key][str(draw.item)] = int(by_place[key].get(str(draw.item), 0)) + 1
		var who_key: String = ("K" if int(draw.who) == -1 else "R") + key
		if not by_who.has(who_key):
			by_who[who_key] = {}
		by_who[who_key][str(draw.item)] = int(by_who[who_key].get(str(draw.item), 0)) + 1
	row["child_draws"] = child_draws
	row["child_draws_per_lap"] = snappedf(float(child_draws) / laps, 0.01)
	row["rival_draws_per_rival_lap"] = snappedf(float(rival_draws) / maxf(1.0, 5.0 * laps), 0.01)
	row["child_full_touches"] = t.full_touches.filter(func(x): return int(x.who) == -1).size()
	row["draws_by_place"] = by_place
	row["draws_by_who_place"] = by_who
	var child_salvos := 0
	var rival_salvos := 0
	var rival_salvos_at_child := 0
	for salvo in t.salvos:
		if int(salvo.who) == -1:
			child_salvos += 1
		else:
			rival_salvos += 1
			if int(salvo.target) == -1:
				rival_salvos_at_child += 1
	row["child_salvos"] = child_salvos
	row["rival_salvos"] = rival_salvos
	row["rival_salvos_at_child"] = rival_salvos_at_child
	# Jeder Einschlag meldet erst "hit"; wird er abgefangen (Schonzeit, Trefferpause,
	# Sturzstelle), folgt sofort "grace" – dann zählt er nicht als Treffer.
	var hits: Array[Dictionary] = []
	var grace_on_child := 0
	var blocked_on_child := 0
	for event in t.events:
		if int(event.target) != -1:
			continue
		match str(event.type):
			"hit":
				hits.append(event)
			"grace":
				grace_on_child += 1
				if not hits.is_empty() and is_equal_approx(float(hits.back().t), float(event.t)):
					hits.pop_back()
			"blocked":
				blocked_on_child += 1
	var hit_times: Array[float] = []
	var rocket_hits_on_child := 0
	for hit in hits:
		hit_times.append(float(hit.t))
		if str(hit.item) == ROCKET:
			rocket_hits_on_child += 1
	row["hits_on_child"] = hits.size()
	row["rocket_hits_on_child"] = rocket_hits_on_child
	row["grace_absorbed_on_child"] = grace_on_child
	row["blocked_on_child"] = blocked_on_child
	row["child_hits_scored"] = int(game.gameplay_stats.get("player_hits_scored", 0))
	var shortest_gap := INF
	for i in range(1, hit_times.size()):
		shortest_gap = minf(shortest_gap, hit_times[i] - hit_times[i - 1])
	row["shortest_hit_gap_s"] = -1.0 if shortest_gap == INF else snappedf(shortest_gap, 0.01)
	return row


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "items-balance"}
	var tracks: Array[String] = []
	for id in _arg("tracks", ",".join(TRACKS.IDS)).split(","):
		tracks.append(id)
	var difficulties: PackedStringArray = _arg("difficulties", "gemuetlich,flott,pro").split(",")
	var seeds: PackedStringArray = _arg("seeds", "20261119").split(",")
	var max_seconds: float = float(_arg("max-seconds", "260"))
	var report: String = _arg("report", "")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	var started: int = Time.get_ticks_msec()
	for track in tracks:
		for difficulty in difficulties:
			for seed_text in seeds:
				var row: Dictionary = await _race(track, difficulty, int(seed_text), max_seconds)
				rows.append(row)
				var short := row.duplicate()
				short.erase("draws_by_place")
				short.erase("draws_by_who_place")
				print("[KartItemBalance] ", JSON.stringify(short))
				if not report.is_empty():
					var file := FileAccess.open(report, FileAccess.WRITE)
					if file != null:
						file.store_string(JSON.stringify({"rows": rows}, "  "))
	var spent: float = (Time.get_ticks_msec() - started) / 1000.0
	print("[KartItemBalance] DONE %d races in %.1f s" % [rows.size(), spent])
	await process_frame
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit(0)
