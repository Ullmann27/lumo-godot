extends SceneTree
## Real compact/Fold windows, unclipped pause actions and actual GUI touches.
# Native method name intentionally matches the Android plugin contract.
# gdlint: disable=function-name


class Host:
	extends Node
	var returns: Array[Dictionary] = []

	func returnToApp(destination: String, payload: String) -> int:
		returns.append({"destination": destination, "payload": JSON.parse_string(payload)})
		return 1


var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _button(caption: String) -> Button:
	for child in game.modal_column.get_children():
		if child is Button and child.text.begins_with(caption):
			return child
	return null


func _inside(control: Control, rectangle: Rect2) -> void:
	assert(control.is_visible_in_tree())
	var box: Rect2 = control.get_global_rect()
	assert(
		rectangle.encloses(box),
		"Control %s rect %s exceeds visible bounds %s"
		% [control.get_path(), box, rectangle]
	)


func _assert_touch_size(control: Control) -> void:
	var logical_size: Vector2 = root.get_visible_rect().size
	var pixel_size: Vector2 = root.size
	var physical: Vector2 = control.get_global_rect().size * pixel_size / logical_size
	assert(minf(physical.x, physical.y) >= 44.0, "Touch target must remain at least 44 dp")


func _assert_race_layout(pixels: Vector2i) -> void:
	root.size = pixels
	await _settle()
	game._apply_safe_area(Rect2(12, 24, 16, 20), Vector2(pixels))
	await _settle()
	game._apply_responsive_layout()
	await _settle()
	var safe_rect: Rect2 = game.safe_ui.get_global_rect()
	_inside(game.joystick, safe_rect)
	_inside(game.pedal_pad, safe_rect)
	assert(game.hud.get_line_count() == 1, "Race title must not wrap into the pause button")
	for button in game.pedal_pad.get_children():
		_inside(button, game.pedal_pad.get_global_rect())
		_assert_touch_size(button)
	_inside(game.modal, safe_rect)
	assert(game.map_panel.visible == (pixels.x >= 900 and pixels.x >= pixels.y))
	var output: String = OS.get_environment("LUMO_QA_DIR")
	if not output.is_empty():
		assert(
			root.get_texture().get_image().save_png(
				output.path_join("kart-fold-%dx%d.png" % [pixels.x, pixels.y])
			)
			== OK
		)


func _physical_size(control: Control) -> Vector2:
	return control.get_global_rect().size * Vector2(root.size) / root.get_visible_rect().size


func _assert_race_controls_fit() -> void:
	var safe_rect: Rect2 = game.safe_ui.get_global_rect()
	for control in [game.joystick, game.pedal_pad, game.gas_button, game.brake_button, game.boost_button, game.item_button]:
		_inside(control, safe_rect)
	var joystick_pixels: Vector2 = _physical_size(game.joystick)
	assert(joystick_pixels.x >= 88.0 and joystick_pixels.y >= 88.0)
	assert(game.camera.fov >= 40.0 and game.camera.fov <= 110.0)


func _tap(control: Control) -> void:
	# Window injects physical pixels and transforms them into its scaled canvas,
	# matching native touchscreen delivery on the 800x480 display.
	var screen_size: Vector2 = root.size
	var logical_size: Vector2 = root.get_visible_rect().size
	var at: Vector2 = control.get_global_rect().get_center() * screen_size / logical_size
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _scroll_into_view(control: Control, scroll: ScrollContainer) -> void:
	var clip: Rect2 = scroll.get_global_rect()
	var box: Rect2 = control.get_global_rect()
	if box.position.y < clip.position.y:
		scroll.scroll_vertical -= clip.position.y - box.position.y + 1.0
	elif box.end.y > clip.end.y:
		scroll.scroll_vertical += box.end.y - clip.end.y + 1.0
	await _settle()
	_inside(control, scroll.get_global_rect())


func _run() -> void:
	assert(
		DisplayServer.get_name() != "headless", "Use the actual desktop rendering/window backend"
	)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	var bridge = root.get_node("HostBridge")
	var host := Host.new()
	root.add_child(host)
	bridge._host = host
	bridge._options = {"sessionId": "pause-layout"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"})
	assert(is_equal_approx(game._resize_compensated_fov(68.0, 16.0 / 9.0), 68.0))
	var wide_fov: float = game._resize_compensated_fov(68.0, 2.4)
	assert(wide_fov >= 68.0, "Wide displays must retain the full vertical kart view")
	assert(
		tan(deg_to_rad(wide_fov) * 0.5) * 2.4
		> tan(deg_to_rad(68.0) * 0.5) * (16.0 / 9.0),
		"A cover display should reveal more road on both sides instead of cropping the kart"
	)
	assert(game.camera.keep_aspect == Camera3D.KEEP_HEIGHT)
	game.set_physics_process(false)
	await _settle()
	root.size = Vector2i(800, 480)
	await _settle()
	game._apply_safe_area(Rect2(0, 32, 0, 24), Vector2(800, 480))
	await _settle()
	game._apply_responsive_layout()
	await _settle()
	_assert_race_controls_fit()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	root.go_back_requested.emit()
	await _settle()
	assert(game.paused and not quit_on_go_back)
	var games: Button = game.pause_navigation.get_node("ReturnToGames")
	var learn: Button = game.pause_navigation.get_node("ReturnToLearning")
	for button in [games, learn]:
		_inside(button, game.modal.get_global_rect())
		_inside(button, game.safe_ui.get_global_rect())
		assert(button.get_global_rect().size.y * root.size.y / root.get_visible_rect().size.y >= 44)
	_inside(_button("Weiterfahren"), game.modal_scroll.get_global_rect())
	await _scroll_into_view(_button("Grafik:"), game.modal_scroll)
	var output: String = OS.get_environment("LUMO_QA_DIR")
	if output.is_empty():
		output = "user://"
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	assert(
		(
			root.get_texture().get_image().save_png(
				output.path_join("godot-kart-pause-800x480.png")
			)
			== OK
		)
	)
	await _tap(_button("Weiterfahren"))
	assert(not game.paused, "Actual physical-pixel screen touch must resume the compact pause")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	root.go_back_requested.emit()
	await _settle()
	await _tap(games)
	assert(host.returns.size() == 1 and host.returns[0].destination == "games")
	assert(host.returns[0].payload.status == "paused" and FileAccess.file_exists(game.SESSION))
	bridge._return_pending = false
	await _tap(learn)
	assert(host.returns.size() == 2 and host.returns[1].destination == "learn")
	assert(host.returns[1].payload.resultId == host.returns[0].payload.resultId)
	bridge._return_pending = false
	var fold_matrix: Array[Vector2i] = [
		Vector2i(320, 720), Vector2i(360, 800), Vector2i(412, 915), Vector2i(600, 960),
		Vector2i(768, 1024), Vector2i(840, 720), Vector2i(1024, 768), Vector2i(1280, 800),
		Vector2i(904, 2316), Vector2i(1812, 2176), Vector2i(2176, 1812),
		Vector2i(2208, 1840), Vector2i(800, 480)
	]
	for pixels in fold_matrix:
		await _assert_race_layout(pixels)
		_assert_race_controls_fit()
		for button in [games, learn]:
			_inside(button, game.modal.get_global_rect())
			_inside(button, game.safe_ui.get_global_rect())
			_assert_touch_size(button)
		_inside(_button("Weiterfahren"), game.modal_scroll.get_global_rect())
		await _scroll_into_view(_button("Grafik:"), game.modal_scroll)
		game.modal_scroll.scroll_vertical = 0
		await _tap(learn)
		assert(host.returns[-1].destination == "learn")
		bridge._return_pending = false
	game.finished = true
	game.result_payload = {"stars": 1, "place": 1}
	game._show_result()
	for pixels in [Vector2i(320, 720), Vector2i(840, 720), Vector2i(1280, 800)]:
		root.size = pixels
		await _settle()
		game._apply_safe_area(Rect2(12, 24, 16, 20), Vector2(pixels))
		await _settle()
		game._apply_responsive_layout()
		await _settle()
		_inside(game.modal, game.safe_ui.get_global_rect())
		_inside(game.modal_column.get_child(0), game.modal_scroll.get_global_rect())
		game.modal_scroll.scroll_vertical = game.modal_scroll.get_v_scroll_bar().max_value
		await _settle()
		_inside(
			game.modal_column.get_child(game.modal_column.get_child_count() - 1),
			game.modal_scroll.get_global_rect()
		)
	var garage = load("res://scripts/games/kart_garage_menu.gd").new()
	root.add_child(garage)
	for pixels in [Vector2i(320, 720), Vector2i(600, 960), Vector2i(840, 720), Vector2i(1280, 800)]:
		root.size = pixels
		await _settle()
		garage._apply_responsive_layout()
		await _settle()
		assert(garage.setup_row.columns == (1 if pixels.x < 760 or pixels.x < pixels.y else 2))
		_inside(garage.setup_row, garage.page_margin.get_global_rect())
		_inside(garage.back_button, garage.page_margin.get_global_rect())
		_inside(garage.next_button, garage.page_margin.get_global_rect())
	garage.queue_free()
	DirAccess.remove_absolute(game.SESSION)
	game.abandoned = true
	game.queue_free()
	await process_frame
	bridge._host = null
	host.queue_free()
	print(
		(
			"[KartPauseLayoutTests] PASS: actual compact/Fold matrix, "
			+ "safe-area controls, pause/results layout and touch navigation"
		)
	)
	await create_timer(0.25).timeout
	# Let the asynchronous runner release its locals before SceneTree teardown.
	quit.call_deferred(0)
