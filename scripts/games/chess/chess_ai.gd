extends RefCounted
## Lumo als Schachgegner – eigene Suche in GDScript.
##
## Bekannte Verfahren (eigene Umsetzung): Negamax mit Alpha-Beta und
## Hauptvarianten-Suche, iterative Vertiefung, Transpositionstabelle über den
## Zobrist-Schlüssel, Zugsortierung (Tabellenzug, MVV-LVA, Killerzüge,
## History), Ruhesuche über Schlagzüge, Nullzug-Kürzung, Schachverlängerung.
## Bewertung: Material, Feldtabellen (Mittel- und Endspiel, gleitend),
## Königssicherheit, Bauernstruktur, Beweglichkeit, Läuferpaar.
##
## Die Suche läuft in Zeitscheiben: Nach `slice_ms` Rechenzeit wartet sie auf
## das nächste Bild (`await process_frame`), damit das Spiel nicht ruckelt.
## `think()` ist darum eine Coroutine: `var r = await ai.think(rules, stufe)`.
##
## Stufen: 0 Küken, 1 Fuchs, 2 Schlaufuchs, 3 Meister. Lumo sieht nur das
## Brett – keine versteckten Hilfen, kein Schummeln.

const RULES = preload("res://scripts/games/chess/chess_rules.gd")

const LEVEL_NAMES := ["Küken", "Fuchs", "Schlaufuchs", "Meister"]
## Je Stufe: höchste Tiefe, Zeitbudget (ms, Wanduhr), Zufallsrauschen in
## Hundertstel-Bauern, Anteil zufälliger Züge, Ruhesuche an.
const LEVELS := [
	{"depth": 1, "budget": 250, "noise": 0, "random": 0.75, "quiesce": false},
	{"depth": 1, "budget": 400, "noise": 45, "random": 0.12, "quiesce": true},
	{"depth": 3, "budget": 900, "noise": 15, "random": 0.0, "quiesce": true},
	{"depth": 20, "budget": 1800, "noise": 0, "random": 0.0, "quiesce": true},
]

const VALUE := [0, 100, 320, 330, 500, 900, 0]
const PHASE_W := [0, 0, 1, 1, 2, 4, 0]
const MATE := 30000
const MATE_BOUND := 29000
const INF := 32000
const TT_EXACT := 0
const TT_LOWER := 1
const TT_UPPER := 2
const TT_LIMIT := 250000
const MAX_PLY := 64

static var pst_mg: Array = []  # [typ] -> PackedInt32Array(64) aus Sicht von Weiß
static var pst_eg: Array = []

var rules: RefCounted
var tt: Dictionary = {}
var killers := PackedInt32Array()
var history := PackedInt32Array()
var nodes := 0
var stopped := false
var hard_deadline := 0
var slice_usec := 10000
var slice_deadline := 0
var frames := 0
var max_slice_usec := 0
var _slice_started := 0
var root_best := -1
var rng := RandomNumberGenerator.new()


static func ensure_tables() -> void:
	if not pst_mg.is_empty():
		return
	RULES.ensure_tables()
	pst_mg.resize(7)
	pst_eg.resize(7)
	for t in 7:
		var mg := PackedInt32Array()
		var eg := PackedInt32Array()
		mg.resize(64)
		eg.resize(64)
		for sq in 64:
			var f := sq & 7
			var r := sq >> 3
			# Abstand zur Brettmitte (0 in der Mitte, 3 am Rand).
			var cf := absf(f - 3.5) - 0.5
			var cr := absf(r - 3.5) - 0.5
			var center := cf + cr
			var m := 0
			var e := 0
			match t:
				1:
					m = r * 6 - 6
					if f in [3, 4]:
						m += [0, 0, 10, 22, 26, 20, 10, 0][r]
					elif f in [2, 5]:
						m += [0, 0, 4, 10, 12, 10, 6, 0][r]
					if r == 1 and f in [3, 4]:
						m -= 12
					e = [0, 0, 8, 18, 32, 52, 80, 0][r]
				2:
					m = int(-center * 10.0) + (8 if r >= 2 else -8)
					e = int(-center * 8.0)
				3:
					m = int(-center * 5.0) + (-12 if r == 0 else 0)
					if f == r or f == 7 - r:
						m += 8
					e = int(-center * 5.0)
				4:
					m = (14 if r == 6 else 0) + (6 if f in [3, 4] else 0) + (-4 if f in [0, 7] else 0)
					e = 6 if r == 6 else 0
				5:
					m = int(-center * 3.0) + (-6 if r == 0 else 0)
					e = int(-center * 7.0)
				6:
					m = [0, -14, -32, -45, -55, -60, -60, -60][r]
					m += [18, 24, 8, -6, -6, 6, 26, 18][f]
					e = int(-center * 12.0)
			mg[sq] = m
			eg[sq] = e
		pst_mg[t] = mg
		pst_eg[t] = eg


func _init(seed_value: int = 0) -> void:
	ensure_tables()
	killers.resize(MAX_PLY * 2)
	history.resize(64 * 64)
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())


static func level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 0, 3)]


# --- Bewertung --------------------------------------------------------------


## Bewertung aus Sicht der Seite am Zug, in Hundertstel-Bauern.
func evaluate(g: RefCounted) -> int:
	var b: PackedInt32Array = g.board
	var mg := 0
	var eg := 0
	var phase := 0
	var pawn_min := [PackedInt32Array([9, 9, 9, 9, 9, 9, 9, 9]), PackedInt32Array([9, 9, 9, 9, 9, 9, 9, 9])]
	var pawn_max := [PackedInt32Array([-1, -1, -1, -1, -1, -1, -1, -1]), PackedInt32Array([-1, -1, -1, -1, -1, -1, -1, -1])]
	var pawn_count := [PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0]), PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])]
	var pawns: Array[int] = []
	var bishops := [0, 0]
	var rays: Array = RULES.rays
	var knight_to: Array = RULES.knight_to
	for sq in 64:
		var p := b[sq]
		if p == 0:
			continue
		var t := p & 7
		var c := p >> 3
		var rel := sq if c == 0 else sq ^ 56
		var sign := 1 if c == 0 else -1
		var mgp: PackedInt32Array = pst_mg[t]
		var egp: PackedInt32Array = pst_eg[t]
		mg += sign * (VALUE[t] + mgp[rel])
		eg += sign * (VALUE[t] + egp[rel])
		phase += PHASE_W[t]
		match t:
			1:
				var f := sq & 7
				var r := sq >> 3
				pawn_count[c][f] += 1
				if r < pawn_min[c][f]:
					pawn_min[c][f] = r
				if r > pawn_max[c][f]:
					pawn_max[c][f] = r
				pawns.append(sq)
			2:
				var cnt := 0
				for to: int in knight_to[sq]:
					var q := b[to]
					if q == 0 or (q >> 3) != c:
						cnt += 1
				mg += sign * (cnt - 4) * 4
				eg += sign * (cnt - 4) * 4
			3, 4, 5:
				bishops[c] += 1 if t == 3 else 0
				var cnt := 0
				var d0 := 4 if t == 3 else 0
				var d1 := 4 if t == 4 else 8
				for di in range(d0, d1):
					for to: int in rays[di * 64 + sq]:
						var q := b[to]
						if q == 0:
							cnt += 1
							continue
						if (q >> 3) != c:
							cnt += 1
						break
				if t == 3:
					mg += sign * (cnt - 6) * 4
					eg += sign * (cnt - 6) * 4
				elif t == 4:
					mg += sign * (cnt - 6) * 2
					eg += sign * (cnt - 6) * 4
				else:
					mg += sign * (cnt - 12)
					eg += sign * (cnt - 12) * 2
	# Bauernstruktur: Doppel-, Einzel- und Freibauern.
	for sq: int in pawns:
		var c := b[sq] >> 3
		var f := sq & 7
		var r := sq >> 3
		var sign := 1 if c == 0 else -1
		var mine: PackedInt32Array = pawn_count[c]
		var left := mine[f - 1] if f > 0 else 0
		var right := mine[f + 1] if f < 7 else 0
		if left == 0 and right == 0:
			mg -= sign * 12
			eg -= sign * 16
		var passed := true
		for ff in range(maxi(0, f - 1), mini(7, f + 1) + 1):
			if c == 0:
				if pawn_max[1][ff] > r:
					passed = false
					break
			else:
				if pawn_min[0][ff] < r and pawn_min[0][ff] != 9:
					passed = false
					break
		if passed:
			var adv := r if c == 0 else 7 - r
			mg += sign * adv * 6
			eg += sign * (adv * adv * 4)
	for c in 2:
		var sign := 1 if c == 0 else -1
		for f in 8:
			var n: int = pawn_count[c][f]
			if n > 1:
				mg -= sign * 12 * (n - 1)
				eg -= sign * 20 * (n - 1)
		if bishops[c] >= 2:
			mg += sign * 30
			eg += sign * 45
	# Königssicherheit (nur im Mittelspiel): Bauernschild und offene Linien.
	for c in 2:
		var sign := 1 if c == 0 else -1
		var ksq: int = g.king_sq[c]
		var kf := ksq & 7
		var kr := ksq >> 3
		var home := kr == 0 if c == 0 else kr == 7
		var shield := 0
		var open_files := 0
		for ff in range(maxi(0, kf - 1), mini(7, kf + 1) + 1):
			var ahead1 := (kr + (1 if c == 0 else -1)) * 8 + ff
			var ahead2 := (kr + (2 if c == 0 else -2)) * 8 + ff
			if ahead1 >= 0 and ahead1 < 64 and b[ahead1] == (1 | (c << 3)):
				shield += 2
			elif ahead2 >= 0 and ahead2 < 64 and b[ahead2] == (1 | (c << 3)):
				shield += 1
			if pawn_count[c][ff] == 0:
				open_files += 1
		var safety := shield * 9 - open_files * 18
		if not home:
			safety -= 20
		mg += sign * safety
	phase = mini(phase, 24)
	var score := (mg * phase + eg * (24 - phase)) / 24
	score += 10 if g.side == 0 else -10
	return score if g.side == 0 else -score


# --- Suche ------------------------------------------------------------------


func _new_search(g: RefCounted, budget_ms: int, slice_ms: int) -> void:
	rules = g
	nodes = 0
	stopped = false
	frames = 0
	max_slice_usec = 0
	var now := Time.get_ticks_usec()
	hard_deadline = now + budget_ms * 1000
	slice_usec = slice_ms * 1000 if slice_ms > 0 else 1 << 50
	slice_deadline = now + slice_usec
	_slice_started = now
	killers.fill(0)
	for i in history.size():
		history[i] = history[i] >> 2
	if tt.size() > TT_LIMIT:
		tt.clear()


## Zeit prüfen; bei Bedarf auf das nächste Bild warten.
func _tick() -> void:
	var now := Time.get_ticks_usec()
	if now >= hard_deadline:
		stopped = true
		return
	if now >= slice_deadline:
		max_slice_usec = maxi(max_slice_usec, now - _slice_started)
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.process_frame
			frames += 1
		now = Time.get_ticks_usec()
		_slice_started = now
		slice_deadline = now + slice_usec
		if now >= hard_deadline:
			stopped = true


## Lumo denkt nach. Ergebnis: {move, score, depth, nodes, ms, frames,
## max_slice_ms, level}. `options` kann "budget_ms", "slice_ms" (0 = ohne
## Pause), "depth" überschreiben; "random_off" schaltet die Zufallszüge der
## leichten Stufen ab (nur für Messungen).
func think(g: RefCounted, level: int, options: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = LEVELS[clampi(level, 0, 3)]
	var started := Time.get_ticks_usec()
	var work: RefCounted = g.duplicate_state()
	var legal: PackedInt32Array = work.legal_moves()
	var result := {"move": -1, "score": 0, "depth": 0, "nodes": 0, "ms": 0.0, "frames": 0,
		"max_slice_ms": 0.0, "level": level}
	if legal.is_empty():
		return result
	var max_depth := int(options.get("depth", cfg.depth))
	var budget := int(options.get("budget_ms", cfg.budget))
	_new_search(work, budget, int(options.get("slice_ms", 10)))
	# Küken und Fuchs ziehen öfter einfach irgendwas (und hängen Figuren ein).
	if not options.get("random_off", false) and rng.randf() < float(cfg.random):
		var pick := legal[rng.randi_range(0, legal.size() - 1)]
		if level == 0:
			var captures: Array[int] = []
			for m: int in legal:
				if RULES.move_flags(m) & RULES.F_CAPTURE:
					captures.append(m)
			if not captures.is_empty() and rng.randf() < 0.35:
				pick = captures[rng.randi_range(0, captures.size() - 1)]
		result.move = pick
		result.ms = (Time.get_ticks_usec() - started) / 1000.0
		return result
	if legal.size() == 1 and not options.has("depth"):
		result.move = legal[0]
		result.depth = 1
		result.ms = (Time.get_ticks_usec() - started) / 1000.0
		return result
	var noise := int(cfg.noise)
	var best := legal[0]
	var best_score := -INF
	var reached := 0
	for depth in range(1, max_depth + 1):
		var r: Array = await _root(depth, legal, noise, bool(cfg.quiesce))
		if stopped and r[0] < 0:
			break
		if r[0] >= 0:
			best = r[0]
			best_score = r[1]
		if not stopped:
			reached = depth
		if stopped:
			break
		if absi(best_score) >= MATE_BOUND:
			break
		# Reicht die Zeit für die nächste Tiefe nicht mehr, gleich aufhören.
		var spent := Time.get_ticks_usec() - started
		if spent * 3 > budget * 1000:
			break
	result.move = best
	result.score = best_score
	result.depth = reached
	result.nodes = nodes
	result.ms = (Time.get_ticks_usec() - started) / 1000.0
	result.frames = frames
	result.max_slice_ms = maxi(max_slice_usec, Time.get_ticks_usec() - _slice_started) / 1000.0
	return result


func _root(depth: int, legal: PackedInt32Array, noise: int, quiesce: bool) -> Array:
	var g := rules
	var ordered := _order(legal, _tt_move(g.hash), 0)
	var alpha := -INF
	var beta := INF
	var best := -1
	var best_score := -INF
	var first := true
	for m: int in ordered:
		g.make_move(m)
		var score := 0
		if first:
			score = -(await _search(depth - 1, -beta, -alpha, 1, quiesce, true))
		else:
			score = -(await _search(depth - 1, -alpha - 1, -alpha, 1, quiesce, true))
			if score > alpha and not stopped:
				score = -(await _search(depth - 1, -beta, -alpha, 1, quiesce, true))
		g.unmake_move()
		if stopped:
			break
		if noise > 0 and absi(score) < MATE_BOUND:
			score += rng.randi_range(-noise, noise)
		first = false
		if score > best_score:
			best_score = score
			best = m
		if score > alpha:
			alpha = score
	if best >= 0:
		_tt_store(g.hash, depth, best_score, TT_EXACT, best)
	return [best, best_score]


func _search(depth: int, alpha: int, beta: int, ply: int, quiesce: bool, allow_null: bool) -> int:
	nodes += 1
	if (nodes & 127) == 0:
		await _tick()
	if stopped:
		return 0
	var g := rules
	if g.halfmove >= 100 or _repeated(g):
		return 0
	var in_check: bool = g.is_attacked(g.king_sq[g.side], g.side ^ 1)
	if in_check:
		depth += 1
	if depth <= 0:
		return await _quiesce(alpha, beta, ply) if quiesce else evaluate(g)
	if ply >= MAX_PLY - 1:
		return evaluate(g)
	var key: int = g.hash
	var tt_move := -1
	if tt.has(key):
		var e: int = tt[key]
		tt_move = e & 0x1FFFFF
		var e_depth := (e >> 21) & 63
		var e_flag := (e >> 27) & 3
		var e_score := ((e >> 29) & 0x1FFFF) - 65536
		if e_depth >= depth and ply > 0:
			if e_score >= MATE_BOUND:
				e_score -= ply
			elif e_score <= -MATE_BOUND:
				e_score += ply
			if e_flag == TT_EXACT:
				return e_score
			if e_flag == TT_LOWER and e_score >= beta:
				return e_score
			if e_flag == TT_UPPER and e_score <= alpha:
				return e_score
	# Nullzug: Wenn selbst ein ausgelassener Zug noch über beta liegt, abkürzen.
	if allow_null and not in_check and depth >= 3 and beta - alpha == 1 and _has_pieces(g):
		g.make_null()
		var null_score: int = -(await _search(depth - 3, -beta, -beta + 1, ply + 1, quiesce, false))
		g.unmake_null()
		if stopped:
			return 0
		if null_score >= beta and null_score < MATE_BOUND:
			return beta
	var moves: PackedInt32Array = g.pseudo_moves()
	var ordered := _order(moves, tt_move, ply)
	var best_score := -INF
	var best_move := -1
	var legal := 0
	var orig_alpha := alpha
	for m: int in ordered:
		if not g.make_move(m):
			g.unmake_move()
			continue
		legal += 1
		var score := 0
		if legal == 1:
			score = -(await _search(depth - 1, -beta, -alpha, ply + 1, quiesce, true))
		else:
			score = -(await _search(depth - 1, -alpha - 1, -alpha, ply + 1, quiesce, true))
			if score > alpha and score < beta and not stopped:
				score = -(await _search(depth - 1, -beta, -alpha, ply + 1, quiesce, true))
		g.unmake_move()
		if stopped:
			return 0
		if score > best_score:
			best_score = score
			best_move = m
		if score > alpha:
			alpha = score
		if alpha >= beta:
			if not (RULES.move_flags(m) & RULES.F_CAPTURE):
				var k := ply * 2
				if killers[k] != m:
					killers[k + 1] = killers[k]
					killers[k] = m
				var hi := (m & 63) * 64 + ((m >> 6) & 63)
				history[hi] = mini(history[hi] + depth * depth, 50000)
			break
	if legal == 0:
		return -MATE + ply if in_check else 0
	var flag := TT_EXACT
	if best_score <= orig_alpha:
		flag = TT_UPPER
	elif best_score >= beta:
		flag = TT_LOWER
	_tt_store(key, depth, best_score, flag, best_move, ply)
	return best_score


func _quiesce(alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 127) == 0:
		await _tick()
	if stopped:
		return 0
	var g := rules
	var stand := evaluate(g)
	if stand >= beta:
		return stand
	if stand > alpha:
		alpha = stand
	if ply >= MAX_PLY - 1:
		return stand
	var moves: PackedInt32Array = g.pseudo_moves(true)
	var ordered := _order(moves, -1, -1)
	var b: PackedInt32Array = g.board
	for m: int in ordered:
		var victim := b[(m >> 6) & 63] & 7
		var gain: int = VALUE[victim] if victim != 0 else 100
		if (m >> 12) & 7:
			gain += 800
		if stand + gain + 200 < alpha:
			continue
		if not g.make_move(m):
			g.unmake_move()
			continue
		var score := -(await _quiesce(-beta, -alpha, ply + 1))
		g.unmake_move()
		if stopped:
			return 0
		if score >= beta:
			return score
		if score > alpha:
			alpha = score
	return alpha


func _repeated(g: RefCounted) -> bool:
	var stack: PackedInt64Array = g.undo_stack
	var n := stack.size() / 3
	var limit := mini(n, g.halfmove)
	var i := 4
	var h: int = g.hash
	while i <= limit:
		if stack[(n - i) * 3 + 2] == h:
			return true
		i += 2
	return false


func _has_pieces(g: RefCounted) -> bool:
	var b: PackedInt32Array = g.board
	var c: int = g.side
	for sq in 64:
		var p := b[sq]
		if p != 0 and (p >> 3) == c and (p & 7) in [2, 3, 4, 5]:
			return true
	return false


func _tt_move(key: int) -> int:
	if tt.has(key):
		return int(tt[key]) & 0x1FFFFF
	return -1


func _tt_store(key: int, depth: int, score: int, flag: int, move: int, ply: int = 0) -> void:
	if score >= MATE_BOUND:
		score += ply
	elif score <= -MATE_BOUND:
		score -= ply
	var mv := move if move >= 0 else 0x1FFFFF
	tt[key] = mv | (mini(depth, 63) << 21) | (flag << 27) | ((score + 65536) << 29)


## Sortiert Züge: Tabellenzug, Schlagzüge (wertvolles Opfer, billiger Täter),
## Umwandlungen, Killerzüge, dann nach History.
func _order(moves: PackedInt32Array, tt_move: int, ply: int) -> PackedInt32Array:
	var b: PackedInt32Array = rules.board
	var n := moves.size()
	var keyed: Array[int] = []
	keyed.resize(n)
	var k1 := killers[ply * 2] if ply >= 0 else 0
	var k2 := killers[ply * 2 + 1] if ply >= 0 else 0
	for i in n:
		var m := moves[i]
		var s := 0
		if m == tt_move:
			s = 2000000
		else:
			var flags := m >> 15
			if flags & RULES.F_CAPTURE:
				var victim := b[(m >> 6) & 63] & 7
				if victim == 0:
					victim = 1
				s = 1000000 + victim * 100 - (b[m & 63] & 7)
			elif (m >> 12) & 7 == RULES.QUEEN:
				s = 950000
			elif m == k1:
				s = 900000
			elif m == k2:
				s = 890000
			else:
				s = history[(m & 63) * 64 + ((m >> 6) & 63)]
			if (m >> 12) & 7 == RULES.QUEEN:
				s += 50000
		# Sortierschlüssel und Zug in eine Zahl packen (Zug hat 20 Bit).
		keyed[i] = (s << 21) | m
	keyed.sort()
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = keyed[n - 1 - i] & 0x1FFFFF
	return out
