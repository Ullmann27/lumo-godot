extends SceneTree
## Bilder vom Schachtisch für die Sichtprüfung (wie am Gerät: gl_compatibility).
## Aufruf: xvfb-run … godot --path . --rendering-method gl_compatibility
##   --audio-driver Dummy --script res://scripts/tests/chess_visual_capture.gd -- <ordner>

const TABLE := "res://scenes/games/chess_table.tscn"
const SESSION = preload("res://scripts/games/chess/chess_session.gd")
const CHILD := "chess-visual-capture"
const OPENING := ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "d2d3", "f8c5", "c2c3", "d7d6", "b1d2", "c8e6"]

var out_dir := ""
var table: Node
var shots: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames(8)
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	image.save_png(path)
	shots.append(path)
	print("[ChessCapture] ", path, " ", image.get_size())


func _resize(size: Vector2i) -> void:
	root.size = size
	DisplayServer.window_set_size(size)
	await _frames(6)
	if table != null:
		table._layout()
	await _frames(4)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://chess_capture"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bridge := root.get_node("HostBridge")
	bridge._options = {"displayDensity": 2.6, "childKey": CHILD, "soundEnabled": false}
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	await _resize(Vector2i(1080, 2160))
	table = load(TABLE).instantiate()
	root.add_child(table)
	await _frames(20)
	await _shot("01_start_hoch")
	# Partie gegen Lumo, ein paar Eröffnungszüge.
	table.mode = "play"
	table.start_match(2, false)
	for uci: String in OPENING:
		table.rules.play_uci(uci)
	table._show_position()
	table.selected = table.rules.move_from_uci("e1g1") & 63
	table._refresh_glow()
	table.say("Mein Läufer kommt heraus und hilft in der Mitte.", "Lumo · Schlaufuchs")
	await _shot("02_partie_3d_hoch")
	table.view = "top"
	table._update_view()
	await _shot("03_partie_draufsicht_hoch")
	await _resize(Vector2i(2160, 1080))
	await _shot("04_partie_draufsicht_quer")
	table.view = "3d"
	table._update_view()
	await _shot("05_partie_3d_quer")
	await _resize(Vector2i(1080, 2160))
	# Schachschule: der Springer.
	table.start_lesson("springer")
	table.step_index = 1
	table._enter_step()
	await _frames(30)
	await _shot("06_schule_springer_hoch")
	table.start_lesson("labyrinth")
	table.step_index = 1
	table._enter_step()
	await _frames(10)
	await _shot("07_schule_labyrinth_hoch")
	table.view = "top"
	table._update_view()
	await _shot("08_schule_labyrinth_draufsicht")
	table.view = "3d"
	table._update_view()
	table.start_trial("t1")
	await _frames(10)
	await _shot("09_probespiel_bauernrennen")
	table.open_path()
	await _shot("10_lernweg")
	print("CHESS_CAPTURE_DONE %d" % shots.size())
	DirAccess.remove_absolute(SESSION.path_for(CHILD))
	table.queue_free()
	await _frames(2)
	quit(0)
