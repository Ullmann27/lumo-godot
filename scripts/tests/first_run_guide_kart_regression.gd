extends SceneTree
## Erste Einführung LUMO KART: erscheint erst im Rennen, jeder Schritt wird durch die
## echte Touch-Eingabe erfüllt, Überspringen/Wiederholen, Fortsetzen nach Abbruch,
## zweites Öffnen ohne Einführung, anderes Kind sieht sie wieder.

var kit_script
const STEP: float = 1.0 / 60.0
const CHILD_A := "guide-test-kart-a"
const CHILD_B := "guide-test-kart-b"
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _open(child: String, manual_gas: bool = true) -> Variant:
	kit_script.use_child(child)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await kit.frames(2)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Kart hängt die Einführung ein")
	await kit.frames(2)
	kit.check(not guide.root.visible, "im Menü ist die Einführung verborgen")
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	game._end_preview()
	game.auto_gas = not manual_gas
	await kit.frames(2)
	kit.check(not guide.root.visible, "während Vorschau/Startampel noch verborgen")
	game.countdown = 0.0
	game.racing = true
	game._update_hud()
	await kit.frames(3)
	return guide


func _close() -> void:
	game.abandoned = true
	game.queue_free()
	await kit.frames(4)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "KartGuide")
	root.size = Vector2i(1280, 720)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	# --- Erstes Öffnen: Einführung im Rennen, Schritt für Schritt mit echter Eingabe.
	var guide = await _open(CHILD_A)
	kit.check(guide.root.visible and guide.bubble.visible, "erstes Rennen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "steer", "Schritt 1 ist Lenken")
	kit.check(guide.portrait.texture != null, "Lumos Bild ist geladen")
	kit.check_target(guide, game.joystick, "Lenken")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	var stick: Vector2 = kit.press(game.joystick, 0)
	kit.drag(stick + Vector2(game.joystick.size.x * 0.4, 0.0), Vector2(60, 0), 0)
	await _wait(0.6)
	kit.check(game.steering > 0.35, "Stick lenkt das Kart (Touch geht durch die Einführung)")
	kit.check(guide.state == "praise", "Lenken erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.current_step_id() == "gas", "Schritt 2 ist GAS")
	kit.check_target(guide, game.gas_button, "GAS")
	var gas: Vector2 = kit.press(game.gas_button, 1)
	await _wait(1.0)
	kit.check(game.gas_held, "GAS-Taste wird gehalten")
	kit.release(gas, 1)
	kit.check(guide.state == "praise", "GAS halten erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.current_step_id() == "drift", "Schritt 3 ist Driften")
	kit.check_target(guide, game.drift_button, "DRIFT")
	var drift: Vector2 = kit.press(game.drift_button, 1)
	await _wait(0.8)
	kit.check(game.drifting, "DRIFT-Taste startet den Drift")
	kit.release(drift, 1)
	kit.release(stick + Vector2(game.joystick.size.x * 0.4, 0.0), 0)
	kit.check(guide.state == "praise", "Driften mit Lenken erfüllt den Schritt")
	await _wait(1.1)
	kit.check(game.item_boxes.size() > 0, "die Trainingsstrecke hat Itemboxen")
	kit.check(guide.current_step_id() == "itembox", "Schritt 4 ist Itembox")
	kit.check(guide.target_rect().has_area(), "Itembox-Schritt zeigt auf ein Ziel")
	# Echte Fahrt durch die erste Itembox.
	var box: Node3D = game.item_boxes[0]
	game.player.position = box.position
	game.speed = 14.0
	for _frame in range(3):
		game._physics_process(STEP)
	kit.check(not str(game.item).is_empty(), "Fahrt durch die Box bringt ein Item")
	game.item_roulette_time = 0.0
	await _wait(0.2)
	kit.check(guide.state == "praise", "Itembox erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.current_step_id() == "item", "Schritt 5 ist Item einsetzen")
	game._update_hud()
	await kit.frames(2)
	kit.check_target(guide, game.item_button, "Item")
	var tap: Vector2 = kit.press(game.item_button, 1)
	await kit.frames(2)
	kit.release(tap, 1)
	await _wait(0.2)
	kit.check(guide.state == "praise", "Tippen aufs Item erfüllt den Schritt")
	await _wait(1.1)
	kit.check(guide.state == "outro", "Abschluss nach dem letzten Schritt")
	await _wait(2.4)
	kit.check(guide.state == "done", "Einführung ist fertig")
	kit.check(
		kit_script.guide_script.load_status(CHILD_A, "kart").state == "done",
		"Ablage merkt sich 'gesehen'"
	)
	await kit.frames(2)
	kit.check(
		guide.replay_button.visible and not guide.bubble.visible, "danach nur der Wiederholen-Knopf"
	)
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	kit.check(
		not guide.replay_button.get_global_rect().intersects(game.joystick.get_global_rect()),
		"Wiederholen verdeckt den Stick nicht"
	)
	kit.check(
		not guide.replay_button.get_global_rect().intersects(game.pedal_pad.get_global_rect()),
		"Wiederholen verdeckt die Pedale nicht"
	)

	# --- Wiederholen über „Lumo, zeig es mir nochmal“, dann Überspringen.
	var replay: Vector2 = kit.press(guide.replay_button, 2)
	kit.release(replay, 2)
	await kit.frames(2)
	kit.check(
		guide.current_step_id() == "steer" and guide.bubble.visible,
		"Wiederholen startet bei Schritt 1"
	)
	var skip: Vector2 = kit.press(guide.skip_button, 2)
	kit.release(skip, 2)
	await kit.frames(2)
	kit.check(
		not guide.is_running() and guide.replay_button.visible,
		"Überspringen schließt die Einführung"
	)
	game.paused = true
	await kit.frames(2)
	kit.check(not guide.root.visible, "in der Pause ist auch der Wiederholen-Knopf weg")
	game.paused = false
	await _close()

	# --- Zweites Öffnen: keine Einführung mehr.
	guide = await _open(CHILD_A)
	kit.check(
		not guide.is_running() and not guide.bubble.visible, "zweites Öffnen zeigt keine Einführung"
	)
	await _close()

	# --- Anderes Kind: sieht sie wieder; Abbruch nach Schritt 1 und Fortsetzen.
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "steer", "anderes Kind sieht die Einführung")
	stick = kit.press(game.joystick, 0)
	kit.drag(stick - Vector2(game.joystick.size.x * 0.4, 0.0), Vector2(-60, 0), 0)
	await _wait(0.6)
	kit.release(stick, 0)
	kit.check(guide.state == "praise", "Lenken nach links zählt auch")
	await _close()
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "kart").step == 1,
		"Abbruch merkt sich Schritt 2"
	)
	guide = await _open(CHILD_B, false)
	await kit.frames(2)
	kit.check(
		guide.current_step_id() == "drift", "Fortsetzen; mit Auto-Gas entfällt der GAS-Schritt"
	)
	var skip_b: Vector2 = kit.press(guide.skip_button, 2)
	kit.release(skip_b, 2)
	await kit.frames(2)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "kart").state == "skipped",
		"Überspringen wird gemerkt"
	)
	await _close()
	guide = await _open(CHILD_B)
	kit.check(not guide.is_running(), "nach Überspringen kommt sie nicht wieder von selbst")
	await _close()

	# --- Automatisierte Läufe ohne Schalter sehen keine Einführung.
	kit_script.automatic_mode()
	kit_script.reset_child(CHILD_A)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await kit.frames(2)
	kit.check(
		game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe bleiben ohne Einführung"
	)
	await _close()
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)
	print("[KartGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
