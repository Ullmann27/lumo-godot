extends RefCounted
## Erste Einführung für LUMOS STERNENPOST – erscheint, sobald Lumo in der Luft ist.
## Schritte: lenken, steigen, Schwung, drei Sternfunken sammeln.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "skypost"
## sky_post.gd: enum Phase { LOADING, MENU, COUNTDOWN, FLYING, FINISHED }
const FLYING := 3


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "steer",
			"text": "Zieh den Stick zur Seite – Lumo fliegt eine Kurve.",
			"target": func() -> Variant: return game.hud.stick,
			"done": _steer_done.bind(game),
		},
		{
			"id": "climb",
			"text": "Stick nach oben: Lumo steigt. Nach unten: Lumo sinkt.",
			"target": func() -> Variant: return game.hud.stick,
			"done": _climb_done.bind(game),
		},
		{
			"id": "boost",
			"text": "Tippe auf SCHWUNG – kurz schneller fliegen!",
			"target": func() -> Variant: return game.hud.boost_button,
			"done": func(guide) -> bool: return guide.seen("boost"),
		},
		{
			"id": "sparks",
			"text": "Flieg durch drei Sternfunken!",
			"target": func() -> Variant: return _star_rect(game),
			"done": _sparks_done.bind(game),
		},
	]
	var options := {
		"outro": "Super! Jetzt bist du ein echter Sternenpost-Flieger.",
		"replay_position": _replay_spot.bind(game),
	}
	var guide = GUIDE.attach(game, ID, steps, _active.bind(game), options)
	if guide == null:
		return null
	game.hud.boost_pressed.connect(func() -> void: guide.note("boost"))
	return guide


static func _active(game: Node) -> bool:
	return (
		int(game.phase) == FLYING
		and not bool(game.paused)
		and is_instance_valid(game.hud)
		and game.flight != null
		and float(game.flight.launch_left) <= 0.0
	)


static func _stick(game: Node) -> Vector2:
	var keys := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
	return Vector2(float(game.touch_steer.x), -float(game.touch_steer.y)) + keys


static func _steer_done(guide, game: Node) -> bool:
	return guide.held(absf(_stick(game).x) > 0.35, 0.4)


static func _climb_done(guide, game: Node) -> bool:
	return guide.held(absf(_stick(game).y) > 0.35, 0.4)


static func _sparks_done(guide, game: Node) -> bool:
	return guide.since_step("sparks", float(game.sparks_taken)) >= 3.0


## Sternzähler links in der Kopfleiste (siehe sky_post_hud.gd _draw_top).
static func _star_rect(game: Node) -> Variant:
	var hud: Control = game.hud
	var u: float = float(hud._unit)
	var origin: Vector2 = hud.top.global_position
	return Rect2(origin + Vector2(4.0 * u, 4.0 * u), Vector2(110.0 * u, 44.0 * u))


## Unter dem Pause-Knopf, weg von Stick und Knöpfen.
static func _replay_spot(_size: Vector2, game: Node) -> Vector2:
	var pause: Control = game.hud.pause_button
	var rect: Rect2 = pause.get_global_rect()
	return Vector2(rect.position.x, rect.end.y + 150.0 * float(game.hud._unit))
