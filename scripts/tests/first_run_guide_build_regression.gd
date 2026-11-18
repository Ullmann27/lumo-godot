extends SceneTree
## Erste Einführung LUMO BAUWELT: echte Touches – Bauteil wählen, auf die Wiese tippen,
## mit dem Finger umsehen, Rückgängig; Überspringen/Wiederholen, Fortsetzen, anderes Kind.

const CHILD_A := "guide-test-build-a"
const CHILD_B := "guide-test-build-b"
var kit_script
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	for slot in range(1, 7):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://lumo_build_%s_%d.json" % [child, slot])
		)
	root.get_node("HostBridge")._options = {"displayDensity": kit_script.density()}
	game = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(8)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Bauwelt hängt die Einführung ein")
	return guide


func _close() -> void:
	game.queue_free()
	await kit.frames(4)


func _next_step(guide) -> void:
	var waited := 0
	while guide.state == "praise" and waited < 600:
		waited += 1
		await process_frame
	kit.check(guide.state != "praise", "Lumos Lob endet (aktiv=%s)" % guide.root.visible)


func _tap_at(at: Vector2, index: int = 0) -> void:
	kit.touch(at, true, index)
	await kit.frames(1)
	kit.touch(at, false, index)
	await kit.frames(2)


func _tap(control: Control, index: int = 1) -> void:
	await _tap_at(control.get_global_rect().get_center(), index)


## Tippt im Zielbereich, bis ein Bauteil steht (Wasser/besetzte Felder lehnt die Welt ab).
func _place_somewhere(guide) -> bool:
	var area: Rect2 = guide.target_rect()
	var before: int = game.model.pieces.size()
	for row in range(5):
		for column in range(5):
			var at: Vector2 = (
				area.position + area.size * Vector2(0.1 + column * 0.2, 0.1 + row * 0.2)
			)
			await _tap_at(at)
			if game.model.pieces.size() > before:
				return true
	return false


func _swipe(from: Vector2, distance: float) -> void:
	kit.touch(from, true, 0)
	await kit.frames(1)
	for step in range(1, 9):
		kit.drag(from + Vector2(distance * step / 8.0, 0.0), Vector2(distance / 8.0, 0.0), 0)
		await kit.frames(1)
	kit.touch(from + Vector2(distance, 0.0), false, 0)
	await kit.frames(2)


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "BuildGuide")
	root.size = kit_script.window_size(Vector2i(1280, 720))
	DisplayServer.window_set_size(root.size)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "erstes Öffnen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "part", "Schritt 1: Bauteil wählen")
	var target: Rect2 = guide.target_rect()
	var part: Control = (
		game.part_buttons.values().filter(func(b): return b.get_global_rect() == target).front()
	)
	await kit.snap("bauwelt-schritt1")
	kit.check_target(guide, part, "Bauteil")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	kit.check(
		not guide.bubble.get_global_rect().intersects(part.get_global_rect()),
		"Sprechblase frei vom Bauteil"
	)
	await _tap(part)
	kit.check(guide.completed.has("part"), "Auswahl erfüllt Schritt 1")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "place", "Schritt 2: auf die Wiese tippen")
	kit.check(guide.target_rect().has_area(), "Zeiger auf die Welt")
	kit.check(await _place_somewhere(guide), "Tippen auf die Welt baut ein Teil")
	await kit.frames(2)
	kit.check(guide.completed.has("place"), "Bauen erfüllt Schritt 2")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "look", "Schritt 3: umsehen")
	var orbit: float = game.orbit
	await _swipe(guide.target_rect().get_center() - Vector2(120, 0), 240.0)
	kit.check(absf(game.orbit - orbit) > 0.3, "Wischen dreht die Kamera")
	kit.check(guide.completed.has("look"), "Umsehen erfüllt Schritt 3")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "undo", "Schritt 4: Rückgängig")
	var undo: Control = (
		game
		. tool_actions
		. get_children()
		. filter(func(b): return b is Button and b.text == "Rückgängig")
		. front()
	)
	kit.check_target(guide, undo, "Rückgängig")
	await _tap(undo)
	kit.check(guide.completed.has("undo"), "Rückgängig erfüllt Schritt 4")
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "build").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	await kit.snap("bauwelt-wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for control in game.upper_hud.find_children("*", "Button", true, false):
		if control.is_visible_in_tree():
			kit.check(
				not replay_rect.intersects(control.get_global_rect()),
				"Wiederholen frei von " + control.text
			)
	await _tap(guide.replay_button, 2)
	kit.check(guide.current_step_id() == "part", "Wiederholen startet bei Schritt 1")
	await _tap(guide.skip_button, 2)
	kit.check(not guide.is_running(), "Überspringen beendet")
	game._pause(true)
	await kit.frames(2)
	kit.check(not guide.root.visible, "in der Pause verborgen")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "part", "anderes Kind sieht sie")
	await _tap_at(guide.target_rect().get_center(), 1)
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "build").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "place", "Fortsetzen bei Schritt 2")
	await _tap(guide.skip_button, 2)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "build").state == "skipped", "übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	game = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(4)
	kit.check(game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	for child in [CHILD_A, CHILD_B]:
		kit_script.reset_child(child)
		for slot in range(1, 7):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://lumo_build_%s_%d.json" % [child, slot])
			)
	print("[BuildGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
