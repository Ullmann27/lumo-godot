extends RefCounted
## Erste Einführung für LUMO QUIZSHOW – während eine Frage offen ist.
## Schritte: Antwort antippen, aufdecken, nächste Frage, einen Joker probieren.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "quiz"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "answer",
			"text": "Lies die Frage und tippe auf eine Antwort.",
			"target": func() -> Variant: return _answer_button(game),
			"done": func(_guide) -> bool: return game._state.get("selected") != null,
		},
		{
			"id": "reveal",
			"text": "Sicher? Dann tippe auf „Antwort aufdecken“.",
			"target": func() -> Variant: return game.reveal_button,
			"done": func(_guide) -> bool: return bool(game._state.get("revealed", false)),
		},
		{
			"id": "next",
			"text": "Weiter geht's: tippe auf „Nächste Frage“.",
			"target": func() -> Variant: return game.next_button,
			"done": _next_done.bind(game),
		},
		{
			"id": "joker",
			"text": "Schwierige Frage? Ein Joker hilft dir – probier einen aus!",
			"target": func() -> Variant: return _joker_button(game),
			"done": _joker_done.bind(game),
			"skip": func() -> bool: return _used(game) >= 3.0,
		},
	]
	var options := {
		"outro": "Toll! Jetzt beantwortest du die Fragen allein.",
		"replay_position": _replay_spot.bind(game),
		"bubble_position": _bubble_top.bind(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	var state: Dictionary = game._state
	return (
		bool(game._authority_ready)
		and not state.is_empty()
		and not bool(state.get("paused", true))
		and not bool(state.get("gameOver", false))
		and not bool(state.get("exit", false))
	)


static func _next_done(guide, game: Node) -> bool:
	var number: float = float(game._state.get("number", 1))
	return guide.since_step("number", number) >= 1.0


static func _used(game: Node) -> float:
	return float(game._state.get("usedJokers", []).size())


static func _joker_done(guide, game: Node) -> bool:
	return guide.since_step("jokers", _used(game)) >= 1.0


static func _answer_button(game: Node) -> Variant:
	for button: Control in game.answer_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			return button
	return null


static func _joker_button(game: Node) -> Variant:
	for button: Control in game.joker_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			return button
	return null


## Rechts unter der Statuszeile, im freien Bereich unter Antworten und Jokern.
static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var line: Rect2 = game.status.get_global_rect()
	return Vector2(line.end.x - size.x, line.end.y + 16.0)


## Unter der Statuszeile: Frage, Antworten und Joker bleiben lesbar.
static func _bubble_top(_size: Vector2, game: Node) -> float:
	return game.status.get_global_rect().end.y + 24.0
