extends SceneTree
## Durchspiel der vier Kartenspiele (Team B3b): jede Variante bis zum Endstand,
## einmal gewonnen und einmal verloren – mit echten Berührungen, Einführung
## überspringen, Einstellungen (Mitspieler, Stärke, Runden), Sterne genau
## einmal an die App, „Nochmal“ und „Anderes Spiel“. Dazu der natürliche
## KI-Ablauf in echtem Tempo: Denkpause, Karte sichtbar aus dem Fächer nehmen,
## kurz halten, legen; der nächste Mitspieler beginnt erst nach der Landung.
## Menüs, Pause, Fortsetzen und Speichern prüft cards_table_regression.gd.
##
## Bilder (Sieg, Niederlage, Pause, Aufnehmen) unter xvfb mit echtem Renderer:
##   -- --capture=/absoluter/ordner   (2176x1812 und 1080x2340, JPG)

const TABLE := "res://scenes/games/cards_table.tscn"
const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const ART = preload("res://scripts/games/cards/cards_deck_art.gd")
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CHILD := "cards-durchspiel-regression"
const SIZES: Array[Vector2i] = [Vector2i(2176, 1812), Vector2i(1080, 2340)]
const WORK_SIZE := Vector2i(720, 600)
## TURN_THINK_SECONDS des Tisches mit Bildtakt-Toleranz.
const THINK_MIN := 0.85
const TITLES := ["Gewonnen!", "Zweiter Platz!", "Dritter Platz!", "Geschafft!"]

var checks := 0
var failures: Array[String] = []
var table: Node
var host: Host
var capture_dir := ""
var shots: Array[String] = []
var settled: Array[Dictionary] = []
## Wartegrenze in echten Sekunden; mit Software-Renderer und Bildern länger.
## Tempo der Ablaufmessung: echtes Tempo, mit Bildern vierfach (Software-Renderer).
var pace := 1.0
var limit := 40.0


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
		push_error("[CardsDurchspiel] " + label)


## Bild des aktuellen Moments in beiden Fold-Größen; danach zurück zur
## kleinen Arbeitsgröße (Software-Renderer bleibt so schnell genug).
func _shot(label: String) -> void:
	if capture_dir.is_empty():
		return
	var back := root.size
	for size: Vector2i in SIZES:
		root.size = size
		await DRIVER.settle(self, 8)
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var path := capture_dir.path_join("%s_%dx%d.jpg" % [label, size.x, size.y])
		_check(picture.save_jpg(path, 0.86) == OK, "Bild gespeichert: " + path)
		shots.append(path)
	root.size = back
	await DRIVER.settle(self, 4)


## Bild mitten in einer Bewegung: Tisch ohne Pausenmenü anhalten.
func _frozen_shot(label: String) -> void:
	if capture_dir.is_empty():
		return
	table._paused = true
	for id: int in table.cards:
		table.cards[id].set_suspended(true)
	for seat: Node3D in table.seats:
		seat.set_suspended(true)
	await _shot(label)
	table._paused = false
	for id: int in table.cards:
		table.cards[id].set_suspended(false)
	for seat: Node3D in table.seats:
		seat.set_suspended(false)


## Größe nur ohne Bilder wechseln: mit Bildern bleibt die Arbeitsgröße.
func _size(size: Vector2i) -> void:
	root.size = WORK_SIZE if not capture_dir.is_empty() else size


func _open(time_scale: float) -> void:
	table = load(TABLE).instantiate()
	root.add_child(table)
	table.time_scale = time_scale
	await DRIVER.skip_opening(self, table)
	table.settled.connect(func(payload: Dictionary) -> void: settled.append(payload))
	await DRIVER.settle(self, 4)


func _close(label: String) -> void:
	_check(
		await SCENE_TEARDOWN.release_scene(self, table, "[CardsDurchspiel] " + label),
		label + ": Szene wird freigegeben"
	)
	table = null
	await DRIVER.settle(self, 2)


func _press(id: String, label: String) -> void:
	_check(await DRIVER.press(self, table, id), label)
	await DRIVER.settle(self, 2)


func _run() -> void:
	Engine.max_fps = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_dir = argument.trim_prefix("--capture=")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		pace = 4.0
		limit = 600.0
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	var original_host: Object = bridge._host
	bridge._options = {
		"displayDensity": 1.75,
		"childKey": CHILD,
		"sessionId": "cards-durchspiel",
		"soundEnabled": false
	}
	host = Host.new()
	bridge._host = host
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	_size(SIZES[0])
	await _ai_pacing()
	var index := 0
	for game: String in ["stich", "ziel", "leiter", "quartett"]:
		_size(SIZES[index % 2])
		await _durchspiel(game, true)
		_size(SIZES[(index + 1) % 2])
		await _durchspiel(game, false)
		index += 1
	bridge._options = original_options
	bridge._host = original_host
	bridge._return_pending = false
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	var soundscape := root.get_node_or_null("GameSoundscape")
	if soundscape != null:
		soundscape.release_audio()
	await create_timer(0.5).timeout
	print(
		(
			"CARDS_DURCHSPIEL_%s checks=%d failures=%d shots=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), shots.size()]
		)
	)
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


## Echtes Tempo: Denkpause, sichtbares Aufnehmen, Landung vor dem nächsten Zug.
func _ai_pacing() -> void:
	await _open(pace)
	table.session.mark_intro_seen("stich")
	table.session.set_prefs(4, 1, 1)
	table._start_match("stich", false)
	_check(await DRIVER.idle(self, table, limit), "Tempo: Austeilen endet")
	var turns := 0
	var guard := 0
	while turns < (4 if pace == 1.0 else 2) and guard < 600 and table.rules.phase() == "playing":
		guard += 1
		if table._can_act():
			await DRIVER.play(self, table, DRIVER.suggestion(table))
			continue
		var player := int(table.rules.current())
		if player <= 0 or table._presenting_player != player:
			await process_frame
			continue
		await _measure_ai_turn(player, turns)
		turns += 1
	_check(
		turns >= (3 if pace == 1.0 else 2), "Tempo: mindestens drei KI-Züge gemessen (%d)" % turns
	)
	await _close("Tempo")


func _fan_slot(node: Node3D, player: int) -> Transform3D:
	var ids: Array = []
	for id: int in table.cards:
		if table.cards[id].zone == "fan" and table.cards[id].owner_seat == player:
			ids.append(id)
	ids.sort_custom(
		func(a: int, b: int) -> bool:
			if table.cards[a].order != table.cards[b].order:
				return table.cards[a].order < table.cards[b].order
			return a < b
	)
	return table._slot(node, ids.find(node.card_id), ids.size())


## Misst einen KI-Zug ab dem Beginn des Überlegens (Motor-Zeit).
func _measure_ai_turn(player: int, turn: int) -> void:
	var name: String = table.seats[player].display_name
	var moves_before := int(table.rules.s.moves)
	var hand: Array = table.rules.s.r.hands[player].duplicate()
	var engine := 0.0
	var first_motion := -1.0
	var first_card := -1
	var rules_at := -1.0
	var lifted := 0.0
	var pickup_shot := false
	var handover_clean := false
	var guard := 0
	while guard < 3000:
		guard += 1
		await process_frame
		engine += root.get_process_delta_time()
		var moving := false
		for id: int in table.cards:
			if table.cards[id].is_moving():
				# Die eigene Hand des Kindes rückt beim Zugbeginn zurecht.
				moving = moving or table.cards[id].zone != "hand"
				if first_motion < 0.0:
					first_motion = engine
					first_card = id
		if rules_at < 0.0 and int(table.rules.s.moves) != moves_before:
			rules_at = engine
		if first_card >= 0 and rules_at < 0.0 and table.cards[first_card].zone == "fan":
			var node: Node3D = table.cards[first_card]
			lifted = maxf(lifted, node.transform.origin.distance_to(_fan_slot(node, player).origin))
			if turn == 0 and not pickup_shot and not node.is_moving() and lifted > 0.05:
				pickup_shot = true
				await _frozen_shot("karten_aufnehmen")
			# Pause mitten im Aufnehmen hält Karte und Regeln an.
			if turn == 1 and node.is_moving() and lifted > 0.01 and not table._paused:
				table._pause()
				var held: Transform3D = node.transform
				for frame in 20:
					await process_frame
				_check(
					(
						node.transform.is_equal_approx(held)
						and int(table.rules.s.moves) == moves_before
					),
					"Tempo: Pause hält die aufgenommene Karte von %s an" % name
				)
				await _shot("karten_pause")
				table._resume()
		if rules_at >= 0.0:
			var next_begins: bool = table._can_act() or table.rules.phase() != "playing"
			for seat: Node3D in table.seats:
				if seat.mood == "think":
					next_begins = true
			if next_begins:
				handover_clean = not moving
				break
	print(
		(
			"[CardsDurchspiel] KI %s: Bewegung nach %.2f s, Regeländerung nach %.2f s, angehoben %.3f m"
			% [name, first_motion, rules_at, lifted]
		)
	)
	_check(
		first_motion >= THINK_MIN / pace,
		"Tempo: %s denkt sichtbar vor der ersten Bewegung (%.2f s)" % [name, first_motion]
	)
	_check(
		first_card >= 0 and hand.has(first_card),
		"Tempo: %s bewegt zuerst eine eigene Handkarte" % name
	)
	_check(
		rules_at > first_motion + table.PICK_UP_SECONDS * 0.8 / pace,
		"Tempo: %s nimmt die Karte auf, bevor sie gilt (%.2f s)" % [name, rules_at - first_motion]
	)
	_check(
		lifted >= ART.HEIGHT * table.PICK_LIFT * 0.8,
		"Tempo: %s hebt die Karte sichtbar an (%.3f m)" % [name, lifted]
	)
	_check(
		not table.rules.s.r.hands[player].has(first_card),
		"Tempo: die aufgenommene Karte ist die gelegte (%d)" % first_card
	)
	_check(handover_clean, "Tempo: nach %s beginnt der nächste Zug erst nach der Landung" % name)


## Eine Partie bis zum Ende: `win` wählt leichte Gegner und gute Züge,
## sonst starke Gegner und schwache Züge. Wiederholt mit neuen Karten, bis
## das gewünschte Ergebnis eintritt.
func _durchspiel(game: String, win: bool) -> void:
	await _open(60.0)
	var label := "%s %s" % [game, "Sieg" if win else "Niederlage"]
	await DRIVER.touch(self, DRIVER.control_centre(table.hud.find_button("Tile_" + game)))
	await DRIVER.settle(self, 3)
	if not table._intro_steps.is_empty():
		_check(
			table.hud.find_button("intro_skip") != null,
			label + ": Einführung lässt sich überspringen"
		)
		await _press("intro_skip", label + ": Einführung überspringen")
		await DRIVER.idle(self, table, limit)
		if table.hud.overlay_kind != "setup":
			table._open_setup(game)
			await DRIVER.settle(self, 2)
	_check(table.hud.overlay_kind == "setup", label + ": Einstellungen erscheinen")
	await _press("Pick_players_2", label + ": ein Mitspieler")
	await _press("Pick_difficulty_%d" % (0 if win else 2), label + ": Stärke")
	await _press("Pick_rounds_1", label + ": eine Runde")
	var reached := false
	for attempt in range(12):
		table.forced_seed = 1 + attempt * 7919 + (0 if win else 104729)
		if attempt == 0:
			await _press("start", label + ": Start")
		else:
			await _press("again", label + ": Nochmal")
		_check(await DRIVER.idle(self, table, limit), label + ": Austeilen endet")
		var result_id := str(table.rules.s.result_id)
		var stars_before: int = root.get_node("ProgressStore").total_stars()
		var rewards_before := host.rewards.size()
		settled.clear()
		await _play(win, label)
		if table.screen != "final":
			_check(false, label + ": Partie endet nicht (Versuch %d)" % attempt)
			break
		var place: int = int(table.rules.places()[0])
		_check(
			settled.size() == 1 and host.rewards.size() == rewards_before + 1,
			label + ": genau eine Belohnung an die App"
		)
		var payload: Dictionary = (
			JSON.parse_string(host.rewards.back()) if host.rewards.size() > rewards_before else {}
		)
		_check(
			str(payload.get("resultId", "")) == result_id and int(payload.get("place", 0)) == place,
			label + ": Belohnung trägt Partie und Platz"
		)
		_check(
			(
				root.get_node("ProgressStore").total_stars()
				== stars_before + int(payload.get("stars", 0))
			),
			label + ": Sterne einmal gutgeschrieben"
		)
		_check(
			table.hud.overlay_kind == "final" and str(table._final_data.title) == TITLES[place - 1],
			label + ": Endstand zeigt „%s“" % TITLES[place - 1]
		)
		for id: String in ["again", "menu", "leave"]:
			_check(table.hud.find_button(id) != null, label + ": Endstand bietet " + id)
		# Endstand erneut zeigen bucht nichts doppelt.
		table._finish_match()
		await DRIVER.settle(self, 2)
		_check(
			host.rewards.size() == rewards_before + 1 and settled.size() == 1,
			label + ": kein zweites Buchen"
		)
		if (place == 1) == win:
			reached = true
			await _shot("karten_%s_%s" % [game, "sieg" if win else "niederlage"])
			break
	_check(reached, label + ": gewünschtes Ergebnis erreicht")
	await _press("menu", label + ": Anderes Spiel")
	_check(
		table.screen == "select" and not table.session.has_match(game),
		label + ": Auswahl ohne offene Partie"
	)
	await _close(label)


func _play(win: bool, label: String) -> void:
	var guard := 0
	while guard < 800 and table.screen == "play":
		guard += 1
		if not await DRIVER.idle(self, table, limit):
			_check(false, label + ": der Tisch hängt")
			return
		if table.hud.overlay_kind == "round":
			await _press("next_round", label + ": nächste Runde")
			continue
		if not table.hud.overlay_kind.is_empty():
			return
		if table._can_act():
			var before := int(table.rules.s.moves)
			var move: Dictionary = _child_move(win)
			if not await DRIVER.play(self, table, move):
				_check(false, "%s: Zug %s per Berührung nicht möglich" % [label, str(move)])
				return
			await DRIVER.idle(self, table, limit)
			if (
				table.rules != null
				and table.screen == "play"
				and int(table.rules.s.moves) == before
			):
				_check(false, "%s: Zug %s nicht angenommen" % [label, str(move)])
				return


func _child_move(win: bool) -> Dictionary:
	var rules: RefCounted = table.rules
	var probe: RefCounted = SESSION.create_rules(rules.game_id())
	probe.s = rules.snapshot()
	if win:
		return SESSION.ai_move(probe, 0, 2)
	# Schwach: die kleinste erlaubte Karte, wenn möglich passen oder ziehen.
	var legal: Array = rules.legal_moves(0)
	var best: Dictionary = legal[0]
	for move: Dictionary in legal:
		if move.has("pass") or move.has("draw"):
			return move
		if (
			move.has("card")
			and best.has("card")
			and DECK.rank(int(move.card)) < DECK.rank(int(best.card))
		):
			best = move
	return best
