extends SceneTree
## Streckenvorschau: friert den Countdown ein, fliegt über die Strecke, gleitet in
## die Verfolgerkamera, lässt sich überspringen und entfällt bei reduzierter Bewegung.
## Mit Anzeige (xvfb) entsteht zusätzlich ein Kontaktbogen echter Engine-Bilder.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_preview_regression.gd -- [out.png]

var game


func _initialize() -> void:
	call_deferred("_run")


func _new_race(track: String) -> void:
	if is_instance_valid(game):
		game.abandoned = true
		game.free()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"})
	await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else ""
	var render: bool = DisplayServer.get_name() != "headless" and not out_path.is_empty()
	root.size = Vector2i(960, 540)
	await _new_race("sonnenhafen")
	assert(game.preview_left == game.PREVIEW_SECONDS, "Rennen beginnt mit der Streckenvorschau")
	var countdown_before: float = game.countdown
	var start_camera: Vector3 = game.camera.global_position
	assert(game.grid_to.size() == 6 and game.grid_from.size() == 6, "Startaufstellung für Lumo und fünf Rivalen")
	var grid_player: Vector3 = game.grid_to[0].origin
	assert(game.player.position.distance_to(grid_player) > 8.0, "Karts warten zunächst hinter der Startlinie")
	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	var shots := [0.12, 0.45, 0.78, 0.97]
	var shot_index: int = 0
	var steps: int = int(game.PREVIEW_SECONDS * 60.0) + 1
	var moved: float = 0.0
	for i in range(steps):
		game._physics_process(1.0 / 60.0)
		moved = maxf(moved, game.camera.global_position.distance_to(start_camera))
		var t: float = float(i + 1) / float(steps)
		if render and shot_index < shots.size() and t >= shots[shot_index]:
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((shot_index % 2) * 960, (shot_index / 2) * 540))
			shot_index += 1
		if i == int((game.PREVIEW_SECONDS - game.GRID_ROLL_SECONDS * 0.5) * 60.0):
			var gap: float = game.player.position.distance_to(grid_player)
			assert(gap > 0.05 and gap < game.GRID_ROLL_DISTANCE - 0.5, "Karts rollen sichtbar auf ihre Plätze")
		if i == 60:
			assert(not game.start_lights.visible, "Keine Startampel während der Vorschau")
			assert(game.countdown == countdown_before, "Countdown läuft während der Vorschau nicht")
			assert(not game.racing, "Keine Steuerung während der Vorschau")
			assert(game.preview_card.visible and game.preview_name.text == "Sonnenhafen", "Titelkarte zeigt den Streckennamen")
	assert(moved > 20.0, "Kamera fliegt sichtbar über die Strecke")
	assert(game.preview_left == 0.0 and not game.preview_card.visible, "Vorschau endet von selbst")
	for k in range(game.grid_to.size()):
		var kart: Node3D = game.player if k == 0 else game.opponents[k - 1]
		assert(kart.transform.origin.distance_to(game.grid_to[k].origin) < 0.001, "Jedes Kart steht exakt auf seinem Startplatz")
	var chase: Vector3 = game.camera.global_position
	game._update_camera(1.0, true)
	assert(game.camera.global_position.distance_to(chase) < 0.05, "Endet exakt in der Verfolgerkamera")
	game._physics_process(1.0 / 60.0)
	assert(game.countdown < countdown_before, "Danach läuft der Countdown")
	assert(not game.racing, "Gas gibt es erst nach dem Countdown")
	# Startampel: drei Rot im Takt des Countdowns, bei LOS alle grün.
	var lamp_shots: Array[Image] = []
	var seen_red: Array[int] = []
	var seen_numbers: Array[String] = []
	while game.countdown > 0.0:
		game._physics_process(1.0 / 60.0)
		if game.countdown > 0.0:
			if not seen_numbers.has(game.countdown_label.text):
				seen_numbers.append(game.countdown_label.text)
			var lit: int = 0
			for lamp in game.start_lamps:
				var style: StyleBoxFlat = lamp.get_theme_stylebox("panel")
				if style.shadow_size > 0:
					lit += 1
			if not seen_red.has(lit):
				seen_red.append(lit)
				if render and lit > 0:
					await RenderingServer.frame_post_draw
					lamp_shots.append(root.get_texture().get_image())
		assert(game.start_lights.visible, "Startampel sichtbar während des Countdowns")
	assert(seen_red.has(1) and seen_red.has(2) and seen_red.has(3), "Rote Lampen leuchten nacheinander auf")
	assert(seen_numbers.has("3") and seen_numbers.has("2") and seen_numbers.has("1"), "Große Countdown-Zahl an der Ampel")
	game._physics_process(1.0 / 60.0)
	assert(game.racing and game.start_lights.visible, "Bei LOS bleibt die Ampel kurz grün stehen")
	var green: StyleBoxFlat = game.start_lamps[0].get_theme_stylebox("panel")
	assert(green.bg_color.g > green.bg_color.r, "LOS = grün")
	for frame in range(int(game.START_GREEN_SECONDS * 60.0) + 2):
		game._physics_process(1.0 / 60.0)
	assert(not game.start_lights.visible, "Danach verschwindet die Ampel")
	if render and lamp_shots.size() >= 1:
		var lights_sheet := Image.create(1920, 540, false, Image.FORMAT_RGBA8)
		for index in range(mini(2, lamp_shots.size())):
			var shot: Image = lamp_shots[lamp_shots.size() - 1 - index]
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(960, 540)
			lights_sheet.blit_rect(shot, Rect2i(0, 0, 960, 540), Vector2i((1 - index) * 960, 0))
		assert(lights_sheet.save_png(out_path.get_base_dir() + "/startampel.png") == OK)

	# Pause während der Vorschau: Karts sofort auf ihre Plätze.
	await _new_race("bergwelt")
	game._physics_process(1.0 / 60.0)
	game._pause()
	assert(game.paused and game.preview_left == 0.0)
	assert(game.player.transform.origin.distance_to(game.grid_to[0].origin) < 0.001, "Pause speichert keine halb gerollten Karts")

	# Überspringen per Tippen.
	await _new_race("zauberwald")
	game._physics_process(1.0 / 60.0)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	game._unhandled_input(tap)
	assert(game.preview_left == 0.0, "Tippen überspringt die Vorschau")
	game._physics_process(1.0 / 60.0)
	assert(game.countdown < 3.5, "Countdown beginnt sofort nach dem Überspringen")

	# Reduzierte Bewegung: keine Kamerafahrt.
	await _new_race("bergwelt")
	game.reduced_motion = true
	game._begin_race()
	assert(game.preview_left == 0.0, "Reduzierte Bewegung startet ohne Kamerafahrt")

	# Von außen beendeter Countdown (Fortsetzen) beendet auch die Vorschau.
	await _new_race("holo_city")
	game.countdown = 0
	game._physics_process(1.0 / 60.0)
	assert(game.preview_left == 0.0)

	if render:
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		assert(sheet.save_png(out_path) == OK)
	print("[KartPreview] PASS: 5-s-Kamerafahrt mit Titel, einrollende Startaufstellung, Startampel 3-2-1-grün, eingefrorener Countdown, weicher Übergang, Überspringen, Pause, reduzierte Bewegung, Fortsetzen")
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0)
