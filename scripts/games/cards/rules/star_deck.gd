extends RefCounted
## Lumo-Sternendeck: vier Farben mit eigener Form (Stern, Mond, Blatt, Welle),
## Werte 1–10 und drei Bildkarten (11 Nova, 12 Eule, 13 Lumo). Reine Daten und
## Rechenhilfen, keine Darstellung. Eine Karte ist eine Zahl 0..51.

const SUIT_COUNT := 4
const RANK_COUNT := 13
const SIZE := 52
const SUIT_KEYS: Array[String] = ["stern", "mond", "blatt", "welle"]
const SUIT_NAMES: Array[String] = ["Stern", "Mond", "Blatt", "Welle"]
const FACE_NAMES := {11: "Nova", 12: "Eule", 13: "Lumo"}


static func card(suit: int, rank: int) -> int:
	return suit * RANK_COUNT + rank - 1


static func suit(card_id: int) -> int:
	@warning_ignore("integer_division")
	return card_id / RANK_COUNT


static func rank(card_id: int) -> int:
	return card_id % RANK_COUNT + 1


static func is_valid(card_id: int) -> bool:
	return card_id >= 0 and card_id < SIZE


static func rank_label(value: int) -> String:
	return str(FACE_NAMES.get(value, str(value)))


## „Stern 7“ oder „Mond-Eule“ – so spricht Lumo eine Karte an.
static func label(card_id: int) -> String:
	var value := rank(card_id)
	if FACE_NAMES.has(value):
		return "%s-%s" % [SUIT_NAMES[suit(card_id)], FACE_NAMES[value]]
	return "%s %d" % [SUIT_NAMES[suit(card_id)], value]


## Alle Karten der gewählten Farben und Werte, aufsteigend sortiert.
static func build(suits: Array, ranks: Array) -> Array:
	var cards: Array = []
	for suit_index: int in suits:
		for value: int in ranks:
			cards.append(card(suit_index, value))
	cards.sort()
	return cards


## xorshift32: der Zustand passt verlustfrei in eine JSON-Zahl.
static func rng_seed(value: int) -> int:
	var state := (value * 2654435761 + 0x9E3779B9) & 0xFFFFFFFF
	if state == 0:
		state = 0x6D2B79F5
	for i in range(4):
		state = rng_next(state)
	return state


static func rng_next(state: int) -> int:
	var x := state & 0xFFFFFFFF
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	return x & 0xFFFFFFFF


## Gleichverteilte Zahl 0..bound-1 aus dem oberen Teil des Zustands.
static func rng_pick(state: int, bound: int) -> int:
	return int((state >> 4) % maxi(1, bound))


## Fisher-Yates mit dem gespeicherten Zustand. Gibt [gemischt, neuer Zustand].
static func shuffled(cards: Array, state: int) -> Array:
	var result: Array = []
	for value: int in cards:
		result.append(value)
	for i in range(result.size() - 1, 0, -1):
		state = rng_next(state)
		var j := rng_pick(state, i + 1)
		var held: int = result[i]
		result[i] = result[j]
		result[j] = held
	return [result, state]


## JSON liefert jede Zahl als float zurück. Der Spielstand kennt nur ganze
## Zahlen, Texte, Wahrheitswerte, Listen und Tabellen.
static func normalized(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(roundf(value))
		TYPE_ARRAY:
			var list: Array = []
			for entry: Variant in value:
				list.append(normalized(entry))
			return list
		TYPE_DICTIONARY:
			var table: Dictionary = {}
			for key: Variant in value:
				table[str(key)] = normalized(value[key])
			return table
	return value
