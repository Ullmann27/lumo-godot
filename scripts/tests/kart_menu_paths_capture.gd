extends SceneTree
## Bildbeleg für die Menüführung von LUMO Kart: geht vom bunten Hauptmenü aus jeden
## erreichbaren Weg (Rennarten, Belohnungen, Saison, Fahrer, Garage, Werkstatt,
## Strecken, Tempo & Gegner, Einstellungen) über die echten Signale des Menüs und
## speichert je Ansicht ein Bild. Dieselben Ansichten dienen als Vorher/Nachher.
## Echter Renderer (xvfb), kein Android-FPS-Test.
## Aufruf: godot --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_menu_paths_capture.gd -- --out=<ordner>
##   [--sizes=1812x2176,2176x1812,1080x2340] [--only=hub,strecken] [--density=2.625]
## --density meldet dem Spiel die Gerätedichte wie die App am Handy (Fold7 ≈ 2,625);
## ohne sie rechnet das Menü mit 1 dp = 1 px und alles erscheint winzig.
## „pause“ startet zuletzt ein echtes Rennen und nimmt das Pausenfenster auf.
var game
var density: float = 0.0
var out_dir: String = "user://kart_menu_paths"
var sizes: Array[Vector2i] = [Vector2i(1812, 2176), Vector2i(2176, 1812), Vector2i(1080, 2340)]
var only: PackedStringArray = PackedStringArray()
var written: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--density="):
			density = float(arg.trim_prefix("--density="))
		elif arg.begins_with("--sizes="):
			sizes.clear()
			for part in arg.trim_prefix("--sizes=").split(",", false):
				var pair := part.split("x")
				if pair.size() == 2:
					sizes.append(Vector2i(int(pair[0]), int(pair[1])))
	call_deferred("_run")


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _wanted(label: String) -> bool:
	return only.is_empty() or only.has(label)


func _shot(label: String) -> void:
	if not _wanted(label):
		return
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out_dir.path_join("%s_%dx%d.png" % [label, root.size.x, root.size.y])
	if image.save_png(path) == OK:
		written += 1
		print("[KartMenuPaths] ", path)
	else:
		push_error("[KartMenuPaths] Bild nicht gespeichert: " + path)


func _landing() -> void:
	game._show_reference_landing(true)
	await _frames(12)


func _step(target: String, label: String) -> void:
	if not _wanted(label):
		return
	await _landing()
	game.reference_landing.mode_selected.emit(target)
	await _frames(12)
	await _shot(label)


func _overlay(kind: String, label: String) -> void:
	if not _wanted(label):
		return
	await _landing()
	game.reference_landing._open_overlay(kind)
	await _shot(label)
	game.reference_landing._close_overlay()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[KartMenuPaths] braucht einen echten Renderer (xvfb)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	if density > 0.0:
		root.get_node("HostBridge")._options["displayDensity"] = density
	root.size = sizes[0]
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(30)
	for window in sizes:
		root.size = window
		await _frames(12)
		await _landing()
		await _shot("hub")
		await _overlay("race", "rennarten")
		await _overlay("rewards", "belohnungen")
		await _overlay("season", "saison")
		await _overlay("cup", "turniere")
		await _step("modes", "rennen")
		await _step("driver", "fahrer")
		await _step("garage", "garage")
		if _wanted("werkstatt"):
			await _landing()
			game.reference_landing.mode_selected.emit("garage")
			await _frames(12)
			game.garage._open_workshop()
			await _shot("werkstatt")
			if game.garage.has_method("_close_workshop"):
				game.garage._close_workshop()
		await _step("world", "strecken")
		await _step("difficulty", "tempo")
		if _wanted("einstellungen"):
			await _landing()
			game.reference_landing.open_settings.emit()
			await _shot("einstellungen")
			if game.has_method("_close_menu_settings"):
				game._close_menu_settings()
	if _wanted("pause"):
		await _landing()
		game._start_selected_race(game.garage.setup.duplicate(true))
		await _frames(90)
		for window in sizes:
			root.size = window
			await _frames(12)
			if not game.paused:
				game._pause()
			await _shot("pause")
	print("[KartMenuPaths] bilder=%d" % written)
	var sound := root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	game.queue_free()
	await _frames(24)
	quit(0 if written > 0 else 1)
