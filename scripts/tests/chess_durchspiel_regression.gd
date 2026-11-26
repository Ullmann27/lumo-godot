extends SceneTree
## Durchspiel Schach (Team B3b): ganze Partien gegen Lumo bis zum Ende –
## einmal gewonnen (Kind spielt gute Züge gegen die leichteste Stufe), einmal
## verloren (zufällige Züge gegen die stärkste Stufe). Sterne genau einmal an
## die App (bei Niederlage keine), Endbild mit „Neue Partie“ und „Hauptmenü“,
## Pause hält alles an, Speichern und Fortsetzen nach dem Schließen.
## Dazu der natürliche Ablauf in echtem Tempo: Erst landet die Figur des
## Kindes, dann denkt Lumo sichtbar, dann hebt seine Figur an, gleitet und
## setzt weich ab; erst danach ist das Kind wieder dran.
## Lektionen, Proben, Regeln und Touch-Ziele prüft chess_table_regression.gd.
##
## Bilder unter xvfb: -- --capture=/absoluter/ordner (2176x1812, 1080x2340)

const SCENE := "res://scenes/games/chess_table.tscn"
const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const AI = preload("res://scripts/games/chess/chess_ai.gd")
const SET = preload("res://scripts/games/chess/chess_set.gd")
const CHESS_SESSION = preload("res://scripts/games/chess/chess_session.gd")
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CHILD := "chess-durchspiel-regression"
const SIZES: Array[Vector2i] = [Vector2i(2176, 1812), Vector2i(1080, 2340)]
const WORK_SIZE := Vector2i(720, 600)

var checks := 0
var failures: Array[String] = []
var table: Node
var host: Host
var capture_dir := ""
var shots: Array[String] = []
var settled: Array[Dictionary] = []
var helper: RefCounted
var rng := RandomNumberGenerator.new()
## Tempo der Ablaufmessung: echtes Tempo, mit Bildern vierfach (Software-Renderer).
var pace := 1.0
var limit := 60.0


class Host:
	extends RefCounted
	var rewards: Array[String] = []
	var returns: Array[String] = []

	# gdlint: disable=function-name
	func reward(payload: String) -> int:
		rewards.append(payload)
		return 1

	# gdlint: disable=function-name
	func returnToApp(destination: String, _payload: String) -> int:
		returns.append(destination)
		return 1


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[ChessDurchspiel] " + label)


func _frames(count: int = 3) -> void:
	for i in count:
		await process_frame


## Bild des aktuellen Moments in beiden Fold-Größen; danach zurück zur
## kleinen Arbeitsgröße (Software-Renderer bleibt so schnell genug).
func _shot(label: String) -> void:
	if capture_dir.is_empty():
		return
	var back := root.size
	for size: Vector2i in SIZES:
		root.size = size
		await _frames(8)
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var path := capture_dir.path_join("%s_%dx%d.jpg" % [label, size.x, size.y])
		_check(picture.save_jpg(path, 0.86) == OK, "Bild gespeichert: " + path)
		shots.append(path)
	root.size = back
	await _frames(4)


## Bild mitten in Lumos Zug: Brett ohne Pausenmenü anhalten.
func _frozen_shot(label: String) -> void:
	if capture_dir.is_empty():
		return
	table._paused = true
	table.chess.set_suspended(true)
	table.board2d.set_suspended(true)
	await _shot(label)
	table._paused = false
	table.chess.set_suspended(false)
	table.board2d.set_suspended(false)


## Größe nur ohne Bilder wechseln: mit Bildern bleibt die Arbeitsgröße.
func _size(size: Vector2i) -> void:
	root.size = WORK_SIZE if not capture_dir.is_empty() else size


func _until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _open() -> void:
	table = load(SCENE).instantiate()
	root.add_child(table)
	await _frames(5)
	table.settled.connect(func(payload: Dictionary) -> void: settled.append(payload))


func _close(label: String) -> void:
	_check(
		await SCENE_TEARDOWN.release_scene(self, table, "[ChessDurchspiel] " + label),
		label + ": Szene frei"
	)
	table = null
	await _frames(2)


func _run() -> void:
	Engine.max_fps = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_dir = argument.trim_prefix("--capture=")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		pace = 4.0
		limit = 900.0
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	var original_host: Object = bridge._host
	bridge._options = {
		"childKey": CHILD,
		"displayDensity": 1.5,
		"soundEnabled": false,
		"sessionId": "chess-durchspiel"
	}
	host = Host.new()
	bridge._host = host
	DirAccess.remove_absolute(CHESS_SESSION.path_for(CHILD))
	helper = AI.new(4242)
	rng.seed = 2026
	_size(SIZES[0])
	await _pacing()
	_size(SIZES[1])
	await _pause_and_resume()
	_size(SIZES[0])
	await _full_game(true)
	_size(SIZES[1])
	await _full_game(false)
	bridge._options = original_options
	bridge._host = original_host
	bridge._return_pending = false
	DirAccess.remove_absolute(CHESS_SESSION.path_for(CHILD))
	var soundscape := root.get_node_or_null("GameSoundscape")
	if soundscape != null:
		soundscape.release_audio()
	await create_timer(0.5).timeout
	print(
		(
			"CHESS_DURCHSPIEL_%s checks=%d failures=%d shots=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), shots.size()]
		)
	)
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _touch(point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await process_frame


## Ein Zug des Kindes per Antippen: Figur, dann Zielfeld.
func _tap_move(m: int) -> bool:
	var before: int = table.rules.played.size()
	await _touch(table.square_point(RULES.move_from(m)))
	await _touch(table.square_point(RULES.move_to(m)))
	return table.rules.played.size() == before + 1


func _start(level: int, scale: float) -> void:
	table.mode = "play"
	table.view = "3d"
	table.time_scale = scale
	table.start_match(level, false)
	table.hints = false
	await _frames(3)


## Echtes Tempo: Landung, Denken, Anheben, Gleiten, Absetzen, Übergabe.
func _pacing() -> void:
	await _open()
	await _start(0, pace)
	table.ai.rng.seed = 11
	for turn in 3:
		_check(
			await _until(func() -> bool: return table.is_idle(), limit),
			"Tempo: Kind ist am Zug (%d)" % turn
		)
		var moves: PackedInt32Array = table._child_moves()
		var m: int = moves[(turn * 7) % moves.size()]
		if turn == 0:
			m = table.rules.move_from_uci("e2e4")
			_check(await _tap_move(m), "Tempo: erster Zug per Antippen")
		else:
			table._child_move(m)
		await _measure_turn(turn)
	await _close("Tempo")


func _measure_turn(turn: int) -> void:
	var engine := 0.0
	var child_landed := -1.0
	var think_at := -1.0
	var reply_at := -1.0
	var played_before: int = table.rules.played.size()
	var mover: Node3D
	var start := Vector3.ZERO
	var goal := Vector3.ZERO
	var lifted_early := 0.0
	var max_height := 0.0
	var overlapped := false
	var shot_taken := false
	var guard := 0
	while guard < 4000:
		guard += 1
		await process_frame
		engine += root.get_process_delta_time()
		var animating: bool = table.chess.is_animating()
		if child_landed < 0.0 and not animating:
			child_landed = engine
		if table.thinking and think_at < 0.0:
			think_at = engine
			overlapped = overlapped or animating
		if reply_at < 0.0 and table.rules.played.size() > played_before:
			reply_at = engine
			var reply: int = table.rules.last_move()
			mover = table.chess.pieces.get(RULES.move_to(reply))
			start = table.chess.square_center(RULES.move_from(reply))
			goal = table.chess.square_center(RULES.move_to(reply))
			_check(
				table._child_moves().is_empty(), "Tempo: während Lumos Zug ist das Kind gesperrt"
			)
		if reply_at >= 0.0 and is_instance_valid(mover) and animating:
			var flat := Vector2(mover.position.x - start.x, mover.position.z - start.z).length()
			var whole := maxf(0.001, Vector2(goal.x - start.x, goal.z - start.z).length())
			var height := mover.position.y - start.y
			max_height = maxf(max_height, height)
			if flat / whole < 0.1:
				lifted_early = maxf(lifted_early, height)
			if turn == 1 and not shot_taken and flat / whole > 0.4 and flat / whole < 0.7:
				shot_taken = true
				await _frozen_shot("schach_lumo_zieht")
		if reply_at >= 0.0 and not table.busy:
			break
	print(
		(
			(
				"[ChessDurchspiel] Zug %d: Kind gelandet %.2f s, Lumo denkt ab %.2f s, "
				+ "zieht ab %.2f s, angehoben %.3f m vor dem Gleiten, Spitze %.3f m"
			)
			% [turn, child_landed, think_at, reply_at, lifted_early, max_height]
		)
	)
	_check(
		child_landed >= 0.0 and think_at >= child_landed,
		"Tempo %d: Lumo denkt erst nach der Landung" % turn
	)
	_check(not overlapped, "Tempo %d: keine Bewegung beim Denkbeginn" % turn)
	_check(
		reply_at - think_at >= table.TURN_THINK_SECONDS * 0.9 / pace,
		"Tempo %d: sichtbare Denkpause (%.2f s)" % [turn, reply_at - think_at]
	)
	_check(
		lifted_early >= SET.PIECE_LIFT * 0.5,
		"Tempo %d: Figur hebt vor dem Gleiten an (%.3f m)" % [turn, lifted_early]
	)
	_check(
		is_instance_valid(mover) and mover.position.is_equal_approx(goal),
		"Tempo %d: Figur steht genau auf dem Zielfeld" % turn
	)
	_check(
		not table.busy and not table._child_moves().is_empty(),
		"Tempo %d: danach ist das Kind dran" % turn
	)


func _pause_and_resume() -> void:
	await _open()
	await _start(1, 4.0)
	for turn in 3:
		await _until(func() -> bool: return table.is_idle(), limit)
		var moves: PackedInt32Array = table._child_moves()
		table._child_move(moves[(turn * 5 + 3) % moves.size()])
	_check(
		await _until(func() -> bool: return table.thinking or table.chess.is_animating(), limit),
		"Pause: Lumo ist beschäftigt"
	)
	table._on_pause()
	_check(table.overlay_kind == "pause" and table._paused, "Pause: Menü erscheint")
	for id: String in ["o_Resume", "o_Rules", "o_Resign", "o_Menu", "o_Leave"]:
		_check(table.find_button(id) != null, "Pause bietet " + id)
	var played: int = table.rules.played.size()
	await create_timer(1.5).timeout
	_check(table.rules.played.size() == played, "Pause: Lumo zieht nicht weiter")
	await _shot("schach_pause")
	table.find_button("o_Resume").pressed.emit()
	_check(not table._paused and table.overlay_kind.is_empty(), "Weiter schließt die Pause")
	_check(await _until(func() -> bool: return table.is_idle(), limit), "Pause: Spiel läuft weiter")
	var fen: String = table.rules.get_fen()
	var result_id: String = table.result_id
	await _close("Pause")
	await _open()
	table.mode = "play"
	table.start_match(-1, true)
	await _frames(3)
	_check(
		table.rules.get_fen() == fen and table.result_id == result_id,
		"Fortsetzen nach dem Schließen: gleiche Stellung und Partie"
	)
	table.session.discard_game(table._slot())
	await _close("Fortsetzen")


## Gewinnen: starke Züge gegen Stufe 0. Verlieren: Zufallszüge gegen Stufe 3.
func _full_game(win: bool) -> void:
	var label := "Schach %s" % ("Sieg" if win else "Niederlage")
	await _open()
	var level := 0 if win else 3
	var reached := false
	for attempt in 4:
		var rewards_before := host.rewards.size()
		settled.clear()
		await _start(level, 40.0)
		table.ai.rng.seed = 100 + attempt
		var result_id: String = table.result_id
		var guard := 0
		while guard < 400 and not table.finished:
			guard += 1
			if not await _until(func() -> bool: return table.is_idle() or table.finished, limit):
				_check(false, label + ": Tisch hängt")
				break
			if table.finished:
				break
			var m := await _child_choice(win)
			if m < 0:
				break
			table._child_move(m)
		await _until(func() -> bool: return table.overlay_kind == "end", limit)
		var outcome := (
			"win"
			if (
				table.rules != null
				and table.rules.status() == "checkmate"
				and table.rules.winner() == 0
			)
			else "other"
		)
		if (
			table.rules != null
			and table.rules.status() == "checkmate"
			and table.rules.winner() == 1
		):
			outcome = "loss"
		print(
			(
				"[ChessDurchspiel] %s Versuch %d: %s nach %d Halbzügen"
				% [
					label,
					attempt,
					outcome,
					table.rules.played.size() if table.rules != null else -1
				]
			)
		)
		_check(table.overlay_kind == "end", label + ": Endbild erscheint")
		_check(
			table.find_button("o_Again") != null and table.find_button("o_Menu") != null,
			label + ": Neue Partie und Hauptmenü"
		)
		if outcome == "win":
			_check(
				host.rewards.size() == rewards_before + 1 and settled.size() == 1,
				label + ": genau eine Belohnung"
			)
			var payload: Dictionary = (
				JSON.parse_string(host.rewards.back())
				if host.rewards.size() > rewards_before
				else {}
			)
			_check(
				(
					str(payload.get("resultId", "")) == result_id
					and int(payload.get("stars", 0)) == table.LEVEL_STARS[level]
				),
				label + ": Sterne der Stufe"
			)
			# Ein zweites Auswerten bucht nichts.
			table._settle("play:x", 1, "win", result_id)
			_check(host.rewards.size() == rewards_before + 1, label + ": kein doppeltes Buchen")
		elif outcome == "loss":
			_check(
				host.rewards.size() == rewards_before and settled.is_empty(),
				label + ": verloren bringt keine Sterne"
			)
			_check(table.session.is_booked(result_id), label + ": Partie ist gebucht")
		if (outcome == "win") == win and outcome != "other":
			reached = true
			await _shot("schach_%s" % ("sieg" if win else "niederlage"))
			break
		table.find_button("o_Again").pressed.emit()
		await _frames(3)
		_check(
			table.screen == "match" and not table.finished and table.result_id != result_id,
			label + ": Neue Partie startet frisch"
		)
	_check(reached, label + ": gewünschtes Ergebnis erreicht")
	table.find_button("o_Menu").pressed.emit()
	await _frames(3)
	_check(table.screen == "home", label + ": Hauptmenü")
	_check(
		table.session.resume_game(table._slot()).is_empty(),
		label + ": keine beendete Partie zum Fortsetzen"
	)
	await _close(label)


func _child_choice(win: bool) -> int:
	var moves: PackedInt32Array = table._child_moves()
	if moves.is_empty():
		return -1
	if not win:
		return moves[rng.randi_range(0, moves.size() - 1)]
	var result: Dictionary = await helper.think(
		table.rules, 3, {"budget_ms": 120, "slice_ms": 0, "random_off": true}
	)
	return int(result.get("move", moves[0]))
