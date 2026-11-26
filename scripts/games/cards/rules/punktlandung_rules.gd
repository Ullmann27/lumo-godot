extends "res://scripts/games/cards/rules/sternenstich_rules.gd"
## Sieben Zielkarten aus dem verdeckten Stapel, eine pro Durchgang.


func game_id() -> String:
	return "ziel"


func title() -> String:
	return "Punktlandung"


func rules_text() -> Array[String]:
	return [
		"Alle bekommen sieben Karten. Die offene Karte zeigt die Zielzahl für diesen Durchgang.",
		"Lege eine beliebige Handkarte. Je näher ihre Zahl am Ziel liegt, desto besser. Die Farbe ist egal.",
		"Beispiel: Bei Ziel 6 sind 5 und 7 beide einen Schritt entfernt. Bei Gleichstand gewinnt die zuerst gelegte Karte.",
		"Wer am nächsten liegt, bekommt einen Punkt und beginnt den nächsten Durchgang mit einer neuen Zielzahl.",
		"Nach sieben Zielkarten bekommt jeder mit den meisten Treffern zwei Extrapunkte. Nova zählt 11, Eule 12 und Lumo 13.",
	]


func target_card() -> int:
	return int(s.r.stock[mini(int(s.r.trick_no), HAND_SIZE - 1)])


func target_rank() -> int:
	return DECK.rank(target_card())


func lead_suit() -> int:
	return -1


func _trick_winner(trick: Array) -> int:
	var target := target_rank()
	var best: Dictionary = trick[0]
	for entry: Dictionary in trick:
		if absi(DECK.rank(entry.c) - target) < absi(DECK.rank(best.c) - target):
			best = entry
	return int(best.p)


func _apply(player: int, move: Dictionary) -> Array:
	# The common turn advances trick_no before returning its events. Keep
	# the target that the players actually saw, even on the last card.
	var resolved_target := target_rank()
	var events := super._apply(player, move)
	for event: Dictionary in events:
		if event.t in ["play", "trick"]:
			event["target"] = resolved_target
	return events


func view(player: int) -> Dictionary:
	var result := super.view(player)
	result.erase("trump")
	result.erase("trump_card")
	result["target"] = target_rank()
	return result
