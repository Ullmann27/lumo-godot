extends RefCounted
## Erste Einführung für LUMO ABENTEUER (Wolkeninseln) – beim Spielen.
## Schritte: mit dem Stick laufen, springen, einen Kristall einsammeln.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "jump"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "walk",
			"text": "Lauf mit dem Stick los – zieh ihn in eine Richtung.",
			"target": func() -> Variant: return game.movement_stick,
			"done": _walked.bind(game),
		},
		{
			"id": "jump",
			"text": "Tippe auf SPRINGEN. Lange halten springt höher!",
			"target": func() -> Variant: return game.jump_action,
			"done": func(guide) -> bool: return guide.seen("jump"),
		},
		{
			"id": "collect",
			"text": "Hol dir einen leuchtenden Kristall auf den Inseln!",
			"target": func() -> Variant: return game.hud,
			"done": _collected.bind(game),
		},
	]
	var options := {
		"outro": "Super! Jetzt erkunde die Wolkeninseln allein.",
		"replay_position": _replay_spot.bind(game),
	}
	var guide = GUIDE.attach(game, ID, steps, _active.bind(game), options)
	if guide == null:
		return null
	game.jump_action.hold_changed.connect(
		func(held: bool) -> void: guide.note("jump" if held else "jump_up")
	)
	return guide


static func _active(game: Node) -> bool:
	return (
		not bool(game.paused)
		and not bool(game.finished)
		and not bool(game.question_open)
		and not game.modal.visible
	)


static func _collected(guide, game: Node) -> bool:
	return guide.since_step("found", float(game.collected.size())) >= 1.0


static func _walked(guide, game: Node) -> bool:
	var axis: Vector2 = game.touch_direction
	axis += Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	return guide.held(axis.length() > 0.4, 0.5)


## Rechts unter der Kopfzeile.
static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var below: float = maxf(game.objective.get_global_rect().end.y, game.message.get_global_rect().end.y)
	return Vector2(view.end.x - size.x - 16.0, below + 12.0)
