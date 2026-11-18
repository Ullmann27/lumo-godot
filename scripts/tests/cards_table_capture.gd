extends SceneTree
## Bildbelege des Kartentischs mit echtem Renderer: Auswahl, Einführung, jede
## der drei Partien, Stich-/Anlege-/Quartett-Moment, Rundenwertung, Endstand –
## in Hoch- und Querformat, dazu ein Fold-Bild. Keine Gerätemessung.

const TABLE := "res://scenes/games/cards_table.tscn"
const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const QUARTETT = preload("res://scripts/games/cards/rules/quartett_rules.gd")
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CHILD := "cards-table-capture"
const VIEWS := [
	["hoch", Vector2i(720, 1280), 1.75],
	["quer", Vector2i(1280, 720), 1.75],
	["fold", Vector2i(1768, 2208), 2.4],
	["foldquer", Vector2i(2208, 1768), 2.4],
]
const FAST := 60.0

var table: Node
var out := ""
var views: Array[Dictionary] = []
var problems: Array[String] = []
var prefix := ""


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	root.disable_3d = false
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s_%s.png" % [out, prefix, name]
	if image.is_empty() or image.get_size() != root.size or image.save_png(path) != OK:
		problems.append("Bild fehlt: " + path)
	views.append({
		"file": path.get_file(), "width": root.size.x, "height": root.size.y, "density": table._ui_scale,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
	})
	root.disable_3d = true


## Spielt schnell weiter, bis `stop` wahr ist. Das Kind zieht wie ein Mitspieler mittlerer Stärke.
func _advance(stop: Callable, limit: int = 500) -> bool:
	table.time_scale = FAST
	for step in range(limit):
		if not await DRIVER.idle(self, table, 60.0):
			problems.append("Tisch hängt")
			return false
		if stop.call():
			return true
		if table.screen != "play":
			return false
		if table.hud.overlay_kind == "round":
			table._on_chosen("next_round", {})
			continue
		if not table.hud.overlay_kind.is_empty():
			return false
		if table._can_act():
			table._human_play(DRIVER.suggestion(table))
	return false


func _start(game: String, players: int, rounds: int, seed_value: int) -> void:
	table.session.mark_intro_seen(game)
	table.session.discard(game)
	table.session.set_prefs(players, 1, rounds)
	table.forced_seed = seed_value
	table.time_scale = FAST
	table._on_chosen("start", {"game": game})
	await DRIVER.idle(self, table, 60.0)


func _wait_hint(word: String, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not word in table.hud.hint_label.text:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Cards capture requires a real renderer")
		quit(2)
		return
	out = OS.get_environment("LUMO_CAPTURE_DIR")
	if out.is_empty():
		out = "res://exports/cards-table"
	# --only=quer,fold beschränkt die Bilder auf diese Ansichten (für schnelle Durchgänge).
	var only: PackedStringArray = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			out = argument.trim_prefix("--output=")
		elif argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 0
	var bridge := root.get_node("HostBridge")
	var original: Dictionary = bridge._options.duplicate(true)
	var save_path := SESSION.path_for(CHILD)
	for view: Array in VIEWS:
		if not only.is_empty() and not str(view[0]) in only:
			continue
		prefix = view[0]
		root.size = view[1]
		bridge._options = {"displayDensity": view[2], "childKey": CHILD, "soundEnabled": false}
		DirAccess.remove_absolute(save_path)
		await process_frame
		table = load(TABLE).instantiate()
		root.add_child(table)
		await DRIVER.settle(self, 8)
		await create_timer(0.8).timeout
		await _shot("01_auswahl")
		if prefix.begins_with("fold"):
			await _start("stich", 4, 3, 4242)
			await _advance(func() -> bool: return table._can_act() and int(table.rules.s.r.trick_no) >= 1)
			await _shot("10_stich_partie")
		else:
			await _all_scenes()
		if not await SCENE_TEARDOWN.release_scene(self, table, "[CardsCapture] " + prefix):
			problems.append("Szene nicht freigegeben")
		table = null
		await process_frame
	root.disable_3d = false
	bridge._options = original
	DirAccess.remove_absolute(save_path)
	var report := FileAccess.open(out.path_join("cards-render.json"), FileAccess.WRITE)
	if report == null:
		problems.append("Bericht nicht schreibbar")
	else:
		report.store_string(JSON.stringify({"renderer": DisplayServer.get_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"android_device_measurement": false, "problems": problems, "views": views}, "  "))
		report.close()
	if problems.is_empty():
		print("CARDS_TABLE_RENDER_PASS renderer=%s images=%d" % [DisplayServer.get_name(), views.size()])
	else:
		push_error("Cards capture: " + ", ".join(problems))
	quit(0 if problems.is_empty() else 1)


func _all_scenes() -> void:
	# Einstellungen und Einführung.
	table.session.mark_intro_seen("stich")
	table._on_chosen("game", {"game": "stich"})
	await DRIVER.settle(self, 4)
	await _shot("02_einstellungen")
	table._on_chosen("intro", {"game": "stich"})
	table.time_scale = FAST
	await DRIVER.idle(self, table, 30.0)
	table._on_chosen("intro_next", {})
	await DRIVER.settle(self, 6)
	await _shot("03_einfuehrung")
	table._on_chosen("intro_skip", {})
	await DRIVER.settle(self, 3)
	# Sternenstich: Zug des Kindes, Stich-Moment, Rundenwertung.
	await _start("stich", 4, 3, 4242)
	await _advance(func() -> bool:
		return table._can_act() and int(table.rules.s.r.trick_no) >= 2 and table._legal_cards.size() < table.rules.s.r.hands[0].size())
	await _shot("10_stich_partie")
	await _advance(func() -> bool: return table._can_act() and table.rules.s.r.trick.size() == 3)
	table.time_scale = 1.0
	table._human_play(DRIVER.suggestion(table))
	root.disable_3d = false
	await _wait_hint("den Stich", 6.0)
	await create_timer(0.35).timeout
	await _shot("11_stich_stich")
	await _advance(func() -> bool: return table.hud.overlay_kind == "round")
	await _shot("12_stich_rundenwertung")
	table._on_chosen("next_round", {})
	await DRIVER.idle(self, table, 60.0)
	table._pause()
	await DRIVER.settle(self, 4)
	await _shot("13_pause")
	table._on_chosen("rules", {})
	await DRIVER.settle(self, 4)
	await _shot("14_regeln")
	table._on_chosen("rules_done", {})
	table._on_chosen("quit", {})
	await DRIVER.settle(self, 3)
	# Sternenleiter: gewachsene Leitern, Anlege-Moment.
	await _start("leiter", 4, 1, 77)
	await _advance(func() -> bool: return table._can_act() and table.rules.s.r.laid.size() >= 14 and not table._legal_cards.is_empty())
	await _shot("20_leiter_partie")
	table.time_scale = 0.7
	table._human_play(DRIVER.suggestion(table))
	root.disable_3d = false
	await create_timer(0.3).timeout
	await _shot("21_leiter_anlegen")
	await _advance(func() -> bool: return table.hud.overlay_kind == "final")
	await _shot("22_leiter_endstand")
	table._on_chosen("menu", {})
	await DRIVER.settle(self, 3)
	# Lumo-Quartett: Frage des Kindes, Quartett-Moment.
	await _start("quartett", 4, 1, 31)
	await _advance(func() -> bool: return table._can_act() and not table._legal_cards.is_empty() and table.rules.sets_total() >= 1)
	if table._can_act():
		table._tap_card(int(table.rules.s.r.hands[0][0]))
		await DRIVER.settle(self, 12)
	await _shot("30_quartett_frage")
	# Weiter, bis das Kind mit einer Frage ein Quartett vollmachen kann.
	var chance: Dictionary = {}
	await _advance(func() -> bool:
		if not table._can_act():
			return false
		for move: Dictionary in table.rules.legal_moves(0):
			if move.has("ask") and QUARTETT.count_rank(table.rules.s.r.hands[0], int(move.ask)) + QUARTETT.count_rank(table.rules.s.r.hands[int(move.from)], int(move.ask)) == 4:
				chance = move
				return true
		return false)
	if not chance.is_empty() and table._can_act():
		table.time_scale = 1.0
		table._human_play(chance)
		root.disable_3d = false
		await _wait_hint("Quartett", 8.0)
		await create_timer(0.9).timeout
	await _shot("31_quartett_quartett")
	await _advance(func() -> bool: return table.hud.overlay_kind == "final")
	await _shot("32_quartett_endstand")
