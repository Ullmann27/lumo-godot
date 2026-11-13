extends SceneTree
## Real native input through the production Kart scene. Renderer captures use
## this same navigation path, with no injected race results or replacement art.
var failures: Array[String] = []
var checks := 0
var game
var capture := false
var baseline := false
var marker := "[KartHomeExperience]"
var output := "res://exports/kart-home-experience"
var captures: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(marker + " " + label)


func _settle(frames: int = 8) -> void:
	for _frame in range(frames):
		await process_frame
	if capture:
		await RenderingServer.frame_post_draw


func _rest_camera() -> void:
	await create_timer(0.65).timeout
	await _settle()


func _tap(control: Control) -> void:
	_check(control.is_visible_in_tree(), "%s is visible for actual touch" % control.name)
	var rect := control.get_global_rect()
	_check(game.safe_ui.get_global_rect().grow(1).encloses(rect), "%s stays in the safe area" % control.name)
	var position := rect.get_center() * Vector2(root.size) / root.get_visible_rect().size
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = position
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _shot(label: String, dimensions: Vector2i) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), label + " has a real viewport image")
	if image == null or image.is_empty():
		return
	_check(image.get_size() == dimensions, label + " has the requested physical dimensions")
	var destination := output.path_join(label + ".png")
	_check(image.save_png(destination) == OK, label + " PNG is saved")
	captures.append({
		"file": label + ".png", "width": dimensions.x, "height": dimensions.y,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"renderer": DisplayServer.get_name(), "baseline": baseline,
		"menu_active": game.menu_active, "mode": str(game.garage.setup.mode),
	})
	print(marker, " CAPTURE ", destination)


func _check_touch_targets(landing) -> void:
	var dp: Vector2 = Vector2(root.size) / root.get_node("MobileRuntime").get_ui_density()
	var logical := root.get_visible_rect().size
	var ui_scale := maxf(logical.x / dp.x, logical.y / dp.y)
	var buttons: Array = landing._mode_buttons.values() + landing._navigation.get_children()
	buttons.append_array([landing._back, landing._start, landing._settings])
	for button in buttons:
		if not button.is_visible_in_tree():
			continue
		var target: Vector2 = button.size / ui_scale
		_check(minf(target.x, target.y) >= 47.99, "%s is at least 48dp: %s" % [button.name, target])
		_check(game.safe_ui.get_global_rect().grow(1).encloses(button.get_global_rect()), "%s fits safe bounds" % button.name)


func _check_home_world(garage) -> void:
	if baseline:
		return
	var home = garage.home_promenade
	_check(is_instance_valid(home) and home.is_visible_in_tree(), "outdoor home is connected to the visible production stage")
	_check(not garage.garage_interior.root.is_visible_in_tree(), "garage room gives way only while Home is active")
	_check(home.get_node_or_null("OriginalHarborWavePavilion") != null, "original authored harbor pavilion is reused")
	_check(home.get_node_or_null("HomeScenicCoastalRoad") != null, "middle-distance coastal road is real geometry")
	_check(home.get_node_or_null("DistantCoastalLoop") != null, "distant loop creates a layered skyline")
	_check(home.find_children("*", "CollisionObject3D", true, false).is_empty(), "Home does not start another racing physics simulation")
	_check(home.find_children("HomeBatch_*", "MultiMeshInstance3D", true, false).size() <= 12, "repeated scenery uses bounded material batches")
	_check(is_instance_valid(garage.preview_kart.lumo_animation.actor.skeleton), "original animated Lumo remains on the selected kart")
	var elapsed_before: float = home.elapsed
	await create_timer(0.12).timeout
	_check(home.elapsed > elapsed_before, "visible water, pennants and boats advance")
	garage.reduced_motion = true
	garage._sync_home_stage()
	garage._advance_home_camera(0.0)
	var stopped_time: float = home.elapsed
	var stopped_camera: Transform3D = garage.preview_camera.transform
	await _settle(12)
	_check(is_equal_approx(home.elapsed, stopped_time), "reduced motion freezes the actual scenery clock")
	_check(garage.preview_camera.transform.is_equal_approx(stopped_camera), "reduced motion removes the camera dolly")
	garage.reduced_motion = false
	garage._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	await _settle()
	var paused_time: float = home.elapsed
	await _settle(12)
	_check(not home.active and is_equal_approx(home.elapsed, paused_time), "application pause stops Home activity")
	garage._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	await _settle()
	_check(home.active, "application resume restores the same Home stage")


func _run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	if baseline and not capture:
		_check(false, "baseline is only valid for the explicit comparison capture")
		quit(1)
		return
	if capture:
		_check(DisplayServer.get_name() != "headless", "capture requires a real renderer")
		if DisplayServer.get_name() == "headless":
			quit(1)
			return
		var requested := OS.get_environment("LUMO_CAPTURE_DIR")
		if not requested.is_empty():
			output = requested
		DirAccess.make_dir_recursive_absolute(output)
	var host := root.get_node("HostBridge")
	host._options["displayDensity"] = 1.0
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var completed := 0
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829), Vector2i(640, 320)]:
		print(marker, " CASE ", dimensions)
		game = scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.lightweight = true
		await _settle()
		root.size = dimensions
		await _settle()
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(dimensions))
		game._show_reference_landing(true)
		await _rest_camera()
		var garage = game.garage
		var landing = game.reference_landing
		var viewport_id: int = garage.preview_viewport.get_instance_id()
		_check_touch_targets(landing)
		await _check_home_world(garage)
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		await _shot("home-" + suffix, dimensions)
		await _tap(landing._mode_buttons.time_trial)
		_check(garage.setup.mode == "time_trial" and game.menu_active, "real mode touch selects Time Trial without starting")
		if not baseline:
			var moving: Transform3D = garage.preview_camera.transform
			await _shot("mode-transition-" + suffix, dimensions)
			await _rest_camera()
			_check(not moving.is_equal_approx(garage.preview_camera.transform), "mode selection performs an actual bounded camera transition")
		await _shot("selected-time-trial-" + suffix, dimensions)
		await _tap(landing._navigation.get_node("Open_garage"))
		await _rest_camera()
		_check(garage.step == 2 and not landing.visible, "Garage touch opens the existing customizer")
		_check(garage.preview_viewport.get_instance_id() == viewport_id, "Garage reuses the same real 3D viewport")
		if not baseline:
			_check(not garage.home_promenade.active and garage.garage_interior.root.is_visible_in_tree(), "Garage restores the authored indoor service bay")
		var fleet: GridContainer = garage.choices.get_child(0)
		var gecko: Button = fleet.get_node("KartCard_gecko_velo")
		garage.choices.get_parent().ensure_control_visible(gecko)
		await _settle()
		await _tap(gecko)
		_check(garage.setup.kart == "gecko_velo", "actual kart choice is preserved")
		await _shot("garage-selected-" + suffix, dimensions)
		await _tap(garage.back_button)
		await _rest_camera()
		landing = game.reference_landing
		_check(landing.visible and garage._landing_active, "Back returns through the actual Home navigation")
		_check(garage.preview_kart.kart_style == "gecko_velo", "Home displays the newly selected real kart")
		_check(garage.preview_viewport.get_instance_id() == viewport_id, "return does not create a second viewport")
		await _shot("home-return-" + suffix, dimensions)
		await _tap(landing._start)
		_check(not game.menu_active and is_instance_valid(game.player), "START constructs a real playable race")
		_check(game.mode == "time_trial" and game.selected_kart == "gecko_velo", "START keeps selected mode and kart")
		await _shot("race-start-" + suffix, dimensions)
		game.queue_free()
		await _settle()
		completed += 1
	_check(completed == 4, "all four viewport cases completed")
	if capture:
		var file := FileAccess.open(output.path_join("home-render.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"baseline": baseline, "captures": captures, "checks": checks, "failures": failures}, "\t"))
			file.close()
		else:
			_check(false, "render receipt is written")
	print(marker, " PASS" if failures.is_empty() else " FAIL", " checks=", checks,
		" cases=", completed, "/4 baseline=", baseline, " renderer=", DisplayServer.get_name())
	quit(0 if failures.is_empty() else 1)
