extends SceneTree
## Tatsächlicher Vorspann mit allen drei Einstellungen, erstem Klick, Rückkehr und weniger Bewegung.

const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const DRIVER = preload("res://scripts/tests/helpers/cards_table_driver.gd")
const DROP = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const SCENE := "res://scenes/games/cards_table.tscn"
var errors: Array[String] = []
var shots := OS.get_environment("LUMO_CARDS_OPENING_SHOTS")
var table
var seen: Array[int] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)


func capture(label: String) -> void:
	if shots.is_empty():
		return
	RenderingServer.render_loop_enabled = true
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(shots.path_join(label + ".png")) == OK, label)
	RenderingServer.render_loop_enabled = false


func open_profile(child: String, reduced: bool, sound: bool = false) -> void:
	root.get_node("HostBridge")._options = {"childKey": child, "displayDensity": 1.0, "reduceAnimations": reduced, "soundEnabled": sound}
	table = load(SCENE).instantiate()
	root.add_child(table)
	await DRIVER.settle(self, 2)


func close_table() -> void:
	check(await DROP.release_scene(self, table, "[CardsOpening]"), "Tisch freigegeben")
	table = null
	await process_frame


func run() -> void:
	var bridge = root.get_node("HostBridge")
	var options: Dictionary = bridge._options.duplicate(true)
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		RenderingServer.render_loop_enabled = false
	var child := "cards-opening-%d" % Time.get_ticks_usec()
	var save_path := SESSION.path_for(child)
	await open_profile(child, false)
	check(table.screen == "opening" and not table.hud.visible, "Film vor der Spielwahl")
	var film = table.opening
	check(film.fan.size() == 5 and film.dealt.card_id == 12, "Originaldeck im Film")
	film.set_process(false)
	for target in [1.23, 2.43, 4.7]:
		while film.elapsed < target:
			film._process(1.0 / 60.0)
			for seat in table.seats:
				seat.advance(1.0 / 60.0)
		seen.append(film.shot)
		check(film.skip.is_visible_in_tree(), "Überspringen in Einstellung %d" % film.shot)
		await capture("cards_opening_%d" % film.shot)
	check(seen == [0, 1, 2], "Makro, Gegenschuss und Tisch-Totale")
	while is_instance_valid(table.opening):
		film._process(1.0 / 60.0)
	await DRIVER.settle(self, 2)
	check(table.screen == "select" and table.hud.visible and table.session.intro_seen("table_opening"), "Filmende und sichtbare Auswahl")
	await capture("cards_opening_3_select")
	await close_table()
	await open_profile(child, false)
	check(table.screen == "select", "Zweiter Besuch beginnt an der Auswahl")
	await close_table()
	DirAccess.remove_absolute(save_path)
	await open_profile(child, false, true)
	check(table.opening.music != null and table.opening.music.playing and absf(table.opening.SCORE.get_length() - 5.7) < 0.05, "Eigener Filmton")
	check(table.opening.elapsed < 1.0, "Knopf im ersten Bild verfügbar")
	await DRIVER.skip_opening(self, table)
	check(table.screen == "select" and table.hud.overlay_kind == "select", "Erste Berührung überspringt und wählt kein Spiel")
	await close_table()
	DirAccess.remove_absolute(save_path)
	await open_profile(child, true)
	check(table.screen == "select" and table.opening == null, "Reduzierte Bewegung überspringt den Film")
	await close_table()
	DirAccess.remove_absolute(save_path)
	var old_save = SESSION.new(save_path)
	old_save.new_match("stich", {"players": 2, "rounds": 1, "difficulty": 1, "seed": 17, "result_id": "test-match", "seats": ["owl"]})
	var snapshot: String = FileAccess.get_file_as_string(save_path)
	await open_profile(child, false)
	check(table.screen == "select" and table.session.has_match("stich"), "Laufende Partie ist sofort erreichbar")
	check(FileAccess.get_file_as_string(save_path) == snapshot, "Öffnen bewahrt die gespeicherte Partie")
	await close_table()
	DirAccess.remove_absolute(save_path)
	bridge._options = options
	RenderingServer.render_loop_enabled = true
	root.get_node("GameSoundscape").release_audio()
	await create_timer(0.35).timeout
	print("CARDS_OPENING_%s shots=%s failures=%d" % ["PASS" if errors.is_empty() else "FAIL", seen, errors.size()])
	quit(0 if errors.is_empty() else 1)
