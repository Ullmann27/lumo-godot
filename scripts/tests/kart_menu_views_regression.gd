extends SceneTree
## Weitere Kart-Menüansichten (Auftrag 18.11., Abschnitt 4):
## - Fahrer: jede Fahrerkarte hat ein eigenes, echtes Bild; gesperrte nennen fehlende Sterne.
## - Tempo & Gegner: je Stufe eine Karte mit Aussagen aus CATALOG.DIFFICULTIES.
## - Einstellungen: der Stufenschalter kennt alle drei Stufen.
## - Ergebnis: genau „Noch einmal“ und „Zur Streckenwahl“ groß; „Zur Streckenwahl“ öffnet
##   die Rennwelten, „Noch einmal“ startet dieselbe Strecke neu.
## Headless lauffähig: godot --headless --script res://scripts/tests/kart_menu_views_regression.gd
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var game
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[KartMenuViews] FAIL: " + label)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _cards(prefix: String) -> Array:
	var result: Array = []
	for child in game.garage.choices.get_children():
		if str(child.name).begins_with(prefix) and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _section(step: int) -> void:
	game._reference_select_mode(["modes", "driver", "garage", "world", "difficulty"][step])
	await _frames(6)


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	var catalog = load("res://scripts/games/kart_catalog.gd")
	var sections = load("res://scripts/games/kart_menu_sections.gd")
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	root.size = Vector2i(1812, 2176)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _frames(8)
	# Fahrer: eigenes Bild je Fahrer, gesperrte mit fehlenden Sternen.
	await _section(1)
	var drivers := _cards("DriverCard_")
	_check(drivers.size() == catalog.DRIVERS.size(), "eine Karte je Fahrer (%d)" % drivers.size())
	var pictures := {}
	for index in range(drivers.size()):
		var card = drivers[index]
		var entry: Dictionary = catalog.DRIVERS[index]
		_check(card.title == str(entry.name), "%s trägt den Namen %s" % [card.name, entry.name])
		_check(card.art != null, "%s hat ein Bild" % card.name)
		if card.art != null:
			pictures[card.art.resource_path] = true
			_check(
				card.art.resource_path.ends_with(str(entry.id) + ".webp"),
				"%s zeigt sein eigenes Bild" % card.name
			)
		var open: bool = catalog.unlocked(entry, int(game.garage.stars), game.garage.unlocked_ids)
		_check(card.disabled != open, "%s ist nur gesperrt, wenn Sterne fehlen" % card.name)
		if not open:
			var missing: int = int(entry.unlock) - int(game.garage.stars)
			_check(
				card.locked_text == "Noch %d ★" % missing,
				"%s nennt die fehlenden Sterne" % card.name
			)
		var height_dp: float = card.size.y / game.garage._preview_dp_scale()
		_check(height_dp >= 120.0, "%s ist groß (%.0f dp hoch)" % [card.name, height_dp])
	_check(pictures.size() == drivers.size(), "jede Fahrerkarte hat ein eigenes Bild")
	# Tempo & Gegner: Aussagen aus den echten Katalogwerten.
	await _section(4)
	var levels := _cards("LevelCard_")
	_check(levels.size() == catalog.DIFFICULTIES.size(), "eine Karte je Stufe")
	for index in range(levels.size()):
		var entry: Dictionary = catalog.DIFFICULTIES[index]
		var lines: PackedStringArray = levels[index].lines
		_check(levels[index].title == str(entry.name), "Stufe %s heißt %s" % [index, entry.name])
		_check(lines == sections.level_facts(entry), "%s nutzt die Katalogaussagen" % entry.name)
		_check(
			lines.has("Rivalen: %d %% Kraft" % roundi(float(entry.rival) * 100.0)),
			"%s nennt die Rivalenkraft" % entry.name
		)
		_check(
			lines.has("Lenkhilfe: an") == (str(entry.id) == "gemuetlich"),
			"%s Lenkhilfe wie im Rennen" % entry.name
		)
		_check(
			levels[index].selected == (str(entry.id) == str(game.garage.setup.difficulty)),
			"%s Auswahl stimmt" % entry.name
		)
	levels[1].pressed.emit()
	await _frames(4)
	_check(
		str(game.garage.setup.difficulty) == str(catalog.DIFFICULTIES[1].id),
		"Antippen wählt die Stufe"
	)
	# Einstellungen: Stufenschalter kennt alle drei Namen.
	game._show_reference_landing(true)
	await _frames(4)
	game._reference_open_settings()
	await _frames(2)
	var toggle: Button = game.modal_column.find_child("DifficultyToggle", true, false)
	var seen: Array[String] = []
	for _press in range(3):
		seen.append(toggle.text)
		toggle.pressed.emit()
	var names: Array[String] = []
	for entry in catalog.DIFFICULTIES:
		names.append("Stufe: " + str(entry.name))
	seen.sort()
	names.sort()
	_check(seen == names, "Stufenschalter zeigt alle drei Stufen: %s" % [seen])
	game._close_menu_settings()
	# Ergebnis: zwei große Aktionen.
	var setup := {
		"mode": "race",
		"driver": "fox",
		"kart": "comet",
		"track": "zauberwald",
		"difficulty": "gemuetlich"
	}
	game._start_selected_race(setup)
	game._end_preview()
	game.countdown = 0
	game.racing = true
	await process_frame
	game.elapsed = 98.4
	game.checkpoint_index = 16
	game._finish(false)
	await _frames(4)
	var main_row: Node = game.modal_column.get_node_or_null("ResultMainActions")
	_check(
		main_row != null and main_row.get_child_count() == 2,
		"Ergebnis hat genau zwei Hauptaktionen"
	)
	if main_row != null and main_row.get_child_count() == 2:
		_check(
			main_row.get_child(0).text == "Noch einmal" and main_row.get_child(0).kind == "primary",
			"erste große Aktion: Noch einmal (gold)"
		)
		_check(
			main_row.get_child(1).text == "Zur Streckenwahl",
			"zweite große Aktion: Zur Streckenwahl"
		)
		var big: float = main_row.get_child(0).get_global_rect().size.y
		for small in game.modal_column.get_node("ResultMoreActions").get_children():
			_check(
				small.get_global_rect().size.y < big,
				"%s ist kleiner als die Hauptaktionen" % small.text
			)
		main_row.get_child(1).pressed.emit()
		await _frames(6)
		_check(
			game.menu_active and int(game.garage.step) == 3,
			"Zur Streckenwahl öffnet die Rennwelten"
		)
		_check(str(game.garage.setup.track) == "zauberwald", "die gefahrene Strecke bleibt gewählt")
	# „Noch einmal“ startet dieselbe Strecke neu.
	game._start_selected_race(setup)
	game._end_preview()
	game.countdown = 0
	game.racing = true
	await process_frame
	game.checkpoint_index = 16
	game._finish(false)
	await _frames(2)
	main_row = game.modal_column.get_node_or_null("ResultMainActions")
	if main_row != null:
		main_row.get_child(0).pressed.emit()
		await _frames(4)
		_check(
			not game.menu_active and game.track_id == "zauberwald" and not game.finished,
			"Noch einmal startet dieselbe Strecke neu"
		)
	game.abandoned = true
	if not (await SCENE_TEARDOWN.release_scene(self, game, "[KartMenuViews]")):
		failures.append("teardown")
	# Keine gespeicherte Stufe oder Sitzung an andere Tests weitergeben.
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	print(
		(
			"[KartMenuViews] %s %d Prüfungen, %d Fehler"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
