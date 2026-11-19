extends SceneTree
## Monte-Carlo-Beleg der Item-Quoten je Rennplatz und Stufe (feste Startwerte).
## Gezogen wird über die echte Spielfunktion kart_island._roll_catalog_item (Gewichte aus
## kart_items.json + Aufholhilfe nach Abstand zum Führenden). Je Stufe wird das echte
## Rennen gebaut; je Platz 1–6 werden DRAWS Ziehungen gemacht, der Abstand zum Führenden
## ist mit eigenem festen Startwert gleichverteilt 0–150 m (Platz 1: 0 m).
## Zielquoten für Sternraketen (vor der Messung festgelegt, siehe TARGETS) werden geprüft.
## `--draws=4000`, `--report=<json>`, `--no-targets` (nur messen, z. B. für „vorher“).
const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const ROCKET := "star_rocket"
const DIFFICULTIES: Array[String] = ["gemuetlich", "flott", "pro"]
## Zielquoten Sternraketen je Platz [min, max]: Platz 1 selten (nicht unmöglich), Plätze 2–6
## deutlich häufiger als vorher, hinten nicht über 30 %, damit Schild, Turbo und Aufholhilfen
## (Kometen-Trio, Nordlicht) für die Letzten wichtig bleiben.
const TARGETS: Dictionary = {
	1: [0.03, 0.08],
	2: [0.15, 0.23],
	3: [0.22, 0.31],
	4: [0.22, 0.31],
	5: [0.22, 0.31],
	6: [0.22, 0.31],
}

var game
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--%s=" % name):
			return str(argument).trim_prefix("--%s=" % name)
		if str(argument) == "--%s" % name:
			return "1"
	return fallback


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("[KartRocketOdds] FAIL ", label)
	return condition


## Rivalen so legen, dass das Kind auf Platz `place` liegt, Führender `gap` m voraus.
func _arrange(place: int, gap: float) -> void:
	game.distance = 2000.0
	var ahead: int = place - 1
	for i in range(game.opponent_distances.size()):
		if i < ahead:
			game.opponent_distances[i] = (
				2000.0 + gap * (1.0 - float(i) / maxf(1.0, float(ahead))) + 0.5
			)
		else:
			game.opponent_distances[i] = 2000.0 - 5.0 - float(i)


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "rocket-odds"}
	var draws: int = int(_arg("draws", "4000"))
	var report: String = _arg("report", "")
	var check_targets: bool = _arg("no-targets", "") != "1"
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	var table: Dictionary = {}
	var gap_rng := RandomNumberGenerator.new()
	for difficulty in DIFFICULTIES:
		game.race_seed = 4242
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
		table[difficulty] = {}
		for place in range(1, 7):
			game.rng.seed = 20261119 + place * 101 + DIFFICULTIES.find(difficulty) * 7
			gap_rng.seed = 911 + place
			var counts: Dictionary = {}
			for n in range(draws):
				var gap: float = 0.0 if place == 1 else gap_rng.randf_range(0.0, 150.0)
				_arrange(place, gap)
				if n == 0:
					_check(game._place() == place, "Aufstellung Platz %d" % place)
				var id: String = game._roll_catalog_item(place)
				counts[id] = int(counts.get(id, 0)) + 1
			var shares: Dictionary = {}
			for id in counts:
				shares[id] = snappedf(float(counts[id]) / float(draws), 0.0001)
			table[difficulty][str(place)] = {"draws": draws, "shares": shares}
			var rocket: float = float(shares.get(ROCKET, 0.0))
			print(
				(
					"[KartRocketOdds] %s Platz %d: Raketen %.1f %% (%d Ziehungen)"
					% [difficulty, place, rocket * 100.0, draws]
				)
			)
			if check_targets:
				var band: Array = TARGETS[place]
				_check(
					rocket >= float(band[0]) and rocket <= float(band[1]),
					(
						"%s Platz %d Raketen %.1f %% im Ziel %.0f–%.0f %%"
						% [
							difficulty,
							place,
							rocket * 100.0,
							float(band[0]) * 100.0,
							float(band[1]) * 100.0
						]
					)
				)
	var analytic: Dictionary = {}
	for place in range(1, 7):
		analytic[str(place)] = CATALOG.odds(place)
	if not report.is_empty():
		var file := FileAccess.open(report, FileAccess.WRITE)
		if file != null:
			file.store_string(
				JSON.stringify(
					{
						"draws_per_cell": draws,
						"monte_carlo": table,
						"weights_only": analytic,
						"targets": TARGETS
					},
					"  "
				)
			)
	game.abandoned = true
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[KartRocketOdds] PASS: %d checks, %d Ziehungen je Platz und Stufe" % [checks, draws])
	else:
		print("[KartRocketOdds] FAILED: %d of %d checks" % [failures.size(), checks])
	await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
