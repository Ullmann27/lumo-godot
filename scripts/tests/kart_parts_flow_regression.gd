extends SceneTree
## Weg A (Auftrag 18.11.): Garage → Kart wählen → Radaufsatz ansehen → montieren →
## Auspuffblende wechseln (einmal verwerfen, einmal montieren) → Rennen starten (Teile am
## Rennfahrzeug) → zurück ins Menü → Spielstand neu laden (Teile wieder da). Dazu: Karten
## zeigen höchstens zwei beschriftete Werte, „Werte“ zeigt alle fünf, „Teile wechseln“ ist
## bei 0 Sternen erreichbar und ≥ 48 dp groß, alte Spielstände ohne Teile laden als Serie.
## Kopflos: godot --headless --path . --script res://scripts/tests/kart_parts_flow_regression.gd

const TUNING = preload("res://scripts/games/kart_tuning.gd")
const CHILD := "parts_flow_child"
var failures: Array[String] = []
var checks := 0
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[KartPartsFlow] FAIL: ", label)


func _frames(count: int = 4) -> void:
	for _i in range(count):
		await process_frame


func _vehicle(kart):
	return kart.get("production_vehicle") if is_instance_valid(kart) else null


func _count_parts(vehicle, prefix: String) -> int:
	if vehicle == null:
		return 0
	return vehicle.find_children("Part_" + prefix + "*", "Node3D", true, false).size()


func _run() -> void:
	var path := TUNING.path_for(CHILD)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	# Alter Spielstand ohne Teile-Einträge (Lack bleibt erhalten, Teile = Serie).
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 1)
	legacy.set_value("meta", "lifetime", 0)
	legacy.set_value("kart_comet", "rims", "chrom")
	legacy.save(path)
	var parts_asset := ResourceLoader.exists("res://assets/kart/production/parts/kart_parts.glb")
	_check(parts_asset, "Teile-Modell kart_parts.glb ist importiert")
	root.size = Vector2i(1080, 2340)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(8)
	var garage = game.garage
	_check(garage != null, "Garage vorhanden")
	if garage == null:
		_finish()
		return
	garage.workshop = TUNING.new(CHILD, 0)
	game.workshop = garage.workshop
	_check(
		garage.workshop.chosen("comet", "wheel_cover") == "serie",
		"alter Spielstand: Radaufsatz = Serie"
	)
	_check(garage.workshop.chosen("comet", "rims") == "chrom", "alter Spielstand: Felgen bleiben")
	garage.step = 2
	garage._select("kart", "comet")
	garage._refresh()
	garage._apply_responsive_layout()
	await _frames(6)
	var bay = garage.parts_bay
	_check(
		bay != null and bay.open_button.is_visible_in_tree(),
		"„Teile wechseln“ sichtbar bei 0 Sternen"
	)
	if bay == null:
		_finish()
		return
	var dp: float = garage._preview_dp_scale() if garage.has_method("_preview_dp_scale") else 1.0
	var button_rect: Rect2 = bay.open_button.get_global_rect()
	_check(
		button_rect.size.y >= 48.0 * dp - 0.5 and button_rect.size.x >= 48.0 * dp,
		"„Teile wechseln“ ≥ 48 dp"
	)
	_check(
		button_rect.end.y <= garage._selection_surface.get_global_rect().position.y + 1.0,
		"„Teile wechseln“ steht beim Kart über der Kartauswahl"
	)
	# Karten: höchstens zwei beschriftete Werte.
	var cards: Array = garage.find_children("*", "Button", true, false).filter(
		func(c): return c.get("bars") != null and c.get("item") is Dictionary
	)
	_check(not cards.is_empty(), "Kartkarten vorhanden")
	for card in cards:
		_check(
			card.bars.only_keys.size() <= 2 and card.bars.show_labels,
			"Karte %s: höchstens zwei beschriftete Werte" % str(card.item.get("id", ""))
		)
	bay._on_stats()
	_check(
		(
			bay.stats_panel.visible
			and bay.stats_bars._keys().size() == 5
			and bay.stats_bars.show_labels
		),
		"„Werte“ zeigt alle fünf beschrifteten Werte"
	)
	bay.stats_panel.hide()
	# Räder: Vorschau → montieren.
	bay._on_open()
	await _frames(2)
	_check(bay.is_open() and bay.panel.is_visible_in_tree(), "Konfigurator geöffnet")
	bay._on_slot("wheel_cover")
	_check(bay.tiles.size() >= 3 and bay.tiles.has("serie"), "Räder: Serie + zwei Formen")
	var pictures := 0
	for id in bay.tiles:
		var picture: TextureRect = bay.tiles[id].find_child("PartPicture", true, false)
		if picture != null and picture.texture != null:
			pictures += 1
	_check(pictures == bay.tiles.size(), "jedes Rad-Teil hat ein gerendertes Teilebild")
	_check(
		bay.panel.get_global_rect().end.y <= garage.footer.get_global_rect().position.y + 1.0,
		"Konfigurator bleibt über der Fußleiste"
	)
	var before_camera: Vector3 = garage.preview_camera.global_position
	bay._on_tile("turbine")
	await _frames(30)
	var vehicle = _vehicle(garage.preview_kart)
	_check(
		vehicle != null and vehicle.mounted_parts.get("wheel_cover") == "turbine",
		"Turbinenrad sofort am Kart (Vorschau)"
	)
	_check(_count_parts(vehicle, "WheelCover_Turbine") == 4, "Turbinenrad an allen vier Rädern")
	_check(
		garage.preview_camera.global_position.distance_to(before_camera) > 0.3,
		"Kamera fährt ans Rad"
	)
	_check(
		garage.workshop.chosen("comet", "wheel_cover") == "serie",
		"Vorschau ist noch nicht gespeichert"
	)
	bay._on_tile("stern")
	await _frames(2)
	vehicle = _vehicle(garage.preview_kart)
	_check(
		(
			_count_parts(vehicle, "WheelCover_Star") == 4
			and _count_parts(vehicle, "WheelCover_Turbine") == 0
		),
		"Wechsel auf Sternrad ersetzt das Turbinenrad"
	)
	bay._on_tile("turbine")
	bay._on_mount()
	await _frames(6)
	_check(not bay.is_open(), "Montieren schließt den Konfigurator")
	_check(garage.workshop.chosen("comet", "wheel_cover") == "turbine", "Turbinenrad gespeichert")
	vehicle = _vehicle(garage.preview_kart)
	_check(
		_count_parts(vehicle, "WheelCover_Turbine") == 4,
		"Turbinenrad nach Neuaufbau der Garage noch am Kart"
	)
	# Auspuff: einmal verwerfen, dann montieren.
	bay._on_open()
	bay._on_slot("exhaust")
	_check(bay.tiles.size() >= 3, "Auspuff: Serie + zwei Formen")
	bay._on_tile("rakete")
	await _frames(2)
	vehicle = _vehicle(garage.preview_kart)
	_check(
		_count_parts(vehicle, "ExhaustTip_Rocket") == 2,
		"Raketendüse links und rechts in der Vorschau"
	)
	bay._on_back()
	await _frames(4)
	vehicle = _vehicle(garage.preview_kart)
	_check(
		(
			garage.workshop.chosen("comet", "exhaust") == "serie"
			and _count_parts(vehicle, "ExhaustTip_Rocket") == 0
		),
		"„Zurück“ verwirft die Vorschau"
	)
	_check(_count_parts(vehicle, "WheelCover_Turbine") == 4, "„Zurück“ lässt montierte Räder dran")
	bay._on_open()
	bay._on_slot("exhaust")
	bay._on_tile("doppel")
	bay._on_mount()
	await _frames(4)
	_check(garage.workshop.chosen("comet", "exhaust") == "doppel", "Doppelrohr gespeichert")
	# Rennen starten: Teile am Rennfahrzeug.
	game.selected_kart = "comet"
	garage.start_requested.emit(garage.setup.duplicate(true))
	await _frames(12)
	var race_kart = _vehicle(game.player)
	_check(race_kart != null, "Rennfahrzeug ist das gebaute Kart")
	if race_kart != null:
		_check(
			(
				race_kart.mounted_parts.get("wheel_cover") == "turbine"
				and race_kart.mounted_parts.get("exhaust") == "doppel"
			),
			"Rennfahrzeug trägt Turbinenrad und Doppelrohr"
		)
		_check(
			(
				_count_parts(race_kart, "WheelCover_Turbine") == 4
				and _count_parts(race_kart, "ExhaustTip_Twin") == 2
			),
			"Teile sind am Rennfahrzeug sichtbar angebaut"
		)
	if game.has_method("_leave_race_for_menu"):
		game._leave_race_for_menu()
		await _frames(8)
	# Neu laden wie nach App-Neustart: Spielstand von der Platte.
	var reloaded = TUNING.new(CHILD, 0)
	_check(
		(
			reloaded.chosen("comet", "wheel_cover") == "turbine"
			and reloaded.chosen("comet", "exhaust") == "doppel"
		),
		"nach Neustart wieder da (pro Kind und Kart)"
	)
	_check(reloaded.chosen("glider", "wheel_cover") == "serie", "anderes Kart bleibt Serie")
	_check(
		TUNING.new("anderes_kind", 0).chosen("comet", "wheel_cover") == "serie",
		"anderes Kinderprofil bleibt Serie"
	)
	_check(
		(
			reloaded.chosen("comet", "rims") == "chrom"
			and reloaded.available() == game.workshop.available()
		),
		"Felgen und Sterne unverändert (Teile kosten nichts)"
	)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TUNING.path_for("anderes_kind"))
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("[KartPartsFlow] PASS %d checks" % checks)
	else:
		print("[KartPartsFlow] FAIL %d of %d checks" % [failures.size(), checks])
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
