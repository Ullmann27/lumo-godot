extends SceneTree
## Exercises production route ownership, physical touch, resize and selected race.
var failures: Array[String] = []
var checks := 0
var game
var capture := false
var output := "res://exports/spatial-menu"
var expected_pixels := Vector2i.ZERO
var completed := 0


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


func _tap(control: Control, relative: Vector2 = Vector2(0.5, 0.5)) -> void:
	var actual: Rect2 = control.get_global_rect()
	_check(control.is_visible_in_tree(), "%s visible before input" % control.name)
	_check(game.safe_ui.get_global_rect().grow(1).encloses(actual),
		"%s inside safe area: %s in %s" % [control.name, actual, game.safe_ui.get_global_rect()])
	var pixels := (actual.position + actual.size * relative) * Vector2(root.size) / root.get_visible_rect().size
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
		if not label.begins_with("tracks-"):
			var region := Rect2(0.38, 0.24, 0.58, 0.45)
			if expected_pixels.x < expected_pixels.y:
				region = Rect2(0.10, 0.20, 0.80, 0.28)
			var orange_pixels := 0
			var lit_pixels := 0
			for y in range(int(region.position.y * expected_pixels.y), int(region.end.y * expected_pixels.y), 3):
				for x in range(int(region.position.x * expected_pixels.x), int(region.end.x * expected_pixels.x), 3):
					var pixel := actual.get_pixel(x, y)
					if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.30:
						lit_pixels += 1
					if pixel.r > 0.35 and pixel.r > pixel.g * 1.20 and pixel.r > pixel.b * 1.35:
						orange_pixels += 1
			_check(lit_pixels >= 30 and orange_pixels >= 2,
				"%s renders the lit stage and original orange Lumo: lit=%d orange=%d" % [label, lit_pixels, orange_pixels])
		print("[SpatialMenu] SCREENSHOT ", label, " actual_pixels=", actual.get_size())


func _check_camera_clear(menu) -> void:
	var origin: Vector3 = menu.preview_camera.get_camera_transform().origin
	var obscured_by: Array[String] = []
	for mesh in menu.garage_interior.root.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		for focus in [Vector3(0, 0.75, 0), Vector3(0, 1.5, 0)]:
			if bounds.intersects_segment(origin, focus) != null:
				obscured_by.append(str(mesh.name))
	_check(obscured_by.is_empty(), "physical camera sees the driver through the open studio: " + str(obscured_by))


func _check_subject_clear(menu, blockers: Array) -> void:
	var preview_rect: Rect2 = menu.preview_container.get_global_rect()
	var projected_scale := preview_rect.size / Vector2(menu.preview_viewport.size)
	var covered: Array[String] = []
	var outside: Array[String] = []
	var behind: Array[String] = []
	var subjects := 0
	var subject_rect := Rect2()
	for mesh in menu.preview_kart.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.skin != null or mesh == menu.preview_kart.far_mesh:
			continue
		var bounds: AABB = mesh.get_aabb()
		var rect := Rect2()
		for corner in range(8):
			var point: Vector3 = mesh.to_global(bounds.get_endpoint(corner))
			if menu.preview_camera.is_position_behind(point):
				behind.append(str(mesh.name))
			var pixel: Vector2 = preview_rect.position + menu.preview_camera.unproject_position(point) * projected_scale
			rect = Rect2(pixel, Vector2.ZERO) if corner == 0 else rect.expand(pixel)
		if not preview_rect.grow(0.01).encloses(rect):
			outside.append(str(mesh.name))
		subject_rect = rect if subjects == 0 else subject_rect.merge(rect)
		for blocker in blockers:
			if blocker.is_visible_in_tree() and rect.intersects(blocker.get_global_rect()):
				covered.append("%s/%s" % [mesh.name, blocker.name])
		subjects += 1
	var skeleton: Skeleton3D = menu.preview_kart.lumo_animation.actor.skeleton
	var head: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin)
	for offset in [Vector3.ZERO, Vector3.UP * 0.46, Vector3(0.66, 0.37, 0), Vector3(-0.66, 0.37, 0)]:
		if menu.preview_camera.is_position_behind(head + offset):
			behind.append("Lumo head")
		var pixel: Vector2 = preview_rect.position + menu.preview_camera.unproject_position(head + offset) * projected_scale
		if not preview_rect.has_point(pixel):
			outside.append("Lumo head")
		subject_rect = subject_rect.expand(pixel)
		for blocker in blockers:
			if blocker.is_visible_in_tree() and blocker.get_global_rect().has_point(pixel):
				covered.append("Lumo head/" + str(blocker.name))
	_check(subjects > 0, "real visible chassis geometry is tested against the UI")
	_check(behind.is_empty(), "real chassis and Lumo head are in front of the camera: " + str(behind))
	_check(outside.is_empty(), "real chassis and Lumo head fit inside the actual preview: " + str(outside))
	_check(covered.is_empty(), "real chassis, tyres and Lumo head stay clear of visible controls: " + str(covered))
	var to_pixels := Vector2(root.size) / root.get_visible_rect().size
	print("[SpatialMenu] SUBJECT ", expected_pixels, " landing=", menu._landing_active,
		" meshes=", subjects, " bounds_px=", Rect2(subject_rect.position * to_pixels, subject_rect.size * to_pixels),
		" camera_origin=", menu.preview_camera.get_camera_transform().origin,
		" behind=", behind.size(), " outside=", outside.size(), " UI_overlaps=", covered.size())


func _check_header_touch(menu) -> void:
	if not menu._stage_header.is_visible_in_tree():
		return
	var header_rect: Rect2 = menu._stage_header.get_global_rect()
	var games_rect: Rect2 = menu.learn_button.get_global_rect()
	for tab in menu.step_buttons:
		_check(not header_rect.intersects(tab.get_global_rect()), "header does not overlap " + tab.text)
		_check(not games_rect.intersects(tab.get_global_rect()), "Spielewelt target does not overlap " + tab.text)
	_check(header_rect.grow(0.01).encloses(games_rect), "Spielewelt target fits the actual header")
	_check(minf(games_rect.size.x, games_rect.size.y) / menu._preview_dp_scale() >= 47.99,
		"Spielewelt retains its complete 48dp target")
	var prior_step: int = menu.step
	var emitted: Array[String] = []
	var connections: Array = menu.exit_requested.get_connections()
	for connection in connections:
		menu.exit_requested.disconnect(connection.callable)
	var receive := func(destination: String): emitted.append(destination)
	menu.exit_requested.connect(receive)
	# The lower interior is hidden behind Tempo in the failing Android APK.
	await _tap(menu.learn_button, Vector2(0.5, 0.85))
	_check(emitted == ["games"], "lower Spielewelt touch emits exactly one real games destination")
	_check(menu.step == prior_step, "Spielewelt touch does not switch to the overlapping Tempo tab")
	menu.exit_requested.disconnect(receive)
	for connection in connections:
		menu.exit_requested.connect(connection.callable, connection.flags)
	var to_pixels := Vector2(root.size) / root.get_visible_rect().size
	print("[SpatialMenu] HEADER ", expected_pixels, " density=", root.get_node("MobileRuntime").get_ui_density(),
		" logical=", root.get_visible_rect().size, " root_scale=", to_pixels,
		" header_px=", Rect2(header_rect.position * to_pixels, header_rect.size * to_pixels),
		" tabs_px=", Rect2(menu.step_strip.global_position * to_pixels, menu.step_strip.size * to_pixels),
		" games_touch_px=", (games_rect.position + games_rect.size * Vector2(0.5, 0.85)) * to_pixels,
		" destinations=", emitted, " previous_section=", prior_step, " actual_section=", menu.step)


func _check_landing_raster_scale(landing) -> void:
	var window_dp: Vector2 = Vector2(root.size) / root.get_node("MobileRuntime").get_ui_density()
	var logical_size: Vector2 = root.get_visible_rect().size
	var ui_scale: float = maxf(logical_size.x / window_dp.x, logical_size.y / window_dp.y)
	var available: Vector2 = landing.size / ui_scale
	var narrow := available.x < 520.0
	var horizontal_modes: bool = landing._modes.columns == 3
	_check(landing._layout_root.scale.is_equal_approx(Vector2.ONE),
		"landing text is rasterized at native UI size, without parent magnification")
	var fonts: Array = [
		[landing._stars, 16 if narrow else 22],
		[landing._settings, 16],
		[landing._back, 16],
		[landing._start, 21 if narrow else 25],
	]
	var buttons: Array = [landing._settings, landing._back, landing._start]
	for button in landing._navigation.get_children():
		fonts.append([button, 14 if narrow else 16])
		buttons.append(button)
	for card in landing._mode_buttons.values():
		fonts.append([card.title_label, 13 if horizontal_modes else (16 if available.y < 440 else 20)])
		fonts.append([card.caption_label, 13])
		fonts.append([card.selection_mark, 14])
		buttons.append(card)
	for spec in fonts:
		var physical_font: float = float(spec[0].get_theme_font_size("font_size")) / ui_scale
		_check(absf(physical_font - float(spec[1])) <= 0.51 / ui_scale,
			"landing %s glyphs have %s dp raster size (actual %.3f)" % [spec[0].name, spec[1], physical_font])
	for button in buttons:
		if button.is_visible_in_tree():
			var actual: Rect2 = button.get_global_rect()
			var touch_size := actual.size / ui_scale
			_check(touch_size.x >= 47.99 and touch_size.y >= 47.99,
				"landing %s retains a 48dp touch target: %s" % [button.name, touch_size])
			_check(game.safe_ui.get_global_rect().grow(1.0).encloses(actual),
				"landing %s remains inside the safe area" % button.name)
	print("[SpatialMenu] RASTER ", expected_pixels, " ui_scale=", ui_scale,
		" title_px=", landing._mode_buttons.time_trial.title_label.get_theme_font_size("font_size"),
		" navigation_px=", landing._navigation.get_node("Open_garage").get_theme_font_size("font_size"),
		" back_px=", landing._back.get_theme_font_size("font_size"))


func _run() -> void:
	if capture:
		assert(DisplayServer.get_name() != "headless", "Captures require a real renderer")
		DirAccess.make_dir_recursive_absolute(output)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var host = root.get_node("HostBridge")
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829), Vector2i(640, 320), Vector2i(2400, 1080)]:
		print("[SpatialMenu] CASE ", dimensions)
		expected_pixels = dimensions
		var android_density: bool = dimensions == Vector2i(2400, 1080)
		host._options["displayDensity"] = 2.625 if android_density else 1.0
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
		game._apply_safe_area(Rect2(0, 32, 0, 126) if android_density else Rect2(12, 16, 12, 20), Vector2(dimensions))
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
		_check_camera_clear(garage)
		_check_landing_raster_scale(landing)
		if android_density:
			_check(landing._modes.columns == 1, "Android landscape keeps the three touch-sized modes beside the 3D stage")
			_check(root.get_visible_rect().size.is_equal_approx(Vector2(1600, 720)),
				"Android physical pixels use the production expanded 1280x720 content scale")
			_check_subject_clear(garage, [landing._header, landing._modes, landing._navigation, landing._footer])
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
		_check_camera_clear(garage)
		await _check_header_touch(garage)
		if android_density:
			_check_subject_clear(garage, [garage._stage_header, garage.step_strip, garage.setup_left, garage.footer, garage.view_choice])
			await _tap(garage.step_buttons[1])
			await _check_header_touch(garage)
			await _tap(garage.step_buttons[2])
			await _check_header_touch(garage)
		await _shot("garage-%dx%d" % [dimensions.x, dimensions.y])
		for inspection in [1, 2, 3, 4, 5, 6]:
			garage._choose_preview_view(inspection, false)
			_check(is_zero_approx(garage.preview_camera.h_offset)
				and is_zero_approx(garage.preview_camera.v_offset), "inspection clears the previous stage camera offsets")
			_check_camera_clear(garage)
		garage._choose_preview_view(0, false)
		garage._set_camera_veil(1.0)
		garage._fit_welcome_camera()
		_check(is_zero_approx(float(garage.preview_vignette.material.get_shader_parameter("camera_transition"))),
			"refitting the stage clears an interrupted projection transition")
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
		completed += 1
	_check(completed == 5, "all five requested cases completed without an assertion abort")
	print("[SpatialMenu] ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " checks; ", completed, "/5 cases; renderer=", DisplayServer.get_name())
	if not failures.is_empty():
		print(JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
