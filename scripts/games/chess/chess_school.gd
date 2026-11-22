extends RefCounted
## Lumos Schachschule: Lektionen, Mini-Spiele und das geführte Probespiel.
##
## Reine Daten und Prüfungen – keine Grafik. Jede Lektion besteht aus kurzen
## Schritten: Lumo zeigt („show“), das Kind tippt („tap“) oder zieht („move“),
## am Ende ein kleines Rätsel. Mini-Spiele sammeln Sterne („collect“).
## Sätze bleiben kurz (höchstens zwölf Wörter), ohne unerklärte Fachwörter.
##
## Der Lernweg (PATH) mischt Lektionen und Probespiel-Stufen: erst die Figuren
## einzeln, dann kleine echte Partien gegen Lumo mit immer mehr Figuren.

const RULES = preload("res://scripts/games/chess/chess_rules.gd")

const EMPTY := "8/8/8/8/8/8/8/8 w - - 0 1"

const LESSONS := {
	"brett":
	{
		"title": "Das Brett",
		"icon": "w_pawn",
		"steps":
		[
			{
				"type": "show",
				"fen": EMPTY,
				"say": "Das ist das Schachbrett. Es hat 64 Felder.",
				"glow": ["a1", "h1", "a8", "h8"]
			},
			{
				"type": "show",
				"fen": EMPTY,
				"say": "Helle und dunkle Felder wechseln sich immer ab.",
				"glow": ["d4", "e4", "d5", "e5"]
			},
			{
				"type": "show",
				"fen": EMPTY,
				"say": "Unten ist deine Seite. Oben sitze ich.",
				"glow": ["a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1"]
			},
			{"type": "tap", "fen": EMPTY, "say": "Tippe auf ein helles Feld!", "want": "light"},
			{
				"type": "tap",
				"fen": EMPTY,
				"say": "Tippe auf ein Feld ganz unten bei dir!",
				"want": "rank1"
			},
		],
	},
	"turm":
	{
		"title": "Der Turm",
		"icon": "w_rook",
		"steps":
		[
			{
				"type": "show",
				"fen": "8/8/8/8/3R4/8/8/8 w - - 0 1",
				"say": "Das ist der Turm.",
				"glow": ["d4"]
			},
			{
				"type": "show",
				"fen": "8/8/8/8/3R4/8/8/8 w - - 0 1",
				"say": "Er fährt gerade: vor, zurück und zur Seite.",
				"glow_moves": "d4"
			},
			{
				"type": "show",
				"fen": "8/8/8/8/3R4/8/8/8 w - - 0 1",
				"say": "So weit er will. Schau!",
				"demo": "d4d8"
			},
			{
				"type": "move",
				"fen": "8/8/8/8/3R4/8/8/8 w - - 0 1",
				"say": "Fahr mit dem Turm zum Stern!",
				"goal": "reach",
				"targets": ["h4"]
			},
			{
				"type": "show",
				"fen": "8/3p4/8/8/3R4/8/8/8 w - - 0 1",
				"say": "Schlagen heißt: Du stellst dich auf die andere Figur.",
				"glow": ["d7"]
			},
			{
				"type": "move",
				"fen": "8/3p4/8/8/3R4/8/8/8 w - - 0 1",
				"say": "Schlag den schwarzen Bauern!",
				"goal": "reach",
				"targets": ["d7"]
			},
		],
	},
	"laeufer":
	{
		"title": "Der Läufer",
		"icon": "w_bishop",
		"steps":
		[
			{
				"type": "show",
				"fen": "8/8/8/8/3B4/8/8/8 w - - 0 1",
				"say": "Das ist der Läufer.",
				"glow": ["d4"]
			},
			{
				"type": "show",
				"fen": "8/8/8/8/3B4/8/8/8 w - - 0 1",
				"say": "Er läuft schräg, so weit er will.",
				"glow_moves": "d4"
			},
			{
				"type": "show",
				"fen": "8/8/8/8/3B4/8/8/8 w - - 0 1",
				"say": "Darum bleibt er immer auf seiner Farbe.",
				"demo": "d4g7"
			},
			{
				"type": "move",
				"fen": "8/8/8/8/3B4/8/8/8 w - - 0 1",
				"say": "Lauf mit dem Läufer zum Stern!",
				"goal": "reach",
				"targets": ["a7"]
			},
			{
				"type": "move",
				"fen": "8/8/1p6/8/3B4/8/8/8 w - - 0 1",
				"say": "Schlag den schwarzen Bauern!",
				"goal": "reach",
				"targets": ["b6"]
			},
		],
	},
	"dame":
	{
		"title": "Die Dame",
		"icon": "w_queen",
		"steps":
		[
			{
				"type": "show",
				"fen": "8/8/8/8/3Q4/8/8/8 w - - 0 1",
				"say": "Das ist die Dame. Sie ist die stärkste Figur.",
				"glow": ["d4"]
			},
			{
				"type": "show",
				"fen": "8/8/8/8/3Q4/8/8/8 w - - 0 1",
				"say": "Sie zieht gerade wie der Turm und schräg wie der Läufer.",
				"glow_moves": "d4"
			},
			{
				"type": "move",
				"fen": "8/8/8/8/3Q4/8/8/8 w - - 0 1",
				"say": "Bring die Dame zum Stern!",
				"goal": "reach",
				"targets": ["a7"]
			},
			{
				"type": "move",
				"fen": "7n/8/8/8/3Q4/8/8/8 w - - 0 1",
				"say": "Schnapp dir die schwarze Figur!",
				"goal": "reach",
				"targets": ["h8"]
			},
		],
	},
	"koenig":
	{
		"title": "Der König",
		"icon": "w_king",
		"steps":
		[
			{
				"type": "show",
				"fen": "7k/8/8/8/3K4/8/8/8 w - - 0 1",
				"say": "Das ist der König. Er ist am wichtigsten.",
				"glow": ["d4"]
			},
			{
				"type": "show",
				"fen": "7k/8/8/8/3K4/8/8/8 w - - 0 1",
				"say": "Er geht nur einen Schritt, in jede Richtung.",
				"glow_moves": "d4"
			},
			{
				"type": "move",
				"fen": "7k/8/8/8/3K4/8/8/8 w - - 0 1",
				"say": "Geh mit dem König zum Stern!",
				"goal": "reach",
				"targets": ["e5"]
			},
			{
				"type": "show",
				"fen": "7k/8/8/8/3K4/8/8/8 w - - 0 1",
				"say": "Den König darf man nie schlagen. Man fängt ihn.",
				"glow": ["h8"]
			},
		],
	},
	"springer":
	{
		"title": "Der Springer",
		"icon": "w_knight",
		"steps":
		[
			{
				"type": "show",
				"fen": "8/8/8/8/3N4/8/8/8 w - - 0 1",
				"say": "Das ist der Springer. Er sieht aus wie ein Pferd.",
				"glow": ["d4"]
			},
			{
				"type": "show",
				"fen": "8/8/8/8/3N4/8/8/8 w - - 0 1",
				"say": "Er springt wie ein L: zwei geradeaus, eins zur Seite.",
				"glow_moves": "d4"
			},
			{
				"type": "show",
				"fen": "8/8/8/2PPP3/2PNP3/2PPP3/8/8 w - - 0 1",
				"say": "Er darf sogar über andere Figuren springen!",
				"demo": "d4e6"
			},
			{
				"type": "move",
				"fen": "8/8/8/8/3N4/8/8/8 w - - 0 1",
				"say": "Spring zum Stern!",
				"goal": "reach",
				"targets": ["b5"]
			},
			{
				"type": "move",
				"fen": "8/8/4p3/8/3N4/8/8/8 w - - 0 1",
				"say": "Schlag den schwarzen Bauern mit einem Sprung!",
				"goal": "reach",
				"targets": ["e6"]
			},
		],
	},
	"bauer":
	{
		"title": "Der Bauer",
		"icon": "w_pawn",
		"steps":
		[
			{
				"type": "show",
				"fen": "8/8/8/8/8/8/4P3/8 w - - 0 1",
				"say": "Das ist der Bauer. Davon hast du acht!",
				"glow": ["e2"]
			},
			{
				"type": "show",
				"fen": "8/8/8/8/8/8/4P3/8 w - - 0 1",
				"say": "Er geht nur nach vorne. Immer ein Feld.",
				"glow": ["e3"]
			},
			{
				"type": "show",
				"fen": "8/8/8/8/8/8/4P3/8 w - - 0 1",
				"say": "Beim allerersten Zug darf er zwei Felder gehen.",
				"demo": "e2e4"
			},
			{
				"type": "move",
				"fen": "8/8/8/8/8/8/3P4/8 w - - 0 1",
				"say": "Mach mit dem Bauern zwei Schritte auf einmal!",
				"goal": "reach",
				"targets": ["d4"]
			},
			{
				"type": "show",
				"fen": "8/8/8/3p4/4P3/8/8/8 w - - 0 1",
				"say": "Schlagen kann er nur schräg nach vorne.",
				"glow": ["d5"]
			},
			{
				"type": "move",
				"fen": "8/8/8/3p4/4P3/8/8/8 w - - 0 1",
				"say": "Schlag den schwarzen Bauern schräg!",
				"goal": "reach",
				"targets": ["d5"]
			},
			{
				"type": "show",
				"fen": "8/4P3/8/8/8/8/8/8 w - - 0 1",
				"say": "Kommt er ganz nach hinten, wird er zur Dame!",
				"glow": ["e8"]
			},
			{
				"type": "move",
				"fen": "8/4P3/8/8/8/8/8/8 w - - 0 1",
				"say": "Lauf nach hinten und verwandle deinen Bauern!",
				"goal": "promote",
				"targets": ["e8"]
			},
		],
	},
	"labyrinth":
	{
		"title": "Turm im Labyrinth",
		"icon": "w_rook",
		"minigame": true,
		"steps":
		[
			{
				"type": "show",
				"fen": "8/8/8/8/8/8/8/R7 w - - 0 1",
				"say": "Die Steine sind Mauern. Der Turm muss außen herum.",
				"walls":
				["a5", "b3", "c3", "d3", "e3", "f3", "g3", "b6", "c6", "d6", "e6", "f6", "g6"]
			},
			{
				"type": "collect",
				"fen": "8/8/8/8/8/8/8/R7 w - - 0 1",
				"say": "Sammle mit dem Turm alle Sterne!",
				"stars": ["a4", "h4", "h7"],
				"walls":
				["a5", "b3", "c3", "d3", "e3", "f3", "g3", "b6", "c6", "d6", "e6", "f6", "g6"],
				"par": 3
			},
		],
	},
	"sterne":
	{
		"title": "Springer sammelt Sterne",
		"icon": "w_knight",
		"minigame": true,
		"steps":
		[
			{
				"type": "collect",
				"fen": "8/8/8/8/8/8/8/1N6 w - - 0 1",
				"say": "Spring mit dem Pferd zu allen Sternen!",
				"stars": ["c3", "e4", "f6"],
				"par": 3
			},
		],
	},
	"schach":
	{
		"title": "Schach!",
		"icon": "w_king",
		"steps":
		[
			{
				"type": "show",
				"fen": "4k3/8/8/8/8/8/8/R3K3 w - - 0 1",
				"say": "Greift jemand den König an, heißt das: Schach!",
				"demo": "a1a8"
			},
			{
				"type": "move",
				"fen": "4k3/8/8/8/8/8/8/R5K1 w - - 0 1",
				"say": "Greif meinen König mit dem Turm an!",
				"goal": "check"
			},
			{
				"type": "show",
				"fen": "4k3/8/8/8/8/8/4r3/4K3 w - - 0 1",
				"say": "Steht dein König im Schach, musst du ihn retten.",
				"glow": ["e1", "e2"]
			},
			{
				"type": "move",
				"fen": "4k3/8/8/8/8/8/4r3/4K3 w - - 0 1",
				"say": "Rette deinen König! Du darfst den Turm schlagen.",
				"goal": "any"
			},
		],
	},
	"matt":
	{
		"title": "Schachmatt",
		"icon": "w_queen",
		"steps":
		[
			{
				"type": "show",
				"fen": "7k/1R6/8/8/8/8/8/R5K1 w - - 0 1",
				"say": "Kann der König nicht mehr fliehen, ist es Schachmatt.",
				"glow": ["h8"]
			},
			{
				"type": "move",
				"fen": "7k/1R6/8/8/8/8/8/R5K1 w - - 0 1",
				"say": "Zwei Türme machen eine Treppe. Setz mich matt!",
				"goal": "mate"
			},
			{
				"type": "move",
				"fen": "k7/7Q/1K6/8/8/8/8/8 w - - 0 1",
				"say": "Jetzt mit Dame und König. Setz mich matt!",
				"goal": "mate"
			},
		],
	},
	"patt":
	{
		"title": "Patt",
		"icon": "b_king",
		"steps":
		[
			{
				"type": "show",
				"fen": "k7/2Q5/1K6/8/8/8/8/8 b - - 0 1",
				"say": "Ich kann nicht ziehen, bin aber nicht im Schach.",
				"glow": ["a8"]
			},
			{
				"type": "show",
				"fen": "k7/2Q5/1K6/8/8/8/8/8 b - - 0 1",
				"say": "Das heißt Patt. Dann gewinnt keiner.",
				"glow": ["a8"]
			},
			{
				"type": "move",
				"fen": "k7/8/1K6/8/8/8/8/2Q5 w - - 0 1",
				"say": "Setz mich matt, aber kein Patt!",
				"goal": "mate"
			},
		],
	},
	"rochade":
	{
		"title": "Die Rochade",
		"icon": "w_rook",
		"steps":
		[
			{
				"type": "show",
				"fen": "4k3/8/8/8/8/8/8/4K2R w K - 0 1",
				"say": "Einmal im Spiel dürfen König und Turm zusammen ziehen.",
				"demo": "e1g1"
			},
			{
				"type": "show",
				"fen": "4k3/8/8/8/8/8/8/4K2R w K - 0 1",
				"say": "Der König geht zwei Schritte. Der Turm springt vorbei.",
				"glow": ["f1", "g1"]
			},
			{
				"type": "move",
				"fen": "4k3/8/8/8/8/8/8/4K2R w K - 0 1",
				"say": "Mach die Rochade: Zieh den König zwei Felder!",
				"goal": "castle"
			},
		],
	},
	"vorbei":
	{
		"title": "Schlagen im Vorbeigehen",
		"icon": "w_pawn",
		"steps":
		[
			{
				"type": "show",
				"fen": "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2",
				"say": "Mein Bauer ist gerade zwei Felder gesprungen.",
				"glow": ["d5"]
			},
			{
				"type": "show",
				"fen": "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2",
				"say": "Du darfst ihn trotzdem schräg schlagen. Aber nur sofort!",
				"glow": ["d6"]
			},
			{
				"type": "move",
				"fen": "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2",
				"say": "Schlag meinen Bauern im Vorbeigehen!",
				"goal": "ep"
			},
		],
	},
	"gabel":
	{
		"title": "Die Gabel",
		"icon": "w_knight",
		"steps":
		[
			{
				"type": "show",
				"fen": "r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1",
				"say": "Eine Gabel greift zwei Figuren auf einmal an.",
				"glow": ["a8", "e8"]
			},
			{
				"type": "move",
				"fen": "r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1",
				"say": "Spring so, dass du König und Turm angreifst!",
				"goal": "reach",
				"targets": ["c7"]
			},
		],
	},
	"fesselung":
	{
		"title": "Die Fesselung",
		"icon": "w_bishop",
		"steps":
		[
			{
				"type": "show",
				"fen": "4k3/3n4/8/1B6/8/8/8/4K3 b - - 0 1",
				"say": "Mein Pferd darf nicht weg. Sonst steht mein König im Schach.",
				"glow": ["d7", "e8"]
			},
			{
				"type": "move",
				"fen": "4k3/3n4/8/8/8/8/8/4KB2 w - - 0 1",
				"say": "Fessle mein Pferd mit deinem Läufer!",
				"goal": "reach",
				"targets": ["b5"]
			},
		],
	},
	"schaefer":
	{
		"title": "Das schnelle Matt",
		"icon": "w_queen",
		"steps":
		[
			{
				"type": "move",
				"fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
				"say": "Zieh den Bauern vor deinem König zwei Felder vor.",
				"goal": "reach",
				"from": ["e2"],
				"targets": ["e4"]
			},
			{
				"type": "move",
				"fen": "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
				"say": "Ich ziehe auch. Jetzt dein Läufer schräg nach c4!",
				"goal": "reach",
				"from": ["f1"],
				"targets": ["c4"]
			},
			{
				"type": "move",
				"fen": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR w KQkq - 2 3",
				"say": "Deine Dame geht schräg bis nach h5.",
				"goal": "reach",
				"from": ["d1"],
				"targets": ["h5"]
			},
			{
				"type": "show",
				"fen": "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
				"say": "Dame und Läufer zielen beide auf f7.",
				"glow": ["f7", "h5", "c4"]
			},
			{
				"type": "move",
				"fen": "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
				"say": "Schlag auf f7 und setz mich matt!",
				"goal": "mate"
			},
			{
				"type": "show",
				"fen": "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4",
				"say": "Spielst du Schwarz, pass gut auf f7 auf!",
				"glow": ["f7"]
			},
		],
	},
}

## Probespiel-Stufen: echte kleine Partien gegen Lumo. Ohne König gewinnt, wer
## zuerst einen Bauern ganz nach hinten bringt oder alle Figuren schlägt.
const TRIALS := {
	"t1":
	{
		"title": "Bauernrennen",
		"icon": "w_pawn",
		"fen": "8/2pppp2/8/8/8/8/2PPPP2/8 w - - 0 1",
		"goal": "race",
		"say": "Wer zuerst einen Bauern nach hinten bringt, gewinnt!"
	},
	"t2":
	{
		"title": "Bauern und Türme",
		"icon": "w_rook",
		"fen": "r6r/2pppp2/8/8/8/8/2PPPP2/R6R w - - 0 1",
		"goal": "race",
		"say": "Jetzt helfen die Türme. Bring einen Bauern nach hinten!"
	},
	"t3":
	{
		"title": "Läufer und Dame",
		"icon": "w_queen",
		"fen": "r1bq1b1r/2pppp2/8/8/8/8/2PPPP2/R1BQ1B1R w - - 0 1",
		"goal": "race",
		"say": "Läufer und Dame spielen mit. Pass gut auf sie auf!"
	},
	"t4":
	{
		"title": "Mit Springern",
		"icon": "w_knight",
		"fen": "rnbq1bnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1BNR w - - 0 1",
		"goal": "race",
		"say": "Alle Figuren außer dem König. Bring einen Bauern durch!"
	},
	"t5":
	{
		"title": "Das ganze Spiel",
		"icon": "w_king",
		"fen": RULES.START_FEN,
		"goal": "mate",
		"say": "Das echte Spiel! Ich erkläre jeden Zug. Zurück darfst du immer."
	},
}

## Der Lernweg für Kinder. Jeder Eintrag öffnet sich, wenn der vorige geschafft ist.
const PATH := [
	["lesson", "brett"],
	["lesson", "bauer"],
	["trial", "t1"],
	["lesson", "turm"],
	["lesson", "labyrinth"],
	["trial", "t2"],
	["lesson", "laeufer"],
	["lesson", "dame"],
	["trial", "t3"],
	["lesson", "springer"],
	["lesson", "sterne"],
	["trial", "t4"],
	["lesson", "koenig"],
	["lesson", "schach"],
	["lesson", "matt"],
	["trial", "t5"],
	["lesson", "patt"],
	["lesson", "rochade"],
	["lesson", "vorbei"],
	["lesson", "gabel"],
	["lesson", "fesselung"],
	["lesson", "schaefer"],
]


static func lesson(id: String) -> Dictionary:
	return LESSONS.get(id, {})


static func trial(id: String) -> Dictionary:
	return TRIALS.get(id, {})


static func title(kind: String, id: String) -> String:
	var entry: Dictionary = lesson(id) if kind == "lesson" else trial(id)
	return str(entry.get("title", id))


static func icon(kind: String, id: String) -> String:
	var entry: Dictionary = lesson(id) if kind == "lesson" else trial(id)
	return str(entry.get("icon", "w_pawn"))


## Erstellt die Stellung eines Schritts (auch ohne Könige).
static func make_rules(fen: String) -> RefCounted:
	var g: RefCounted = RULES.new()
	g.allow_kingless = true
	if not g.set_fen(fen):
		push_warning("[ChessSchool] Stellung unlesbar: " + fen)
	return g


static func squares(names: Array) -> Array[int]:
	var out: Array[int] = []
	for n: Variant in names:
		var sq := RULES.square_from_name(str(n))
		if sq >= 0:
			out.append(sq)
	return out


## Erlaubte Züge eines Schritts: Mauern versperren den Weg (Labyrinth).
static func allowed_moves(g: RefCounted, step: Dictionary) -> PackedInt32Array:
	var walls := squares(step.get("walls", []))
	var out := PackedInt32Array()
	for m: int in g.legal_moves():
		if walls.is_empty() or not _crosses(m, walls):
			out.append(m)
	return out


static func _crosses(m: int, walls: Array[int]) -> bool:
	var from := RULES.move_from(m)
	var to := RULES.move_to(m)
	if walls.has(to):
		return true
	var df := signi((to & 7) - (from & 7))
	var dr := signi((to >> 3) - (from >> 3))
	var steps := maxi(absi((to & 7) - (from & 7)), absi((to >> 3) - (from >> 3)))
	var straight := (
		(to & 7) == (from & 7)
		or (to >> 3) == (from >> 3)
		or absi((to & 7) - (from & 7)) == absi((to >> 3) - (from >> 3))
	)
	if not straight:
		return false  # Springer springt über Mauern.
	for i in range(1, steps):
		if walls.has(from + i * (df + dr * 8)):
			return true
	return false


## Prüft einen Tipp auf ein Feld.
static func tap_ok(step: Dictionary, sq: int) -> bool:
	match str(step.get("want", "")):
		"light":
			return RULES.is_light_square(sq)
		"dark":
			return not RULES.is_light_square(sq)
		"rank1":
			return (sq >> 3) == 0
	return squares(step.get("targets", [])).has(sq)


## Ist ein Zug die Lösung des Schritts? `g` ist die Stellung vor dem Zug.
static func move_ok(step: Dictionary, g: RefCounted, m: int) -> bool:
	if not allowed_moves(g, step).has(m):
		return false
	# Optional: nur die genannte Figur darf ziehen (geführte Eröffnung).
	var from_squares := squares(step.get("from", []))
	if not from_squares.is_empty() and not from_squares.has(RULES.move_from(m)):
		return false
	var to := RULES.move_to(m)
	var flags := RULES.move_flags(m)
	var targets := squares(step.get("targets", []))
	match str(step.get("goal", "")):
		"reach":
			return targets.has(to)
		"promote":
			return (flags & RULES.F_PROMO) != 0 and (targets.is_empty() or targets.has(to))
		"castle":
			return (flags & RULES.F_CASTLE) != 0
		"ep":
			return (flags & RULES.F_EP) != 0
		"any":
			return true
		"check", "mate":
			g.make_move(m)
			var check: bool = g.in_check()
			var mate: bool = check and not g.has_legal_move()
			g.unmake_move()
			return mate if str(step.goal) == "mate" else check
	return false


## Eine Lösung für Tests und für „Zeig es mir“.
static func solution(step: Dictionary) -> Array:
	var g: RefCounted = make_rules(str(step.get("fen", EMPTY)))
	match str(step.get("type", "")):
		"tap":
			for sq in 64:
				if tap_ok(step, sq):
					return [sq]
			return []
		"move":
			for m: int in allowed_moves(g, step):
				if move_ok(step, g, m):
					return [m]
			return []
		"collect":
			return collect_route(step)
	return []


## Kürzeste Zugfolge, die alle Sterne einsammelt (Breitensuche, nur die eine
## Figur des Kindes zieht; nach jedem Zug ist das Kind wieder dran).
static func collect_route(step: Dictionary) -> Array:
	var g: RefCounted = make_rules(str(step.get("fen", EMPTY)))
	var stars := squares(step.get("stars", []))
	var start_sq := -1
	for sq in 64:
		if g.board[sq] != 0 and (g.board[sq] >> 3) == 0:
			start_sq = sq
			break
	if start_sq < 0:
		return []
	var full := (1 << stars.size()) - 1
	var queue: Array = [[start_sq, 0, []]]
	var seen := {"%d:%d" % [start_sq, 0]: true}
	while not queue.is_empty():
		var node: Array = queue.pop_front()
		var at: int = node[0]
		var got: int = node[1]
		var path: Array = node[2]
		if got == full:
			return path
		if path.size() > 12:
			continue
		var probe: RefCounted = make_rules(fen_with_piece(g, start_sq, at))
		for m: int in allowed_moves(probe, step):
			var to := RULES.move_to(m)
			var mask := got
			var idx := stars.find(to)
			if idx >= 0:
				mask |= 1 << idx
			var key := "%d:%d" % [to, mask]
			if seen.has(key):
				continue
			seen[key] = true
			var next_path := path.duplicate()
			next_path.append([at, to])
			queue.append([to, mask, next_path])
	return []


## Die Ausgangsstellung, aber die Figur von `from` steht auf `to`.
static func fen_with_piece(g: RefCounted, from: int, to: int) -> String:
	var copy: RefCounted = make_rules(g.get_fen())
	var piece: int = copy.board[from]
	copy.board[from] = 0
	copy.board[to] = piece
	return copy.get_fen()


## Sterne einer Lektion nach Fehlern: ohne Fehler drei.
static func stars_for(mistakes: int) -> int:
	if mistakes <= 0:
		return 3
	return 2 if mistakes <= 2 else 1


## Sterne eines Mini-Spiels nach Zügen im Vergleich zur kürzesten Lösung.
static func collect_stars(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	return 2 if moves <= par + 3 else 1


## Ist ein Eintrag des Lernwegs offen? (Der erste immer, sonst nach dem vorigen.)
static func unlocked(index: int, done: Callable) -> bool:
	if index <= 0:
		return true
	if index >= PATH.size():
		return false
	var prev: Array = PATH[index - 1]
	return bool(done.call(str(prev[0]), str(prev[1])))


# --- Probespiel -------------------------------------------------------------


static func make_trial(id: String) -> RefCounted:
	var info := trial(id)
	return make_rules(str(info.get("fen", RULES.START_FEN)))


## Ergebnis einer Probespiel-Stellung nach einem Zug:
## "" läuft weiter, sonst "white", "black" oder "draw".
static func trial_result(id: String, g: RefCounted) -> String:
	var info := trial(id)
	if str(info.get("goal", "")) == "mate":
		var st: String = g.status()
		if st == "checkmate":
			return "white" if g.winner() == 0 else "black"
		return "" if st == "playing" else "draw"
	# Rennen: Ist ein Bauer (jetzt Dame) auf der letzten Reihe angekommen?
	var last: int = g.last_move()
	if last >= 0 and (RULES.move_flags(last) & RULES.F_PROMO) != 0:
		return "white" if g.side == 1 else "black"
	var count := [0, 0]
	for sq in 64:
		if g.board[sq] != 0:
			count[g.board[sq] >> 3] += 1
	if count[1] == 0:
		return "white"
	if count[0] == 0:
		return "black"
	# Wer im Rennen nicht mehr ziehen kann, hat verloren (klare Regel für Kinder).
	if not g.has_legal_move():
		return "black" if g.side == 0 else "white"
	if g.played.size() >= 160:
		return "draw"
	return ""
