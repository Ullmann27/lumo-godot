extends SceneTree
## Kart-Einstieg: Intro über dem Menü, Einfahrt mit Drift, Logo, Überspringen,
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
	var shots := [0.55, 1.85, 2.75, 3.9]
	var positions: Array[float] = []
	var headings: Array[float] = []
	for index in range(shots.size()):
		intro._update(shots[index])
		positions.append(intro.kart.position.x)
		headings.append(intro.kart.rotation.y)
		if render:
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			image.resize(960, 540)
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(image, Rect2i(0, 0, 960, 540), Vector2i((index % 2) * 960, (index / 2) * 540))
	assert(positions[0] < -8.0 and positions[1] > positions[0] and absf(positions[3]) < 0.01, "Lumo fährt von links auf die Bühne")
	assert(headings[1] > headings[0] + 0.5, "Lumo driftet quer ein")
	assert(absf(headings[3] - intro.FINAL_HEADING) < 0.01, "Lumo kommt zur Kamera gedreht zum Stehen")
	assert(intro.logo.modulate.a > 0.99 and intro.lumo_label.text == "LUMO", "Logo steht")
	assert(intro.kart.celebration_place == 1, "Lumo freut sich nach dem Einparken")
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
	print("[KartIntro] PASS: Einfahrt, Drift, Logo, Freude, Tippen/Zurück überspringen, Menü danach bedienbar, kein Intro in Prüfungen")
	quit(0)
