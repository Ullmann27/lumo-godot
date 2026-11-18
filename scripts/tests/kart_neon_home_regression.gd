extends SceneTree
## Laufzeit-Regression für das Neon-Hauptmenü (Zielbild 17.11.2026): echte Routen, ehrliche Werte.
const HUB = preload("res://scripts/games/kart_neon_hub.gd")
const ARENA = preload("res://scripts/games/kart_neon_arena.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
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

func _run() -> void:
	var hub = _make(17)
	await process_frame
	hub.size = Vector2(1280, 720)
	await process_frame
	_check(hub._highlight != null and hub._highlight.is_visible_in_tree(), "Strecken-Highlight sichtbar")
	_check(hub._track_buttons.size() == 4, "vier echte Katalogstrecken im Highlight")
	for id in ["volcano_night", "jungle_emerald_3600", "desert_drift", "sonnenhafen"]:
		_check(hub._track_buttons.has(id), "Strecke im Katalog: " + id)
		_check(hub._track_buttons[id].art != null, "echtes Vorschaubild: " + id)
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
	_check(hub._mode_tiles.size() == 4, "vier große Modus-Kacheln: Rennen, Turniere, Saison, Event")
	hub._mode_tiles["race"].pressed.emit()
	_check(routes == ["race"] and starts == 1 and hub.current_mode == "race", "Rennen startet sofort ein echtes Rennen")
	routes.clear()
	hub._mode_tiles["cup"].pressed.emit()
	_check(routes == ["cup"] and starts == 2, "Turniere startet den echten Sternen-Cup")
	routes.clear()
	hub._mode_tiles["event"].pressed.emit()
	_check(routes.size() == 2 and routes[0] == hub._weekly_track and routes[1] == "race" and starts == 3,
		"Event = Wochen-Abenteuer auf echter Strecke")
	routes.clear()
	hub._mode_tiles["season"].pressed.emit()
	_check(hub._overlay.visible and hub._overlay_title.text == "Sternenpfad", "Saison öffnet den Sternenpfad")
	_check(hub.handle_back() and not hub._overlay.visible, "Zurück schließt den Sternenpfad")
	hub._feature_tiles["garage"].pressed.emit()
	hub._feature_tiles["world"].pressed.emit()
	_check(routes == ["garage", "world"], "Garage und Strecken führen in echte Garage-Schritte")
	routes.clear()
	hub._feature_tiles["rewards"].pressed.emit()
	_check(hub._overlay.visible and hub._overlay_title.text == "Belohnungen", "Belohnungen zeigt echte Freischaltungen")
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
	# Ehrlicher Neustart: 0 Sterne -> Stufe 1, kein vorgetäuschter Fortschritt.
	var fresh = _make(0)
	await process_frame
	fresh.size = Vector2(412, 915)
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
	print("[NeonHome] ", JSON.stringify({"checks": checks, "failures": failures, "status": "PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
