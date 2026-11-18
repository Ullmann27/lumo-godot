extends SceneTree
## Lumos Einführung mit ECHTEN Eingaben über den App-Einstieg (HostBridge-
## Startoptionen wie aus Flutter): Luftblick, Lumo am freien Bauplatz, Tippen
## auf Bauplatz/Karten/Bereiche/„Nächster Tag“, sichtbarer Ernteweg.
## Prüft außerdem: altes Dorf bekommt das Angebot statt still „erledigt“,
## unterbrochene Einführung setzt am richtigen Schritt fort, Überspringen,
## Wiederholen, „Lumo, zeig mir mein Dorf“, Text und Stimme unabhängig,
## Zeigerziele existieren und sind sichtbar, vier Bereiche, Tipp auf Gebäude.
const CHILD := "village_tutorial_regression"
const SLOT := 5
const TOUR := "Lumo, zeig mir mein Dorf"
var checks := 0
var failures: Array[String] = []
var world_script
var density := 1.0


class FakeHost:
	extends Object
	var spoken: Array[String] = []

	func speakLearning(payload: String) -> bool:  # gdlint: disable=function-name
		spoken.append(str(JSON.parse_string(payload).get("text", "")))
		return true

	func stopLearningSpeech() -> void:  # gdlint: disable=function-name
		pass


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
	return root.get_final_transform() * (village.safe_ui.get_global_transform_with_canvas() * local)


func _tap_local(village: Node, local: Vector2) -> void:
	var point := _screen(village, local)
	await _touch(point, true)
	await _touch(point, false)
	await _frames(4)


func _tap_control(village: Node, control: Control) -> void:
	if control == null:
		_check(false, "Knopf fehlt")
		return
	var rect: Rect2 = village._hud_rect(control)
	await _tap_local(village, rect.get_center())


func _bubble_button(tutorial: Node, caption: String) -> Button:
	for child in tutorial.bubble_buttons.get_children():
		if child is Button and child.text == caption and not child.is_queued_for_deletion():
			return child
	return null


func _options(child: String, extra := {}) -> Dictionary:
	var launch := {
		"game": "settlement", "scene": "settlement", "livingVillage": true, "settlementMode": "settlement",
		"childKey": child, "buildSlot": SLOT, "displayDensity": density,
	}
	launch.merge(extra, true)
	return launch


func _open(child: String, extra := {}) -> Node:
	var launch := _options(child, extra)
	root.get_node("HostBridge").set("_options", launch.duplicate(true))
	root.get_node("SceneRouter").launch_options = launch.duplicate(true)
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(10)
	return village


func _close(village: Node) -> void:
	village.queue_free()
	await _frames(4)


func _land(village: Node) -> void:
	for _i in range(900):
		if not village.tutorial.guide.flying:
			break
		await process_frame
	await _frames(4)


## Zeigerziel des aktuellen Schritts: existiert, ist sichtbar, liegt im Bild.
func _pointer_ok(village: Node, label: String) -> Rect2:
	var tutorial: Node = village.tutorial
	var rect: Rect2 = tutorial.target_rect()
	_check(rect.size.x >= 20.0 and rect.size.y >= 20.0, "Zeigerziel existiert: " + label)
	_check(Rect2(Vector2.ZERO, village.safe_ui.size).grow(1.0).encloses(rect), "Zeigerziel im Bild: %s %s" % [label, rect])
	_check(tutorial.ring.visible and tutorial.pointer.visible, "Ring und Pfeil sichtbar: " + label)
	return rect


func _save_path(child: String) -> String:
	return world_script.project_path(child, SLOT, "village")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	Input.emulate_touch_from_mouse = true
	world_script = load("res://scripts/creative/build_settlement_world.gd")
	DirAccess.remove_absolute(_save_path(CHILD))
	await _first_visit()
	await _reload_finished()
	await _interrupted()
	await _skip_and_tour()
	await _old_villages()
	await _legacy_version_one()
	await _text_and_voice()
	await _portrait_and_fold()
	for child in [CHILD, CHILD + "_b", CHILD + "_c", CHILD + "_d", CHILD + "_e", CHILD + "_f"]:
		DirAccess.remove_absolute(_save_path(child))
	if failures.is_empty():
		print("[VillageTutorial] PASS checks=", checks)
		quit(0)
	else:
		print("[VillageTutorial] FAIL checks=", checks, " failures=", failures)
		quit(1)


func _first_visit() -> void:
	var village: Node = await _open(CHILD)
	var tutorial: Node = village.tutorial
	_check(tutorial != null and tutorial.active(), "Neues Profil startet mit Lumos Einführung")
	_check(tutorial.current_id() == "luftblick", "Erster Schritt: Blick aus der Luft")
	_check(tutorial.guide.flying and village.radius > 80.0, "Kamera ist hoch über dem Tal (%.0f)" % village.radius)
	_check(_bubble_button(tutorial, "Überspringen") != null, "Luftblick ist überspringbar")
	for spec in tutorial.STEPS:
		_check(str(spec.text).split(" ", false).size() <= 12, "Höchstens 12 Wörter: " + str(spec.text))
		_check(str(spec.say) != "" and str(spec.mode) != "", "Eigener Sprechsatz: " + str(spec.id))
	# Starter dock: only what house and farm need.
	_check(village.area_tabs.bauen.visible and village.area_tabs.versorgen.visible, "Bauen und Versorgen sind da")
	_check(not village.area_tabs.nachbarn.visible and not village.area_tabs.schuetzen.visible, "Nachbarn/Schützen öffnen sich später")
	_check(village.purchase_buttons.house.visible and not village.purchase_buttons.clinic.visible, "Am Anfang nur das Wohnhaus beim Bauen")
	_check(not village.bottom.visible, "Während des Flugs freier Blick auf das Tal")
	var before: Dictionary = village.model.snapshot()
	await _land(village)
	_check(village.day_button.is_visible_in_tree(), "Nach der Landung ist „Nächster Tag“ fest sichtbar")
	_check(tutorial.current_id() == "hallo", "Nach dem Flug: Lumo begrüßt")
	_check(absf(village.radius - 26.0) < 0.5 and village.tilt < 0.8, "Kamera setzt nah auf (%.1f)" % village.radius)
	var lumo: Node3D = village.village_life.lumo
	_check(lumo != null and lumo.is_usable(), "Das echte, geriggte Lumo-Modell steht im Dorf")
	var plot: int = tutorial.guide.guide_plot
	_check(plot >= 0 and village.model.plot_buildable(plot), "Landeplatz ist ein freier Bauplatz")
	if lumo != null and plot >= 0:
		var gap := Vector2(lumo.position.x, lumo.position.z).distance_to(Vector2(village._plot_world(plot).x, village._plot_world(plot).z))
		_check(gap < 4.0, "Lumo steht neben dem Bauplatz (%.1f)" % gap)
		await _frames(30)
		var still := Vector2(lumo.position.x, lumo.position.z).distance_to(Vector2(village._plot_world(plot).x, village._plot_world(plot).z))
		_check(village.village_life.lumo_path.size() == 1 and absf(still - gap) < 0.05, "Lumo wartet am Bauplatz statt herumzulaufen")
	_check(tutorial.bubble_text.text == "Hier entsteht dein Dorf. Wollen wir das erste Haus bauen?", "Lumos Satz: " + tutorial.bubble_text.text)
	_pointer_ok(village, "Lumo")
	_check(village.model.snapshot() == before, "Luftblick verändert den Spielstand nicht")
	await _tap_control(village, _bubble_button(tutorial, "Ja, los!"))
	_check(tutorial.current_id() == "bauplatz", "Ja führt zum Bauplatz")
	var plot_rect := _pointer_ok(village, "Bauplatz")
	await _tap_local(village, plot_rect.get_center())
	_check(village.selected_plot >= 0, "Antippen wählt den Bauplatz")
	_check(tutorial.current_id() == "wohnhaus", "Weiter zum Wohnhaus")
	var house_rect := _pointer_ok(village, "Wohnhaus-Karte")
	_check(house_rect.intersects(village._hud_rect(village.purchase_buttons.house)), "Pfeil zeigt auf die Wohnhaus-Karte")
	var wood_before := int(village.model.player().resources.wood)
	await _tap_local(village, house_rect.get_center())
	_check(village.model._count(village.model.player(), "house") == 1, "Echter Tipp baut das Wohnhaus")
	_check(int(village.model.player().resources.wood) == wood_before - 4, "Mit den echten Baukosten")
	_check(tutorial.current_id() == "versorgen", "Dann: Bereich Versorgen öffnen")
	var tab_rect := _pointer_ok(village, "Bereich Versorgen")
	_check(tab_rect.intersects(village._hud_rect(village.area_tabs.versorgen)), "Pfeil zeigt auf „Versorgen“")
	await _tap_local(village, tab_rect.get_center())
	_check(village.dock_section() == "versorgen", "Tipp öffnet „Versorgen“")
	_check(tutorial.current_id() == "bauernhof", "Dann der Bauernhof")
	var farm_rect := _pointer_ok(village, "Bauernhof-Karte")
	_check(farm_rect.intersects(village._hud_rect(village.purchase_buttons.farm)), "Pfeil zeigt auf die Bauernhof-Karte")
	_check(not village.purchase_buttons.house.visible, "Unter Versorgen keine Wohnhäuser")
	await _tap_local(village, farm_rect.get_center())
	_check(village.model._count(village.model.player(), "farm") == 1, "Bauernhof gebaut")
	_check(tutorial.current_id() == "tag", "Dann der nächste Tag")
	var day_rect := _pointer_ok(village, "Nächster Tag")
	_check(day_rect.intersects(village._hud_rect(village.day_button)), "Pfeil zeigt auf „Nächster Tag“")
	var day_before := int(village.model.day)
	var food_before := int(village.model.player().resources.food)
	await _tap_local(village, day_rect.get_center())
	_check(int(village.model.day) == day_before + 1, "Echter Tipp auf „Nächster Tag“")
	_check(tutorial.current_id() == "ernte", "Dann die erste Ernte")
	var produced := int(tutorial.harvest.get("food", 0))
	var eaten := int(tutorial.harvest.get("eaten", 0))
	_check(produced > 0, "Der Hof hat wirklich geerntet (%d)" % produced)
	_check(int(village.model.player().resources.food) == food_before + produced - eaten, "Vorrat stimmt: %d + %d − %d" % [food_before, produced, eaten])
	_check(tutorial.bubble_text.text.contains(str(produced)), "Lumo nennt die echte Ernte: " + tutorial.bubble_text.text)
	_check(str(tutorial.guide.get_meta("flow", "")) == "hof_vorrat", "Karotten fliegen sichtbar vom Hof in den Vorrat")
	_check(tutorial.guide.flow_ends().size() == 2 and tutorial.guide.flow_ends()[0] != Vector2.INF, "Ernteweg beginnt am echten Hof")
	_pointer_ok(village, "Vorrat")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(tutorial.current_id() == "familie", "Dann: Vorrat versorgt die Familie")
	_check(str(tutorial.guide.get_meta("flow", "")) == "vorrat_familie", "Karotten gehen vom Vorrat zur Familie")
	_check(tutorial.bubble_text.text.contains(str(eaten)), "Lumo nennt den echten Verbrauch: " + tutorial.bubble_text.text)
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(tutorial.current_id() == "ziel", "Zum Schluss das Ziel")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(not tutorial.active() and tutorial.done, "Einführung beendet – das Dorf läuft weiter")
	_check(not tutorial.visible or not tutorial.context_topic.is_empty(), "Keine Einführungsblase mehr im freien Spiel")
	_check(village.village_life.lumo_path.size() > 1, "Lumo läuft danach wieder seine Runde")
	_check(village.dock.full_tools and village.purchase_buttons.well.visible, "Nach der Einführung: mehr Gebäude beim Versorgen")
	_check(village.model.campaign_status().chapter >= 2, "Kapitel 1 ist mit echten Handlungen geschafft")
	if not tutorial.context_topic.is_empty():
		await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	# Tap on a map object opens its area directly.
	village.select_dock_section("bauen")
	var farm_plot := -1
	for building in village.model.player().buildings:
		if str(building.kind) == "farm":
			farm_plot = int(building.plot)
	var farm_screen: Vector2 = root.get_final_transform() * village.camera.unproject_position(village._plot_world(farm_plot) + Vector3.UP * 0.4)
	await _touch(farm_screen, true)
	await _touch(farm_screen, false)
	await _frames(4)
	_check(village.selected_plot == farm_plot and village.dock_section() == "versorgen", "Tipp auf den Hof öffnet „Versorgen“")
	# Context explanation exactly once.
	_check(tutorial.explain_once("handel"), "Erster Handel wird kurz erklärt")
	_check(tutorial.visible and tutorial.bubble_text.text.contains("tauschst"), "Kurzer Satz statt Textwand")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(not tutorial.explain_once("handel"), "Dieselbe Erklärung nur einmal")
	# Replay a topic.
	tutorial.replay("Essen")
	_check(tutorial.active() and tutorial.current_id() == "versorgen", "„Lumo zeigt es noch einmal“: Essen")
	_check(_bubble_button(tutorial, "Überspringen") == null, "Wiederholung ohne Überspring-Druck")
	tutorial.replay("Rohstoffe")
	_pointer_ok(village, "Rohstoffe")
	await _tap_control(village, _bubble_button(tutorial, "Verstanden"))
	_check(not tutorial.active() and tutorial.done, "Wiederholung endet nach dem Thema, Einführung bleibt erledigt")
	_check(village._save(), "Speichern")
	await _close(village)


func _reload_finished() -> void:
	var village: Node = await _open(CHILD)
	_check(village.tutorial.done and not village.tutorial.active(), "Einführung bleibt erledigt")
	_check(not village.tutorial.offering, "Kein Angebot nach fertiger Einführung")
	_check(village.tutorial.seen.has("handel"), "Gesehene Erklärungen sind gespeichert")
	_check(village.dock.full_tools, "Freigeschaltete Werkzeuge bleiben")
	await _close(village)


func _interrupted() -> void:
	var child := CHILD + "_b"
	DirAccess.remove_absolute(_save_path(child))
	var village: Node = await _open(child)
	await _land(village)
	await _tap_control(village, _bubble_button(village.tutorial, "Ja, los!"))
	await _tap_local(village, village.tutorial.target_rect().get_center())
	await _tap_local(village, village.tutorial.target_rect().get_center())
	_check(village.tutorial.current_id() == "versorgen", "Haus gebaut, jetzt Versorgen")
	village._save()
	await _close(village)
	village = await _open(child)
	_check(village.tutorial.active() and village.tutorial.current_id() == "versorgen", "Rückkehr: weiter bei „Versorgen“ (%s)" % village.tutorial.current_id())
	_check(not village.tutorial.guide.flying, "Kein zweiter Luftflug bei Rückkehr")
	_check(absf(village.radius - 26.0) < 0.5, "Kamera wieder neben Lumo am Bauplatz")
	_check(village.tutorial.guide.lumo_held, "Lumo wartet wieder am Bauplatz")
	_pointer_ok(village, "Versorgen nach Rückkehr")
	await _tap_local(village, village.tutorial.target_rect().get_center())
	await _tap_local(village, village.tutorial.target_rect().get_center())
	_check(village.tutorial.current_id() == "tag", "Hof gebaut, jetzt Tag")
	village._save()
	await _close(village)
	village = await _open(child)
	_check(village.tutorial.current_id() == "tag", "Rückkehr: weiter bei „Nächster Tag“")
	await _close(village)


func _skip_and_tour() -> void:
	var child := CHILD + "_c"
	DirAccess.remove_absolute(_save_path(child))
	var village: Node = await _open(child)
	_check(village.tutorial.guide.flying, "Flug läuft")
	await _tap_control(village, _bubble_button(village.tutorial, "Überspringen"))
	_check(not village.tutorial.active() and village.tutorial.done, "Überspringen im Luftblick beendet die Einführung")
	_check(not village.tutorial.guide.flying, "Flug sofort beendet")
	village._save()
	await _close(village)
	village = await _open(child)
	_check(not village.tutorial.visible, "Übersprungen bleibt übersprungen")
	# „Lumo, zeig mir mein Dorf“ über das echte Pausenmenü.
	await _tap_control(village, village.walk_button.get_parent().get_child(village.walk_button.get_index() + 1))
	_check(village.paused, "Pausenmenü offen")
	var tour: Button = village.pause_panel.find_child("VillageTutorialTour", true, false)
	_check(tour != null and tour.text == TOUR, "Pausenmenü: „Lumo, zeig mir mein Dorf“")
	await _tap_control(village, tour)
	_check(not village.paused and village.tutorial.active() and village.tutorial.guide.flying, "Rundgang startet mit Luftblick")
	await _land(village)
	_check(village.tutorial.current_id() == "hallo", "Rundgang: Lumo begrüßt am Bauplatz")
	village.model.try_build("house", village._next_free_plot())
	village.model.try_build("farm", village._next_free_plot())
	await _tap_control(village, _bubble_button(village.tutorial, "Ja, los!"))
	_check(village.tutorial.current_id() == "tag", "Erledigtes wird übersprungen: weiter beim letzten sinnvollen Schritt (%s)" % village.tutorial.current_id())
	await _close(village)


func _write_without_meta(child: String, prepare: Callable) -> void:
	DirAccess.remove_absolute(_save_path(child))
	var village: Node = await _open(child)
	village.tutorial.skip()
	prepare.call(village)
	village._save()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path(child)))
	await _close(village)
	raw.erase("village_meta")
	var file := FileAccess.open(_save_path(child), FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()


func _old_villages() -> void:
	var child := CHILD + "_d"
	await _write_without_meta(child, func(village: Node) -> void:
		village.model.try_build("house", village._next_free_plot())
		village.model.try_build("farm", village._next_free_plot()))
	var village: Node = await _open(child)
	_check(not village.save_blocked, "Alte Datei ohne village_meta lädt")
	_check(village.model.player().buildings.size() == 2, "Altes Dorf mit zwei Gebäuden")
	_check(not village.tutorial.done, "Zwei Gebäude: NICHT still als erledigt markiert")
	_check(village.tutorial.offering and village.tutorial.visible, "Lumo bietet den Rundgang an")
	_check(_bubble_button(village.tutorial, TOUR) != null, "Angebot heißt „Lumo, zeig mir mein Dorf“")
	_check(village.dock.full_tools and village.area_tabs.schuetzen.visible, "Altes Dorf behält alle Bereiche")
	await _tap_control(village, _bubble_button(village.tutorial, "Nein, ich baue weiter"))
	_check(village.tutorial.done and not village.tutorial.visible, "Bewusst abgelehnt")
	village._save()
	await _close(village)
	village = await _open(child)
	_check(not village.tutorial.visible and village.tutorial.done, "Ablehnung bleibt gespeichert")
	await _close(village)
	# Day four without buildings, accepting the tour.
	child = CHILD + "_e"
	await _write_without_meta(child, func(village: Node) -> void:
		for _i in range(3):
			village.model.next_day())
	village = await _open(child)
	_check(int(village.model.day) == 4 and not village.tutorial.done and village.tutorial.offering, "Tag 4: Angebot statt still erledigt")
	await _tap_control(village, _bubble_button(village.tutorial, TOUR))
	_check(village.tutorial.active() and village.tutorial.guide.flying, "Angebot angenommen: Luftblick")
	await _land(village)
	await _tap_control(village, _bubble_button(village.tutorial, "Ja, los!"))
	_check(village.tutorial.current_id() == "bauplatz", "Ohne Gebäude: es geht beim Bauplatz los")
	await _close(village)


func _legacy_version_one() -> void:
	var child := CHILD + "_f"
	DirAccess.remove_absolute(_save_path(child))
	var village: Node = await _open(child)
	village.model.try_build("house", village._next_free_plot())
	village._save()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path(child)))
	await _close(village)
	# Version 1: step 5 = "bauernhof" in the old nine-step list.
	raw.village_meta.tutorial = {"version": 1, "step": 5, "done": false, "seen": ["handel"], "start_day": 1}
	var file := FileAccess.open(_save_path(child), FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	village = await _open(child)
	_check(village.tutorial.current_id() == "versorgen", "Alter Stand (Schritt Bauernhof) führt zu Versorgen → Hof (%s)" % village.tutorial.current_id())
	_check(village.tutorial.seen.has("handel"), "Alte gesehene Erklärungen bleiben")
	await _close(village)


func _text_and_voice() -> void:
	var child := CHILD + "_c"
	DirAccess.remove_absolute(_save_path(child))
	# Text off: pointer, ring, Lumo and buttons still lead; the voice line exists.
	var village: Node = await _open(child, {"villageTutorialText": false})
	await _land(village)
	var tutorial: Node = village.tutorial
	_check(not tutorial.bubble_text.visible, "Text kann aus sein")
	_check(tutorial.voice.requested.has(tutorial.step_text(tutorial.step, true)), "Sprechsatz wird angefordert, auch ohne Text")
	_check(_bubble_button(tutorial, "Ja, los!") != null and tutorial.ring.visible, "Ohne Text: Knöpfe und Zeiger führen")
	await _close(village)
	# Voice with a (test) host and text on; voice off keeps text alone.
	village = await _open(child)
	await _land(village)
	tutorial = village.tutorial
	_check(tutorial.bubble_text.visible and not tutorial.voice.available(), "Ohne Freigabe: nur Text, keine Stimme")
	_check(_bubble_button(tutorial, "🔊") == null, "Kein Vorlese-Knopf ohne Stimme")
	var host := FakeHost.new()
	tutorial.voice.enabled = true
	tutorial.voice.host = host
	tutorial.spoken_step = ""
	tutorial._show()
	_check(host.spoken.size() == 1 and host.spoken[0] == tutorial.step_text(tutorial.step, true), "Mit Stimme: Lumo spricht den Satz")
	_check(_bubble_button(tutorial, "🔊") != null, "Vorlese-Knopf mit Stimme")
	await _frames(3)
	await _tap_control(village, _bubble_button(tutorial, "🔊"))
	_check(host.spoken.size() == 2, "Vorlese-Knopf spricht noch einmal")
	tutorial.voice.host = null
	host.free()
	await _close(village)


func _portrait_and_fold() -> void:
	for spec in [[Vector2i(412, 915), 1.0], [Vector2i(1812, 2176), 2.625], [Vector2i(1080, 2340), 2.625], [Vector2i(2176, 1812), 2.625]]:
		root.size = spec[0]
		density = float(spec[1])
		var child := CHILD + "_c"
		DirAccess.remove_absolute(_save_path(child))
		var village: Node = await _open(child)
		await _land(village)
		await _frames(6)
		var label := "%dx%d" % [root.size.x, root.size.y]
		var bubble_rect: Rect2 = village._hud_rect(village.tutorial.bubble)
		_check(Rect2(Vector2.ZERO, village.safe_ui.size).grow(0.5).encloses(bubble_rect), "%s: Blase passt %s" % [label, bubble_rect])
		var start: Button = _bubble_button(village.tutorial, "Ja, los!")
		_check(start != null and start.get_global_rect().size.y * _scale() >= 48.0 * density - 0.5, "%s: Knopf ≥ 48 dp" % label)
		for control in [village.area_tabs.bauen, village.area_tabs.versorgen, village.day_button]:
			var pixels: float = minf(control.get_global_rect().size.x, control.get_global_rect().size.y) * _scale()
			_check(control.is_visible_in_tree() and pixels >= 48.0 * density - 0.5, "%s: %s ≥ 48 dp (%.0f px)" % [label, control.text, pixels])
			_check(Rect2(Vector2.ZERO, village.safe_ui.size).grow(0.5).encloses(village._hud_rect(control)), "%s: %s im Bild" % [label, control.text])
		await _tap_control(village, start)
		await _tap_local(village, village.tutorial.target_rect().get_center())
		await _tap_local(village, village.tutorial.target_rect().get_center())
		_check(village.tutorial.current_id() == "versorgen", "%s: Haus mit echten Tipps gebaut" % label)
		_pointer_ok(village, label + " Versorgen")
		await _tap_local(village, village.tutorial.target_rect().get_center())
		_pointer_ok(village, label + " Bauernhof")
		await _tap_local(village, village.tutorial.target_rect().get_center())
		_pointer_ok(village, label + " Nächster Tag")
		_check(village.tutorial.current_id() == "tag", "%s: Hof gebaut" % label)
		await _close(village)
	root.size = Vector2i(1280, 720)
	density = 1.0


## Physische Pixel je logischer Einheit (Fenster / Inhaltsgröße).
func _scale() -> float:
	return root.get_final_transform().x.x
