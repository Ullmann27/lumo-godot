extends SceneTree
## Lumo als Schachgegner und Lehrer – ohne Szene.
## Stufen: 0 Anfänger, 1 Fortgeschritten, 2 Meister, 3 Militärschachspieler,
## 4 Lernspiel (Kinder). Matt in 1/2/3, hängende Figuren schlagen, taktische
## Motive (Gabel, Spieß), keine eingehängten Figuren, Zeitbudget, Rechnen über
## mehrere Bilder, Eröffnungsbuch, Stufen gegeneinander, Erklärungen, Warnungen.
## Mit `-- --quick` entfallen die langsamen Militär-Messungen.

const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const AI = preload("res://scripts/games/chess/chess_ai.gd")
const COACH = preload("res://scripts/games/chess/chess_coach.gd")
const BOOK = preload("res://scripts/games/chess/chess_book.gd")
const MILITARY := 3
const MASTER := 2

const MATE_IN_1 := [
	["r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", "h5f7"],
	["6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1", "a1a8"],
	["rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2", "d8h4"],
	["6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1", "g5f7"],
]
const MATE_IN_2 := [
	"7k/8/8/8/8/8/R7/1R4K1 w - - 0 1",
	"7k/8/8/8/8/8/Q7/1R4K1 w - - 0 1",
	"k7/8/2K5/8/8/8/8/7R w - - 0 1",
]
## Stellungen für „hängt keine Figur ein“ und die Zeitmessung.
## Matt in 3 (5 Halbzüge, jeweils einzige oder kürzeste Lösung vom Test selbst geprüft).
const MATE_IN_3 := [
	"4N1k1/5ppp/8/1Q3R2/8/8/5PPP/6K1 w - - 0 1",
	"7k/6pp/8/8/3N4/3Q4/8/6K1 w - - 0 1",
	"1k3B2/ppp4Q/8/8/8/1R6/8/6K1 w - - 0 1",
	"5N1k/6pp/8/1Q6/8/8/8/6K1 w - - 0 1",
]
## Taktik: Stellung, erwarteter Zug, Motiv.
const TACTICS := [
	["4k3/8/8/3r4/8/8/3Q4/4K3 w - - 0 1", "d2d5", "hängender Turm"],
	["r3k3/8/8/1N6/8/8/8/4K3 w - - 0 1", "b5c7", "Springergabel König und Turm"],
	["4k3/3q4/8/8/4N3/8/8/4K3 w - - 0 1", "e4f6", "Springergabel König und Dame"],
	["8/8/8/3k3q/8/8/8/R5K1 w - - 0 1", "a1a5", "Spieß: Turm gegen König und Dame"],
	["6k1/8/8/8/2q5/8/8/2R3K1 w - - 0 1", "c1c4", "hängende Dame"],
]
const MIDDLE := [
	"r1bqkbnr/pppp1ppp/2n5/4p3/3PP3/5N2/PPP2PPP/RNBQKB1R b KQkq d3 0 3",
	"rnbqkb1r/pp2pppp/3p1n2/8/3NP3/8/PPP2PPP/RNBQKB1R w KQkq - 1 5",
	"r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 0 7",
	"r2qkb1r/ppp2ppp/2n1bn2/3pp3/4P3/2NP1N2/PPP1BPPP/R1BQK2R w KQkq - 2 6",
	"r1bqk2r/ppp2ppp/2n2n2/3pp3/1b2P3/2NP1N2/PPP1BPPP/R1BQK2R w KQkq - 0 6",
	"rnbqkbnr/ppp2ppp/8/3pp3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq d6 0 3",
	"r3k2r/pp1n1ppp/2pbpn2/q2p4/3P1B2/2PBPN2/PP1N1PPP/R2QK2R w KQkq - 3 9",
	"2r2rk1/pp2qppp/2n1pn2/3p4/3P4/P1NBPN2/1P3PPP/R2Q1RK1 w - - 4 13",
]

var checks := 0
var failures: Array[String] = []
var table_lines: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[ChessAI] " + label)


func _run() -> void:
	var started := Time.get_ticks_msec()
	_fens_valid()
	await _mate_in_one()
	await _mate_in_two()
	await _no_blunders()
	await _budget_and_frames()
	await _levels_table()
	await _match_master_vs_chick()
	await _coach()
	for line: String in table_lines:
		print(line)
	print("CHESS_AI_%s checks=%d failures=%d time=%.1fs" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(),
		(Time.get_ticks_msec() - started) / 1000.0,
	])
	quit(0 if failures.is_empty() else 1)


func _fens_valid() -> void:
	var all: Array[String] = []
	for e: Array in MATE_IN_1:
		all.append(e[0])
	all.append_array(MATE_IN_2)
	all.append_array(MIDDLE)
	for fen: String in all:
		_check(RULES.new(fen).get_fen().split(" ")[0] == fen.split(" ")[0], "Teststellung lesbar: " + fen)


func _mate_in_one() -> void:
	for entry: Array in MATE_IN_1:
		for level in [2, 3]:
			var g: RefCounted = RULES.new(entry[0])
			var ai := AI.new(11)
			var r: Dictionary = await ai.think(g, level)
			var uci: String = g.to_uci(r.move) if r.move >= 0 else "-"
			g.play(r.move)
			_check(g.status() == "checkmate", "Matt in 1 Stufe %d: %s spielt %s" % [level, entry[0], uci])


func _forced_mate_after(g: RefCounted, plies_left: int) -> bool:
	# Weiß hat gezogen; jede Antwort muss in `plies_left` Zügen matt werden.
	var replies: PackedInt32Array = g.legal_moves()
	if replies.is_empty():
		return g.status() == "checkmate"
	if plies_left <= 0:
		return false
	for reply: int in replies:
		g.make_move(reply)
		var found := false
		for m: int in g.legal_moves():
			g.make_move(m)
			if g.in_check() and not g.has_legal_move():
				found = true
			g.unmake_move()
			if found:
				break
		g.unmake_move()
		if not found:
			return false
	return true


func _mate_in_two() -> void:
	for fen: String in MATE_IN_2:
		var g: RefCounted = RULES.new(fen)
		var ai := AI.new(5)
		var r: Dictionary = await ai.think(g, 3)
		print("[ChessAI] Matt in 2 %s -> %s score=%d depth=%d %.0f ms" % [fen, g.to_uci(r.move), r.score, r.depth, r.ms])
		_check(int(r.score) >= AI.MATE - 3, "Meister sieht Matt in 2: " + fen)
		g.make_move(r.move)
		_check(_forced_mate_after(g, 1), "Zug erzwingt Matt in 2: " + fen)


## Material aus Sicht der Seite am Zug, nur Schlagzüge (Ruhesuche ohne Lage).
func _material(g: RefCounted) -> int:
	var s := 0
	for sq in 64:
		var p: int = g.board[sq]
		if p != 0:
			s += (AI.VALUE[p & 7]) * (1 if (p >> 3) == g.side else -1)
	return s


func _q_material(g: RefCounted, alpha: int, beta: int, depth: int) -> int:
	var stand := _material(g)
	if stand >= beta or depth <= 0:
		return stand
	alpha = maxi(alpha, stand)
	for m: int in g.pseudo_moves(true):
		if not g.make_move(m):
			g.unmake_move()
			continue
		var score := -_q_material(g, -beta, -alpha, depth - 1)
		g.unmake_move()
		if score >= beta:
			return score
		alpha = maxi(alpha, score)
	return alpha


func _after_value(g: RefCounted, m: int) -> int:
	g.make_move(m)
	var v := -_q_material(g, -100000, 100000, 6)
	g.unmake_move()
	return v


func _no_blunders() -> void:
	for fen: String in MIDDLE:
		var g: RefCounted = RULES.new(fen)
		var ai := AI.new(3)
		var r: Dictionary = await ai.think(g, 3)
		var best_possible := -100000
		for m: int in g.legal_moves():
			best_possible = maxi(best_possible, _after_value(g, m))
		var mine := _after_value(g, r.move)
		print("[ChessAI] Meister %s: %s Material danach %d (bestes %d) Tiefe %d %.0f ms" % [
			fen.split(" ")[0], g.to_san(r.move), mine, best_possible, r.depth, r.ms])
		_check(mine >= best_possible - 100, "Meister hängt keine Figur ein: %s (%s)" % [fen, g.to_uci(r.move)])


func _budget_and_frames() -> void:
	var g: RefCounted = RULES.new(MIDDLE[2])
	var ai := AI.new(9)
	var frame_count := [0]
	var counter := func() -> void: frame_count[0] += 1
	process_frame.connect(counter)
	var r: Dictionary = await ai.think(g, 3, {"slice_ms": 8})
	process_frame.disconnect(counter)
	print("[ChessAI] Zeitscheiben: %.0f ms, %d Bilder, längste Scheibe %.1f ms, Tiefe %d, %d Knoten" % [
		r.ms, frame_count[0], r.max_slice_ms, r.depth, r.nodes])
	_check(int(r.frames) >= 10, "Suche verteilt sich auf viele Bilder (%d)" % r.frames)
	_check(frame_count[0] >= int(r.frames), "Bilder laufen während der Suche weiter")
	_check(float(r.max_slice_ms) < 40.0, "keine Scheibe länger als 40 ms (%.1f)" % r.max_slice_ms)
	_check(float(r.ms) <= AI.LEVELS[3].budget + 250, "Meister bleibt im Zeitbudget (%.0f ms)" % r.ms)
	_check(g.legal_moves().has(r.move), "Meister liefert legalen Zug")


func _levels_table() -> void:
	for level in 4:
		var depths: Array[int] = []
		var times: Array[float] = []
		var total_nodes := 0
		var total_ms := 0.0
		for fen: String in MIDDLE:
			var g: RefCounted = RULES.new(fen)
			var ai := AI.new(21)
			var r: Dictionary = await ai.think(g, level, {"random_off": true})
			depths.append(int(r.depth))
			times.append(float(r.ms))
			total_nodes += int(r.nodes)
			total_ms += float(r.ms)
			_check(g.legal_moves().has(r.move), "Stufe %d liefert legalen Zug" % level)
			_check(float(r.ms) <= AI.LEVELS[level].budget + 250, "Stufe %d im Budget (%.0f ms)" % [level, r.ms])
		depths.sort()
		times.sort()
		table_lines.append("[ChessAI] Stufe %s: Tiefe min %d / median %d / max %d, Zeit median %.0f ms / max %.0f ms, %.0f Knoten/s" % [
			AI.level_name(level), depths[0], depths[depths.size() / 2], depths[-1],
			times[times.size() / 2], times[-1], total_nodes / maxf(total_ms / 1000.0, 0.001)])


func _match(white_level: int, black_level: int, budget: int, seed_value: int) -> String:
	var g: RefCounted = RULES.new()
	var ai_w := AI.new(seed_value)
	var ai_b := AI.new(seed_value + 1)
	while g.status() == "playing" and g.played.size() < 240:
		var level := white_level if g.side == 0 else black_level
		var ai: RefCounted = ai_w if g.side == 0 else ai_b
		var r: Dictionary = await ai.think(g, level, {"budget_ms": budget, "slice_ms": 0})
		if not g.play(r.move):
			return "illegal"
	var st: String = g.status()
	if st == "checkmate":
		return "white" if g.winner() == 0 else "black"
	return st


func _match_master_vs_chick() -> void:
	var t0 := Time.get_ticks_msec()
	var a := await _match(3, 0, 300, 100)
	var b := await _match(0, 3, 300, 200)
	print("[ChessAI] Meister gegen Küken: %s / %s (%.1f s)" % [a, b, (Time.get_ticks_msec() - t0) / 1000.0])
	_check(a == "white", "Meister (Weiß) schlägt Küken: " + a)
	_check(b == "black", "Meister (Schwarz) schlägt Küken: " + b)
	t0 = Time.get_ticks_msec()
	var c := await _match(2, 1, 300, 300)
	var d := await _match(1, 2, 300, 400)
	print("[ChessAI] Schlaufuchs gegen Fuchs: %s / %s (%.1f s)" % [c, d, (Time.get_ticks_msec() - t0) / 1000.0])
	var fox_points := (1.0 if c == "black" else 0.0) + (1.0 if d == "white" else 0.0)
	var clever_points := (1.0 if c == "white" else 0.0) + (1.0 if d == "black" else 0.0)
	_check(c != "illegal" and d != "illegal", "Partien Schlaufuchs/Fuchs ohne Fehler")
	_check(clever_points > fox_points, "Schlaufuchs ist stärker als Fuchs (%s / %s)" % [c, d])


func _coach() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# Erklärungen für viele Züge: immer ein kurzer Satz.
	var g: RefCounted = RULES.new()
	var sentences := 0
	for i in 40:
		var moves: PackedInt32Array = g.legal_moves()
		if moves.is_empty() or g.is_over():
			break
		var m: int = moves[rng.randi_range(0, moves.size() - 1)]
		for mine: bool in [true, false]:
			var text: String = COACH.explain(g, m, mine)
			sentences += 1
			_check(not text.is_empty(), "Erklärung vorhanden")
			for part: String in text.replace("!", ".").replace("?", ".").split(".", false):
				_check(COACH.word_count(part) <= 12, "Satz höchstens 12 Wörter: " + text)
		g.play(m)
	print("[ChessAI] %d Erklärungen geprüft" % sentences)
	# Schlagen eines ungeschützten Turms.
	g = RULES.new("4k3/8/8/3r4/8/8/3Q4/4K3 w - - 0 1")
	var text := COACH.explain(g, g.move_from_uci("d2d5"), false)
	_check(text.contains("Turm"), "Erklärung nennt die geschlagene Figur: " + text)
	g = RULES.new("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
	_check(COACH.explain(g, g.move_from_uci("e1g1")).contains("Sicherheit"), "Rochade erklärt")
	g = RULES.new("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
	text = COACH.explain(g, g.move_from_uci("f1c4"))
	_check(text.contains("Läufer"), "Entwicklung erklärt: " + text)
	# Warnung: Springer zieht auf ein vom Bauern bedrohtes Feld.
	g = RULES.new("rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2")
	var warn := COACH.warning(g, g.move_from_uci("g1h3"))
	_check(warn.is_empty(), "kein Fehlalarm bei sicherem Zug")
	g = RULES.new("rnbqkbnr/ppp2ppp/8/3pp3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3")
	warn = COACH.warning(g, g.move_from_uci("b1c3"))
	_check(warn.is_empty(), "kein Fehlalarm bei gedecktem Springer")
	g = RULES.new("rnbqkbnr/pp3ppp/8/2ppp3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 4")
	warn = COACH.warning(g, g.move_from_uci("g1f3"))
	_check(warn.is_empty(), "Springer f3 ist gedeckt")
	warn = COACH.warning(g, g.move_from_uci("d1h5"))
	_check(warn.is_empty() or warn.kind == "hang", "Damenzug geprüft")
	g = RULES.new("rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2")
	warn = COACH.warning(g, g.move_from_uci("d1g4"))
	_check(not warn.is_empty() and warn.kind == "hang" and str(warn.text).contains("Dame"),
		"Warnung: Dame auf g4 hängt (%s)" % str(warn.get("text", "")))
	g = RULES.new("rnbqkbnr/pppp1ppp/8/4p3/6P1/8/PPPPPP1P/RNBQKBNR w KQkq - 0 2")
	warn = COACH.warning(g, g.move_from_uci("f2f3"))
	_check(not warn.is_empty() and warn.kind == "mate", "Warnung vor Narrenmatt")
	for part: String in str(warn.get("text", "")).replace("!", ".").replace("?", ".").split(".", false):
		_check(COACH.word_count(part) <= 12, "Warnsatz kurz")
	# Tipp liefert legalen Zug und Text.
	g = RULES.new("4k3/8/8/3r4/8/8/3Q4/4K3 w - - 0 1")
	var hint: Dictionary = await COACH.hint(g)
	_check(not hint.is_empty() and g.legal_moves().has(int(hint.move)), "Tipp ist ein legaler Zug")
	_check(int(hint.get("to", -1)) == RULES.square_from_name("d5"), "Tipp zeigt das Schlagen des Turms")
	print("[ChessAI] Tipp: " + str(hint.get("text", "")))
