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
	assert(root.get_visible_rect().encloses(control.get_global_rect()), "The complete action must be visible before touch")
	var position: Vector2 = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 3
		touch.position = position
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	for pixels in [Vector2i(1280, 720), Vector2i(800, 480)]:
		game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.lightweight = true
		await _settle()
		root.size = pixels
		await _settle()
		assert(game.menu_active)
		var font: Font = game.safe_ui.theme.default_font
		var coordinates: Dictionary = TextServerManager.get_primary_interface().font_get_variation_coordinates(font.get_rids()[0])
		assert(float(coordinates.get(2003265652, 200)) >= 600, "Actual rendered font must use semibold weight")
		var mode_grid: GridContainer = game.garage.choices.get_child(0)
		assert(mode_grid.get_child_count() == 5, "Five race modes; the learning cup is gone")
		for mode_button in mode_grid.get_children():
			assert(root.get_visible_rect().encloses(mode_button.get_global_rect()), "Every mode must be visible")
		await _tap(mode_grid.get_child(1))
		assert(game.garage.setup.mode == "cup")
		await _settle()
		for step in range(5):
			assert(game.garage.step == step)
			assert(game.garage.next_button.get_global_rect().size.y * root.size.y / root.get_visible_rect().size.y >= 44, "Compact setup actions retain a large touch area")
			if step == 0:
				DirAccess.make_dir_recursive_absolute("res://exports/holographic-proof")
				root.get_texture().get_image().save_png("res://exports/holographic-proof/menu-flow-%dx%d.png" % [pixels.x, pixels.y])
			await _tap(game.garage.next_button)
			await _settle()
		assert(not game.menu_active and game.mode == "cup" and game.track_id == "sonnenhafen")
		assert(is_instance_valid(game.player) and game.opponents.size() == 5)
		for frame in range(220):
			game._physics_process(1.0 / 60)
		assert(game.racing and game.elapsed > 0)
		game.abandoned = true
		game.queue_free()
		await _settle()
		print("[KartMenuFlow] %s: five visible modes, five actual touch steps, started cup race" % pixels)
	print("[KartMenuFlow] PASS: complete pixel-touch setup at1280x720 and800x480, semibold font, every mode visible")
	# AudioServer releases stopped stream playbacks on its asynchronous mix thread.
	await create_timer(0.12).timeout
	quit(0)
