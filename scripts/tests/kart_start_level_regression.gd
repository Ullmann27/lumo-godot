extends SceneTree
## Gegnerstufe im Kart: Ein neues Kind startet auf "Entdecken" (nicht mehr auf dem
## erzwungenen "Extrem"), eine gefahrene oder eingestellte Stufe bleibt für genau
## dieses Kind gespeichert, und der alte gemeinsame Wert zählt nicht als Wahl.
## Verfolgt den Weg Menü -> Schnellstart -> Werte, mit denen die Rennphysik rechnet.
const PREFERENCES: String = "user://kart_preferences.cfg"
const CHILD_A: String = "start-level-regression-a"
const CHILD_B: String = "start-level-regression-b"
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("[KartStartLevel] FAIL ", text)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _open(child: String) -> Node:
	root.get_node("HostBridge")._options = {"childKey": child}
	var game: Node = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _frames(3)
	return game


func _close(game: Node) -> void:
	game.abandoned = true
	game.queue_free()
	await _frames(3)


func _stored(child: String) -> String:
	var config := ConfigFile.new()
	config.load(PREFERENCES)
	return str(config.get_value("levels", child.sha256_text(), ""))


func _run() -> void:
	var catalog: GDScript = load("res://scripts/games/kart_catalog.gd")
	var racecraft: GDScript = load("res://scripts/games/kart_rival_racecraft.gd")
	var powertrain: GDScript = load("res://scripts/games/kart_powertrain.gd")
	# Ausgangslage wie auf einem bestehenden Gerät: gemeinsamer Altwert "pro".
	var config := ConfigFile.new()
	config.load(PREFERENCES)
	for child in [CHILD_A, CHILD_B]:
		if config.has_section_key("levels", child.sha256_text()):
			config.erase_section_key("levels", child.sha256_text())
	config.set_value("race", "difficulty", "pro")
	config.save(PREFERENCES)

	var game: Node = await _open(CHILD_A)
	_check(game.difficulty == "gemuetlich", "neues Kind lädt die Einstiegsstufe")
	_check(str(game.garage.setup.difficulty) == "gemuetlich", "Menü zeigt für ein neues Kind Entdecken")
	_check(
		str(catalog.entry(catalog.DIFFICULTIES, "gemuetlich").name) == "Entdecken",
		"Einstiegsstufe heißt im Menü Entdecken"
	)
	# Schnellstart aus dem Hauptmenü nimmt genau diese Stufe mit ins Rennen.
	game._show_reference_landing()
	await _frames(3)
	game.reference_landing.current_mode = "race"
	game._reference_quick_start()
	await _frames(3)
	_check(not game.menu_active, "Schnellstart baut ein Rennen")
	_check(game.difficulty == "gemuetlich", "Schnellstart fährt auf Entdecken")
	var rules: Dictionary = catalog.entry(catalog.DIFFICULTIES, game.difficulty)
	_check(is_equal_approx(float(rules.rival), 0.86), "Rivalenfaktor der Einstiegsstufe ist 0,86")
	var kart_id: String = str(game.selected_kart)
	var own_top: float = powertrain.top_speed(racecraft.factors(kart_id), float(rules.speed))
	var rival_cruise: float = racecraft.cruise_speed(kart_id, rules)
	_check(
		is_equal_approx(rival_cruise, own_top * 0.86),
		"Rivalen rechnen mit 86 % des eigenen Endtempos (gleiches Kart)"
	)
	# Eigentempo ist auf allen Stufen gleich (volles Tempo), Rivalen werden je Stufe stärker.
	var previous_rival: float = 0.0
	for level in ["gemuetlich", "flott", "pro"]:
		var level_rules: Dictionary = catalog.entry(catalog.DIFFICULTIES, level)
		var level_own: float = powertrain.top_speed(racecraft.factors(kart_id), float(level_rules.speed))
		_check(is_equal_approx(level_own, own_top), "eigenes Endtempo auf %s gleich wie auf Entdecken" % level)
		var level_rival: float = racecraft.cruise_speed(kart_id, level_rules)
		_check(level_rival > previous_rival, "Rivalen-Endtempo steigt mit der Stufe (%s)" % level)
		_check(level_rival <= level_own + 0.0001, "Rivalen fahren auf %s nicht schneller als das Kind" % level)
		previous_rival = level_rival
	_check(is_equal_approx(float(rules.speed), 1.17), "Entdecken fährt volles Tempo (1,17 wie bisher Extrem)")
	_check(_stored(CHILD_A) == "gemuetlich", "gefahrene Stufe ist für das Kind gespeichert")
	await _close(game)

	# Das Kind wählt bewusst "Abenteuer" und fährt damit.
	game = await _open(CHILD_A)
	var chosen: Dictionary = game.garage.setup.duplicate(true)
	chosen["difficulty"] = "flott"
	chosen["mode"] = "race"
	game._start_selected_race(chosen)
	await _frames(3)
	_check(game.difficulty == "flott", "gewählte Stufe kommt im Rennen an")
	_check(_stored(CHILD_A) == "flott", "gewählte Stufe wird gespeichert")
	await _close(game)

	# Neustart der App: dieselbe Stufe, auch im Cup und beim Wiederholen.
	game = await _open(CHILD_A)
	_check(str(game.garage.setup.difficulty) == "flott", "nach Neustart bleibt die gewählte Stufe")
	var cup: Dictionary = game.garage.setup.duplicate(true)
	cup["mode"] = "cup"
	game._start_selected_race(cup)
	await _frames(3)
	_check(game.difficulty == "flott", "Sternen-Cup fährt auf der gespeicherten Stufe")
	_check(
		str(game.setup_snapshot.get("difficulty", "")) == "flott",
		"Wiederholen startet mit derselben Stufe"
	)
	await _close(game)

	# Ein anderes Kind am selben Gerät beginnt wieder auf Entdecken.
	game = await _open(CHILD_B)
	_check(str(game.garage.setup.difficulty) == "gemuetlich", "zweites Kind startet auf Entdecken")
	_check(_stored(CHILD_A) == "flott", "Stufe des ersten Kindes bleibt unberührt")
	game._save_preferences()
	_check(_stored(CHILD_A) == "flott", "Speichern des zweiten Kindes löscht nichts")
	await _close(game)

	# Beschädigter Wert fällt auf die Einstiegsstufe zurück.
	config = ConfigFile.new()
	config.load(PREFERENCES)
	config.set_value("levels", CHILD_B.sha256_text(), "turbo-unbekannt")
	config.save(PREFERENCES)
	game = await _open(CHILD_B)
	_check(game.difficulty == "gemuetlich", "unbekannter Wert wird zu Entdecken")
	await _close(game)

	config = ConfigFile.new()
	config.load(PREFERENCES)
	for child in [CHILD_A, CHILD_B]:
		if config.has_section_key("levels", child.sha256_text()):
			config.erase_section_key("levels", child.sha256_text())
	config.save(PREFERENCES)
	root.get_node("HostBridge")._options = {}
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	print(
		JSON.stringify(
			{
				"test": "kart_start_level",
				"status": "PASS" if failures.is_empty() else "FAIL",
				"checks": checks,
				"failures": failures
			}
		)
	)
	quit(0 if failures.is_empty() else 1)
