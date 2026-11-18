extends RefCounted
## Positive pieces are white. Square 0 is a8; 63 is h1.
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const VALUES := [0, 100, 320, 330, 500, 900, 0]
const ORTHOGONAL := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const KNIGHT_STEPS := [
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2),
]

var board := PackedInt32Array([
	-4, -2, -3, -5, -6, -3, -2, -4, -1, -1, -1, -1, -1, -1, -1, -1,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 3, 5, 6, 3, 2, 4,
])
var side := 1
var castle := 15
var en_passant := -1
var quiet_plies := 0


static func square(file: int, rank: int) -> int:
	return rank * 8 + file if file >= 0 and file < 8 and rank >= 0 and rank < 8 else -1


@warning_ignore("integer_division")
static func rank_of(index: int) -> int:
	return index / 8


static func square_name(index: int) -> String:
	return "%s%d" % ["abcdefgh"[index % 8], 8 - rank_of(index)]


func attacked(index: int, by: int) -> bool:
	var file := index % 8
	var rank := rank_of(index)
	for dx in [-1, 1]:
		var source := square(file + dx, rank + by)
		if source >= 0 and board[source] == by * PAWN:
			return true
	for offset: Vector2i in KNIGHT_STEPS:
		var source := square(file + offset.x, rank + offset.y)
		if source >= 0 and board[source] == by * KNIGHT:
			return true
	for offset: Vector2i in ORTHOGONAL + DIAGONAL:
		for distance in range(1, 8):
			var source := square(file + offset.x * distance, rank + offset.y * distance)
			if source < 0:
				break
			var piece := board[source] * by
			if piece == 0:
				continue
			var line_piece := ROOK if offset.x == 0 or offset.y == 0 else BISHOP
			if piece == QUEEN or piece == line_piece or (distance == 1 and piece == KING):
				return true
			break
	return false


func in_check(color: int) -> bool:
	var king := board.find(color * KING)
	return king >= 0 and attacked(king, -color)


func legal_moves(origin := -1) -> Array[Vector3i]:
	var moves: Array[Vector3i] = []
	var candidates: Array[Vector3i] = []
	if origin >= 0:
		_piece_moves(origin, candidates)
	else:
		for index in range(64):
			_piece_moves(index, candidates)
	for move in candidates:
		if not after(move).in_check(side):
			moves.append(move)
	return moves


func _piece_moves(origin: int, moves: Array[Vector3i]) -> void:
	var piece := board[origin] * side
	if piece <= 0:
		return
	var file := origin % 8
	var rank := rank_of(origin)
	if piece == PAWN:
		var forward := square(file, rank - side)
		if forward >= 0 and board[forward] == 0:
			_append(moves, origin, forward, piece)
			var double_step := square(file, rank - 2 * side)
			if rank == (6 if side > 0 else 1) and board[double_step] == 0:
				_append(moves, origin, double_step, piece)
		for dx in [-1, 1]:
			var target := square(file + dx, rank - side)
			if target >= 0 and (board[target] * side in [-5, -4, -3, -2, -1] or target == en_passant):
				_append(moves, origin, target, piece)
		return
	var directions: Array = ORTHOGONAL + DIAGONAL
	match piece:
		KNIGHT: directions = KNIGHT_STEPS
		BISHOP: directions = DIAGONAL
		ROOK: directions = ORTHOGONAL
	var reach := 1 if piece in [KNIGHT, KING] else 7
	for offset: Vector2i in directions:
		for distance in range(1, reach + 1):
			var target := square(file + offset.x * distance, rank + offset.y * distance)
			if target < 0 or board[target] * side > 0 or board[target] == -side * KING:
				break
			_append(moves, origin, target, piece)
			if board[target] != 0:
				break
	if piece == KING and file == 4 and rank == (7 if side > 0 else 0) and not in_check(side):
		var rights := 1 if side > 0 else 4
		if castle & rights and board[origin + 3] == side * ROOK and board[origin + 1] == 0 and board[origin + 2] == 0:
			if not after(Vector3i(origin, origin + 1, 0)).in_check(side):
				_append(moves, origin, origin + 2, piece)
		if castle & (rights * 2) and board[origin - 4] == side * ROOK and board[origin - 1] == 0 and board[origin - 2] == 0 and board[origin - 3] == 0:
			if not after(Vector3i(origin, origin - 1, 0)).in_check(side):
				_append(moves, origin, origin - 2, piece)


func _append(moves: Array[Vector3i], origin: int, target: int, piece: int) -> void:
	if piece == PAWN and rank_of(target) in [0, 7]:
		for promotion in [QUEEN, ROOK, BISHOP, KNIGHT]:
			moves.append(Vector3i(origin, target, promotion))
	else:
		moves.append(Vector3i(origin, target, 0))


func after(move: Vector3i) -> RefCounted:
	var next := get_script().new() as RefCounted
	next.board = board.duplicate()
	var piece := absi(board[move.x])
	next.board[move.x] = 0
	next.board[move.y] = side * (move.z if move.z != 0 else piece)
	if piece == PAWN and move.y == en_passant:
		next.board[move.y + side * 8] = 0
	if piece == KING and absi(move.y - move.x) == 2:
		var right := move.y > move.x
		next.board[move.x + (1 if right else -1)] = side * ROOK
		next.board[move.x + (3 if right else -4)] = 0
	next.castle = castle
	if piece == KING:
		next.castle &= 12 if side > 0 else 3
	for corner in [0, 7, 56, 63]:
		if move.x == corner or move.y == corner:
			next.castle &= ~{0: 8, 7: 4, 56: 2, 63: 1}[corner]
	next.en_passant = move.x - side * 8 if piece == PAWN and absi(move.y - move.x) == 16 else -1
	next.quiet_plies = 0 if piece == PAWN or board[move.y] != 0 else quiet_plies + 1
	next.side = -side
	return next


func dead_position() -> bool:
	var minors := 0
	var bishops := 0
	var bishop_color := -1
	for index in range(64):
		match absi(board[index]):
			PAWN, ROOK, QUEEN:
				return false
			KNIGHT:
				minors += 1
			BISHOP:
				minors += 1
				bishops += 1
				var color := (index % 8 + rank_of(index)) % 2
				if bishop_color >= 0 and bishop_color != color:
					return false
				bishop_color = color
	return minors <= 1 or bishops == minors


func repetition_key() -> String:
	var target := -1
	if en_passant >= 0:
		for dx in [-1, 1]:
			var source := square(en_passant % 8 + dx, rank_of(en_passant) + side)
			if source >= 0 and board[source] == PAWN * side:
				if legal_moves(source).has(Vector3i(source, en_passant, 0)):
					target = en_passant
					break
	return "%s/%s/%s/%s" % [board, side, castle, target]


func computer_move(level: int, moves: Array[Vector3i]) -> Vector3i:
	var candidates := _ordered(moves)
	if level == 0:
		return candidates[randi_range(0, mini(candidates.size() - 1, 4))]
	var best := candidates[0]
	var score := -1000000
	var depth := mini(level, 3)
	for index in range(candidates.size()):
		var move := candidates[index]
		var next = after(move)
		var value := -_search(next, depth, -1000000, -score)
		if value > score:
			score = value
			best = move
	return best


func _ordered(moves: Array[Vector3i]) -> Array[Vector3i]:
	var ordered := moves.duplicate()
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return _priority(a) > _priority(b))
	return ordered


func _priority(move: Vector3i) -> int:
	var center := 7 - absi((move.y % 8) * 2 - 7) - absi(rank_of(move.y) * 2 - 7)
	return VALUES[absi(board[move.y])] * 10 - VALUES[absi(board[move.x])] + VALUES[move.z] * 10 + center


func _search(position: RefCounted, depth: int, alpha: int, beta: int) -> int:
	var moves: Array[Vector3i] = position.legal_moves()
	if moves.is_empty():
		return -90000 - depth if position.in_check(position.side) else 0
	if position.dead_position():
		return 0
	if depth == 0:
		var material := 0
		for index in range(64):
			var piece: int = position.board[index]
			var center := 7 - absi((index % 8) * 2 - 7) - absi(rank_of(index) * 2 - 7)
			if piece != 0:
				material += signi(piece) * (VALUES[absi(piece)] + (center * 3 if absi(piece) in [KNIGHT, BISHOP, PAWN] else 0))
		return material * position.side
	var ordered: Array[Vector3i] = position._ordered(moves)
	var best := -1000000
	for index in range(mini(ordered.size(), 7) if depth >= 2 else ordered.size()):
		var value := -_search(position.after(ordered[index]), depth - 1, -beta, -alpha)
		best = maxi(best, value)
		alpha = maxi(alpha, best)
		if alpha >= beta:
			break
	return best
