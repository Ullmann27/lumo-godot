extends SceneTree
## Lumos Sternenpost (headless): registration, address riddles, the soft
## world (no crash anywhere), the flight bot delivering every letter on all three
## stages, wrong house and miss with help, the cloud race to the finish on all
## stages (rivals never stuck), free flight (secret stars, photo spots, album),
## save and continue, child switch, result and stars exactly once.
##
##   godot --headless --path . --script res://scripts/tests/sky_post_regression.gd [-- only=delivery,race]

const BOT = preload("res://scripts/tests/helpers/sky_post_bot.gd")
const ADDRESSES = preload("res://scripts/games/skypost/sky_post_addresses.gd")
const LAYOUT = preload("res://scripts/games/skypost/sky_post_layout.gd")
const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")
const SESSION = preload("res://scripts/games/skypost/sky_post_session.gd")
const STEP: float = 1.0 / 60.0

var checks: int = 0
var failures: Array[String] = []
var router: Node
var bridge: Node
var scene: PackedScene
var rewards: Array[Dictionary] = []
var only: PackedStringArray = []
var step_ms: Array[float] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.trim_prefix("only=").split(",")
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[SkyPost] ok: " + label)
	else:
		failures.append(label)
		print("[SkyPost] FAILED CHECK: " + label)


func _wanted(part: String) -> bool:
	return only.is_empty() or only.has(part)


func _run() -> void:
	router = root.get_node("SceneRouter")
	bridge = root.get_node("HostBridge")
	bridge.reward_reported.connect(func(payload: Dictionary) -> void: rewards.append(payload))
	scene = load("res://scenes/games/sky_post.tscn")
	if _wanted("register"):
		_test_registration()
	if _wanted("riddles"):
		_test_riddles()
	if _wanted("layout"):
		_test_layout()
	if _wanted("delivery"):
		for stage in TUNING.STAGES:
			await _test_delivery(stage)
	if _wanted("help"):
		await _test_wrong_and_miss()
	if _wanted("race"):
		for stage in TUNING.STAGES:
			await _test_race(stage)
	if _wanted("free"):
		await _test_free()
	if _wanted("save"):
		await _test_save_and_children()
	if _wanted("safe"):
		await _test_never_crash()
	if not step_ms.is_empty():
		step_ms.sort()
		var total: float = 0.0
		for value in step_ms:
			total += value
		print(
			(
				"[SkyPost] Container-Messung je Spielschritt (Simulation + Darstellung, headless): "
				+ "Mittel %.3f ms, 95%% %.3f ms, max %.3f ms über %d Schritte"
				% [
					total / step_ms.size(),
					step_ms[int(step_ms.size() * 0.95)],
					step_ms[-1],
					step_ms.size()
				]
			)
		)
	if failures.is_empty():
		print("[SkyPost] PASS: %d checks" % checks)
		quit(0)
	else:
		print(
			(
				"[SkyPost] FAIL: %d of %d checks failed: %s"
				% [failures.size(), checks, " | ".join(failures)]
			)
		)
		quit(1)


# ------------------------------------------------------------------ helpers


func _open(child: String, extra: Dictionary = {}):
	var options: Dictionary = {
		"grade": 2,
		"subject": "Mathematik",
		"childKey": child,
		"sessionId": "skypost-test",
		"skypostProfile": "low",
	}
	options.merge(extra, true)
	router.launch_options = options
	var game = scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.build_now()
	return game


func _close(game) -> void:
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


func _choose(game, mode: String, stage: String) -> void:
	game.mode = mode
	game.stage = stage


func _fly(game, seconds: float, stop: Callable) -> float:
	var steps: int = int(seconds / STEP)
	for index in range(steps):
		var started: int = Time.get_ticks_usec()
		game.advance(STEP)
		if index % 7 == 0:
			step_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if stop.call():
			return float(index + 1) * STEP
	return -1.0


# ------------------------------------------------------------------ registration


func _test_registration() -> void:
	_check(
		router.SCENES.get("skypost", "") == "res://scenes/games/sky_post.tscn",
		"SceneRouter kennt das Ziel skypost"
	)
	_check(
		bridge.validated_options({"game": "skypost"}).scene == "skypost",
		"Host-Startoption game=skypost wird angenommen"
	)
	var boot: Script = load("res://scripts/app/app_boot.gd")
	_check(
		boot.TITLE_BY_SCENE.get("skypost", "") == "LUMOS STERNENPOST",
		"Startbild nennt LUMOS STERNENPOST"
	)
	_check(
		ResourceLoader.exists(str(boot.COVER_BY_SCENE.get("skypost", ""))),
		"eigenes Titelbild aus einer echten Szenenaufnahme"
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/app/app_boot.gd")
	_check(source.contains('"run", "skypost"'), "app_boot startet --scene=skypost")
	var routes = load("res://scripts/games/game_hub_routes.gd")
	var listed: bool = false
	for entry in routes.ENTRIES:
		listed = listed or str(entry.destination) == "skypost"
	_check(listed, "Godot-Spielewelt listet die Sternenpost")
	_check(
		not routes.launch_options_for("skypost", {}, 3, "Deutsch").is_empty(),
		"Spielewelt baut Startoptionen für skypost"
	)


# ------------------------------------------------------------------ riddles


func _test_riddles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad: int = 0
	var wrong_sum: int = 0
	var kinds: Dictionary = {}
	for grade in range(1, 5):
		for subject in ["Mathematik", "Deutsch"]:
			for index in range(60):
				var kind: String = ADDRESSES.kind_for(subject, grade, index)
				var riddle: Dictionary = ADDRESSES.make(kind, grade, rng)
				kinds[kind] = true
				if not ADDRESSES.valid(riddle):
					bad += 1
					continue
				if kind == "math":
					var right: int = int(riddle.answers[int(riddle.answer)])
					var text: String = str(riddle.solution).get_slice(" = ", 0)
					var value: int = _evaluate(text)
					if value != right or right <= 0:
						wrong_sum += 1
					if grade <= 2 and right > (10 if grade == 1 else 20):
						wrong_sum += 1
				elif kind == "word":
					var target: String = str(riddle.prompt).get_slice("dem ", 1)
					var right_word: String = str(riddle.answers[int(riddle.answer)])
					var pools := {
						"Tunwort": ADDRESSES.VERBS,
						"Namenwort": ADDRESSES.NOUNS,
						"Wiewort": ADDRESSES.ADJECTIVES
					}
					if not pools[target].has(right_word):
						wrong_sum += 1
					for slot in range(3):
						if slot != int(riddle.answer) and pools[target].has(riddle.answers[slot]):
							wrong_sum += 1
				elif kind == "clock":
					var right_clock: String = str(riddle.answers[int(riddle.answer)])
					var minute: int = int(right_clock.get_slice(":", 2))
					if grade == 1 and minute != 0:
						wrong_sum += 1
	_check(bad == 0, "alle 480 Rätsel haben drei verschiedene Antworten und genau eine richtige")
	_check(wrong_sum == 0, "Rechnungen, Wortarten und Uhrzeiten stimmen (Fehler: %d)" % wrong_sum)
	_check(
		kinds.has("math") and kinds.has("word") and kinds.has("clock"),
		"Hausnummer-Rechnung, Wortart und Uhrzeit kommen vor"
	)
	var plain: Dictionary = ADDRESSES.make("math", 1, rng, true)
	_check(
		str(plain.prompt).begins_with("Haus ") and not str(plain.prompt).contains("+"),
		"ohne Rätsel steht die Hausnummer direkt da"
	)


func _evaluate(text: String) -> int:
	for sign in ["+", "−", "·"]:
		if text.contains(" %s " % sign):
			var a: int = int(text.get_slice(" %s " % sign, 0))
			var b: int = int(text.get_slice(" %s " % sign, 1))
			match sign:
				"+":
					return a + b
				"−":
					return a - b
				"·":
					return a * b
	return -1


# ------------------------------------------------------------------ world


func _test_layout() -> void:
	var layout = LAYOUT.build()
	var blocked_gates: int = 0
	for gate in LAYOUT.GATES:
		if layout.blocked(gate, 4.0):
			blocked_gates += 1
	_check(blocked_gates == 0, "kein Ring steckt in einer Insel oder einem Haus")
	var sparks: PackedVector3Array = layout.race_sparks()
	_check(sparks.size() >= 24, "Wolkenrennen hat %d Sternfunken an der Strecke" % sparks.size())
	var route: Array = [0, 1, 2, 3, 4, 5]
	_check(
		layout.delivery_sparks(route).size() >= 20,
		"Lieferflug hat Sternfunken entlang der Wege und in den Aufwinden"
	)
	_check(layout.houses.size() == 18, "sechs Postbezirke mit je drei Häusern")
	var gaps: Array[float] = []
	for district in range(LAYOUT.DISTRICTS.size()):
		var houses: Array[Dictionary] = layout.district_houses(district)
		for a in range(3):
			for b in range(a + 1, 3):
				gaps.append(
					Vector2(houses[a].mailbox.x, houses[a].mailbox.z).distance_to(
						Vector2(houses[b].mailbox.x, houses[b].mailbox.z)
					)
				)
	gaps.sort()
	var widest: float = float(TUNING.CATCH_RADIUS.entdecken) + TUNING.CATCH_HELP_MAX
	_check(
		gaps[0] > widest,
		(
			"Briefkästen eines Bezirks liegen weiter auseinander (%.1f m) als der größte Fangkreis (%.1f m)"
			% [gaps[0], widest]
		)
	)


# ------------------------------------------------------------------ delivery


func _test_delivery(stage: String) -> void:
	var game = await _open("skypost-delivery-" + stage)
	_choose(game, "delivery", stage)
	rewards.clear()
	game.start_flight(false)
	var bot = BOT.new(game)
	game.autopilot = bot.stick
	var deliveries: int = game.delivery.jobs.size()
	var seconds: float = _fly(game, 900.0, func() -> bool: return game.phase == game.Phase.FINISHED)
	_check(
		deliveries >= 5 and int(TUNING.DELIVERIES[stage]) == deliveries,
		"%s: Tour mit %d Lieferungen" % [stage, deliveries]
	)
	_check(
		seconds > 0.0 and game.delivery.done == deliveries,
		(
			"%s: Flug-Bot stellt alle %d Briefe zu (%.0f s Flugzeit, %d Abwürfe, beim 1. Versuch %d)"
			% [stage, deliveries, seconds, bot.drops, game.delivery.first_try_count()]
		)
	)
	game.advance(STEP)
	_check(game.rewards_booked == 1 and rewards.size() == 1, "%s: Ergebnis genau einmal gebucht" % stage)
	if not rewards.is_empty():
		_check(
			int(rewards[0].stars) > 0 and str(rewards[0].game) == "skypost",
			"%s: Sterne an den Host (%d)" % [stage, int(rewards[0].stars)]
		)
	game._finish_delivery()
	game._book_reward()
	bridge.reward(game.result_payload)
	_check(
		game.rewards_booked == 1 and rewards.size() == 1,
		"%s: nochmaliges Beenden und Zurück bucht nichts doppelt" % stage
	)
	_check(game.menus.screen == "result", "%s: Ergebnisbild ist offen" % stage)
	await _close(game)


func _test_wrong_and_miss() -> void:
	var game = await _open("skypost-help")
	_choose(game, "delivery", "abenteuer")
	game.start_flight(false)
	var bot = BOT.new(game)
	game.autopilot = bot.stick
	var delivery = game.delivery
	var right: int = delivery.target_house()
	var other: int = -1
	for house in delivery.district_houses():
		if house != right:
			other = house
	bot.wrong_house = other
	var events: Array[String] = []
	game.moment.connect(func(kind: String, _detail: Dictionary) -> void: events.append(kind))
	var radius_before: float = delivery.catch_radius()
	_fly(game, 300.0, func() -> bool: return events.has("wrong"))
	_check(events.has("wrong"), "falsches Haus wird erkannt")
	_check(delivery.done == 0 and delivery.tries[0] == 1, "der Brief bleibt an Bord, ein Versuch mehr")
	_check(
		delivery.catch_radius() > radius_before,
		"Hilfe nach Fehlversuch: Fangkreis %.1f → %.1f m" % [radius_before, delivery.catch_radius()]
	)
	_check(game.hud.toast.text.contains("Das ist das Haus"), "Lumo sagt, welches Haus es war")
	# A drop over the open meadow is a miss.
	delivery.drop = {}
	var centre: Vector3 = delivery.centre()
	var island: Dictionary = game.layout.islands[int(LAYOUT.DISTRICTS[0].island)]
	game.flight.place(centre + Vector3(0, 30, -float(island.radius) * 3.0), 0.0, 14.0)
	var landed: Variant = delivery.predict(game.flight.pos, game.flight.velocity)
	_check(landed == null, "über dem Wolkenmeer gibt es keinen Landepunkt")
	game.flight.place(centre + Vector3(0, 40, 0), 0.0, 9.0)
	delivery.release(game.flight.pos, Vector3.ZERO)
	_fly(game, 30.0, func() -> bool: return delivery.drop.is_empty())
	_check(events.has("miss") or delivery.done == 1, "ein Abwurf neben die Briefkästen ist daneben")
	bot.wrong_house = -1
	_fly(game, 240.0, func() -> bool: return delivery.done >= 1)
	_check(delivery.done >= 1 and delivery.first_try_count() == 0, "danach klappt es, zählt aber nicht als 1. Versuch")
	await _close(game)


# ------------------------------------------------------------------ race


func _test_race(stage: String) -> void:
	var game = await _open("skypost-race-" + stage)
	_choose(game, "race", stage)
	rewards.clear()
	game.start_flight(false)
	_check(game.phase == game.Phase.COUNTDOWN, "%s: Wolkenrennen beginnt mit Countdown" % stage)
	var bot = BOT.new(game)
	game.autopilot = bot.stick
	# Lambdas capture locals by value: shared numbers live in a dictionary.
	var seen := {"stuck": 0.0, "finished": 0, "slowest": INF}
	var rivals = game.rivals
	_check(rivals.rivals.size() == 3, "%s: drei Gegner" % stage)
	var seated: int = 0
	for rival in rivals.rivals:
		seated += 1 if bool(rival.seated) else 0
	_check(seated == 3, "%s: in jedem Gegner-Flieger sitzt ein Mitspieler-Tier" % stage)
	var watch := func() -> void:
		if game.phase == game.Phase.COUNTDOWN or not rivals.running or rivals.clock < 3.0:
			return
		for rival in rivals.rivals:
			seen.stuck = maxf(float(seen.stuck), float(rival.stuck))
			if not bool(rival.finished):
				seen.slowest = minf(float(seen.slowest), float(rival.speed))
	var seconds: float = _fly(
		game,
		900.0,
		func() -> bool:
			watch.call()
			return game.phase == game.Phase.FINISHED
	)
	_check(
		seconds > 0.0 and game.race.finished,
		(
			"%s: Wolkenrennen-Bot fliegt alle %d Ringe ins Ziel (%.0f s, %d mitten durch)"
			% [stage, game.race.total(), seconds, game.race.hits]
		)
	)
	_fly(
		game,
		300.0,
		func() -> bool:
			watch.call()
			var count: int = 0
			for rival in rivals.rivals:
				count += 1 if bool(rival.finished) else 0
			seen.finished = count
			return count == 3
	)
	_check(int(seen.finished) == 3, "%s: alle drei Gegner kommen ins Ziel" % stage)
	_check(
		float(seen.stuck) < 0.5 and float(seen.slowest) > 4.0,
		(
			"%s: kein Gegner hängt fest (längster Halt %.2f s, langsamster %.1f m/s)"
			% [stage, float(seen.stuck), float(seen.slowest)]
		)
	)
	var times: Array[String] = []
	for rival in rivals.rivals:
		times.append("%s %.0f s" % [rival.name, float(rival.finish_time)])
	print("[SkyPost] %s: Lumo %.0f s, %s" % [stage, game.race.finish_time, ", ".join(times)])
	var place: int = int(game.result_payload.get("place", 0))
	_check(place >= 1 and place <= 4, "%s: Platz %d" % [stage, place])
	_check(game.rewards_booked == 1 and rewards.size() == 1, "%s: Rennergebnis genau einmal" % stage)
	await _close(game)


# ------------------------------------------------------------------ free flight


func _test_free() -> void:
	var child: String = "skypost-free"
	SESSION.store_album(child.sha256_text(), 0, 0)
	var game = await _open(child)
	_choose(game, "free", "entdecken")
	game.start_flight(false)
	var bot = BOT.new(game)
	game.autopilot = bot.stick
	_fly(game, 420.0, func() -> bool: return game._bits(game.free_photos) >= 2)
	var photos: int = game._bits(game.free_photos)
	_check(photos >= 2, "Freiflug: der Bot fliegt durch %d FOTO-Rahmen" % photos)
	# A secret star right in front of Lumo.
	var index: int = -1
	for k in range(game.world.spark_positions.size()):
		if game.world.spark_taken[k] == 0:
			index = k
			break
	var spot: Vector3 = game.world.spark_positions[index]
	game.flight.place(spot + Vector3(0, 0, 6.0), 0.0, 12.0)
	_fly(game, 2.0, func() -> bool: return game.world.spark_taken[index] == 1)
	_check(game.world.spark_taken[index] == 1, "Freiflug: geheimer Stern wird eingesammelt")
	rewards.clear()
	game.elapsed = maxf(game.elapsed, TUNING.FREE_MIN_SECONDS + 1.0)
	game.pause()
	game._on_again()
	_check(game.phase == game.Phase.FINISHED, "Freiflug beenden zeigt das Ergebnis")
	_check(rewards.size() == 1 and int(rewards[0].stars) > 0, "Freiflug: Sterne für Neues")
	var album: Dictionary = SESSION.album(child.sha256_text())
	_check(
		game._bits(int(album.photos)) >= 2 and int(album.secrets) != 0,
		"Album merkt sich Fotos und geheime Sterne je Kind"
	)
	await _close(game)
	# The same finds again give nothing new.
	game = await _open(child)
	_choose(game, "free", "entdecken")
	game.start_flight(false)
	game.free_photos = int(album.photos)
	game.free_secrets = int(album.secrets)
	game.elapsed = 5.0
	rewards.clear()
	game.finish_free()
	_check(
		rewards.size() == 1 and int(rewards[0].stars) == 0,
		"schon Gefundenes und ein kurzer Flug bringen keine Sterne"
	)
	await _close(game)


# ------------------------------------------------------------------ save, children


func _test_save_and_children() -> void:
	var child: String = "skypost-save-a"
	var game = await _open(child)
	_choose(game, "delivery", "entdecken")
	SESSION.erase(SESSION.path_for(child.sha256_text(), "delivery"))
	game.start_flight(false)
	var bot = BOT.new(game)
	game.autopilot = bot.stick
	_fly(game, 600.0, func() -> bool: return game.delivery.done >= 2)
	var result_id: String = game.result_id
	var first_jobs: Array = game.delivery.jobs.duplicate(true)
	game.pause()
	_check(game.paused and game.menus.screen == "pause", "Pause hält den Flug an")
	var before: Vector3 = game.flight.pos
	game.advance(STEP)
	_check(game.flight.pos == before, "in der Pause bewegt sich nichts")
	game.to_menu()
	_check(game.menus.screen == "start", "Zum Menü zeigt das Startmenü")
	var save_text: String = str(game.menus.data.get("save", ""))
	_check(save_text == "2 von 5 Briefen", "Startmenü bietet Weiterfliegen an (%s)" % save_text)
	await _close(game)
	# Another child sees nothing of it.
	game = await _open("skypost-save-b")
	_choose(game, "delivery", "entdecken")
	_check(
		str(game._start_data().save).is_empty(),
		"Kindwechsel: ein anderes Kind sieht keinen fremden Spielstand"
	)
	await _close(game)
	# The first child continues where it stopped.
	game = await _open(child)
	_choose(game, "delivery", "entdecken")
	game.start_flight(true)
	_check(game.delivery.done == 2, "Weiterfliegen: 2 Briefe sind schon zugestellt")
	_check(game.result_id == result_id, "Weiterfliegen behält die Ergebnis-Kennung")
	_check(
		str(game.delivery.jobs[2].riddle.prompt) == str(first_jobs[2].riddle.prompt),
		"Weiterfliegen behält die Adressen der Tour"
	)
	rewards.clear()
	bot = BOT.new(game)
	game.autopilot = bot.stick
	_fly(game, 600.0, func() -> bool: return game.phase == game.Phase.FINISHED)
	_check(game.phase == game.Phase.FINISHED and rewards.size() == 1, "fortgesetzte Tour endet mit einem Ergebnis")
	_check(
		SESSION.peek(SESSION.path_for(child.sha256_text(), "delivery"), game._identity()).is_empty(),
		"nach dem Ergebnis ist der Spielstand gelöscht"
	)
	var record: Dictionary = SESSION.record(child.sha256_text(), "delivery", "entdecken")
	_check(not record.is_empty(), "Bestwert des Kindes gespeichert")
	_check(
		SESSION.record("skypost-save-b".sha256_text(), "delivery", "entdecken").is_empty(),
		"Kindwechsel: das andere Kind hat keinen Bestwert"
	)
	# A broken save file is ignored, never repaired.
	var path: String = SESSION.path_for(child.sha256_text(), "delivery")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[skypost]\nversion=1\ndone=99\n")
	file.close()
	_check(SESSION.peek(path, game._identity()).is_empty(), "kaputter Spielstand wird nicht angeboten")
	SESSION.erase(path)
	await _close(game)


# ------------------------------------------------------------------ safety


func _test_never_crash() -> void:
	var game = await _open("skypost-safe")
	_choose(game, "free", "extrem")
	game.start_flight(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2058
	var held := {"stick": Vector2.ZERO}
	game.autopilot = func(_game) -> Vector2: return held.stick
	var inside: int = 0
	var lowest: float = INF
	var highest: float = -INF
	var seen := {"cushions": 0}
	game.moment.connect(
		func(kind: String, _detail: Dictionary) -> void:
			if kind == "cushion":
				seen.cushions = int(seen.cushions) + 1
	)
	for second in range(240):
		if second % 2 == 0:
			var stick := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if second % 20 < 6:
				stick.y = -1.0
			held.stick = stick
		for k in range(60):
			game.advance(STEP)
			if game.layout.blocked(game.flight.pos, 0.3):
				inside += 1
			lowest = minf(lowest, game.flight.pos.y)
			highest = maxf(highest, game.flight.pos.y)
	_check(inside == 0, "4 Minuten Zufallsflug: Lumo steckt nie in Insel oder Haus")
	_check(
		lowest >= LAYOUT.CLOUD_FLOOR - 0.01 and highest <= LAYOUT.CEILING + 0.01,
		"Wolkenpolster und Himmelsdecke halten (%.1f .. %.1f m)" % [lowest, highest]
	)
	_check(
		int(seen.cushions) > 0,
		"Sturzflug nach unten endet im Wolkenpolster (%d mal)" % int(seen.cushions)
	)
	await _close(game)
