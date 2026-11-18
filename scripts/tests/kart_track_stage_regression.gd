extends SceneTree
## Streckenwahl-Bühne (Heinz' Weg B): Kart-Hauptmenü → „Strecken“ → Strecken antippen,
## schnell wechseln, starten, zurück. Prüft, dass Bild, Name, Fortschritt, Karte und
## gestarteter Kurs zusammenpassen, höchstens eine Vorschau läuft, Verlassen anhält,
## reduzierte Bewegung ein Standbild zeigt und kein Garagenteller stehen bleibt.
##
##   godot --headless --path . --script res://scripts/tests/kart_track_stage_regression.gd
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const CARD = preload("res://scripts/games/kart_track_card.gd")
const PLAYER = preload("res://scripts/games/kart_track_preview_player.gd")
const WINTER := "winter_sprint"
const JUNGLE := "jungle_emerald_3600"
## Fold offen, schmales Hochformat, Fold quer (px) bei 2,625 px/dp.
const FORMATS := [
	[Vector2i(1812, 2176), "fold"], [Vector2i(1080, 2340), "schmal"], [Vector2i(2176, 1812), "quer"]
]
const DENSITY := 2.625
var game
var garage
var stage
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		print("[TrackStage] FAIL: ", text)


func _settle(frames := 3) -> void:
	for _index in range(frames):
		await process_frame


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _px(control: Control) -> Rect2:
	var scale := Vector2(root.size) / root.get_visible_rect().size
	var rect := control.get_global_rect()
	return Rect2(rect.position * scale, rect.size * scale)


func _touch(control: Control) -> void:
	var center := _px(control).get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = center
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _settle()


func _choose(id: String) -> void:
	var card: Control = stage.card_for(id)
	_check(card != null, "Karte %s vorhanden" % id)
	if card == null:
		return
	(garage.choices.get_parent() as ScrollContainer).ensure_control_visible(card)
	await _settle(3)
	var drawer_rect: Rect2 = garage.choices.get_parent().get_global_rect()
	_check(drawer_rect.grow(1.0).encloses(card.get_global_rect()), "%s: Karte ganz sichtbar" % id)
	await _touch(card)


func _open_tracks(via: String) -> void:
	game._show_reference_landing(true)
	await _settle(8)
	var hub = game.reference_landing
	var tile: Control = hub.find_child(via, true, false)
	_check(tile != null and tile.is_visible_in_tree(), "Hauptmenü zeigt %s" % via)
	if tile != null:
		await _touch(tile)
	await _settle(10)


func _text_fits(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var lines := label.get_line_count()
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			<= label.size.x + 1.0
		)
	return lines <= maxi(1, label.max_lines_visible) or label.max_lines_visible < 0


func _expect_selected(id: String, where: String) -> void:
	var entry: Dictionary = CATALOG.entry(CATALOG.TRACKS, id)
	_check(
		str(garage.setup.track) == id,
		"%s: Startauswahl ist %s (ist %s)" % [where, id, garage.setup.track]
	)
	_check(stage.track_id == id, "%s: Bühne zeigt %s (ist %s)" % [where, id, stage.track_id])
	_check(stage.name_label.text == str(entry.name), "%s: Name %s" % [where, entry.name])
	var path := str(stage.still.texture.resource_path) if stage.still.texture != null else ""
	_check(path.get_file().get_basename() == id, "%s: Bild gehört zu %s (%s)" % [where, id, path])
	var achieved: int = garage.track_pass.stage(id, str(garage.setup.difficulty))
	_check(
		stage.progress_label.text == "%d von 3 Zielen" % achieved,
		"%s: Fortschritt %s" % [where, stage.progress_label.text]
	)
	var selected_cards := 0
	for child in garage.choices.get_children():
		if child is CARD and child.selected:
			selected_cards += 1
			_check(
				child.track_id == id and child.badge.visible,
				"%s: nur %s ist markiert" % [where, id]
			)
	_check(selected_cards == 1, "%s: genau eine Karte gewählt (%d)" % [where, selected_cards])


func _run() -> void:
	var host = root.get_node("HostBridge")
	host._options["displayDensity"] = DENSITY
	root.size = FORMATS[0][0]
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.lightweight = true
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(6)
	garage = game.garage
	stage = garage.track_stage
	await _open_tracks("Feature_world")
	print(
		(
			"[TrackStage] Menüpfad: Kart-Hauptmenü → Kachel „Strecken“ (Feature_world) → step=%d"
			% garage.step
		)
	)
	_check(
		garage.step == 3 and stage.active and stage.is_visible_in_tree(),
		"Kachel Strecken öffnet die Bühne"
	)
	_check(
		(
			_px(stage.stage_frame).size.x * _px(stage.stage_frame).size.y
			> 0.3 * root.size.x * root.size.y
		),
		"Bühnenbild ist die größte Fläche der Seite (>30 %)"
	)
	# Kein Garagenteller, keine Werkstattkulisse in der Streckenwahl.
	_check(not garage.garage_interior.root.visible, "Werkstattkulisse ausgeblendet")
	var podium: Node3D = garage.preview.get_node_or_null("TranslucentHeroStage")
	_check(podium != null and not podium.visible, "Garagenteller ausgeblendet")
	var rings_visible := false
	for ring in garage.stage_rings:
		rings_visible = rings_visible or ring.visible
	_check(not rings_visible, "Lichtringe des Tellers ausgeblendet")
	_check(
		garage.preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"verdecktes 3D-Diorama rendert nicht"
	)
	# Jede Strecke: Bild, Name, Ziel und Startauswahl gemeinsam.
	for entry in CATALOG.TRACKS:
		await _choose(str(entry.id))
		await _settle(2)
		_expect_selected(str(entry.id), "Auswahl")
		var card: Control = stage.card_for(str(entry.id))
		_check(_text_fits(card.title_label), "%s: Kartenname nicht abgeschnitten" % entry.name)
		_check(_text_fits(stage.name_label), "%s: Bühnenname nicht abgeschnitten" % entry.name)
		_check(stage._map_points.size() >= 3, "%s: Karte aus Mittellinie" % entry.name)
		_check(stage._map_track == str(entry.id), "%s: Minikarte gehört zur Strecke" % entry.name)
	# Touch-Ziele ≥ 48 dp (126 px am Fold).
	for control in [
		stage.card_for(WINTER), stage.overview_button, garage.next_button, garage.back_button
	]:
		var rect := _px(control)
		_check(
			rect.size.x >= 125.9 and rect.size.y >= 125.9,
			"%s mindestens 126×126 px (%s)" % [control.name, rect.size]
		)
	# Schnelles Wechseln Winter-Sprint ↔ Dschungelherz, 20×.
	for index in range(20):
		var id := WINTER if index % 2 == 0 else JUNGLE
		garage._select("track", id)
		await process_frame
	await _settle(3)
	_expect_selected(JUNGLE, "nach 20× Wechsel")
	var players: int = garage.find_children("*", "VideoStreamPlayer", true, false).size()
	_check(players == 1, "genau ein Vorschau-Player nach schnellem Wechsel (%d)" % players)
	_check(
		stage.player.track_id == JUNGLE or stage.player.track_id.is_empty(),
		"Vorschau gehört zu Dschungelherz"
	)
	var has_clip: bool = PLAYER.has_clip(JUNGLE)
	await _wait(PLAYER.HOLD_BEFORE + 0.4)
	if has_clip:
		_check(
			stage.player.video.stream != null and stage.player.track_id == JUNGLE,
			"Dschungelherz-Clip geladen"
		)
		print("[TrackStage] Clip Dschungelherz läuft: ", stage.is_preview_playing())
	# Übersicht über den ganzen Rundkurs bleibt erreichbar.
	await _touch(stage.overview_button)
	_check(
		stage.overview and not stage.stage_frame.visible,
		"„Strecke ansehen“ zeigt die Rundkurs-Übersicht"
	)
	_check(
		garage.preview_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED,
		"Übersicht rendert 3D"
	)
	_check(
		is_instance_valid(garage.preview_world) and str(garage.preview_world.track_id) == JUNGLE,
		"Übersicht ist Dschungelherz"
	)
	_check(not stage.is_preview_playing(), "Vorschau pausiert in der Übersicht")
	await _touch(stage.overview_button)
	_check(not stage.overview and stage.stage_frame.visible, "zurück zum Bühnenbild")
	# Verlassen der Ansicht hält die Vorschau an.
	await _touch(garage.step_buttons[2])
	_check(garage.step == 2 and not stage.visible, "Reiter Karts verlässt die Bühne")
	_check(
		not stage.is_preview_playing() and stage.player.video.stream == null,
		"Verlassen hält die Vorschau an"
	)
	_check(
		garage.preview_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED,
		"Garage rendert wieder 3D"
	)
	var podium_back: bool = podium.visible
	_check(podium_back, "Garagenteller ist in der Garage wieder da")
	await _touch(garage.step_buttons[3])
	_expect_selected(JUNGLE, "zurück im Reiter Strecken")
	# Reduzierte Bewegung: nur das beste Einzelbild.
	garage.reduced_motion = true
	garage._select("track", WINTER)
	await _settle(3)
	await _wait(PLAYER.HOLD_BEFORE + 0.5)
	_check(
		not stage.is_preview_playing() and stage.player.video.stream == null,
		"reduzierte Bewegung: kein Clip"
	)
	_check(stage.still.texture != null and stage.still.visible, "reduzierte Bewegung: Standbild")
	garage.reduced_motion = false
	# Andere Formate: letzte Strecke und langer Name erreichbar und lesbar.
	for format in FORMATS.slice(1):
		root.size = format[0]
		await _settle(8)
		for id in ["candy_cloud", JUNGLE]:
			if CATALOG.entry(CATALOG.TRACKS, id).get("id", "") != id:
				continue
			await _choose(id)
			await _settle(2)
			_expect_selected(id, format[1])
			_check(
				_text_fits(stage.card_for(id).title_label),
				"%s: %s Kartenname lesbar" % [format[1], id]
			)
			_check(_text_fits(stage.name_label), "%s: %s Bühnenname lesbar" % [format[1], id])
			var frame: Control = stage.card_for(id).picture_frame
			_check(
				_px(frame).size.x >= 60.0 * DENSITY, "%s: %s Kartenbild sichtbar" % [format[1], id]
			)
		var picture := _px(stage.stage_frame)
		var cards := _px(garage.choices.get_parent())
		_check(not picture.intersects(cards), "%s: Bühne und Karten überlappen nicht" % format[1])
		_check(
			not picture.intersects(_px(garage.footer)), "%s: Bühne frei vom Startknopf" % format[1]
		)
		if format[1] == "quer":
			_check(
				picture.position.x < cards.position.x and picture.size.x > cards.size.x,
				"quer: Vorschau links größer, Auswahl rechts"
			)
		else:
			_check(picture.end.y <= cards.position.y, "%s: Vorschau über den Karten" % format[1])
		_check(
			_px(garage.next_button).end.y >= root.size.y * 0.85,
			"%s: Startknopf unten (Daumen)" % format[1]
		)
	root.size = FORMATS[0][0]
	await _settle(8)
	# Start: die gewählte Strecke ist der gefahrene Kurs; die Vorschau stoppt.
	await _choose(JUNGLE)
	await _settle(2)
	await _touch(garage.next_button)
	await _settle(6)
	_check(not game.menu_active and is_instance_valid(game.world), "Rennen startet")
	_check(
		str(game.track_id) == JUNGLE and str(game.world.track_id) == JUNGLE,
		"Gestartet: Dschungelherz (%s)" % game.track_id
	)
	# Das Menü wird zum Rennen freigegeben; die Vorschau darf nicht weiterlaufen.
	var stopped: bool = (
		not is_instance_valid(stage) or (not stage.is_preview_playing() and not stage.visible)
	)
	_check(stopped, "Rennstart hält die Vorschau an")
	var videos := 0
	for node in root.find_children("*", "VideoStreamPlayer", true, false):
		videos += 1 if node.is_playing() else 0
	_check(videos == 0, "im Rennen läuft keine Vorschau (%d)" % videos)
	# Zurück ins Menü: wieder die zuletzt gewählte Strecke.
	game._leave_race_for_menu()
	await _settle(6)
	await _open_tracks("Open_world")
	garage = game.garage
	stage = garage.track_stage
	_check(garage.step == 3 and stage.active, "Leiste Strecken öffnet nach dem Rennen die Bühne")
	_expect_selected(JUNGLE, "nach Rückkehr aus dem Rennen")
	game.abandoned = true
	game.queue_free()
	await _settle(4)
	var sound = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await _wait(0.4)
	print(
		(
			"[TrackStage] %s %d Prüfungen, %d Fehler"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
