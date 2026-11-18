extends Node3D
## Lumos Kartentisch: drei eigene Kartenspiele an einem 3D-Rundtisch.
##
## Diese Szene ist nur Bühne und Bedienung. Die Regeln liegen in
## scripts/games/cards/rules/, der Spielstand in cards_session.gd. Der Tisch
## zeigt, was der Regelkern meldet, und reicht Züge des Kindes dorthin weiter.
## Er braucht keine Spiel-Autorität der App: Regeln, Mitspieler und Spielstand
## laufen vollständig hier.

signal settled(payload: Dictionary)

const ROOM = preload("res://scripts/games/cards/cards_room.gd")
const SEAT = preload("res://scripts/games/cards/cards_seat.gd")
const CARD = preload("res://scripts/games/cards/cards_card.gd")
const ART = preload("res://scripts/games/cards/cards_deck_art.gd")
const HUD = preload("res://scripts/games/cards/cards_hud.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const INTRO = preload("res://scripts/games/cards/cards_intro.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")

const LUMO_ANGLE := -60.0
const OPPONENT_ANGLES := {1: [180.0], 2: [-138.0, 138.0], 3: [-122.0, 180.0, 122.0]}
const ROSTER: Array[String] = ["squirrel", "owl", "turtle", "lion", "rabbit"]
const GOLD := Color(1.0, 0.78, 0.25, 0.95)
const CYAN := Color(0.35, 0.9, 1.0, 0.95)
const OFF := Color(0, 0, 0, 0)
const HAND_DEPTH := 1.0
const STOCK_SHOWN := 7
const GAMES := {
	"stich": {
		"title": "Sternenstich",
		"text": "Bediene die Farbe und hol dir mit der höchsten Karte den Stich.",
		"skill": "Zahlen vergleichen",
		"cards": [12, 22, 37, 48],
	},
	"leiter": {
		"title": "Sternenleiter",
		"text": "Lege Zahlenreihen von der 5 aus. Wer zuerst alle Karten los ist, gewinnt.",
		"skill": "Nachbarzahlen",
		"cards": [3, 4, 5, 6],
	},
	"quartett": {
		"title": "Lumo-Quartett",
		"text": "Frag nach Karten und sammle vier gleiche Werte.",
		"skill": "Merken und fragen",
		"cards": [10, 23, 36, 49],
	},
}

var room: Node3D
var hud: Control
var camera: Camera3D
var session: RefCounted
var rules: RefCounted
var seats: Array = []
var cards: Dictionary = {}
var cards_root: Node3D
var hand_root: Node3D
var screen := ""
var game := ""
## Tempo aller Wartezeiten und Kartenflüge (Tests drehen es hoch).
var time_scale := 1.0
var reduced_motion := false
var sound_enabled := true
var last_result: Dictionary = {}

var _ui_scale := 1.0
var _android_safe_area_enabled := false
var _android_safe_area: Dictionary = {}
var _previous_window: Dictionary = {}
var _busy := false
var _paused := false
var _pumping := false
var _pump_generation := -1
var _intro_waiting_turn := false
var _generation := 0
var _selected: Array = []
var _pick_rank := 0
var _legal_cards: Dictionary = {}
var _won_owner: Dictionary = {}
var _intro_steps: Array = []
var _intro_index := -1
var _intro_blocking := false
var _setup_game := ""
var _press: Dictionary = {}
var _drag_card := -1
var _hand_metrics: Dictionary = {}
var _ghosts: Array[Node3D] = []
var _burst: CPUParticles3D
var _final_data: Dictionary = {}
var _closed := false
var _seat_ids: Array = []
var _stars_shown := 0


func _ready() -> void:
	var window := get_window()
	_previous_window = {"scale": window.content_scale_size, "quit": get_tree().quit_on_go_back,
		"orientation": DisplayServer.screen_get_orientation()}
	window.content_scale_size = Vector2i.ZERO
	get_tree().quit_on_go_back = false
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	_android_safe_area_enabled = MobileRuntime.requires_safe_area_observation()
	var options: Dictionary = HostBridge.launch_options()
	reduced_motion = bool(options.get("reduceAnimations", false))
	sound_enabled = bool(options.get("soundEnabled", true))
	session = SESSION.new(SESSION.path_for(str(options.get("childKey", ""))))
	session.load_file()
	room = ROOM.new()
	room.name = "Room"
	add_child(room)
	camera = room.camera
	cards_root = Node3D.new()
	cards_root.name = "Cards"
	add_child(cards_root)
	hand_root = Node3D.new()
	hand_root.name = "Hand"
	add_child(hand_root)
	_burst = _make_burst()
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)
	hud = HUD.new()
	hud.name = "Hud"
	layer.add_child(hud)
	hud.chosen.connect(_on_chosen)
	_seat_ids = ["squirrel", "owl", "turtle"]
	_build_seats(_seat_ids)
	get_viewport().size_changed.connect(_resize)
	MobileRuntime.safe_area_changed.connect(_resize)
	_resize()
	_open_select()
	_greet.call_deferred()


func _exit_tree() -> void:
	_closed = true
	_generation += 1
	if MobileRuntime.safe_area_changed.is_connected(_resize):
		MobileRuntime.safe_area_changed.disconnect(_resize)
	if get_viewport().size_changed.is_connected(_resize):
		get_viewport().size_changed.disconnect(_resize)
	if not _previous_window.is_empty():
		get_window().content_scale_size = _previous_window.scale
		get_tree().quit_on_go_back = _previous_window.quit
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(_previous_window.orientation)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "play" and hud.overlay_kind.is_empty():
			_pause()
		elif screen == "select":
			_leave()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		_store()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		if is_inside_tree() and not is_queued_for_deletion():
			_resize.call_deferred()


# ------------------------------------------------------------ Fläche und Blick


func _safe_area_insets() -> Rect2:
	if _android_safe_area.get("window_size") == get_window().size:
		var observed: Rect2 = _android_safe_area.insets
		var factor: Vector2 = Vector2(get_window().size) / _android_safe_area.view_size
		return Rect2(observed.position * factor, observed.size * factor)
	var insets := Rect2()
	if OS.has_feature("mobile"):
		insets = MobileRuntime.get_safe_area_insets()
	return insets


func _get_safe_area_observation() -> Dictionary:
	return MobileRuntime.get_safe_area_observation()


func _resize() -> void:
	if not is_inside_tree() or not is_instance_valid(hud) or _closed:
		return
	_android_safe_area = _get_safe_area_observation()
	_ui_scale = MobileRuntime.get_ui_density()
	var insets := _safe_area_insets()
	hud.visible = not _android_safe_area_enabled or _android_safe_area.get("window_size") == get_window().size
	hud.rebuild(_ui_scale, insets)
	_frame_camera()
	_measure_hand()
	_layout_all(0.0)
	_refresh_hud()


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _frame_camera() -> void:
	var size := view_size()
	var aspect := size.x / maxf(1.0, size.y)
	var portrait := aspect < 1.0
	var ladder := game == "leiter" and screen == "play"
	if portrait:
		room.frame(aspect, 1.42 if ladder else 1.9, 1.6, 54.0 if ladder else 40.0, 0.16 if ladder else 0.10)
	else:
		room.frame(aspect, 2.4, 1.5 if ladder else 1.95, 50.0 if ladder else 37.0, 0.26 if ladder else 0.22)
	hand_root.global_transform = camera.get_camera_transform()


## Größe und Lage der eigenen Hand am unteren Bildrand.
func _measure_hand() -> void:
	var size := view_size()
	var insets := _safe_area_insets()
	var area := size - insets.position - insets.size
	var compact := area.y / _ui_scale < 520.0 and area.x > area.y
	var card_px := clampf(area.y * (0.30 if compact else 0.19), 96.0 * _ui_scale, (150.0 if compact else 210.0) * _ui_scale)
	var half_height := HAND_DEPTH * tan(deg_to_rad(camera.fov * 0.5))
	var unit := 2.0 * half_height / size.y
	_hand_metrics = {
		"card_px": card_px,
		"unit": unit,
		"scale": card_px * unit / ART.HEIGHT,
		"centre_x": (insets.position.x + area.x * 0.5 - size.x * 0.5) * unit,
		"base_y": -half_height + (insets.size.y + 8.0 * _ui_scale + card_px * 0.56) * unit,
		"avail_px": area.x - 20.0 * _ui_scale,
		"zone_px": card_px * 1.24 + 12.0 * _ui_scale + insets.size.y,
	}
	hud.hand_height = card_px * 1.24 + 12.0 * _ui_scale


func _process(delta: float) -> void:
	if _closed:
		return
	hand_root.global_transform = camera.get_camera_transform()
	for seat: Node3D in seats:
		if is_instance_valid(seat):
			seat.advance(delta)
	_place_plates()


func _place_plates() -> void:
	if not is_instance_valid(hud) or hud.plates.is_empty():
		return
	for player in range(1, seats.size()):
		if player - 1 < hud.plates.size() and is_instance_valid(seats[player]):
			hud.place_plate(player, camera.unproject_position(seats[player].head_top()) + Vector2(0, -6.0 * _ui_scale))


# --------------------------------------------------------------------- Figuren


func _build_seats(opponents: Array) -> void:
	for seat: Node3D in seats:
		if is_instance_valid(seat):
			seat.queue_free()
	seats.clear()
	room.clear_stools()
	var lumo: Node3D = SEAT.new()
	lumo.name = "SeatLumo"
	add_child(lumo)
	lumo.setup("lumo", ROOM.seat_transform(LUMO_ANGLE, ROOM.SEAT_RADIUS + 0.2), 0)
	lumo.set_reduced_motion(reduced_motion)
	room.add_stool(LUMO_ANGLE, lumo.tint, ROOM.SEAT_RADIUS + 0.2)
	seats.append(lumo)
	var angles: Array = OPPONENT_ANGLES[clampi(opponents.size(), 1, 3)]
	for index in range(mini(opponents.size(), 3)):
		var seat: Node3D = SEAT.new()
		seat.name = "Seat%d" % (index + 1)
		add_child(seat)
		seat.setup(str(opponents[index]), ROOM.seat_transform(angles[index]), index + 1)
		seat.set_reduced_motion(reduced_motion)
		room.add_stool(angles[index], seat.tint)
		seats.append(seat)
	_seat_ids = opponents.duplicate()


func _greet() -> void:
	if seats.is_empty() or _closed:
		return
	seats[0].look_at_point(camera.global_position)
	seats[0].react("wave")
	for player in range(1, seats.size()):
		seats[player].look_at_point(Vector3(0, ROOM.TABLE_Y, 0))


## Richtung von der Tischmitte zum Platz eines Spielers (0 = Kind, vorn).
func _dir(player: int) -> Vector3:
	if player <= 0 or player >= seats.size():
		return Vector3(0, 0, 1)
	var at: Vector3 = seats[player].position
	return Vector3(at.x, 0, at.z).normalized()


func _pick_opponents(count: int, seed_value: int) -> Array:
	var order: Array = DECK.shuffled(range(ROSTER.size()), DECK.rng_seed(seed_value + 5))[0]
	var chosen: Array = []
	for index in range(count):
		chosen.append(ROSTER[int(order[index])])
	return chosen


# ---------------------------------------------------------------- Bildschirme


func _open_select() -> void:
	_generation += 1
	screen = "select"
	game = ""
	rules = null
	_intro_steps = []
	_intro_index = -1
	_paused = false
	_busy = false
	_clear_cards()
	_clear_selection()
	hud.hide_bubble()
	hud.set_hint("")
	hud.set_action("")
	hud.set_trump(-1)
	hud.set_plates([])
	_frame_camera()
	var games: Array = []
	for id: String in SESSION.GAMES:
		var info: Dictionary = GAMES[id]
		var resume := ""
		var summary: Dictionary = session.match_summary(id)
		if not summary.is_empty():
			resume = "Weiterspielen · Runde %d von %d" % [summary.round, summary.rounds_total]
		games.append({"id": id, "title": info.title, "text": info.text, "skill": info.skill,
			"cards": info.cards, "resume": resume})
	_stars_shown = ProgressStore.total_stars()
	hud.show_select({"games": games, "stars": _stars_shown})
	for seat: Node3D in seats:
		seat.set_suspended(false)
		seat.react("idle")


func _open_setup(id: String) -> void:
	_setup_game = id
	var info: Dictionary = GAMES[id]
	var prefs: Dictionary = session.prefs()
	var resume := ""
	var summary: Dictionary = session.match_summary(id)
	if not summary.is_empty():
		resume = "Weiterspielen · Runde %d von %d" % [summary.round, summary.rounds_total]
	hud.show_setup({"game": id, "title": info.title, "text": info.text, "players": prefs.players,
		"difficulty": prefs.difficulty, "rounds": prefs.rounds, "resume": resume})


func _on_chosen(id: String, payload: Dictionary) -> void:
	if _closed:
		return
	if id not in ["action", "seat"]:
		_sfx("ui_confirm")
	match id:
		"game":
			var picked := str(payload.game)
			if not session.intro_seen(picked) and not session.has_match(picked):
				_setup_game = picked
				_start_intro(picked)
			else:
				_open_setup(picked)
		"pref":
			var prefs: Dictionary = session.prefs()
			prefs[str(payload.key)] = int(payload.value)
			session.set_prefs(int(prefs.players), int(prefs.difficulty), int(prefs.rounds))
			_open_setup(_setup_game)
		"start":
			_start_match(str(payload.game), false)
		"resume":
			_start_match(str(payload.game), true)
		"intro":
			_start_intro(str(payload.game))
		"back", "menu":
			_open_select()
		"leave":
			_leave()
		"pause":
			_pause()
		"continue":
			_resume()
		"rules":
			hud.show_rules({"title": rules.title(), "lines": rules.rules_text(), "back": "rules_done"})
		"rules_done":
			hud.show_pause({"text": _pause_text()})
		"restart":
			hud.show_confirm({"title": "Neu starten?", "text": "Die laufende Partie wird durch eine neue ersetzt.",
				"yes": "restart_yes", "no": "rules_done", "yes_text": "Ja, neu starten", "no_text": "Lieber weiterspielen"})
		"restart_yes":
			var again := game
			var was_intro := not _intro_steps.is_empty()
			hud.close_overlay()
			if was_intro:
				_start_intro(again)
			else:
				session.discard(again)
				_start_match(again, false)
		"quit":
			hud.close_overlay()
			_store()
			_open_select()
		"next_round":
			_next_round()
		"again":
			_start_match(game, false)
		"action":
			_on_action()
		"seat":
			_on_seat(int(payload.player))
		"intro_next":
			_intro_advance()
		"intro_skip":
			_intro_finish()


func _pause_text() -> String:
	if not _intro_steps.is_empty():
		return "Die Einführung wartet auf dich."
	return "Deine Partie ist gespeichert. Du kannst jederzeit weiterspielen."


func _pause() -> void:
	if screen != "play" or rules == null or not hud.overlay_kind.is_empty():
		return
	_paused = true
	_cancel_drag()
	for seat: Node3D in seats:
		seat.set_suspended(true)
	_store()
	hud.show_pause({"text": _pause_text()})


func _resume() -> void:
	_paused = false
	hud.close_overlay()
	for seat: Node3D in seats:
		seat.set_suspended(false)
	_refresh_hud()
	_pump()


func _leave() -> void:
	if _closed:
		return
	_store()
	if HostBridge.is_embedded():
		_closed = HostBridge.return_to_app("games")
	else:
		SceneRouter.goto("games")


func _store() -> void:
	if rules != null and _intro_steps.is_empty() and screen == "play" and rules.phase() != "match_over":
		session.store(rules)


# ------------------------------------------------------------------- Partie


func _start_match(id: String, resume: bool) -> void:
	_generation += 1
	hud.close_overlay()
	hud.hide_bubble()
	_intro_steps = []
	_intro_index = -1
	_intro_blocking = false
	game = id
	screen = "play"
	_paused = false
	_busy = false
	_won_owner.clear()
	_final_data.clear()
	var fresh := true
	rules = session.resume(id) if resume else null
	if rules != null:
		fresh = false
	else:
		var prefs: Dictionary = session.prefs()
		var seed_value := int(Time.get_ticks_usec() & 0x3FFFFFFF) ^ int(Time.get_unix_time_from_system())
		rules = session.new_match(id, {
			"players": int(prefs.players),
			"rounds": int(prefs.rounds),
			"difficulty": int(prefs.difficulty),
			"seed": seed_value & 0x3FFFFFFF,
			"result_id": "cards-%s-%s" % [id, HostBridge.new_result_id()],
			"seats": _pick_opponents(int(prefs.players) - 1, seed_value),
		})
	_enter_table(fresh)


func _enter_table(deal: bool) -> void:
	var wanted: Array = rules.s.seats
	if wanted.size() != rules.players() - 1:
		wanted = _pick_opponents(rules.players() - 1, int(rules.s.seed))
	if wanted != _seat_ids or seats.size() != rules.players():
		_build_seats(wanted)
	for seat: Node3D in seats:
		seat.set_suspended(false)
		seat.react("idle")
		seat.look_at_point(Vector3(0, ROOM.TABLE_Y, 0))
	hud.show_top(true)
	_frame_camera()
	_measure_hand()
	_spawn_round(deal)
	_refresh_hud()
	if rules.phase() == "round_over":
		_show_round()
	elif rules.phase() == "match_over":
		_finish_match()
	else:
		_after_deal(deal)


func _after_deal(deal: bool) -> void:
	var generation := _generation
	if deal:
		_busy = true
		_announce_round()
		await _wait(0.9 + 0.045 * cards.size())
		if generation != _generation:
			return
		_busy = false
	_pump()


func _announce_round() -> void:
	var text := "Runde %d von %d" % [rules.round_number(), rules.rounds_total()]
	if game == "stich":
		text += " · Trumpf ist %s" % DECK.SUIT_NAMES[int(rules.s.r.trump)]
	hud.set_hint(text)


func _next_round() -> void:
	if rules == null or rules.phase() != "round_over":
		return
	hud.close_overlay()
	rules.next_round()
	_won_owner.clear()
	_store()
	_spawn_round(true)
	_refresh_hud()
	_after_deal(true)


## Der Zugtakt: lässt Mitspieler ziehen, bis das Kind dran ist oder die Runde endet.
func _pump() -> void:
	if (_pumping and _pump_generation == _generation) or rules == null or screen != "play":
		return
	_pumping = true
	_pump_generation = _generation
	var generation := _generation
	while generation == _generation and rules != null and not _paused and not _intro_blocking:
		if rules.phase() == "round_over":
			if _intro_steps.is_empty():
				_show_round()
			else:
				_intro_finish()
			break
		if rules.phase() == "match_over":
			if _intro_steps.is_empty():
				_finish_match()
			else:
				_intro_finish()
			break
		var player: int = rules.current()
		if player == 0:
			_begin_human_turn()
			break
		await _ai_turn(player)
	if generation == _generation:
		_pumping = false


func _ai_turn(player: int) -> void:
	var generation := _generation
	var seat: Node3D = seats[player]
	_legal_cards.clear()
	_refresh_hud()
	hud.set_hint("%s ist dran." % seat.display_name)
	hud.set_action("")
	seat.react("think")
	for other: Node3D in seats:
		other.look_at_point(seat.chest())
	await _wait(0.55 + 0.25 * float((int(rules.s.moves) * 7 + player * 3) % 4))
	if generation != _generation or _paused:
		seat.calm()
		return
	var move: Dictionary = SESSION.ai_move(rules, player)
	seat.calm()
	var result: Dictionary = rules.play(player, move)
	_store()
	await _play_events(result.events)


func _begin_human_turn() -> void:
	_legal_cards.clear()
	for move: Dictionary in rules.legal_moves(0):
		if move.has("card"):
			_legal_cards[int(move.card)] = true
		elif move.has("ask"):
			for card: int in rules.s.r.hands[0]:
				if DECK.rank(card) == int(move.ask):
					_legal_cards[card] = true
	_clear_selection()
	for seat: Node3D in seats:
		seat.look_home()
	seats[0].look_at_point(Vector3(0, ROOM.TABLE_Y, 0.2))
	_sfx("turn_ping")
	_refresh_hud()
	_layout_hand(0.16)
	_intro_on_turn()


func _turn_hint() -> String:
	if rules == null or rules.phase() != "playing" or rules.current() != 0:
		return ""
	match game:
		"stich":
			if rules.s.r.trick.is_empty():
				return "Du spielst aus. Tippe eine Karte an."
			var lead: int = rules.lead_suit()
			if _legal_cards.size() < rules.s.r.hands[0].size():
				return "Bediene %s! Tippe eine leuchtende Karte." % DECK.SUIT_NAMES[lead]
			return "Du hast kein %s. Lege eine beliebige Karte – Trumpf sticht." % DECK.SUIT_NAMES[lead]
		"leiter":
			if _legal_cards.is_empty():
				return "Keine Karte passt. Tippe auf Aussetzen."
			return "Du bist dran. Lege eine leuchtende Karte an ihre Leiter."
		"quartett":
			if _pick_rank > 0:
				return "Wen fragst du nach %s? Tippe einen Mitspieler an." % _rank_words(_pick_rank)
			if _legal_cards.is_empty():
				return "Du hast keine Karten. Tippe auf Karte ziehen."
			return "Du bist dran. Tippe eine Karte an, nach der du fragen willst."
	return ""


func _rank_words(value: int) -> String:
	if DECK.FACE_NAMES.has(value):
		return "der %s-Karte" % DECK.FACE_NAMES[value]
	return "der %d" % value


func _can_act() -> bool:
	return (screen == "play" and rules != null and not _busy and not _paused and not _intro_blocking
		and rules.phase() == "playing" and rules.current() == 0 and hud.overlay_kind.is_empty())


func _clear_selection() -> void:
	_selected.clear()
	_pick_rank = 0


func _human_play(move: Dictionary) -> void:
	if not _can_act():
		return
	var result: Dictionary = rules.play(0, move)
	if not result.ok:
		hud.set_hint(str(result.error))
		_sfx("card_refuse")
		return
	_busy = true
	_clear_selection()
	_legal_cards.clear()
	hud.set_action("")
	_store()
	var generation := _generation
	await _play_events(result.events)
	if generation != _generation:
		return
	_busy = false
	_intro_after_play()
	_pump()


func _on_action() -> void:
	if not _can_act():
		return
	var legal: Array = rules.legal_moves(0)
	if legal.size() == 1 and (legal[0].has("pass") or legal[0].has("draw")):
		_human_play(legal[0])
	elif _selected.size() == 1 and game != "quartett":
		_human_play({"card": int(_selected[0])})


func _on_seat(player: int) -> void:
	if not _can_act() or game != "quartett" or _pick_rank <= 0:
		return
	var move := {"ask": _pick_rank, "from": player}
	if rules.is_legal(0, move):
		_human_play(move)
	else:
		hud.set_hint(rules.explain(0, move))
		_sfx("card_refuse")


func _tap_card(card: int) -> void:
	if not cards.has(card):
		return
	if not _can_act():
		if rules != null and rules.phase() == "playing" and rules.current() != 0 and not _busy:
			hud.set_hint("Du bist noch nicht dran.")
		return
	if game == "quartett":
		_pick_rank = DECK.rank(card)
		_selected.clear()
		for own: int in rules.s.r.hands[0]:
			if DECK.rank(own) == _pick_rank:
				_selected.append(own)
		_sfx("card_select")
		_refresh_hud()
		_layout_hand(0.14)
		_intro_on_select()
		return
	if not _legal_cards.has(card):
		cards[card].refuse()
		hud.set_hint(rules.explain(0, {"card": card}))
		_sfx("card_refuse")
		return
	if _selected == [card]:
		_human_play({"card": card})
		return
	_selected = [card]
	_sfx("card_select")
	_refresh_hud()
	_layout_hand(0.14)


# ------------------------------------------------------------------ Eingabe


func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		point = event.position
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and not _press.is_empty():
		point = event.position
		moved = true
	else:
		return
	if screen != "play" or rules == null or not hud.overlay_kind.is_empty():
		return
	if pressed:
		var card := _hand_card_at(point)
		if card >= 0:
			_press = {"card": card, "start": point, "dragging": false}
			get_viewport().set_input_as_handled()
		elif game == "quartett" and _pick_rank > 0:
			var seat := _seat_at(point)
			if seat > 0:
				_on_seat(seat)
				get_viewport().set_input_as_handled()
	elif moved and not _press.is_empty():
		var distance: float = point.distance_to(_press.start)
		if not bool(_press.dragging) and distance > 16.0 * _ui_scale and _can_act() and game != "quartett":
			_press.dragging = true
			_drag_card = int(_press.card)
		if bool(_press.dragging):
			_drag_to(point)
	elif released and not _press.is_empty():
		var card := int(_press.card)
		var dragging := bool(_press.dragging)
		_press.clear()
		_drag_card = -1
		if dragging:
			var above_hand := point.y < view_size().y - float(_hand_metrics.zone_px)
			if above_hand and _legal_cards.has(card) and _can_act():
				_human_play({"card": card})
			else:
				if above_hand and _can_act():
					hud.set_hint(rules.explain(0, {"card": card}))
					_sfx("card_refuse")
				_layout_hand(0.18)
		else:
			_tap_card(card)
		get_viewport().set_input_as_handled()


func _cancel_drag() -> void:
	_press.clear()
	if _drag_card >= 0:
		_drag_card = -1
		_layout_hand(0.12)


func _hand_card_at(point: Vector2) -> int:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var best := -1
	var nearest := INF
	for id: int in cards:
		var node: Node3D = cards[id]
		if node.zone != "hand":
			continue
		var distance: float = node.ray_hit(origin, direction, 0.004)
		if distance > 0.0 and distance < nearest:
			nearest = distance
			best = id
	return best


func _seat_at(point: Vector2) -> int:
	var best := -1
	var nearest := 84.0 * _ui_scale
	for player in range(1, seats.size()):
		var at := camera.unproject_position(seats[player].chest() + Vector3(0, 0.3, 0))
		var distance := at.distance_to(point)
		if distance < nearest:
			nearest = distance
			best = player
	return best


func _drag_to(point: Vector2) -> void:
	if _drag_card < 0 or not cards.has(_drag_card):
		return
	var node: Node3D = cards[_drag_card]
	var size := view_size()
	var unit: float = _hand_metrics.unit
	var local := Vector3((point.x - size.x * 0.5) * unit, (size.y * 0.5 - point.y) * unit + float(_hand_metrics.card_px) * unit * 0.2, -HAND_DEPTH + 0.08)
	var target := _hand_basis(0.0, float(_hand_metrics.scale) * 1.12)
	node.stop()
	node.transform = Transform3D(target, local)
	node.set_look("hand")
	node.set_glow(GOLD if _legal_cards.has(_drag_card) else OFF)


# -------------------------------------------------------------------- Karten


func _clear_cards() -> void:
	for id: int in cards:
		if is_instance_valid(cards[id]):
			cards[id].queue_free()
	cards.clear()
	for ghost: Node3D in _ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghosts.clear()


func _cards_in_play() -> Array:
	var all: Array = []
	var r: Dictionary = rules.s.r
	for hand: Array in r.hands:
		all.append_array(hand)
	match game:
		"stich":
			# Der Reststapel bleibt die Runde über liegen: Trumpfkarte und ein paar Deckkarten genügen.
			all.append_array(r.stock.slice(0, STOCK_SHOWN))
			all.append_array(r.played)
			for entry: Dictionary in r.trick:
				all.append(int(entry.c))
		"leiter":
			all.append_array(r.laid)
		"quartett":
			all.append_array(r.stock)
			for own: Array in r.sets:
				for value: int in own:
					for suit in range(DECK.SUIT_COUNT):
						all.append(DECK.card(suit, value))
	return all


## Legt für die Runde alle Karten an. `deal`: vom Stapel im Bogen austeilen.
func _spawn_round(deal: bool) -> void:
	_clear_cards()
	_clear_selection()
	_legal_cards.clear()
	var all := _cards_in_play()
	var start := _stock_centre()
	for index in range(all.size()):
		var node: Node3D = CARD.new()
		cards_root.add_child(node)
		node.setup(int(all[index]))
		node.transform = _flat(start + Vector3(0, 0.004 * index, 0), 0.0, false, 1.0)
		cards[int(all[index])] = node
	if game == "leiter":
		_build_ladder_marks()
	_assign_from_state()
	if not deal or reduced_motion:
		_layout_all(0.0)
		return
	# Reihum austeilen: jede Karte startet etwas später.
	var order := 0
	var hand_size := 0
	for hand: Array in rules.s.r.hands:
		hand_size = maxi(hand_size, hand.size())
	var delays: Dictionary = {}
	for index in range(hand_size):
		for player in range(rules.players()):
			var seat: int = (int(rules.s.r.turn) + player) % rules.players()
			var hand: Array = rules.s.r.hands[seat]
			if index < hand.size():
				delays[int(hand[index])] = 0.25 + 0.045 * order
				order += 1
	_layout_all(0.42, delays, 0.32)
	_deal_ticks(order)


func _deal_ticks(count: int) -> void:
	var generation := _generation
	for index in range(mini(count, 40)):
		if index % 2 == 0:
			_sfx("card_deal")
		await _wait(0.045)
		if generation != _generation:
			return


func _stock_centre() -> Vector3:
	if game == "stich":
		return Vector3(-0.56, ROOM.TABLE_Y + 0.008, -0.1)
	return Vector3(0.0, ROOM.TABLE_Y + 0.008, -0.02)


## Ordnet jede Karte ihrem Ort im Spielstand zu.
func _assign_from_state() -> void:
	var r: Dictionary = rules.s.r
	for player in range(rules.players()):
		var hand: Array = r.hands[player]
		for index in range(hand.size()):
			_place(int(hand[index]), "hand" if player == 0 else "fan", player, index)
	match game:
		"stich":
			for index in range(r.stock.size()):
				_place(int(r.stock[index]), "trump" if index == 0 else "stock", -1, r.stock.size() - index)
			for index in range(r.trick.size()):
				_place(int(r.trick[index].c), "trick", int(r.trick[index].p), index)
			# Gewonnene Stiche: bekannte Besitzer behalten, Rest nach Stichzahl verteilen.
			var open: Array = []
			var have: Array = []
			for player in range(rules.players()):
				have.append(0)
			for card: int in r.played:
				if _won_owner.has(card):
					have[int(_won_owner[card])] += 1
				else:
					open.append(card)
			for player in range(rules.players()):
				while have[player] < int(r.tricks[player]) * rules.players() and not open.is_empty():
					_won_owner[int(open.pop_front())] = player
					have[player] += 1
			var stack: Array = []
			for player in range(rules.players()):
				stack.append(0)
			for card: int in r.played:
				var owner := int(_won_owner.get(card, 0))
				_place(card, "won", owner, stack[owner])
				stack[owner] += 1
		"leiter":
			for card: int in r.laid:
				_place(card, "ladder", -1, 0)
		"quartett":
			for index in range(r.stock.size()):
				_place(int(r.stock[index]), "stock", -1, r.stock.size() - index)
			for player in range(rules.players()):
				var own: Array = r.sets[player]
				for k in range(own.size()):
					for suit in range(DECK.SUIT_COUNT):
						_place(DECK.card(suit, int(own[k])), "set", player, k * 4 + suit)


func _place(card: int, zone: String, owner: int, order: int) -> void:
	if not cards.has(card):
		return
	var node: Node3D = cards[card]
	node.zone = zone
	node.owner_seat = owner
	node.order = order


static func _flat(at: Vector3, yaw: float, face_up: bool, scale: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw)
	if not face_up:
		basis = basis * Basis(Vector3.BACK, PI)
	return Transform3D(basis.scaled(Vector3.ONE * scale), at)


func _jitter(card: int, amount: float) -> float:
	return (float((card * 37 + 11) % 17) / 16.0 - 0.5) * amount


func _hand_basis(roll: float, scale: float) -> Basis:
	# Karte steht vor der Kamera: Bild zur Kamera, Oberkante nach oben, leicht gekippt.
	var facing := Basis(Vector3.RIGHT, Vector3(0, 0, 1), Vector3(0, -1, 0))
	return (Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, deg_to_rad(-9.0)) * facing).scaled(Vector3.ONE * scale)


func _hand_order() -> Array:
	var own: Array = []
	for id: int in cards:
		if cards[id].zone == "hand":
			own.append(id)
	if game == "quartett":
		own.sort_custom(func(a: int, b: int) -> bool:
			return DECK.rank(a) * 4 + DECK.suit(a) < DECK.rank(b) * 4 + DECK.suit(b))
	else:
		own.sort()
	return own


## Zielort einer Karte laut ihrer Zuordnung (Weltkoordinaten, außer Hand).
func _slot(node: Node3D, index: int, count: int) -> Transform3D:
	var y := ROOM.TABLE_Y + 0.006
	var card: int = node.card_id
	match node.zone:
		"hand":
			var m := _hand_metrics
			var card_w: float = float(m.card_px) * 0.711
			var spacing: float = minf(card_w * 0.74, (float(m.avail_px) - card_w) / maxf(1.0, count - 1.0))
			var offset := float(index) - float(count - 1) * 0.5
			var unit: float = m.unit
			var roll := -offset * minf(deg_to_rad(3.2), deg_to_rad(26.0) / maxf(1.0, count))
			var lift := 0.0
			if _selected.has(card):
				lift = float(m.card_px) * 0.20
			elif _legal_cards.has(card) and _can_act():
				lift = float(m.card_px) * 0.05
			var drop := absf(offset) * absf(offset) * float(m.card_px) * 0.004
			var at := Vector3(float(m.centre_x) + offset * spacing * unit, float(m.base_y) + (lift - drop) * unit, -HAND_DEPTH + 0.002 * index)
			return Transform3D(_hand_basis(roll, float(m.scale) * (1.06 if _selected.has(card) else 1.0)), at)
		"fan":
			var seat: Node3D = seats[node.owner_seat]
			var fan: Transform3D = seat.fan_transform()
			var step := minf(deg_to_rad(11.0), deg_to_rad(78.0) / maxf(1.0, count - 1.0))
			var angle := -(float(index) - float(count - 1) * 0.5) * step
			var scale := 0.5
			var local := Transform3D(Basis(Vector3.UP, angle), Vector3(0, 0.0035 * index, 0.1)) * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3(0, 0, -ART.HEIGHT * scale * 0.62))
			return fan * local
		"stock":
			return _flat(_stock_centre() + Vector3(0, 0.0045 * index, 0), _jitter(card, 0.07), false, 1.0)
		"trump":
			return _flat(_stock_centre() + Vector3(0.2, -0.002, 0.0), PI * 0.5 + _jitter(card, 0.04), true, 1.0)
		"trick":
			var toward := _dir(node.owner_seat)
			return _flat(Vector3(0.16, y + 0.005 * node.order, 0.02) + toward * 0.32, _jitter(card, 0.3), true, 1.3)
		"won":
			var toward := _dir(node.owner_seat)
			var tangent := Vector3(toward.z, 0, -toward.x)
			var base := toward * 0.86 + tangent * 0.36
			if node.owner_seat == 0:
				base = Vector3(0.82, 0, 0.5)
			@warning_ignore("integer_division")
			var packet: int = node.order / maxi(1, rules.players())
			return _flat(base + Vector3(0.022 * packet, y + 0.0045 * node.order, 0.016 * packet), _jitter(card, 0.25) + atan2(toward.x, toward.z), false, 0.56)
		"ladder":
			var suits: Array = rules.s.r.suits
			var column := suits.find(DECK.suit(card))
			var x := (float(column) - float(suits.size() - 1) * 0.5) * 0.335
			var value := DECK.rank(card)
			return _flat(Vector3(x, y + 0.0045 * (10 - value), 0.07 - float(value - 5) * 0.122), 0.0, true, 1.08)
		"set":
			var toward := _dir(node.owner_seat)
			var tangent := Vector3(toward.z, 0, -toward.x)
			@warning_ignore("integer_division")
			var set_index: int = node.order / 4
			var within: int = node.order % 4
			var total: int = rules.s.r.sets[node.owner_seat].size()
			@warning_ignore("integer_division")
			var row: int = set_index / 5
			var per_row := mini(5, total - row * 5)
			var along := (float(set_index % 5) - float(per_row - 1) * 0.5) * 0.2
			var base := toward * ((0.62 if node.owner_seat == 0 else 0.8) - 0.19 * row) + tangent * along
			return _flat(base + tangent * (float(within) - 1.5) * 0.032 + Vector3(0, y + 0.004 * within, 0), atan2(toward.x, toward.z) * 0.0 + (float(within) - 1.5) * 0.06, true, 0.5)
	return node.transform


## Bringt alle Karten an ihren Ort. `delays`: Startverzögerung je Karte.
func _layout_all(duration: float, delays: Dictionary = {}, arc: float = 0.0) -> void:
	if rules == null or cards.is_empty():
		return
	var groups: Dictionary = {}
	for id: int in cards:
		var node: Node3D = cards[id]
		var key := "%s/%d" % [node.zone, node.owner_seat]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(id)
	for key: String in groups:
		var ids: Array = groups[key]
		if key.begins_with("hand"):
			ids = _hand_order()
		else:
			ids.sort_custom(func(a: int, b: int) -> bool:
				if cards[a].order != cards[b].order:
					return cards[a].order < cards[b].order
				return a < b)
		for index in range(ids.size()):
			var id := int(ids[index])
			if id == _drag_card:
				continue
			_send(cards[id], index, ids.size(), duration, float(delays.get(id, 0.0)), arc)


func _layout_hand(duration: float) -> void:
	var ids := _hand_order()
	for index in range(ids.size()):
		if int(ids[index]) != _drag_card:
			_send(cards[int(ids[index])], index, ids.size(), duration, 0.0, 0.0)


func _layout_zone(zone: String, owner: int, duration: float) -> void:
	var ids: Array = []
	for id: int in cards:
		if cards[id].zone == zone and cards[id].owner_seat == owner:
			ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		if cards[a].order != cards[b].order:
			return cards[a].order < cards[b].order
		return a < b)
	for index in range(ids.size()):
		_send(cards[int(ids[index])], index, ids.size(), duration, 0.0, 0.0)


func _send(node: Node3D, index: int, count: int, duration: float, delay: float, arc: float) -> void:
	var in_hand: bool = node.zone == "hand"
	var parent: Node3D = hand_root if in_hand else cards_root
	if node.get_parent() != parent:
		var world: Transform3D = node.global_transform
		node.get_parent().remove_child(node)
		parent.add_child(node)
		node.global_transform = world
	var target := _slot(node, index, count)
	if in_hand:
		var mine := _can_act()
		var legal := _legal_cards.has(node.card_id)
		node.set_look("dim" if mine and not legal and game != "quartett" else "hand")
		if _selected.has(node.card_id):
			node.set_glow(CYAN)
		elif mine and legal:
			node.set_glow(GOLD)
		else:
			node.set_glow(OFF)
	else:
		node.set_look("table")
		node.set_glow(OFF)
	var quick := duration / maxf(0.01, time_scale)
	if reduced_motion or duration <= 0.0:
		node.snap_to(target)
	elif not node.transform.is_equal_approx(target):
		node.fly_to(target, quick, delay / maxf(0.01, time_scale), arc)


func _build_ladder_marks() -> void:
	# Schwache Farbzeichen zeigen, wo jede Leiter mit ihrer 5 beginnt.
	var keys := ["stern", "mond", "blatt", "welle"]
	var suits: Array = rules.s.r.suits
	for column in range(suits.size()):
		var mark := Sprite3D.new()
		mark.texture = load("res://assets/cards_table/ui/suit_%s.webp" % keys[int(suits[column])])
		mark.axis = Vector3.AXIS_Y
		mark.pixel_size = 0.0019
		mark.modulate = Color(1, 1, 1, 0.34)
		mark.shaded = false
		mark.position = Vector3((float(column) - float(suits.size() - 1) * 0.5) * 0.335, ROOM.TABLE_Y + 0.004, 0.07)
		cards_root.add_child(mark)
		_ghosts.append(mark)


# ------------------------------------------------------- Ereignisse abspielen


func _wait(seconds: float) -> void:
	if reduced_motion:
		seconds *= 0.25
	var timer := create_tween()
	timer.tween_interval(maxf(0.001, seconds / maxf(0.01, time_scale)))
	await timer.finished


func _sfx(sound: String) -> void:
	if sound_enabled:
		AudioManager.play_sfx(sound)


func _name_of(player: int) -> String:
	if player == 0:
		return "Du"
	return seats[player].display_name if player < seats.size() else "Mitspieler"


func _play_events(events: Array) -> void:
	var generation := _generation
	for event: Dictionary in events:
		if generation != _generation:
			return
		match str(event.t):
			"play":
				await _show_play(event)
			"trick":
				await _show_trick(event)
			"lay":
				await _show_lay(event)
			"pass":
				await _show_pass(event)
			"ask":
				await _show_ask(event)
			"give":
				await _show_give(event)
			"miss":
				await _show_miss(event)
			"draw", "refill":
				await _show_draw(event)
			"set":
				await _show_set(event)
			"skip":
				pass
			"round_over":
				await _wait(0.5)
	if generation != _generation:
		return
	_assign_from_state()
	_layout_all(0.22)
	_refresh_hud()


func _react(player: int, mood: String) -> void:
	if player >= 0 and player < seats.size():
		seats[player].react(mood)


func _show_play(event: Dictionary) -> void:
	var player := int(event.p)
	var card := int(event.card)
	_place(card, "trick", player, rules.s.r.trick.size() if not rules.s.r.trick.is_empty() else rules.players())
	if player == 0:
		seats[0].react("nod")
	else:
		_react(player, "play")
	_sfx("card_play")
	_send(cards[card], 0, 1, 0.42, 0.0, 0.3)
	_layout_zone("hand" if player == 0 else "fan", player, 0.2)
	for seat: Node3D in seats:
		seat.look_at_point(Vector3(0.1, ROOM.TABLE_Y, 0))
	_refresh_hud()
	await _wait(0.5)


func _show_trick(event: Dictionary) -> void:
	var winner := int(event.winner)
	var trick_cards: Array = event.cards
	await _wait(0.45)
	hud.set_hint("%s den Stich!" % ("Du gewinnst" if winner == 0 else seats[winner].display_name + " gewinnt"))
	var best := -1
	var lead := DECK.suit(int(trick_cards[0]))
	for card: int in trick_cards:
		var power: int = rules.strength(card, lead, int(rules.s.r.trump))
		if best < 0 or power > rules.strength(best, lead, int(rules.s.r.trump)):
			best = card
	if cards.has(best):
		cards[best].set_glow(GOLD)
	_sfx("trick_win")
	_burst_at(Vector3(0.14, ROOM.TABLE_Y + 0.1, 0))
	if winner == 0:
		seats[0].react("happy")
	else:
		_react(winner, "happy")
		# Wer knapp verloren hat, ärgert sich kurz – freundlich, ohne Häme.
		var sore: int = (winner + 1 + int(rules.s.r.trick_no)) % rules.players()
		if sore != winner and sore != 0:
			_react(sore, "grumpy")
	await _wait(0.75)
	var base := 0
	for id: int in cards:
		if cards[id].zone == "won" and cards[id].owner_seat == winner:
			base += 1
	for index in range(trick_cards.size()):
		var card := int(trick_cards[index])
		_won_owner[card] = winner
		_place(card, "won", winner, base + index)
		cards[card].set_glow(OFF)
		_send(cards[card], 0, 1, 0.5, 0.05 * index, 0.22)
	_refresh_hud()
	await _wait(0.65)


func _show_lay(event: Dictionary) -> void:
	var player := int(event.p)
	var card := int(event.card)
	_place(card, "ladder", -1, 0)
	_react(player, "play" if player > 0 else "nod")
	_sfx("card_play")
	_send(cards[card], 0, 1, 0.46, 0.0, 0.3)
	_layout_zone("hand" if player == 0 else "fan", player, 0.2)
	if player > 0:
		hud.set_hint("%s legt %s." % [seats[player].display_name, DECK.label(card)])
	_refresh_hud()
	await _wait(0.6)
	if int(event.left) == 0:
		_react(player, "happy")
		_burst_at(cards[card].global_position + Vector3(0, 0.1, 0))


func _show_pass(event: Dictionary) -> void:
	var player := int(event.p)
	hud.set_hint("%s aus." % ("Du setzt" if player == 0 else seats[player].display_name + " setzt"))
	_react(player, "grumpy" if player > 0 else "idle")
	_sfx("card_pass")
	await _wait(0.75)


func _show_ask(event: Dictionary) -> void:
	var player := int(event.p)
	var target := int(event.from)
	var words := _rank_words(int(event.rank))
	if player == 0:
		hud.set_hint("Du fragst %s nach %s." % [seats[target].display_name, words])
		seats[0].react("point")
	else:
		var whom: String = "dich" if target == 0 else seats[target].display_name
		hud.set_hint("%s fragt %s nach %s." % [seats[player].display_name, whom, words])
		seats[player].emote("ask", 1.2)
		seats[player].look_at_point(camera.global_position if target == 0 else seats[target].chest())
	if target > 0:
		seats[target].look_at_point(seats[player].chest() if player > 0 else camera.global_position)
	_sfx("card_select")
	await _wait(0.95)


func _show_give(event: Dictionary) -> void:
	var player := int(event.p)
	var target := int(event.from)
	var given: Array = event.cards
	var count := given.size()
	var text := "%d Karte%s" % [count, "" if count == 1 else "n"]
	if player == 0:
		hud.set_hint("Treffer! Du bekommst %s und darfst noch einmal." % text)
	elif target == 0:
		hud.set_hint("%s bekommt %s von dir." % [seats[player].display_name, text])
	else:
		hud.set_hint("Treffer! %s bekommt %s." % [seats[player].display_name, text])
	_react(player, "happy")
	if target > 0:
		_react(target, "grumpy")
	for index in range(count):
		var card := int(given[index])
		_place(card, "hand" if player == 0 else "fan", player, 100 + index)
		_send(cards[card], 0, 1, 0.5, 0.08 * index, 0.3)
		_sfx("card_draw")
	await _wait(0.6)
	_layout_zone("hand" if target == 0 else "fan", target, 0.2)
	_assign_hand_orders(player)
	_layout_zone("hand" if player == 0 else "fan", player, 0.2)
	if player == 0:
		_layout_hand(0.2)
	_refresh_hud()
	await _wait(0.35)


func _assign_hand_orders(player: int) -> void:
	var hand: Array = rules.s.r.hands[player]
	for index in range(hand.size()):
		if cards.has(int(hand[index])) and cards[int(hand[index])].zone in ["hand", "fan"]:
			cards[int(hand[index])].order = index


func _show_miss(event: Dictionary) -> void:
	var player := int(event.p)
	var target := int(event.from)
	if player == 0:
		hud.set_hint("%s hat keine. Du ziehst eine Karte." % seats[target].display_name)
	elif target == 0:
		hud.set_hint("Du hast keine. %s zieht eine Karte." % seats[player].display_name)
	else:
		hud.set_hint("Fehlgriff! %s zieht eine Karte." % seats[player].display_name)
	if target > 0:
		seats[target].react("grumpy")
		seats[target].hide_emote()
	_sfx("card_pass")
	await _wait(0.6)


func _show_draw(event: Dictionary) -> void:
	var player := int(event.p)
	var card := int(event.card)
	if not cards.has(card):
		return
	_place(card, "hand" if player == 0 else "fan", player, 100)
	_sfx("card_draw")
	_send(cards[card], 0, 1, 0.5, 0.0, 0.3)
	await _wait(0.55)
	_assign_hand_orders(player)
	if player == 0:
		_layout_hand(0.2)
	else:
		_layout_zone("fan", player, 0.2)
	if bool(event.get("lucky", false)):
		hud.set_hint("Glückstreffer! %s noch einmal fragen." % ("Du darfst" if player == 0 else seats[player].display_name + " darf"))
		_react(player, "happy")
		_burst_at(seats[player].chest() if player > 0 else Vector3(0, ROOM.TABLE_Y + 0.3, 0.8))
		await _wait(0.7)
	_refresh_hud()


func _show_set(event: Dictionary) -> void:
	var player := int(event.p)
	var set_cards: Array = event.cards
	var set_index: int = rules.s.r.sets[player].find(int(event.rank))
	hud.set_hint("%s ein Quartett: vier Mal %s!" % ["Du hast" if player == 0 else seats[player].display_name + " hat",
		DECK.rank_label(int(event.rank))])
	_react(player, "happy")
	_sfx("quartet")
	for index in range(set_cards.size()):
		var card := int(set_cards[index])
		_place(card, "set", player, maxi(0, set_index) * 4 + DECK.suit(card))
		_send(cards[card], 0, 1, 0.55, 0.07 * index, 0.34)
	await _wait(0.7)
	var toward := _dir(player)
	_burst_at(toward * (0.62 if player == 0 else 0.8) + Vector3(0, ROOM.TABLE_Y + 0.1, 0))
	_layout_zone("hand" if player == 0 else "fan", player, 0.2)
	if player == 0:
		_layout_hand(0.2)
	_refresh_hud()
	await _wait(0.45)


func _make_burst() -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	burst.name = "StarBurst"
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 18
	burst.lifetime = 0.8
	burst.explosiveness = 0.92
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 0.7
	burst.initial_velocity_max = 1.5
	burst.gravity = Vector3(0, -1.6, 0)
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.1
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 6
	mesh.rings = 3
	burst.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffd76a")
	burst.material_override = material
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	return burst


func _burst_at(at: Vector3) -> void:
	if reduced_motion or not is_instance_valid(_burst):
		return
	_burst.global_position = at
	_burst.restart()
	_burst.emitting = true


# ------------------------------------------------------------------ Anzeige


func _refresh_hud() -> void:
	if not is_instance_valid(hud):
		return
	if rules == null or screen != "play":
		hud.set_plates([])
		return
	var info: Dictionary = GAMES[game]
	var round_text := "Runde %d von %d" % [rules.round_number(), rules.rounds_total()]
	if not _intro_steps.is_empty():
		round_text = "Einführung"
	hud.set_game(str(info.title), round_text)
	hud.set_stars(ProgressStore.total_stars())
	hud.set_trump(int(rules.s.r.trump) if game == "stich" else -1)
	var current: int = rules.current()
	var plates: Array = []
	for player in range(rules.players()):
		var detail := ""
		match game:
			"stich":
				var count := int(rules.s.r.tricks[player])
				detail = "%d Stich%s" % [count, "" if count == 1 else "e"]
			"leiter":
				var left: int = rules.s.r.hands[player].size()
				detail = "%d Karte%s" % [left, "" if left == 1 else "n"]
			"quartett":
				detail = "%d Quartett%s · %d K." % [rules.s.r.sets[player].size(), "" if rules.s.r.sets[player].size() == 1 else "e",
					rules.s.r.hands[player].size()]
		var target: bool = (game == "quartett" and _pick_rank > 0 and player > 0 and _can_act()
			and rules.is_legal(0, {"ask": _pick_rank, "from": player}))
		plates.append({
			"name": "Du (Lumo)" if player == 0 else seats[player].display_name,
			"portrait": "lumo" if player == 0 else seats[player].kind,
			"info": detail,
			"active": player == current,
			"target": target,
		})
	hud.set_plates(plates)
	if _can_act():
		hud.set_hint(_turn_hint())
		var legal: Array = rules.legal_moves(0)
		if legal.size() == 1 and legal[0].has("pass"):
			hud.set_action("Aussetzen")
		elif legal.size() == 1 and legal[0].has("draw"):
			hud.set_action("Karte ziehen")
		elif _selected.size() == 1 and game != "quartett":
			hud.set_action("Legen")
		else:
			hud.set_action("")
	else:
		hud.set_action("")


func _round_rows(points: Array, detail_for: Callable) -> Array:
	var rows: Array = []
	var best := -1
	for value: int in points:
		best = maxi(best, value)
	for player in range(rules.players()):
		rows.append({
			"name": "Du (Lumo)" if player == 0 else seats[player].display_name,
			"portrait": "lumo" if player == 0 else seats[player].kind,
			"detail": detail_for.call(player),
			"points": "+%d" % int(points[player]),
			"winner": int(points[player]) == best,
		})
	return rows


func _round_detail(entry: Dictionary, player: int) -> String:
	match game:
		"stich":
			var count := int(entry.tricks[player])
			return "%d Stich%s · gesamt %d" % [count, "" if count == 1 else "e", int(rules.s.scores[player])]
		"leiter":
			var left := int(entry.left[player])
			return ("alle Karten gelegt" if left == 0 else "%d Karte%s übrig" % [left, "" if left == 1 else "n"]) + " · gesamt %d" % int(rules.s.scores[player])
		"quartett":
			var count: int = entry.sets[player].size()
			return "%d Quartett%s · gesamt %d" % [count, "" if count == 1 else "e", int(rules.s.scores[player])]
	return ""


func _show_round() -> void:
	var entry: Dictionary = rules.s.history.back()
	var won: bool = entry.winners.has(0)
	_sfx("round_win" if won else "card_pass")
	seats[0].react("happy" if won else "nod")
	for player: int in entry.winners:
		_react(player, "happy")
	var title := "Runde %d geschafft!" % rules.round_number()
	var text := "Du hast diese Runde gewonnen!" if won else "%s gewinnt diese Runde." % _name_of(int(entry.winners[0]))
	hud.set_hint("")
	hud.show_round({"title": title, "text": text,
		"rows": _round_rows(entry.points, func(player: int) -> String: return _round_detail(entry, player)),
		"next_text": "Nächste Runde"})


func _finish_match() -> void:
	var places: Array = rules.places()
	var place := int(places[0])
	if _final_data.is_empty():
		var payload: Dictionary = session.settle(rules, str(SceneRouter.launch_options.get("sessionId", HostBridge.launch_options().get("sessionId", ""))))
		var reward_text := "Bereits gewertet"
		var warning := ""
		if not payload.is_empty():
			last_result = payload
			ProgressStore.add_stars(int(payload.stars))
			var accepted: bool = HostBridge.reward(payload)
			if HostBridge.is_embedded() and not accepted:
				warning = HostBridge.SAVE_FAILURE
			reward_text = "+%d Stern%s" % [int(payload.stars), "" if int(payload.stars) == 1 else "e"]
			settled.emit(payload)
		var rows: Array = []
		for player in range(rules.players()):
			rows.append({
				"name": "Du (Lumo)" if player == 0 else seats[player].display_name,
				"portrait": "lumo" if player == 0 else seats[player].kind,
				"detail": "%d. Platz" % int(places[player]),
				"points": str(int(rules.s.scores[player])),
				"winner": int(places[player]) == 1,
			})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.points) > int(b.points))
		var titles := ["Gewonnen!", "Zweiter Platz!", "Dritter Platz!", "Geschafft!"]
		var texts := ["Lumo jubelt: Du hast die Partie gewonnen!", "Stark gespielt – ganz knapp dran!",
			"Gut gemacht! Beim nächsten Mal klappt noch mehr.", "Jede Partie macht dich besser. Gleich noch einmal?"]
		_final_data = {"title": titles[place - 1], "text": texts[place - 1], "place": place, "rows": rows,
			"reward": reward_text, "warning": warning}
	screen = "final"
	_sfx("round_win")
	seats[0].react("happy" if place == 1 else "wave")
	for player in range(1, seats.size()):
		if int(places[player]) == 1:
			seats[player].react("happy")
	hud.set_hint("")
	hud.set_action("")
	hud.set_stars(ProgressStore.total_stars())
	hud.show_final(_final_data)


# --------------------------------------------------------------- Einführung


func _start_intro(id: String) -> void:
	_generation += 1
	hud.close_overlay()
	game = id
	screen = "play"
	_paused = false
	_busy = false
	_won_owner.clear()
	rules = INTRO.demo(id)
	_intro_steps = INTRO.steps(id)
	_intro_index = -1
	_intro_blocking = true
	_enter_intro_table()


func _enter_intro_table() -> void:
	var wanted: Array = rules.s.seats
	if wanted != _seat_ids or seats.size() != rules.players():
		_build_seats(wanted)
	for seat: Node3D in seats:
		seat.set_suspended(false)
		seat.react("idle")
	hud.show_top(true)
	_frame_camera()
	_measure_hand()
	_spawn_round(true)
	_refresh_hud()
	hud.set_hint("")
	_intro_advance()


func _intro_step() -> Dictionary:
	if _intro_index >= 0 and _intro_index < _intro_steps.size():
		return _intro_steps[_intro_index]
	return {}


func _intro_advance() -> void:
	if _intro_steps.is_empty():
		return
	_intro_index += 1
	if _intro_index >= _intro_steps.size():
		_intro_finish()
		return
	var step := _intro_step()
	if str(step.when) == "turn" and (rules.phase() != "playing" or rules.current() != 0 or _busy):
		# Erst die Mitspieler ziehen lassen; der Schritt erscheint, wenn das Kind dran ist.
		hud.hide_bubble()
		_intro_blocking = false
		_intro_index -= 1
		_intro_waiting_turn = true
		_pump()
		return
	_intro_show(step)


func _intro_show(step: Dictionary) -> void:
	var wait := str(step.wait)
	var buttons: Array = []
	if wait == "tap":
		buttons = [["intro_skip", "Überspringen", "blue"], ["intro_next", "Weiter", "gold"]]
	elif wait == "done":
		buttons = [["intro_next", "Los geht's!", "gold"]]
	else:
		buttons = [["intro_skip", "Überspringen", "blue"]]
	_intro_blocking = wait in ["tap", "done"]
	hud.show_bubble(str(step.text), buttons)
	seats[0].look_at_point(camera.global_position)
	seats[0].react("point" if wait in ["tap", "done"] else "nod")
	_intro_focus(str(step.focus))
	_refresh_hud()
	_layout_hand(0.15)
	if not _intro_blocking and _legal_cards.is_empty() and not _busy:
		# Das Kind ist dran, der Zug hat aber noch nicht begonnen.
		_pump()


func _intro_focus(what: String) -> void:
	for id: int in cards:
		if cards[id].zone == "trump":
			cards[id].set_glow(GOLD if what == "trump" else OFF)


func _intro_on_turn() -> void:
	if _intro_steps.is_empty():
		return
	if _intro_waiting_turn:
		_intro_waiting_turn = false
		_intro_index += 1
		_intro_show(_intro_step())


func _intro_on_select() -> void:
	if not _intro_steps.is_empty() and str(_intro_step().get("wait", "")) == "select":
		_intro_advance()


func _intro_after_play() -> void:
	if _intro_steps.is_empty():
		return
	if str(_intro_step().get("wait", "")) == "play":
		_intro_advance()


func _intro_finish() -> void:
	if _intro_steps.is_empty():
		return
	var id := game
	_intro_steps = []
	_intro_index = -1
	_intro_blocking = false
	_intro_waiting_turn = false
	hud.hide_bubble()
	session.mark_intro_seen(id)
	# Nach der Einführung wählt das Kind Mitspieler und Stärke – oder spielt weiter.
	_open_select()
	_open_setup(id)


# ------------------------------------------------------- Auskunft für Prüfungen


## Bildpunkt der Kartenmitte (für Bedien- und Bildprüfungen).
func card_point(card: int) -> Vector2:
	return camera.unproject_position(cards[card].global_position) if cards.has(card) else Vector2(-1, -1)


## Die vier Ecken der Kartenfläche in Bildpunkten.
func card_quad(card: int) -> Array:
	var quad: Array = []
	if not cards.has(card):
		return quad
	var node: Node3D = cards[card]
	for corner: Vector3 in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]:
		var at := camera.unproject_position(node.to_global(corner * Vector3(ART.WIDTH, 0, ART.HEIGHT)))
		quad.append([at.x, at.y])
	return quad


func hand_cards() -> Array:
	return _hand_order()


func is_idle() -> bool:
	if _busy or _pumping:
		return false
	for id: int in cards:
		if cards[id].is_moving():
			return false
	return true
