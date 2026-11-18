extends SceneTree
## Regelkern von Lumo Schach ohne Szene: Perft gegen die bekannten
## Referenzzahlen, alle Sonderregeln, FEN und Spielstand.
##
## Standardlauf bleibt unter fünf Minuten. Die tiefen Perft-Zahlen laufen mit
## `-- --deep` (Grundstellung 5, Kiwipete 4, Stellung 3 Tiefe 5).

const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const SESSION = preload("res://scripts/games/chess/chess_session.gd")

const KIWIPETE := "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
const POS3 := "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
const POS4 := "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"
const POS5 := "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"

const PERFT_BASE := [
	["Grundstellung", RULES.START_FEN, [20, 400, 8902, 197281]],
	["Kiwipete", KIWIPETE, [48, 2039, 97862]],
	["Stellung 3", POS3, [14, 191, 2812, 43238]],
	["Stellung 4", POS4, [6, 264, 9467]],
	["Stellung 5", POS5, [44, 1486, 62379]],
]
const PERFT_DEEP := [
	["Grundstellung", RULES.START_FEN, 5, 4865609],
	["Kiwipete", KIWIPETE, 4, 4085603],
	["Stellung 3", POS3, 5, 674624],
]

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[ChessRules] " + label)


func _run() -> void:
	var started := Time.get_ticks_msec()
	_perft_base()
	if OS.get_cmdline_user_args().has("--deep"):
		_perft_deep()
	_fen_roundtrip()
	_castling()
	_en_passant()
	_promotion()
	_mate_and_stalemate()
	_draws()
	_san()
	_take_back_and_hash()
	_session()
	print("CHESS_RULES_%s checks=%d failures=%d time=%.1fs" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(),
		(Time.get_ticks_msec() - started) / 1000.0,
	])
	quit(0 if failures.is_empty() else 1)


func _perft_base() -> void:
	for entry: Array in PERFT_BASE:
		var game: RefCounted = RULES.new(entry[1])
		var want: Array = entry[2]
		for d in want.size():
			var t0 := Time.get_ticks_usec()
			var nodes: int = game.perft(d + 1)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			print("[ChessRules] perft %s Tiefe %d = %d (Soll %d) %.0f ms" % [entry[0], d + 1, nodes, want[d], ms])
			_check(nodes == int(want[d]), "perft %s Tiefe %d: %d statt %d" % [entry[0], d + 1, nodes, want[d]])
			_check(game.get_fen() == RULES.new(entry[1]).get_fen(), "perft %s lässt Stellung unverändert" % entry[0])


func _perft_deep() -> void:
	for entry: Array in PERFT_DEEP:
		var game: RefCounted = RULES.new(entry[1])
		var t0 := Time.get_ticks_msec()
		var nodes: int = game.perft(entry[2])
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		print("[ChessRules] perft-tief %s Tiefe %d = %d (Soll %d) %.1f s" % [entry[0], entry[2], nodes, entry[3], secs])
		_check(nodes == int(entry[3]), "perft-tief %s: %d statt %d" % [entry[0], nodes, entry[3]])


func _fen_roundtrip() -> void:
	for fen: String in [RULES.START_FEN, KIWIPETE, POS3, POS4, POS5,
			"rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3"]:
		var game: RefCounted = RULES.new(fen)
		_check(game.get_fen() == fen, "FEN hin und zurück: " + fen)
		_check(game.hash == game.compute_hash(), "Schlüssel stimmt nach FEN")
	var game: RefCounted = RULES.new()
	for bad: String in ["", "8/8/8/8/8/8/8/8 w - - 0 1", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1",
			"knbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1", "P3k3/8/8/8/8/8/8/4K3 w - - 0 1",
			"4k3/8/8/8/8/8/8/4K3 x - - 0 1"]:
		_check(not game.set_fen(bad), "kaputte FEN abgelehnt: " + bad)
	_check(game.get_fen() == RULES.START_FEN, "kaputte FEN lässt Stand unverändert")


func _has(game: RefCounted, uci: String) -> bool:
	return game.move_from_uci(uci) >= 0


func _castling() -> void:
	var base := "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
	var game: RefCounted = RULES.new(base)
	_check(_has(game, "e1g1") and _has(game, "e1c1"), "Weiß darf beidseitig rochieren")
	_check(game.play_uci("e1g1"), "kurze Rochade spielbar")
	_check(game.piece_at(6) == RULES.KING and game.piece_at(5) == RULES.ROOK and game.piece_at(7) == 0,
		"kurze Rochade stellt König g1, Turm f1")
	_check(game.get_fen().split(" ")[2] == "kq", "nach Rochade nur noch Schwarz rochadeberechtigt")
	_check(game.play_uci("e8c8"), "lange Rochade Schwarz")
	_check(game.piece_at(58) == (RULES.KING | 8) and game.piece_at(59) == (RULES.ROOK | 8), "lange Rochade stellt König c8, Turm d8")
	# Durch Schach, aus dem Schach, ins Schach, verstellt, Turm/König gezogen.
	game = RULES.new("r3k2r/8/8/8/8/8/5r2/R3K2R w KQkq - 0 1")  # Turm f2 greift f1 an
	_check(not _has(game, "e1g1"), "keine Rochade über angegriffenes Feld f1")
	game.set_fen("r3k2r/8/8/8/8/8/4r3/R3K2R w KQkq - 0 1")
	_check(not _has(game, "e1g1") and not _has(game, "e1c1"), "keine Rochade aus dem Schach")
	game.set_fen("r3k2r/8/8/8/8/8/6r1/R3K2R w KQkq - 0 1")
	_check(not _has(game, "e1g1") and _has(game, "e1c1"), "keine Rochade ins Schach (g1)")
	game.set_fen("r3k2r/8/8/8/8/8/1r6/R3K2R w KQkq - 0 1")
	_check(_has(game, "e1c1"), "lange Rochade erlaubt, wenn nur b1 angegriffen ist")
	game.set_fen("r3k2r/8/8/8/8/8/8/RN2K1NR w KQkq - 0 1")
	_check(not _has(game, "e1g1") and not _has(game, "e1c1"), "keine Rochade mit Figur dazwischen")
	game.set_fen(base)
	game.play_uci("h1h2")
	game.play_uci("a8a7")
	game.play_uci("h2h1")
	game.play_uci("a7a8")
	_check(not _has(game, "e1g1") and _has(game, "e1c1"), "gezogener Turm verliert sein Rochaderecht")
	game.set_fen(base)
	game.play_uci("a1a8")
	_check(game.get_fen().split(" ")[2] == "Kk", "geschlagener Turm nimmt Rochaderecht mit")
	game.set_fen(base)
	game.play_uci("e1e2")
	game.play_uci("e8e7")
	game.play_uci("e2e1")
	game.play_uci("e7e8")
	_check(game.get_fen().split(" ")[2] == "-", "gezogener König verliert beide Rechte")


func _en_passant() -> void:
	var game: RefCounted = RULES.new("4k3/8/8/8/3p4/8/4P3/4K3 w - - 0 1")
	game.play_uci("e2e4")
	_check(game.get_fen().split(" ")[3] == "e3", "Doppelschritt setzt en-passant-Feld")
	_check(_has(game, "d4e3"), "en passant möglich")
	game.play_uci("d4e3")
	_check(game.piece_at(RULES.square_from_name("e4")) == 0, "en passant entfernt geschlagenen Bauern")
	_check(game.piece_at(RULES.square_from_name("e3")) == (RULES.PAWN | 8), "Schläger steht auf e3")
	game.take_back()
	_check(game.piece_at(RULES.square_from_name("e4")) == RULES.PAWN, "Zurücknehmen stellt Bauern wieder hin")
	# Nur sofort: nach einem anderen Zug verfällt das Recht.
	game.play_uci("e8d8")
	game.play_uci("e1d1")
	_check(not _has(game, "d4e3"), "en passant nur direkt danach")
	# Gefesselt entlang der Reihe: en passant würde den König freilegen.
	game.set_fen("8/8/8/K2pP2r/8/8/8/7k w - d6 0 1")
	_check(not _has(game, "e5d6"), "en passant verboten, wenn er den König entblößt")


func _promotion() -> void:
	var game: RefCounted = RULES.new("8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	var promos := 0
	for m: int in game.legal_moves():
		if RULES.move_promo(m) != 0:
			promos += 1
	_check(promos == 4, "vier Umwandlungen (Dame, Turm, Läufer, Springer)")
	_check(game.play_uci("e7e8"), "Umwandlung ohne Angabe")
	_check(game.piece_at(60) == RULES.QUEEN, "Vorgabe ist die Dame")
	game.take_back()
	_check(game.play_uci("e7e8n"), "Kind wählt Springer")
	_check(game.piece_at(60) == RULES.KNIGHT, "Springer steht auf e8")
	game.take_back()
	_check(game.piece_at(52) == RULES.PAWN and game.piece_at(60) == 0, "Zurücknehmen macht wieder einen Bauern")


func _mate_and_stalemate() -> void:
	var game: RefCounted = RULES.new()
	for u: String in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		game.play_uci(u)
	_check(game.status() == "checkmate", "Narrenmatt ist Matt")
	_check(game.winner() == RULES.BLACK, "Schwarz gewinnt das Narrenmatt")
	game.set_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	_check(game.status() == "stalemate", "Patt erkannt")
	_check(not game.in_check(), "Patt ist kein Schach")
	game.set_fen("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	game.play_uci("a1a8")
	_check(game.status() == "checkmate", "Grundreihenmatt")
	game.set_fen("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
	game.play_uci("h1h8")
	_check(game.in_check() and game.status() == "playing", "Schach, aber kein Matt")


func _draws() -> void:
	var game: RefCounted = RULES.new()
	for i in 2:
		for u: String in ["g1f3", "g8f6", "f3g1", "f6g8"]:
			game.play_uci(u)
	_check(game.repetition_count() == 3, "Grundstellung dreimal")
	_check(game.status() == "draw_repetition", "dreifache Stellung ist Remis")
	game.take_back()
	_check(game.status() == "playing", "nach Zurücknehmen läuft das Spiel")
	game.set_fen("4k3/8/8/8/8/8/8/R3K3 w - - 99 80")
	game.play_uci("a1a2")
	_check(game.status() == "draw_fifty", "50-Züge-Regel")
	game.set_fen("4k3/8/8/8/8/8/R7/4K3 w - - 98 80")
	game.play_uci("a2a3")
	_check(game.status() == "playing", "99 Halbzüge reichen nicht")
	game.set_fen("6k1/R7/6K1/8/8/8/8/8 w - - 99 80")
	game.play_uci("a7a8")
	_check(game.status() == "checkmate", "Matt geht vor 50-Züge-Regel")
	for fen: String in ["4k3/8/8/8/8/8/8/4K3 w - - 0 1", "4k3/8/8/8/8/8/8/4KN2 w - - 0 1",
			"4k3/8/8/8/8/8/8/4KB2 w - - 0 1", "2b1k3/8/8/8/8/8/8/4KB2 w - - 0 1"]:
		game.set_fen(fen)
		_check(game.status() == "draw_material", "unzureichendes Material: " + fen)
	for fen: String in ["4k3/8/8/8/8/8/8/2B1KB2 w - - 0 1", "3bk3/8/8/8/8/8/8/4KB2 w - - 0 1",
			"4k3/8/8/8/8/8/8/3NKN2 w - - 0 1", "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"]:
		game.set_fen(fen)
		_check(game.status() == "playing", "genug Material: " + fen)
	# Wiederholung zählt en passant mit: gleiche Felder, aber andere Möglichkeiten.
	game.set_fen("4k3/8/8/8/3p4/8/4P3/4K3 w - - 0 1")
	game.play_uci("e2e4")
	var with_ep: int = game.hash
	game.set_fen("4k3/8/8/8/3pP3/8/8/4K3 b - - 0 1")
	_check(with_ep != game.hash, "en-passant-Möglichkeit ändert die Stellung")


func _san() -> void:
	var game: RefCounted = RULES.new()
	_check(game.to_san(game.move_from_uci("g1f3")) == "Nf3", "SAN Nf3")
	_check(game.to_san(game.move_from_uci("g1f3"), true) == "Sf3", "deutsch Sf3")
	game.set_fen("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
	_check(game.to_san(game.move_from_uci("e1g1")) == "O-O", "SAN O-O")
	game.set_fen("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
	_check(game.to_san(game.move_from_uci("a1d1")) == "Rad1", "SAN mit Linien-Unterscheidung")
	game.set_fen("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	_check(game.to_san(game.move_from_uci("a1a8")) == "Ra8#", "SAN Matt")
	game.set_fen("8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	_check(game.to_san(game.move_from_uci("e7e8q")) == "e8=Q", "SAN Umwandlung")


func _take_back_and_hash() -> void:
	var game: RefCounted = RULES.new(KIWIPETE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fens: Array[String] = [game.get_fen()]
	for i in 60:
		var moves: PackedInt32Array = game.legal_moves()
		if moves.is_empty() or game.is_over():
			break
		game.play(moves[rng.randi_range(0, moves.size() - 1)])
		fens.append(game.get_fen())
		_check(game.hash == game.compute_hash(), "Schlüssel stimmt nach Zug %d" % i)
	while game.take_back():
		fens.pop_back()
		_check(game.get_fen() == fens[-1], "Zurücknehmen stellt FEN wieder her")
	_check(game.get_fen() == KIWIPETE, "alles zurückgenommen")


func _session() -> void:
	var path := "user://chess_rules_regression_session.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var session: RefCounted = SESSION.new(path)
	var game: RefCounted = RULES.new()
	for u: String in ["e2e4", "e7e5", "g1f3"]:
		game.play_uci(u)
	session.store_game("play", game, {"level": 2, "color": 0})
	session.data.school["lesson_rook"] = 3
	session.save_file()
	var again: RefCounted = SESSION.new(path)
	_check(again.load_file(), "Spielstand lesbar")
	var back: Dictionary = again.resume_game("play")
	_check(not back.is_empty(), "Partie wieder da")
	var restored: RefCounted = back.get("rules")
	_check(restored != null and restored.get_fen() == game.get_fen(), "gleiche Stellung nach Laden")
	_check(int(back.get("meta", {}).get("level", -1)) == 2, "Stufe bleibt")
	_check(int(again.data.school.get("lesson_rook", 0)) == 3, "Schulfortschritt bleibt")
	_check(restored.take_back() and restored.get_fen() == RULES.new("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2").get_fen(),
		"Zurücknehmen nach Laden")
	# Alte Fassung ohne Schule und mit kaputter Partie: wird ergänzt bzw. verworfen.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"v": 1, "games": {"play": {"start": "kaputt", "moves": []}}}))
	file.close()
	var old: RefCounted = SESSION.new(path)
	_check(old.load_file(), "Fassung 1 wird gelesen")
	_check(old.data.school is Dictionary, "Fassung 1 bekommt Schulstand")
	_check(old.resume_game("play").is_empty(), "kaputte Partie wird verworfen")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{kein json")
	file.close()
	_check(not SESSION.new(path).load_file(), "kaputte Datei ergibt leeren Stand")
	DirAccess.remove_absolute(path)
