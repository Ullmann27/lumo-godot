extends "res://scripts/tests/kart_pause_layout_regression.gd"
## Actual window-delivered finger swipe over a pause button; no scrollbar writes.

func _drag(control: Control) -> void:
	var screen_scale: Vector2 = Vector2(root.size) / root.get_visible_rect().size
	var start: Vector2 = control.get_global_rect().get_center() * screen_scale
	var finish: Vector2 = start - Vector2(0, 190)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var previous: Vector2 = start
	for step in range(1, 21):
		var at: Vector2 = start.lerp(finish, float(step) / 20.0)
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = at
		event.relative = at - previous
		event.velocity = event.relative * 60.0
		Input.parse_input_event(event)
		previous = at
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = finish
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()

func _run() -> void:
	Input.set_emulate_touch_from_mouse(true)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1920, 1080)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"})
	await _settle()
	await _tap(game.top_pause_button)
	await _settle()
	var before: bool = game.muted
	var distance: float = game.distance
	var sound := _button("Ton:")
	assert(sound != null and game.paused)
	var offset: int = game.modal_scroll.scroll_vertical
	await _drag(sound)
	print("[PauseTouchScroll] before=", offset, " after=", game.modal_scroll.scroll_vertical, " mute_before=", before, " mute_after=", game.muted)
	if game.modal_scroll.scroll_vertical <= offset:
		print("[PauseTouchScroll] FAIL: swipe on settings button did not scroll")
		game.queue_free()
		await process_frame
		quit(1)
		return
	assert(game.muted == before, "Dragging must not toggle the touched setting")
	assert(game.paused and game.distance == distance, "Scrolling must keep the race paused")
	var gas_before: bool = game.auto_gas
	var gas := _button("Gas:")
	print("[PauseTouchScroll] gas_before=", gas_before, " rect=", gas.get_global_rect(), " clip=", game.modal_scroll.get_global_rect())
	await _tap(gas)
	assert(game.auto_gas != gas_before, "Normal tap must still change the public gas setting")
	var output := "res://exports/touch-scroll"
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	await _settle()
	assert(root.get_texture().get_image().save_png(output.path_join("settings-after-actual-swipe.png")) == OK)
	var proof := {"physical_surface": [root.size.x, root.size.y], "initial_scroll": offset,
		"observed_scroll": game.modal_scroll.scroll_vertical, "swipe_did_not_toggle_sound": game.muted == before,
		"normal_tap_toggled_gas": game.auto_gas != gas_before, "race_stayed_paused": game.paused}
	FileAccess.open(output.path_join("touch-scroll.json"), FileAccess.WRITE).store_string(JSON.stringify(proof, "  "))
	game.queue_free()
	await process_frame
	# The audio mixer releases Ogg playback on its own thread, after the
	# scene exits. Keep the strict leak check and let that shutdown complete.
	await create_timer(0.6).timeout
	print("[PauseTouchScroll] PASS: actual swipe scrolls settings without changing a setting; normal tap works")
	quit()
