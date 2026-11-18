extends SceneTree
## Erste Einführung LUMO LAUF: erscheint erst beim Laufen, jeder Schritt wird durch die
## echte Touch-Eingabe (Stick, SPRINGEN, FLITZEN) bzw. echte Sterne erfüllt;
## Überspringen/Wiederholen, Fortsetzen, zweites Öffnen, anderes Kind.

const STEP: float = 1.0 / 60.0
const CHILD_A := "guide-test-run-a"
const CHILD_B := "guide-test-run-b"
var kit_script
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	game = load("res://scenes/games/lumo_run.tscn").instantiate()
	root.add_child(game)
	await kit.frames(2)
	game.set_process(false)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Lauf hängt die Einführung ein")
	await kit.frames(2)
	kit.check(not guide.root.visible, "im Streckenmenü ist die Einführung verborgen")
	game.start_course(0, false)
	await kit.frames(2)
	kit.check(not guide.root.visible, "während des Countdowns verborgen")
	game.countdown_left = 0.0
	game.advance(STEP)
	await kit.frames(3)
	return guide


func _close() -> void:
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await kit.frames(4)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _tap(control: Control, index: int = 1) -> void:
	var at: Vector2 = kit.press(control, index)
	await kit.frames(2)
	kit.release(at, index)
	await kit.frames(2)


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "RunGuide")
	root.size = Vector2i(720, 1280)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.root.visible and guide.bubble.visible, "erster Lauf zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "steer", "Schritt 1 ist Lenken")
	kit.check_target(guide, game.hud.stick, "Lenken")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	var stick: Vector2 = kit.press(game.hud.stick, 0)
	kit.drag(stick + Vector2(game.hud.stick.size.x * 0.4, 0.0), Vector2(50, 0), 0)
	await _wait(0.5)
	kit.check(game.touch_steer.x > 0.35, "Stick lenkt Lumo (Touch geht durch die Einführung)")
	kit.release(stick, 0)
	kit.check(guide.state == "praise", "Lenken erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.current_step_id() == "jump", "Schritt 2 ist Springen")
	kit.check_target(guide, game.hud.jump_button, "SPRINGEN")
	await _tap(game.hud.jump_button)
	kit.check(guide.state == "praise", "SPRINGEN erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.current_step_id() == "dash", "Schritt 3 ist Flitzen")
	kit.check_target(guide, game.hud.dash_button, "FLITZEN")
	await _tap(game.hud.dash_button)
	kit.check(guide.state == "praise", "FLITZEN erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.current_step_id() == "stars", "Schritt 4 ist Sterne sammeln")
	kit.check(guide.target_rect().has_area(), "Sternzähler ist das Zeigerziel")
	# Echte Sterne: Lumo läuft von knapp davor durch die Sterne (hohe verfehlt er).
	var taken: int = 0
	var kept_before: int = game.track.kept
	for index in range(game.plan.star_s.size()):
		if taken >= 3 or guide.state != "running":
			break
		if float(game.plan.star_s[index]) < 30.0:
			continue
		var before: int = game.track.kept
		game.player.place(
			float(game.plan.star_s[index]) - 1.5, float(game.plan.star_lat[index]), 8.0
		)
		for _step in range(30):
			game.advance(STEP)
		if game.track.kept > before:
			taken += 1
		await kit.frames(1)
	await kit.frames(2)
	var gained: int = game.track.kept - kept_before
	kit.check(taken >= 1 and gained >= 3, "Sternzähler +%d durch %d echte Sterne" % [gained, taken])
	kit.check(guide.state == "praise", "drei Sterne erfüllen den Schritt")
	await _wait(1.1)
	kit.check(guide.state == "outro", "Abschluss nach dem letzten Schritt")
	await _wait(2.4)
	kit.check(guide.state == "done", "Einführung ist fertig")
	kit.check(
		kit_script.guide_script.load_status(CHILD_A, "run").state == "done", "Ablage: gesehen"
	)
	await kit.frames(2)
	kit.check(guide.replay_button.visible and not guide.bubble.visible, "danach nur Wiederholen")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for control in [
		game.hud.stick, game.hud.jump_button, game.hud.dash_button, game.hud.pause_button
	]:
		kit.check(
			not replay_rect.intersects(control.get_global_rect()),
			"Wiederholen frei von " + control.name
		)
	await _tap(guide.replay_button, 2)
	kit.check(guide.current_step_id() == "steer", "Wiederholen startet bei Schritt 1")
	await _tap(guide.skip_button, 2)
	kit.check(not guide.is_running(), "Überspringen schließt die Einführung")
	game.pause()
	await kit.frames(2)
	kit.check(not guide.root.visible, "in der Pause verborgen")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running() and not guide.bubble.visible, "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "steer", "anderes Kind sieht die Einführung")
	kit.check(game.hud.stick.is_visible_in_tree(), "Stick ist sichtbar")
	stick = kit.press(game.hud.stick, 0)
	kit.drag(stick - Vector2(game.hud.stick.size.x * 0.4, 0.0), Vector2(-50, 0), 0)
	await _wait(0.5)
	kit.release(stick, 0)
	await _close()
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "run").step == 1, "Abbruch merkt Schritt 2"
	)
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "jump", "Fortsetzen bei Springen")
	await _tap(guide.skip_button, 2)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "run").state == "skipped",
		"Überspringen gemerkt"
	)
	await _close()

	kit_script.automatic_mode()
	game = load("res://scenes/games/lumo_run.tscn").instantiate()
	root.add_child(game)
	await kit.frames(2)
	kit.check(game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)
	print("[RunGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
