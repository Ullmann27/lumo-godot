extends RefCounted
## Mitspieler-KI für die drei Lumo-Kartenspiele.
##
## Die KI sieht nur, was auch ein Kind an ihrem Platz sähe: die eigene Hand,
## den Tisch und den öffentlichen Verlauf (`view()` des Regelkerns). Fremde
## Hände und der verdeckte Stapel kommen hier nie an.
##
## Stärke 0 (leicht) spielt oft einfach irgendeine erlaubte Karte und merkt
## sich wenig. Stärke 1 (mittel) spielt nach einfachen Faustregeln. Stärke 2
## (schwer) zählt gespielte Karten mit und plant voraus.

const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const STICH = preload("res://scripts/games/cards/rules/sternenstich_rules.gd")
const LEVEL_NAMES: Array[String] = ["Leicht", "Mittel", "Schwer"]

var _rng := 1


## Wählt einen Zug. Gibt {"move": Zug, "rng": neuer Zufallszustand} zurück.
static func choose(view: Dictionary, legal: Array, level: int, rng: int) -> Dictionary:
	var ai := new()
	ai._rng = rng if rng != 0 else 1
	var move: Dictionary = legal[0] if not legal.is_empty() else {}
	if legal.size() > 1:
		match str(view.get("game", "")):
			"stich":
				move = ai._stich(view, legal, level)
			"leiter":
				move = ai._leiter(view, legal, level)
			"quartett":
				move = ai._quartett(view, legal, level)
	return {"move": move, "rng": ai._rng}


func _roll(bound: int) -> int:
	_rng = DECK.rng_next(_rng)
	return DECK.rng_pick(_rng, bound)


func _chance(percent: int) -> bool:
	return _roll(100) < percent


func _any(options: Array) -> Variant:
	return options[_roll(options.size())]


## Bester Eintrag nach Punktzahl; bei Gleichstand entscheidet der Zufall.
func _best(options: Array, values: Array) -> Variant:
	var top: float = -INF
	for value: float in values:
		top = maxf(top, value)
	var winners: Array = []
	for i in range(options.size()):
		if is_equal_approx(float(values[i]), top):
			winners.append(options[i])
	return _any(winners)


# ---------------------------------------------------------------- Sternenstich

## Gedachte Verteilungen je Zug von Schwer. Mehr ist genauer, aber langsamer.
static var stich_samples := 30


func _stich(view: Dictionary, legal: Array, level: int) -> Dictionary:
	var cards: Array = []
	for move: Dictionary in legal:
		cards.append(int(move.card))
	# Leicht greift meistens einfach zu, Mittel verschätzt sich manchmal.
	if (level <= 0 and _chance(65)) or (level == 1 and _chance(22)):
		return {"card": _any(cards)}
	var trump := int(view.trump)
	if level >= 2:
		return {"card": _stich_plan(view, cards, trump)}
	var trick: Array = []
	for entry: Dictionary in view.trick:
		trick.append(int(entry.c))
	return {"card": _stich_rule(cards, trick, int(view.players), trump)}


## Faustregel für Leicht und Mittel – und für die gedachten Mitspieler von Schwer.
## Ausspielen: höchste Farbkarte. Bedienen: als Letzter billig gewinnen, sonst
## nur mit hoher Karte gewinnen, sonst die kleinste Karte abwerfen.
func _stich_rule(hand: Array, trick: Array, seats: int, trump: int) -> int:
	if trick.is_empty():
		var lead_card := -1
		var lead_rank := -1
		var low_trump := -1
		for card: int in hand:
			var value: int = card % DECK.RANK_COUNT
			@warning_ignore("integer_division")
			if card / DECK.RANK_COUNT != trump:
				if value > lead_rank:
					lead_rank = value
					lead_card = card
			elif low_trump < 0 or value < low_trump % DECK.RANK_COUNT:
				low_trump = card
		return lead_card if lead_card >= 0 else low_trump
	@warning_ignore("integer_division")
	var lead: int = trick[0] / DECK.RANK_COUNT
	var best_now := 0
	for card: int in trick:
		best_now = maxi(best_now, STICH.strength(card, lead, trump))
	var win_low := -1
	var win_low_strength := 1000
	var win_high := -1
	var win_high_strength := -1
	var low := -1
	var low_cost := 1000
	for card: int in hand:
		var power := STICH.strength(card, lead, trump)
		if power > best_now:
			if power < win_low_strength:
				win_low_strength = power
				win_low = card
			if power > win_high_strength:
				win_high_strength = power
				win_high = card
		var cost: int = card % DECK.RANK_COUNT + (100 if power >= 200 else 0)
		if cost < low_cost:
			low_cost = cost
			low = card
	if win_low < 0:
		return low
	if trick.size() == seats - 1 or win_high_strength >= 200:
		return win_low
	if win_high % DECK.RANK_COUNT >= 9:
		return win_high
	return low


## Karten, die niemand am Tisch gesehen hat (ohne die eigene Hand).
func _unseen(view: Dictionary) -> Array:
	var seen: Dictionary = {int(view.trump_card): true}
	for card: int in view.hand:
		seen[card] = true
	for card: int in view.played:
		seen[card] = true
	for entry: Dictionary in view.trick:
		seen[int(entry.c)] = true
	var unseen: Array = []
	for card in range(DECK.SIZE):
		if not seen.has(card):
			unseen.append(card)
	return unseen


## Schwer: denkt sich mögliche Verteilungen der unbekannten Karten aus, spielt
## jede erlaubte Karte in Gedanken zu Ende und nimmt die mit den meisten
## eigenen Stichen. Bekannt ist dabei nur, was offen auf dem Tisch lag – auch,
## wer eine Farbe nicht mehr bedienen konnte.
func _stich_plan(view: Dictionary, cards: Array, trump: int) -> int:
	var me := int(view.me)
	var seats := int(view.players)
	var unseen := _unseen(view)
	var trick_players: Array = []
	var trick_cards: Array = []
	for entry: Dictionary in view.trick:
		trick_players.append(int(entry.p))
		trick_cards.append(int(entry.c))
	var legal_filter: Array = []
	for p in range(seats):
		legal_filter.append(view.void[p] if view.has("void") else [])
	var totals: Array = []
	for card: int in cards:
		totals.append(0.0)
	for sample in range(stich_samples):
		# Unbekannte Karten mischen und an die Mitspieler verteilen.
		for i in range(unseen.size() - 1, 0, -1):
			var j := _roll(i + 1)
			var held: int = unseen[i]
			unseen[i] = unseen[j]
			unseen[j] = held
		var world: Array = []
		var cursor := 0
		for p in range(seats):
			var hand: Array = []
			if p != me:
				var wanted := int(view.hand_sizes[p])
				var blank: Array = legal_filter[p]
				var scan := cursor
				while hand.size() < wanted and scan < unseen.size():
					@warning_ignore("integer_division")
					if not blank.has(unseen[scan] / DECK.RANK_COUNT):
						# Passende Karte nach vorn tauschen und vergeben.
						var take: int = unseen[scan]
						unseen[scan] = unseen[cursor]
						unseen[cursor] = take
						hand.append(take)
						cursor += 1
					scan += 1
				while hand.size() < wanted and cursor < unseen.size():
					hand.append(unseen[cursor])
					cursor += 1
			world.append(hand)
		for index in range(cards.size()):
			var hands: Array = []
			for p in range(seats):
				hands.append(world[p].duplicate())
			for card: int in view.hand:
				if card != int(cards[index]):
					hands[me].append(card)
			var players_now: Array = trick_players.duplicate()
			var cards_now: Array = trick_cards.duplicate()
			players_now.append(me)
			cards_now.append(int(cards[index]))
			totals[index] += _stich_rollout(hands, players_now, cards_now, (me + 1) % seats, trump, me, view.tricks)
	# Bei gleichem Ergebnis die billigere Karte behalten.
	for index in range(cards.size()):
		var card := int(cards[index])
		@warning_ignore("integer_division")
		totals[index] -= 0.004 * (card % DECK.RANK_COUNT + (13 if card / DECK.RANK_COUNT == trump else 0))
	return int(_best(cards, totals))


## Spielt eine gedachte Verteilung zu Ende. Ergebnis: eigene Punkte der Runde
## (Stiche plus Anteil am Bonus für die meisten Stiche).
func _stich_rollout(hands: Array, trick_players: Array, trick_cards: Array, turn: int, trump: int, me: int, taken: Array) -> float:
	var seats := hands.size()
	var counts: Array = taken.duplicate()
	while true:
		if trick_cards.size() == seats:
			@warning_ignore("integer_division")
			var lead: int = trick_cards[0] / DECK.RANK_COUNT
			var best := 0
			var best_power := -1
			for i in range(seats):
				var power := STICH.strength(trick_cards[i], lead, trump)
				if power > best_power:
					best_power = power
					best = i
			turn = trick_players[best]
			counts[turn] += 1
			trick_players.clear()
			trick_cards.clear()
			if hands[turn].is_empty():
				break
		var hand: Array = hands[turn]
		var options: Array = hand
		if not trick_cards.is_empty():
			@warning_ignore("integer_division")
			var lead_suit: int = trick_cards[0] / DECK.RANK_COUNT
			var follows: Array = []
			for card: int in hand:
				@warning_ignore("integer_division")
				if card / DECK.RANK_COUNT == lead_suit:
					follows.append(card)
			if not follows.is_empty():
				options = follows
		var choice := _stich_rule(options, trick_cards, seats, trump)
		hand.erase(choice)
		trick_players.append(turn)
		trick_cards.append(choice)
		turn = (turn + 1) % seats
	var most := 0
	var tied := 0
	for count: int in counts:
		if count > most:
			most = count
			tied = 1
		elif count == most:
			tied += 1
	var value := float(counts[me])
	if int(counts[me]) == most:
		value += float(STICH.WIN_BONUS) / tied
	return value


# --------------------------------------------------------------- Sternenleiter


func _leiter(view: Dictionary, legal: Array, level: int) -> Dictionary:
	if level <= 0 and _chance(80):
		return _any(legal)
	var hand: Array = view.hand
	var center := int(view.center)
	var low_end := int(view.rank_low)
	var high_end := int(view.rank_high)
	var values: Array = []
	for move: Dictionary in legal:
		var card := int(move.card)
		var suit := DECK.suit(card)
		var value := DECK.rank(card)
		var score := 0.0
		var directions: Array = [-1, 1] if value == center else [1 if value > center else -1]
		for direction: int in directions:
			var own_far := 0
			var own_count := 0
			var foreign := 0
			var end := low_end if direction < 0 else high_end
			var step := value + direction
			while (step >= end if direction < 0 else step <= end):
				if hand.has(DECK.card(suit, step)):
					own_count += 1
					own_far = absi(step - value)
				else:
					foreign += 1
				step += direction
			if own_count > 0:
				# Diese Leiter brauche ich selbst: je weiter meine Karte weg ist, desto dringender.
				score += 3.0 * own_far + own_count
				if hand.has(DECK.card(suit, value + direction)) and value + direction >= low_end and value + direction <= high_end:
					score += 2.0
			elif level >= 2:
				# Öffnet nur den anderen den Weg.
				score -= 2.0 * foreign
			if value == end:
				score += 1.5
		if level <= 1:
			# Mittel schaut nur auf die eigenen Karten und irrt sich manchmal.
			score += float(_roll(5))
		values.append(score)
	return _best(legal, values)


# --------------------------------------------------------------- Lumo-Quartett


func _quartett(view: Dictionary, legal: Array, level: int) -> Dictionary:
	if level <= 0 and _chance(60):
		return _any(legal)
	if level == 1 and _chance(12):
		return _any(legal)
	var me := int(view.me)
	var seats := int(view.players)
	var hand: Array = view.hand
	var history: Array = view.log
	var window: int = [3, 10, history.size()][clampi(level, 0, 2)]
	var known: Array = []
	var none: Array = []
	for p in range(seats):
		known.append({})
		none.append({})
	for entry: Dictionary in history.slice(maxi(0, history.size() - window)):
		var kind := str(entry.t)
		var p := int(entry.p)
		var value := int(entry.get("rank", 0))
		match kind:
			"miss":
				known[p][value] = maxi(1, int(known[p].get(value, 0)))
				none[p].erase(value)
				none[int(entry.from)][value] = true
				known[int(entry.from)].erase(value)
			"give":
				known[p][value] = maxi(1, int(known[p].get(value, 0))) + int(entry.n)
				none[p].erase(value)
				none[int(entry.from)][value] = true
				known[int(entry.from)].erase(value)
			"draw":
				if int(entry.get("lucky", 0)) == 1:
					known[p][value] = int(known[p].get(value, 0)) + 1
				else:
					# Unbekannte Karte: „hat keine“ gilt nicht mehr sicher.
					none[p].clear()
			"refill":
				none[p].clear()
			"set":
				for q in range(seats):
					known[q].erase(value)
					none[q][value] = true
	var unknown_cards := int(view.stock_size)
	for q in range(seats):
		if q != me:
			unknown_cards += int(view.hand_sizes[q])
	var values: Array = []
	for move: Dictionary in legal:
		if move.has("draw"):
			values.append(0.0)
			continue
		var value := int(move.ask)
		var target := int(move.from)
		var mine := 0
		for card: int in hand:
			if DECK.rank(card) == value:
				mine += 1
		var score := 0.0
		if int(known[target].get(value, 0)) > 0:
			score = 100.0 + 10.0 * (mine + int(known[target][value]))
		elif none[target].has(value):
			score = -50.0
		else:
			var elsewhere := 0
			for q in range(seats):
				if q != me and q != target:
					elsewhere += int(known[q].get(value, 0))
			var open := maxi(0, DECK.SUIT_COUNT - mine - elsewhere)
			var share := float(view.hand_sizes[target]) / float(maxi(1, unknown_cards))
			var chance := 1.0 - pow(1.0 - clampf(share, 0.0, 1.0), float(open))
			score = 40.0 * chance + 5.0 * mine
		values.append(score)
	return _best(legal, values)
