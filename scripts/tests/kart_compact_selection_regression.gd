extends SceneTree
## Real input and clipped-control geometry at the Android compact safe area.
## This runs headlessly; the separate renderer menu-flow gate remains required.
var failures: Array[String] = []
var checks := 0
var completed := 0
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[CompactKartSelection] " + label)


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _tap(control: Control) -> void:
	var rect := control.get_global_rect()
	var scale: float = game.garage._preview_dp_scale()
	_check(control.is_visible_in_tree(), "%s is visible" % control.name)
	_check(minf(rect.size.x, rect.size.y) / scale >= 47.99,
		"%s retains 48dp touch dimensions" % control.name)
	_check(game.safe_ui.get_global_rect().grow(0.01).encloses(rect),
		"%s is fully inside the safe area" % control.name)
	var position := rect.get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _footer_touches(garage, saved: bool) -> void:
	# This layout probe follows actual native input up to the production
	# signal boundary. The existing complete-race gate owns save/resume I/O.
	var starts: Array = garage.start_requested.get_connections()
	var resumes: Array = garage.resume_requested.get_connections()
	for connection in starts:
		garage.start_requested.disconnect(connection.callable)
	for connection in resumes:
		garage.resume_requested.disconnect(connection.callable)
	var destinations: Array[String] = []
	var receive_start := func(setup: Dictionary): destinations.append("start:" + str(setup.get("kart", "")))
	var receive_resume := func(): destinations.append("resume")
	garage.start_requested.connect(receive_start)
	garage.resume_requested.connect(receive_resume)
	await _tap(garage.next_button)
	_check(destinations == ["start:gecko_velo"], "actual Start touch reaches the selected kart signal exactly once")
	if saved:
		await _tap(garage.footer.get_node("ResumeRace"))
		_check(destinations == ["start:gecko_velo", "resume"], "actual Fortsetzen touch reaches only the resume signal")
	print("[CompactKartSelection] footer touch destinations=", destinations)
	garage.start_requested.disconnect(receive_start)
	garage.resume_requested.disconnect(receive_resume)
	for connection in starts:
		garage.start_requested.connect(connection.callable, connection.flags)
	for connection in resumes:
		garage.resume_requested.connect(connection.callable, connection.flags)


func _case(pixels: Vector2i, saved: bool, density: float = 1.0,
		insets: Rect2 = Rect2(16, 32, 16, 48)) -> void:
	root.get_node("HostBridge")._options["displayDensity"] = density
	root.size = pixels
	await _settle()
	game._apply_safe_area(insets, Vector2(pixels))
	var garage = game.garage
	garage.step = 2
	garage.setup.kart = "comet"
	garage._refresh()
	garage._apply_responsive_layout()
	await _settle()
	var scroll: ScrollContainer = garage.choices.get_parent()
	var fleet: GridContainer = garage.choices.get_child(0)
	_check(fleet.get_child_count() == 14, "all fourteen original karts remain reachable")
	var visible_cards := 0
	for card in fleet.get_children():
		scroll.ensure_control_visible(card)
		await _settle()
		var fully_visible: bool = scroll.get_global_rect().grow(0.01).encloses(card.get_global_rect())
		_check(fully_visible,
			"%s fits the scroll viewport at %s saved=%s" % [card.name, pixels, saved])
		if fully_visible:
			visible_cards += 1
		_check(card.size.y / garage._preview_dp_scale() >= 47.99,
			"%s retains 48dp while scrolling" % card.name)
		if density > 1.0:
			_check(card.size.y / garage._preview_dp_scale() >= 89.99,
				"%s retains the readable 90dp Android card" % card.name)
	var gecko: Button = fleet.get_node("KartCard_gecko_velo")
	scroll.ensure_control_visible(gecko)
	await _settle()
	print("[CompactKartSelection] pixels=", pixels, " saved=", saved,
		" density=", density, " safe_dp=", game.safe_ui.size / garage._preview_dp_scale(),
		" list_dp=", scroll.size / garage._preview_dp_scale(),
		" gecko_dp=", gecko.size / garage._preview_dp_scale(),
		" complete_cards=", visible_cards, "/14",
		" list=", scroll.get_global_rect(), " gecko=", gecko.get_global_rect(),
		" workshop=", garage.workshop_button.get_global_rect(),
		" footer=", garage.footer.get_global_rect())
	await _tap(gecko)
	_check(garage.setup.kart == "gecko_velo" and garage.preview_kart.kart_style == "gecko_velo",
		"actual touch selects Gecko and updates the live kart")
	for button in garage.footer.get_children():
		if button is Button and button.is_visible_in_tree():
			_check(game.safe_ui.get_global_rect().grow(0.01).encloses(button.get_global_rect()),
				"footer %s stays inside safe bounds" % button.name)
			_check(minf(button.size.x, button.size.y) / garage._preview_dp_scale() >= 47.99,
				"footer %s retains 48dp" % button.name)
			for other in garage.footer.get_children():
				if other is Button and other.is_visible_in_tree() and other.get_index() > button.get_index():
					_check(not button.get_global_rect().intersects(other.get_global_rect()),
						"footer %s and %s have separate touch rectangles" % [button.name, other.name])
	_check(garage.footer.has_node("ResumeRace") == saved, "existing resume action is preserved")
	await _tap(garage.workshop_button)
	_check(is_instance_valid(garage.workshop_view), "actual workshop touch opens its production view")
	if is_instance_valid(garage.workshop_view):
		_check(garage.workshop_view.kart_id == "gecko_velo", "workshop receives the selected kart")
		garage.handle_back()
		await _settle()
	await _footer_touches(garage, saved)
	completed += 1


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.get_node("HostBridge")._options["displayDensity"] = 1.0
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _case(Vector2i(640, 320), false)
	await _case(Vector2i(800, 480), false)
	await _case(Vector2i(640, 320), false)
	# The production garage reads this flag when creating the real resume action.
	game.saved_session_available = true
	game._show_garage()
	await _settle()
	await _case(Vector2i(640, 320), true)
	# Exact real-Android geometry: 90dp cards previously exceeded the 82.29dp
	# scroll area, even after ensure_control_visible aligned the chosen card.
	for saved in [false, true]:
		game.saved_session_available = saved
		game._show_garage()
		await _settle()
		await _case(Vector2i(2400, 1080), saved, 2.625, Rect2(0, 32, 0, 126))
	_check(completed == 6, "all six cases completed without an assertion abort")
	game.abandoned = true
	game.queue_free()
	await _settle()
	print("[CompactKartSelection] ", "PASS" if failures.is_empty() else "FAIL",
		" ", checks, " checks; ", completed, "/6 cases; renderer=", DisplayServer.get_name())
	quit(0 if failures.is_empty() else 1)
