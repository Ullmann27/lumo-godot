extends SceneTree
## Reproducible full-race simulation to measure how exciting the rivals are.
## A fixed reference driver only holds gas and steers toward the road centre
## 10 m ahead (like a thumb on the stick: no drift, no boost, no items).
## Seeds are fixed, so a code change is measured, not guessed.
## Prints one "[RivalSim] {json}" line per difficulty; LUMO_RIVAL_SIM_OUT
## additionally writes the summaries as JSON. Then asserts that the default
## race is a real contest, Entdecken stays winnable and rivals stay fair.

const STEP := 1.0 / 60.0
const KART_SCENE := "res://scenes/games/kart_island.tscn"
const DIFFICULTIES := ["gemuetlich", "flott", "pro"]
const SAMPLE_EVERY := 30
const FRAME_CAP := 30000


func _initialize() -> void:
	call_deferred("_run")


func _order(game) -> Array[int]:
	# -1 is the child; 0..4 are rivals. Sorted by race progress, leader first.
	var progress: Array[Dictionary] = [{"id": -1, "distance": float(game.distance)}]
	for i in range(game.opponent_distances.size()):
		progress.append({"id": i, "distance": float(game.opponent_distances[i])})
	progress.sort_custom(func(a, b): return a.distance > b.distance)
	var ids: Array[int] = []
	for entry in progress:
		ids.append(int(entry.id))
	return ids


func _race(difficulty: String) -> Dictionary:
	var game = load(KART_SCENE).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.lightweight = true
	game.rng.seed = 1997
	seed(1997)
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": difficulty
		}
	)
	await process_frame
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	var frames := 0
	var previous: Array[int] = _order(game)
	var player_overtakes := 0
	var player_overtaken := 0
	var rival_swaps := 0
	var lead_changes := 0
	var close_samples := 0
	var samples := 0
	var max_lead_gap := 0.0
	var max_deficit := 0.0
	while not game.finished and frames < FRAME_CAP:
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
		game._physics_process(STEP)
		frames += 1
		if frames % SAMPLE_EVERY != 0:
			continue
		var order: Array[int] = _order(game)
		var before_player: int = previous.find(-1)
		var now_player: int = order.find(-1)
		if now_player < before_player:
			player_overtakes += before_player - now_player
		elif now_player > before_player:
			player_overtaken += now_player - before_player
		var rivals_before: Array[int] = previous.filter(func(id): return id >= 0)
		var rivals_now: Array[int] = order.filter(func(id): return id >= 0)
		for slot in range(rivals_now.size()):
			if rivals_now[slot] != rivals_before[slot]:
				rival_swaps += 1
		if order[0] != previous[0]:
			lead_changes += 1
		var nearest := INF
		for i in range(game.opponent_distances.size()):
			nearest = minf(nearest, absf(float(game.opponent_distances[i]) - float(game.distance)))
		samples += 1
		if nearest < 15.0:
			close_samples += 1
		var best_rival := -INF
		for d in game.opponent_distances:
			best_rival = maxf(best_rival, float(d))
		max_lead_gap = maxf(max_lead_gap, float(game.distance) - best_rival)
		max_deficit = maxf(max_deficit, best_rival - float(game.distance))
		previous = order
		if frames % 600 == 0:
			await process_frame
	var final_order: Array[int] = _order(game)
	var summary := {
		"difficulty": difficulty,
		"finished": bool(game.finished),
		"seconds": snappedf(float(game.elapsed), 0.01),
		"player_place": final_order.find(-1) + 1,
		"player_overtakes": player_overtakes,
		"player_overtaken": player_overtaken,
		"rival_position_swaps": rival_swaps,
		"lead_changes": lead_changes,
		"share_within_15m": snappedf(float(close_samples) / maxf(1.0, samples), 0.001),
		"max_player_lead_m": snappedf(max_lead_gap, 0.1),
		"max_player_deficit_m": snappedf(max_deficit, 0.1),
		"resets": int(game.reset_count),
	}
	game.abandoned = true
	game.queue_free()
	await process_frame
	return summary


## Rivals far behind may push, but without a boost never faster than the
## child's own kart can drive in the same race.
func _fair_speed_cap() -> Array[String]:
	var problems: Array[String] = []
	var game = load(KART_SCENE).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.lightweight = true
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	await process_frame
	game.countdown = 0
	game.racing = true
	var rules: Dictionary = game.CATALOG.entry(game.CATALOG.DIFFICULTIES, "gemuetlich")
	var child_top: float = game.POWERTRAIN.top_speed(game.kart_factors, float(rules.speed))
	game.distance = 400.0
	for frame in range(240):
		for i in range(game.opponents.size()):
			game.opponent_boost_times[i] = 0.0
			game.opponent_items[i] = ""
		game._drive_opponents(STEP)
		for i in range(game.opponents.size()):
			var speed: float = float(game.opponents[i].motion_speed)
			if speed > child_top + 0.001:
				problems.append("rival %d drove %.2f m/s > child top %.2f" % [i, speed, child_top])
	game.abandoned = true
	game.queue_free()
	await process_frame
	return problems


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	var results: Dictionary = {}
	for difficulty in DIFFICULTIES:
		var summary: Dictionary = await _race(difficulty)
		results[difficulty] = summary
		print("[RivalSim] ", JSON.stringify(summary))
	var output := OS.get_environment("LUMO_RIVAL_SIM_OUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "  ") + "\n")
	var problems: Array[String] = await _fair_speed_cap()
	for difficulty in DIFFICULTIES:
		if not results[difficulty].finished:
			problems.append(difficulty + " race did not finish")
	# Generous bounds around the measured 2026-10-22 tuning, not exact values.
	var easy: Dictionary = results.gemuetlich
	if easy.player_place != 1 or easy.max_player_lead_m > 400.0:
		problems.append("Entdecken must stay winnable with rivals in reach: %s" % easy)
	var normal: Dictionary = results.flott
	if normal.share_within_15m < 0.5 or normal.lead_changes < 4:
		problems.append("Abenteuer must be a real contest: %s" % normal)
	var expert: Dictionary = results.pro
	if expert.share_within_15m < 0.6 or expert.max_player_lead_m > 60.0:
		problems.append("Sternen-Profi must stay demanding: %s" % expert)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	# Let tree-level tweens and timers of the freed races end before quitting,
	# otherwise their resources are reported as still in use at exit.
	await create_timer(1.0).timeout
	if problems.is_empty():
		print(
			"[RivalRace] PASS: contested default race, winnable Entdecken, demanding Profi, fair speed cap"
		)
		quit(0)
	else:
		for problem in problems:
			push_error("[RivalRace] " + problem)
		print("[RivalRace] FAIL: ", problems.size())
		quit(1)
