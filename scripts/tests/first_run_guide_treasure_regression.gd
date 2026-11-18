extends SceneTree
## Erste Einführung LUMO SCHATZSUCHE: echter Stick, Hinweis (im Querformat), ANSEHEN am
## Stern und richtige Antwort per Touch; Überspringen/Wiederholen, Fortsetzen, anderes Kind.

const CHILD_A := "guide-test-treasure-a"
const CHILD_B := "guide-test-treasure-b"
var kit_script
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _tap(control: Control, index: int = 2) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	kit.touch(at, true, index)
	await kit.frames(1)
	kit.touch(at, false, index)
	await kit.frames(2)


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://lumo_treasure_%s.json" % child)
	)
	root.get_node("HostBridge")._options = {"displayDensity": kit_script.density()}
	game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(8)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Schatzsuche hängt die Einführung ein")
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


func _walk(direction: Vector2, seconds: float) -> void:
	var centre: Vector2 = game.joystick.get_global_rect().get_center()
	kit.touch(centre, true, 0)
	await kit.frames(1)
	kit.drag(centre + direction * game.joystick.size.x * 0.4, direction * 40.0, 0)
	await create_timer(seconds).timeout
	kit.touch(centre, false, 0)
	await kit.frames(2)


## Stellt Lumo an den nächsten Stern, tippt ANSEHEN und die richtige Antwort.
func _solve_current() -> bool:
	var clue: Dictionary = game.model.current()
	game.player.position = Vector3(clue.at.x, game.player.position.y, clue.at.z)
	await kit.frames(4)
	if game.action.disabled:
		return false
	await _tap(game.action)
	if not game.modal.visible:
		return false
	var wanted: String = str(clue.answers[int(clue.correct)])
	for button in game.modal_box.find_children("*", "Button", true, false):
		if button.text == wanted:
			await _tap(button)
			break
	await kit.frames(3)
	if game.modal.visible:
		for button in game.modal_box.find_children("*", "Button", true, false):
			if button.text.begins_with("Weiter") or button.text.begins_with("Insel"):
				await _tap(button)
				break
	await kit.frames(3)
	return str(clue.id) in game.model.found


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "TreasureGuide")
	# Kurzes Querformat: dort gibt es den Hinweis-Knopf (Hochformat zeigt den Text offen).
	root.size = kit_script.window_size(Vector2i(1280, 460))
	DisplayServer.window_set_size(root.size)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "erstes Öffnen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "walk", "Schritt 1: laufen")
	kit.check_target(guide, game.joystick, "Stick")
	await kit.snap("schatzsuche-schritt1")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	var start: Vector3 = game.player.position
	await _walk(Vector2(0.3, -1.0).normalized(), 1.0)
	kit.check(game.player.position.distance_to(start) > 0.5, "Stick bewegt Lumo")
	kit.check(guide.completed.has("walk"), "Laufen erfüllt Schritt 1")
	await _next_step(guide)
	if game.clue_button.is_visible_in_tree():
		kit.check(guide.current_step_id() == "clue", "Schritt 2: Hinweis")
		kit.check_target(guide, game.clue_button, "Hinweis")
		await _tap(game.clue_button)
		kit.check(game.modal.visible, "Hinweis-Fenster offen")
		kit.check(not guide.root.visible, "im Fenster verborgen")
		kit.check(guide.completed.has("clue"), "Hinweis erfüllt Schritt 2")
		for button in game.modal_box.find_children("*", "Button", true, false):
			if button.text == "Weiter erkunden":
				await _tap(button)
		await _next_step(guide)
	kit.check(guide.current_step_id() == "solve", "Schritt 3: ANSEHEN und Rätsel")
	kit.check_target(guide, game.action, "ANSEHEN")
	kit.check(await _solve_current(), "ANSEHEN und richtige Antwort finden den Schatz")
	kit.check(guide.completed.has("solve"), "Rätsel erfüllt Schritt 3")
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "treasure").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	await kit.snap("schatzsuche-wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for control in [game.joystick, game.action, game.jump_button, game.clue_button]:
		if control.is_visible_in_tree():
			kit.check(
				not replay_rect.intersects(control.get_global_rect()),
				"Wiederholen frei von " + control.name
			)
	for button in game.top.find_children("*", "Button", true, false):
		kit.check(
			not replay_rect.intersects(button.get_global_rect()),
			"Wiederholen frei von " + button.text
		)
	await _tap(guide.replay_button)
	kit.check(guide.current_step_id() == "walk", "Wiederholen startet bei Schritt 1")
	await _tap(guide.skip_button)
	kit.check(not guide.is_running(), "Überspringen beendet")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "walk", "anderes Kind sieht sie")
	await _walk(Vector2.LEFT, 1.0)
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "treasure").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() in ["clue", "solve"], "Fortsetzen nach Schritt 1")
	await _tap(guide.skip_button)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "treasure").state == "skipped", "übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	game = load("res://scenes/creative/treasure_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(4)
	kit.check(game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	for child in [CHILD_A, CHILD_B]:
		kit_script.reset_child(child)
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://lumo_treasure_%s.json" % child)
		)
	print("[TreasureGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
