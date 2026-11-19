extends RefCounted
## Erste Einführung für LUMO SCHATZSUCHE – beim Erkunden (nicht in Fenstern).
## Schritte: mit dem Stick laufen, Hinweis lesen, am Stern ANSEHEN und das Rätsel lösen.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "treasure"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "walk",
			"text": "Lauf mit dem Stick los – folge dem goldenen Stern!",
			"target": func() -> Variant: return game.joystick,
			"done": _walked.bind(game),
		},
		{
			"id": "clue",
			"text": "Tippe auf „Hinweis“ – dann weißt du, wohin.",
			"target": func() -> Variant: return game.clue_button,
			"done": func(_guide) -> bool: return game.modal.visible,
			# Im Hochformat steht der Hinweis schon offen im Hinweisfeld.
			"skip": func() -> bool: return not game.clue_button.is_visible_in_tree(),
		},
		{
			"id": "solve",
			"text": "Beim Stern: tippe auf ANSEHEN und löse das Rätsel.",
			"target": func() -> Variant: return game.action,
			"done": _solved.bind(game),
			"skip": func() -> bool: return bool(game.model.completed),
		},
	]
	var options := {
		"outro": "Gefunden! Jetzt suchst du die anderen Schätze allein.",
		"replay_position": _replay_spot.bind(game),
		"bubble_position": func(_size: Vector2) -> float: return _bubble_top(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	return not bool(game.paused) and not game.modal.visible and not bool(game.model.completed)


static func _walked(guide, game: Node) -> bool:
	var axis: Vector2 = game.joystick.axis
	axis += Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	return guide.held(axis.length() > 0.4, 0.6)


static func _solved(guide, game: Node) -> bool:
	return guide.since_step("found", float(game.model.found.size())) >= 1.0


## Unter der Kopfleiste und dem Hinweisfeld; Stick und Knöpfe unten bleiben frei.
static func _bubble_top(game: Node) -> float:
	var below: float = game.top.get_global_rect().end.y
	if is_instance_valid(game.clue_panel) and game.clue_panel.is_visible_in_tree():
		below = maxf(below, game.clue_panel.get_global_rect().end.y)
	return below + 10.0


## Links neben der Schatzkarte oben (Stick, Springen und ANSEHEN bleiben frei).
static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var below: float = game.top.get_global_rect().end.y + 12.0
	if is_instance_valid(game.hunt_map) and game.hunt_map.is_visible_in_tree():
		var map: Rect2 = game.hunt_map.get_global_rect()
		return Vector2(map.position.x - size.x - 12.0, map.position.y)
	return Vector2(view.end.x - size.x - 14.0, below)
