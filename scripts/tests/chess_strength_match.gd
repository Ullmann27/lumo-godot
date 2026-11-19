extends SceneTree
## Stärkemessung: Stufe gegen Stufe (ganze Partien, beide Farben).
## Aufruf: godot --headless --path . --script res://scripts/tests/chess_strength_match.gd
##   -- [paarungen] [eröffnungen] [zeitfaktor]
## Beispiel: -- 1:0,2:1,3:2 4 0.25
## Paarung "a:b" = Stufe a (stärker) gegen Stufe b. Jede Eröffnung wird mit
## beiden Farben gespielt (also 2 × Eröffnungen Partien je Paarung). Der
## Zeitfaktor kürzt die Budgets beider Stufen gleichmäßig (Verhältnis bleibt).
## Ausgang: Matt/Patt/Remisregeln; nach 200 Halbzügen wird nach Material
## gewertet (≥ 3 Bauern Vorsprung = Sieg, sonst Remis) und so gekennzeichnet.

const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const AI = preload("res://scripts/games/chess/chess_ai.gd")
const BOOK = preload("res://scripts/games/chess/chess_book.gd")

var lines_out: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _material(g: RefCounted) -> int:
	var s := 0
	for sq in 64:
		var p: int = g.board[sq]
		if p != 0:
			s += AI.VALUE[p & 7] * (1 if (p >> 3) == 0 else -1)
	return s


## Ergebnis aus Sicht von Weiß: 1, 0.5, 0 und eine kurze Beschreibung.
func _game(white: int, black: int, opening: String, factor: float, seed_value: int) -> Array:
	var g: RefCounted = RULES.new()
	for uci: String in opening.split(" ", false):
		g.play_uci(uci)
	var ai_w := AI.new(seed_value)
	var ai_b := AI.new(seed_value + 7)
	var depth_sum := [0, 0]
	var depth_n := [0, 0]
	while g.status() == "playing" and g.played.size() < 200:
		var level := white if g.side == 0 else black
		var ai: RefCounted = ai_w if g.side == 0 else ai_b
		var budget := int(AI.level_config(level).budget * factor)
		var r: Dictionary = await ai.think(g, level, {"budget_ms": maxi(budget, 50), "slice_ms": 0})
		if not bool(r.get("book", false)) and int(r.depth) > 0:
			depth_sum[g.side] += int(r.depth)
			depth_n[g.side] += 1
		if not g.play(int(r.move)):
			return [0.0 if g.side == 0 else 1.0, "illegal"]
	var st: String = g.status()
	var depth_text := (
		"Ø Tiefe W %.1f / S %.1f"
		% [float(depth_sum[0]) / maxi(depth_n[0], 1), float(depth_sum[1]) / maxi(depth_n[1], 1)]
	)
	if st == "checkmate":
		return [
			1.0 if g.winner() == 0 else 0.0,
			"Matt nach %d Halbzügen, %s" % [g.played.size(), depth_text]
		]
	if st != "playing":
		return [0.5, "%s nach %d Halbzügen, %s" % [st, g.played.size(), depth_text]]
	var mat := _material(g)
	if mat >= 300:
		return [1.0, "nach Material gewertet (+%d), %s" % [mat, depth_text]]
	if mat <= -300:
		return [0.0, "nach Material gewertet (%d), %s" % [mat, depth_text]]
	return [0.5, "nach Material Remis (%d), %s" % [mat, depth_text]]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pairs_text := args[0] if args.size() > 0 else "1:0,2:1,3:2"
	var openings := int(args[1]) if args.size() > 1 else 2
	var factor := float(args[2]) if args.size() > 2 else 1.0
	var all_ok := true
	for pair: String in pairs_text.split(","):
		var strong := int(pair.get_slice(":", 0))
		var weak := int(pair.get_slice(":", 1))
		var points := 0.0
		var games := 0
		var t0 := Time.get_ticks_msec()
		for i in openings:
			var line: String = BOOK.LINES[(i * 7) % BOOK.LINES.size()]
			var opening := " ".join(line.split(" ").slice(0, 4))
			for strong_white: bool in [true, false]:
				var w := strong if strong_white else weak
				var b := weak if strong_white else strong
				var res: Array = await _game(
					w, b, opening, factor, 1000 + i * 31 + (0 if strong_white else 5)
				)
				var strong_points: float = res[0] if strong_white else 1.0 - float(res[0])
				points += strong_points
				games += 1
				var text := (
					"[ChessStrength] %s (%s) gegen %s (%s), Eröffnung %s: %s – %s"
					% [
						AI.level_name(w),
						"W",
						AI.level_name(b),
						"S",
						opening,
						"1-0" if res[0] == 1.0 else ("0-1" if res[0] == 0.0 else "½-½"),
						res[1]
					]
				)
				print(text)
				lines_out.append(text)
		var summary := (
			"[ChessStrength] %s gegen %s: %.1f / %d Punkte für %s (Zeitfaktor %.2f, %.0f s)"
			% [
				AI.level_name(strong),
				AI.level_name(weak),
				points,
				games,
				AI.level_name(strong),
				factor,
				(Time.get_ticks_msec() - t0) / 1000.0
			]
		)
		print(summary)
		lines_out.append(summary)
		if points <= games * 0.5:
			all_ok = false
	print("CHESS_STRENGTH_%s" % ("PASS" if all_ok else "FAIL"))
	quit(0 if all_ok else 1)
