extends "res://scripts/games/cards/rules/cards_rules.gd"
## Lumo-Quartett – Sammelspiel mit Fragen.
##
## Vier Karten mit demselben Wert bilden ein Quartett. Wer dran ist, fragt einen
## Mitspieler nach einem Wert, von dem er selbst mindestens eine Karte hält.
## Hat der Gefragte solche Karten, gibt er alle ab und der Frager darf weiter
## fragen. Sonst ist es ein Fehlgriff: Der Frager zieht eine Karte vom Stapel.
## Zieht er dabei genau den gefragten Wert, darf er noch einmal. Ein volles
## Quartett wird sofort abgelegt. Wer die meisten Quartette hat, gewinnt.

const SETUP := {
	2: {"ranks": [1, 2, 3, 4, 5, 11, 12, 13], "hand": 7},
	3: {"ranks": [1, 2, 3, 4, 5, 6, 11, 12, 13], "hand": 6},
	4: {"ranks": [1, 2, 3, 4, 5, 6, 7, 11, 12, 13], "hand": 5},
}
const LOG_LIMIT := 400


func game_id() -> String:
	return "quartett"


func title() -> String:
	return "Lumo-Quartett"


func rules_text() -> Array[String]:
	return [
		"Vier Karten mit demselben Wert sind ein Quartett. Sammle so viele Quartette wie möglich.",
		"Wenn du dran bist: Tippe eine deiner Karten an und dann den Mitspieler, den du fragen willst.",
		"Hat er Karten mit diesem Wert, bekommst du alle und darfst gleich noch einmal fragen.",
		"Hat er keine, ist es ein Fehlgriff: Du ziehst eine Karte vom Stapel.",
		"Ziehst du dabei genau den gefragten Wert, darfst du noch einmal fragen.",
		"Ein volles Quartett wird sofort abgelegt und zählt 1 Punkt.",
	]


func ranks_in_play() -> Array:
	return s.r.ranks.duplicate()


func _deal() -> void:
	var setup: Dictionary = SETUP[players()]
	var all_suits: Array = range(DECK.SUIT_COUNT)
	var deck := _shuffle(DECK.build(all_suits, setup.ranks))
	var each := int(setup.hand)
	var hands: Array = []
	var sets: Array = []
	for p in range(players()):
		var hand: Array = deck.slice(p * each, (p + 1) * each)
		hand.sort()
		hands.append(hand)
		sets.append([])
	s.r = {
		"hands": hands,
		"stock": deck.slice(players() * each),
		"sets": sets,
		"ranks": setup.ranks.duplicate(),
		"turn": _starter(),
		"log": [],
	}
	# Schon beim Austeilen kann ein Quartett entstehen.
	for p in range(players()):
		_collect_sets(p, [])
	_settle_turn([])


static func count_rank(hand: Array, value: int) -> int:
	var count := 0
	for card: int in hand:
		if DECK.rank(card) == value:
			count += 1
	return count


static func ranks_of(hand: Array) -> Array:
	var seen: Array = []
	for card: int in hand:
		var value := DECK.rank(card)
		if not seen.has(value):
			seen.append(value)
	seen.sort()
	return seen


func sets_total() -> int:
	var total := 0
	for own: Array in s.r.sets:
		total += own.size()
	return total


func legal_moves(player: int) -> Array:
	var moves: Array = []
	if phase() != "playing" or player != current():
		return moves
	var hand: Array = s.r.hands[player]
	for value: int in ranks_of(hand):
		for q in range(players()):
			if q != player and not s.r.hands[q].is_empty():
				moves.append({"ask": value, "from": q})
	if moves.is_empty() and not s.r.stock.is_empty():
		moves.append({"draw": 1})
	return moves


func explain(player: int, move: Dictionary) -> String:
	if phase() != "playing":
		return "Die Runde ist zu Ende."
	if player != current():
		return "Du bist noch nicht dran."
	if move.has("draw"):
		return "Du kannst noch jemanden fragen."
	var value := int(move.get("ask", 0))
	var target := int(move.get("from", -1))
	if count_rank(s.r.hands[player], value) == 0:
		return "Du darfst nur nach einem Wert fragen, den du selbst auf der Hand hast."
	if target == player:
		return "Frag einen Mitspieler, nicht dich selbst."
	if target < 0 or target >= players():
		return "Diesen Mitspieler gibt es nicht."
	if s.r.hands[target].is_empty():
		return "Dieser Mitspieler hat gerade keine Karten."
	return "Das geht gerade nicht."


func _log(entry: Dictionary) -> void:
	s.r.log.append(entry)
	if s.r.log.size() > LOG_LIMIT:
		s.r.log.pop_front()


func _collect_sets(player: int, events: Array) -> void:
	var hand: Array = s.r.hands[player]
	for value: int in ranks_of(hand):
		if count_rank(hand, value) < DECK.SUIT_COUNT:
			continue
		var cards: Array = []
		for card: int in hand.duplicate():
			if DECK.rank(card) == value:
				cards.append(card)
				hand.erase(card)
		s.r.sets[player].append(value)
		_log({"t": "set", "p": player, "rank": value})
		events.append({"t": "set", "p": player, "rank": value, "cards": cards})


## Wer keine Karten hat, zieht nach oder setzt aus. Endet die Runde, wird gewertet.
func _settle_turn(events: Array) -> void:
	if sets_total() == s.r.ranks.size():
		events.append(_score_round())
		return
	for step in range(players() + 1):
		var player := int(s.r.turn)
		if not s.r.hands[player].is_empty():
			return
		if not s.r.stock.is_empty():
			var card: int = s.r.stock.pop_front()
			s.r.hands[player].append(card)
			_log({"t": "refill", "p": player})
			events.append({"t": "refill", "p": player, "card": card})
			return
		events.append({"t": "skip", "p": player})
		s.r.turn = (player + 1) % players()


func _apply(player: int, move: Dictionary) -> Array:
	var events: Array = []
	if move.has("draw"):
		var drawn: int = s.r.stock.pop_front()
		s.r.hands[player].append(drawn)
		s.r.hands[player].sort()
		_log({"t": "draw", "p": player, "rank": 0, "lucky": 0})
		events.append({"t": "draw", "p": player, "card": drawn, "lucky": false, "rank": 0})
		_collect_sets(player, events)
		s.r.turn = (player + 1) % players()
		_settle_turn(events)
		return events
	var value := int(move.ask)
	var target := int(move.from)
	var given: Array = []
	for card: int in s.r.hands[target].duplicate():
		if DECK.rank(card) == value:
			given.append(card)
			s.r.hands[target].erase(card)
	events.append({"t": "ask", "p": player, "from": target, "rank": value})
	if not given.is_empty():
		s.r.hands[player].append_array(given)
		s.r.hands[player].sort()
		_log({"t": "give", "p": player, "from": target, "rank": value, "n": given.size()})
		events.append({"t": "give", "p": player, "from": target, "rank": value, "cards": given})
		_collect_sets(player, events)
		_settle_turn(events)
		return events
	_log({"t": "miss", "p": player, "from": target, "rank": value})
	events.append({"t": "miss", "p": player, "from": target, "rank": value})
	var again := false
	if not s.r.stock.is_empty():
		var drawn: int = s.r.stock.pop_front()
		s.r.hands[player].append(drawn)
		s.r.hands[player].sort()
		again = DECK.rank(drawn) == value
		_log({"t": "draw", "p": player, "rank": value, "lucky": 1 if again else 0})
		events.append({"t": "draw", "p": player, "card": drawn, "lucky": again, "rank": value})
		_collect_sets(player, events)
	if not again:
		s.r.turn = (player + 1) % players()
	_settle_turn(events)
	return events


func _score_round() -> Dictionary:
	var points: Array = []
	for own: Array in s.r.sets:
		points.append(own.size())
	return _finish_round(points, {"sets": s.r.sets.duplicate(true)})


func view(player: int) -> Dictionary:
	var result := _base_view(player)
	result.merge({
		"ranks": s.r.ranks.duplicate(),
		"sets": s.r.sets.duplicate(true),
		"stock_size": s.r.stock.size(),
		"log": s.r.log.duplicate(true),
	})
	return result


func check() -> String:
	var r: Dictionary = s.r
	for key: String in ["hands", "stock", "sets", "ranks", "turn", "log"]:
		if not r.has(key):
			return "Feld fehlt: " + key
	if r.hands.size() != players() or r.sets.size() != players():
		return "Spielerzahl passt nicht"
	var piles: Array = [r.stock]
	for hand: Array in r.hands:
		piles.append(hand)
	var laid: Array = []
	var seen: Dictionary = {}
	for own: Array in r.sets:
		for value: int in own:
			if seen.has(value) or not r.ranks.has(value):
				return "Quartett doppelt oder fremd"
			seen[value] = true
			for suit in range(DECK.SUIT_COUNT):
				laid.append(DECK.card(suit, value))
	piles.append(laid)
	var all_suits: Array = range(DECK.SUIT_COUNT)
	var problem := _conserved(piles, DECK.build(all_suits, r.ranks))
	if not problem.is_empty():
		return problem
	for hand: Array in r.hands:
		for value: int in ranks_of(hand):
			if count_rank(hand, value) >= DECK.SUIT_COUNT:
				return "Volles Quartett liegt noch auf der Hand"
	if int(r.turn) < 0 or int(r.turn) >= players():
		return "Zug außerhalb der Runde"
	if phase() == "playing" and r.hands[int(r.turn)].is_empty():
		return "Spieler am Zug hat keine Karten"
	return ""
