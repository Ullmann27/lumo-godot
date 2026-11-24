extends RefCounted
## Erste Einführung für LUMO MEMORY – nur wenn das Kind am Zug ist.
## Schritte: eine Karte aufdecken, eine zweite aufdecken, ein Paar finden.

const GUIDE = preload("res://scripts/systems/first_run_guide.gd")
const ID := "memory"


static func attach(game: Node) -> CanvasLayer:
	var steps: Array = [
		{
			"id": "first_card",
			"text": "Tippe auf eine Karte – sie dreht sich um.",
			"target": _hidden_card.bind(game),
			"done": func(guide) -> bool: return guide.since_step("open", _open_count(game)) >= 1.0,
		},
		{
			"id": "second_card",
			"text": "Tippe noch eine Karte. Ist es das gleiche Bild?",
			"target": _hidden_card.bind(game),
			"done": _second_done.bind(game),
		},
		{
			"id": "pair",
			"text": "Merk dir die Bilder und finde ein Paar!",
			"target": func() -> Variant: return game.scores,
			"done": _pair_done.bind(game),
		},
	]
	var options := {
		"outro": "Ein Paar! Jetzt spielst du allein gegen Lumo.",
		"replay_position": _replay_spot.bind(game),
		"bubble_position": _bubble_top.bind(game),
	}
	return GUIDE.attach(game, ID, steps, _active.bind(game), options)


static func _active(game: Node) -> bool:
	var state: Dictionary = game._state
	return (
		not state.is_empty()
		and str(state.get("turn", "")) == "kind"
		and not bool(state.get("paused", true))
		and not bool(state.get("complete", false))
		and not game.overlay.visible
	)


static func _open_count(game: Node) -> float:
	var count := 0
	for card: Dictionary in game._state.get("cards", []):
		if bool(card.faceUp) and not bool(card.matched):
			count += 1
	return float(count)


static func _second_done(guide, game: Node) -> bool:
	var pairs: float = guide.since_step("pairs", float(game._state.get("kindPairs", 0)))
	var moves: float = guide.since_step("moves", float(game._state.get("kindMoves", 0)))
	return _open_count(game) >= 2.0 or pairs >= 1.0 or moves >= 1.0


static func _pair_done(guide, game: Node) -> bool:
	return guide.since_step("pairs", float(game._state.get("kindPairs", 0))) >= 1.0


## Erste sichtbare, noch verdeckte Karte.
static func _hidden_card(game: Node) -> Variant:
	var cards: Array = game._state.get("cards", [])
	for index in range(mini(cards.size(), game._cards.size())):
		var button: Control = game._cards[index].button
		if not bool(cards[index].faceUp) and button.is_visible_in_tree():
			return button
	return null


## Über der Fußleiste: die Karten auf dem Tisch bleiben frei.
static func _bubble_top(size: Vector2, game: Node) -> float:
	return game.footer.get_global_rect().position.y - size.y - 10.0


## Rechts unter der Kopfleiste.
static func _replay_spot(size: Vector2, game: Node) -> Vector2:
	var header: Rect2 = game.header.get_global_rect()
	return Vector2(header.end.x - size.x, header.end.y + 12.0)
