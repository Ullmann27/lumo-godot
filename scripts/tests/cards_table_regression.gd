extends SceneTree
## Der neue Kartentisch von der Auswahl bis zum Endstand – bedient mit echten
## Berührungen. Regeln und KI prüft cards_rules_regression.gd ohne Szene.

const TABLE := "res://scenes/games/cards_table.tscn"
const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const INTRO = preload("res://scripts/games/cards/cards_intro.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CHILD := "cards-table-regression"
const SHAPES := [
	[Vector2i(720, 1280), 1.75], [Vector2i(1280, 720), 1.75],
	[Vector2i(1768, 2208), 2.4], [Vector2i(2208, 1768), 2.4],
]
const SPEED := 60.0

var checks := 0
var failures: Array[String] = []
var table: Node
var settled: Array[Dictionary] = []
var rewards: Array[Dictionary] = []


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
		push_error("[CardsTable] " + label)


func _open() -> void:
	table = load(TABLE).instantiate()
	root.add_child(table)
	table.time_scale = SPEED
	table.settled.connect(func(payload: Dictionary) -> void: settled.append(payload))
	await DRIVER.settle(self, 4)


func _close(label: String) -> void:
	_check(await SCENE_TEARDOWN.release_scene(self, table, "[CardsTable] " + label), label + " releases the scene")
	table = null
	await DRIVER.settle(self, 2)


func _press(id: String, label: String) -> void:
	_check(await DRIVER.press(self, table, id), label)
	await DRIVER.settle(self, 2)


func _run() -> void:
	Engine.max_fps = 0
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	var original_host: Object = bridge._host
	bridge._options = {"displayDensity": 1.75, "childKey": CHILD, "sessionId": "cards-session", "soundEnabled": false}
	bridge.reward_reported.connect(func(payload: Dictionary) -> void: rewards.append(payload))
	var save_path := SESSION.path_for(CHILD)
	DirAccess.remove_absolute(save_path)
	root.size = SHAPES[0][0]
	for game: String in SESSION.GAMES:
		_check(INTRO.ready(game).is_empty(), "intro round of %s teaches its rule: %s" % [game, INTRO.ready(game)])
	_check(not ResourceLoader.exists("res://assets/cards_table/cards/red/red_draw_two.png")
		and not FileAccess.file_exists("res://scripts/games/cards/cards_table_actor.gd"), "the old UNO table art and actor are gone")
	await _open()
	_scene_checks()
	var only := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	if only.is_empty():
		await _layouts()
	if only in ["", "stich"]:
		await _stich(bridge)
	if only in ["", "leiter"]:
		await _leiter()
	if only in ["", "quartett"]:
		await _quartett(bridge)
	if is_instance_valid(table):
		await _close("end")
	bridge._options = original_options
	bridge._host = original_host
	DirAccess.remove_absolute(save_path)
	print("CARDS_TABLE_RUNTIME_%s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _scene_checks() -> void:
	_check(table.screen == "select" and table.hud.overlay_kind == "select", "the route opens the game selection")
	for game: String in SESSION.GAMES:
		_check(table.hud.find_button("Tile_" + game) != null, "selection offers " + game)
	_check(table.seats.size() == 4, "Lumo and three fellow players sit at the table")
	_check(table.seats[0].kind == "lumo" and table.seats[0].usable() and table.seats[0].skeleton.get_bone_count() == 65,
		"Lumo is the original 65-bone character")
	for player in range(1, table.seats.size()):
		_check(table.seats[player].usable() and table.seats[player].kind in table.ROSTER, "fellow player %d is a roster character" % player)
	_check(table.room.batches.size() > 0 and table.room.batched_instances > table.room.batches.size() * 5,
		"static room parts are batched (%d parts in %d batches)" % [table.room.batched_instances, table.room.batches.size()])
	_check(table.room.find_children("*", "OmniLight3D", true, false).size() + table.room.find_children("*", "SpotLight3D", true, false).size() <= 3,
		"the room keeps a small light budget")
	_check(table.room.camera.current, "the table camera is active")


func _targets(label: String, density: float) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(root.size))
	var seen := 0
	for button: Button in table.hud.visible_buttons():
		var rect := Rect2(button.get_global_transform_with_canvas() * Vector2.ZERO, button.size)
		seen += 1
		_check(view.grow(0.5).encloses(rect), "%s: %s stays inside the screen %s" % [label, button.name, rect])
		_check(minf(rect.size.x, rect.size.y) / density >= 47.9, "%s: %s is at least 48 dp (%s)" % [label, button.name, rect.size / density])
	_check(seen > 0, label + " shows touch targets")


func _layouts() -> void:
	var bridge := root.get_node("HostBridge")
	for entry: Array in SHAPES:
		root.size = entry[0]
		bridge._options["displayDensity"] = entry[1]
		await DRIVER.settle(self, 3)
		table._resize()
		await DRIVER.settle(self, 3)
		var label := "%dx%d" % [root.size.x, root.size.y]
		_targets(label + " selection", entry[1])
		table.session.mark_intro_seen("leiter")
		table._on_chosen("game", {"game": "leiter"})
		await DRIVER.settle(self, 3)
		_targets(label + " setup", entry[1])
		table._on_chosen("start", {"game": "leiter"})
		_check(await DRIVER.idle(self, table), label + " deal settles")
		_targets(label + " play", entry[1])
		var hand: Array = table.hand_cards()
		_check(hand.size() == 9, label + " shows nine hand cards")
		var view := Rect2(Vector2.ZERO, Vector2(root.size))
		for card: int in hand:
			var point: Vector2 = DRIVER.hand_point(table, card)
			_check(view.has_point(point), "%s: hand card %d is reachable at %s" % [label, card, point])
			_check(table._hand_card_at(point) == card, "%s: the visible corner of card %d picks that card (got %d at %s)" % [label, card, table._hand_card_at(point), point])
		var ladder_x: Array = []
		for card: int in table.cards:
			if table.cards[card].zone == "fan":
				_check(view.grow(40).has_point(table.card_point(card)), label + " fellow players' cards are in view")
		for plate: Button in table.hud.plates:
			ladder_x.append(plate.position.x)
			_check(view.encloses(Rect2(plate.get_global_transform_with_canvas() * Vector2.ZERO, plate.size)), label + " name plate inside the screen")
		table._pause()
		await DRIVER.settle(self, 3)
		_targets(label + " pause", entry[1])
		table._on_chosen("quit", {})
		await DRIVER.settle(self, 3)
		table.session.discard("leiter")
	table.session.data.intro_seen.erase("leiter")
	table.session.save_file()
	root.size = SHAPES[0][0]
	bridge._options["displayDensity"] = SHAPES[0][1]
	await DRIVER.settle(self, 3)
	table._resize()
	table._open_select()
	await DRIVER.settle(self, 3)


## Führt durch die Einführung; das Kind handelt in den Mitmach-Schritten selbst.
func _intro(game: String) -> void:
	await DRIVER.touch(self, DRIVER.control_centre(table.hud.find_button("Tile_" + game)))
	await DRIVER.settle(self, 3)
	_check(table.screen == "play" and table.game == game and not table._intro_steps.is_empty(), game + ": first visit starts the playable introduction")
	_check(is_instance_valid(table.hud.bubble), game + ": Lumo explains in a speech bubble")
	_check(table.hud.find_button("intro_skip") != null, game + ": the introduction can be skipped")
	var steps := 0
	var guard := 0
	while not table._intro_steps.is_empty() and guard < 40:
		guard += 1
		_check(await DRIVER.idle(self, table), game + ": introduction step settles")
		var step: Dictionary = table._intro_step()
		if step.is_empty():
			break
		match str(step.wait):
			"tap", "done":
				steps += 1
				await _press("intro_next", game + ": Weiter is pressed")
			"select":
				steps += 1
				_check(table._can_act(), game + ": the child may choose a card in the introduction")
				var own: int = table.rules.s.r.hands[0][0]
				await DRIVER.touch(self, DRIVER.hand_point(table, own))
				await DRIVER.settle(self, 3)
				_check(table._pick_rank == DECK.rank(own), game + ": tapping a card selects its value")
			"play":
				steps += 1
				_check(table._can_act(), game + ": the child plays a real move in the introduction")
				var move: Dictionary = DRIVER.suggestion(table)
				if game == "quartett":
					move = {"ask": table._pick_rank, "from": 1}
				var before: int = int(table.rules.s.moves)
				_check(await DRIVER.play(self, table, move), game + ": introduction move is made by touch")
				await DRIVER.idle(self, table)
				_check(int(table.rules.s.moves) > before, game + ": the introduction move counts in the real rule core")
	_check(steps == 4, "%s: the introduction has four steps (%d)" % [game, steps])
	await DRIVER.settle(self, 3)
	_check(table.hud.overlay_kind == "setup" and table.session.intro_seen(game), game + ": after the introduction the settings open")
	_check(not table.session.has_match(game), game + ": the practice round is not saved")


func _pick(key: String, value: int, label: String) -> void:
	await _press("Pick_%s_%d" % [key, value], label)


## Spielt mit Berührungen, bis `stop` wahr wird oder die Partie endet.
func _play_until(stop: Callable, label: String) -> void:
	var guard := 0
	while guard < 600 and table.screen in ["play"]:
		guard += 1
		if not await DRIVER.idle(self, table, 40.0):
			_check(false, label + ": the table hangs")
			return
		if stop.call():
			return
		if table.hud.overlay_kind == "round":
			await _press("next_round", label + ": next round")
			continue
		if not table.hud.overlay_kind.is_empty():
			return
		if table._can_act():
			var before: int = int(table.rules.s.moves)
			var move: Dictionary = DRIVER.suggestion(table)
			if not await DRIVER.play(self, table, move):
				_check(false, "%s: move %s could not be made by touch" % [label, str(move)])
				return
			await DRIVER.idle(self, table, 40.0)
			if table.rules != null and int(table.rules.s.moves) == before:
				_check(false, "%s: touch move %s was not accepted" % [label, str(move)])
				return


func _final_checks(game: String, result_id: String, stars_before: int) -> Dictionary:
	_check(table.screen == "final" and table.hud.overlay_kind == "final", game + ": the match ends with the final standings")
	_check(settled.size() == 1, game + ": the result is settled exactly once")
	var payload: Dictionary = settled[0] if settled.size() == 1 else {}
	_check(payload.get("resultId") == result_id and payload.get("game") == "cards" and payload.get("variant") == game
		and payload.get("status") == "completed", game + ": the result carries the match id")
	var place: int = int(table.rules.places()[0])
	_check(int(payload.get("place", 0)) == place and int(payload.get("stars", 0)) == SESSION.stars_for(place, int(table.rules.s.difficulty), table.rules.rounds_total()),
		game + ": stars follow the place")
	_check(root.get_node("ProgressStore").total_stars() == stars_before + int(payload.get("stars", 0)), game + ": stars are added once")
	_check(table.session.is_booked(result_id) and not table.session.has_match(game), game + ": the finished match is booked and cleared")
	return payload


func _stich(bridge: Node) -> void:
	var game := "stich"
	await _intro(game)
	await _pick("players", 4, game + ": three fellow players")
	await _pick("difficulty", 2, game + ": hard")
	await _pick("rounds", 3, game + ": three rounds")
	_check(table.session.prefs() == {"players": 4, "difficulty": 2, "rounds": 3}, game + ": the choices are stored")
	await _press("start", game + ": start")
	_check(await DRIVER.idle(self, table), game + ": deal settles")
	_check(table.rules.players() == 4 and int(table.rules.s.difficulty) == 2 and table.rules.rounds_total() == 3, game + ": the match follows the settings")
	_check(table.cards.size() == 28 + table.STOCK_SHOWN, game + ": every hand card and the stock are 3D cards")
	var result_id := str(table.rules.s.result_id)
	_check(result_id.begins_with("cards-stich-"), game + ": the match has its own result id")
	await _play_until(func() -> bool: return table._can_act() and table._legal_cards.size() < table.rules.s.r.hands[0].size(), game)
	# Nicht bedienbare Karte: wird abgelehnt und erklärt.
	var refused := -1
	for card: int in table.rules.s.r.hands[0]:
		if not table._legal_cards.has(card):
			refused = card
	_check(refused >= 0, game + ": a hand with a forbidden card is reached")
	var before: Dictionary = table.rules.snapshot()
	await DRIVER.touch(self, DRIVER.hand_point(table, refused))
	await DRIVER.settle(self, 3)
	_check(table.rules.snapshot() == before and table._selected.is_empty(), game + ": a card that may not be played stays in the hand")
	_check("bedienen" in table.hud.hint_label.text, game + ": the table says why: " + table.hud.hint_label.text)
	_check(table.cards[refused].look() == "dim", game + ": forbidden cards are dimmed")
	var legal: int = table._legal_cards.keys()[0]
	_check(table.cards[legal].glow != null and table.cards[legal].glow.visible, game + ": playable cards glow")
	# Ziehen: Karte nach oben auf den Tisch schieben.
	var from: Vector2 = DRIVER.hand_point(table, legal)
	await DRIVER.drag(self, from, Vector2(root.size.x * 0.5, root.size.y * 0.45))
	await DRIVER.idle(self, table)
	_check(not table.rules.s.r.hands[0].has(legal), game + ": dragging a card onto the table plays it")
	# Pause hält die Mitspieler an.
	await _play_until(func() -> bool: return table._can_act(), game)
	await _press("Pause", game + ": pause")
	_check(table.hud.overlay_kind == "pause" and table._paused, game + ": the pause menu opens")
	for id: String in ["continue", "rules", "restart", "quit"]:
		_check(table.hud.find_button(id) != null, game + ": pause offers " + id)
	await _press("rules", game + ": rules")
	_check(table.hud.overlay_kind == "rules", game + ": rules are shown")
	await _press("rules_done", game + ": back from rules")
	var moves: int = int(table.rules.s.moves)
	_check(table.hud.overlay.mouse_filter == Control.MOUSE_FILTER_STOP and not table._can_act(), game + ": the pause menu covers the table")
	table._tap_card(int(table.rules.s.r.hands[0][0]))
	await DRIVER.settle(self, 6)
	_check(int(table.rules.s.moves) == moves and table._selected.is_empty(), game + ": nothing moves while paused")
	await _press("continue", game + ": continue")
	_check(table.hud.overlay_kind.is_empty() and not table._paused, game + ": play goes on")
	# Speichern und Fortsetzen: Tisch schließen, neu öffnen, gleiche Partie.
	await _play_until(func() -> bool: return table._can_act() and int(table.rules.s.r.trick_no) >= 2, game)
	var saved: Dictionary = table.rules.snapshot()
	await _close("stich mid-match")
	await _open()
	_check(table.session.has_match(game), game + ": a running match is found after reopening")
	await DRIVER.touch(self, DRIVER.control_centre(table.hud.find_button("Tile_" + game)))
	await DRIVER.settle(self, 3)
	_check(table.hud.overlay_kind == "setup" and table.hud.find_button("resume") != null, game + ": reopening offers to continue")
	await _press("resume", game + ": resume")
	_check(await DRIVER.idle(self, table), game + ": resumed table settles")
	_check(table.rules.snapshot() == saved, game + ": the resumed match is identical")
	_check(str(table.rules.s.result_id) == result_id, game + ": the result id survives the resume")
	var expected_cards: int = saved.r.played.size() + table.STOCK_SHOWN + saved.r.trick.size()
	for hand: Array in saved.r.hands:
		expected_cards += hand.size()
	_check(table.seats.size() == 4 and table.cards.size() == expected_cards, game + ": cards and players are rebuilt from the save")
	# Mit eingebetteter App: Meldung über die Brücke.
	var host := Host.new()
	bridge._host = host
	var stars_before: int = root.get_node("ProgressStore").total_stars()
	settled.clear()
	rewards.clear()
	var rounds_seen := 0
	await _play_until(func() -> bool: return false, game)
	rounds_seen = table.rules.s.history.size()
	_check(rounds_seen == 3 and table.rules.phase() == "match_over", game + ": three rounds are played to the end")
	var payload := _final_checks(game, result_id, stars_before)
	_check(host.rewards.size() == 1 and JSON.parse_string(host.rewards[0]).get("resultId") == result_id, game + ": the host receives one reward call")
	_check(rewards.size() == 1, game + ": the bridge reports the reward once")
	# Größe ändern und erneut öffnen: keine zweite Buchung.
	table._resize()
	await DRIVER.settle(self, 3)
	table._finish_match()
	await DRIVER.settle(self, 3)
	_check(settled.size() == 1 and host.rewards.size() == 1 and root.get_node("ProgressStore").total_stars() == stars_before + int(payload.get("stars", 0)),
		game + ": showing the standings again books nothing")
	await _close("stich finished")
	await _open()
	_check(not table.session.has_match(game) and table.session.is_booked(result_id), game + ": reopening after the end offers no finished match")
	_check(root.get_node("ProgressStore").total_stars() == stars_before + int(payload.get("stars", 0)) and host.rewards.size() == 1, game + ": reopening books nothing")
	# Zurück zur App über die Brücke.
	await _press("leave", game + ": leave")
	_check(host.returns == ["games"] and table._closed, game + ": Zurück returns to the app once")
	bridge._host = null
	bridge._return_pending = false
	await _close("stich returned")
	await _open()


func _leiter() -> void:
	var game := "leiter"
	await _intro(game)
	await _pick("players", 3, game + ": two fellow players")
	await _pick("difficulty", 0, game + ": easy")
	await _pick("rounds", 1, game + ": one round")
	await _press("start", game + ": start")
	_check(await DRIVER.idle(self, table), game + ": deal settles")
	_check(table.rules.players() == 3 and table.seats.size() == 3 and table.cards.size() == 27, game + ": three players, 27 cards")
	var first_id := str(table.rules.s.result_id)
	await _play_until(func() -> bool: return table._can_act() and not table._legal_cards.is_empty() and table._legal_cards.size() < table.rules.s.r.hands[0].size(), game)
	var refused := -1
	for card: int in table.rules.s.r.hands[0]:
		if not table._legal_cards.has(card):
			refused = card
	var before: Dictionary = table.rules.snapshot()
	await DRIVER.touch(self, DRIVER.hand_point(table, refused))
	await DRIVER.settle(self, 3)
	_check(table.rules.snapshot() == before, game + ": a card that does not fit stays in the hand")
	_check("Leiter" in table.hud.hint_label.text, game + ": the table explains the ladder: " + table.hud.hint_label.text)
	var legal: int = table._legal_cards.keys()[0]
	await DRIVER.touch(self, DRIVER.hand_point(table, legal))
	await DRIVER.settle(self, 3)
	_check(table._selected == [legal] and table.hud.action_button.visible and table.hud.action_button.text == "Legen",
		game + ": the first tap lifts the card and offers Legen")
	await _press("Action", game + ": Legen")
	await DRIVER.idle(self, table)
	_check(table.rules.s.r.laid.has(legal) and table.cards[legal].zone == "ladder", game + ": the card lies in its ladder")
	# Neu starten ersetzt die Partie durch eine neue.
	await _play_until(func() -> bool: return table._can_act(), game)
	await _press("Pause", game + ": pause")
	await _press("restart", game + ": restart")
	_check(table.hud.overlay_kind == "confirm", game + ": restarting asks first")
	await _press("restart_yes", game + ": confirm restart")
	_check(await DRIVER.idle(self, table), game + ": new deal settles")
	_check(str(table.rules.s.result_id) != first_id and table.rules.s.r.laid.size() <= 3 and table.rules.round_number() == 1,
		game + ": a restart is a new match with a new result id")
	var result_id := str(table.rules.s.result_id)
	var stars_before: int = root.get_node("ProgressStore").total_stars()
	settled.clear()
	await _play_until(func() -> bool: return false, game)
	_final_checks(game, result_id, stars_before)
	await _press("menu", game + ": back to the selection")
	_check(table.screen == "select", game + ": Anderes Spiel opens the selection")


func _quartett(bridge: Node) -> void:
	var game := "quartett"
	await _intro(game)
	await _pick("players", 2, game + ": one fellow player")
	await _pick("difficulty", 1, game + ": medium")
	await _pick("rounds", 1, game + ": one round")
	await _press("start", game + ": start")
	_check(await DRIVER.idle(self, table), game + ": deal settles")
	_check(table.rules.players() == 2 and table.seats.size() == 2 and table.cards.size() == 32, game + ": two players, 32 cards")
	await _play_until(func() -> bool: return table._can_act() and not table._legal_cards.is_empty(), game)
	var own: int = table.rules.s.r.hands[0][0]
	await DRIVER.touch(self, DRIVER.hand_point(table, own))
	await DRIVER.settle(self, 3)
	_check(table._pick_rank == DECK.rank(own), game + ": tapping a card chooses the value to ask for")
	_check(not table.hud.plates[0].disabled and "Wen fragst du" in table.hud.hint_label.text, game + ": fellow players become touch targets")
	var before: int = int(table.rules.s.moves)
	await DRIVER.touch(self, DRIVER.control_centre(table.hud.plates[0]))
	await DRIVER.idle(self, table)
	_check(int(table.rules.s.moves) > before, game + ": tapping a fellow player asks the question")
	var result_id := str(table.rules.s.result_id)
	var stars_before: int = root.get_node("ProgressStore").total_stars()
	settled.clear()
	await _play_until(func() -> bool: return false, game)
	_check(table.rules.sets_total() == table.rules.ranks_in_play().size(), game + ": every quartet is laid")
	var sets_shown := 0
	for card: int in table.cards:
		if table.cards[card].zone == "set":
			sets_shown += 1
	_check(sets_shown == 32, game + ": all quartets lie on the table")
	_final_checks(game, result_id, stars_before)
	await _press("again", game + ": play again")
	_check(await DRIVER.idle(self, table), game + ": new match settles")
	_check(table.screen == "play" and str(table.rules.s.result_id) != result_id, game + ": Nochmal starts a fresh match")
	table._on_chosen("pause", {})
	await DRIVER.settle(self, 2)
	await _press("quit", game + ": quit to selection")
	_check(table.screen == "select" and table.session.has_match(game), game + ": Beenden keeps the match for later")
	table.session.discard(game)
	_check(bridge._host == null, "the standalone table needs no host")
	await _close("final")
