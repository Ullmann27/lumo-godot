extends SceneTree
## „LUMO Sternenkompass“: Ziehung genau einmal beim Einsammeln, Darstellung ändert nichts.
## Prüft die Zeitkurve (3,5 s, Abbremsen), das Endsymbol = Ergebnis, dass die Animation
## keinen Spiel-Zufall verbraucht, Überspringen per Tipp, keine Item-Nutzung während der
## Ziehung, Pause, Speichern/Laden, zweites Prisma, volles Inventar, Rennende, reduzierte
## Bewegung und die Bedienfläche. Echtes Rennen (Sonnenhafen, headless, Physik-Schritte).
const COMPASS = preload("res://scripts/games/kart_items/kart_star_compass.gd")
const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const STEP := 1.0 / 60.0

var game
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("[KartStarCompass] FAIL ", label)
	return condition


func _timing() -> void:
	var seconds: float = COMPASS.duration(false)
	_check(
		seconds >= COMPASS.MIN_SECONDS and seconds <= COMPASS.MAX_SECONDS,
		"Standard 3,2–4,0 s (%.2f)" % seconds
	)
	_check(COMPASS.duration(true) <= 0.35, "reduzierte Bewegung höchstens 0,35 s")
	var times: PackedFloat32Array = COMPASS.tick_times(seconds)
	_check(is_equal_approx(times[times.size() - 1], seconds), "letzter Wechsel genau am Ende")
	var previous := 0.0
	var last_interval := 0.0
	var growing := true
	for k in range(times.size()):
		var interval: float = times[k] - previous
		if k > 0 and interval + 0.0001 < last_interval:
			growing = false
		last_interval = interval
		previous = times[k]
	_check(growing, "Wechsel werden stetig langsamer")
	_check(
		last_interval >= 0.45,
		"letzter Wechsel ≥ 0,45 s – klar erkennbares Abbremsen (%.2f)" % last_interval
	)
	_check(times[0] <= 0.08, "Start schnell (%.3f s)" % times[0])
	var in_last_half: int = 0
	for at in times:
		if at > seconds - 0.5:
			in_last_half += 1
	_check(in_last_half <= 1, "in den letzten 0,5 s höchstens ein Wechsel (%d)" % in_last_half)
	for id in CATALOG.ids():
		for draw in range(6):
			var final: String = COMPASS.symbol_for_step(id, times.size(), times.size(), draw)
			if not _check(
				final == id, "Endsymbol = Ergebnis (%s, Ziehung %d → %s)" % [id, draw, final]
			):
				return


func _start_race() -> void:
	game.race_seed = 777
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
	game.paused = false
	game.finished = false
	game.auto_gas = true


func _drive_to_prism() -> int:
	var index := -1
	for i in range(game.catalog_boxes.size()):
		if is_zero_approx(game.catalog_box_laterals[i]):
			index = i
			break
	var d: float = game.catalog_box_distances[index]
	game.distance = d - 30.0
	game.previous_road_distance = d - 30.0
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(d - 30.0, 0.0)
	game.player_heading = game._heading(d - 30.0)
	game.speed = 0.0
	var frames := 0
	while frames < 600 and str(game.item).is_empty():
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, 0)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(
			-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
		)
		game._physics_process(STEP)
		frames += 1
	game.steering = 0.0
	return index


func _clear() -> void:
	game.item = ""
	game.item_charges = 0
	game.item_roulette_time = 0.0
	game.star_compass.clear()
	game._sync_player_rocket_phase()


func _one_draw_and_no_rng() -> void:
	_clear()
	var draws_before: int = game.item_telemetry.draws.size()
	var box: int = _drive_to_prism()
	_check(box >= 0 and not game.catalog_boxes[box].visible, "Prisma beim Durchfahren eingesammelt")
	var result: String = str(game.item)
	_check(CATALOG.has(result), "Ergebnis steht sofort fest (%s)" % result)
	_check(game.item_telemetry.draws.size() == draws_before + 1, "genau eine Ziehung")
	_check(game.item_roulette_time > 3.0, "Kompass läuft (%.2f s)" % game.item_roulette_time)
	var shatter: bool = false
	for child in game.race_root.get_children():
		if child.name.begins_with("PrismShatter"):
			shatter = true
	_check(shatter, "Prisma zerfällt in Lichtsplitter")
	var compass: Dictionary = game.star_compass.hud_state(game.item_roulette_time, null)
	_check(
		not compass.is_empty() and str(compass.result) == result, "HUD-Zustand trägt das Ergebnis"
	)
	# Nur die Darstellung fortschreiben: Spiel-Zufall bleibt unberührt.
	var rng_state: int = game.rng.state
	var phases: Dictionary = {}
	var item_changes := 0
	var used_before: int = int(game.gameplay_stats.get("items_used", 0))
	var frames := 0
	while game.item_roulette_time > 0.0 and frames < 400:
		var shown: String = str(game.item)
		game._update_item_experience(STEP)
		game._update_item_hud(STEP)
		var state: Dictionary = game.item_hud.state.get("compass", {})
		phases[COMPASS.phase_of(state)] = true
		if str(game.item) != shown:
			item_changes += 1
		frames += 1
	_check(game.rng.state == rng_state, "Animation verbraucht keinen Spiel-Zufall")
	_check(
		item_changes == 0 and str(game.item) == result,
		"Ergebnis ändert sich während der Animation nie"
	)
	var seconds: float = frames * STEP
	_check(seconds >= 3.2 and seconds <= 4.0, "Ziehung dauert %.2f s" % seconds)
	for phase in ["fast", "slowing", "settle"]:
		_check(phases.has(phase), "Phase %s sichtbar" % phase)
	game._update_item_hud(STEP)
	var after: Dictionary = game.item_hud.state.get("compass", {})
	_check(COMPASS.phase_of(after) == "result", "Abschluss zeigt das Ergebnis")
	_check(
		int(game.gameplay_stats.get("items_used", 0)) == used_before,
		"während der Ziehung nichts benutzt"
	)
	_check(game.item_roulette_time <= 0.0 and str(game.item) == result, "Item-Knopf danach nutzbar")


func _skip_and_no_use() -> void:
	_clear()
	game._grant_item_with_roulette("boost")
	var used_before: int = int(game.gameplay_stats.get("items_used", 0))
	var boost_before: float = game.boost_time
	game._use_item()
	_check(game.item_roulette_time <= 0.0, "Tipp aufs Feld zeigt das Ergebnis sofort")
	_check(
		str(game.item) == "boost" and game.boost_time == boost_before,
		"Überspringen benutzt das Item nicht"
	)
	_check(bool(game.star_compass.skipped), "Überspringen ist vermerkt")
	game._use_item()
	_check(
		str(game.item).is_empty() and game.boost_time > boost_before,
		"zweiter Tipp benutzt das Item"
	)
	_check(int(game.gameplay_stats.get("items_used", 0)) >= used_before, "Zähler konsistent")


func _pause_hold() -> void:
	_clear()
	game._grant_item_with_roulette("shield")
	game._update_item_experience(0.5)
	var left: float = game.item_roulette_time
	game.paused = true
	for frame in range(120):
		game._physics_process(STEP)
	_check(
		is_equal_approx(game.item_roulette_time, left),
		"Pause hält die Ziehung an (%.2f)" % game.item_roulette_time
	)
	_check(str(game.item) == "shield", "Pause zieht nicht neu")
	game._use_item()
	_check(game.item_roulette_time > 0.0, "in der Pause kein Überspringen/Benutzen")
	game.paused = false


func _save_and_load() -> void:
	_clear()
	game._grant_item_with_roulette("star_rocket")
	game._update_item_experience(1.0)
	var left: float = game.item_roulette_time
	var draws: int = game.item_telemetry.draws.size()
	game._save_session()
	game.item = "boost"
	game.item_roulette_time = 0.0
	var restored: bool = game._restore_session()
	_check(restored, "Sitzung wird geladen")
	_check(str(game.item) == "star_rocket", "geladen: dasselbe Ergebnis (%s)" % game.item)
	_check(
		absf(game.item_roulette_time - left) < 0.05,
		"geladen: Ziehung läuft weiter (%.2f/%.2f)" % [game.item_roulette_time, left]
	)
	_check(game.item_telemetry.draws.size() <= draws, "Laden erzeugt keine neue Ziehung")
	game.paused = false
	game.racing = true


func _second_prism_and_full() -> void:
	_clear()
	game._grant_item_with_roulette("pulse")
	var draws: int = game.item_telemetry.draws.size()
	var lap: int = int(game.distance / game.track_length)
	var other: int = -1
	for i in range(game.catalog_boxes.size()):
		if not game.catalog_box_collected.has(lap * game.catalog_boxes.size() + i):
			other = i
			break
	game.player.position = game.catalog_boxes[other].position
	game._collect_catalog_boxes(lap)
	_check(str(game.item) == "pulse", "zweites Prisma während der Ziehung ändert nichts")
	_check(game.item_telemetry.draws.size() == draws, "keine zweite Ziehung")
	_check(game.item_roulette_time > 0.0, "laufende Ziehung bleibt")
	game._finish_item_roulette(false)
	var next: int = -1
	for i in range(game.catalog_boxes.size()):
		if not game.catalog_box_collected.has(lap * game.catalog_boxes.size() + i):
			next = i
			break
	game.player.position = game.catalog_boxes[next].position
	game._collect_catalog_boxes(lap)
	_check(
		str(game.item) == "pulse" and game.item_roulette_time <= 0.0,
		"volles Feld: Item bleibt, kein Kompass"
	)


func _direct_grant_ends_compass() -> void:
	_clear()
	game._grant_item_with_roulette("pulse")
	game._grant_item("star_rocket")
	_check(
		game.item_roulette_time <= 0.0 and str(game.item) == "star_rocket",
		"direkt vergebenes Item beendet die alte Kompass-Darstellung"
	)
	game._use_item()
	_check(game.rocket_phase == "armed", "erster Tipp schärft danach sofort die Raketen")
	_clear()


func _race_end() -> void:
	_clear()
	game._grant_item_with_roulette("boost")
	game.finished = true
	game._use_item()
	_check(
		game.item_roulette_time > 0.0 and str(game.item) == "boost",
		"nach Rennende kein Benutzen/Überspringen"
	)
	game._update_item_experience(4.0)
	_check(game.item_roulette_time <= 0.0, "Kompass endet auch nach Rennende sauber")
	game.finished = false


func _reduced_motion() -> void:
	_clear()
	game.reduced_motion = true
	game._grant_item_with_roulette("shield")
	_check(game.item_roulette_time <= 0.35, "reduzierte Bewegung: %.2f s" % game.item_roulette_time)
	game.reduced_motion = false
	_clear()


func _touch_target() -> void:
	# 48 dp auf einem 360-dp-Handy = 96 px der 720er Projektbasis.
	var side: float = minf(
		game.item_button.custom_minimum_size.x, game.item_button.custom_minimum_size.y
	)
	_check(side >= 96.0, "Item-Feld ≥ 48 dp (%.0f px Basis)" % side)
	# Kart läuft quer: schmales Handy (2340×1080 → 1560×720 Basis) und Fold offen.
	for case in [
		[Vector2(1560, 720), Rect2(Vector2(1240, 560), Vector2(112, 112))],
		[Vector2(864, 720), Rect2(Vector2(560, 560), Vector2(112, 112))],
	]:
		var view: Vector2 = case[0]
		var item_rect: Rect2 = case[1]
		var place: Dictionary = COMPASS.layout(view, item_rect, 1.0)
		var radius: float = place.radius
		var centre: Vector2 = place.centre
		_check(radius * 2.0 >= 180.0, "Kompass groß genug (%.0f px Basis ≈ 90 dp)" % (radius * 2.0))
		_check(
			Rect2(Vector2.ZERO, view).encloses(
				Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			),
			"Kompass ganz im Bild %s" % view
		)
		_check(
			not Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0).intersects(
				item_rect
			),
			"Kompass verdeckt das Item-Feld nicht %s" % view
		)


func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"childKey": "star-compass"}
	_timing()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await _start_race()
	_one_draw_and_no_rng()
	_skip_and_no_use()
	_pause_hold()
	_save_and_load()
	_second_prism_and_full()
	_direct_grant_ends_compass()
	_race_end()
	_reduced_motion()
	_touch_target()
	game.abandoned = true
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[KartStarCompass] PASS: %d checks" % checks)
	else:
		print("[KartStarCompass] FAILED: %d of %d checks" % [failures.size(), checks])
	await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
