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
		if i == 60:
			assert(game.countdown == countdown_before, "Countdown läuft während der Vorschau nicht")
			assert(not game.racing, "Keine Steuerung während der Vorschau")
			assert(str(game.message.text).contains("Sonnenhafen"), "Streckenname erscheint")
	assert(moved > 20.0, "Kamera fliegt sichtbar über die Strecke")
	assert(game.preview_left == 0.0 and not str(game.message.text).contains("Überspringen"), "Vorschau endet von selbst")
	var chase: Vector3 = game.camera.global_position
	game._update_camera(1.0, true)
	assert(game.camera.global_position.distance_to(chase) < 0.05, "Endet exakt in der Verfolgerkamera")
	game._physics_process(1.0 / 60.0)
	assert(game.countdown < countdown_before, "Danach läuft der Countdown")
	assert(not game.racing, "Gas gibt es erst nach dem Countdown")

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
	print("[KartPreview] PASS: 5-s-Kamerafahrt mit Titel, eingefrorener Countdown, weicher Übergang, Überspringen, reduzierte Bewegung, Fortsetzen")
	game.abandoned = true
	game.queue_free()
	quit(0)
