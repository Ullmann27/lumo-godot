extends RefCounted
## Erste Einführung für LUMO BAUWELT – im Bau-Modus (nicht beim Herumlaufen, nicht in
## Pause oder Auswahlfenstern). Schritte: Bauteil wählen, auf die Wiese tippen,
## umsehen, Rückgängig.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "build"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "part",
			"text": "Such dir unten ein Bauteil aus.",
			"target": func() -> Variant: return _part_button(game),
			"done": func(guide) -> bool: return guide.changed("part", str(game.chosen)),
		},
		{
			"id": "place",
			"text": "Tippe auf die Wiese – dort baust du es hin.",
			"target": func() -> Variant: return _world_rect(game, 0.5),
			"done": _placed.bind(game),
		},
		{
			"id": "look",
			"text": "Zieh einen Finger über die Welt, um dich umzusehen.",
			"target": func() -> Variant: return _world_rect(game, 0.7),
			"done": _looked.bind(game),
		},
		{
			"id": "undo",
			"text": "Ups? Mit „Rückgängig“ verschwindet dein letztes Teil.",
			"target": func() -> Variant: return _tool(game, "Rückgängig"),
			"done": func(guide) -> bool: return guide.since_step("count", _count(game)) <= -1.0,
		},
	]
	var options := {
		"outro": "Super! Jetzt bau deine eigene Welt.",
		"replay_position": _replay_spot.bind(game),
		"bubble_position": func(_size: Vector2) -> float: return _bubble_top(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	var dialog: Window = game.choice_window
	return (
		not bool(game.paused)
		and not bool(game.exploring)
		and not bool(game.move_mode)
		and str(game.sandbox_mode).is_empty()
		and not (is_instance_valid(dialog) and dialog.visible)
		and not (is_instance_valid(game.pause_panel) and game.pause_panel.visible)
	)


static func _count(game: Node) -> float:
	return float(game.model.pieces.size())


static func _placed(guide, game: Node) -> bool:
	return guide.since_step("count", _count(game)) >= 1.0


static func _looked(guide, game: Node) -> bool:
	return absf(guide.since_step("orbit", float(game.orbit))) >= 0.35


static func _part_button(game: Node) -> Variant:
	var fallback: Control = null
	for id: String in game.part_buttons:
		var button: Control = game.part_buttons[id]
		if not button.is_visible_in_tree():
			continue
		if id != str(game.chosen):
			return button
		fallback = button
	return fallback


static func _tool(game: Node, caption: String) -> Variant:
	for button in game.tool_actions.get_children():
		if button is Button and button.text == caption and button.is_visible_in_tree():
			return button
	return null


## Freie Fläche der Welt zwischen oberer Leiste und unterem Werkzeugdock.
static func _world_rect(game: Node, share: float) -> Variant:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var top: float = (
		game.upper_hud.get_global_rect().end.y if is_instance_valid(game.upper_hud) else 0.0
	)
	var bottom: float = view.end.y
	if is_instance_valid(game.lower_hud):
		bottom = game.lower_hud.get_global_rect().position.y
	var height: float = maxf(80.0, (bottom - top) * share * 0.6)
	var width: float = view.size.x * share * 0.6
	var centre := Vector2(view.get_center().x, (top + bottom) * 0.5)
	return Rect2(centre - Vector2(width, height) * 0.5, Vector2(width, height))


## Sprechblase oben unter der Leiste, damit Bauteile und Welt frei bleiben.
static func _bubble_top(game: Node) -> float:
	if is_instance_valid(game.upper_hud):
		return game.upper_hud.get_global_rect().end.y + 12.0
	return 90.0


static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var top: float = _bubble_top(game)
	return Vector2(view.end.x - size.x - 16.0, top)
