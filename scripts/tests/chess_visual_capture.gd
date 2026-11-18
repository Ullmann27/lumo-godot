extends SceneTree
## Belegbilder vom Schachtisch (wie am Gerät: gl_compatibility).
## Aufruf: xvfb-run … godot --path . --rendering-method gl_compatibility
##   --audio-driver Dummy --script res://scripts/tests/chess_visual_capture.gd -- <ordner> [maßstab] [auswahl]
## Maßstab < 1 verkleinert alle Fenster (Zwischenprüfung). Auswahl: Kommaliste
## der Bildnamen-Anfänge (z. B. "01,05"); leer = alle.

const TABLE := "res://scenes/games/chess_table.tscn"
const SESSION = preload("res://scripts/games/chess/chess_session.gd")
const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const CHILD := "chess-visual-capture"
const FOLD := Vector2i(1812, 2176)
const FOLD_WIDE := Vector2i(2176, 1812)
const SLIM := Vector2i(1080, 2340)
## Eine Partie „Für Große“ (Italienisch), Stellung nach 14 Halbzügen.
const PRO_GAME := ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "c2c3", "g8f6", "d2d3", "d7d6",
	"e1g1", "e8g8", "f1e1", "a7a6"]
## Probespiel: Kind hat die Dame zu früh gebracht, Lumo greift sie an.
const TRIAL_GAME := ["e2e4", "e7e5", "d1h5", "b8c6", "f1c4", "g8f6"]

var out_dir := ""
var scale := 1.0
var only: PackedStringArray = []
var table: Node
var shots: Array[String] = []
var bridge: Node


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _wanted(name: String) -> bool:
	if only.is_empty():
		return true
	for prefix: String in only:
		if name.begins_with(prefix):
			return true
	return false


func _shot(name: String) -> void:
	await _frames(10)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	image.save_png(path)
	shots.append(path)
	print("[ChessCapture] ", path, " ", image.get_size())


func _resize(size: Vector2i) -> void:
	var s := Vector2i(Vector2(size) * scale)
	bridge._options["displayDensity"] = 2.625 * scale
	root.size = s
	DisplayServer.window_set_size(s)
	await _frames(6)
	if table != null:
		table._layout()
	await _frames(4)


## Neuer Tisch je Bild-Gruppe, damit Schriftgrößen zur Dichte passen.
func _fresh(size: Vector2i) -> void:
	if table != null:
		table.queue_free()
		await _frames(2)
	await _resize(size)
	table = load(TABLE).instantiate()
	table.time_scale = 50.0
	root.add_child(table)
	await _frames(20)


func _wait_idle() -> void:
	for i in 400:
		if table.is_idle():
			break
		await process_frame
	await _frames(20)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://chess_capture"
	scale = float(args[1]) if args.size() > 1 else 1.0
	if args.size() > 2 and not args[2].is_empty():
		only = args[2].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	bridge = root.get_node("HostBridge")
	bridge._options = {"displayDensity": 2.625, "childKey": CHILD, "soundEnabled": false}
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	for size_name: String in ["fold", "slim"]:
		var size := FOLD if size_name == "fold" else SLIM
		var tag := "_" + size_name
		if _wanted("01") or _wanted("02"):
			await _fresh(size)
			if _wanted("01"):
				await _shot("01_start" + tag)
			if _wanted("02"):
				table.open_levels("pro")
				await _shot("02_stufen_fuer_grosse" + tag)
		if _wanted("03"):
			await _fresh(size)
			table.start_lesson("bauer")
			table.step_index = 3
			table._enter_step()
			await _wait_idle()
			table.selected = RULES.square_from_name("d2")
			table._refresh_glow()
			await _shot("03_lernen_bauer" + tag)
		if _wanted("04"):
			await _fresh(size)
			table.start_lesson("springer")
			table.step_index = 1
			table._enter_step()
			await _wait_idle()
			await _shot("04_lernen_springer" + tag)
		if _wanted("05"):
			await _fresh(size)
			table.start_trial("t5")
			await _wait_idle()
			# Züge direkt setzen, dann Lumos letzten Zug mit Gefahrenhinweis zeigen.
			for i in TRIAL_GAME.size() - 1:
				table.rules.play_uci(TRIAL_GAME[i])
			var lumo_move: int = table.rules.move_from_uci(TRIAL_GAME[-1])
			var before: RefCounted = table.rules.duplicate_state()
			table.rules.play(lumo_move)
			table._show_position()
			var danger: Dictionary = table.COACH.danger(table.rules)
			table._danger_sq = int(danger.get("square", -1))
			table._refresh_glow()
			table.say(table.COACH.explain(before, lumo_move, true) + " " + str(danger.get("text", "")), "Lumo")
			await _shot("05_probespiel_hinweis" + tag)
		if _wanted("06"):
			for view: String in ["3d", "top"]:
				await _fresh(size)
				table.view = view
				table.mode = "pro"
				table.start_match(3, false)
				for uci: String in PRO_GAME:
					table.rules.play_uci(uci)
				table._show_position()
				table.say("Ich ziehe a6.", "Lumo · Militärschachspieler")
				await _shot("06_fuer_grosse_%s%s" % [view, tag])
				if size_name == "fold":
					await _resize(FOLD_WIDE)
					await _shot("06_fuer_grosse_%s_fold_quer" % view)
	print("CHESS_CAPTURE_DONE %d" % shots.size())
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	if table != null:
		table.queue_free()
	await _frames(2)
	quit(0)
