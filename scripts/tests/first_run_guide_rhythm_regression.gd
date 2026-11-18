extends SceneTree
## Erste Einführung LUMO RHYTHM PARTY: echte Touches im Takt auf die Spurtasten, Pause
## über Ⅱ; Überspringen/Wiederholen, Fortsetzen, zweites Öffnen, anderes Kind.

const CHILD_A := "guide-test-rhythm-a"
const CHILD_B := "guide-test-rhythm-b"
var kit_script
var kit
var game


func _initialize() -> void:
	call_deferred("_run")


func _button(parent: Node, caption: String) -> Button:
	for button in parent.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree():
			return button
	return null


func _tap(control: Control, index: int = 3) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	kit.touch(at, true, index)
	await kit.frames(1)
	kit.touch(at, false, index)
	await kit.frames(2)


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lumo_rhythm_%s.cfg" % child))
	root.get_node("HostBridge")._options = {"displayDensity": kit_script.density()}
	game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(6)
	var guide = game.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Rhythmus hängt die Einführung ein")
	kit.check(not guide.root.visible, "im Startmenü verborgen")
	await _tap(_button(game.menu, "Los geht’s!"))
	kit.check(game.running, "Touch auf „Los geht’s!“ startet das Lied")
	await kit.frames(3)
	return guide


func _close() -> void:
	game.queue_free()
	await kit.frames(4)


func _next_step(guide) -> void:
	while guide.state == "praise":
		await process_frame


## Tippt die nächste offene Tipp-/Sternnote genau im Takt auf ihrer Spurtaste.
func _hit_next() -> bool:
	var note: Dictionary = {}
	for candidate: Dictionary in game.model.notes:
		if int(candidate.state) == 0:
			note = candidate
			break
	if note.is_empty():
		return false
	while game.model.time < float(note.time) - 0.03:
		await process_frame
	var lane: Control = game.lane_buttons[int(note.lane)]
	var at: Vector2 = lane.get_global_rect().get_center()
	kit.touch(at, true, 0)
	await process_frame
	if str(note.kind) in ["hold", "slide"]:
		var end: float = float(note.time) + float(note.length)
		while game.model.time < end:
			if str(note.kind) == "slide" and game.model.time > end - 0.1:
				var target: Control = game.lane_buttons[int(note.target)]
				kit.drag(target.get_global_rect().get_center(), Vector2.ZERO, 0)
			await process_frame
	kit.touch(at, false, 0)
	await kit.frames(2)
	return int(note.state) == 2


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "RhythmGuide")
	root.size = kit_script.window_size(Vector2i(720, 1280))
	DisplayServer.window_set_size(root.size)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "Lied läuft: Lumos Sprechblase")
	kit.check(guide.current_step_id() == "hit", "Schritt 1: eine Note treffen")
	kit.check_target(guide, game.lane_buttons[int(game.model.notes[0].lane)], "erste Spur")
	await kit.snap("rhythmus-schritt1")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	kit.check(
		not guide.bubble.get_global_rect().intersects(game.bottom.get_global_rect()),
		"Sprechblase frei von den Spurtasten"
	)
	kit.check(await _hit_next(), "Tippen im Takt trifft die Note")
	kit.check(guide.completed.has("hit"), "Treffer erfüllt Schritt 1")
	var hits := 0
	while not guide.completed.has("combo") and hits < 6:
		if await _hit_next():
			hits += 1
	kit.check(
		int(game.model.combo) >= 3, "drei Treffer hintereinander (Combo %d)" % game.model.combo
	)
	kit.check(guide.completed.has("combo"), "Combo erfüllt Schritt 2")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "pause", "Schritt 3: Pause")
	kit.check_target(guide, game.pause_button, "Pause")
	await _tap(game.pause_button)
	kit.check(game.paused, "Touch auf Ⅱ pausiert")
	kit.check(not guide.root.visible, "im Pausenmenü verborgen")
	kit.check(guide.completed.has("pause"), "Pause erfüllt Schritt 3")
	await _tap(_button(game.menu, "Weiter im Takt"))
	while game.resume_countdown > 0.0:
		await process_frame
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "rhythm").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for control in game.lane_buttons + [game.pause_button]:
		kit.check(
			not replay_rect.intersects(control.get_global_rect()),
			"Wiederholen frei von " + control.text
		)
	await _tap(guide.replay_button, 2)
	kit.check(guide.current_step_id() == "hit", "Wiederholen startet bei Schritt 1")
	await _tap(guide.skip_button, 2)
	kit.check(not guide.is_running(), "Überspringen beendet")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "hit", "anderes Kind sieht sie")
	kit.check(await _hit_next(), "Kind B trifft")
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "rhythm").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "combo", "Fortsetzen bei Schritt 2")
	await _tap(guide.skip_button, 2)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "rhythm").state == "skipped", "übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	game = load("res://scenes/creative/rhythm_world.tscn").instantiate()
	root.add_child(game)
	await kit.frames(4)
	kit.check(game.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	for child in [CHILD_A, CHILD_B]:
		kit_script.reset_child(child)
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://lumo_rhythm_%s.cfg" % child)
		)
	print("[RhythmGuide] PASS: %d Prüfungen" % kit.checks)
	if root.has_node("GameSoundscape"):
		root.get_node("GameSoundscape").release_audio()
	await create_timer(0.4).timeout
	quit(0)
