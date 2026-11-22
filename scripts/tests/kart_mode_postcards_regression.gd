extends SceneTree
## Touch the pictured modes over the live showroom, then check the real game owner.
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var out := OS.get_environment("LUMO_MENU_PHOTOS")
var picker_only := OS.get_cmdline_user_args().has("--picker-only")
var failures: Array[String] = []
var game


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("[KartModePostcards] ", label)


func frames(count := 4) -> void:
	for i in range(count):
		await process_frame


func tap(button: Control) -> void:
	check(button.is_visible_in_tree(), "visible " + str(button.name))
	var at := button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 1
		e.position = at
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	await frames()


func shot(id: String) -> void:
	if out.is_empty():
		return
	RenderingServer.render_loop_enabled = true
	await frames(5)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(id + ".png")) == OK, "photo " + id)
	RenderingServer.render_loop_enabled = false


func return_home() -> void:
	game._leave_race_for_menu()
	await frames()
	game._show_reference_landing(true)
	await frames()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("A renderer is required for the touch and showroom test.")
		quit(1)
		return
	RenderingServer.render_loop_enabled = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	var router = root.get_node("SceneRouter")
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	router.launch_options = {"childKey": "kart_card_ui", "kartEntryPrepared": true}
	router.goto("kart")
	await frames(12)
	game = current_scene
	game.set_physics_process(false)
	game.lightweight = true
	game.garage.setup.track = "zauberwald"
	game._show_reference_landing(true)
	for size in [Vector2i(1812, 2176), Vector2i(2176,1812), Vector2i(1080,2520), Vector2i(2400,1080)]:
		root.size = size
		await frames(5)
		var hub = game.reference_landing
		var ids := ["race", "cup", "parcours", "event"]
		for id in ids:
			var card = hub._mode_tiles[id]
			check(card.art != null, id + " course photograph")
			check(card.size.x / hub._layout_scale >= 64 and card.size.y / hub._layout_scale >= 64, id + " child touch size")
		if not picker_only:
			await shot("nachher-" + ("fold" if size.x == 1812 else "quer" if size.x == 2176 else "phone-quer" if size.x == 2400 else "cover"))
		if size.x == 2400 and not picker_only:
			for control in [hub._navigation.get_node("Open_garage"), hub._feature_tiles.garage]:
				var rect: Rect2 = control.get_global_rect()
				var pixels := Vector2(root.size) / root.get_visible_rect().size
				print("[KartModePostcards] garage ", control.name, " px ", rect.get_center() * pixels, " relative ", rect.get_center() / root.get_visible_rect().size)
		await tap(hub._navigation.get_node("Dock_race"))
		check(hub._overlay.visible and hub._race_kinds.visible, "actual mode picker opened")
		await tap(hub._race_kind_buttons.time_trial)
		check(game.garage.setup.mode == "time_trial" and hub._kind_description.text.contains("Geist"), "time trial details describe selected mode")
		var clip: Rect2 = hub._race_kinds.get_parent().get_parent().get_global_rect().grow(1)
		for kind in hub._race_kind_buttons.values():
			check(kind.text.contains("\n") and clip.encloses(kind.get_global_rect()), "mode goal and entire touch target visible " + str(kind.name) + " " + str(size))
		await shot("spielarten-%s" % size.x)
		await tap(hub._overlay.find_child("CloseOverlay", true, false))
		check(not hub._overlay.visible, "return from mode selection")
		if size.x == 2400 and not picker_only:
			await tap(hub._navigation.get_node("Open_garage"))
			var bay = game.garage.parts_bay
			check(game.garage.step == 2 and bay.open_button.is_visible_in_tree(), "Garage opens fitted kart")
			var switch_at: Vector2 = bay.open_button.get_global_rect().get_center()
			print("[KartModePostcards] Teile wechseln px ", switch_at * Vector2(root.size) / root.get_visible_rect().size,
				" relative ", switch_at / root.get_visible_rect().size)
			await shot("garage-phone-quer")
			await tap(bay.open_button)
			check(bay.is_open(), "Teile wechseln opens parts drawer")
			await shot("teile-phone-quer")
			bay.handle_back()
			game._show_reference_landing(true)
			await frames()
	if picker_only:
		await finish(game)
		return
	root.size = Vector2i(1080,720)
	root.get_node("HostBridge")._options["displayDensity"] = 1.0
	await frames()
	var hub = game.reference_landing
	await tap(hub._mode_tiles.race)
	check(not game.menu_active and game.mode == "race" and game.track_id == "zauberwald" and game.opponents.size() == 5, "race starts selected course with five rivals")
	await return_home()
	hub = game.reference_landing
	await tap(hub._mode_tiles.cup)
	check(hub._overlay.visible and hub._overlay_list.has_node("CupTracks"), "tournament shows actual cup courses")
	await tap(hub._live_start)
	check(not game.menu_active and game.mode == "cup", "tournament starts real cup")
	await return_home()
	hub = game.reference_landing
	var weekly: String = hub._weekly_track
	await tap(hub._mode_tiles.event)
	check(not game.menu_active and game.track_id == weekly and game.mode == "race", "weekly event starts scheduled track")
	await return_home()
	hub = game.reference_landing
	await tap(hub._mode_tiles.parcours)
	await frames(8)
	var parcours = current_scene
	check(parcours.has_method("start_world") and parcours.hud.choice.visible, "adventure opens playable world picker")
	await tap(parcours.hud.choice.find_child("World_wolkenwerkstatt", true, false))
	check(parcours.playing and parcours.race != null, "world card starts actual adventure race")
	await finish(parcours)


func finish(scene: Node) -> void:
	check(await TEARDOWN.release_scene(self, scene, "[KartModePostcards]"), "teardown")
	root.get_node("GameSoundscape").release_audio()
	var end := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < end:
		await process_frame
	print("[KartModePostcards] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
