extends SceneTree
## Erste Einführung LUMO ABENTEUER: echter Stick, SPRINGEN per Touch, ein echter Kristall;
## Überspringen/Wiederholen, Fortsetzen, zweites Öffnen, anderes Kind.

const CHILD_A := "guide-test-jump-a"
const CHILD_B := "guide-test-jump-b"
var kit_script
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _tap(control: Control, index: int = 2) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	kit.touch(at, true, index)
	await kit.frames(2)
	kit.touch(at, false, index)
	await kit.frames(2)


func _forget_session(child: String) -> void:
	var prefix := "jump_" + child.sha256_text().substr(0, 24)
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with(prefix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file))


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	_forget_session(child)
	root.get_node("HostBridge")._options = {"displayDensity": kit_script.density()}
	game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	await kit.frames(6)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Abenteuer hängt die Einführung ein")
	return guide


func _close() -> void:
	game.abandoned = true
	game.queue_free()
	await kit.frames(4)


func _next_step(guide) -> void:
	while guide.state == "praise":
		await process_frame


func _walk(direction: Vector2) -> void:
	var centre: Vector2 = game.movement_stick.get_global_rect().get_center()
	kit.touch(centre, true, 0)
	await kit.frames(1)
	kit.drag(centre + direction * game.movement_stick.size.x * 0.4, direction * 40.0, 0)
	await create_timer(0.8).timeout
	kit.touch(centre, false, 0)
	await kit.frames(2)


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "JumpGuide")
	root.size = kit_script.window_size(Vector2i(720, 1280))
	DisplayServer.window_set_size(root.size)
	for child in [CHILD_A, CHILD_B]:
		kit_script.reset_child(child)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "erstes Öffnen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "walk", "Schritt 1: laufen")
	kit.check_target(guide, game.movement_stick, "Stick")
	await kit.snap("abenteuer-schritt1")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	await _walk(Vector2.UP)
	kit.check(guide.completed.has("walk"), "Stick erfüllt Schritt 1")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "jump", "Schritt 2: springen")
	kit.check_target(guide, game.jump_action, "SPRINGEN")
	await _tap(game.jump_action, 1)
	kit.check(guide.completed.has("jump"), "SPRINGEN erfüllt Schritt 2")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "collect", "Schritt 3: Kristall")
	kit.check(guide.target_rect().has_area(), "Zeiger auf der Anzeige")
	var crystal: Node3D = null
	for candidate: Node3D in game.crystals:
		if candidate.visible:
			crystal = candidate
			break
	game.actor.position = crystal.position
	await kit.frames(6)
	kit.check(not crystal.visible, "Lumo sammelt den Kristall echt ein")
	kit.check(guide.completed.has("collect"), "Kristall erfüllt Schritt 3")
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "jump").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for control in game.header_buttons + [game.movement_stick, game.jump_action]:
		kit.check(
			not replay_rect.intersects(control.get_global_rect()),
			"Wiederholen frei von " + control.name
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
	await _walk(Vector2.LEFT)
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "jump").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "jump", "Fortsetzen bei Schritt 2")
	await _tap(guide.skip_button)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "jump").state == "skipped", "übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	await kit.frames(4)
	kit.check(game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	for child in [CHILD_A, CHILD_B]:
		kit_script.reset_child(child)
		_forget_session(child)
	print("[JumpGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
