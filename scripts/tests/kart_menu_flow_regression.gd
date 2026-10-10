extends SceneTree
## Actual physical-pixel taps complete all five setup steps on desktop and compact Android sizes.
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	# Fonts, nested container minimums and deferred safe-area bounds each
	# propagate after a resize. Two frames were renderer-timing dependent.
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw


func _tap(control: Control) -> void:
	if not game.safe_ui.get_global_rect().encloses(control.get_global_rect()):
		print(
			(
				"[KartMenuFlow] unsafe tap: window=%s step=%s action=%s rect=%s safe=%s margin=%s minimum=%s"
				% [
					root.size,
					game.garage.step,
					control.name,
					control.get_global_rect(),
					game.safe_ui.get_global_rect(),
					game.garage.page_margin.get_global_rect(),
					game.garage.page_margin.get_combined_minimum_size()
				]
			)
		)
	assert(control.is_visible_in_tree())
	assert(
		root.get_visible_rect().encloses(control.get_global_rect()),
		"The complete action must be visible before touch"
	)
	assert(
		game.safe_ui.get_global_rect().encloses(control.get_global_rect()),
		"Touch action must stay inside the safe screen area"
	)
	var position: Vector2 = (
		control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	)
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 3
		touch.position = position
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var kart_scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	for pixels in [Vector2i(1280, 720), Vector2i(800, 480), Vector2i(640, 320)]:
		game = kart_scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.lightweight = true
		await _settle()
		root.size = pixels
		await _settle()
		# Simulate camera/status/navigation insets through the same parent that
		# handles them on Android; the garage must not apply them a second time.
		game._apply_safe_area(Rect2(16, 32, 16, 48), Vector2(pixels))
		game.garage._apply_responsive_layout()
		await _settle()
		assert(game.menu_active)
		var font: Font = game.safe_ui.theme.default_font
		assert(
			font.resource_path == "res://assets/fonts/Nunito-Bold.ttf",
			"HUD uses the exact static Nunito Bold from the app"
		)
		assert(
			(
				game.garage.title_label.get_theme_font("font").resource_path
				== "res://assets/fonts/Nunito-Black.ttf"
			),
			"Menu headings use the app heading face"
		)
		var mode_grid: GridContainer = game.garage.choices.get_child(0)
		assert(mode_grid.get_child_count() == 5, "Five race modes; the learning cup is gone")
		var cup_button: Button = null
		for mode_button in mode_grid.get_children():
			if str(mode_button.title) == "Sternen-Cup":
				cup_button = mode_button
		assert(is_instance_valid(cup_button), "Cup is discoverable independent of visual list order")
		if pixels.y >= 600:
			print("[KartMenuFlow][ReferenceGeometry] pixels=", pixels,
				" safe=", game.safe_ui.get_global_rect(),
				" list=", game.garage.choices.get_parent().get_global_rect(),
				" modes=", mode_grid.get_global_rect())
			for mode_button in mode_grid.get_children():
				assert(
					game.garage.choices.get_parent().get_global_rect().encloses(
						mode_button.get_global_rect()
					),
					"Every mode must fit the actual scroll viewport"
				)
		else:
			assert(
				root.get_visible_rect().encloses(game.garage.preview_container.get_global_rect()),
				"Short landscape keeps the real preview on screen"
			)
			print("[KartMenuFlow][CompactModeGeometry] pixels=", pixels,
				" safe=", game.safe_ui.get_global_rect(),
				" list=", game.garage.choices.get_parent().get_global_rect(),
				" first=", mode_grid.get_child(0).get_global_rect(),
				" second=", mode_grid.get_child(1).get_global_rect(),
				" preview=", game.garage.preview_container.get_global_rect(),
				" header=", game.garage.header_row.get_global_rect())
			assert(
				game.garage.choices.get_parent().get_global_rect().encloses(
					mode_grid.get_child(0).get_global_rect()
				),
				"First full-size choice is touchable; further modes scroll"
			)
		game.garage.choices.get_parent().ensure_control_visible(cup_button)
		await _settle()
		await _tap(cup_button)
		assert(game.garage.setup.mode == "cup")
		await _settle()
		for step in range(5):
			assert(game.garage.step == step)
			if step == 2:
				var kart_grid: GridContainer = game.garage.choices.get_child(0)
				assert(kart_grid.get_child_count() == 14, "All fourteen karts are offered as cards")
				var new_kart: Control = kart_grid.get_node("KartCard_gecko_velo")
				game.garage.choices.get_parent().ensure_control_visible(new_kart)
				await _settle()
				await _tap(new_kart)
				await _settle()
				assert(game.garage.setup.kart == "gecko_velo")
				var inspect: OptionButton = game.garage.view_choice
				assert(inspect.is_visible_in_tree())
				print("[KartMenuFlow][InspectorGeometry] pixels=", pixels,
					" safe=", game.safe_ui.get_global_rect(),
					" inspector=", inspect.get_global_rect(),
					" overlay=", inspect.get_parent().get_global_rect(),
					" preview=", game.garage.preview_container.get_global_rect(),
					" menu=", game.garage.get_global_rect())
				assert(game.safe_ui.get_global_rect().encloses(inspect.get_global_rect()))
				assert(inspect.size.y * root.size.y / root.get_visible_rect().size.y >= 43.99)
				game.garage._choose_preview_view(2)
				await _settle()
				root.get_texture().get_image().save_png(
					(
						"res://exports/holographic-proof/garage-inspection-%dx%d.png"
						% [pixels.x, pixels.y]
					)
				)
			assert(
				(
					(
						game.garage.next_button.get_global_rect().size.y
						* root.size.y
						/ root.get_visible_rect().size.y
					)
					>= 44
				),
				"Compact setup actions retain a large touch area"
			)
			if step == 0:
				DirAccess.make_dir_recursive_absolute("res://exports/holographic-proof")
				root.get_texture().get_image().save_png(
					"res://exports/holographic-proof/menu-flow-%dx%d.png" % [pixels.x, pixels.y]
				)
			await _tap(game.garage.next_button)
			await _settle()
		assert(not game.menu_active and game.mode == "cup" and game.track_id == "sonnenhafen")
		assert(is_instance_valid(game.player) and game.opponents.size() == 5)
		# Use Android's default manual accelerator for the complete control view.
		game.auto_gas = false
		game._update_hud()
		# The garage-to-race transition must apply the actual driving layout
		# itself. Do not call its layout methods here to repair a broken result.
		for control in [game.joystick, game.pedal_pad, game.top_pause_button]:
			assert(
				root.get_visible_rect().encloses(control.get_global_rect()),
				"Race controls must fit the real viewport after menu start"
			)
			assert(
				game.safe_ui.get_global_rect().encloses(control.get_global_rect()),
				"Race controls must stay inside the existing safe insets"
			)
		for action in game.pedal_pad.get_children():
			assert(action.is_visible_in_tree())
			assert(
				game.pedal_pad.get_global_rect().grow(0.02).encloses(action.get_global_rect()),
				"Action exceeds its pad beyond subpixel rounding"
			)
			var physical: Vector2 = action.size * Vector2(root.size) / root.get_visible_rect().size
			assert(minf(physical.x, physical.y) >= 43.99)
		assert(not game.map_panel.visible or pixels.x >= 900)
		# Erst läuft die Streckenvorschau, danach der Countdown.
		for frame in range(220 + ceili(game.preview_left * 60.0)):
			game._physics_process(1.0 / 60)
		assert(game.racing and game.elapsed > 0)
		await _settle()
		root.get_texture().get_image().save_png(
			"res://exports/holographic-proof/race-flow-%dx%d.png" % [pixels.x, pixels.y]
		)
		game.abandoned = true
		game.queue_free()
		await _settle()
		print("[KartMenuFlow] %s: five modes, five actual touch steps, started cup race" % pixels)
	# The compact welcome also offers the direct start path. Exercise it with
	# the same parent insets, not only in an unconstrained standalone garage.
	game = kart_scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	root.size = Vector2i(640, 320)
	await _settle()
	assert(root.size == Vector2i(640, 320), "Direct start must run at the compact physical size")
	game._apply_safe_area(Rect2(16, 32, 16, 48), Vector2(640, 320))
	game.garage._apply_responsive_layout()
	await _settle()
	# One gold "Weiter" button is the design contract. The legacy
	# cyan quick-start button is deliberately hidden and MUST NOT be tapped.
	assert(not game.garage.quick_start_button.visible)
	var cup_mode: Button = null
	for entry in game.garage.choices.get_child(0).get_children():
		if str(entry.title) == "Sternen-Cup":
			cup_mode = entry
	assert(is_instance_valid(cup_mode))
	game.garage.choices.get_parent().ensure_control_visible(cup_mode)
	await _settle()
	await _tap(cup_mode)
	assert(game.garage.setup.mode == "cup")
	await _settle()
	root.get_texture().get_image().save_png(
		"res://exports/holographic-proof/menu-direct-640x320.png"
	)
	for index in range(5):
		assert(game.garage.step == index)
		assert(game.garage.next_button.visible)
		await _tap(game.garage.next_button)
		await _settle()
	assert(not game.menu_active and game.mode == "cup" and game.track_id == "sonnenhafen")
	assert(is_instance_valid(game.player) and game.opponents.size() == 5)
	game.abandoned = true
	game.queue_free()
	await _settle()
	print("[KartMenuFlow] PASS: direct selected Cup start inside compact Android safe insets")
	print("[KartMenuFlow] PASS: five touch steps; 1280x720,800x480,640x320; safe controls >=44px")
	# Destroy all camera/world references and allow Godot's GL renderer to
	# consume the deferred free queue before exiting this 4-scene integration run.
	# A 120 ms timeout previously logged four outstanding SceneCull RIDs.
	root.world_3d.fallback_environment = null
	await create_timer(1.5).timeout
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	quit(0)
