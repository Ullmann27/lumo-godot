extends SceneTree

const RULES = preload("res://scripts/games/chess/chess_position.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _verify(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + description)


func _descendants(state: RefCounted, depth: int) -> int:
	if depth == 0:
		return 1
	var count := 0
	for move: Vector3i in state.legal_moves():
		count += _descendants(state.after(move), depth - 1)
	return count


func _run() -> void:
	var start = RULES.new()
	_verify(_descendants(start, 1) == 20, "initial position legal moves")
	_verify(_descendants(start, 2) == 400, "initial position depth two")
	_verify(_descendants(start, 3) == 8902, "initial position depth three")
	var passant = start
	for move in [Vector3i(52, 36, 0), Vector3i(8, 16, 0), Vector3i(36, 28, 0), Vector3i(11, 27, 0)]:
		_verify(passant.legal_moves().has(move), "moves leading to en passant")
		passant = passant.after(move)
	_verify(passant.legal_moves().has(Vector3i(28, 19, 0)), "en passant available")
	_verify(passant.after(Vector3i(28, 19, 0)).board[27] == 0, "en passant removes bypassed pawn")
	var special = RULES.new()
	special.board.fill(0)
	special.board[60] = 6
	special.board[63] = 4
	special.board[4] = -6
	_verify(special.legal_moves(60).has(Vector3i(60, 62, 0)), "king-side castle legal")
	var castled = special.after(Vector3i(60, 62, 0))
	_verify(castled.board[61] == 4 and castled.board[62] == 6, "castling moves both pieces")
	special.board[5] = -4
	_verify(not special.legal_moves(60).has(Vector3i(60, 62, 0)), "castling through check is blocked")
	special.board[8] = 1
	_verify(special.legal_moves(8).size() == 4, "all four promotions offered")
	var played = start
	for move in [Vector3i(53, 45, 0), Vector3i(12, 28, 0), Vector3i(54, 38, 0), Vector3i(3, 39, 0)]:
		_verify(played.legal_moves().has(move), "legal shortest mate move")
		played = played.after(move)
	_verify(played.in_check(1) and played.legal_moves().is_empty(), "checkmate recognized")
	var bot_moves: Array[Vector3i] = start.legal_moves()
	for level in range(4):
		_verify(bot_moves.has(start.computer_move(level, bot_moves)), "each level selects a legal move")
	var scene := load("res://scenes/games/chess_table.tscn") as PackedScene
	var table := scene.instantiate()
	root.add_child(table)
	await process_frame
	_verify(table._board.get_child_count() >= 1, "3D board built on scene load")
	table._start(true, 0)
	for move: Vector3i in table.GUIDED:
		table._pick(move.x)
		table._pick(move.y)
		if table._active:
			await create_timer(0.38).timeout
	_verify(not table._active and table._position.in_check(-1), "guided exercise reaches checkmate")
	_verify(table._message.text.contains("Lernrunde geschafft"), "guided finish is acknowledged")
	table.queue_free()
	await process_frame
	print("CHESS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
