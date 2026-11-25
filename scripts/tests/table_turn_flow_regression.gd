extends SceneTree
## Echte Tischszenen mit normalem Tempo: Zwischenpositionen, Eingabesicherung,
## Pausen, geordnete Übergaben und Abbruch beim Reset. Optional echte GL-Bilder:
## -- --capture=/absoluter/ordner (unter xvfb, nicht --headless).

const CHESS_RULES = preload("res://scripts/games/chess/chess_rules.gd")
const CHESS_SESSION = preload("res://scripts/games/chess/chess_session.gd")
const CARDS_SESSION = preload("res://scripts/games/cards/cards_session.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const CHILD := "table-turn-flow-regression"

var checks := 0
var failures: Array[String] = []
var chess_table: Node
var cards_table: Node
var capture_dir := ""
var shots := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[TableTurnFlow] " + message)


func _until(condition: Callable, seconds: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await process_frame
	return true


func _frames(count: int = 3) -> void:
	for i in count:
		await process_frame


func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	_check(picture.save_png(capture_dir.path_join(label + ".png")) == OK, "Bild gespeichert: " + label)
	shots += 1


func _run() -> void:
	Engine.max_fps = 60
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var bridge: Node = root.get_node("HostBridge")
	bridge._options = {"childKey": CHILD, "displayDensity": 1.5, "soundEnabled": false}
	root.size = Vector2i(1440, 900)
	DirAccess.remove_absolute(CHESS_SESSION.path_for(CHILD))
	DirAccess.remove_absolute(CARDS_SESSION.path_for(CHILD))
	await _chess_flow()
	await _chess_special_moves()
	await _chess_abort()
	chess_table.queue_free()
	await _frames(3)
	await _cards_flow()
	await _cards_transfer()
	await _cards_abort_and_reduced_motion()
	cards_table.queue_free()
	await _frames(4)
	root.get_node("GameSoundscape").release_audio()
	await create_timer(0.3).timeout
	DirAccess.remove_absolute(CHESS_SESSION.path_for(CHILD))
	DirAccess.remove_absolute(CARDS_SESSION.path_for(CHILD))
	print("TABLE_TURN_FLOW_%s checks=%d failures=%d captures=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), shots])
	quit(0 if failures.is_empty() else 1)


func _chess_flow() -> void:
	chess_table = load("res://scenes/games/chess_table.tscn").instantiate()
	root.add_child(chess_table)
	await _frames(5)
	chess_table.mode = "play"
	chess_table.view = "top"
	chess_table.start_match(0, false)
	chess_table.hints = false
	chess_table.ai.rng.seed = 77
	var m: int = chess_table.rules.move_from_uci("e2e4")
	var from: int = CHESS_RULES.move_from(m)
	var to: int = CHESS_RULES.move_to(m)
	var mover: Node3D = chess_table.chess.pieces[from]
	var start: Vector3 = mover.position
	var target: Vector3 = chess_table.chess.square_center(to)
	await _capture("chess_top_00_before")
	chess_table._commit_child_move(m)
	_check(chess_table.busy and not chess_table.thinking, "Schach: erst Kinderbewegung, dann Denken")
	_check(chess_table.chess.is_animating() and chess_table.board2d.is_animating(), "Schach: beide Ansichten animieren")
	await create_timer(0.2).timeout
	_check(not mover.position.is_equal_approx(start) and not mover.position.is_equal_approx(target), "Schach 3D: echte Zwischenposition")
	_check(chess_table.board2d._progress > 0.0 and chess_table.board2d._progress < 1.0, "Schach 2D: echte Zwischenposition")
	_check(chess_table.rules.played.size() == 1 and not chess_table.thinking, "Schach: KI beginnt nicht im Kinderflug")
	await _capture("chess_top_01_child_in_flight")
	chess_table._on_pause()
	var held: Vector3 = mover.position
	var held_progress: float = chess_table.board2d._progress
	await create_timer(0.3).timeout
	_check(mover.position.is_equal_approx(held) and is_equal_approx(chess_table.board2d._progress, held_progress), "Schach: Pause hält beide Bewegungen")
	_check(chess_table.chess.is_animating() and chess_table.board2d.is_animating(), "Schach: pausierte Bewegung bleibt beschäftigt")
	chess_table._resume()
	_check(await _until(func() -> bool: return chess_table.thinking), "Schach: Denken folgt auf Landung")
	_check(mover.position.is_equal_approx(target), "Schach: Kinderfigur steht vor KI-Start am Ziel")
	chess_table._on_pause()
	await create_timer(0.35).timeout
	_check(chess_table.rules.played.size() == 1, "Schach: KI setzt während Denkpause keinen Zug")
	chess_table._resume()
	_check(await _until(func() -> bool: return chess_table.rules.played.size() == 2), "Schach: genau eine KI-Antwort beginnt")
	var reply: int = chess_table.rules.last_move()
	var reply_to: int = CHESS_RULES.move_to(reply)
	var reply_from: int = CHESS_RULES.move_from(reply)
	var reply_piece: Node3D = chess_table.chess.pieces[reply_to]
	await create_timer(0.24).timeout
	_check(chess_table.busy and chess_table._child_moves().is_empty(), "Schach: Kind bleibt während KI-Bewegung gesperrt")
	_check(not reply_piece.position.is_equal_approx(chess_table.chess.square_center(reply_from))
		and not reply_piece.position.is_equal_approx(chess_table.chess.square_center(reply_to)),
		"Schach: KI-Figur bewegt sich sichtbar zwischen ihren Feldern")
	await _capture("chess_top_02_lumo_in_flight")
	var played: int = chess_table.rules.played.size()
	var next_moves: PackedInt32Array = chess_table.rules.legal_moves()
	chess_table._commit_child_move(next_moves[0])
	_check(chess_table.rules.played.size() == played, "Schach: zusätzlicher Zug im Flug wird abgewiesen")
	chess_table._on_pause()
	held = reply_piece.position
	await create_timer(0.3).timeout
	_check(reply_piece.position.is_equal_approx(held), "Schach: Pause hält auch Lumos Figur")
	chess_table.open_rules()
	chess_table.find_button("o_RulesBack").pressed.emit()
	_check(not chess_table._paused, "Schach: Regeln aus Pause kehren in laufende Partie zurück")
	_check(await _until(func() -> bool: return chess_table.is_idle()), "Schach: Zugfolge endet")
	_check(chess_table.rules.played.size() == 2, "Schach: genau zwei Halbzüge nach Übergabe")
	_check(chess_table.board2d.board == chess_table.rules.board, "Schach 2D: Endbrett entspricht Regeln")
	_check(reply_piece.position.is_equal_approx(chess_table.chess.square_center(reply_to)), "Schach 3D: KI landet am Zielfeld")
	await _capture("chess_top_03_settled")
	var fen: String = chess_table.rules.get_fen()
	chess_table.open_home()
	chess_table.start_match(-1, true)
	_check(chess_table.rules.get_fen() == fen, "Schach: Speicherstand nach Zugfolge unverändert fortgesetzt")


func _chess_special_moves() -> void:
	chess_table.start_match(0, false)
	chess_table.view = "3d"
	chess_table._update_view()
	var cases := [
		["r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "e1g1"],
		["4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", "e5d6"],
		["4k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7a8q"],
	]
	for entry: Array in cases:
		chess_table.rules = CHESS_RULES.new(str(entry[0]))
		chess_table._show_position()
		var move: int = chess_table.rules.move_from_uci(str(entry[1]))
		_check(move >= 0 and chess_table.rules.play(move), "Sonderzug legal: " + str(entry[1]))
		chess_table.chess.animate_move(move, chess_table.rules.board, 0.6)
		chess_table.board2d.animate_move(move, chess_table.rules.board, 0.6)
		if entry[1] == "e1g1":
			await create_timer(0.24).timeout
			var rook: Node3D = chess_table.chess.pieces[5]
			_check(rook.position.is_equal_approx(chess_table.chess.square_center(7)), "Rochade: Turm wartet auf den König")
			_check(chess_table.board2d._rook_progress == 0.0, "Rochade 2D: gleiche Reihenfolge")
			await _capture("chess_3d_01_castling_king_in_flight")
			await create_timer(0.42).timeout
			_check(not rook.position.is_equal_approx(chess_table.chess.square_center(7)), "Rochade: danach folgt der Turm")
			await _capture("chess_3d_02_castling_rook_in_flight")
		_check(await _until(func() -> bool: return not chess_table.chess.is_animating() and not chess_table.board2d.is_animating()), "Sonderzug landet: " + str(entry[1]))
		_check(chess_table.board2d.board == chess_table.rules.board, "Sonderzug 2D-Endbrett: " + str(entry[1]))
		var count := 0
		for sq in 64:
			if chess_table.rules.board[sq] != 0:
				count += 1
				var node: Node3D = chess_table.chess.pieces.get(sq)
				_check(node != null and int(node.get_meta("piece")) == chess_table.rules.board[sq]
					and node.position.is_equal_approx(chess_table.chess.square_center(sq)), "Sonderzug 3D-Figur auf Feld %d" % sq)
		_check(chess_table.chess.pieces.size() == count and chess_table.chess._retiring.is_empty(), "Sonderzug: keine verlorene/zusätzliche Figur")
	await _capture("chess_3d_03_settled")


func _chess_abort() -> void:
	chess_table.start_match(0, false)
	chess_table.hints = false
	chess_table._commit_child_move(chess_table.rules.move_from_uci("e2e4"))
	await create_timer(0.2).timeout
	chess_table.open_path()
	var settled_pawn: Node3D = chess_table.chess.pieces[CHESS_RULES.square_from_name("e4")]
	_check(settled_pawn.position.is_equal_approx(chess_table.chess.square_center(CHESS_RULES.square_from_name("e4"))),
		"Schach: Lernweg-Menü rastet unterbrochene Figur auf gültigem Feld ein")
	_check(not chess_table.chess.is_animating() and not chess_table.board2d.is_animating(),
		"Schach: Menü beendet beide Darstellungen")
	chess_table.start_match(0, false)
	chess_table.hints = false
	chess_table._commit_child_move(chess_table.rules.move_from_uci("e2e4"))
	await create_timer(0.2).timeout
	chess_table.start_match(0, false)
	await create_timer(1.0).timeout
	_check(chess_table.rules.get_fen() == CHESS_RULES.START_FEN and chess_table.is_idle(), "Schach: Reset im Flug verwirft alten Ablauf")
	chess_table._commit_child_move(chess_table.rules.move_from_uci("d2d4"))
	_check(await _until(func() -> bool: return chess_table.thinking), "Schach: Reset während Denken vorbereiten")
	chess_table.start_match(0, false)
	await create_timer(1.2).timeout
	_check(chess_table.rules.played.is_empty() and chess_table.is_idle(), "Schach: alte KI-Antwort verändert neue Partie nicht")
	chess_table.reduced_motion = true
	chess_table._commit_child_move(chess_table.rules.move_from_uci("e2e4"))
	await create_timer(0.25).timeout
	_check(chess_table.rules.played.size() == 1 and chess_table.thinking, "Schach: reduzierte Bewegung bewahrt Denkzeit")
	_check(not chess_table.chess.is_animating() and not chess_table.board2d.is_animating(), "Schach: reduzierte Bewegung ohne Flug")
	_check(await _until(func() -> bool: return chess_table.is_idle()), "Schach: reduzierte Bewegung beendet Zug korrekt")
	_check(chess_table.board2d.board == chess_table.rules.board, "Schach: reduzierter Endzustand stimmt")


func _fresh_cards(game: String, seed_value: int) -> RefCounted:
	var state: RefCounted = CARDS_SESSION.create_rules(game)
	state.setup({"players": 2, "difficulty": 1, "rounds": 1, "seed": seed_value,
		"result_id": "tempo-" + game + "-" + str(seed_value)})
	return state


func _cards_fixture(state: RefCounted) -> void:
	cards_table._open_select()
	cards_table.game = state.game_id()
	cards_table.rules = state
	cards_table.screen = "play"
	cards_table._intro_blocking = true
	cards_table._enter_table(false)
	cards_table._intro_blocking = false
	_check(state.check().is_empty(), "Kartentest nutzt gültigen Regelstand")


func _opponent_starts() -> RefCounted:
	for seed_value in range(1, 100):
		var state := _fresh_cards("stich", seed_value)
		if state.current() == 1:
			return state
	return null


func _cards_flow() -> void:
	cards_table = load("res://scenes/games/cards_table.tscn").instantiate()
	root.add_child(cards_table)
	await _frames(5)
	if is_instance_valid(cards_table.opening):
		cards_table.opening.finish()
	await _frames(3)
	var state := _opponent_starts()
	_check(state != null, "Gültige Partie mit KI als Ausspieler gefunden")
	_cards_fixture(state)
	var probe := _fresh_cards("stich", 1)
	probe.s = state.snapshot()
	var chosen: Dictionary = CARDS_SESSION.ai_move(probe, 1)
	var card: Node3D = cards_table.cards[int(chosen.card)]
	var start: Transform3D = card.transform
	await _capture("cards_00_before")
	cards_table._pump()
	_check(cards_table._busy and not cards_table._can_act(), "Karten: ganze KI-Aktion sperrt Eingabe")
	await create_timer(0.25).timeout
	_check(int(state.s.moves) == 0 and card.transform.is_equal_approx(start), "Karten: erkennbare Denkpause vor Bewegung")
	cards_table._pause()
	await create_timer(0.35).timeout
	_check(int(state.s.moves) == 0, "Karten: Pause hält KI-Denkzeit")
	cards_table._resume()
	_check(await _until(func() -> bool: return int(state.s.moves) == 1), "Karten: KI beginnt genau einen Zug")
	await create_timer(0.25).timeout
	var target: Transform3D = cards_table._slot(card, 0, 1)
	_check(card.is_moving() and not card.transform.is_equal_approx(start)
		and not card.transform.is_equal_approx(target), "Karten: sichtbare Zwischenposition Hand zu Tisch")
	_check(state.current() == 0 and not cards_table._can_act(), "Karten: trotz Regelübergabe bleibt Kind bis Landung gesperrt")
	cards_table._human_play(state.legal_moves(0)[0])
	_check(int(state.s.moves) == 1, "Karten: Eingabe während KI-Flug verändert Regeln nicht")
	await _capture("cards_01_lumo_card_in_flight")
	cards_table._pause()
	var held: Transform3D = card.transform
	await create_timer(0.3).timeout
	_check(card.transform.is_equal_approx(held) and card.is_moving(), "Karten: Pause bewahrt Zwischenposition und Bewegungsstatus")
	cards_table._resume()
	_check(await _until(func() -> bool: return cards_table.is_idle()), "Karten: KI-Zug endet geordnet")
	_check(card.transform.is_equal_approx(target) and cards_table._can_act(), "Karten: nach Landung ist Kind dran")
	_check(int(state.s.moves) == 1 and state.check().is_empty(), "Karten: genau ein legaler KI-Zug")
	await _capture("cards_02_settled")
	var saved: Dictionary = state.snapshot()
	cards_table._open_select()
	cards_table._start_match("stich", true)
	_check(cards_table.rules.snapshot() == saved, "Karten: Fortsetzen erhält exakt den abgeschlossenen Stand")


func _cards_transfer() -> void:
	var fixture: RefCounted
	var move: Dictionary = {}
	var given: Array[int] = []
	for seed_value in range(1, 300):
		var state := _fresh_cards("quartett", seed_value)
		if state.current() != 0:
			continue
		for option: Dictionary in state.legal_moves(0):
			if not option.has("ask"):
				continue
			var matches: Array[int] = []
			for id: int in state.s.r.hands[int(option.from)]:
				if DECK.rank(id) == int(option.ask):
					matches.append(id)
			if matches.size() >= 2:
				fixture = state
				move = option
				given = matches
				break
		if fixture != null:
			break
	_check(fixture != null, "Quartett: legalen Transfer mehrerer Karten gefunden")
	_cards_fixture(fixture)
	var first: Node3D = cards_table.cards[given[0]]
	var second: Node3D = cards_table.cards[given[1]]
	var second_start: Transform3D = second.global_transform
	cards_table._human_play(move)
	# Kein weiterer KI-Zug nach dieser Prüfsequenz; der gespielte Zug läuft weiter.
	cards_table._intro_blocking = true
	_check(await _until(func() -> bool: return first.is_moving()), "Quartett: erste Karte fliegt")
	await create_timer(0.25).timeout
	_check(not second.is_moving() and second.global_transform.is_equal_approx(second_start), "Quartett: zweite Karte wartet auf erste Landung")
	_check(await _until(func() -> bool: return second.is_moving()), "Quartett: zweite Karte folgt")
	_check(not first.is_moving(), "Quartett: Transfers überlappen nicht")
	await _capture("cards_quartet_sequential_transfer")
	_check(await _until(func() -> bool: return cards_table.is_idle()), "Quartett: gesamter Ereigniszug endet")
	_check(fixture.check().is_empty() and int(fixture.s.moves) == 1, "Quartett: konservierter Endzustand nach Transfer")


func _cards_abort_and_reduced_motion() -> void:
	var state := _opponent_starts()
	_cards_fixture(state)
	cards_table._pump()
	_check(await _until(func() -> bool: return int(state.s.moves) == 1), "Karten: Abbruch während Bewegung vorbereitet")
	await create_timer(0.15).timeout
	cards_table._open_select()
	await create_timer(1.3).timeout
	_check(cards_table.screen == "select" and cards_table.cards.is_empty() and cards_table.rules == null, "Karten: Menü verwirft veraltete Ereignisse")
	state = _opponent_starts()
	_cards_fixture(state)
	cards_table._pump()
	await create_timer(0.2).timeout
	cards_table._open_select()
	await create_timer(1.3).timeout
	_check(cards_table.screen == "select" and cards_table.rules == null, "Karten: Abbruch während Denken startet keinen Zug")
	state = _opponent_starts()
	cards_table.reduced_motion = true
	_cards_fixture(state)
	cards_table._pump()
	await create_timer(0.3).timeout
	_check(int(state.s.moves) == 0 and cards_table._busy, "Karten: reduzierte Bewegung bewahrt Denkzeit")
	_check(await _until(func() -> bool: return cards_table.is_idle()), "Karten: reduzierte Bewegung beendet Zug")
	_check(int(state.s.moves) == 1 and state.check().is_empty(), "Karten: reduzierter Endzustand stimmt")
