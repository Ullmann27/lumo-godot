extends SceneTree
## Regelkern, KI und Spielstand der drei Lumo-Kartenspiele – ohne Szene.
## Jede Partie ist über ihren Startwert wiederholbar.

const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const STICH = preload("res://scripts/games/cards/rules/sternenstich_rules.gd")
const LEITER = preload("res://scripts/games/cards/rules/sternenleiter_rules.gd")
const QUARTETT = preload("res://scripts/games/cards/rules/quartett_rules.gd")
const GAMES: Array[String] = ["stich", "leiter", "quartett"]
const MATCHES_PER_LEVEL := 200
const DUEL_MATCHES := 400
const MOVE_LIMIT := 4000

var checks := 0
var failures: Array[String] = []
var moves_total := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[CardsRules] " + label)


func _run() -> void:
	_deck()
	for game: String in GAMES:
		_deal(game)
		_illegal(game)
	_stich_scoring()
	_leiter_scoring()
	_quartett_scoring()
	# Die Massenprüfung gilt den Regeln; Schwer denkt hier mit weniger
	# Stichproben, damit 200 Partien je Stärke zügig durchlaufen.
	var samples: int = SESSION.AI.stich_samples
	SESSION.AI.stich_samples = 8
	for game: String in GAMES:
		for level in range(3):
			_simulate(game, level)
	SESSION.AI.stich_samples = samples
	for game: String in GAMES:
		_strength(game)
	_session()
	print("CARDS_RULES_%s checks=%d failures=%d moves=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), moves_total])
	quit(0 if failures.is_empty() else 1)


func _new(game: String, seed_value: int, players: int, level: int, rounds: int = 3) -> RefCounted:
	var rules := SESSION.create_rules(game)
	rules.setup({"players": players, "rounds": rounds, "seed": seed_value, "difficulty": level,
		"result_id": "test-%s-%d" % [game, seed_value], "seats": ["owl", "lion", "rabbit"]})
	return rules


func _deck() -> void:
	var all: Array = DECK.build(range(4), range(1, 14))
	_check(all.size() == 52, "deck has 52 cards")
	var unique: Dictionary = {}
	for card: int in all:
		unique[card] = true
		_check(DECK.card(DECK.suit(card), DECK.rank(card)) == card, "suit and rank rebuild the card")
	_check(unique.size() == 52, "deck has no duplicate")
	_check(DECK.label(DECK.card(1, 7)) == "Mond 7" and DECK.label(DECK.card(0, 13)) == "Stern-Lumo", "cards are named")
	var first: Array = DECK.shuffled(all, DECK.rng_seed(7))
	var again: Array = DECK.shuffled(all, DECK.rng_seed(7))
	var other: Array = DECK.shuffled(all, DECK.rng_seed(8))
	_check(first[0] == again[0] and first[1] == again[1], "same seed gives the same shuffle")
	_check(first[0] != other[0], "another seed gives another shuffle")
	var sorted_copy: Array = first[0].duplicate()
	sorted_copy.sort()
	_check(sorted_copy == all, "shuffle keeps every card exactly once")
	# Der Zufallszustand muss eine JSON-Runde überstehen.
	var state := DECK.rng_seed(123456)
	for i in range(200):
		state = DECK.rng_next(state)
		_check(state > 0 and state <= 0xFFFFFFFF and int(JSON.parse_string(JSON.stringify(state))) == state,
			"rng state survives JSON")
	# Gleichverteilung grob prüfen: 13 Fächer, 13000 Würfe.
	var bins: Array = []
	bins.resize(13)
	bins.fill(0)
	for i in range(13000):
		state = DECK.rng_next(state)
		bins[DECK.rng_pick(state, 13)] += 1
	for count: int in bins:
		_check(count > 850 and count < 1150, "rng spreads evenly (%d)" % count)


func _deal(game: String) -> void:
	for players in range(2, 5):
		for seed_value in range(1, 26):
			var rules := _new(game, seed_value, players, 1)
			_check(rules.check().is_empty(), "%s deal %d/%d is complete: %s" % [game, players, seed_value, rules.check()])
			_check(rules.players() == players and rules.phase() == "playing", game + " starts playing")
			var twin := _new(game, seed_value, players, 1)
			_check(twin.snapshot() == rules.snapshot(), game + " deal is repeatable by seed")
			var sizes: Array = rules.view(0).hand_sizes
			match game:
				"stich":
					for size: int in sizes:
						_check(size == 7, "stich deals seven cards")
					_check(rules.s.r.stock.size() == 52 - 7 * players, "stich keeps the rest as stock")
					_check(DECK.suit(int(rules.s.r.trump_card)) == int(rules.s.r.trump), "trump card shows the trump suit")
				"leiter":
					for size: int in sizes:
						_check(size == 9, "leiter deals nine cards")
					_check(rules.s.r.suits.size() == maxi(2, players), "leiter uses one suit per player")
				"quartett":
					var setup: Dictionary = QUARTETT.SETUP[players]
					var in_hands := 0
					for size: int in sizes:
						in_hands += size
					var laid: int = rules.sets_total() * 4
					_check(in_hands + rules.s.r.stock.size() + laid == setup.ranks.size() * 4, "quartett uses whole quartets")
		var a := _new(game, 3, players, 1)
		var b := _new(game, 4, players, 1)
		_check(a.s.r.hands != b.s.r.hands, game + " deals differ between seeds")


func _illegal(game: String) -> void:
	for seed_value in range(1, 31):
		var rules := _new(game, seed_value, 2 + seed_value % 3, 1)
		# Ein paar Züge weit spielen, damit Stiche und Leitern angefangen sind.
		for step in range(seed_value % 9):
			if rules.phase() == "playing":
				rules.play(rules.current(), SESSION.ai_move(rules, rules.current()))
		if rules.phase() != "playing":
			continue
		var player: int = rules.current()
		var before: Dictionary = rules.snapshot()
		var legal: Array = rules.legal_moves(player)
		_check(not legal.is_empty(), game + " always offers a move to the player in turn")
		var attempts: Array = [{}, {"card": -1}, {"card": 99}, {"nonsense": 1}, {"ask": 0, "from": 0}]
		var wrong: int = (player + 1) % rules.players()
		_check(rules.legal_moves(wrong).is_empty(), game + " offers no move out of turn")
		_check(not rules.play(wrong, legal[0]).ok, game + " rejects a move out of turn")
		for card in range(52):
			var move := {"card": card}
			if not rules.is_legal(player, move):
				attempts.append(move)
		if game == "leiter" and not legal[0].has("pass"):
			attempts.append({"pass": 1})
		if game == "quartett":
			for value in range(1, 14):
				for target in range(-1, rules.players() + 1):
					var ask := {"ask": value, "from": target}
					if not rules.is_legal(player, ask):
						attempts.append(ask)
			if not legal[0].has("draw"):
				attempts.append({"draw": 1})
		for move: Dictionary in attempts:
			var result: Dictionary = rules.play(player, move)
			_check(not result.ok and result.events.is_empty() and not str(result.error).is_empty(),
				"%s rejects %s with a reason" % [game, str(move)])
		_check(rules.snapshot() == before, game + " keeps its state after rejected moves")
		if game == "stich" and not rules.s.r.trick.is_empty():
			var lead: int = rules.lead_suit()
			var has_lead := false
			for card: int in rules.s.r.hands[player]:
				has_lead = has_lead or DECK.suit(card) == lead
			for move: Dictionary in legal:
				_check(not has_lead or DECK.suit(int(move.card)) == lead, "stich forces following suit")
		if game == "leiter":
			for move: Dictionary in legal:
				_check(move.has("pass") or rules.fits(int(move.card)), "leiter only offers fitting cards")


func _stich_scoring() -> void:
	var c := func(suit: int, value: int) -> int: return DECK.card(suit, value)
	var trick := [{"p": 0, "c": c.call(0, 5)}, {"p": 1, "c": c.call(0, 9)}, {"p": 2, "c": c.call(1, 13)}, {"p": 3, "c": c.call(0, 2)}]
	_check(STICH.winner_of(trick, 3) == 1, "highest card of the led suit wins")
	_check(STICH.winner_of(trick, 1) == 2, "a trump beats the led suit")
	trick[3].c = c.call(2, 1)
	_check(STICH.winner_of(trick, 2) == 3, "even the smallest trump wins")
	trick[2].c = c.call(2, 4)
	_check(STICH.winner_of(trick, 2) == 2, "the higher trump wins")
	_check(STICH.winner_of([{"p": 2, "c": c.call(3, 3)}, {"p": 3, "c": c.call(1, 12)}], 0) == 2, "an off-suit card never wins")
	# Ganze Runde: 4 Spieler, Stiche werden gezählt und gewertet.
	var rules := _new("stich", 11, 4, 2, 2)
	var tricks_seen := 0
	var over: Dictionary = {}
	while rules.phase() == "playing":
		var player: int = rules.current()
		var before_trick: Array = rules.s.r.trick.duplicate(true)
		var move: Dictionary = SESSION.ai_move(rules, player)
		var result: Dictionary = rules.play(player, move)
		for event: Dictionary in result.events:
			if event.t == "trick":
				tricks_seen += 1
				before_trick.append({"p": player, "c": int(move.card)})
				_check(int(event.winner) == STICH.winner_of(before_trick, int(rules.s.r.trump)), "trick goes to the computed winner")
				_check(rules.phase() != "playing" or rules.current() == int(event.winner), "trick winner leads next")
			if event.t == "round_over":
				over = event
	_check(tricks_seen == 7 and not over.is_empty(), "a round has seven tricks")
	var most := 0
	for count: int in over.detail.tricks:
		most = maxi(most, count)
	var sum := 0
	for p in range(4):
		var expected: int = int(over.detail.tricks[p]) + (2 if int(over.detail.tricks[p]) == most else 0)
		_check(int(over.points[p]) == expected, "trick points plus winner bonus")
		_check(over.winners.has(p) == (int(over.detail.tricks[p]) == most), "round winner has the most tricks")
		sum += int(over.detail.tricks[p])
	_check(sum == 7 and rules.phase() == "round_over", "all seven tricks are scored, round is over")
	_check(rules.legal_moves(0).is_empty() and not rules.play(0, {"card": 0}).ok, "no move after the round ended")
	var starter_before: int = int(rules.s.r.leader)
	rules.next_round()
	_check(rules.phase() == "playing" and rules.round_number() == 2 and rules.check().is_empty(), "next round deals again")
	_check(starter_before >= 0 and int(rules.s.r.turn) == (int(rules.s.starter) + 1) % 4, "the starter moves on each round")


func _leiter_scoring() -> void:
	var rules := _new("leiter", 5, 4, 2, 1)
	var c := func(suit: int, value: int) -> int: return DECK.card(suit, value)
	_check(rules.fits(c.call(0, 5)) and not rules.fits(c.call(0, 4)) and not rules.fits(c.call(0, 6)),
		"a ladder starts only with its five")
	# Gezielte Stellung: Spieler 0 hält Stern 5, 4, 6 und 3.
	rules.s.r.hands = [[c.call(0, 3), c.call(0, 4), c.call(0, 5), c.call(0, 6)], [], [], []]
	var rest: Array = []
	for card: int in DECK.build(range(4), range(1, 10)):
		if not rules.s.r.hands[0].has(card):
			rest.append(card)
	for i in range(rest.size()):
		rules.s.r.hands[1 + i % 3].append(rest[i])
	rules.s.r.turn = 0
	_check(rules.check().is_empty(), "crafted ladder position is valid: " + rules.check())
	_check(not rules.play(0, {"card": c.call(0, 4)}).ok, "four waits for the five")
	_check(rules.play(0, {"card": c.call(0, 5)}).ok, "five opens the ladder")
	rules.s.r.turn = 0
	_check(not rules.play(0, {"card": c.call(0, 3)}).ok, "three waits for the four")
	_check("4" in rules.explain(0, {"card": c.call(0, 3)}), "the reason names the neighbour number")
	_check(rules.play(0, {"card": c.call(0, 4)}).ok and int(rules.s.r.low[0]) == 4, "ladder grows downwards")
	rules.s.r.turn = 0
	_check(rules.play(0, {"card": c.call(0, 6)}).ok and int(rules.s.r.high[0]) == 6, "ladder grows upwards")
	rules.s.r.turn = 0
	var last: Dictionary = rules.play(0, {"card": c.call(0, 3)})
	_check(last.ok and rules.phase() == "match_over", "emptying the hand ends the round")
	var over: Dictionary = last.events.back()
	_check(over.t == "round_over" and over.winners == [0] and int(over.points[0]) == 3, "first player out wins three points")
	_check(int(over.detail.left[0]) == 0 and int(over.detail.finisher) == 0, "winner has no cards left")
	for p in range(1, 4):
		var better := 0
		for q in range(4):
			if int(over.detail.left[q]) < int(over.detail.left[p]):
				better += 1
		_check(int(over.points[p]) == [3, 2, 1, 0][better], "fewer cards left means more points")
	# Aussetzen: nur wenn wirklich nichts passt.
	var stuck := _new("leiter", 9, 2, 1, 1)
	stuck.s.r.hands = [[c.call(0, 1), c.call(0, 9), c.call(1, 1)], []]
	for card: int in DECK.build(range(2), range(1, 10)):
		if not stuck.s.r.hands[0].has(card):
			stuck.s.r.hands[1].append(card)
	stuck.s.r.turn = 0
	_check(stuck.legal_moves(0) == [{"pass": 1}], "a player without a fitting card may only pass")
	var passed: Dictionary = stuck.play(0, {"pass": 1})
	_check(passed.ok and passed.events[0].t == "pass" and stuck.current() == 1, "passing hands the turn on")
	_check(not stuck.legal_moves(1).has({"pass": 1}), "a player with a fitting card may not pass")


func _quartett_scoring() -> void:
	var c := func(suit: int, value: int) -> int: return DECK.card(suit, value)
	var rules := _new("quartett", 5, 3, 2, 1)
	var ranks: Array = rules.ranks_in_play()
	var deck: Array = DECK.build(range(4), ranks)
	# Spieler 0: drei Einsen und eine Zwei. Spieler 1: die vierte Eins. Spieler 2: Zweien.
	var h0: Array = [c.call(0, 1), c.call(1, 1), c.call(2, 1), c.call(0, 2)]
	var h1: Array = [c.call(3, 1), c.call(0, 3), c.call(1, 3)]
	var h2: Array = [c.call(1, 2), c.call(2, 2), c.call(0, 4)]
	var stock: Array = []
	for card: int in deck:
		if not h0.has(card) and not h1.has(card) and not h2.has(card):
			stock.append(card)
	# Oben auf dem Stapel: erst eine Niete, dann die letzte Zwei.
	stock.erase(c.call(3, 2))
	stock.erase(c.call(0, 5))
	stock.push_front(c.call(3, 2))
	stock.push_front(c.call(0, 5))
	rules.s.r.hands = [h0, h1, h2]
	rules.s.r.stock = stock
	rules.s.r.sets = [[], [], []]
	rules.s.r.log = []
	rules.s.r.turn = 0
	_check(rules.check().is_empty(), "crafted quartett position is valid: " + rules.check())
	_check(not rules.play(0, {"ask": 3, "from": 1}).ok, "asking needs a card of that value in hand")
	_check(not rules.play(0, {"ask": 1, "from": 0}).ok, "nobody may ask themselves")
	var hit: Dictionary = rules.play(0, {"ask": 1, "from": 1})
	var kinds: Array = []
	for event: Dictionary in hit.events:
		kinds.append(event.t)
	_check(hit.ok and kinds == ["ask", "give", "set"], "a hit hands the cards over and lays the quartet: " + str(kinds))
	_check(rules.s.r.sets[0] == [1] and rules.current() == 0, "after a hit the same player asks again")
	_check(QUARTETT.count_rank(rules.s.r.hands[1], 1) == 0, "the asked player gives all cards of that value")
	var miss: Dictionary = rules.play(0, {"ask": 2, "from": 1})
	kinds.clear()
	for event: Dictionary in miss.events:
		kinds.append(event.t)
	_check(miss.ok and kinds == ["ask", "miss", "draw"], "a miss draws one card: " + str(kinds))
	_check(rules.current() == 1 and rules.s.r.hands[0].has(c.call(0, 5)), "after a miss the next player is in turn")
	rules.s.r.turn = 0
	var lucky: Dictionary = rules.play(0, {"ask": 2, "from": 1})
	_check(lucky.ok and bool(lucky.events.back().lucky) and rules.current() == 0, "drawing the asked value gives another turn")
	var taken: Dictionary = rules.play(0, {"ask": 2, "from": 2})
	_check(taken.ok and rules.s.r.sets[0] == [1, 2], "four equal values form a quartet at once")
	_check(rules.check().is_empty(), "quartett stays consistent: " + rules.check())
	# Rundenende: alle Quartette liegen, Punkte = Quartette.
	var full := _new("quartett", 21, 2, 2, 1)
	var guard := 0
	while full.phase() == "playing" and guard < MOVE_LIMIT:
		full.play(full.current(), SESSION.ai_move(full, full.current()))
		guard += 1
	var entry: Dictionary = full.s.history[0]
	_check(full.phase() == "match_over" and int(entry.points[0]) + int(entry.points[1]) == full.ranks_in_play().size(),
		"every quartet is laid and counted once")
	_check(full.s.r.stock.is_empty() and full.s.r.hands[0].is_empty() and full.s.r.hands[1].is_empty(), "no card is left over")


## Vertauscht alles, was Spieler `player` nicht sehen kann.
func _scramble_hidden(rules: RefCounted, player: int, state: int) -> void:
	var hidden: Array = []
	var slots: Array = []
	for p in range(rules.players()):
		if p != player:
			slots.append(rules.s.r.hands[p])
	if rules.s.r.has("stock"):
		slots.append(rules.s.r.stock)
	var keep_first: bool = rules.game_id() == "stich"
	for i in range(slots.size()):
		var pile: Array = slots[i]
		var start := 1 if keep_first and i == slots.size() - 1 else 0
		for index in range(start, pile.size()):
			hidden.append(pile[index])
	var mixed: Array = DECK.shuffled(hidden, state)[0]
	var cursor := 0
	for i in range(slots.size()):
		var pile: Array = slots[i]
		var start := 1 if keep_first and i == slots.size() - 1 else 0
		for index in range(start, pile.size()):
			pile[index] = mixed[cursor]
			cursor += 1


func _simulate(game: String, level: int) -> void:
	var longest := 0
	var total := 0
	var saves := 0
	var blind := 0
	for seed_value in range(1, MATCHES_PER_LEVEL + 1):
		var players := 2 + seed_value % 3
		var rules := _new(game, seed_value * 7919 + level, players, level)
		var twin: RefCounted = null
		var save_at := 3 + seed_value % 40
		var count := 0
		var rounds_seen := 0
		while rules.phase() != "match_over" and count < MOVE_LIMIT:
			if rules.phase() == "round_over":
				_round_totals(game, rules)
				rounds_seen += 1
				rules.next_round()
				if twin != null:
					twin.next_round()
				_check(rules.check().is_empty(), "%s new round is complete" % game)
				continue
			var player: int = rules.current()
			var legal: Array = rules.legal_moves(player)
			if legal.is_empty():
				_check(false, "%s seed %d: no legal move in turn" % [game, seed_value])
				break
			if count % 11 == 5:
				# Die KI darf nichts Verdecktes sehen: Sicht bleibt gleich, wenn
				# fremde Hände und der Stapel vertauscht werden.
				var probe := SESSION.create_rules(game)
				probe.s = rules.snapshot()
				var seen: Dictionary = probe.view(player)
				_scramble_hidden(probe, player, DECK.rng_seed(seed_value + count))
				_check(probe.view(player) == seen, "%s view hides other hands and the stock" % game)
				var rng: int = int(rules.s.ai_rng)
				var first: Dictionary = SESSION.AI.choose(seen, legal, level, rng)
				var second: Dictionary = SESSION.AI.choose(probe.view(player), legal, level, rng)
				_check(first.move == second.move, "%s AI decides without hidden cards" % game)
				blind += 1
			var move: Dictionary = SESSION.ai_move(rules, player)
			_check(rules.is_legal(player, move), "%s AI level %d plays a legal move" % [game, level])
			var result: Dictionary = rules.play(player, move)
			if not result.ok:
				_check(false, "%s seed %d: legal move was refused: %s" % [game, seed_value, result.error])
				break
			count += 1
			if count % 4 == 0 or rules.phase() != "playing":
				var problem: String = rules.check()
				if not problem.is_empty():
					_check(false, "%s seed %d move %d: %s" % [game, seed_value, count, problem])
					break
			if twin != null:
				var mirrored: Dictionary = twin.play(player, SESSION.ai_move(twin, player))
				if not mirrored.ok or twin.s != rules.s:
					_check(false, "%s seed %d: resumed match drifts apart" % [game, seed_value])
					break
			elif count == save_at and rules.phase() == "playing":
				# Speichern → Laden: identischer Zustand, auch über JSON.
				var text := JSON.stringify(rules.snapshot())
				twin = SESSION.create_rules(game)
				_check(twin.restore(JSON.parse_string(text)), "%s restores a saved match" % game)
				_check(twin.snapshot() == rules.snapshot(), "%s restored state is identical" % game)
				_check(JSON.stringify(twin.snapshot()) == text, "%s restored state saves to the same text" % game)
				saves += 1
		_check(rules.phase() == "match_over", "%s seed %d level %d finishes (%d moves)" % [game, seed_value, level, count])
		if rules.phase() == "match_over":
			_round_totals(game, rules)
			rounds_seen += 1
			_check(rounds_seen == 3 and rules.s.history.size() == 3, game + " plays three scored rounds")
			var sum := 0
			for round_entry: Dictionary in rules.s.history:
				sum += int(round_entry.points[0])
			_check(sum == int(rules.s.scores[0]), game + " match score is the sum of its rounds")
			_check(rules.places().has(1), game + " has a winner")
			if twin != null:
				_check(twin.snapshot() == rules.snapshot(), game + " saved match ends exactly like the original")
		longest = maxi(longest, count)
		total += count
	moves_total += total
	print("[CardsRules] %s level=%d matches=%d moves avg=%.1f max=%d saves=%d blind_checks=%d" % [
		game, level, MATCHES_PER_LEVEL, float(total) / MATCHES_PER_LEVEL, longest, saves, blind])


func _round_totals(game: String, rules: RefCounted) -> void:
	var entry: Dictionary = rules.s.history.back()
	var sum := 0
	for value: int in entry.points:
		sum += value
	match game:
		"stich":
			_check(sum == 7 + 2 * entry.winners.size(), "stich scores seven tricks plus bonus")
		"leiter":
			_check(int(entry.left[int(entry.finisher)]) == 0 and entry.winners.has(int(entry.finisher)), "leiter winner has no cards")
			for p in range(rules.players()):
				_check((int(entry.left[p]) == 0) == (int(entry.points[p]) == 3), "only empty hands score three")
		"quartett":
			_check(sum == rules.s.r.ranks.size(), "quartett scores every quartet once")


## Sitz 0 spielt stärker als die anderen: gewinnt er öfter als der Zufall?
func _strength(game: String) -> void:
	for pairing: Array in [[2, 0], [1, 0], [2, 1]]:
		var wins := 0.0
		for seed_value in range(1, DUEL_MATCHES + 1):
			var rules := _new(game, 50000 + seed_value * 31, 4, 1, 1)
			var guard := 0
			while rules.phase() == "playing" and guard < MOVE_LIMIT:
				var player: int = rules.current()
				rules.play(player, SESSION.ai_move(rules, player, int(pairing[0]) if player == 0 else int(pairing[1])))
				guard += 1
			var winners: Array = rules.s.history[0].winners
			if winners.has(0):
				wins += 1.0 / winners.size()
		var rate := wins / DUEL_MATCHES
		print("[CardsRules] strength %s: level %d against three level %d wins %.1f%% (chance 25%%)" % [
			game, pairing[0], pairing[1], rate * 100.0])
		_check(rate > 0.26, "%s: level %d beats level %d more often than chance (%.3f)" % [game, pairing[0], pairing[1], rate])


func _session() -> void:
	var path := "user://lumo_cards_rules_regression.json"
	DirAccess.remove_absolute(path)
	var session := SESSION.new(path)
	_check(not session.load_file() and not session.has_match("stich"), "a new child starts without a saved match")
	for game: String in GAMES:
		var rules: RefCounted = session.new_match(game, {"players": 3, "rounds": 2, "seed": 77, "difficulty": 2,
			"result_id": "result-" + game, "seats": ["owl", "lion"]})
		for step in range(9):
			rules.play(rules.current(), SESSION.ai_move(rules, rules.current()))
		_check(session.store(rules), game + " match is stored")
		# Neu geöffnet: Datei von der Platte, gleiche Partie, gleiche Ergebnis-ID.
		var reopened := SESSION.new(path)
		_check(reopened.load_file() and reopened.has_match(game), game + " match is found after reopening")
		var resumed: RefCounted = reopened.resume(game)
		_check(resumed != null and resumed.snapshot() == rules.snapshot(), game + " resumes with the identical state")
		_check(str(resumed.s.result_id) == "result-" + game, game + " keeps its result id")
		_check(reopened.match_summary(game).round == rules.round_number(), game + " summary shows the round")
		_check(reopened.settle(resumed).is_empty() and not reopened.is_booked("result-" + game), "an unfinished match is not booked")
		var guard := 0
		while resumed.phase() != "match_over" and guard < MOVE_LIMIT:
			if resumed.phase() == "round_over":
				resumed.next_round()
			else:
				resumed.play(resumed.current(), SESSION.ai_move(resumed, resumed.current()))
			guard += 1
		reopened.store(resumed)
		var payload: Dictionary = reopened.settle(resumed, "session-1")
		var place: int = int(resumed.places()[0])
		_check(payload.get("resultId") == "result-" + game and payload.get("game") == "cards" and payload.get("variant") == game,
			game + " result names the match")
		_check(int(payload.get("stars", 0)) == SESSION.stars_for(place, 2, 2) and int(payload.stars) >= 1 and int(payload.place) == place,
			game + " result carries stars for the place")
		_check(reopened.settle(resumed, "session-1").is_empty(), game + " result is booked only once")
		_check(not reopened.has_match(game), game + " finished match is no longer offered")
		# Absturz vor dem Aufräumen: die beendete Partie liegt noch einmal in der Datei.
		var crashed := SESSION.new(path)
		crashed.load_file()
		crashed.data.matches[game] = resumed.snapshot()
		crashed.save_file()
		var after_crash := SESSION.new(path)
		after_crash.load_file()
		_check(after_crash.is_booked("result-" + game), game + " booking survives reopening")
		var leftover: RefCounted = after_crash.resume(game)
		_check(leftover != null and after_crash.settle(leftover).is_empty(), game + " reopened finished match is not booked twice")
		_check(not after_crash.has_match(game), game + " leftover match is cleared")
		_check(int(after_crash.data.stats[game].played) == 1, game + " counts one finished match")
	_check(SESSION.stars_for(1, 0, 3) == 3 and SESSION.stars_for(1, 2, 3) == 4 and SESSION.stars_for(2, 2, 3) == 2
		and SESSION.stars_for(4, 1, 3) == 1 and SESSION.stars_for(1, 2, 1) == 2, "stars follow place, strength and length")
	# Beschädigte Stände werden abgelehnt, nicht gespielt.
	var broken := SESSION.new(path)
	broken.load_file()
	var good: RefCounted = broken.new_match("stich", {"players": 4, "rounds": 1, "seed": 5, "result_id": "x"})
	var bad: Dictionary = good.snapshot()
	bad.r.hands[0][0] = bad.r.hands[1][0]
	broken.data.matches["stich"] = bad
	_check(broken.resume("stich") == null and not broken.has_match("stich"), "a save with a duplicated card is refused")
	var foreign: Dictionary = good.snapshot()
	foreign.game = "leiter"
	broken.data.matches["stich"] = foreign
	_check(broken.resume("stich") == null, "a save of another game is refused")
	broken.data.matches["stich"] = "kaputt"
	_check(not broken.has_match("stich") and broken.resume("stich") == null, "a non-table save is ignored")
	session.set_prefs(9, -3, 12)
	_check(session.prefs() == {"players": 4, "difficulty": 0, "rounds": 5}, "preferences are clamped")
	_check(SESSION.path_for("kind-a") != SESSION.path_for("kind-b") and SESSION.path_for("") == "user://lumo_cards_standalone.json",
		"every child has its own file")
	DirAccess.remove_absolute(path)
