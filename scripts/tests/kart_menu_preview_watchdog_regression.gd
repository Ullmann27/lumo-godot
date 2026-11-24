extends SceneTree
## Gerätefehler 21.11.2026: „Im Kart-Hauptmenü verschwindet nach einer Zeit Lumo mit dem Kart
## und man sieht nichts mehr.“ Der Wächter der Menü-Vorschau (kart_spatial_menu.gd) muss jeden
## erkennbaren Ausfall selbst beheben: Kart unsichtbar, gelöscht, aus dem Bild geschoben,
## Vorschau angehalten, Kamera inaktiv. Er darf nicht eingreifen, solange alles stimmt, in der
## Werkstatt oder bei der Streckenwahl, und er hält Abstand und Höchstzahl der Reparaturen ein.
## Mit echtem Renderer (xvfb) wird zusätzlich das gezeichnete Bild geprüft.
var game
var garage
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("[MenuWatchdog] FAIL ", text)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


## Wächter sofort prüfen lassen (statt 5 s zu warten), Reparatur-Abstand aufheben.
func _watch_now() -> void:
	garage._preview_since_repair = garage.PREVIEW_REPAIR_GAP
	garage._preview_watch_time = garage.PREVIEW_WATCH_SECONDS
	garage._watch_preview(0.0)
	await _frames(6)


func _healthy(label: String) -> void:
	_check(
		garage.preview_problem().is_empty(),
		"%s: Vorschau in Ordnung (%s)" % [label, garage.preview_problem()]
	)
	_check(
		is_instance_valid(garage.preview_kart) and garage.preview_kart.is_visible_in_tree(),
		"%s: Kart sichtbar" % label
	)


func _fault(label: String, expected: String, breaker: Callable) -> void:
	var before: int = garage.preview_repairs.size()
	breaker.call()
	await _frames(2)
	_check(
		garage.preview_problem() == expected,
		"%s erkannt als %s (%s)" % [label, expected, garage.preview_problem()]
	)
	await _watch_now()
	_check(garage.preview_repairs.size() == before + 1, "%s: genau eine Reparatur" % label)
	_check(
		not garage.preview_repairs.is_empty() and garage.preview_repairs[-1] == expected,
		"%s: Grund protokolliert" % label
	)
	await _healthy("nach %s" % label)


func _run() -> void:
	root.size = Vector2i(2176, 1812)
	root.get_node("HostBridge")._options = {"displayDensity": 2.625}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _frames(20)
	game._show_reference_landing()
	await _frames(30)
	garage = game.garage
	_check(garage.has_method("preview_problem"), "Garage hat den Vorschau-Wächter")
	await _healthy("Hauptmenü")

	# Ohne Ausfall greift der Wächter nicht ein (auch nach vielen Prüfrunden).
	for _i in range(5):
		await _watch_now()
	_check(garage.preview_repairs.is_empty(), "gesunde Vorschau wird nicht neu aufgebaut")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(
			garage.preview_pixels_problem().is_empty(),
			"gezeichnetes Vorschaubild ist nicht einfarbig (%s)" % garage.preview_pixels_problem()
		)

	await _fault("Kart unsichtbar", "kart_unsichtbar", func(): garage.preview_kart.visible = false)
	await _fault(
		"Vorschau angehalten",
		"vorschau_angehalten",
		func(): garage.preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	)
	await _fault(
		"Kart aus dem Bild",
		"kart_ausserhalb_bild",
		func(): garage.preview_pivot.position = Vector3(0, 0, -400)
	)
	await _fault(
		"Kamera inaktiv", "kamera_nicht_aktiv", func(): garage.preview_camera.clear_current(false)
	)
	await _fault(
		"Kart gelöscht",
		"kart_fehlt",
		func():
			garage.preview_pivot.remove_child(garage.preview_kart)
			garage.preview_kart.queue_free()
	)

	# Abstand: eine zweite Reparatur sofort danach wird verweigert.
	var count: int = garage.preview_repairs.size()
	garage.preview_kart.visible = false
	garage._preview_since_repair = 0.0
	garage._preview_watch_time = garage.PREVIEW_WATCH_SECONDS
	garage._watch_preview(0.0)
	_check(
		garage.preview_repairs.size() == count,
		"zweite Reparatur innerhalb von 30 s wird verweigert"
	)
	garage.preview_kart.visible = true

	# Rückkehr in die App: sofortige Prüfung beim nächsten Bild.
	garage.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(
		is_equal_approx(garage._preview_watch_time, garage.PREVIEW_WATCH_SECONDS),
		"nach der Rückkehr in die App prüft der Wächter sofort"
	)

	# Höchstzahl je Besuch.
	while garage.preview_repairs.size() < garage.PREVIEW_REPAIR_LIMIT:
		garage.preview_kart.visible = false
		await _watch_now()
	garage.preview_kart.visible = false
	await _watch_now()
	_check(
		garage.preview_repairs.size() == garage.PREVIEW_REPAIR_LIMIT,
		"höchstens %d Reparaturen je Besuch" % garage.PREVIEW_REPAIR_LIMIT
	)
	garage.preview_kart.visible = true

	# Werkstatt und Streckenwahl: dort ist die Vorschau absichtlich anders – kein Eingriff.
	garage.preview_repairs.clear()
	garage.step = 3
	garage._preview_watch_time = garage.PREVIEW_WATCH_SECONDS
	garage._watch_preview(0.0)
	_check(garage.preview_repairs.is_empty(), "Streckenwahl: Wächter greift nicht ein")
	garage.step = 0

	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	game.queue_free()
	await _frames(10)
	print(
		(
			"[MenuWatchdog] %s: %d Prüfungen, %d Fehler"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
