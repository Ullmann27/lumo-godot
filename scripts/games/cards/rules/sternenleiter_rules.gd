extends "res://scripts/games/cards/rules/cards_rules.gd"
## Sternenleiter – Anlegespiel mit Zahlenreihen.
##
## Gespielt wird mit den Werten 1 bis 9 und so vielen Farben wie Spielern
## (mindestens zwei). Jeder bekommt neun Karten. Jede Farbe bildet eine Leiter:
## Sie beginnt mit der 5 in der Mitte und wächst Karte für Karte nach unten bis
## zur 1 und nach oben bis zur 9. Wer anlegen kann, muss anlegen. Wer nicht
## kann, setzt aus. Wer zuerst alle Karten los ist, gewinnt die Runde.

const CENTER := 5
const LOW := 1
const HIGH := 9
const PLACE_POINTS := [3, 2, 1, 0]


func game_id() -> String:
	return "leiter"


func title() -> String:
	return "Sternenleiter"


func rules_text() -> Array[String]:
	return [
		"Gespielt wird mit den Zahlen 1 bis 9. Jeder bekommt 9 Karten.",
		"Jede Farbe bekommt eine eigene Leiter. Sie beginnt immer mit der 5.",
		"An eine Leiter passt nur die Nachbarzahl: unten die nächstkleinere, oben die nächstgrößere.",
		"Wer eine passende Karte hat, muss eine legen. Wer keine hat, setzt aus.",
		"Wer zuerst alle Karten los ist, gewinnt die Runde.",
		"Punkte: 3 für den ersten Platz, dann 2, 1 und 0 – je weniger Karten übrig sind, desto besser.",
	]


func suits_in_play() -> Array:
	return s.r.suits.duplicate()


func _deal() -> void:
	var suits: Array = range(maxi(2, players()))
	var deck := _shuffle(DECK.build(suits, range(LOW, HIGH + 1)))
	@warning_ignore("integer_division")
	var each: int = deck.size() / players()
	var hands: Array = []
	for p in range(players()):
		var hand: Array = deck.slice(p * each, (p + 1) * each)
		hand.sort()
		hands.append(hand)
	var low: Array = []
	var high: Array = []
	for i in range(DECK.SUIT_COUNT):
		low.append(0)
		high.append(0)
	s.r = {
		"hands": hands,
		"suits": suits,
		"low": low,
		"high": high,
		"turn": _starter(),
		"passes": 0,
		"laid": [],
	}


## Passt diese Karte jetzt an ihre Leiter?
func fits(card: int) -> bool:
	var suit := DECK.suit(card)
	var value := DECK.rank(card)
	if not s.r.suits.has(suit):
		return false
	if int(s.r.low[suit]) == 0:
		return value == CENTER
	return value == int(s.r.low[suit]) - 1 or value == int(s.r.high[suit]) + 1


func legal_moves(player: int) -> Array:
	var moves: Array = []
	if phase() != "playing" or player != current():
		return moves
	for card: int in s.r.hands[player]:
		if fits(card):
			moves.append({"card": card})
	if moves.is_empty():
		moves.append({"pass": 1})
	return moves


func explain(player: int, move: Dictionary) -> String:
	if phase() != "playing":
		return "Die Runde ist zu Ende."
	if player != current():
		return "Du bist noch nicht dran."
	if move.has("pass"):
		return "Du hast eine passende Karte. Die musst du legen."
	var card := int(move.get("card", -1))
	if not s.r.hands[player].has(card):
		return "Diese Karte hast du nicht."
	var suit := DECK.suit(card)
	var name: String = DECK.SUIT_NAMES[suit]
	if int(s.r.low[suit]) == 0:
		return "Die %s-Leiter beginnt mit der 5." % name
	var wanted: Array[String] = []
	if int(s.r.low[suit]) > LOW:
		wanted.append(str(int(s.r.low[suit]) - 1))
	if int(s.r.high[suit]) < HIGH:
		wanted.append(str(int(s.r.high[suit]) + 1))
	if wanted.is_empty():
		return "Die %s-Leiter ist fertig." % name
	return "An die %s-Leiter passt jetzt nur die %s." % [name, " oder die ".join(wanted)]


func _apply(player: int, move: Dictionary) -> Array:
	var events: Array = []
	if move.has("pass"):
		s.r.passes = int(s.r.passes) + 1
		events.append({"t": "pass", "p": player})
		s.r.turn = (player + 1) % players()
		return events
	var card := int(move.card)
	var suit := DECK.suit(card)
	var value := DECK.rank(card)
	s.r.hands[player].erase(card)
	s.r.laid.append(card)
	s.r.passes = 0
	if int(s.r.low[suit]) == 0:
		s.r.low[suit] = value
		s.r.high[suit] = value
	elif value < int(s.r.low[suit]):
		s.r.low[suit] = value
	else:
		s.r.high[suit] = value
	events.append({"t": "lay", "p": player, "card": card, "left": s.r.hands[player].size()})
	if s.r.hands[player].is_empty():
		events.append(_score_round(player))
	else:
		s.r.turn = (player + 1) % players()
	return events


func _score_round(finisher: int) -> Dictionary:
	var left: Array = []
	for hand: Array in s.r.hands:
		left.append(hand.size())
	var points: Array = []
	for p in range(players()):
		var place := 0
		for q in range(players()):
			if int(left[q]) < int(left[p]):
				place += 1
		points.append(int(PLACE_POINTS[place]))
	return _finish_round(points, {"left": left, "finisher": finisher})


func view(player: int) -> Dictionary:
	var result := _base_view(player)
	result.merge({
		"suits": s.r.suits.duplicate(),
		"low": s.r.low.duplicate(),
		"high": s.r.high.duplicate(),
		"laid": s.r.laid.duplicate(),
		"center": CENTER,
		"rank_low": LOW,
		"rank_high": HIGH,
	})
	return result


func check() -> String:
	var r: Dictionary = s.r
	for key: String in ["hands", "suits", "low", "high", "turn", "passes", "laid"]:
		if not r.has(key):
			return "Feld fehlt: " + key
	if r.hands.size() != players() or r.low.size() != DECK.SUIT_COUNT or r.high.size() != DECK.SUIT_COUNT:
		return "Spielerzahl passt nicht"
	if r.suits.size() != maxi(2, players()):
		return "Farbenzahl passt nicht"
	var piles: Array = [r.laid]
	for hand: Array in r.hands:
		piles.append(hand)
	var problem := _conserved(piles, DECK.build(r.suits, range(LOW, HIGH + 1)))
	if not problem.is_empty():
		return problem
	var expected: Dictionary = {}
	for suit: int in r.suits:
		var low := int(r.low[suit])
		var high := int(r.high[suit])
		if low == 0 and high == 0:
			continue
		if low < LOW or high > HIGH or low > CENTER or high < CENTER:
			return "Leiter außerhalb der Reihe"
		for value in range(low, high + 1):
			expected[DECK.card(suit, value)] = true
	if expected.size() != r.laid.size():
		return "Leitern passen nicht zu den gelegten Karten"
	for card: int in r.laid:
		if not expected.has(card):
			return "Karte liegt nicht in einer lückenlosen Leiter"
	if int(r.turn) < 0 or int(r.turn) >= players():
		return "Zug außerhalb der Runde"
	return ""
