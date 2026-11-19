extends RefCounted
## Erste Einführung für LUMO RHYTHM PARTY – während ein Lied läuft.
## Schritte: eine Note treffen, drei hintereinander treffen, Pause finden.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "rhythm"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "hit",
			"text": "Kommt ein Licht unten an? Tippe genau dann auf seine Taste!",
			"target": func() -> Variant: return _next_lane(game),
			"done":
			func(guide) -> bool: return guide.since_step("hits", float(game.model.hits)) >= 1.0,
		},
		{
			"id": "combo",
			"text": "Super! Jetzt triff drei Lichter hintereinander.",
			"target": func() -> Variant: return _next_lane(game),
			"done": func(_guide) -> bool: return int(game.model.combo) >= 3,
		},
		{
			"id": "pause",
			"text": "Brauchst du eine Pause? Tippe auf Ⅱ – das Lied wartet auf dich.",
			"target": func() -> Variant: return game.pause_button,
			"done": func(_guide) -> bool: return bool(game.paused),
		},
	]
	var options := {
		"outro": "Toll im Takt! Jetzt spielst du das Lied allein.",
		"replay_position": _replay_spot.bind(game),
		"bubble_position": func(_size: Vector2) -> float: return _bubble_top(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	return (
		bool(game.running)
		and not bool(game.paused)
		and not bool(game.finished)
		and not game.menu.visible
		and float(game.resume_countdown) <= 0.0
	)


## Taste der nächsten noch offenen Note.
static func _next_lane(game: Node) -> Variant:
	var best_time := INF
	var lane := -1
	for note: Dictionary in game.model.notes:
		if int(note.state) == 0 and float(note.time) < best_time:
			best_time = float(note.time)
			lane = int(note.lane)
	if lane < 0:
		return null
	return game.lane_buttons[lane]


## Unter der Rückmeldezeile oben; Notenbahn und Tasten bleiben frei.
static func _bubble_top(game: Node) -> float:
	return game.feedback.get_global_rect().end.y + 10.0


static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	return Vector2(view.end.x - size.x - 16.0, _bubble_top(game))
