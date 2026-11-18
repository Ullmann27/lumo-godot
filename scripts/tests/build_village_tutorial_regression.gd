extends SceneTree
## Lumos Einführung mit ECHTEN Eingaben: Tippen auf die echten Knöpfe, Wischen
## über die Welt, Antippen des Bauplatzes. Prüft Übergang ins laufende Spiel,
## Überspringen, Speichern/Laden, Wiederholen je Thema und Kontext-Erklärungen.
const CHILD := "village_tutorial_regression"
const SLOT := 5
var checks := 0
var failures: Array[String] = []
var world_script


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageTutorial] " + message)


func _frames(count := 6) -> void:
	for _i in range(count):
		await process_frame


func _touch(point: Vector2, pressed: bool, index := 3) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _drag(start: Vector2, end: Vector2) -> void:
	await _touch(start, true)
	var previous := start
	for step in range(1, 13):
		var point := start.lerp(end, float(step) / 12.0)
		var event := InputEventScreenDrag.new()
		event.index = 3
		event.position = point
		event.relative = point - previous
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		previous = point
		await process_frame
	await _touch(end, false)
	await _frames(3)


func _screen(village: Node, local: Vector2) -> Vector2:
	return village.safe_ui.get_global_transform_with_canvas() * local


func _tap_local(village: Node, local: Vector2) -> void:
	var point := _screen(village, local)
	await _touch(point, true)
	await _touch(point, false)
	await _frames(4)


func _tap_control(village: Node, control: Control) -> void:
	var rect: Rect2 = village._hud_rect(control)
	await _tap_local(village, rect.get_center())


func _bubble_button(tutorial: Node, caption: String) -> Button:
	for child in tutorial.bubble_buttons.get_children():
		if child is Button and child.text == caption:
			return child
	return null


func _open(child: String) -> Node:
	root.get_node("SceneRouter").launch_options = {
		"childKey": child, "buildSlot": SLOT, "settlementMode": "settlement", "livingVillage": true
	}
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(10)
	return village


func _close(village: Node) -> void:
	village.queue_free()
	await _frames(4)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	Input.emulate_touch_from_mouse = true
	world_script = load("res://scripts/creative/build_settlement_world.gd")
	var save: String = world_script.project_path(CHILD, SLOT, "village")
	DirAccess.remove_absolute(save)
	var village: Node = await _open(CHILD)
	var tutorial: Node = village.tutorial
	_check(tutorial != null and tutorial.active(), "Neues Dorf startet mit Lumos Einführung")
	_check(tutorial.current_id() == "hallo", "Erster Schritt: Lumo begrüßt")
	_check(tutorial.bubble.is_visible_in_tree(), "Sprechblase ist sichtbar")
	_check(tutorial.bubble.find_child("LumoFace", true, false).texture != null, "Lumos echtes Gesicht in der Blase")
	for spec in tutorial.STEPS:
		_check(str(spec.text).split(" ", false).size() <= 12, "Höchstens 12 Wörter: " + str(spec.text))
	var before: Dictionary = village.model.snapshot()
	await _tap_control(village, _bubble_button(tutorial, "Los geht's!"))
	_check(tutorial.current_id() == "kamera", "Knopf führt zum Umsehen")
	_check(village.model.snapshot() == before, "Begrüßung verändert den Spielstand nicht")
	# Camera: a real one-finger swipe over the world.
	var band: Vector2 = village.tutorial_safe_band()
	var mid := Vector2(village.safe_ui.size.x * 0.5, (band.x + band.y) * 0.5)
	_check(tutorial.target_rect().size != Vector2.ZERO, "Zeiger zeigt auf die Welt")
	await _drag(_screen(village, mid + Vector2(-140, 0)), _screen(village, mid + Vector2(160, 30)))
	_check(tutorial.current_id() == "bauplatz", "Echtes Wischen erfüllt den Kamera-Schritt")
	# Plot: tap where the pointer shows.
	var plot_rect: Rect2 = tutorial.target_rect()
	_check(plot_rect.size != Vector2.ZERO, "Zeiger zeigt auf einen freien Bauplatz")
	await _tap_local(village, plot_rect.get_center())
	_check(village.selected_plot >= 0, "Antippen wählt den Bauplatz")
	_check(tutorial.current_id() == "wohnhaus", "Weiter zum Wohnhaus")
	var house_rect: Rect2 = tutorial.target_rect()
	_check(house_rect.size.x >= 48.0, "Zeiger auf der Wohnhaus-Karte")
	var wood_before := int(village.model.player().resources.wood)
	await _tap_local(village, house_rect.get_center())
	_check(village.model._count(village.model.player(), "house") == 1, "Echter Tipp baut das Wohnhaus")
	_check(int(village.model.player().resources.wood) == wood_before - 4, "Mit den echten Baukosten")
	_check(tutorial.current_id() == "rohstoffe", "Dann werden Rohstoffe erklärt")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(tutorial.current_id() == "bauernhof", "Dann der Bauernhof")
	await _tap_local(village, tutorial.target_rect().get_center())
	_check(village.model._count(village.model.player(), "farm") == 1, "Bauernhof ohne extra Bauplatzwahl gebaut")
	_check(tutorial.current_id() == "tag", "Dann der nächste Tag")
	var day_before := int(village.model.day)
	await _tap_local(village, tutorial.target_rect().get_center())
	_check(int(village.model.day) == day_before + 1, "Echter Tipp auf „Nächster Tag“")
	_check(tutorial.current_id() == "bewohner", "Dann die Bewohner")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(tutorial.current_id() == "ziel", "Zum Schluss das Ziel")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(not tutorial.active() and tutorial.done, "Einführung beendet – das Dorf läuft weiter")
	_check(not tutorial.visible, "Keine Blase mehr im freien Spiel")
	_check(village.model.campaign_status().chapter >= 2, "Kapitel 1 ist mit echten Handlungen geschafft")
	# Context explanation exactly once.
	_check(tutorial.explain_once("handel"), "Erster Handel wird kurz erklärt")
	_check(tutorial.visible and tutorial.bubble_text.text.contains("tauschst"), "Kurzer Satz statt Textwand")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(not tutorial.explain_once("handel"), "Dieselbe Erklärung nur einmal")
	# Replay a topic from the pause menu path.
	tutorial.replay("Bauen")
	_check(tutorial.active() and tutorial.current_id() == "bauplatz", "„Lumo zeigt es noch einmal“: Bauen")
	_check(_bubble_button(tutorial, "Überspringen") == null, "Wiederholung ohne Überspring-Druck")
	tutorial.replay("Rohstoffe")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(not tutorial.active(), "Wiederholung endet nach dem Thema")
	_check(village._save(), "Speichern")
	var snapshot: Dictionary = village.model.snapshot()
	await _close(village)
	# Reload: tutorial state and the village persist.
	village = await _open(CHILD)
	_check(village.model.snapshot() == snapshot, "Dorf lädt unverändert")
	_check(village.tutorial.done and not village.tutorial.visible, "Einführung bleibt erledigt")
	_check(village.tutorial.seen.has("handel"), "Gesehene Erklärungen sind gespeichert")
	await _close(village)
	DirAccess.remove_absolute(save)
	# Skip path.
	village = await _open(CHILD)
	await _tap_control(village, _bubble_button(village.tutorial, "Ich kenne das schon"))
	_check(not village.tutorial.active(), "„Ich kenne das schon“ überspringt")
	village._save()
	await _close(village)
	village = await _open(CHILD)
	_check(not village.tutorial.visible, "Übersprungen bleibt übersprungen")
	await _close(village)
	# Older saves without tutorial data: grown villages are not sent back.
	var legacy_text := FileAccess.get_file_as_string(save)
	var legacy: Dictionary = JSON.parse_string(legacy_text)
	legacy.erase("village_meta")
	var file := FileAccess.open(save, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	village = await _open(CHILD)
	_check(not village.save_blocked, "Alte Datei ohne village_meta lädt")
	_check(village.tutorial.active(), "Frisches altes Dorf bekommt die Einführung angeboten")
	await _close(village)
	DirAccess.remove_absolute(save)
	# Portrait: bubble fits the screen.
	root.size = Vector2i(412, 915)
	village = await _open(CHILD)
	await _frames(6)
	var bubble_rect: Rect2 = village._hud_rect(village.tutorial.bubble)
	_check(Rect2(Vector2.ZERO, village.safe_ui.size).grow(0.5).encloses(bubble_rect), "Hochformat: Blase passt %s in %s" % [bubble_rect, village.safe_ui.size])
	var start: Button = _bubble_button(village.tutorial, "Los geht's!")
	_check(start != null and start.size.y >= 48.0, "Hochformat: Knopf ≥ 48 dp")
	await _close(village)
	DirAccess.remove_absolute(save)
	if failures.is_empty():
		print("[VillageTutorial] PASS checks=", checks)
		quit(0)
	else:
		print("[VillageTutorial] FAIL checks=", checks, " failures=", failures)
		quit(1)
