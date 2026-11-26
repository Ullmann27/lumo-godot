extends SceneTree
## Selects Punktlandung from the real table, plays seven targets by touch
## and observes the announced target before the next round is displayed.

const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")
const CHILD := "punktlandung-reveal-regression"

var table: Node
var resolved: Dictionary = {}
var failures: Array[String] = []
var checks := 0
var capture_dir := ""
var reveal_capture_requested := false
var capture_in_progress := false


class Host:
	extends RefCounted
	var options := {"childKey": CHILD, "reduceAnimations": true, "soundEnabled": false}
	var rewards: Array[String] = []
	var returns: Array[String] = []

	func getLaunchOptions() -> String:
		return JSON.stringify(options)

	func reward(payload: String) -> int:
		rewards.append(payload)
		return 1

	func returnToApp(destination: String, _payload: String) -> int:
		returns.append(destination)
		return 1


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("[Punktlandung] FAIL " + message)


func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	capture_in_progress = true
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var path := capture_dir.path_join(label + ".jpg")
	_check(root.get_texture().get_image().save_jpg(path, 0.91) == OK, "rendered " + path)
	RenderingServer.render_loop_enabled = false
	capture_in_progress = false


func _observe_resolution() -> void:
	if not is_instance_valid(table) or table.rules == null or table.game != "ziel":
		return
	var hint: String = table.hud._hint_text
	if not hint.contains("Abstand:"):
		return
	var turn: int = table.rules.s.r.trick_no
	if resolved.has(turn):
		return
	resolved[turn] = hint
	var played: Array = table.rules.s.r.played
	var stock: Array = table.rules.s.r.stock
	var expected_target := DECK.rank(int(stock[turn - 1]))
	var best_distance := 12
	for card: int in played.slice(played.size() - table.rules.players()):
		best_distance = mini(best_distance, absi(DECK.rank(card) - expected_target))
	_check(hint.begins_with("Ziel %d ·" % expected_target), "turn %d announces its original target" % turn)
	_check(hint.ends_with("Abstand: %d." % best_distance), "turn %d explains the winning distance" % turn)
	_check(table.hud.round_label.text.ends_with("Ziel %d" % expected_target),
		"turn %d keeps the matching target in the header" % turn)
	var label: Label = table.hud.hint_label
	var safe: Control = table.hud.safe
	_check(label.is_visible_in_tree() and safe.get_global_rect().encloses(label.get_global_rect()),
		"turn %d keeps the complete explanation inside the game display" % turn)
	if not reveal_capture_requested:
		reveal_capture_requested = true
		_capture.call_deferred("Punktlandung-Abstand")


func _press(id: String) -> void:
	_check(await DRIVER.press(self, table, id), "touch " + id)
	await DRIVER.settle(self, 2)


func _run() -> void:
	capture_dir = OS.get_environment("LUMO_PUNKTLANDUNG_BELEGE")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless":
			printerr("[Punktlandung] A renderer is required for image evidence")
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var narrow_cover := "--fold-cover" in OS.get_cmdline_user_args()
	root.size = Vector2i(1080, 2340) if narrow_cover else Vector2i(860, 780)
	var bridge: Node = root.get_node("HostBridge")
	var previous_host: Object = bridge._host
	var previous_options: Dictionary = bridge._options
	var host := Host.new()
	if narrow_cover:
		host.options["displayDensity"] = 2.625
	bridge._host = host
	bridge._options = host.options
	var path: String = SESSION.path_for(CHILD)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	table = (load("res://scenes/games/cards_table.tscn") as PackedScene).instantiate()
	root.add_child(table)
	table.time_scale = 1.75
	await DRIVER.settle(self, 12)
	_check(table.hud.overlay_kind == "select", "Cards opens its own table")
	for id in ["stich", "leiter", "quartett", "ziel"]:
		_check(is_instance_valid(table.hud.find_button("Tile_" + id)), "visible game choice " + id)
	await _capture("Cards-Spielauswahl")
	await _press("Tile_ziel")
	_check(table.screen == "play" and table.game == "ziel", "the first choice opens its own introduction")
	await _press("intro_skip")
	_check(table.hud.overlay_kind == "setup", "return from introduction to Punktlandung setup")
	await _press("Pick_players_2")
	await _press("Pick_rounds_1")
	table.forced_seed = 2085
	process_frame.connect(_observe_resolution)
	await _press("start")
	var remaining := 10
	while remaining > 0 and table.screen == "play":
		remaining -= 1
		if not await DRIVER.idle(self, table, 30.0):
			_check(false, "the played cards settled")
			break
		if table._can_act():
			_check(await DRIVER.play(self, table, DRIVER.suggestion(table)), "legal child card touched twice")
	process_frame.disconnect(_observe_resolution)
	while capture_in_progress:
		await process_frame
	_check(table.screen == "final" and table.hud.overlay_kind == "final", "full result after seven targets")
	_check(resolved.size() == 7, "all seven visible comparisons were observed")
	_check(host.rewards.size() == 1, "exactly one reward reached the host")
	_check(not table.session.has_match("ziel"), "a finished match is not offered for resume")
	await _capture("Punktlandung-Ergebnis")
	await _press("leave")
	_check(host.returns == ["games"], "return to games requested once")
	_check(await TEARDOWN.release_scene(self, table, "[Punktlandung]"), "released table")
	bridge._host = previous_host
	bridge._options = previous_options
	bridge._return_pending = false
	root.get_node("GameSoundscape").release_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PUNKTLANDUNG_%s checks=%d comparisons=%d failures=%d" %
		["PASS" if failures.is_empty() else "FAIL", checks, resolved.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
