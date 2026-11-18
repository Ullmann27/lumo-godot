extends RefCounted
## Gemeinsamer Regelkern einer Karten-Partie am Lumo-Tisch.
##
## Der ganze Spielstand liegt in `s` und besteht nur aus ganzen Zahlen, Texten,
## Wahrheitswerten, Listen und Tabellen. Er lässt sich deshalb ohne Verlust als
## JSON speichern und wieder laden. Die Darstellung liest nur über `view()`,
## `legal_moves()` und die Ereignislisten von `play()`.

const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const VERSION := 1

var s: Dictionary = {}


func game_id() -> String:
	return ""


func title() -> String:
	return ""


## Neue Partie. config: players (2–4), rounds (1–5), seed, difficulty (0–2),
## result_id und seats (Kennungen der Mitspieler-Figuren).
func setup(config: Dictionary) -> void:
	var count := clampi(int(config.get("players", 4)), 2, 4)
	var seed_value := int(config.get("seed", 1))
	var totals: Array = []
	for i in range(count):
		totals.append(0)
	s = {
		"v": VERSION,
		"game": game_id(),
		"players": count,
		"rounds_total": clampi(int(config.get("rounds", 3)), 1, 5),
		"round": 0,
		"scores": totals,
		"history": [],
		"seed": seed_value,
		"rng": DECK.rng_seed(seed_value),
		"ai_rng": DECK.rng_seed(seed_value ^ 0x5BD1E995),
		"starter": DECK.rng_pick(DECK.rng_seed(seed_value + 17), count),
		"difficulty": clampi(int(config.get("difficulty", 1)), 0, 2),
		"result_id": str(config.get("result_id", "")),
		"seats": DECK.normalized(config.get("seats", [])),
		"phase": "playing",
		"moves": 0,
		"r": {},
	}
	_deal()


func players() -> int:
	return int(s.get("players", 0))


func phase() -> String:
	return str(s.get("phase", ""))


func current() -> int:
	return int(s.r.get("turn", 0)) if phase() == "playing" else -1


func round_number() -> int:
	return int(s.get("round", 0)) + 1


func rounds_total() -> int:
	return int(s.get("rounds_total", 1))


func scores() -> Array:
	return s.scores.duplicate()


## Plätze 1..n; gleiche Punktzahl teilt sich den besseren Platz.
func places() -> Array:
	var result: Array = []
	for p in range(players()):
		var place := 1
		for q in range(players()):
			if int(s.scores[q]) > int(s.scores[p]):
				place += 1
		result.append(place)
	return result


func snapshot() -> Dictionary:
	return s.duplicate(true)


## Lädt einen gespeicherten Stand. Lehnt fremde oder beschädigte Daten ab.
func restore(saved: Variant) -> bool:
	if not saved is Dictionary:
		return false
	var candidate: Dictionary = DECK.normalized(saved)
	if int(candidate.get("v", 0)) != VERSION or str(candidate.get("game", "")) != game_id():
		return false
	for key: String in ["players", "rounds_total", "round", "scores", "history", "rng", "ai_rng",
		"starter", "difficulty", "result_id", "seats", "phase", "moves", "r", "seed"]:
		if not candidate.has(key):
			return false
	if not candidate.scores is Array or not candidate.r is Dictionary:
		return false
	if int(candidate.players) < 2 or int(candidate.players) > 4:
		return false
	if candidate.scores.size() != int(candidate.players):
		return false
	if str(candidate.phase) not in ["playing", "round_over", "match_over"]:
		return false
	var previous := s
	s = candidate
	if not check().is_empty():
		s = previous
		return false
	return true


func legal_moves(_player: int) -> Array:
	return []


func is_legal(player: int, move: Dictionary) -> bool:
	for candidate: Dictionary in legal_moves(player):
		if candidate == move:
			return true
	return false


## Führt einen Zug aus. Nur der Spieler am Zug und nur erlaubte Züge.
func play(player: int, move: Dictionary) -> Dictionary:
	if phase() != "playing":
		return {"ok": false, "error": "Die Runde ist zu Ende.", "events": []}
	if player != current():
		return {"ok": false, "error": "Du bist noch nicht dran.", "events": []}
	var clean: Dictionary = DECK.normalized(move)
	if not is_legal(player, clean):
		return {"ok": false, "error": explain(player, clean), "events": []}
	s.moves = int(s.moves) + 1
	var events: Array = _apply(player, clean)
	return {"ok": true, "error": "", "events": events}


## Startet nach der Rundenwertung die nächste Runde.
func next_round() -> Array:
	if phase() != "round_over":
		return []
	s.round = int(s.round) + 1
	s.phase = "playing"
	_deal()
	return [{"t": "deal", "round": int(s.round)}]


func view(_player: int) -> Dictionary:
	return {}


func explain(_player: int, _move: Dictionary) -> String:
	return "Das geht gerade nicht."


## Prüft die Erhaltung aller Karten. Leerer Text heißt: alles stimmt.
func check() -> String:
	return ""


func rules_text() -> Array[String]:
	return []


func _deal() -> void:
	pass


func _apply(_player: int, _move: Dictionary) -> Array:
	return []


func _starter() -> int:
	return (int(s.starter) + int(s.round)) % players()


func _shuffle(cards: Array) -> Array:
	var mixed: Array = DECK.shuffled(cards, int(s.rng))
	s.rng = mixed[1]
	return mixed[0]


func _base_view(player: int) -> Dictionary:
	var sizes: Array = []
	for hand: Array in s.r.hands:
		sizes.append(hand.size())
	var hand_copy: Array = s.r.hands[player].duplicate()
	return {
		"game": game_id(),
		"players": players(),
		"me": player,
		"turn": current(),
		"round": int(s.round),
		"rounds_total": int(s.rounds_total),
		"scores": s.scores.duplicate(),
		"hand": hand_copy,
		"hand_sizes": sizes,
	}


## Schließt die Runde ab: Punkte gutschreiben, Verlauf merken, Phase setzen.
func _finish_round(points: Array, detail: Dictionary) -> Dictionary:
	for p in range(players()):
		s.scores[p] = int(s.scores[p]) + int(points[p])
	var best := -1
	for value: int in points:
		best = maxi(best, value)
	var winners: Array = []
	for p in range(players()):
		if int(points[p]) == best:
			winners.append(p)
	var entry := {"points": points.duplicate(), "winners": winners}
	entry.merge(detail)
	s.history.append(entry)
	s.phase = "match_over" if int(s.round) + 1 >= int(s.rounds_total) else "round_over"
	return {
		"t": "round_over",
		"points": points.duplicate(),
		"winners": winners,
		"detail": detail.duplicate(true),
		"final": s.phase == "match_over",
	}


## Hilfsprüfung: jede Karte genau einmal in den genannten Stapeln.
func _conserved(piles: Array, expected: Array) -> String:
	var seen: Dictionary = {}
	var total := 0
	for pile: Array in piles:
		for card: Variant in pile:
			if typeof(card) != TYPE_INT or not DECK.is_valid(card):
				return "ungültige Karte %s" % str(card)
			if seen.has(card):
				return "Karte doppelt: %s" % DECK.label(card)
			seen[card] = true
			total += 1
	if total != expected.size():
		return "Kartenzahl %d statt %d" % [total, expected.size()]
	for card: int in expected:
		if not seen.has(card):
			return "Karte fehlt: %s" % DECK.label(card)
	return ""
