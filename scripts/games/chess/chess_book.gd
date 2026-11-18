extends RefCounted
## Lumos kleines Eröffnungswissen: eigene Tabelle bekannter Hauptlinien
## (Spanisch, Italienisch, Schottisch, Russisch, Sizilianisch, Französisch,
## Caro-Kann, Skandinavisch, Damengambit, Slawisch, Nimzo-Indisch,
## Königsindisch, Englisch, Réti). Nur aus der Grundstellung, nur solange die
## Partie genau einer Linie folgt; danach rechnet die Suche selbst.
## Zusammengestellt aus allgemeinem Schachwissen (keine fremde Datei).

const RULES = preload("res://scripts/games/chess/chess_rules.gd")

const LINES := [
	"e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6 c2c3 e8g8",
	"e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 e1g1 f6e4 d2d4 e4d6 b5c6 d7c6 d4e5 d6f5",
	"e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d3 d7d6 e1g1 e8g8",
	"e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 d2d3 f8e7 e1g1 e8g8 f1e1 d7d6",
	"e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 g8f6 d4c6 b7c6 e4e5 d8e7",
	"e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d6d5 f1d3 b8c6",
	"e2e4 e7e5 b1c3 g8f6 g1f3 b8c6 f1b5 f8b4 e1g1 e8g8",
	"e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1e3 e7e5",
	"e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 e7e5 d4b5 d7d6",
	"e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 a7a6 f1d3 g8f6 e1g1 d8c7",
	"e2e4 c7c5 b1c3 b8c6 g2g3 g7g6 f1g2 f8g7 d2d3 d7d6",
	"e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8e7 e4e5 f6d7 g5e7 d8e7",
	"e2e4 e7e6 d2d4 d7d5 b1d2 c7c5 e4d5 e6d5 g1f3 b8c6",
	"e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5 e4g3 f5g6 h2h4 h7h6",
	"e2e4 c7c6 d2d4 d7d5 e4e5 c8f5 g1f3 e7e6 f1e2 c6c5",
	"e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 g8f6 g1f3 c8f5",
	"e2e4 g7g6 d2d4 f8g7 b1c3 d7d6 g1f3 g8f6 f1e2 e8g8",
	"d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3 h7h6",
	"d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4 a2a4 c8f5 e2e3 e7e6",
	"d2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3 e7e6 f1c4 c7c5 e1g1 a7a6",
	"d2d4 d7d5 g1f3 g8f6 c1f4 e7e6 e2e3 c7c5 c2c3 b8c6",
	"d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8 f1d3 d7d5 g1f3 c7c5",
	"d2d4 g8f6 c2c4 e7e6 g1f3 b7b6 g2g3 c8b7 f1g2 f8e7 e1g1 e8g8",
	"d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8 f1e2 e7e5",
	"d2d4 g8f6 c2c4 g7g6 b1c3 d7d5 c4d5 f6d5 e2e4 d5c3 b2c3 f8g7",
	"c2c4 e7e5 b1c3 g8f6 g1f3 b8c6 g2g3 d7d5 c4d5 f6d5 f1g2 d5b6",
	"c2c4 g8f6 b1c3 e7e6 e2e4 d7d5 e4e5 d5d4",
	"c2c4 c7c5 g1f3 g8f6 b1c3 b8c6 g2g3 g7g6 f1g2 f8g7",
	"g1f3 d7d5 g2g3 g8f6 f1g2 e7e6 e1g1 f8e7 d2d3 e8g8",
	"g1f3 g8f6 c2c4 e7e6 b1c3 d7d5 d2d4 f8e7 c1g5 e8g8",
]

static var _table: Dictionary = {}


## Baut die Nachschlagetabelle: bisherige Züge (Leerzeichen-getrennt) → mögliche Antworten.
static func table() -> Dictionary:
	if not _table.is_empty():
		return _table
	for line: String in LINES:
		var moves := line.split(" ")
		for i in moves.size():
			var key := " ".join(moves.slice(0, i))
			var next: Array = _table.get(key, [])
			next.append(moves[i])  # Mehrfach genannte Züge sind häufiger (Gewicht).
			_table[key] = next
	return _table


## Ein Buchzug für die Stellung oder -1 (nicht aus der Grundstellung, Linie verlassen).
static func pick(g: RefCounted, rng: RandomNumberGenerator) -> int:
	if g.start_fen != RULES.START_FEN or g.played.size() >= 16:
		return -1
	var key := " ".join(PackedStringArray(g.played))
	var choices: Array = table().get(key, [])
	if choices.is_empty():
		return -1
	var uci := str(choices[rng.randi_range(0, choices.size() - 1)])
	var m: int = g.move_from_uci(uci)
	if m < 0 or not g.legal_moves().has(m):
		return -1
	return m


## Für Tests: Jede Linie ist von der Grundstellung aus legal.
static func broken_lines() -> Array[String]:
	var bad: Array[String] = []
	for line: String in LINES:
		var g: RefCounted = RULES.new()
		for uci: String in line.split(" "):
			if not g.play_uci(uci):
				bad.append("%s (%s)" % [line, uci])
				break
	return bad
