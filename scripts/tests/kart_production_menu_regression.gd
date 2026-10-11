extends SceneTree
## Actual production menu, dp/density, scroll accessibility and real rig.
## Explicit desktop surface/density fixtures; NOT a physical Fold device.
var game
var output := "/tmp/lumo-kart-production-menu"
var checks := 0
var failures := 0
var measurements: Array = []
var first_case := 0
var only_case := -1
var motion_output := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	for arg in args:
		if arg.begins_with("--first-case="):
			first_case = int(arg.trim_prefix("--first-case="))
		if arg.begins_with("--only-case="):
			only_case = int(arg.trim_prefix("--only-case="))
		if arg.begins_with("--motion-output="):
			motion_output = arg.trim_prefix("--motion-output=")
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[KartProductionMenu] " + label)


func _settle(frames := 8) -> void:
	for frame in range(frames):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _dp(control: Control, density: float) -> Vector2:
	return control.size * Vector2(root.size) / root.get_visible_rect().size / density


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	seed(1923)
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host = root.get_node("HostBridge")
	host._options = {"soundEnabled": false, "reduceAnimations": true}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	var menu = game.garage
	menu.stars = 48 # Isolated comparison fixture, never a real child balance.
	_check(is_instance_valid(menu.preview_kart.lumo_animation), "Real menu factory attaches the existing rig")
	_check(not menu.preview_kart.driver.visible, "Menu does not draw two Lumos")
	_check(menu.preview_kart.lumo_animation.actor.skeleton.get_bone_count() == 65, "Existing 65-bone skeleton")
	menu.reduced_motion = true
	menu.preview_kart.reduced_motion = true
	menu.preview_kart.lumo_animation.clear_celebration()
	menu.set_process(false)
	var matrix := [
		[Vector2i(360, 800), 1.0],
		[Vector2i(640, 360), 1.0],
		[Vector2i(1280, 720), 1.0],
		[Vector2i(1200, 896), 1.0],
		[Vector2i(2176, 1812), 2.25],
		[Vector2i(2316, 904), 2.5],
		[Vector2i(640, 320), 1.0],
		[Vector2i(1280, 720), 1.0, Rect2(16, 32, 16, 48)],
		[Vector2i(640, 320), 1.0, Rect2(16, 32, 16, 48)],
		[Vector2i(1920, 1080), 1.875, Rect2(0, 63, 72, 0)],
		[Vector2i(1920, 1080), 2.75, Rect2(0, 63, 72, 0)],
	]
	for case in range(first_case, matrix.size()):
		if only_case >= 0 and case != only_case:
			continue
		var sample: Array = matrix[case]
		var pixels: Vector2i = sample[0]
		var density: float = sample[1]
		host._options["displayDensity"] = density
		root.size = pixels
		await _settle(2)
		game._apply_safe_area(sample[2] if sample.size() > 2 else Rect2(), Vector2(pixels))
		await _settle(2)
		menu.step = 0
		menu._refresh()
		await _settle()
		menu._apply_responsive_layout()
		menu.preview_pivot.rotation.y = -0.25
		menu.preview_kart._process(1.0 / 30.0)
		await _settle(12)
		_check(is_equal_approx(root.get_node("MobileRuntime").get_ui_density(), density), "Density uses actual supplied scale")
		var viewport: Rect2 = game.safe_ui.get_global_rect()
		for action in [menu.back_button, menu.next_button] + menu.step_buttons:
			_check(viewport.encloses(action.get_global_rect()),
				"Main action inside " + str(pixels) + " " + action.name + " " + str(action.get_global_rect()))
			_check(_dp(action, density).x >= 47.8 and _dp(action, density).y >= 47.8,
				"Main action at least 48dp: " + action.name + " " + str(pixels))
		_check(not menu.quick_start_button.visible, "Exactly one main gold action")
		_check(menu.progress_icon.visible == menu.progress_label.visible,
			"Reward icon never appears as a clipped unlabelled star")
		_check(viewport.encloses(menu.brand_wordmark.get_global_rect()), "Whole two-line wordmark stays inside")
		_check(menu.brand_wordmark.get_script().resource_path == "res://scripts/games/kart_wordmark.gd",
			"Reference wordmark uses native sharp lettering and flags, not emoji text")
		var cards: GridContainer = menu.choices.get_child(0)
		_check(cards.get_child_count() == 5, "Five real modes")
		var scroll: ScrollContainer = menu.choices.get_parent()
		scroll.scroll_vertical = 0
		await _settle()
		var first_visible := scroll.get_global_rect().encloses(cards.get_child(0).get_global_rect())
		_check(first_visible, "First real mode is fully visible: " + str(pixels))
		var ui_scale: float = root.get_visible_rect().size.x / (float(pixels.x) / density)
		var selected_count := 0
		for card in cards.get_children():
			if card.selection_mark.visible:
				selected_count += 1
			_check(_dp(card, density).y >= 47.8, "Selectable mode is never a 28px substitute")
			_check(float(card.title_label.get_theme_font_size("font_size")) / ui_scale >= 15.5,
				"Readable mode type at actual density")
			var title_size: int = card.title_label.get_theme_font_size("font_size")
			var title_font: Font = card.title_label.get_theme_font("font")
			var full_width: float = title_font.get_string_size(
				card.title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
			_check(card.title_label.size.x + 0.75 >= full_width,
				"Complete mode name, not an ellipsis: " + card.title + " " + str(pixels)
				+ " density=" + str(density) + " available=" + str(card.title_label.size.x)
				+ " required=" + str(full_width))
			scroll.ensure_control_visible(card)
			await _settle(2)
			# ScrollContainer uses integer offsets; at a stretched viewport the
			# final row can differ by a fraction of one physical raster pixel.
			var rounding: float = maxf(1.0, maxf(
				root.get_visible_rect().size.x / float(pixels.x),
				root.get_visible_rect().size.y / float(pixels.y)
			) * 0.6)
			var reachable: bool = scroll.get_global_rect().grow(rounding).encloses(card.get_global_rect())
			if not reachable:
				print("[KartProductionMenu] bounds=", scroll.get_global_rect(), " card=", card.get_global_rect(),
					" scroll=", scroll.scroll_vertical, " max=", scroll.get_v_scroll_bar().max_value,
					" page=", scroll.get_v_scroll_bar().page)
			_check(reachable,
				"Every mode is reachable without clipping: " + card.title + " " + str(pixels))
		_check(selected_count == 1 and cards.get_child(0).selection_mark.visible,
			"Exactly the real selected mode has a check mark")
		if float(pixels.x) / density >= 760 and float(pixels.y) / density >= 600:
			_check(scroll.get_global_rect().grow(1).encloses(cards.get_global_rect()),
				"All five reference cards fit the large/Fold viewport without scrolling: "
				+ str(scroll.get_global_rect()) + " modes=" + str(cards.get_global_rect()))
		scroll.scroll_vertical = 0
		await _settle()
		var file := "menu-%dx%d-density-%.2f%s.png" % [
			pixels.x, pixels.y, density, "-safe-area" if sample.size() > 2 else ""]
		if DisplayServer.get_name() != "headless":
			_check(root.get_texture().get_image().save_png(output.path_join(file)) == OK, "Actual render saved")
		measurements.append({
			"surface_px": [pixels.x, pixels.y], "density": density,
			"logical_dp": [float(pixels.x) / density, float(pixels.y) / density],
			"next_button_dp": [_dp(menu.next_button, density).x, _dp(menu.next_button, density).y],
			"mode_button_dp": [_dp(cards.get_child(0), density).x, _dp(cards.get_child(0), density).y],
			"scroll_content": scroll.get_v_scroll_bar().max_value,
			"scroll_page": scroll.get_v_scroll_bar().page, "image": file,
			"test_stars": 48, "seed": 1923,
			"android_inset_fixture": sample.size() > 2,
			"physical_android_device": false,
		})
		print("[KartProductionMenu] CASE ", pixels, " density=", density, " checks=", checks, " failures=", failures)
		FileAccess.open(output.path_join("menu-progress.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"checks": checks, "failures": failures, "surfaces": measurements}, "\t"))
	host._options["displayDensity"] = 1.0
	root.size = Vector2i(1280, 720)
	await _settle(2)
	game._apply_safe_area(Rect2(), Vector2(root.size))
	await _settle(2)
	menu._apply_responsive_layout()
	menu.reduced_motion = false
	menu.preview_kart.reduced_motion = false
	menu.preview_kart._process(1.0 / 30.0)
	menu.preview_kart.lumo_animation.play_menu_behavior("greeting_wave")
	_check(menu.preview_kart.lumo_animation.actor.current_behavior == "greeting_wave", "Real greeting clip, not pivot-only motion")
	if not motion_output.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(motion_output)
		menu.preview_kart.set_process(false)
		for frame in range(28):
			menu.preview_kart._process(0.10)
			await _settle(1)
			_check(root.get_texture().get_image().save_png(
				motion_output.path_join("wave-%03d.png" % frame)) == OK, "Actual animated menu frame")
		_check(menu.preview_kart.lumo_animation.actor.current_behavior == "kart_seated",
			"Greeting returns to seated Kart pose without repeating")
		FileAccess.open(motion_output.path_join("provenance.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"real_godot_frames": true, "frame_count": 28,
				"sample_step_seconds": 0.10, "wall_clock_fps_benchmark": false,
				"animation_clip": "greeting_wave", "source_glb_unchanged": true,
				"physical_android_device": false}, "\t"))
		menu.preview_kart.set_process(true)
	menu.preview_kart._process(0.10)
	var wave_time: float = menu.preview_kart.lumo_animation.actor.player.current_animation_position
	menu.reduced_motion = true
	menu.preview_kart.reduced_motion = true
	menu.preview_kart._process(0.10)
	_check(not menu.preview_kart.lumo_animation.play_menu_behavior("greeting_wave"), "Quiet mode rejects recurring gesture")
	menu._select("mode", "time_trial")
	await _settle()
	_check(menu.setup.mode == "time_trial", "Actual mode selection survives the visual change")
	menu._next()
	_check(menu.step == 1, "Actual Weiter enters the existing setup, no competing menu")
	game.abandoned = true
	game.queue_free()
	await _settle()
	await create_timer(0.5).timeout
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans_after != orphan_baseline:
		Node.print_orphan_nodes()
	_check(orphans_after == orphan_baseline, "Real menu and rig return orphan nodes to baseline")
	var report := {"checks": checks, "failures": failures, "surfaces": measurements,
		"wave_sample_seconds": wave_time, "physical_android_device": false,
		"orphan_nodes_before": orphan_baseline, "orphan_nodes_after": orphans_after}
	FileAccess.open(output.path_join("menu-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[KartProductionMenu] ", JSON.stringify({"checks": checks, "failures": failures}))
	if failures == 0:
		print("[KartProductionMenu] PASS real factory, ", measurements.size(),
			" density/layout cases, 48dp and accessible modes")
	quit(0 if failures == 0 else 1)
