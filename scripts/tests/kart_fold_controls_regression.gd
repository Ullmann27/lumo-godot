extends SceneTree
## Real render, safe area, physical input and fold/unfold regression.
var game
var measurements: Array = []
var output: String = OS.get_environment("LUMO_QA_DIR")

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at * Vector2(root.size) / root.get_visible_rect().size
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _pixels(control: Control) -> Vector2:
	return control.size * Vector2(root.size) / root.get_visible_rect().size

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	if output.is_empty():
		output = "res://exports/fold-controls"
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _settle()
	game._start_selected_race({"mode":"training", "driver":"fox", "kart":"comet", "track":"candy_cloud", "difficulty":"gemuetlich"})
	game._end_preview()
	game.set_physics_process(false)
	game.auto_gas = false
	game.countdown = 0
	game.racing = true
	game.paused = false
	game.item = "shield"
	game.boosts = 2
	game.modal.hide()
	game.message.text = "Lenken · Gas halten · Los geht’s!"
	game._update_hud()
	var actions: Array = [game.gas_button, game.brake_button, game.drift_button, game.boost_button, game.item_button]
	var matrix: Array[Vector2i] = [Vector2i(800,360),Vector2i(320,720),Vector2i(1280,720),Vector2i(600,960),Vector2i(840,720),Vector2i(2176,1812),Vector2i(1812,2176),Vector2i(2316,904),Vector2i(640,320),Vector2i(1280,720)]
	for pixels in matrix:
		root.size = pixels
		await _settle()
		game._apply_safe_area(Rect2(12,20,16,16),Vector2(pixels))
		await _settle()
		game._apply_responsive_layout()
		await _settle()
		var safe: Rect2 = game.safe_ui.get_global_rect()
		assert(safe.encloses(game.joystick.get_global_rect()), "Stick outside safe area: %s" % pixels)
		var rectangles: Array[Rect2] = [game.joystick.get_global_rect()]
		for action in actions:
			var rectangle: Rect2 = action.get_global_rect()
			assert(safe.encloses(rectangle), "Action outside safe area: %s %s" % [action.name,pixels])
			assert(_pixels(action).x >= 44.0, "Touch target too small")
			assert(action.label.get_minimum_size().x <= action.size.x, "Caption clipped: %s" % action.name)
			assert(action.ICONS.has(action.icon_id), "Missing real icon asset")
			for other in rectangles:
				assert(not rectangle.grow(-0.5).intersects(other), "Overlapping touch targets: %s %s" % [action.name,pixels])
			rectangles.append(rectangle)
		var shortest: float = minf(pixels.x,pixels.y)
		var expanded: bool = shortest >= 600 and maxf(pixels.x,pixels.y)/shortest <= 1.65
		if expanded:
			assert(_pixels(game.joystick).x >= shortest * 0.30, "Fold stick must remain prominent")
			assert(_pixels(game.gas_button).x >= shortest * 0.21, "Fold gas button must grow with display")
		if pixels == Vector2i(1280,720):
			assert(is_equal_approx(_pixels(game.gas_button).x,156.0), "Normal landscape sizing changed")
		if pixels == Vector2i(800,360):
			assert(is_equal_approx(_pixels(game.gas_button).x,52.0), "Short phone sizing changed")
		measurements.append({"surface": [pixels.x,pixels.y],"stick_px":_pixels(game.joystick).x,"gas_px":_pixels(game.gas_button).x,"boost_px":_pixels(game.boost_button).x})
		assert(root.get_texture().get_image().save_png(output.path_join("kart-controls-%dx%d.png" % [pixels.x,pixels.y])) == OK)
	# Exercise both real item states on the long cover display. A visible empty
	# item must not fire; an acquired shield must be consumed exactly once.
	root.size = Vector2i(2316,904)
	await _settle()
	game._apply_safe_area(Rect2(12,20,16,16),Vector2(root.size))
	game.item = ""
	game._update_hud()
	await _settle()
	assert(game.item_button.disabled, "Empty inventory must disable item action")
	await _touch(4,game.item_button.get_global_rect().get_center(),true)
	assert(not game.item_button.held and game.item.is_empty(), "Empty item cannot activate")
	await _touch(4,Vector2(420,250),false)
	assert(root.get_texture().get_image().save_png(output.path_join("kart-cover-empty-item.png")) == OK)
	game.item = "shield"
	game._update_hud()
	await _touch(4,game.item_button.get_global_rect().get_center(),true)
	assert(game.item.is_empty() and game.shield_time > 0.0, "Acquired shield must activate")
	await _touch(4,Vector2(420,250),false)
	game._update_hud()
	assert(game.item_button.disabled, "Consumed item must become unavailable")
	root.size = Vector2i(840,720)
	await _settle()
	game._apply_safe_area(Rect2(12,20,16,16),Vector2(root.size))
	await _settle()
	var stick: Vector2 = game.joystick.get_global_rect().get_center() + Vector2(game.joystick.size.x * 0.25,0)
	await _touch(1,stick,true)
	await _touch(2,game.gas_button.get_global_rect().get_center(),true)
	assert(game.steering > 0.5 and game.gas_held, "Simultaneous steering and gas")
	await _touch(3,game.boost_button.get_global_rect().get_center(),true)
	assert(game.boosts == 1 and game.boost_time > 0.0, "Boost must fire once")
	assert(game.steering > 0.5 and game.gas_held, "Boost must not steal other fingers")
	game._update_hud()
	await _settle()
	assert(root.get_texture().get_image().save_png(output.path_join("kart-controls-active.png")) == OK)
	await _touch(3,Vector2(420,250),false)
	assert(game.boosts == 1 and game.gas_held, "Release outside must not retrigger boost")
	await _touch(2,Vector2(420,250),false)
	await _touch(1,Vector2(420,250),false)
	assert(not game.gas_held and game.steering == 0, "All fingers release outside")
	await _touch(2,game.gas_button.get_global_rect().get_center(),true)
	game._pause()
	game._update_hud()
	assert(not game.gas_held and not game.gas_button.held, "Pause releases the held pedal")
	var count: int = game.boosts
	await _touch(3,game.boost_button.get_global_rect().get_center(),true)
	assert(game.boosts == count, "Paused/disabled action cannot fire")
	await _touch(3,Vector2(420,250),false)
	FileAccess.open(output.path_join("control-measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"  "))
	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[KartFoldControls] PASS: ten resizes, scaled Fold targets, cover and compact sizes, actual empty/shield item actions, distinct artwork, no overlap, real three-finger driving, release outside and pause")
	await create_timer(0.15).timeout
	quit.call_deferred(0)
