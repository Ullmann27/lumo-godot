extends SceneTree
## Kart-Einstieg: Film über dem Menü, geprüfte Dekodierung, Überspringen,
## danach sofort bedienbares Menü; reduzierte Bewegung und --script ohne Intro.
## Mit Anzeige (xvfb) und Pfadargument entsteht ein Kontaktbogen echter Bilder.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_intro_regression.gd -- [out.png]

const GAME = "res://scenes/games/kart_island.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _game(mode: String, reduced: bool = false):
	var game = load(GAME).instantiate()
	game.intro_mode = mode
	root.add_child(game)
	await process_frame
	await process_frame
	if reduced:
		game.reduced_motion = true
	return game


func _drop(game) -> void:
	game.abandoned = true
	game.queue_free()
	await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else ""
	var render: bool = DisplayServer.get_name() != "headless" and not out_path.is_empty()
	root.size = Vector2i(1280, 720)

	# Standard in automatisierten Prüfungen: Menü sofort, kein Intro.
	var plain = await _game("auto")
	assert(plain.menu_active and is_instance_valid(plain.garage))
	assert(not is_instance_valid(plain.intro), "--script-Prüfungen sehen das Menü sofort")
	await _drop(plain)

	var game = await _game("force")
	assert(is_instance_valid(game.intro), "Erster Kart-Einstieg zeigt das Intro")
	var intro = game.intro
	intro.set_process(false)
	assert(intro.mouse_filter == Control.MOUSE_FILTER_STOP, "Intro fängt Tipps ab, statt Menüknöpfe auszulösen")
	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	assert(is_instance_valid(intro.film) and intro.film.stream.resource_path == intro.OPENING_PATH, "Der verpackte Rennfilm läuft")
	assert(intro.film.is_playing(), "Der Decoder startet beim Einstieg")
	# Let Godot decode four successive shots (Theora has no portable seek).
	if render:
		intro.set_process(true)
		var cue_times := [.3,1.7,3.4,4.95]
		var index := 0
		var until := Time.get_ticks_msec() + 60000
		while index < cue_times.size() and Time.get_ticks_msec() < until:
			await process_frame
			if not is_instance_valid(intro) or intro.leaving:
				break
			if intro.film.stream_position < cue_times[index]:
				continue
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			print("[KartIntro] Dekodiertes Filmbild ",index," bei ",intro.film.stream_position)
			image.resize(960,540)
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image, Rect2i(0,0,960,540), Vector2i((index%2)*960,(index/2)*540))
			index += 1
		assert(index == 4, "Alle vier Einstellungen vom laufenden Videoplayer gesehen (%d/4)" % index)
	# Tippen überspringt; während des Ausblendens geht der nächste Tipp schon ans Menü.
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	intro._gui_input(tap)
	assert(intro.leaving and intro.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	intro.set_process(true)
	for frame in range(40):
		await process_frame
	assert(not is_instance_valid(game.intro), "Intro räumt sich nach dem Ausblenden auf")
	assert(game.menu_active and game.garage.is_visible_in_tree(), "Menü ist danach direkt bedienbar")
	# Zurück im nächsten Menü zeigt kein zweites Intro.
	game._show_garage()
	assert(not is_instance_valid(game.intro), "Intro nur beim Einstieg, nicht nach jedem Rennen")
	await _drop(game)

	# Zurück-Taste während des Intros überspringt nur das Intro.
	var back_game = await _game("force")
	back_game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(back_game.intro.leaving and back_game.menu_active, "Zurück beendet nur das Intro")
	await _drop(back_game)

	if render:
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		assert(sheet.save_png(out_path) == OK)
	print("[KartIntro] PASS: Film, Dekoder, Touch/Zurück, Menü und einmaliger Einstieg")
	# Let the asynchronous audio mixer release the final stopped playback.
	await create_timer(0.2).timeout
	quit(0)
