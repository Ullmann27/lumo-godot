extends SceneTree
## Erste Einführung LUMO PUZZLE-ATELIER: echte Touches – Teil auf seinen Platz ziehen,
## „Ein Tipp“, das gehobene Teil hinlegen; Überspringen/Wiederholen, Fortsetzen,
## zweites Öffnen, anderes Kind.

const CHILD_A := "guide-test-puzzle-a"
const CHILD_B := "guide-test-puzzle-b"
var kit_script
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lumo_puzzle_%s.json" % child))
	root.get_node("HostBridge")._options = {"displayDensity": kit_script.density()}
	game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(6)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Puzzle hängt die Einführung ein")
	kit.check(not guide.root.visible, "im Auswahlmenü verborgen")
	var start: Button = null
	for button in game.menu.find_children("*", "Button", true, false):
		if button.text == "Neues Puzzle beginnen":
			start = button
	await _tap(start, 1)
	kit.check(not game.paused, "Touch auf „Neues Puzzle beginnen“ startet")
	await kit.frames(4)
	return guide


func _close() -> void:
	game.queue_free()
	await kit.frames(4)


func _next_step(guide) -> void:
	while guide.state == "praise":
		await process_frame


func _tap(control: Control, index: int) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	kit.touch(at, true, index)
	await kit.frames(1)
	kit.touch(at, false, index)
	await kit.frames(2)


## Zieht das Teil unter dem Zeiger auf seinen Zielplatz (echter Finger).
func _drag_piece(guide) -> bool:
	var before: int = game.model.placed()
	var from: Vector2 = guide.target_rect().get_center()
	kit.touch(from, true, 0)
	await kit.frames(2)
	if game.dragging < 0:
		return false
	var id: int = game.dragging
	var slot: Vector2 = game.model.target(id)
	var goal: Vector2 = game.camera.unproject_position(Vector3(slot.x, 0.8, slot.y))
	var target: Vector2 = (
		goal - (game.camera.unproject_position(game.nodes[id].global_position) - from)
	)
	for step in range(1, 13):
		kit.drag(from.lerp(target, step / 12.0), (target - from) / 12.0, 0)
		await kit.frames(1)
	if guide.current_step_id() in ["drag", "hint_piece"]:
		kit.check(guide.target_rect().has_area(), "beim Ziehen zeigt Lumo den Zielplatz")
	kit.touch(target, false, 0)
	await kit.frames(3)
	return game.model.placed() > before


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "PuzzleGuide")
	root.size = kit_script.window_size(Vector2i(1280, 720))
	DisplayServer.window_set_size(root.size)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "Puzzle offen: Lumos Sprechblase")
	kit.check(guide.current_step_id() == "drag", "Schritt 1: Teil ziehen")
	kit.check(guide.target_rect().has_area(), "Zeiger auf ein freies Teil")
	await kit.snap("puzzle-schritt1")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	kit.check(await _drag_piece(guide), "Ziehen legt ein Teil an seinen Platz")
	kit.check(guide.completed.has("drag"), "Teil am Platz erfüllt Schritt 1")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "hint", "Schritt 2: Ein Tipp")
	var hint: Control = null
	for button in game.tool_scroll.find_children("*", "Button", true, false):
		if button.text == "Ein Tipp":
			hint = button
	kit.check_target(guide, hint, "Ein Tipp")
	await _tap(hint, 1)
	kit.check(guide.completed.has("hint"), "Tipp erfüllt Schritt 2")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "hint_piece", "Schritt 3: gehobenes Teil hinlegen")
	kit.check(int(game.selected_piece) >= 0, "Tipp hebt ein Teil an")
	kit.check(await _drag_piece(guide), "das gehobene Teil rastet ein")
	kit.check(guide.completed.has("hint_piece"), "Hinlegen erfüllt Schritt 3")
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "puzzle").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	await kit.snap("puzzle-wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for button in game.safe_ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button != guide.replay_button:
			kit.check(
				not replay_rect.intersects(button.get_global_rect()),
				"Wiederholen frei von " + button.text
			)
	await _tap(guide.replay_button, 2)
	kit.check(guide.current_step_id() == "drag", "Wiederholen startet bei Schritt 1")
	await _tap(guide.skip_button, 2)
	kit.check(not guide.is_running(), "Überspringen beendet")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "drag", "anderes Kind sieht sie")
	kit.check(await _drag_piece(guide), "Kind B legt ein Teil")
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "puzzle").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "hint", "Fortsetzen bei Schritt 2")
	await _tap(guide.skip_button, 2)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "puzzle").state == "skipped", "übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	game = load("res://scenes/creative/puzzle_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(4)
	kit.check(game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	for child in [CHILD_A, CHILD_B]:
		kit_script.reset_child(child)
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://lumo_puzzle_%s.json" % child)
		)
	print("[PuzzleGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
