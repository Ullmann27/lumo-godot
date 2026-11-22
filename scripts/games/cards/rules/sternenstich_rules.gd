extends "res://scripts/games/cards/rules/cards_rules.gd"
## Sternenstich – einfaches Stichspiel.
##
## Jeder bekommt sieben Karten. Die nächste Karte vom Stapel zeigt die
## Trumpffarbe. Wer ausspielt, legt eine beliebige Karte. Alle anderen müssen
## die ausgespielte Farbe bedienen, wenn sie können. Den Stich gewinnt der
## höchste Trumpf, sonst die höchste Karte der ausgespielten Farbe. Wer den
## Stich gewinnt, spielt als Nächstes aus. Jeder Stich zählt einen Punkt, die
## meisten Stiche bringen zwei Punkte dazu.

const HAND_SIZE := 7
const WIN_BONUS := 2


func game_id() -> String:
	return "stich"


func title() -> String:
	return "Sternenstich"


func rules_text() -> Array[String]:
	return [
		"Jeder bekommt 7 Karten. Die aufgedeckte Karte zeigt die Trumpffarbe.",
		"Wer ausspielt, legt eine beliebige Karte in die Mitte.",
		"Alle anderen müssen dieselbe Farbe legen, wenn sie eine haben.",
		"Die höchste Karte der ausgespielten Farbe gewinnt den Stich. Trumpf schlägt alle anderen Farben.",
		"Lumo (13) ist die höchste Karte, dann Eule (12) und Nova (11).",
		"Jeder Stich zählt 1 Punkt. Wer die meisten Stiche hat, gewinnt die Runde und bekommt 2 Punkte dazu.",
	]


func _deal() -> void:
	var all_suits: Array = range(DECK.SUIT_COUNT)
	var all_ranks: Array = range(1, DECK.RANK_COUNT + 1)
	var deck := _shuffle(DECK.build(all_suits, all_ranks))
	var hands: Array = []
	var tricks: Array = []
	var void_suits: Array = []
	for p in range(players()):
		var hand: Array = deck.slice(p * HAND_SIZE, (p + 1) * HAND_SIZE)
		hand.sort()
		hands.append(hand)
		tricks.append(0)
		void_suits.append([])
	var stock: Array = deck.slice(players() * HAND_SIZE)
	var trump_card: int = stock[0]
	s.r = {
		"hands": hands,
		"stock": stock,
		"trump_card": trump_card,
		"trump": DECK.suit(trump_card),
		"leader": _starter(),
		"turn": _starter(),
		"trick": [],
		"tricks": tricks,
		"played": [],
		"trick_no": 0,
		"last_winner": -1,
		"void": void_suits,
	}


func lead_suit() -> int:
	return DECK.suit(int(s.r.trick[0].c)) if not s.r.trick.is_empty() else -1


func legal_moves(player: int) -> Array:
	var moves: Array = []
	if phase() != "playing" or player != current():
		return moves
	var hand: Array = s.r.hands[player]
	var lead := lead_suit()
	var follows: Array = []
	for card: int in hand:
		if DECK.suit(card) == lead:
			follows.append(card)
	for card: int in (follows if not follows.is_empty() else hand):
		moves.append({"card": card})
	return moves


func explain(player: int, move: Dictionary) -> String:
	if phase() != "playing":
		return "Die Runde ist zu Ende."
	if player != current():
		return "Du bist noch nicht dran."
	var card := int(move.get("card", -1))
	if not s.r.hands[player].has(card):
		return "Diese Karte hast du nicht."
	var lead := lead_suit()
	if lead >= 0 and DECK.suit(card) != lead:
		return "Du musst %s bedienen." % DECK.SUIT_NAMES[lead]
	return "Das geht gerade nicht."


## Stärke einer Karte im laufenden Stich: Trumpf über Farbe über Abwurf.
static func strength(card: int, lead: int, trump: int) -> int:
	var card_suit := DECK.suit(card)
	if card_suit == trump:
		return 200 + DECK.rank(card)
	if card_suit == lead:
		return 100 + DECK.rank(card)
	return 0


## Wer gewinnt diese (vollständige oder halbe) Kartenfolge?
static func winner_of(trick: Array, trump: int) -> int:
	var lead := DECK.suit(int(trick[0].c))
	var best := 0
	for i in range(1, trick.size()):
		if strength(int(trick[i].c), lead, trump) > strength(int(trick[best].c), lead, trump):
			best = i
	return int(trick[best].p)


func _trick_winner(trick: Array) -> int:
	return winner_of(trick, int(s.r.trump))


func _apply(player: int, move: Dictionary) -> Array:
	var card := int(move.card)
	var lead := lead_suit()
	if lead >= 0 and DECK.suit(card) != lead and not s.r.void[player].has(lead):
		# Für alle sichtbar: Dieser Spieler konnte die Farbe nicht bedienen.
		s.r.void[player].append(lead)
	s.r.hands[player].erase(card)
	s.r.trick.append({"p": player, "c": card})
	var events: Array = [{"t": "play", "p": player, "card": card}]
	if s.r.trick.size() < players():
		s.r.turn = (player + 1) % players()
		return events
	var winner := _trick_winner(s.r.trick)
	var winning_card: int = int(s.r.trick[(winner - int(s.r.leader) + players()) % players()].c)
	var cards: Array = []
	for entry: Dictionary in s.r.trick:
		cards.append(int(entry.c))
		s.r.played.append(int(entry.c))
	s.r.tricks[winner] = int(s.r.tricks[winner]) + 1
	s.r.trick = []
	s.r.trick_no = int(s.r.trick_no) + 1
	s.r.leader = winner
	s.r.turn = winner
	s.r.last_winner = winner
	events.append({"t": "trick", "winner": winner, "best": winning_card, "cards": cards, "tricks": s.r.tricks.duplicate()})
	if s.r.hands[winner].is_empty():
		events.append(_score_round())
	return events


func _score_round() -> Dictionary:
	var most := 0
	for count: int in s.r.tricks:
		most = maxi(most, count)
	var points: Array = []
	for p in range(players()):
		var count := int(s.r.tricks[p])
		points.append(count + (WIN_BONUS if count == most else 0))
	return _finish_round(points, {"tricks": s.r.tricks.duplicate()})


func view(player: int) -> Dictionary:
	var result := _base_view(player)
	var trick: Array = []
	for entry: Dictionary in s.r.trick:
		trick.append({"p": int(entry.p), "c": int(entry.c)})
	result.merge({
		"trump": int(s.r.trump),
		"trump_card": int(s.r.trump_card),
		"leader": int(s.r.leader),
		"trick": trick,
		"tricks": s.r.tricks.duplicate(),
		"played": s.r.played.duplicate(),
		"stock_size": s.r.stock.size(),
		"hand_size": HAND_SIZE,
		"void": s.r.void.duplicate(true),
	})
	return result


func check() -> String:
	var r: Dictionary = s.r
	for key: String in ["hands", "stock", "trump_card", "trump", "leader", "turn", "trick", "tricks", "played", "trick_no", "void"]:
		if not r.has(key):
			return "Feld fehlt: " + key
	if r.hands.size() != players() or r.tricks.size() != players() or r.void.size() != players():
		return "Spielerzahl passt nicht"
	var piles: Array = [r.stock, r.played]
	for hand: Array in r.hands:
		piles.append(hand)
	var on_table: Array = []
	for entry: Variant in r.trick:
		if not entry is Dictionary or not entry.has("p") or not entry.has("c"):
			return "Stich beschädigt"
		on_table.append(entry.c)
	piles.append(on_table)
	var all_suits: Array = range(DECK.SUIT_COUNT)
	var all_ranks: Array = range(1, DECK.RANK_COUNT + 1)
	var problem := _conserved(piles, DECK.build(all_suits, all_ranks))
	if not problem.is_empty():
		return problem
	if r.stock.is_empty() or int(r.stock[0]) != int(r.trump_card) or DECK.suit(int(r.trump_card)) != int(r.trump):
		return "Trumpf passt nicht zum Stapel"
	var total := 0
	for count: int in r.tricks:
		total += count
	if total != int(r.trick_no) or r.played.size() != total * players():
		return "Stichzahl passt nicht"
	if int(r.turn) < 0 or int(r.turn) >= players() or r.trick.size() >= players():
		return "Zug außerhalb der Runde"
	for p in range(players()):
		for suit: int in r.void[p]:
			for card: int in r.hands[p]:
				if DECK.suit(card) == suit:
					return "Spieler %d hat eine Farbe, die er nicht bedienen konnte" % p
		var expected := HAND_SIZE - total
		for entry: Dictionary in r.trick:
			if int(entry.p) == p:
				expected -= 1
		if r.hands[p].size() != expected:
			return "Handgröße von Spieler %d stimmt nicht" % p
	return ""
