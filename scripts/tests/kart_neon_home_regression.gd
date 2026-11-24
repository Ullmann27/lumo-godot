extends SceneTree
## Laufzeit-Regression für das Neon-Hauptmenü (Zielbild 17.11.2026): echte Routen, ehrliche Werte.
const HUB = preload("res://scripts/games/kart_neon_hub.gd")
const ARENA = preload("res://scripts/games/kart_neon_arena.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var checks := 0
var failures: Array[String] = []
var routes: Array[String] = []
var rotations: Array[float] = []
var starts := 0
var settings := 0
var exits := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _make(stars: int):
	var hub = HUB.new()
	hub.total_stars = stars
	hub.mode_selected.connect(func(route: String): routes.append(route))
	hub.preview_rotate_requested.connect(func(angle: float): rotations.append(angle))
	hub.quick_start.connect(func(): starts += 1)
	hub.open_settings.connect(func(): settings += 1)
	hub.return_to_games.connect(func(): exits += 1)
	root.add_child(hub)
	return hub


func _window(dimensions: Vector2i, density: float) -> void:
	# The production layout converts canvas pixels through the actual window
	# and Android display density. Resizing only the child left headless at
	# 64x64 and created a fictitious 20x UI scale before the first assertion.
	root.get_node("HostBridge")._options["displayDensity"] = density
	root.size = dimensions
	await process_frame
	await process_frame
	_check(root.size == dimensions, "echte Fenstergröße: " + str(dimensions))
	_check(is_equal_approx(root.get_node("MobileRuntime").get_ui_density(), density),
		"echte Android-Dichte: " + str(density))


func _track_controls(hub, pixels_per_canvas: Vector2, density: float, tag: String) -> void:
	var hero: Control = hub._highlight_pick
	var hero_rect := hero.get_global_rect()
	var k: float = hero.ui_scale
	var has_play := hero.size.y >= 110.0 * k
	# Independent of arrow placement: _draw_thumb draws a 40dp Play square,
	# inset 8dp from the lower-right edge of each sufficiently tall picture.
	var play_rect := hero.get_global_transform() * Rect2(
		hero.size - Vector2(48, 48) * k, Vector2(40, 40) * k)
	var arrows: Array[Control] = [hub._thumb_prev, hub._thumb_next]
	for arrow in arrows:
		var rect := arrow.get_global_rect()
		var touch_dp := rect.size * pixels_per_canvas / density
		_check(arrow.is_visible_in_tree(), "Streckenpfeil sichtbar: %s %s" % [tag, arrow.name])
		_check(touch_dp.x >= 47.99 and touch_dp.y >= 47.99,
			"Streckenpfeil mindestens 48x48 dp: %s %s %s" % [tag, arrow.name, touch_dp])
		_check(hero_rect.grow(0.01).encloses(rect),
			"Streckenpfeil vollständig im großen Bild: %s %s" % [tag, arrow.name])
		if has_play:
			_check(not rect.intersects(play_rect.grow(4.0 * k)),
				"Streckenpfeil hält 4dp Abstand zum Play-Symbol: %s %s" % [tag, arrow.name])
	_check(is_equal_approx(arrows[0].position.y, arrows[1].position.y),
		"Streckenpfeile auf gleicher Höhe: " + tag)
	_check(not arrows[0].get_global_rect().intersects(arrows[1].get_global_rect()),
		"Streckenpfeile sind getrennt: " + tag)
	print("[NeonHomeControls] ", JSON.stringify({"window": root.size, "density": density,
		"hero_canvas": hero_rect, "next_canvas": arrows[1].get_global_rect(),
		"play_canvas": play_rect if has_play else Rect2(),
		"play_gap_dp": (play_rect.position.y - arrows[1].get_global_rect().end.y)
			* pixels_per_canvas.y / density if has_play else -1.0}))


func _track_layouts() -> void:
	for config in [
		{"size": Vector2i(412, 915), "density": 1.0},
		{"size": Vector2i(720, 1280), "density": 2.0},
		{"size": Vector2i(1384, 1400), "density": 1.0},
		{"size": Vector2i(1384, 1400), "density": 2.0},
		{"size": Vector2i(1280, 720), "density": 2.0},
	]:
		await _window(config.size, config.density)
		var hub = _make(17)
		await process_frame
		await process_frame
		var viewport := root.get_visible_rect()
		var pixels_per_canvas := Vector2(root.size) / viewport.size
		var tag := "%s @ %s dp" % [root.size, config.density]
		_check(hub.size.is_equal_approx(viewport.size), "Menü füllt den tatsächlichen Viewport: " + tag)
		_track_controls(hub, pixels_per_canvas, float(config.density), tag)
		var seen := {}
		for step in range(CATALOG.TRACKS.size()):
			seen[hub._featured_track] = true
			var shown: Array[Control] = []
			for id in hub._track_buttons:
				var thumb: Control = hub._track_buttons[id]
				if thumb.is_visible_in_tree():
					shown.append(thumb)
					_check(id != hub._featured_track, "Vorschau ergänzt die gewählte Strecke: " + tag)
			_check(shown.size() >= 3, "mindestens drei weitere Streckenbilder: " + tag)
			for index in range(shown.size()):
				var rect := shown[index].get_global_rect()
				var touch_dp := rect.size * pixels_per_canvas / float(config.density)
				_check(touch_dp.x >= 47.99 and touch_dp.y >= 47.99,
					"Streckenvorschau mindestens 48x48 dp: %s %s" % [tag, touch_dp])
				_check(hub._highlight.get_global_rect().encloses(rect),
					"vollständiges Streckenbild im Highlight: " + tag)
				for other in range(index + 1, shown.size()):
					_check(not rect.intersects(shown[other].get_global_rect()),
						"getrennte Streckenbilder: %s %s/%s" % [tag, shown[index].name, shown[other].name])
			hub._thumb_next.pressed.emit()
			await process_frame
			await process_frame
		_check(seen.size() == CATALOG.TRACKS.size(), "alle Katalogstrecken erreichbar: " + tag)
		print("[NeonHomeLayout] window=", root.size, " density=", config.density,
			" viewport=", viewport.size, " canvas_per_dp=", hub._layout_scale, " tracks=", seen.size())
		hub.free()


func _run() -> void:
	await _window(Vector2i(1280, 720), 1.0)
	var hub = _make(17)
	await process_frame
	await process_frame
	_check(hub._highlight != null and hub._highlight.is_visible_in_tree(), "Strecken-Highlight sichtbar")
	# Alle Strecken des Katalogs stehen im Hauptmenü zur Wahl (nicht nur vier).
	var catalog = preload("res://scripts/games/kart_catalog.gd")
	_check(hub._track_buttons.size() == catalog.TRACKS.size() and catalog.TRACKS.size() >= 13,
		"alle %d Katalogstrecken im Highlight (%d Bilder)" % [catalog.TRACKS.size(), hub._track_buttons.size()])
	for entry in catalog.TRACKS:
		var id := str(entry.id)
		_check(hub._track_buttons.has(id), "Strecke im Katalog: " + id)
		_check(hub._track_buttons.has(id) and hub._track_buttons[id].art != null, "echtes Vorschaubild: " + id)
	# Die Pfeile auf dem großen Bild gehen durch jede Strecke; nichts liegt übereinander.
	_check(hub._thumb_prev.is_visible_in_tree() and hub._thumb_next.is_visible_in_tree(), "Pfeile zum Blättern sichtbar")
	_check(hub._thumb_next.get_global_rect().size.x >= 36.0, "Pfeil ist groß genug zum Antippen (%.0f px)" % hub._thumb_next.get_global_rect().size.x)
	var seen := {}
	for _step in range(catalog.TRACKS.size()):
		seen[hub._featured_track] = true
		var shown: Array = []
		for id in hub._track_buttons:
			if hub._track_buttons[id].is_visible_in_tree():
				shown.append(id)
		_check(shown.size() >= 3 and not shown.has(hub._featured_track), "drei weitere Streckenbilder neben der gewählten (%d)" % shown.size())
		for a in range(shown.size()):
			for b in range(a + 1, shown.size()):
				_check(not hub._track_buttons[shown[a]].get_global_rect().intersects(hub._track_buttons[shown[b]].get_global_rect()),
					"Streckenbilder %s und %s überlappen nicht" % [shown[a], shown[b]])
		hub._thumb_next.pressed.emit()
		await process_frame
		await process_frame
	_check(seen.size() == catalog.TRACKS.size(), "die Pfeile erreichen jede Strecke (%d von %d)" % [seen.size(), catalog.TRACKS.size()])
	_check(routes.size() == catalog.TRACKS.size(), "jeder Pfeil-Tipp übergibt die Strecke an das Rennen (%d)" % routes.size())
	hub._thumb_prev.pressed.emit()
	await process_frame
	hub._thumb_next.pressed.emit()
	await process_frame
	routes.clear()
	# Issue #204: hervorgehoben ist die Strecke, die "Rennen" startet – ohne Vorgabe die
	# erste Katalogstrecke, nie eine bloße Werbestrecke.
	_check(hub._featured_track == "sonnenhafen" and hub.selected_track == "sonnenhafen",
		"Highlight zeigt beim Start die Strecke des nächsten Rennens")
	hub._track_buttons["jungle_emerald_3600"].pressed.emit()
	_check(hub._featured_track == "jungle_emerald_3600", "Tippen auf Vorschau wechselt das Highlight")
	_check(routes == ["jungle_emerald_3600"], "Tippen auf Vorschau übergibt die Strecke an das Rennen")
	routes.clear()
	hub._highlight_pick.pressed.emit()
	_check(routes == ["jungle_emerald_3600", "world"], "Highlight öffnet echte Streckenwahl mit Dschungel")
	routes.clear()
	hub._rotation_left.pressed.emit()
	hub._rotation_right.pressed.emit()
	_check(rotations.size() == 2 and is_equal_approx(rotations[0] + rotations[1], 0), "Drehteller links/rechts")
	_check(hub._mode_tiles.size() == 4, "vier spielbare Modus-Kacheln: Rennen, Turnier, Abenteuer, Wochenrennen")
	hub._mode_tiles["race"].pressed.emit()
	_check(routes == ["race"] and starts == 1 and hub.current_mode == "race", "Rennen startet sofort ein echtes Rennen")
	routes.clear()
	hub._mode_tiles["cup"].pressed.emit()
	_check(routes == ["cup"] and starts == 1 and hub._overlay.visible and hub._overlay_title.text == "Sternen-Cup",
		"Turniere zeigt zuerst den Sternen-Cup (noch kein Start)")
	var cup_tracks: GridContainer = hub._overlay_list.get_node_or_null("CupTracks")
	_check(cup_tracks != null and cup_tracks.get_child_count() == CATALOG.TRACKS.size(),
		"Sternen-Cup zeigt alle %d Strecken" % CATALOG.TRACKS.size())
	if cup_tracks != null:
		for index in range(cup_tracks.get_child_count()):
			var card = cup_tracks.get_child(index)
			_check(card.art != null and card.title.begins_with("%d · " % (index + 1)),
				"Cup-Strecke %d hat Bild und Reihenfolge" % (index + 1))
	_check(hub._live_start.visible, "Sternen-Cup hat einen Startknopf")
	hub._live_start.pressed.emit()
	_check(starts == 2 and hub.current_mode == "cup", "Startknopf beginnt den echten Sternen-Cup")
	hub._close_overlay()
	routes.clear()
	hub._mode_tiles["event"].pressed.emit()
	_check(routes.size() == 2 and routes[0] == hub._weekly_track and routes[1] == "race" and starts == 3,
		"Event = Wochen-Abenteuer auf echter Strecke")
	routes.clear()
	hub._mode_tiles["parcours"].pressed.emit()
	_check(routes == ["parcours"], "Abenteuer öffnet die echte Parcours-Weltwahl")
	routes.clear()
	hub._progress.pressed.emit()
	_check(hub._overlay.visible and hub._overlay_title.text == "Sternenpfad", "Saison öffnet den Sternenpfad")
	var route: VBoxContainer = hub._overlay_list.get_node_or_null("StarPathRoute")
	_check(route != null and route.get_child_count() == PATH.milestones().size(),
		"Sternenpfad als Weg mit einer Station je echter Freischaltung")
	_check(hub.handle_back() and not hub._overlay.visible, "Zurück schließt den Sternenpfad")
	hub._feature_tiles["garage"].pressed.emit()
	hub._feature_tiles["world"].pressed.emit()
	_check(routes == ["garage", "world"], "Garage und Strecken führen in echte Garage-Schritte")
	routes.clear()
	hub._feature_tiles["rewards"].pressed.emit()
	_check(hub._overlay.visible and hub._overlay_title.text == "Belohnungen", "Belohnungen zeigt echte Freischaltungen")
	var rewards: GridContainer = hub._overlay_list.get_node_or_null("RewardCards")
	_check(rewards != null and rewards.get_child_count() == PATH.milestones().size(), "Belohnungen als Karten")
	if rewards != null:
		var pictures := {}
		for card in rewards.get_children():
			_check(card.art != null, "Belohnung %s hat ein Bild" % card.title)
			if card.art != null:
				pictures[card.art.resource_path] = true
		_check(pictures.size() == rewards.get_child_count(), "jede Belohnung hat ihr eigenes Bild")
	hub._close_overlay()
	_check(hub._navigation.get_child_count() == 9, "neun Einträge in der unteren Leiste")
	hub._navigation.get_node("Landing_settings").pressed.emit()
	_check(settings == 1, "Einstellungen öffnet echte Kart-Optionen")
	hub._navigation.get_node("Open_garage").pressed.emit()
	_check(routes == ["garage"], "Leiste: Garage")
	hub._back.pressed.emit()
	_check(exits == 1, "Zurück zur Spielewelt")
	_check(hub._progress_label.text.contains("17"), "Sternenpfad nutzt echte Sterne")
	_check(hub._player.stars == 17 and PATH.level(17) == 2, "Stufe aus echten Sternen (10 je Stufe)")
	hub.free()
	await _track_layouts()
	# Ehrlicher Neustart: 0 Sterne -> Stufe 1, kein vorgetäuschter Fortschritt.
	await _window(Vector2i(412, 915), 1.0)
	var fresh = _make(0)
	await process_frame
	await process_frame
	_check(PATH.level(0) == 1 and PATH.level_progress(0).x == 0, "Neustart bei Stufe 1 mit 0 Sternen")
	_check(PATH.path_progress(0).x == 0, "Sternenpfad startet ehrlich bei 0")
	_check(not fresh._feature_tiles["rewards"].badge, "kein Belohnungs-Hinweis ohne echte Freischaltung")
	var texts := ""
	for node in fresh.find_children("*", "", true, false):
		if "title" in node:
			texts += str(node.title) + " "
		if "caption" in node:
			texts += str(node.caption) + " "
		if node is Label:
			texts += node.text + " "
	for forbidden in ["XP", "Premium", "Saisonpass", "kaufen!", "7.320", "128"]:
		_check(not texts.contains(forbidden), "keine erfundenen Werte/Kaufhinweise: " + forbidden)
	fresh.free()
	var arena = ARENA.new()
	root.add_child(arena)
	arena.build()
	arena.set_active(true, false)
	arena.advance(1.0 / 60.0)
	_check(arena.elapsed > 0 and arena.get_node_or_null("KartTurntable") != null, "echter 3D-Showroom")
	_check(arena.find_children("*", "CollisionObject3D", true, false).is_empty(), "Showroom ändert keine Fahrphysik")
	arena.free()
	_check(await TEARDOWN.release_audio(self, root, "[NeonHome]"), "UI-Klick und Mixer vor Prozessende freigegeben")
	print("[NeonHome] ", JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
