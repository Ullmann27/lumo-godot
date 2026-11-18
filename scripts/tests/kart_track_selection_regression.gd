extends SceneTree
## Issue #204: the course chosen in the live Kart menu is the course that loads.
##
## Every case mounts the menu the way an Android launch does (neon landing in
## front of the spatial menu) and presses the real controls: a screen touch when
## the control is fully on screen, its pressed signal otherwise (counted apart).
## The loaded course is read from the race itself (owner and built world), never
## from the menu selection.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const CHOICE = preload("res://scripts/games/kart_menu_choice.gd")
const KINDS_WITH_COURSE: Array[String] = ["race", "time_trial", "training"]

var game
var checks := 0
var failures: Array[String] = []
var touch_presses := 0
var signal_presses := 0
var loaded: Array[String] = []
var selected: Array[String] = []
## Optional picture proof (needs a real renderer): --capture=<directory>.
var capture_dir := ""
var shots := 0


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame


func _shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join("%02d_%s.png" % [shots, name])
	if root.get_texture().get_image().save_png(path) == OK:
		shots += 1


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
		print("[KartTrackSelection] FAIL: ", text)


func _press(control: Control, what: String) -> void:
	if not is_instance_valid(control):
		_check(false, "Control fehlt: " + what)
		return
	# A card further down a list is reached the way a child reaches it: by scrolling.
	var clip := root.get_visible_rect()
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			if not parent.get_global_rect().encloses(control.get_global_rect()):
				parent.ensure_control_visible(control)
				await _settle()
			clip = clip.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	var rect: Rect2 = control.get_global_rect()
	if control.is_visible_in_tree() and rect.has_area() and clip.encloses(rect):
		var point: Vector2 = rect.get_center() * Vector2(root.size) / root.get_visible_rect().size
		for pressed in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 3
			touch.position = point
			touch.pressed = pressed
			Input.parse_input_event(touch)
			Input.flush_buffered_events()
			await process_frame
		touch_presses += 1
	else:
		control.emit_signal("pressed")
		signal_presses += 1
	await _settle()


func _fresh() -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	# Pictures show the real course scenery; the plain run keeps the light build.
	game.lightweight = capture_dir.is_empty()
	await _settle()
	# Script runs skip the landing; a real launch always shows it first.
	game._show_reference_landing(false)
	await _settle()
	await _settle()


func _drop() -> void:
	if is_instance_valid(game):
		game.abandoned = true
		game.queue_free()
	await _settle()


func _hub():
	return game.reference_landing


func _course_name(id: String) -> String:
	return str(CATALOG.entry(CATALOG.TRACKS, id).get("name", id))


func _choice(title: String) -> Control:
	for child in game.garage.choices.find_children("*", "Button", true, false):
		if child is CHOICE and child.title == title:
			return child
	return null


## The race must be running the expected course – owner, world and log agree.
func _expect_race(expected: String, expected_mode: String, path: String) -> void:
	selected.append(expected)
	var started: bool = not game.menu_active and is_instance_valid(game.world)
	_check(started, "%s: Rennen wurde nicht gestartet (%s)" % [path, expected])
	if not started:
		loaded.append("-")
		return
	loaded.append(str(game.world.track_id))
	_check(
		str(game.track_id) == expected,
		"%s: gewählt %s, Rennen meldet %s" % [path, expected, game.track_id]
	)
	_check(
		str(game.world.track_id) == expected,
		"%s: gewählt %s, gebaute Welt ist %s" % [path, expected, game.world.track_id]
	)
	_check(
		str(game.mode) == expected_mode,
		"%s: Rennart %s erwartet, gestartet %s" % [path, expected_mode, game.mode]
	)
	print(
		"[KartTrackSelection] %s gewählt=%s geladen=%s modus=%s"
		% [path, expected, game.world.track_id, game.mode]
	)


## A: thumbnail in the Strecken-Highlight, then the big "Rennen" tile.
func _case_thumb_then_race(id: String) -> void:
	await _fresh()
	await _press(_hub()._track_buttons.get(id), "Streckenbild " + id)
	await _shot("A_%s_menue_gewaehlt" % id)
	await _press(_hub()._mode_tiles["race"], "Kachel Rennen")
	_expect_race(id, "race", "A Streckenbild → Rennen")
	await _shot("A_%s_rennen" % id)
	await _drop()


## B: nothing tapped – "Rennen" starts the course the highlight shows as active.
func _case_shown_highlight_is_started() -> void:
	await _fresh()
	var shown: String = str(_hub()._featured_track)
	var active_thumbs: Array[String] = []
	for id in _hub()._track_buttons:
		if bool(_hub()._track_buttons[id].active):
			active_thumbs.append(str(id))
	_check(
		active_thumbs.size() <= 1,
		"B: höchstens ein Streckenbild darf aktiv sein, aktiv: %s" % str(active_thumbs)
	)
	await _press(_hub()._mode_tiles["race"], "Kachel Rennen")
	_expect_race(shown, "race", "B angezeigtes Highlight → Rennen")
	await _drop()


## C: thumbnail, big highlight tile (opens "Rennwelten"), START.
func _case_pick_then_start(id: String) -> void:
	await _fresh()
	await _press(_hub()._track_buttons.get(id), "Streckenbild " + id)
	await _press(_hub()._highlight_pick, "Highlight-Kachel")
	_check(
		game.menu_active and int(game.garage.step) == 3,
		"C: Highlight-Kachel öffnet die Rennwelten (Abschnitt %d)" % int(game.garage.step)
	)
	_check(
		_choice(_course_name(id)) != null,
		"C: die Rennwelten zeigen die Streckenliste mit %s" % _course_name(id)
	)
	await _shot("C_%s_rennwelten" % id)
	await _press(game.garage.next_button, "START")
	_expect_race(id, "race", "C Highlight-Kachel → START")
	await _shot("C_%s_rennen" % id)
	await _drop()


## D: dock "Strecken", course card in the list, START – for every course.
func _case_world_list(id: String) -> void:
	await _fresh()
	await _press(_hub()._navigation.get_node_or_null("Open_world"), "Leiste Strecken")
	_check(
		game.menu_active and int(game.garage.step) == 3,
		"D: Leiste Strecken öffnet die Rennwelten (Abschnitt %d)" % int(game.garage.step)
	)
	var card: Control = _choice(_course_name(id))
	_check(card != null, "D: Streckenkarte %s ist in der Liste" % _course_name(id))
	if card != null:
		await _press(card, "Streckenkarte " + id)
		await _settle()
		await _shot("D_%s_karte_gewaehlt" % id)
		await _press(game.garage.next_button, "START")
	_expect_race(id, "race", "D Leiste Strecken → Karte → START")
	await _shot("D_%s_rennen" % id)
	await _drop()


## E: thumbnail, overlay "Rennarten" with a kind that drives one course, START.
func _case_kind(id: String, kind: String) -> void:
	await _fresh()
	await _press(_hub()._track_buttons.get(id), "Streckenbild " + id)
	await _press(_hub()._navigation.get_node_or_null("Dock_race"), "Leiste Rennen")
	await _press(_hub()._race_kind_buttons.get(kind), "Rennart " + kind)
	await _press(_hub()._live_start, "START im Overlay")
	_expect_race(id, kind, "E Streckenbild → Rennart %s → START" % kind)
	await _drop()


## F: leave a running race for the menu and start again: same course, shown and driven.
func _case_back_and_again(id: String) -> void:
	await _fresh()
	await _press(_hub()._track_buttons.get(id), "Streckenbild " + id)
	await _press(_hub()._mode_tiles["race"], "Kachel Rennen")
	_expect_race(id, "race", "F erster Start")
	game._leave_race_for_menu()
	await _settle()
	game._show_reference_landing(true)
	await _settle()
	await _settle()
	_check(
		str(_hub()._featured_track) == id,
		"F: nach der Rückkehr zeigt das Highlight %s, nicht %s" % [id, _hub()._featured_track]
	)
	await _press(_hub()._mode_tiles["race"], "Kachel Rennen")
	_expect_race(id, "race", "F zweiter Start nach Menü")
	await _drop()


## G: the cup drives every course in order; picking a course afterwards is a single race again.
func _case_cup_then_course(id: String) -> void:
	await _fresh()
	await _press(_hub()._mode_tiles["cup"], "Kachel Turniere")
	_expect_race(str(CATALOG.TRACKS[0].id), "cup", "G Turnier beginnt mit Strecke 1")
	game._leave_race_for_menu()
	await _settle()
	game._show_reference_landing(true)
	await _settle()
	await _settle()
	await _press(_hub()._track_buttons.get(id), "Streckenbild " + id)
	await _press(_hub()._highlight_pick, "Highlight-Kachel")
	await _press(game.garage.next_button, "START")
	_expect_race(id, "race", "G nach Turnier: Strecke gewählt → START")
	await _drop()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--case="):
			only = str(argument).trim_prefix("--case=")
		if str(argument).begins_with("--capture="):
			capture_dir = str(argument).trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	var thumbs: Array[String] = ["volcano_night", "jungle_emerald_3600", "desert_drift", "sonnenhafen"]
	if only in ["", "A"]:
		for id in thumbs:
			await _case_thumb_then_race(id)
	if only in ["", "B"]:
		await _case_shown_highlight_is_started()
	if only in ["", "C"]:
		for id in ["volcano_night", "jungle_emerald_3600", "sonnenhafen"]:
			await _case_pick_then_start(id)
	if only in ["", "D"]:
		for entry in CATALOG.TRACKS:
			await _case_world_list(str(entry.id))
	if only in ["", "E"]:
		for kind in ["time_trial", "training"]:
			for id in ["volcano_night", "jungle_emerald_3600"]:
				await _case_kind(id, kind)
	if only in ["", "F"]:
		await _case_back_and_again("volcano_night")
	if only in ["", "G"]:
		await _case_cup_then_course("jungle_emerald_3600")
	var distinct := {}
	for id in loaded:
		distinct[id] = true
	print(
		"[KartTrackSelection] %d Prüfungen, %d Fehler, %d Starts, %d verschiedene geladene Strecken, %d Touch, %d Signal"
		% [checks, failures.size(), loaded.size(), distinct.size(), touch_presses, signal_presses]
	)
	if failures.is_empty():
		print(
			"[KartTrackSelection] PASS: %d checks; the selected course loads on %d starts across %d courses"
			% [checks, loaded.size(), distinct.size()]
		)
	else:
		for text in failures:
			print("[KartTrackSelection]   - ", text)
		print("[KartTrackSelection] FAILED: %d of %d checks" % [failures.size(), checks])
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)
