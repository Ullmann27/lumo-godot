extends SceneTree
## Exercises production route ownership, physical touch, resize and selected race.
var failures: Array[String] = []
var checks := 0
var game
var capture := false
var output := "res://exports/spatial-menu"
var expected_pixels := Vector2i.ZERO


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[SpatialMenu] " + label)


func _settle() -> void:
	for _frame in range(8):
		await process_frame
	if capture:
		await RenderingServer.frame_post_draw


func _tap(control: Control) -> void:
	var actual: Rect2 = control.get_global_rect()
	_check(control.is_visible_in_tree(), "%s visible before input" % control.name)
	_check(game.safe_ui.get_global_rect().grow(1).encloses(actual),
		"%s inside safe area: %s in %s" % [control.name, actual, game.safe_ui.get_global_rect()])
	var pixels := actual.get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = pixels
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _shot(label: String) -> void:
	if capture:
		var actual := root.get_texture().get_image()
		_check(actual.get_size() == expected_pixels,
			"%s raster matches requested pixels: %s == %s" % [label, actual.get_size(), expected_pixels])
		_check(actual.save_png(output.path_join(label + ".png")) == OK,
			"%s screenshot is written" % label)
		print("[SpatialMenu] SCREENSHOT ", label, " actual_pixels=", actual.get_size())


func _run() -> void:
	if capture:
		assert(DisplayServer.get_name() != "headless", "Captures require a real renderer")
		DirAccess.make_dir_recursive_absolute(output)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var host = root.get_node("HostBridge")
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829), Vector2i(640, 320)]:
		print("[SpatialMenu] CASE ", dimensions)
		expected_pixels = dimensions
		host._options["displayDensity"] = 1.0
		game = scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.lightweight = true
		await _settle()
		# Desktop production startup deliberately opens at 1280x720. Apply the
		# resize after _ready so a portrait filename cannot hide landscape pixels.
		root.size = dimensions
		await _settle()
		_check(root.size == dimensions, "window reaches the requested physical dimensions")
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(dimensions))
		game._show_reference_landing(true)
		await _settle()
		var garage = game.garage
		var landing = game.reference_landing
		var viewport_id: int = garage.preview_viewport.get_instance_id()
		_check(garage.preview_container.is_visible_in_tree(), "live stage visible under landing")
		_check(garage.preview_container.get_global_rect().size.x >= game.safe_ui.size.x * 0.98,
			"3D stage fills the safe width")
		_check(garage.preview_container.get_global_rect().size.y >= game.safe_ui.size.y * 0.98,
			"3D stage fills the safe height")
		_check(garage.setup.difficulty == "pro", "new setups default to the requested extreme difficulty")
		_check(not garage.world_backdrop.is_visible_in_tree(), "live scene owns the backdrop")
		await _shot("landing-%dx%d" % [dimensions.x, dimensions.y])
		await _tap(landing._mode_buttons.time_trial)
		_check(garage.setup.mode == "time_trial" and game.menu_active, "mode touch selects without starting")
		await _tap(landing._navigation.get_node("Open_garage"))
		_check(garage.step == 2 and not landing.visible, "garage navigation opens real customizer")
		_check(garage.preview_viewport.get_instance_id() == viewport_id, "navigation reuses one live viewport")
		var fleet: GridContainer = garage.choices.get_child(0)
		_check(fleet.get_child_count() == 14, "all existing karts remain reachable")
		var gecko: Button = fleet.get_node("KartCard_gecko_velo")
		garage.choices.get_parent().ensure_control_visible(gecko)
		await _settle()
		await _tap(gecko)
		_check(garage.setup.kart == "gecko_velo" and garage.preview_kart.kart_style == "gecko_velo",
			"touch replaces the actual 3D kart and the race selection")
		await _shot("garage-%dx%d" % [dimensions.x, dimensions.y])
		await _tap(garage.step_buttons[3])
		_check(garage.step == 3 and is_instance_valid(garage.preview_world), "track tab constructs real world geometry")
		_check(not garage.garage_interior.root.visible, "garage walls do not enclose the track preview")
		var road_frame := Rect2(Vector2.ZERO, Vector2(garage.preview_viewport.size))
		var route: Curve3D = garage.preview_world.curve
		var complete_road := true
		for sample in range(96):
			var point: Vector3 = garage.preview_world.to_global(route.sample_baked(route.get_baked_length() * sample / 96.0))
			complete_road = complete_road and road_frame.has_point(garage.preview_camera.unproject_position(point))
		_check(complete_road, "complete drivable road remains inside the track camera")
		await _shot("tracks-%dx%d" % [dimensions.x, dimensions.y])
		await _tap(garage.step_buttons[4])
		_check(garage.step == 4, "difficulty section is directly reachable")
		for action in [garage.back_button, garage.next_button, garage.step_buttons[4]]:
			var dp_scale: float = garage._preview_dp_scale()
			_check(action.size.y / dp_scale >= 47.99, "%s has at least 48dp height" % action.name)
		await _tap(garage.next_button)
		_check(not game.menu_active and game.mode == "time_trial", "start keeps the selected real race mode")
		_check(game.selected_kart == "gecko_velo" and game.difficulty == "pro", "start preserves chosen kart and difficulty")
		_check(is_instance_valid(game.player), "a real playable race is constructed")
		game.queue_free()
		await _settle()
	print("[SpatialMenu] ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " checks; renderer=", DisplayServer.get_name())
	if not failures.is_empty():
		print(JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
