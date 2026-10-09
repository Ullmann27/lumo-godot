extends SceneTree
## Garage und Werkstatt: vierzehn Karts als Karten (gesperrte gedimmt), Wertebalken, Werkstatt öffnen,
## Teile verbessern, Aussehen ansehen/kaufen/wählen, Sterne zurückholen, Zurück-Taste und Layout
## auf Querformat, Fold-Größen und Hochformat. Mit Anzeige (xvfb).
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const GAME = "res://scenes/games/kart_island.tscn"
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _inside(control: Control, label: String) -> void:
	assert(control.is_visible_in_tree(), label + " ist sichtbar")
	var rect: Rect2 = control.get_global_rect()
	assert(root.get_visible_rect().grow(0.5).encloses(rect), "%s liegt im Bild (%s in %s)" % [label, rect, root.get_visible_rect()])


func _find(parent: Node, node_name: String) -> Node:
	return parent.find_child(node_name, true, false)


func _check_cards() -> void:
	var garage = game.garage
	garage.stars = 20
	garage.unlocked_ids = ["comet", "glider", "turbo"]
	garage.step = 2
	garage._refresh()
	await _settle()
	var grid: GridContainer = garage.choices.get_child(0)
	assert(grid.get_child_count() == 14, "Vierzehn Kart-Karten")
	var locked: int = 0
	for card in grid.get_children():
		assert(card.name.begins_with("KartCard_"))
		if card.disabled:
			locked += 1
	assert(locked == 5, "Fünf Karts sind bei 20 Sternen noch gesperrt (%d)" % locked)
	assert(not grid.get_node("KartCard_glider").disabled and grid.get_node("KartCard_turbo").disabled == false, "Glider (8) und Aurora GT (18) sind offen")
	assert(grid.get_node("KartCard_blitz").disabled and grid.get_node("KartCard_stella").disabled, "Blitz und Stella gesperrt")
	assert(grid.get_node("KartCard_stella").lock_label.visible and "noch 100" in grid.get_node("KartCard_stella").lock_label.text, "Gesperrte Karte nennt die fehlenden Sterne")
	assert(garage.kart_panel.visible and is_instance_valid(garage.kart_bars), "Wertebalken stehen unter der Vorschau")
	# Auswahl wirkt auf Einstellung, Wertebalken und Vorschau.
	grid.get_node("KartCard_glider").pressed.emit()
	await _settle()
	assert(garage.setup.kart == "glider")
	assert(is_equal_approx(float(garage.kart_bars.base.handling), 9.0) and is_equal_approx(float(garage.kart_bars.base.speed), 5.0), "Wertebalken zeigen Glider")
	assert("Glider" in garage.kart_summary.text and "Wendig" in garage.kart_summary.text)
	assert(garage.preview_kart.kart_style == "glider", "Die 3D-Vorschau zeigt den Glider")
	grid = garage.choices.get_child(0)
	grid.get_node("KartCard_blitz").pressed.emit()
	assert(garage.setup.kart == "glider", "Gesperrte Karts lassen sich nicht wählen")


func _check_workshop() -> void:
	var garage = game.garage
	garage.setup.kart = "comet"
	garage.step = 2
	garage.workshop = TUNING.new("ws_garage_test", 12)
	garage.workshop.save_enabled = false
	garage._refresh()
	await _settle()
	assert(garage.workshop_button.visible and not garage.workshop_button.disabled and "12" in garage.workshop_button.text, "Werkstatt-Knopf zeigt das Budget")
	garage.workshop_button.pressed.emit()
	await _settle()
	var view = garage.workshop_view
	assert(is_instance_valid(view) and view.name == "Workshop", "Werkstatt öffnet sich über der Garage")
	assert(garage.preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Garage-Vorschau pausiert hinter der Werkstatt")
	assert("COMET" in view.title_label.text and view.budget_label.text == "★ 12 frei")
	var changes: Array = [0]
	view.changed.connect(func(): changes[0] += 1)
	# Teil verbessern.
	var motor: Button = _find(_find(view, "Part_motor"), "Upgrade")
	assert(not motor.disabled and "Stufe 1" in motor.text and "4" in motor.text, "Motor Stufe 1 kostet 4 (%s)" % motor.text)
	motor.pressed.emit()
	await _settle()
	assert(view.tuning.level("comet", "motor") == 1 and view.budget_label.text == "★ 8 frei" and changes[0] == 1)
	assert(is_equal_approx(float(view.bars.bonus.speed), 0.4) and is_equal_approx(float(view.bars.base.speed), 6.0), "Tuning-Anteil erscheint als Bonus am Balken")
	assert("Motor" in view.toast_label.text and "Stufe 1" in view.toast_label.text, "Rückmeldung nennt das Teil")
	_find(_find(view, "Part_bremsen"), "Upgrade").pressed.emit()
	assert(view.tuning.level("comet", "bremsen") == 1 and view.tuning.available() == 4)
	var broke: Button = _find(_find(view, "Part_bremsen"), "Upgrade")
	assert(broke.disabled and "Noch 4" in broke.text, "Stufe 2 kostet 8, mit 4 Sternen gesperrt: 'Noch 4 ★' (%s)" % broke.text)
	view.tuning.upgrade("comet", "bremsen")
	assert(view.tuning.level("comet", "bremsen") == 1, "Zu teuer: auch direkt nichts passiert")
	# Aussehen: ansehen, nicht gekauft, kaufen. Erst kommen mehr Fortschrittssterne dazu.
	view.tuning.report_lifetime(200)
	view._refresh_all()
	var paint_row = _find(view, "Look_paint")
	var swatch: Button = _find(paint_row, "Swatch_feuer")
	swatch.pressed.emit()
	await _settle()
	var buy: Button = _find(paint_row, "Buy")
	assert(buy.visible and "6" in buy.text, "Kaufknopf mit Preis")
	assert(view.tuning.chosen("comet", "paint") == "werk", "Erst ansehen, noch nichts gewählt")
	assert(view.preview_kart.chassis_look.paint == Color("b3202a"), "Vorschau zeigt den neuen Lack sofort")
	var before: int = view.tuning.available()
	buy.pressed.emit()
	await _settle()
	assert(view.tuning.chosen("comet", "paint") == "feuer" and view.tuning.available() == before - 6 and not buy.visible)
	_find(paint_row, "Swatch_werk").pressed.emit()
	assert(view.tuning.chosen("comet", "paint") == "werk", "Besessenes Aussehen wählt man ohne Kosten")
	# Alles zurück: erst armieren, dann bestätigen.
	var paid: int = view.tuning.spent_on_parts()
	assert(paid > 0)
	var refund: Button = view.refund_button
	var available: int = view.tuning.available()
	refund.pressed.emit()
	assert(view.tuning.available() == available and "Sicher" in refund.text, "Erster Tipp fragt nach")
	refund.pressed.emit()
	assert(view.tuning.available() == available + paid and view.tuning.total_level("comet") == 0, "Zweiter Tipp gibt alle Sterne zurück")
	assert(view.tuning.owned.has("paint:feuer"), "Das Aussehen bleibt")
	# Zurück schließt zuerst die Werkstatt.
	assert(garage.handle_back() and not is_instance_valid(garage.workshop_view))
	await _settle()
	assert(garage.preview_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Vorschau läuft wieder")
	assert(not garage.handle_back(), "Ohne Werkstatt kümmert sich die Garage nicht um Zurück")
	assert(is_equal_approx(float(garage.kart_bars.bonus.speed), 0.0))


func _check_layouts() -> void:
	var garage = game.garage
	garage.workshop = TUNING.new("ws_layout_test", 500)
	garage.workshop.save_enabled = false
	for size in [Vector2i(1280, 720), Vector2i(800, 480), Vector2i(640, 320), Vector2i(412, 915), Vector2i(690, 829)]:
		root.size = size
		await _settle()
		garage._apply_responsive_layout()
		garage.setup.kart = "comet"
		garage.step = 2
		garage._refresh()
		await _settle()
		garage.workshop_button.pressed.emit()
		await _settle()
		var view = garage.workshop_view
		view._apply_layout()
		await _settle()
		_inside(view.back_button, "Zurück-Knopf %s" % size)
		_inside(view.title_label, "Titel %s" % size)
		_inside(view.budget_label, "Budget %s" % size)
		_inside(view.preview_container, "Vorschau %s" % size)
		assert(view.back_button.get_global_rect().size.y >= 43.9, "Zurück ist groß genug (%s)" % size)
		assert(view.right_scroll.get_child(0).get_child_count() >= 8, "Teile, Aussehen und Rückgabe stehen in der Liste")
		for part in TUNING.PARTS:
			var row = _find(view, "Part_" + str(part.id))
			var button: Button = _find(row, "Upgrade")
			assert(button.get_combined_minimum_size().y >= 43.9, "Verbessern-Knopf ist fingergroß (%s)" % size)
			assert(button.get_global_rect().size.x <= root.get_visible_rect().size.x, "Knopf passt in die Breite (%s)" % size)
		var scroll: ScrollContainer = view.right_scroll
		assert(scroll.get_global_rect().size.x > 100 and scroll.get_global_rect().size.y > 60, "Liste hat nutzbare Fläche (%s)" % size)
		assert(view.body.columns == (1 if size.x < size.y else 2), "Spalten passen zur Ausrichtung (%s)" % size)
		if size == Vector2i(1280, 720):
			DirAccess.make_dir_recursive_absolute("res://exports/holographic-proof")
			root.get_texture().get_image().save_png("res://exports/holographic-proof/workshop-1280x720.png")
		garage.handle_back()
		await _settle()


func _drain() -> void:
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(0.25).timeout


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	game = load(GAME).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	root.size = Vector2i(1280, 720)
	await _settle()
	await _check_cards()
	await _check_workshop()
	await _check_layouts()
	game.abandoned = true
	game.queue_free()
	await _settle()
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	# Freigegebene Szenen, Vorschau-Viewports und Audio-Wiedergaben erst ganz abbauen lassen, damit
	# beim Beenden keine Ressourcen mehr gehalten werden (strenger Probe-Runner).
	await _drain()
	print("[KartWorkshop] PASS: vierzehn Kart-Karten mit gesperrten Karts, Wertebalken, Werkstatt öffnen/verbessern/kaufen/zurückholen, Zurück-Taste und Layout auf 1280×720, 800×480, 640×320, 412×915, 690×829")
	quit(0)
