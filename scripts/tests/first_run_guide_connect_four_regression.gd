extends SceneTree
## Erste Einführung VIER GEWINNT: echte Touches auf die Spaltenknöpfe, Spielstand vom
## Test-Host, Lumos Züge dazwischen; Überspringen/Wiederholen, Fortsetzen, anderes Kind.

const TABLE := "res://scripts/games/connect_four/connect_four_table.gd"
const TOKEN := "cccccccccccccccccccccccccccccccc"
const CHILD_A := "guide-test-c4-a"
const CHILD_B := "guide-test-c4-b"
var kit_script
var kit
var table
var bridge


class Transport:
	extends RefCounted
	var state: Dictionary = {}
	var requests: Array[Dictionary] = []

	func getConnectFourState() -> String:
		return JSON.stringify(state)

	func submitConnectFourAction(payload: String) -> bool:
		requests.append(JSON.parse_string(payload))
		return true

	func returnToApp(_destination: String, _payload: String) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _fresh_state() -> Dictionary:
	var board := []
	board.resize(42)
	board.fill(0)
	return {
		"schema": 1,
		"game": "connect_four",
		"token": TOKEN,
		"roundId": "d".repeat(32),
		"owner": "a".repeat(64),
		"revision": 1,
		"recordRevision": 1,
		"ack": 0,
		"rejected": 0,
		"paused": false,
		"canDrop": true,
		"exit": false,
		"reduceMotion": false,
		"twoPlayers": false,
		"rewarded": false,
		"phase": "playing",
		"level": "leicht",
		"turn": 1,
		"board": board,
		"columns": [],
		"validColumns": [0, 1, 2, 3, 4, 5, 6],
		"winningLine": [],
		"error": null
	}


func _push(next: Dictionary) -> void:
	next.revision = int(table._state.revision) + 1
	next.recordRevision = int(table._state.recordRevision) + 1
	if not bridge.requests.is_empty():
		next.ack = int(bridge.requests.back().sequence)
	bridge.state = next.duplicate(true)
	kit.check(table.apply_state(next), "Host-Zustand angenommen")
	while table._dropping:
		await process_frame
	await kit.frames(3)


## Legt einen Stein in die Spalte (Host-Antwort) – piece 1 Kind, 2 Lumo.
func _place(column: int, piece: int) -> void:
	var next: Dictionary = table._state.duplicate(true)
	var row := 5
	while int(next.board[row * 7 + column]) != 0:
		row -= 1
	next.board[row * 7 + column] = piece
	next.columns.append(column)
	next.turn = 2 if piece == 1 else 1
	next.canDrop = piece == 2
	await _push(next)


func _kid_drop(column: int) -> void:
	var button: Control = table.column_buttons[column]
	kit.check(not button.disabled, "Spalte %d ist bereit" % (column + 1))
	var at: Vector2 = kit.press(button, 1)
	await kit.frames(1)
	kit.release(at, 1)
	await kit.frames(2)
	var last: Dictionary = bridge.requests.back()
	kit.check(
		last.action == "drop" and int(last.column) == column,
		"Touch wirft in Spalte %d" % (column + 1)
	)
	await _place(column, 1)


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	root.get_node("HostBridge")._options = {
		"displayDensity": kit_script.density(), "connectFourToken": TOKEN
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
	bridge.state = _fresh_state()
	table = load(TABLE).new()
	table._host = bridge
	root.add_child(table)
	await kit.frames(10)
	var guide = table.get_node_or_null("FirstRunGuide")
	kit.check(guide != null, "Vier gewinnt hängt die Einführung ein")
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


func _tap(control: Control) -> void:
	var at: Vector2 = kit.press(control, 2)
	kit.release(at, 2)
	await kit.frames(2)


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "ConnectFourGuide")
	root.size = kit_script.window_size(Vector2i(720, 1280))
	DisplayServer.window_set_size(root.size)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "erstes Öffnen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "drop", "Schritt 1: Stein einwerfen")
	kit.check_target(guide, table.column_buttons[3], "Spalte 4")
	await kit.snap("vier-gewinnt-schritt1")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	await _kid_drop(3)
	kit.check(guide.completed.has("drop"), "Einwerfen erfüllt Schritt 1")
	kit.check(not guide.root.visible, "während Lumos Zug verborgen")
	await _place(4, 2)
	await _next_step(guide)
	kit.check(guide.current_step_id() == "neighbour", "Schritt 2: neben den eigenen Stein")
	kit.check_target(guide, table.column_buttons[4], "Nachbarspalte")
	await _kid_drop(2)
	kit.check(guide.completed.has("neighbour"), "Nachbarstein erfüllt Schritt 2")
	await _place(2, 2)
	await _next_step(guide)
	kit.check(guide.current_step_id() == "block", "Schritt 3: auf Lumos Stein")
	kit.check(guide.target_rect().has_area(), "Zeiger auf eine Spalte mit Lumos Stein")
	await _kid_drop(4)
	kit.check(guide.completed.has("block"), "Stein auf Lumos Stein erfüllt Schritt 3")
	await _place(0, 2)
	await _next_step(guide)
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(
		kit_script.guide_script.load_status(CHILD_A, "connect_four").state == "done", "gesehen"
	)
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for button in table.column_buttons + [table.pause_button, table.return_button]:
		kit.check(
			not replay_rect.intersects(button.get_global_rect()),
			"Wiederholen frei von " + button.text
		)
	await _tap(guide.replay_button)
	kit.check(guide.current_step_id() == "drop", "Wiederholen startet bei Schritt 1")
	await _tap(guide.skip_button)
	kit.check(not guide.is_running(), "Überspringen beendet")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "drop", "anderes Kind sieht sie")
	await _kid_drop(1)
	await _close()
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "connect_four").step == 1, "Abbruch gemerkt"
	)
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "neighbour", "Fortsetzen bei Schritt 2")
	await _tap(guide.skip_button)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "connect_four").state == "skipped",
		"übersprungen"
	)
	await _close()

	kit_script.automatic_mode()
	bridge = Transport.new()
	bridge.state = _fresh_state()
	table = load(TABLE).new()
	table._host = bridge
	root.add_child(table)
	await kit.frames(4)
	kit.check(table.get_node_or_null("FirstRunGuide") == null, "--script-Läufe ohne Einführung")
	await _close()
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)
	print("[ConnectFourGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
