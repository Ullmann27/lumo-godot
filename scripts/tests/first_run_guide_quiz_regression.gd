extends SceneTree
## Erste Einführung LUMO QUIZSHOW: echte Touches auf Antwort, Aufdecken, Nächste Frage
## und Joker (Spielstand vom Test-Host wie in quiz_studio_runtime.gd); Überspringen/
## Wiederholen, Fortsetzen, zweites Öffnen, anderes Kind.

const TABLE := "res://scripts/games/quiz/quiz_studio.gd"
const TOKEN := "b1111111111111111111111111111111"
const CHILD_A := "guide-test-quiz-a"
const CHILD_B := "guide-test-quiz-b"
var kit_script
var kit
var table
var bridge


class Transport:
	extends RefCounted
	var value: Dictionary = {}
	var requests: Array[Dictionary] = []

	func getTableState() -> String:
		return JSON.stringify(value)

	func submitTableAction(payload: String) -> bool:
		requests.append(JSON.parse_string(payload))
		return true

	func returnToApp(_destination: String, _payload: String) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _fresh_state() -> Dictionary:
	return {
		"schema": 1,
		"game": "quiz",
		"token": TOKEN,
		"roundId": "c".repeat(32),
		"owner": "a".repeat(64),
		"revision": 1,
		"recordRevision": 1,
		"ack": 0,
		"rejected": 0,
		"paused": false,
		"exit": false,
		"reduceMotion": false,
		"subject": "alle",
		"grade": 1,
		"number": 1,
		"total": 20,
		"questionSubject": "Mathe",
		"prompt": "Wie viele Ecken hat ein Dreieck?",
		"options": ["Zwei", "Drei", "Vier", "Fünf"],
		"selected": null,
		"revealed": false,
		"gameOver": false,
		"won": false,
		"correctIndex": null,
		"explanation": null,
		"hidden": [],
		"usedJokers": [],
		"audience": null,
		"hint": null,
		"securedStars": 0,
		"awardedStars": 0,
		"rewarded": false,
		"error": null,
		"canSelect": true,
		"canReveal": false,
		"canNext": false
	}


## Host bestätigt die letzte Eingabe mit den Änderungen.
func _ack(delta: Dictionary) -> void:
	var value: Dictionary = table._state.duplicate(true)
	value.merge(delta, true)
	value.ack = int(bridge.requests.back().sequence)
	value.recordRevision = int(table._state.recordRevision) + 1
	value.revision = int(table._state.revision) + 1
	bridge.value = value
	table._poll_state()
	await kit.frames(6)


func _tap(control: Control, action: String) -> void:
	kit.check(control.is_visible_in_tree() and not control.disabled, action + " ist bereit")
	var count: int = bridge.requests.size()
	var at: Vector2 = kit.press(control, 1)
	await kit.frames(1)
	kit.release(at, 1)
	await kit.frames(2)
	kit.check(bridge.requests.size() == count + 1, "Touch sendet " + action)
	kit.check(str(bridge.requests.back().get("action", "")) == action, "Eingabe ist " + action)


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	root.get_node("HostBridge")._options = {
		"displayDensity": kit_script.density(), "tableToken": TOKEN
	}
	var mobile = root.get_node("MobileRuntime")
	mobile._android_safe_area_enabled = true
	mobile._safe_area_reader = func(_callback): return false
	mobile._safe_area_observation = {
		"window_size": root.size,
		"view_size": Vector2(root.size),
		"decor_size": Vector2(root.size),
		"render_rect": Rect2(Vector2.ZERO, Vector2(root.size)),
		"system_insets": Rect2(),
		"insets": Rect2()
	}
	bridge = Transport.new()
	bridge.value = _fresh_state()
	table = load(TABLE).new()
	table._host = bridge
	root.add_child(table)
	await kit.frames(12)
	var guide = table.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Quizshow hängt die Einführung ein")
	return guide


func _close() -> void:
	table.queue_free()
	await kit.frames(4)


func _next_step(guide) -> void:
	var waited := 0
	while guide.state == "praise" and waited < 600:
		waited += 1
		await process_frame
	kit.check(guide.state != "praise", "Lumos Lob endet (aktiv=%s)" % guide.root.visible)


func _press(control: Control) -> void:
	var at: Vector2 = kit.press(control, 2)
	kit.release(at, 2)
	await kit.frames(2)


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "QuizGuide")
	root.size = kit_script.window_size(Vector2i(720, 1280))
	DisplayServer.window_set_size(root.size)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(table._authority_ready, "Spielstand bestätigt")
	kit.check(guide.bubble.visible and guide.root.visible, "erstes Öffnen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "answer", "Schritt 1: Antwort antippen")
	await kit.snap("quiz-schritt1")
	kit.check_target(guide, table.answer_buttons[0], "Antwort A")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	await _tap(table.answer_buttons[1], "select")
	await _ack({"selected": 1, "canReveal": true})
	kit.check(guide.completed.has("answer"), "Antwort erfüllt Schritt 1")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "reveal", "Schritt 2: aufdecken")
	kit.check_target(guide, table.reveal_button, "Aufdecken")
	await _tap(table.reveal_button, "reveal")
	await _ack(
		{
			"revealed": true,
			"correctIndex": 1,
			"explanation": "Ein Dreieck hat drei Ecken.",
			"canSelect": false,
			"canReveal": false,
			"canNext": true,
			"securedStars": 1
		}
	)
	kit.check(guide.completed.has("reveal"), "Aufdecken erfüllt Schritt 2")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "next", "Schritt 3: nächste Frage")
	kit.check_target(guide, table.next_button, "Nächste Frage")
	await _tap(table.next_button, "next")
	await _ack(
		{
			"number": 2,
			"prompt": "Was ist 2 + 3?",
			"options": ["4", "5", "6", "7"],
			"selected": null,
			"revealed": false,
			"correctIndex": null,
			"explanation": null,
			"canSelect": true,
			"canNext": false
		}
	)
	kit.check(guide.completed.has("next"), "Nächste Frage erfüllt Schritt 3")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "joker", "Schritt 4: Joker")
	kit.check_target(guide, table.joker_buttons[0], "Joker")
	await _tap(table.joker_buttons[0], "joker")
	await _ack({"usedJokers": [str(bridge.requests.back().joker)], "hidden": [0, 2]})
	kit.check(guide.completed.has("joker"), "Joker erfüllt Schritt 4")
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "quiz").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	await kit.snap("quiz-wiederholen")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for button in (
		table.answer_buttons + table.joker_buttons + [table.return_button, table.pause_button]
	):
		if button.is_visible_in_tree():
			kit.check(
				not replay_rect.intersects(button.get_global_rect()),
				"Wiederholen frei von " + button.name
			)
	await _press(guide.replay_button)
	kit.check(guide.current_step_id() == "answer", "Wiederholen startet bei Schritt 1")
	await _press(guide.skip_button)
	kit.check(not guide.is_running(), "Überspringen beendet")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "answer", "anderes Kind sieht sie")
	await _tap(table.answer_buttons[2], "select")
	await _ack({"selected": 2, "canReveal": true})
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "quiz").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "reveal", "Fortsetzen bei Schritt 2")
	await _press(guide.skip_button)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "quiz").state == "skipped", "übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	bridge = Transport.new()
	bridge.value = _fresh_state()
	table = load(TABLE).new()
	table._host = bridge
	root.add_child(table)
	await kit.frames(4)
	kit.check(table.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)
	print("[QuizGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
