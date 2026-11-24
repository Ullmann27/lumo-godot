extends RefCounted
## Erste Einführung für LUMO LAUF – erscheint, sobald Lumo auf der Strecke läuft.
## Schritte: lenken, springen, flitzen, drei Sterne sammeln.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "run"
## lumo_run.gd: enum Phase { MENU, LOADING, COUNTDOWN, RUNNING, FINISHED }
const RUNNING := 3


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "steer",
			"text": "Lenke Lumo mit dem Stick nach links und rechts.",
			"target": func() -> Variant: return game.hud.stick,
			"done": _steer_done.bind(game),
		},
		{
			"id": "jump",
			"text": "Tippe auf SPRINGEN. Lange halten springt höher!",
			"target": func() -> Variant: return game.hud.jump_button,
			"done": func(guide) -> bool: return guide.seen("jump"),
		},
		{
			"id": "dash",
			"text": "Tippe auf FLITZEN – ein kurzer Sprint.",
			"target": func() -> Variant: return game.hud.dash_button,
			"done": func(guide) -> bool: return guide.seen("dash"),
		},
		{
			"id": "stars",
			"text": "Sammle drei Sterne!",
			"target": func() -> Variant: return _star_rect(game),
			"done": _stars_done.bind(game),
		},
	]
	var options := {
		"outro": "Super! Jetzt lauf los – Lumo zählt auf dich.",
		"replay_position": _replay_spot.bind(game),
	}
	var guide = GUIDE.attach(game, ID, steps, _active.bind(game), options)
	if guide == null:
		return null
	game.hud.jump_changed.connect(
		func(held: bool) -> void: guide.note("jump" if held else "jump_up")
	)
	game.hud.dash_pressed.connect(func() -> void: guide.note("dash"))
	return guide


static func _active(game: Node) -> bool:
	return (
		int(game.phase) == RUNNING
		and not bool(game.paused)
		and not bool(game.question_open)
		and is_instance_valid(game.hud)
	)


static func _steer_done(guide, game: Node) -> bool:
	var axis: float = float(game.touch_steer.x) + Input.get_axis("ui_left", "ui_right")
	return guide.held(absf(axis) > 0.35, 0.3)


static func _stars_done(guide, game: Node) -> bool:
	return (
		is_instance_valid(game.track) and guide.since_step("stars", float(game.track.kept)) >= 3.0
	)


## Sternzähler oben links in der Kopfleiste (siehe run_hud.gd _draw_top).
static func _star_rect(game: Node) -> Variant:
	var hud: Control = game.hud
	var u: float = float(hud._unit)
	var row: float = 52.0 * u
	var origin: Vector2 = hud.top.global_position
	return Rect2(origin + Vector2(row + 8.0 * u, 6.0 * u), Vector2(84.0 * u, row - 12.0 * u))


## Unter dem Pause-Knopf, weg von Stick und Sprungknöpfen.
static func _replay_spot(_size: Vector2, game: Node) -> Vector2:
	var pause: Control = game.hud.pause_button
	var rect: Rect2 = pause.get_global_rect()
	return Vector2(rect.position.x, rect.end.y + 70.0 * float(game.hud._unit))
