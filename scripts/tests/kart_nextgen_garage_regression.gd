extends SceneTree
## Drives the production Kart entry, native selection and two-contact preview.
## --capture requires a renderer and writes actual pixels, never a headless image.
var checks := 0
var failures: Array[String] = []
var capture := false
var game
var output := "res://exports/nextgen-garage"
var records: Array[Dictionary] = []


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[NextGenGarage] " + label)


func _settle(frames: int = 5) -> void:
	for _frame in range(frames):
		await process_frame
	if capture:
		await RenderingServer.frame_post_draw


func _tap(button: Control) -> void:
	_check(button.is_visible_in_tree(), str(button.name) + " is visible before touch")
	var pixel: Vector2 = button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	await _touch(0, pixel, true)
	await _touch(0, pixel, false)
	await _settle()


func _touch(index: int, point: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	await process_frame


func _drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	Input.parse_input_event(event)
	await process_frame


func _shot(label: String, menu) -> void:
	if not capture:
		return
	await _settle()
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == root.size, label + " has actual requested raster")
	if image == null:
		return
	_check(image.save_png(output.path_join(label + ".png")) == OK, label + " PNG saved")
	records.append({"name": label, "width": image.get_width(), "height": image.get_height(),
		"draw_calls": menu.preview_draw_calls(), "zoom": menu._camera_zoom,
		"selected_kart": menu.setup.kart, "host_behavior": menu.service_station.host.current_behavior,
		"renderer": RenderingServer.get_current_rendering_method()})


func _host_visible_in_region(menu) -> void:
	var pixels := Vector2(menu.preview_viewport.size)
	var normalized: Rect2 = menu._visible_stage_region()
	var safe := Rect2(normalized.position * pixels, normalized.size * pixels)
	var outside := 0
	var points: Array[Vector3] = menu.service_station.subject_points()
	for point in points:
		if menu.preview_camera.is_position_behind(point) or not safe.has_point(menu.preview_camera.unproject_position(point)):
			outside += 1
	_check(points.size() == 130 and outside == 0, "original standing body, ears and hands fit clear stage (%d outside)" % outside)


func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("[NextGenGarage] --capture requires real rendered pixels")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var host = root.get_node("HostBridge")
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(2400, 1080)]:
		host._options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
		game = scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await _settle()
		root.size = dimensions
		await _settle()
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(dimensions))
		game._show_reference_landing(true)
		await _settle()
		await _tap(game.reference_landing._navigation.get_node("Open_garage"))
		var menu = game.garage
		var station = menu.service_station
		_check(menu.step == 2 and station.host.is_visible_in_tree(), "production Garage entry reveals original standing host")
		_check(station.host.is_usable() and station.host.skeleton.get_bone_count() == 65, "original imported 65-bone asset is live")
		_check(not menu.preview_kart.lumo_animation.visible, "the same fox is not duplicated in his kart")
		_check(station.find_child("BalancedWheel", true, false) != null and station.find_child("ToolSteel", true, false) is MultiMeshInstance3D,
			"actual balancing wheel and batched workshop tools are installed")
		_check(station.find_children("*", "CollisionObject3D", true, false).is_empty(), "workshop decoration adds no gameplay collider")
		_host_visible_in_region(menu)
		await _shot("garage-%dx%d" % [dimensions.x, dimensions.y], menu)
		var original_host_id: int = station.host.get_instance_id()
		var previous_selection_count: int = station.selection_count
		var cards: GridContainer = menu.choices.get_child(0)
		var selected: Button = cards.get_node("KartCard_gecko_velo")
		menu.choices.get_parent().ensure_control_visible(selected)
		await _settle()
		await _tap(selected)
		_check(menu.setup.kart == "gecko_velo" and menu.preview_kart.kart_style == "gecko_velo", "native card touch changes actual selected kart")
		_check(station.host.get_instance_id() == original_host_id, "host survives vehicle replacement")
		_check(station.selection_count == previous_selection_count + 1 and station.host.current_behavior == "point_portal", "new selection triggers one original explanatory gesture")
		var before_wheel: float = station.balance_wheel.rotation.z
		station.advance(0.15)
		_check(not is_equal_approx(before_wheel, station.balance_wheel.rotation.z), "selection drives visible real wheel rotation")
		await _shot("selection-%dx%d" % [dimensions.x, dimensions.y], menu)
		var preview_rect: Rect2 = menu.preview_container.get_global_rect()
		var region: Rect2 = menu._visible_stage_region()
		var center: Vector2 = (preview_rect.position + preview_rect.size * region.get_center()) * Vector2(root.size) / root.get_visible_rect().size
		var spread: float = minf(dimensions.x, dimensions.y) * 0.07
		var first := center - Vector2(spread, 0)
		var second := center + Vector2(spread, 0)
		var initial_angle: float = menu.preview_angle
		var initial_distance: float = menu.preview_camera.position.distance_to(menu._camera_focus)
		await _touch(3, first, true)
		await _touch(4, second, true)
		await _drag(4, second + Vector2(spread * 0.5, 0), Vector2(spread * 0.5, 0))
		_check(menu._pinch.captured and menu._camera_zoom < 1.0, "real two-contact drag zooms production camera")
		_check(menu.preview_camera.position.distance_to(menu._camera_focus) < initial_distance, "pinch moves the actual camera closer")
		await _touch(4, second + Vector2(spread * 0.5, 0), false)
		await _drag(3, first + Vector2(20, 0), Vector2(20, 0))
		await _touch(3, first + Vector2(20, 0), false)
		_check(is_equal_approx(menu.preview_angle, initial_angle) and not menu.rotate_drag and menu._preview_touch_index == -1,
			"remaining pinch finger cannot become a drag or click")
		_check(menu.step == 2 and menu.setup.kart == "gecko_velo", "pinch release does not alter selection or navigate")
		await _shot("zoom-%dx%d" % [dimensions.x, dimensions.y], menu)
		await _touch(5, center, true)
		await _drag(5, center + Vector2(35, 0), Vector2(35, 0))
		await _touch(5, center + Vector2(35, 0), false)
		_check(not is_equal_approx(menu.preview_angle, initial_angle), "fresh single-finger gesture still rotates actual kart")
		menu.reduced_motion = true
		menu._sync_workshop_host()
		station.react_to_selection()
		var reduced_angle: float = station.balance_wheel.rotation.z
		station.advance(0.3)
		_check(is_equal_approx(reduced_angle, station.balance_wheel.rotation.z) and not station.host.player.is_playing(), "reduced motion freezes wheel and authored character clip")
		menu.reduced_motion = false
		menu._sync_workshop_host()
		menu._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(station.host.suspended and not station.host.visible and menu._pinch.contacts.is_empty(), "background clears gesture and suspends original host")
		menu._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		menu._sync_workshop_host()
		_check(station.host.visible and not station.host.suspended, "return restores the active workshop host")
		await _tap(menu.step_buttons[1])
		_check(not station.host.visible and menu.preview_kart.lumo_animation.visible, "driver inspection restores actual seated driver without duplicate fox")
		_check(is_equal_approx(menu._camera_zoom, 1.0), "new section restores complete default framing")
		game.queue_free()
		await _settle()
	if capture:
		var manifest := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
		_check(manifest != null, "capture manifest can be written")
		if manifest != null:
			manifest.store_string(JSON.stringify(records, "\t"))
			manifest.close()
	print("[NextGenGarage] ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " checks; captures=", records.size())
	quit(0 if failures.is_empty() else 1)
