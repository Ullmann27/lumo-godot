extends RefCounted
## Bedient den Kartentisch in Prüfungen wie ein Kind: mit echten Berührungen
## auf Karten, Knöpfen und Namensschildern.

const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")


static func settle(tree: SceneTree, frames: int = 3) -> void:
	for frame in range(frames):
		await tree.process_frame


## Wartet, bis keine Karte mehr fliegt und kein Zug mehr läuft.
static func idle(tree: SceneTree, table: Node, limit_seconds: float = 30.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(limit_seconds * 1000.0)
	await settle(tree, 2)
	while not table.is_idle():
		if Time.get_ticks_msec() > deadline:
			return false
		await tree.process_frame
	await settle(tree, 2)
	return true


static func touch(tree: SceneTree, point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame


static func drag(tree: SceneTree, from: Vector2, to: Vector2, steps: int = 6) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = from
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await tree.process_frame
	for step in range(1, steps + 1):
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = from.lerp(to, float(step) / steps)
		move.relative = (to - from) / steps
		Input.parse_input_event(move)
		Input.flush_buffered_events()
		await tree.process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = to
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await tree.process_frame
	await tree.process_frame


static func control_centre(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


static func press(tree: SceneTree, table: Node, id: String) -> bool:
	var button: Button = table.hud.find_button(id)
	if button == null or button.disabled:
		return false
	await touch(tree, control_centre(button))
	return true


## Sichtbarer Punkt einer Handkarte: oben links, wo Wert und Farbzeichen stehen.
static func hand_point(table: Node, card: int) -> Vector2:
	var quad: Array = table.card_quad(card)
	var top_left := Vector2(quad[0][0], quad[0][1])
	var top_right := Vector2(quad[1][0], quad[1][1])
	var bottom_left := Vector2(quad[3][0], quad[3][1])
	return top_left + (top_right - top_left) * 0.16 + (bottom_left - top_left) * 0.2


## Spielt einen erlaubten Zug des Kindes mit Berührungen.
static func play(tree: SceneTree, table: Node, move: Dictionary) -> bool:
	if move.has("pass") or move.has("draw"):
		return await press(tree, table, "Action")
	if move.has("card"):
		var card := int(move.card)
		await touch(tree, hand_point(table, card))
		await idle(tree, table, 5.0)
		if not table._selected.has(card):
			return false
		await touch(tree, hand_point(table, card))
		return true
	if move.has("ask"):
		var wanted := int(move.ask)
		var own := -1
		for card: int in table.rules.s.r.hands[0]:
			if DECK.rank(card) == wanted:
				own = card
				break
		if own < 0:
			return false
		await touch(tree, hand_point(table, own))
		await idle(tree, table, 5.0)
		if table._pick_rank != wanted:
			return false
		var plate: Button = table.hud.plates[int(move.from) - 1]
		await touch(tree, control_centre(plate))
		return true
	return false


## Der Zug, den ein mittelstarker Mitspieler an Stelle des Kindes wählen würde.
static func suggestion(table: Node) -> Dictionary:
	var rules: RefCounted = table.rules
	var probe: RefCounted = SESSION.create_rules(rules.game_id())
	probe.s = rules.snapshot()
	return SESSION.ai_move(probe, 0, 1)
