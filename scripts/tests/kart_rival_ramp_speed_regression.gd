extends SceneTree
## Ein Rivale, der hinter dem Kind liegt (Gummiband schiebt), fährt auf eine Rampe zu.
## Früher wurde der Schub vor der Rampe Takt für Takt aufmultipliziert (45 -> 273 m/s,
## Flug über rund 1.000 m). Geprüft wird das echte _drive_opponents auf Sonnenhafen
## in allen drei Stufen: Tempo bleibt unter der physikalischen Obergrenze, der Rivale
## gewinnt im Rampenfenster keine unmögliche Strecke.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RACECRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const STEP := 1.0 / 60.0
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("[KartRivalRamp] FAIL ", text)


func _run() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for level in ["gemuetlich", "flott", "pro"]:
		game.race_seed = 5
		game._start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": "sonnenhafen",
				"difficulty": level
			}
		)
		await process_frame
		game.countdown = 0.0
		game.racing = true
		var kickers: Array = game.world.action.get("kickers", [])
		_check(not kickers.is_empty(), "%s: Sonnenhafen hat Rampen" % level)
		if kickers.is_empty():
			continue
		var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, level)
		var take_off: float = float(kickers[0].take_off)
		var start: float = take_off - 120.0
		# Kind 150 m vor dem Rivalen: der Rivale bekommt den vollen Gummiband-Schub.
		game.distance = start + 150.0
		game.previous_road_distance = start + 150.0
		game.player.transform = game.world.reset_transform(start + 150.0)
		for index in range(game.opponents.size()):
			var at: float = start - 40.0 * float(index)
			game.opponent_distances[index] = at
			game.opponent_headings[index] = game._heading(at)
			game.opponents[index].transform = game.world.reset_transform(
				at, -1.7 + 0.85 * float(index % 4)
			)
			game.opponents[index].set_motion(
				RACECRAFT.cruise_speed(game.opponents[index].kart_style, rules), 0, false, false
			)
		var worst_ratio: float = 0.0
		var worst_gain: float = 0.0
		for _frame in range(240):
			var before: Array[float] = []
			for index in range(game.opponents.size()):
				before.append(float(game.opponent_distances[index]))
			game.distance = start + 150.0
			game._drive_opponents(STEP)
			for index in range(game.opponents.size()):
				var top: float = POWERTRAIN.top_speed(
					RACECRAFT.factors(game.opponents[index].kart_style), float(rules.speed)
				)
				# Obergrenze: Turbo 1,32 x Nordlicht 1,2 x voller Gummiband-Schub 1,10.
				var ceiling: float = top * 1.32 * 1.2 * 1.1
				worst_ratio = maxf(
					worst_ratio, absf(float(game.opponents[index].motion_speed)) / ceiling
				)
				worst_gain = maxf(
					worst_gain,
					(float(game.opponent_distances[index]) - before[index]) / (ceiling * STEP)
				)
		_check(
			worst_ratio <= 1.0,
			(
				"%s: Rivalen-Tempo an der Rampe bleibt unter der Obergrenze (%.2f)"
				% [level, worst_ratio]
			)
		)
		_check(
			worst_gain <= 1.05,
			"%s: kein Streckensprung im Rampenfenster (%.2f)" % [level, worst_gain]
		)
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	var report := {
		"test": "kart_rival_ramp_speed",
		"checks": checks,
		"failures": failures,
		"status": "PASS" if failures.is_empty() else "FAIL"
	}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
