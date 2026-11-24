extends SceneTree
## The neon main menu offers every catalogue race kind. The rebuilt menu only
## started Rennen and Turnier; Zeitfahren, Freies Training and Kristall-Arena
## had lost their direct entry. All five kinds and START are visible without
## scrolling on phone landscape/portrait and both Fold displays.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const SURFACES: Array = [
	["phone_landscape", Vector2i(1600, 720), 2.0],
	["phone_portrait", Vector2i(720, 1600), 2.0],
	["fold7_inner", Vector2i(1968, 2184), 2.625],
	["fold7_cover", Vector2i(1080, 2520), 2.625],
]
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[KartRaceKinds] FAIL: " + text)


func _settle(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.lightweight = true
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(12)
	for surface in SURFACES:
		var label: String = surface[0]
		var host: Node = root.get_node_or_null("HostBridge")
		if host != null and "_options" in host:
			host._options["displayDensity"] = float(surface[2])
		root.size = surface[1]
		await _settle(6)
		game.reduced_motion = true
		game._show_reference_landing()
		await _settle(12)
		var hub = game.reference_landing
		var dock: Button = hub.find_child("Dock_race", true, false)
		_check(dock != null, label + " bottom bar has Rennen")
		dock.pressed.emit()
		await _settle(12)
		_check(hub._overlay.visible and hub._overlay_title.text == "Rennarten", label + " Rennen opens the race kinds")
		_check(game.menu_active and hub.visible, label + " opening the kinds does not start a race")
		var clip: Rect2 = hub._race_kinds.get_parent().get_parent().get_global_rect().grow(1.0)
		var screen: Rect2 = root.get_visible_rect()
		var found: Array[String] = []
		for kind in hub._race_kinds.get_children():
			found.append(str(kind.get_meta("race_kind_name")))
			_check(kind.is_visible_in_tree() and clip.encloses(kind.get_global_rect()),
				"%s '%s' visible without scrolling" % [label, kind.get_meta("race_kind_name")])
			_check(kind.text.contains(str(kind.get_meta("race_kind_name"))), label + " kind shows its name")
		var expected: Array[String] = []
		for entry in CATALOG.MODES:
			expected.append(str(entry.name))
		_check(found == expected, "%s offers %s, found %s" % [label, expected, found])
		var start: Button = hub.find_child("LiveQuickStart", true, false)
		_check(start != null and start.is_visible_in_tree() and screen.encloses(start.get_global_rect()),
			label + " START visible on screen")
		for id in ["time_trial", "training", "arena", "cup", "race"]:
			var button: Button = hub._race_kind_buttons[id]
			button.pressed.emit()
			_check(game.garage.setup.mode == id, "%s choosing %s sets the real next race" % [label, id])
			_check(hub.visible and game.menu_active, label + " choosing a kind stays in the menu")
			_check(button.text.begins_with("✓ "), "%s %s shows it is chosen" % [label, id])
		_check(hub.handle_back() and not hub._overlay.visible, label + " Back closes the race kinds")
	# START launches exactly the chosen kind.
	game._show_reference_landing()
	await _settle(12)
	var hub_final = game.reference_landing
	hub_final._route("race")
	hub_final._race_kind_buttons["time_trial"].pressed.emit()
	(hub_final.find_child("LiveQuickStart", true, false) as Button).pressed.emit()
	await _settle(12)
	_check(not game.menu_active and game.mode == "time_trial", "START launches the chosen Zeitfahren")
	game.abandoned = true
	game.queue_free()
	await _settle(4)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	if failures > 0:
		print("[KartRaceKinds] FAIL: %d of %d checks" % [failures, checks])
		quit(1)
		return
	print("[KartRaceKinds] PASS: %d checks; five race kinds and START on %d displays" % [checks, SURFACES.size()])
	quit(0)
