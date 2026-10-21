extends SceneTree
## Real production owner, real touch input, all five setup pages and settings.
## Desktop GL fixtures are not a physical Android performance measurement.
var game
var output := "res://exports/sol-menu-journey"
var captures: Array[Dictionary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	call_deferred("_run")


func _settle(frames := 2) -> void:
	# Input and layout need processed engine frames. Expensive synchronized
	# llvmpipe readbacks are reserved for actual screenshots, not each tap.
	for index in range(frames):
		await process_frame


func _tap(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _settle()
	print("[CompleteMenuJourney] TAP ", control.name, " window=", root.size)
	var rect := control.get_global_rect()
	assert(control.is_visible_in_tree(), "Journey tried an invisible control")
	print("[CompleteMenuJourney] BOUNDS ", rect, " viewport=", root.get_visible_rect())
	assert(root.get_visible_rect().grow(1).encloses(rect), "Control must fit before a real tap: " + str(control.name))
	var scale: Vector2 = Vector2(root.size) / root.get_visible_rect().size
	assert(rect.size.y * scale.y >= 47.9, "Touch target is smaller than 48dp: " + str(control.name))
	assert(rect.size.x * scale.x >= 47.9, "Touch target is narrower than 48dp: " + str(control.name))
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = rect.get_center() * scale
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var name := "%s-%dx%d.png" % [label, root.size.x, root.size.y]
	assert(root.get_texture().get_image().save_png(output.path_join(name)) == OK)
	captures.append({"image": name, "size": [root.size.x, root.size.y],
		"step": game.garage.step, "setup": game.garage.setup.duplicate(true),
		"renderer": RenderingServer.get_current_rendering_method(),
		"engine": Engine.get_version_info().string, "physical_android": false})


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.lightweight = true
	root.add_child(game)
	game.set_physics_process(false)
	await _settle(6)
	for dimensions in [Vector2i(640, 360), Vector2i(320, 740), Vector2i(840, 960), Vector2i(1280, 720)]:
		root.size = dimensions
		await _settle(6)
		print("[CompleteMenuJourney] SIZE requested=", dimensions, " actual=", root.size)
		game.reduced_motion = true
		game.garage.reduced_motion = true
		game.garage.stars = 60 # Explicit render/unlock fixture, no child progress write.
		game.garage._refresh()
		game._show_reference_landing()
		await _settle(6)
		print("[CompleteMenuJourney] LANDING inherited_scale=",
			game.reference_landing.get_global_transform().get_scale(),
			" physical_window=", game.reference_landing.get_window().size,
			" canvas=", root.get_visible_rect().size)
		assert(not game.garage.visible)
		assert(game.garage.preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
		assert(root.get_visible_rect().grow(1).encloses(
			game.reference_landing.find_child("LiveQuickStart", true, false).get_global_rect()))
		await _tap(game.reference_landing.find_child("Landing_time_trial", true, false))
		assert(game.garage.setup.mode == "time_trial")
		await _tap(game.reference_landing.find_child("Landing_settings", true, false))
		assert(game.menu_settings_open and game.modal.visible)
		assert(game.menu_active and not is_instance_valid(game.player))
		var was_muted: bool = game.muted
		await _tap(game.modal_column.get_node("AudioToggle"))
		assert(game.muted != was_muted, "Menu audio control must change real preferences")
		var old_graphics: String = game.graphics_profile
		await _tap(game.modal_column.get_node("GraphicsProfileToggle"))
		assert(game.graphics_profile != old_graphics and game.menu_active)
		assert(not is_instance_valid(game.player), "Menu preferences must not build or mutate a race")
		var old_gas: bool = game.auto_gas
		await _tap(game.modal_column.get_node("GasModeToggle"))
		assert(game.auto_gas != old_gas)
		var preferences := ConfigFile.new()
		assert(preferences.load(game.PREFERENCES) == OK)
		assert(preferences.get_value("race", "auto_gas") == game.auto_gas)
		assert(preferences.get_value("race", "muted") == game.muted)
		await _capture("settings")
		await _tap(game.menu_settings_navigation.get_node("CloseKartSettings"))
		assert(not game.modal.visible and not game.menu_settings_open)
		assert(game.reference_landing.current_mode == "time_trial", "Settings must retain the chosen mode")
		await _tap(game.reference_landing.find_child("Landing_garage", true, false))
		assert(game.garage.step == 2 and not game.reference_landing.visible)
		for step in range(5):
			await _tap(game.garage.step_buttons[step])
			assert(game.garage.step == step)
			if step == 0:
				for choice in game.garage.choices.get_child(0).get_children():
					if choice.title == "Einzelrennen":
						await _tap(choice)
						break
				assert(game.garage.setup.mode == "race")
			elif step == 1:
				await _tap(game.garage.choices.get_child(1))
				assert(game.garage.setup.driver == "rabbit")
			elif step == 2:
				await _tap(game.garage.choices.get_child(0).get_node("KartCard_gecko_velo"))
				assert(game.garage.setup.kart == "gecko_velo")
			elif step == 3:
				await _tap(game.garage.choices.get_child(0))
				assert(game.garage.setup.track == "sonnenhafen")
				assert(is_instance_valid(game.garage.preview_world))
			else:
				await _tap(game.garage.choices.get_child(0))
				assert(game.garage.setup.difficulty == "gemuetlich")
			await _capture("setup-%d" % (step + 1))
			assert(root.get_visible_rect().grow(1).encloses(game.garage.next_button.get_global_rect()))
		var selected: Dictionary = game.garage.setup.duplicate(true)
		for step in range(4, -1, -1):
			assert(game.garage.step == step)
			await _tap(game.garage.back_button)
		assert(game.reference_landing.visible and game.reference_landing.current_mode == "race")
		assert(game.garage.setup == selected, "Returning to the main menu must preserve every setup choice")
		if dimensions == Vector2i(1280, 720):
			await _tap(game.reference_landing.find_child("LiveQuickStart", true, false))
			assert(not game.menu_active and game.mode == "race", "START must preserve the configured mode")
			assert(game.selected_kart == selected.kart and is_instance_valid(game.player))
			assert(game.opponents.size() == 5)
	game.queue_free()
	await _settle()
	var report := FileAccess.open(output.path_join("journey.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(captures, "  "))
	report.close()
	print("[CompleteMenuJourney] PASS: five real setup pages, preferences, 48dp touches, main-menu return and configured race")
	quit(0)
