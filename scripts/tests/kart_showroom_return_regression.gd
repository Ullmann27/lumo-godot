extends SceneTree
## Verify the final composited display, including overlays, after the real result button.
## Compare two renders with the vehicle toggled while animation is frozen.
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var failed := false
var game
var out := ""


func _initialize() -> void:
	out = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[ShowroomReturn] A renderer is required.")
		quit(1)
		return
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = true
	game.set_physics_process(false)
	await _frames(3)
	for dimensions in [Vector2i(1812, 2176), Vector2i(2176, 1812)]:
		root.size = dimensions
		var cup: bool = dimensions.x < dimensions.y
		game._start_selected_race({"mode": "cup" if cup else "race", "driver": "fox", "kart": "comet",
			"track": "zauberwald", "difficulty": "gemuetlich"})
		game._end_preview()
		game.countdown = 0
		game.racing = true
		game.elapsed = 90.0
		game._finish(false)
		await _frames(2)
		var result_button: Button
		for action in game.modal_column.find_children("*", "Button", true, false):
			if action.text == ("Neue Fahrt auswählen" if cup else "Zur Streckenwahl"):
				result_button = action
				break
		if result_button == null:
			printerr("[ShowroomReturn] Ergebnisaktion fehlt")
			failed = true
			break
		result_button.pressed.emit()
		await _frames(5)
		if is_instance_valid(game.race_root):
			printerr("[ShowroomReturn] Rennwelt nach dem Ergebnis weiterhin geladen")
			failed = true
		if not is_instance_valid(game.reference_landing) or not game.reference_landing.visible:
			game._show_reference_landing(true)
		await _capture_subject("hauptmenue")
		game._reference_select_mode("garage")
		await _capture_subject("garage")
		if cup:
			# Simulate a lost rendering target after the app resumes. Live nodes and
			# camera still look healthy to structural checks in this failure mode.
			var showroom = game.garage
			showroom.preview_viewport.disable_3d = true
			await RenderingServer.frame_post_draw
			var problem: String = showroom.preview_pixels_problem()
			if problem != "bild_einfarbig" or not showroom.repair_preview(problem):
				printerr("[ShowroomReturn] Leere Oberfläche nicht erkannt: ", problem)
				failed = true
			await _capture_subject("wiederhergestellt")
	game.abandoned = true
	await TEARDOWN.release_scene(self, game, "[ShowroomReturn]")
	print("[ShowroomReturn] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _capture_subject(label: String) -> void:
	await _frames(6)
	var garage = game.garage
	garage.process_mode = Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	if not out.is_empty():
		shown.save_png(out.path_join("%s_%sx%s.png" % [label, root.size.x, root.size.y]))
	var displayed := garage.preview_container.get_global_rect() as Rect2
	var region: Rect2 = garage._visible_stage_region()
	var scale := Vector2(shown.get_size()) / root.get_visible_rect().size
	var corner := (displayed.position + region.position * displayed.size) * scale
	var extent := displayed.size * region.size * scale
	var roi := Rect2i(corner, extent).intersection(Rect2i(Vector2i.ZERO, shown.get_size()))
	shown = shown.get_region(roi)
	var actor = garage.service_station.host if label != "hauptmenue" else garage.preview_kart.lumo_animation
	if not is_instance_valid(actor) or not actor.is_visible_in_tree() or not roi.has_area():
		printerr("[ShowroomReturn] Original-Lumo oder seine Bühne fehlt")
		failed = true
		garage.process_mode = Node.PROCESS_MODE_INHERIT
		return
	actor.hide()
	await RenderingServer.frame_post_draw
	var no_fox: Image = root.get_texture().get_image().get_region(roi)
	actor.show()
	garage.preview_kart.hide()
	await RenderingServer.frame_post_draw
	var no_kart: Image = root.get_texture().get_image().get_region(roi)
	garage.preview_kart.show()
	garage.process_mode = Node.PROCESS_MODE_INHERIT
	var fox_pixels := _changed(shown, no_fox)
	var kart_pixels := _changed(shown, no_kart)
	print("[ShowroomReturn] %s %s: Lumo %d, Kart %d von 19200 Bildpunkten" % [
		label, root.size, fox_pixels, kart_pixels])
	if fox_pixels < 100 or kart_pixels < 360:
		failed = true


func _changed(shown: Image, hidden: Image) -> int:
	shown.resize(160, 120)
	hidden.resize(160, 120)
	var changed := 0
	for y in 120:
		for x in 160:
			var a := shown.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.16:
				changed += 1
	return changed
