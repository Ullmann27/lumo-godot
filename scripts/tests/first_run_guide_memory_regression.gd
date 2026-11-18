extends SceneTree
## Erste Einführung LUMO MEMORY: echte Touches auf Karten (Spielstand vom Test-Host
## wie in memory_table_regression.gd), Überspringen/Wiederholen, Fortsetzen,
## zweites Öffnen, anderes Kind; während Lumos Zug verborgen.

const TABLE := "res://scripts/games/memory/memory_table.gd"
const TOKEN := "cccccccccccccccccccccccccccccccc"
const OWNER := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const CHILD_A := "guide-test-memory-a"
const CHILD_B := "guide-test-memory-b"
var kit_script
var kit
var table
var bridge


class Transport:
	extends RefCounted
	var state: Dictionary = {}
	var requests: Array[Dictionary] = []

	func getTableState() -> String:
		return JSON.stringify(state)

	func submitTableAction(payload: String) -> bool:
		requests.append(JSON.parse_string(payload))
		return true

	func returnToApp(_destination: String, _payload: String) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _fresh_state() -> Dictionary:
	var cards := []
	for index in range(8):
		cards.append({"index": index, "faceUp": false, "matched": false, "motif": null})
	return {
		"schema": 1,
		"game": "memory",
		"token": TOKEN,
		"owner": OWNER,
		"roundId": "d".repeat(32),
		"revision": 1,
		"recordRevision": 1,
		"ack": 0,
		"rejected": 0,
		"paused": false,
		"exit": false,
		"reduceMotion": false,
		"rewarded": false,
		"difficulty": "leicht",
		"pack": "alle",
		"count": 8,
		"cards": cards,
		"turn": "kind",
		"phase": "select",
		"kindPairs": 0,
		"lumoPairs": 0,
		"kindMoves": 0,
		"kindStreak": 0,
		"line": "Lass uns Memory spielen!",
		"remainingMs": 0,
		"complete": false,
		"stars": 0,
		"canFlip": true,
		"best": {},
		"error": null
	}


## Antwort des Hosts auf die letzte Eingabe: neue Revision mit den Änderungen.
func _reply(changes: Dictionary) -> void:
	var next: Dictionary = table._state.duplicate(true)
	next.revision = int(next.revision) + 1
	next.recordRevision = int(next.recordRevision) + 1
	if not bridge.requests.is_empty():
		next.ack = int(bridge.requests.back().sequence)
	next.merge(changes, true)
	bridge.state = next.duplicate(true)
	kit.check(table.apply_state(next), "Host-Zustand angenommen")
	await kit.frames(40)


func _flip(index: int, motif: String, matched: bool = false, extra: Dictionary = {}) -> void:
	var button: Control = table._cards[index].button
	var at: Vector2 = kit.press(button, 1)
	await kit.frames(1)
	kit.release(at, 1)
	await kit.frames(2)
	kit.check(
		bridge.requests.back().action == "flip", "Touch auf Karte %d sendet Aufdecken" % index
	)
	var cards: Array = table._state.cards.duplicate(true)
	cards[index] = {"index": index, "faceUp": true, "matched": matched, "motif": motif}
	if matched:
		for other in range(cards.size()):
			if other != index and cards[other].get("motif") == motif:
				cards[other].matched = true
	var changes := {"cards": cards}
	changes.merge(extra, true)
	await _reply(changes)


func _open(child: String) -> Variant:
	kit_script.use_child(child)
	root.get_node("HostBridge")._options = {"displayDensity": 1.0, "tableToken": TOKEN}
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
	kit.check(guide != null, "Memory hängt die Einführung ein")
	return guide


## Wartet, bis Lumos Lob vorbei ist.
func _next_step(guide) -> void:
	while guide.state == "praise":
		await process_frame


func _close() -> void:
	table.queue_free()
	await kit.frames(4)


func _run() -> void:
	kit_script = load("res://scripts/tests/first_run_guide_kit.gd")
	kit = kit_script.new(self, "MemoryGuide")
	root.size = Vector2i(720, 1280)
	kit_script.reset_child(CHILD_A)
	kit_script.reset_child(CHILD_B)

	var guide = await _open(CHILD_A)
	kit.check(guide.bubble.visible and guide.root.visible, "erstes Öffnen zeigt Lumos Sprechblase")
	kit.check(guide.current_step_id() == "first_card", "Schritt 1: Karte aufdecken")
	kit.check_target(guide, table._cards[0].button, "Karte 1")
	kit.check_touch_size(guide, guide.skip_button, "Überspringen")
	await _flip(0, "panda")
	kit.check(guide.completed.has("first_card"), "Aufdecken erfüllt Schritt 1")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "second_card", "Schritt 2: zweite Karte")
	kit.check_target(guide, table._cards[1].button, "Karte 2")
	await _flip(1, "hase", false, {"kindMoves": 1})
	kit.check(guide.completed.has("second_card"), "zweite Karte erfüllt Schritt 2")
	await _next_step(guide)
	kit.check(guide.current_step_id() == "pair", "Schritt 3: Paar finden")
	kit.check(guide.target_rect().has_area(), "Zeiger auf dem Punktestand")
	# Lumos Zug: die Einführung tritt zur Seite.
	var cards: Array = table._state.cards.duplicate(true)
	for index in [0, 1]:
		cards[index] = {"index": index, "faceUp": false, "matched": false, "motif": null}
	await _reply({"cards": cards, "turn": "lumo", "phase": "botFirst"})
	kit.check(not guide.root.visible, "während Lumos Zug verborgen")
	await _reply({"turn": "kind", "phase": "select"})
	kit.check(guide.root.visible and guide.current_step_id() == "pair", "Kind wieder dran: weiter")
	await _flip(2, "stern")
	await _flip(3, "stern", true, {"kindPairs": 1, "kindMoves": 2})
	kit.check(guide.completed.has("pair"), "ein Paar erfüllt Schritt 3")
	await _next_step(guide)
	kit.check(guide.state in ["outro", "done"], "Abschluss")
	await create_timer(2.4).timeout
	kit.check(guide.state == "done", "Einführung fertig")
	kit.check(kit_script.guide_script.load_status(CHILD_A, "memory").state == "done", "gesehen")
	await kit.frames(2)
	kit.check(guide.replay_button.visible, "Wiederholen-Knopf sichtbar")
	kit.check_touch_size(guide, guide.replay_button, "Wiederholen")
	var replay_rect: Rect2 = guide.replay_button.get_global_rect()
	for card in table._cards:
		if card.button.is_visible_in_tree():
			kit.check(
				not replay_rect.intersects(card.button.get_global_rect()),
				"Wiederholen frei von Karten"
			)
	for button in [table.back_button, table.pause_button]:
		kit.check(
			not replay_rect.intersects(button.get_global_rect()),
			"Wiederholen frei von " + button.name
		)
	var at: Vector2 = kit.press(guide.replay_button, 2)
	kit.release(at, 2)
	await kit.frames(2)
	kit.check(guide.current_step_id() == "first_card", "Wiederholen startet bei Schritt 1")
	at = kit.press(guide.skip_button, 2)
	kit.release(at, 2)
	await kit.frames(2)
	kit.check(not guide.is_running(), "Überspringen beendet")
	await _close()

	guide = await _open(CHILD_A)
	kit.check(not guide.is_running(), "zweites Öffnen ohne Einführung")
	await _close()

	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "first_card", "anderes Kind sieht sie")
	await _flip(4, "pilz")
	await _close()
	kit.check(kit_script.guide_script.load_status(CHILD_B, "memory").step == 1, "Abbruch gemerkt")
	guide = await _open(CHILD_B)
	kit.check(guide.current_step_id() == "second_card", "Fortsetzen bei Schritt 2")
	at = kit.press(guide.skip_button, 2)
	kit.release(at, 2)
	await kit.frames(2)
	kit.check(
		kit_script.guide_script.load_status(CHILD_B, "memory").state == "skipped", "übersprungen"
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
	print("[MemoryGuide] PASS: %d Prüfungen" % kit.checks)
	await create_timer(0.4).timeout
	quit(0)
