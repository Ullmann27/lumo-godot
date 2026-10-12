extends SceneTree
## Real input on the same garage across cover/inner display changes.
## Desktop GL + explicit density fixtures; not physical Fold verification.
var game
var output := ""
var records: Array[Dictionary] = []
var previous_emulation := false


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw


func _pixels(rect: Rect2) -> Rect2:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	return Rect2(rect.position * factor, rect.size * factor)


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _tap(control: Control) -> void:
	var point := _pixels(control.get_global_rect()).get_center()
	await _touch(point, true)
	await _touch(point, false)
	await _settle()


func _drag(start: Vector2, end: Vector2) -> void:
	await _touch(start, true)
	var previous := start
	for index in range(1, 13):
		var point := start.lerp(end, float(index) / 12.0)
		var event := InputEventScreenDrag.new()
		event.position = point
		event.relative = point - previous
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		previous = point
		await process_frame
	await _touch(end, false)
	await create_timer(0.3).timeout
	await _settle()


func _record(label: String, passed: bool) -> bool:
	var scroll := game.garage.choices.get_parent() as ScrollContainer
	records.append({"label": label, "passed": passed, "window": str(root.size),
		"step": game.garage.step, "selection": game.garage.setup.duplicate(),
		"scroll": scroll.scroll_vertical, "page": scroll.get_v_scroll_bar().page,
		"content": scroll.get_v_scroll_bar().max_value,
		"menu": str(game.garage.get_global_rect()), "choices": str(scroll.get_global_rect())})
	var file := FileAccess.open(output.path_join("garage-touch.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	if not passed:
		await _capture("FAIL")
		print("[GarageTouch] FAIL: ", label)
		Input.emulate_touch_from_mouse = previous_emulation
		game.queue_free()
		await _settle()
		quit(1)
	return passed


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))


func _run() -> void:
	output = OS.get_environment("LUMO_QA_DIR")
	if output.is_empty():
		output = "res://exports/garage-touch"
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	previous_emulation = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var host = root.get_node("HostBridge")
	host._options = {"soundEnabled": false, "reduceAnimations": true}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	# Only earned-balance fixture changes availability. No real profile save is changed.
	game.garage.stars = 48
	var cases := [[Vector2i(904, 2316), 2.5], [Vector2i(2176, 1812), 2.25],
		[Vector2i(2316, 904), 2.5], [Vector2i(1812, 2176), 2.25]]
	for index in range(cases.size()):
		host._options["displayDensity"] = cases[index][1]
		root.size = cases[index][0]
		await _settle()
		game._apply_safe_area(Rect2(0, 32, 0, 24), Vector2(root.size))
		game._apply_responsive_layout()
		await _settle()
		await _tap(game.garage.step_buttons[1])
		if not await _record("Live resize: driver tab responds", game.garage.step == 1):
			return
		await _capture("%02d-drivers-before" % index)
		var driver_index: int = 1 if game.garage.setup.driver == "fox" else 0
		var expected_driver := "rabbit" if driver_index == 1 else "fox"
		var driver: Button = game.garage.choices.get_child(driver_index)
		var scroll := game.garage.choices.get_parent() as ScrollContainer
		if not await _record("Unlocked Nova button is visible and reachable",
			not driver.disabled and scroll.get_global_rect().encloses(driver.get_global_rect())):
			return
		await _tap(driver)
		if not await _record("Real tap changes the unlocked driver", game.garage.setup.driver == expected_driver):
			return
		await _tap(game.garage.step_buttons[3])
		await _capture("%02d-worlds-before" % index)
		var before: int = scroll.scroll_vertical
		var bounds := _pixels(scroll.get_global_rect())
		var start := Vector2(bounds.get_center().x, bounds.end.y - bounds.size.y * 0.25)
		var end := Vector2(start.x, bounds.position.y + bounds.size.y * 0.15)
		await _drag(start, end)
		await _capture("%02d-worlds-after-drag" % index)
		if not await _record("Drag on world buttons scrolls without selecting",
			scroll.scroll_vertical > before + 8 and game.garage.setup.track == "sonnenhafen"):
			return
		var visible: Button = null
		for child in game.garage.choices.get_children():
			if child is Button and scroll.get_global_rect().encloses(child.get_global_rect()):
				visible = child
		if not await _record("Scrolled world has a complete tappable button", visible != null):
			return
		var title: String = visible.title
		await _tap(visible)
		var catalog = load("res://scripts/games/kart_catalog.gd")
		if not await _record("Real tap selects the scrolled world exactly",
			catalog.entry(catalog.TRACKS, game.garage.setup.track).name == title):
			return
		# Reset via actual touch on the first step and driver's Lumo choice.
		await _tap(game.garage.step_buttons[1])
		await _tap(game.garage.choices.get_child(0))
		await _tap(game.garage.step_buttons[2])
		var kart_before: String = game.garage.setup.kart
		var kart_grid: GridContainer = game.garage.choices.get_child(0)
		for card in kart_grid.get_children():
			var rectangle: Rect2 = card.get_global_rect()
			if not await _record("Every kart card fits the horizontal selection area",
				rectangle.position.x >= scroll.get_global_rect().position.x - 1
				and rectangle.end.x <= scroll.get_global_rect().end.x + 1):
				return
		bounds = _pixels(scroll.get_global_rect())
		start = Vector2(bounds.get_center().x, bounds.end.y - bounds.size.y * 0.2)
		end = Vector2(start.x, bounds.position.y + bounds.size.y * 0.2)
		# Changing tabs can retain a legitimate list offset; return via genuine swipes.
		for attempt in range(8):
			if scroll.scroll_vertical == 0:
				break
			await _drag(end, start)
		before = scroll.scroll_vertical
		await _drag(start, end)
		await _capture("%02d-karts-after-drag" % index)
		if not await _record("Drag over kart grid scrolls without changing the vehicle",
			scroll.scroll_vertical > before + 8 and game.garage.setup.kart == kart_before):
			return
		visible = null
		var grid: GridContainer = game.garage.choices.get_child(0)
		# A real drag can stop between rows. Reveal a complete card with further
		# real short drags, rather than tapping a clipped row or assigning an offset.
		for attempt in range(9):
			for child in grid.get_children():
				if child is Button and not child.disabled and scroll.get_global_rect().encloses(child.get_global_rect()):
					visible = child
			if visible != null:
				break
			var middle := bounds.get_center()
			await _drag(middle, middle - Vector2(0, 28))
		if not await _record("A fully visible unlocked scrolled kart is tappable", visible != null):
			return
		if not await _record("Extra revealing drags never select a kart", game.garage.setup.kart == kart_before):
			return
		var kart_id: String = visible.item.id
		await _tap(visible)
		if not await _record("Actual scrolled kart tap selects that exact vehicle",
			game.garage.setup.kart == kart_id):
			return
		await _tap(game.garage.step_buttons[0])
		await _capture("%02d-menu-after" % index)
		# Each independent drag assertion starts from the actual selected first world.
		game.garage.setup.track = "sonnenhafen"
	Input.emulate_touch_from_mouse = previous_emulation
	game.queue_free()
	await _settle()
	print("[GarageTouch] PASS: ", records.size(), " checks; genuine resize/tap/drag")
	quit(0)
