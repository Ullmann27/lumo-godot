extends SceneTree
## Bildbeweis für das Kart-Hauptmenü mit dem gerenderten UI-Kit: vier Flächen, dazu die
## Overlays Rennarten und Sternenpfad, und die Zeichenaufrufe des Menü-Frames.
## Aufruf unter xvfb mit echtem Renderer; Ausgabe per `-- --out=<ordner>`.
## Nur Aufnahme; keine Spielstände werden geschrieben.
const SURFACES := [
	["phone_portrait", Vector2i(720, 1600), 2.0],
	["fold7_inner", Vector2i(1968, 2184), 2.625],
	["fold7_cover", Vector2i(1080, 2520), 2.625],
	["phone_landscape", Vector2i(1600, 720), 2.0],
	["tablet_landscape", Vector2i(1920, 1200), 1.5],
]
var output := "user://kart_menu_ui3d"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.substr(6)
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for i in range(frames):
		await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = output.path_join(file)
	image.save_png(path)
	print("[KartMenuUi3dEvidence] saved ", path, " ", image.get_size())


func _draw_calls(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var total := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	var canvas := RenderingServer.viewport_get_render_info(
		root.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	var objects := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
	)
	print(
		(
			"[KartMenuUi3dEvidence] draw_calls %s total=%d canvas_root=%d objects=%d"
			% [tag, total, canvas, objects]
		)
	)


## Fokusring und gedrückter Zustand, damit beide im Bild geprüft werden können.
func _capture_states(hub: Control) -> void:
	var pressed: Array[Button] = [hub._mode_tiles["race"], hub._feature_tiles["garage"], hub._back]
	for tile in pressed:
		tile.toggle_mode = true
		tile.set_pressed_no_signal(true)
		tile.queue_redraw()
	hub._mode_tiles["cup"].grab_focus()
	await _settle(4)
	await _save("states_pressed_focus_hero.png")
	hub._navigation.get_node("Open_garage").grab_focus()
	await _settle(4)
	await _save("states_focus_nav.png")
	for tile in pressed:
		tile.set_pressed_no_signal(false)
		tile.toggle_mode = false
		tile.queue_redraw()
	hub._navigation.get_node("Open_garage").release_focus()
	await _settle(2)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[KartMenuUi3dEvidence] SKIP: braucht einen echten Renderer (xvfb)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(10)
	for entry in SURFACES:
		var host: Node = root.get_node_or_null("HostBridge")
		if host != null and "_options" in host:
			host._options["displayDensity"] = float(entry[2])
		root.size = entry[1]
		await _settle(6)
		game.reduced_motion = true
		game._show_reference_landing()
		await _settle(30)
		await _draw_calls(str(entry[0]))
		await _save("menu_%s.png" % entry[0])
		var hub: Control = game.reference_landing
		if str(entry[0]) == "phone_portrait":
			await _capture_states(hub)
		for kind in ["race", "season", "rewards"]:
			hub._open_overlay(kind)
			await _settle(8)
			await _save("overlay_%s_%s.png" % [kind, entry[0]])
			hub._close_overlay()
		await _settle(4)
	game.queue_free()
	await _settle(4)
	print("[KartMenuUi3dEvidence] PASS")
	quit(0)
