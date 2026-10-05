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
		rectangle.encloses(box), "Actual control must be fully visible inside its clipping panel"
	)


func _physical_size(control: Control) -> Vector2:
	return control.get_global_rect().size * Vector2(root.size) / root.get_visible_rect().size


func _assert_race_controls_fit() -> void:
	for control in [game.joystick, game.pedal_pad, game.gas_button, game.brake_button, game.boost_button, game.item_button]:
		_inside(control, game.safe_ui.get_global_rect())
	var joystick_pixels := _physical_size(game.joystick)
	var gas_pixels := _physical_size(game.gas_button)
	assert(joystick_pixels.x >= 88.0 and joystick_pixels.y >= 88.0)
	assert(gas_pixels.x >= 44.0 and gas_pixels.y >= 44.0)
	assert(game.camera.fov >= 64.0 and game.camera.fov <= 80.0)


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
	game.set_physics_process(false)
	await _settle()
	root.size = Vector2i(800, 480)
	await _settle()
	game._apply_safe_area(Rect2(0, 32, 0, 24), Vector2(800, 480))
	game._on_viewport_resized()
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
	_inside(_button("Grafik:"), game.modal_scroll.get_global_rect())
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
	for pixels in [
		Vector2i(904, 2316),
		Vector2i(1812, 2176),
		Vector2i(2176, 1812),
		Vector2i(2208, 1840),
		Vector2i(800, 480),
	]:
		root.size = pixels
		await _settle()
		game._apply_safe_area(Rect2(0, 32, 0, 24), Vector2(pixels))
		game._on_viewport_resized()
		await _settle()
		_assert_race_controls_fit()
		for button in [games, learn]:
			_inside(button, game.modal.get_global_rect())
			_inside(button, game.safe_ui.get_global_rect())
		_inside(_button("Weiterfahren"), game.modal_scroll.get_global_rect())
		_inside(_button("Grafik:"), game.modal_scroll.get_global_rect())
		await _tap(learn)
		assert(host.returns[-1].destination == "learn")
		bridge._return_pending = false
	DirAccess.remove_absolute(game.SESSION)
	game.abandoned = true
	game.queue_free()
	await process_frame
	bridge._host = null
	host.queue_free()
	print(
		(
			"[KartPauseLayoutTests] PASS: actual compact/Fold resize windows, "
			+ "adaptive race controls/camera, visible actions/settings, touch games/learn/resume"
		)
	)
	await create_timer(0.12).timeout
	quit(0)
