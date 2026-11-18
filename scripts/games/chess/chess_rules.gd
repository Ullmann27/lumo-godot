extends RefCounted
## Regelkern für Lumo Schach – reines GDScript ohne Szene.
##
## Brett als 64 Felder (0 = a1, 7 = h1, 56 = a8, 63 = h8). Figuren als Zahl:
## Typ 1..6 (Bauer, Springer, Läufer, Turm, Dame, König), Schwarz zusätzlich +8.
## Züge als Zahl: von | nach << 6 | Umwandlungstyp << 12 | Merkmale << 15.
##
## Der Zuggenerator erzeugt erst alle „fast legalen“ Züge und prüft dann mit
## Ziehen/Zurücknehmen, ob der eigene König danach angegriffen ist. Ziehen und
## Zurücknehmen arbeiten auf demselben Zustand (kein Kopieren) und führen einen
## Zobrist-Schlüssel mit (für Stellungswiederholung und die Lumo-Suche).
##
## Alle Regeln: Rochade (beide Seiten mit allen Bedingungen), en passant,
## Umwandlung (frei wählbar), Schach, Matt, Patt, dreifache Stellung,
## 50-Züge-Regel und unzureichendes Material. FEN lesen und schreiben.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const BLACK_BIT := 8
const WHITE := 0
const BLACK := 1

const F_CAPTURE := 1
const F_DOUBLE := 2
const F_EP := 4
const F_CASTLE := 8
const F_PROMO := 16

const CASTLE_WK := 1
const CASTLE_WQ := 2
const CASTLE_BK := 4
const CASTLE_BQ := 8

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const FEN_LETTERS := ".pnbrqk"
const SAN_LETTERS := ["", "", "N", "B", "R", "Q", "K"]
const SAN_LETTERS_DE := ["", "", "S", "L", "T", "D", "K"]
const FILES := "abcdefgh"

# Richtungen als (Linie, Reihe): 0..3 gerade (Turm), 4..7 schräg (Läufer).
const DIRS := [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

static var _ready_tables := false
static var knight_to: Array = []  # je Feld PackedInt32Array
static var king_to: Array = []
static var rays: Array = []  # rays[richtung * 64 + feld] -> PackedInt32Array
static var castle_mask := PackedInt32Array()
static var z_piece := PackedInt64Array()  # figur * 64 + feld
static var z_castle := PackedInt64Array()
static var z_ep := PackedInt64Array()
static var z_side := 0

var board := PackedInt32Array()
var side := WHITE
var castling := 0
var ep := -1
var halfmove := 0
var fullmove := 1
var king_sq := PackedInt32Array([4, 60])
var hash := 0
var ep_key := -1  # Linie, die im Schlüssel steht (nur wenn en passant möglich)
var undo_stack := PackedInt64Array()  # je Zug 3 Werte: Zug, Info, Schlüssel davor
var start_fen := START_FEN
var played: Array[String] = []  # Züge seit start_fen in UCI-Schreibweise


static func ensure_tables() -> void:
	if _ready_tables:
		return
	_ready_tables = true
	knight_to.clear()
	king_to.clear()
	rays.clear()
	var jumps := [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
	]
	for sq in 64:
		var f := sq & 7
		var r := sq >> 3
		var kn := PackedInt32Array()
		for j: Vector2i in jumps:
			if f + j.x >= 0 and f + j.x < 8 and r + j.y >= 0 and r + j.y < 8:
				kn.append((r + j.y) * 8 + f + j.x)
		knight_to.append(kn)
		var kg := PackedInt32Array()
		for d: Vector2i in DIRS:
			if f + d.x >= 0 and f + d.x < 8 and r + d.y >= 0 and r + d.y < 8:
				kg.append((r + d.y) * 8 + f + d.x)
		king_to.append(kg)
	rays.resize(8 * 64)
	for di in 8:
		var d: Vector2i = DIRS[di]
		for sq in 64:
			var ray := PackedInt32Array()
			var f := (sq & 7) + d.x
			var r := (sq >> 3) + d.y
			while f >= 0 and f < 8 and r >= 0 and r < 8:
				ray.append(r * 8 + f)
				f += d.x
				r += d.y
			rays[di * 64 + sq] = ray
	castle_mask.resize(64)
	castle_mask.fill(15)
	castle_mask[0] = 15 & ~CASTLE_WQ
	castle_mask[7] = 15 & ~CASTLE_WK
	castle_mask[4] = 15 & ~(CASTLE_WK | CASTLE_WQ)
	castle_mask[56] = 15 & ~CASTLE_BQ
	castle_mask[63] = 15 & ~CASTLE_BK
	castle_mask[60] = 15 & ~(CASTLE_BK | CASTLE_BQ)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5C4A_C411
	z_piece.resize(16 * 64)
	for i in 16 * 64:
		z_piece[i] = _rand64(rng)
	z_castle.resize(16)
	for i in 16:
		z_castle[i] = _rand64(rng)
	z_ep.resize(8)
	for i in 8:
		z_ep[i] = _rand64(rng)
	z_side = _rand64(rng)


static func _rand64(rng: RandomNumberGenerator) -> int:
	return (int(rng.randi()) << 32) ^ int(rng.randi())


func _init(fen: String = START_FEN) -> void:
	ensure_tables()
	if not set_fen(fen):
		set_fen(START_FEN)


# --- Hilfen -----------------------------------------------------------------


static func color_of(piece: int) -> int:
	return piece >> 3


static func type_of(piece: int) -> int:
	return piece & 7


static func move_from(m: int) -> int:
	return m & 63


static func move_to(m: int) -> int:
	return (m >> 6) & 63


static func move_promo(m: int) -> int:
	return (m >> 12) & 7


static func move_flags(m: int) -> int:
	return m >> 15


static func make_code(from: int, to: int, promo: int = 0, flags: int = 0) -> int:
	return from | (to << 6) | (promo << 12) | (flags << 15)


static func square_name(sq: int) -> String:
	if sq < 0 or sq > 63:
		return "-"
	return FILES[sq & 7] + str((sq >> 3) + 1)


static func square_from_name(name: String) -> int:
	if name.length() != 2:
		return -1
	var f := FILES.find(name[0].to_lower())
	var r := int(name[1]) - 1
	if f < 0 or r < 0 or r > 7 or not name[1].is_valid_int():
		return -1
	return r * 8 + f


static func is_light_square(sq: int) -> bool:
	return ((sq & 7) + (sq >> 3)) % 2 == 1


func piece_at(sq: int) -> int:
	return board[sq]


# --- FEN --------------------------------------------------------------------


## Liest eine FEN-Stellung. Gibt false zurück (Zustand unverändert), wenn sie
## kaputt ist: falsche Feldzahl, fehlender oder doppelter König, Bauer auf der
## Grundreihe, unbekannte Zeichen.
func set_fen(fen: String) -> bool:
	var parts := fen.strip_edges().split(" ", false)
	if parts.size() < 2:
		return false
	var new_board := PackedInt32Array()
	new_board.resize(64)
	new_board.fill(0)
	var rows := parts[0].split("/")
	if rows.size() != 8:
		return false
	var kings := [0, 0]
	var ksq := PackedInt32Array([-1, -1])
	for ri in 8:
		var rank := 7 - ri
		var file := 0
		for ch in rows[ri]:
			if ch.is_valid_int():
				file += int(ch)
				continue
			var t := FEN_LETTERS.find(ch.to_lower())
			if t <= 0 or file > 7:
				return false
			var col := WHITE if ch == ch.to_upper() else BLACK
			if t == PAWN and (rank == 0 or rank == 7):
				return false
			var sq := rank * 8 + file
			new_board[sq] = t | (col << 3)
			if t == KING:
				kings[col] += 1
				ksq[col] = sq
			file += 1
		if file != 8:
			return false
	if kings[0] != 1 or kings[1] != 1:
		return false
	var new_side := WHITE
	if parts[1] == "b":
		new_side = BLACK
	elif parts[1] != "w":
		return false
	var new_castling := 0
	if parts.size() > 2 and parts[2] != "-":
		for ch in parts[2]:
			var bit := "KQkq".find(ch)
			if bit < 0:
				return false
			new_castling |= 1 << bit
	# Rechte nur behalten, wenn König und Turm wirklich auf ihren Feldern stehen.
	if new_board[4] != KING:
		new_castling &= ~(CASTLE_WK | CASTLE_WQ)
	if new_board[7] != ROOK:
		new_castling &= ~CASTLE_WK
	if new_board[0] != ROOK:
		new_castling &= ~CASTLE_WQ
	if new_board[60] != (KING | BLACK_BIT):
		new_castling &= ~(CASTLE_BK | CASTLE_BQ)
	if new_board[63] != (ROOK | BLACK_BIT):
		new_castling &= ~CASTLE_BK
	if new_board[56] != (ROOK | BLACK_BIT):
		new_castling &= ~CASTLE_BQ
	var new_ep := -1
	if parts.size() > 3 and parts[3] != "-":
		new_ep = square_from_name(parts[3])
		if new_ep < 0:
			return false
		var want_rank := 5 if new_side == WHITE else 2
		if new_ep >> 3 != want_rank:
			new_ep = -1
	board = new_board
	side = new_side
	castling = new_castling
	ep = new_ep
	halfmove = int(parts[4]) if parts.size() > 4 and parts[4].is_valid_int() else 0
	fullmove = maxi(1, int(parts[5]) if parts.size() > 5 and parts[5].is_valid_int() else 1)
	king_sq = ksq
	undo_stack = PackedInt64Array()
	start_fen = fen.strip_edges()
	played.clear()
	_refresh_ep_key()
	hash = compute_hash()
	return true


func get_fen() -> String:
	var out := ""
	for rank in range(7, -1, -1):
		var gap := 0
		for file in 8:
			var p := board[rank * 8 + file]
			if p == EMPTY:
				gap += 1
				continue
			if gap > 0:
				out += str(gap)
				gap = 0
			var ch := FEN_LETTERS[p & 7]
			out += ch.to_upper() if color_of(p) == WHITE else ch
		if gap > 0:
			out += str(gap)
		if rank > 0:
			out += "/"
	var rights := ""
	for bit in 4:
		if castling & (1 << bit):
			rights += "KQkq"[bit]
	if rights.is_empty():
		rights = "-"
	return "%s %s %s %s %d %d" % [
		out, "w" if side == WHITE else "b", rights, square_name(ep) if ep >= 0 else "-",
		halfmove, fullmove,
	]


func compute_hash() -> int:
	var h := 0
	for sq in 64:
		if board[sq] != EMPTY:
			h ^= z_piece[board[sq] * 64 + sq]
	h ^= z_castle[castling]
	if ep_key >= 0:
		h ^= z_ep[ep_key]
	if side == BLACK:
		h ^= z_side
	return h


## Die en-passant-Linie zählt für Stellungsgleichheit nur, wenn ein Bauer der
## Seite am Zug wirklich dorthin schlagen könnte.
func _refresh_ep_key() -> void:
	ep_key = -1
	if ep < 0:
		return
	var pawn := PAWN | (side << 3)
	var from_rank := 4 if side == WHITE else 3
	var f := ep & 7
	if f > 0 and board[from_rank * 8 + f - 1] == pawn:
		ep_key = f
	elif f < 7 and board[from_rank * 8 + f + 1] == pawn:
		ep_key = f


# --- Angriffe ---------------------------------------------------------------


## Wird `sq` von Figuren der Farbe `by` angegriffen?
func is_attacked(sq: int, by: int) -> bool:
	var b := board
	var f := sq & 7
	var col := by << 3
	# Bauern: weiße Bauern greifen nach oben an, stehen also unterhalb.
	if by == WHITE:
		if sq >= 16:
			if f > 0 and b[sq - 9] == PAWN:
				return true
			if f < 7 and b[sq - 7] == PAWN:
				return true
	else:
		if sq < 48:
			if f > 0 and b[sq + 7] == (PAWN | BLACK_BIT):
				return true
			if f < 7 and b[sq + 9] == (PAWN | BLACK_BIT):
				return true
	var kn := KNIGHT | col
	for t: int in knight_to[sq]:
		if b[t] == kn:
			return true
	var kg := KING | col
	for t: int in king_to[sq]:
		if b[t] == kg:
			return true
	var rk := ROOK | col
	var qn := QUEEN | col
	var bs := BISHOP | col
	for di in 4:
		for t: int in rays[di * 64 + sq]:
			var p := b[t]
			if p != EMPTY:
				if p == rk or p == qn:
					return true
				break
	for di in range(4, 8):
		for t: int in rays[di * 64 + sq]:
			var p := b[t]
			if p != EMPTY:
				if p == bs or p == qn:
					return true
				break
	return false


func in_check(color: int = -1) -> bool:
	var c := side if color < 0 else color
	return is_attacked(king_sq[c], c ^ 1)


## Alle Felder, die `sq` gerade bedroht (für Erklärungen und Leuchten).
func attacks_from(sq: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var p := board[sq]
	if p == EMPTY:
		return out
	var t := p & 7
	var c := p >> 3
	match t:
		PAWN:
			var dr := 8 if c == WHITE else -8
			var f := sq & 7
			var to := sq + dr
			if to >= 0 and to < 64:
				if f > 0:
					out.append(to - 1)
				if f < 7:
					out.append(to + 1)
		KNIGHT:
			out.append_array(knight_to[sq])
		KING:
			out.append_array(king_to[sq])
		_:
			var d0 := 4 if t == BISHOP else 0
			var d1 := 4 if t == ROOK else 8
			for di in range(d0, d1):
				for to: int in rays[di * 64 + sq]:
					out.append(to)
					if board[to] != EMPTY:
						break
	return out


# --- Zuggenerator -----------------------------------------------------------


## Fast legale Züge der Seite am Zug (der eigene König kann danach noch im
## Schach stehen). `captures_only` liefert nur Schlagzüge und Umwandlungen.
func pseudo_moves(captures_only: bool = false) -> PackedInt32Array:
	var out := PackedInt32Array()
	var b := board
	var us := side
	var them_bit := (us ^ 1) << 3
	for sq in 64:
		var p := b[sq]
		if p == EMPTY or (p >> 3) != us:
			continue
		var t := p & 7
		if t == PAWN:
			_pawn_moves(sq, out, captures_only)
		elif t == KNIGHT or t == KING:
			var targets: PackedInt32Array = knight_to[sq] if t == KNIGHT else king_to[sq]
			for to: int in targets:
				var q := b[to]
				if q == EMPTY:
					if not captures_only:
						out.append(sq | (to << 6))
				elif (q & BLACK_BIT) == them_bit:
					out.append(sq | (to << 6) | (F_CAPTURE << 15))
			if t == KING and not captures_only:
				_castle_moves(sq, out)
		else:
			var d0 := 4 if t == BISHOP else 0
			var d1 := 4 if t == ROOK else 8
			for di in range(d0, d1):
				for to: int in rays[di * 64 + sq]:
					var q := b[to]
					if q == EMPTY:
						if not captures_only:
							out.append(sq | (to << 6))
						continue
					if (q & BLACK_BIT) == them_bit:
						out.append(sq | (to << 6) | (F_CAPTURE << 15))
					break
	return out


func _pawn_moves(sq: int, out: PackedInt32Array, captures_only: bool) -> void:
	var b := board
	var us := side
	var dr := 8 if us == WHITE else -8
	var start_rank := 1 if us == WHITE else 6
	var last_rank := 7 if us == WHITE else 0
	var f := sq & 7
	var to := sq + dr
	var promo := (to >> 3) == last_rank
	if b[to] == EMPTY:
		if promo:
			_add_promos(sq, to, 0, out)
		elif not captures_only:
			out.append(sq | (to << 6))
			if (sq >> 3) == start_rank and b[to + dr] == EMPTY:
				out.append(sq | ((to + dr) << 6) | (F_DOUBLE << 15))
	var them_bit := (us ^ 1) << 3
	for side_step in [-1, 1]:
		if (side_step < 0 and f == 0) or (side_step > 0 and f == 7):
			continue
		var cap: int = to + side_step
		var q := b[cap]
		if q != EMPTY and (q & BLACK_BIT) == them_bit:
			if promo:
				_add_promos(sq, cap, F_CAPTURE, out)
			else:
				out.append(sq | (cap << 6) | (F_CAPTURE << 15))
		elif cap == ep:
			out.append(sq | (cap << 6) | ((F_CAPTURE | F_EP) << 15))


func _add_promos(from: int, to: int, flags: int, out: PackedInt32Array) -> void:
	for t in [QUEEN, KNIGHT, ROOK, BISHOP]:
		out.append(from | (to << 6) | (t << 12) | ((flags | F_PROMO) << 15))


func _castle_moves(sq: int, out: PackedInt32Array) -> void:
	var b := board
	if side == WHITE:
		if sq != 4:
			return
		if castling & CASTLE_WK and b[5] == EMPTY and b[6] == EMPTY and b[7] == ROOK:
			if not is_attacked(4, BLACK) and not is_attacked(5, BLACK) and not is_attacked(6, BLACK):
				out.append(4 | (6 << 6) | (F_CASTLE << 15))
		if castling & CASTLE_WQ and b[3] == EMPTY and b[2] == EMPTY and b[1] == EMPTY and b[0] == ROOK:
			if not is_attacked(4, BLACK) and not is_attacked(3, BLACK) and not is_attacked(2, BLACK):
				out.append(4 | (2 << 6) | (F_CASTLE << 15))
	else:
		if sq != 60:
			return
		var rook := ROOK | BLACK_BIT
		if castling & CASTLE_BK and b[61] == EMPTY and b[62] == EMPTY and b[63] == rook:
			if not is_attacked(60, WHITE) and not is_attacked(61, WHITE) and not is_attacked(62, WHITE):
				out.append(60 | (62 << 6) | (F_CASTLE << 15))
		if castling & CASTLE_BQ and b[59] == EMPTY and b[58] == EMPTY and b[57] == EMPTY and b[56] == rook:
			if not is_attacked(60, WHITE) and not is_attacked(59, WHITE) and not is_attacked(58, WHITE):
				out.append(60 | (58 << 6) | (F_CASTLE << 15))


## Alle legalen Züge der Seite am Zug.
func legal_moves() -> PackedInt32Array:
	var out := PackedInt32Array()
	for m: int in pseudo_moves():
		if make_move(m):
			out.append(m)
		unmake_move()
	return out


func legal_moves_from(sq: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m: int in legal_moves():
		if (m & 63) == sq:
			out.append(m)
	return out


func has_legal_move() -> bool:
	for m: int in pseudo_moves():
		var ok := make_move(m)
		unmake_move()
		if ok:
			return true
	return false


# --- Ziehen und Zurücknehmen ------------------------------------------------


## Führt einen (fast legalen) Zug aus. Gibt false zurück, wenn der eigene
## König danach im Schach steht – der Zug muss dann trotzdem mit
## `unmake_move()` zurückgenommen werden.
func make_move(m: int) -> bool:
	var from := m & 63
	var to := (m >> 6) & 63
	var promo := (m >> 12) & 7
	var flags := m >> 15
	var b := board
	var piece := b[from]
	var captured := b[to]
	var us := side
	undo_stack.append(m)
	undo_stack.append(captured | (castling << 4) | ((ep + 1) << 8) | ((ep_key + 1) << 16) | (halfmove << 20))
	undo_stack.append(hash)
	var h := hash
	if ep_key >= 0:
		h ^= z_ep[ep_key]
	h ^= z_castle[castling]
	b[from] = EMPTY
	h ^= z_piece[piece * 64 + from]
	if flags & F_EP:
		var cap_sq := to - 8 if us == WHITE else to + 8
		var cap_piece := b[cap_sq]
		b[cap_sq] = EMPTY
		h ^= z_piece[cap_piece * 64 + cap_sq]
	elif captured != EMPTY:
		h ^= z_piece[captured * 64 + to]
	var placed := (promo | (us << 3)) if promo != 0 else piece
	b[to] = placed
	h ^= z_piece[placed * 64 + to]
	if flags & F_CASTLE:
		var rf := 0
		var rt := 0
		match to:
			6:
				rf = 7
				rt = 5
			2:
				rf = 0
				rt = 3
			62:
				rf = 63
				rt = 61
			58:
				rf = 56
				rt = 59
		var rook := b[rf]
		b[rf] = EMPTY
		b[rt] = rook
		h ^= z_piece[rook * 64 + rf] ^ z_piece[rook * 64 + rt]
	if (piece & 7) == KING:
		king_sq[us] = to
	castling &= castle_mask[from] & castle_mask[to]
	h ^= z_castle[castling]
	if (piece & 7) == PAWN or captured != EMPTY or (flags & F_EP):
		halfmove = 0
	else:
		halfmove += 1
	if us == BLACK:
		fullmove += 1
	side = us ^ 1
	h ^= z_side
	ep = (from + to) >> 1 if flags & F_DOUBLE else -1
	if ep >= 0:
		_refresh_ep_key()
		if ep_key >= 0:
			h ^= z_ep[ep_key]
	else:
		ep_key = -1
	hash = h
	return not is_attacked(king_sq[us], side)


func unmake_move() -> void:
	var n := undo_stack.size()
	var m := int(undo_stack[n - 3])
	var info := int(undo_stack[n - 2])
	hash = int(undo_stack[n - 1])
	undo_stack.resize(n - 3)
	var from := m & 63
	var to := (m >> 6) & 63
	var flags := m >> 15
	side ^= 1
	var us := side
	var b := board
	var piece := b[to]
	if flags & F_PROMO:
		piece = PAWN | (us << 3)
	b[from] = piece
	b[to] = info & 15
	if flags & F_EP:
		var cap_sq := to - 8 if us == WHITE else to + 8
		b[cap_sq] = PAWN | ((us ^ 1) << 3)
	if flags & F_CASTLE:
		match to:
			6:
				b[7] = b[5]
				b[5] = EMPTY
			2:
				b[0] = b[3]
				b[3] = EMPTY
			62:
				b[63] = b[61]
				b[61] = EMPTY
			58:
				b[56] = b[59]
				b[59] = EMPTY
	if (piece & 7) == KING:
		king_sq[us] = from
	castling = (info >> 4) & 15
	ep = ((info >> 8) & 127) - 1
	ep_key = ((info >> 16) & 15) - 1
	halfmove = info >> 20
	if us == BLACK:
		fullmove -= 1


## Nullzug für die Suche (Seite wechselt, sonst nichts).
func make_null() -> void:
	undo_stack.append(0)
	undo_stack.append((castling << 4) | ((ep + 1) << 8) | ((ep_key + 1) << 16) | (halfmove << 20))
	undo_stack.append(hash)
	var h := hash
	if ep_key >= 0:
		h ^= z_ep[ep_key]
	ep = -1
	ep_key = -1
	side ^= 1
	hash = h ^ z_side


func unmake_null() -> void:
	var n := undo_stack.size()
	var info := int(undo_stack[n - 2])
	hash = int(undo_stack[n - 1])
	undo_stack.resize(n - 3)
	side ^= 1
	ep = ((info >> 8) & 127) - 1
	ep_key = ((info >> 16) & 15) - 1


func ply_count() -> int:
	return undo_stack.size() / 3


# --- Spielverlauf (für Tisch, Schule, Speichern) ----------------------------


## Spielt einen legalen Zug und merkt ihn sich. Unzulässige Züge ändern nichts.
func play(m: int) -> bool:
	if not legal_moves().has(m):
		return false
	make_move(m)
	played.append(to_uci(m))
	return true


func play_uci(uci: String) -> bool:
	var m := move_from_uci(uci)
	return m >= 0 and play(m)


## Nimmt den letzten gespielten Zug zurück.
func take_back() -> bool:
	if played.is_empty() or undo_stack.size() < 3:
		return false
	unmake_move()
	played.pop_back()
	return true


func last_move() -> int:
	if undo_stack.size() < 3:
		return -1
	return int(undo_stack[undo_stack.size() - 3])


func to_uci(m: int) -> String:
	var s := square_name(m & 63) + square_name((m >> 6) & 63)
	var promo := (m >> 12) & 7
	if promo != 0:
		s += FEN_LETTERS[promo]
	return s


## Sucht den legalen Zug zu „e2e4“ / „e7e8q“. Ohne Umwandlungsbuchstaben
## wird die Dame gewählt (Vorgabe für Kinder). -1 wenn kein solcher Zug.
func move_from_uci(uci: String) -> int:
	if uci.length() < 4:
		return -1
	var from := square_from_name(uci.substr(0, 2))
	var to := square_from_name(uci.substr(2, 2))
	var promo := QUEEN
	if uci.length() > 4:
		promo = FEN_LETTERS.find(uci[4].to_lower())
	for m: int in legal_moves():
		if (m & 63) == from and ((m >> 6) & 63) == to:
			var mp := (m >> 12) & 7
			if mp == 0 or mp == promo:
				return m
	return -1


## Kurzschrift (SAN), z. B. „Nf3“, „exd5“, „O-O“, „e8=Q+“. Mit `german`
## deutsche Buchstaben (S, L, T, D, K). Muss vor dem Zug aufgerufen werden.
func to_san(m: int, german: bool = false) -> String:
	var from := m & 63
	var to := (m >> 6) & 63
	var flags := m >> 15
	var piece := board[from]
	var t := piece & 7
	var s := ""
	if flags & F_CASTLE:
		s = "O-O" if (to & 7) == 6 else "O-O-O"
	else:
		var letters: Array = SAN_LETTERS_DE if german else SAN_LETTERS
		if t == PAWN:
			if flags & F_CAPTURE:
				s = FILES[from & 7] + "x"
		else:
			s = letters[t]
			var same_file := false
			var same_rank := false
			var other := false
			for o: int in legal_moves():
				var of := o & 63
				if of != from and ((o >> 6) & 63) == to and (board[of] & 7) == t:
					other = true
					if (of & 7) == (from & 7):
						same_file = true
					if (of >> 3) == (from >> 3):
						same_rank = true
			if other:
				if not same_file:
					s += FILES[from & 7]
				elif not same_rank:
					s += str((from >> 3) + 1)
				else:
					s += square_name(from)
			if flags & F_CAPTURE:
				s += "x"
		s += square_name(to)
		var promo := (m >> 12) & 7
		if promo != 0:
			s += "=" + str(letters[promo])
	make_move(m)
	if in_check():
		s += "#" if not has_legal_move() else "+"
	unmake_move()
	return s


# --- Spielende --------------------------------------------------------------


## Wie oft die aktuelle Stellung schon auf dem Brett stand (inklusive jetzt).
func repetition_count() -> int:
	var count := 1
	var n := undo_stack.size() / 3
	var limit := mini(n, halfmove)
	var i := 2
	while i <= limit:
		if int(undo_stack[(n - i) * 3 + 2]) == hash:
			count += 1
		i += 2
	return count


## Reicht das Material auf dem Brett überhaupt noch für ein Matt?
func insufficient_material() -> bool:
	var minors := 0
	var knights := 0
	var bishop_colors := [0, 0]
	for sq in 64:
		var t := board[sq] & 7
		match t:
			PAWN, ROOK, QUEEN:
				return false
			KNIGHT:
				minors += 1
				knights += 1
			BISHOP:
				minors += 1
				bishop_colors[1 if is_light_square(sq) else 0] += 1
	if minors <= 1:
		return true
	# Nur Läufer, alle auf derselben Feldfarbe: kein Matt möglich.
	return knights == 0 and (bishop_colors[0] == 0 or bishop_colors[1] == 0)


## "playing", "checkmate", "stalemate", "draw_repetition", "draw_fifty",
## "draw_material". Matt geht vor allen Remis-Regeln.
func status() -> String:
	if not has_legal_move():
		return "checkmate" if in_check() else "stalemate"
	if insufficient_material():
		return "draw_material"
	if halfmove >= 100:
		return "draw_fifty"
	if repetition_count() >= 3:
		return "draw_repetition"
	return "playing"


func is_over() -> bool:
	return status() != "playing"


## Gewinner: 0 Weiß, 1 Schwarz, -1 Remis oder noch offen.
func winner() -> int:
	return side ^ 1 if status() == "checkmate" else -1


# --- Speichern --------------------------------------------------------------


func snapshot() -> Dictionary:
	return {"start": start_fen, "moves": played.duplicate()}


## Stellt einen Stand aus `snapshot()` wieder her (Start + alle Züge, damit
## Wiederholungen und Zurücknehmen erhalten bleiben). Bei Fehlern false.
func restore(data: Dictionary) -> bool:
	var keep_fen := start_fen
	var keep_moves := played.duplicate()
	if not set_fen(str(data.get("start", START_FEN))):
		return false
	var moves: Variant = data.get("moves", [])
	if moves is Array:
		for u: Variant in moves:
			if not play_uci(str(u)):
				set_fen(keep_fen)
				for k: String in keep_moves:
					play_uci(k)
				return false
	return true


func duplicate_state() -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy.restore(snapshot())
	return copy


# --- Perft ------------------------------------------------------------------


## Zählt alle Zugfolgen bis `depth` (Standardtest für Zuggeneratoren).
func perft(depth: int) -> int:
	if depth <= 0:
		return 1
	var nodes := 0
	for m: int in pseudo_moves():
		if make_move(m):
			nodes += 1 if depth == 1 else perft(depth - 1)
		unmake_move()
	return nodes
