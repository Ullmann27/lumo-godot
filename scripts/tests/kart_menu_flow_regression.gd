extends SceneTree
## Actual physical-pixel taps complete all five setup steps on desktop and compact Android sizes.
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _tap(control: Control) -> void:
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
	for pixels in [Vector2i(1280, 720), Vector2i(800, 480), Vector2i(640, 320)]:
		game = load("res://scenes/games/kart_island.tscn").instantiate()
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
		if pixels.y >= 440:
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
			assert(
				game.garage.choices.get_parent().get_global_rect().encloses(
					mode_grid.get_child(1).get_global_rect()
				),
				"Visible cup choice must be touchable; further modes scroll"
			)
		await _tap(mode_grid.get_child(1))
		assert(game.garage.setup.mode == "cup")
		await _settle()
		for step in range(5):
			assert(game.garage.step == step)
			if step == 2:
				var inspect: OptionButton = game.garage.view_choice
				assert(inspect.is_visible_in_tree())
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
	print("[KartMenuFlow] PASS: five touch steps; 1280x720,800x480,640x320; safe controls >=44px")
	# AudioServer releases stopped stream playbacks on its asynchronous mix thread.
	await create_timer(0.12).timeout
	quit(0)
