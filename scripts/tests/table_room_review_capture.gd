extends SceneTree
## Schnelle Bildbelege für das Spielzimmer des Kartentischs (Runden-Review):
## Auswahl, Austeilen (Mischen/Flug), Sternenstich, Sternenleiter und
## Lumo-Quartett in Quer- (1600×720) und Hochformat (720×1600), dazu
## Draw-Calls/Dreiecke je Qualitätsprofil. Keine Gerätemessung (llvmpipe).
##
## Aufruf (xvfb, gl_compatibility):
##   … --script res://scripts/tests/table_room_review_capture.gd -- --output=<dir> [--tiers=0,1,2] [--views=quer,hoch]

const TABLE := "res://scenes/games/cards_table.tscn"
const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const SCENE_TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const CHILD := "table-room-review"
const VIEWS := {"quer": [Vector2i(1600, 720), 1.75], "hoch": [Vector2i(720, 1600), 1.75]}
const FAST := 60.0

var table: Node
var out := ""
var prefix := ""
var problems: Array[String] = []
var metrics: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s_%s.jpg" % [out, prefix, name]
	if image.is_empty() or image.save_jpg(path, 0.86) != OK:
		problems.append("Bild fehlt: " + path)
	metrics["%s_%s" % [prefix, name]] = {
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}
	print("[RoomReview] %s_%s %s" % [prefix, name, JSON.stringify(metrics["%s_%s" % [prefix, name]])])


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


func _start(game: String, players: int, seed_value: int, fast: float = FAST) -> void:
	table.session.mark_intro_seen(game)
	table.session.discard(game)
	table.session.set_prefs(players, 1, 1)
	table.forced_seed = seed_value
	table.time_scale = fast
	table._on_chosen("start", {"game": game})


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Review capture requires a real renderer")
		quit(2)
		return
	var tiers: Array = [1]
	var views: Array = ["quer", "hoch"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			out = argument.trim_prefix("--output=")
		elif argument.begins_with("--tiers="):
			tiers = Array(argument.trim_prefix("--tiers=").split(",")).map(func(v: String) -> int: return int(v))
		elif argument.begins_with("--views="):
			views = Array(argument.trim_prefix("--views=").split(","))
	if out.is_empty():
		out = "res://exports/table-room-review"
	DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 0
	var bridge := root.get_node("HostBridge")
	var performance: Node = root.get_node("PerformanceManager")
	var original_profile: int = int(performance.get("current_profile"))
	var original: Dictionary = bridge._options.duplicate(true)
	var save_path := SESSION.path_for(CHILD)
	for tier: int in tiers:
		performance.call("set_profile", tier, false)
		for view: String in views:
			prefix = "%s_%s" % [["low", "medium", "high"][tier], view]
			root.size = VIEWS[view][0]
			bridge._options = {"displayDensity": VIEWS[view][1], "childKey": CHILD, "soundEnabled": false}
			DirAccess.remove_absolute(save_path)
			await process_frame
			table = load(TABLE).instantiate()
			root.add_child(table)
			table.room.clock_override = 10.0 * 3600.0 + 8.0 * 60.0
			await DRIVER.settle(self, 8)
			await create_timer(0.6).timeout
			await _shot("01_auswahl")
			# Austeilen in echter Geschwindigkeit: Bild mitten im Mischen und im Flug.
			await _start("stich", 4, 4242, 1.0)
			await create_timer(0.35).timeout
			await _shot("02_mischen")
			await create_timer(0.75).timeout
			await _shot("03_austeilen")
			await _advance(func() -> bool:
				return table._can_act() and int(table.rules.s.r.trick_no) >= 2)
			await _shot("10_stich")
			if tier == 1 or tiers.size() == 1:
				table._on_chosen("quit", {})
				await DRIVER.settle(self, 3)
				await _start("leiter", 4, 77)
				await _advance(func() -> bool: return table._can_act() and table.rules.s.r.laid.size() >= 12)
				await _shot("20_leiter")
				table._on_chosen("quit", {})
				await DRIVER.settle(self, 3)
				await _start("quartett", 3, 5150)
				await _advance(func() -> bool: return table._can_act() and int(table.rules.s.moves) >= 4)
				await _shot("30_quartett")
			if not await SCENE_TEARDOWN.release_scene(self, table, "[RoomReview] " + prefix):
				problems.append("Szene nicht freigegeben")
			table = null
			await process_frame
	performance.call("set_profile", original_profile, false)
	bridge._options = original
	DirAccess.remove_absolute(save_path)
	var report := FileAccess.open(out.path_join("review-metrics.json"), FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "problems": problems, "shots": metrics}, "  "))
		report.close()
	print("TABLE_ROOM_REVIEW_%s" % ("PASS" if problems.is_empty() else "FAIL " + ", ".join(problems)))
	quit(0 if problems.is_empty() else 1)
