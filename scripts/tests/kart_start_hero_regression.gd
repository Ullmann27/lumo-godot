extends SceneTree
## Real start-menu layout, touch-to-race and bounded camera motion.
const GARAGE := "res://scripts/games/kart_garage_menu.gd"
var checks: int = 0
var failures: Array[String] = []
var starts: Array[Dictionary] = []
var resume_calls: int = 0
var review_output: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[StartHero] FAIL: ", label)


func _settle() -> void:
	for frame in range(5):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _inside(control: Control, pixels: Vector2i) -> bool:
	var rect: Rect2 = control.get_global_rect()
	if rect.end.x > pixels.x + 1 or rect.end.y > pixels.y + 1:
		print("[StartHero] bounds ", control.name, ": ", rect, " window=", pixels)

	return (
		rect.position.x >= -1
		and rect.position.y >= -1
		and rect.end.x <= pixels.x + 1
		and rect.end.y <= pixels.y + 1
	)


func _tap_visible(control: Button, clip: Rect2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.disabled:
		return false
	var target: Rect2 = control.get_global_rect().intersection(clip)
	if target.size.x < 44.0 or target.size.y < 44.0:
		return false
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 7
		touch.position = target.get_center()
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	return true


func _save_review(garage, pixels: Vector2i, file: String) -> void:
	if review_output.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(review_output)
	var image: Image = root.get_texture().get_image()
	assert(image.get_size() == pixels, "review must use the actual requested viewport")
	var path: String = review_output.path_join(file + ".png")
	assert(image.save_png(path) == OK)
	var report := FileAccess.open(review_output.path_join(file + ".json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({
		"image": file + ".png", "sha256": FileAccess.get_sha256(path),
		"size": [pixels.x, pixels.y], "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"menu_step": garage.step, "setup": garage.setup,
		"has_saved_race": garage.has_saved_race, "reduced_motion": garage.reduced_motion,
		"pose_yaw": garage.preview_pivot.rotation.y,
		"camera_position": str(garage.preview_camera.position),
		"camera_fov": garage.preview_camera.fov,
		"next_rect": str(garage.next_button.get_global_rect()),
		"page_rect": str(garage.page_margin.get_global_rect()),
		"render_capture": true, "physical_android_device": false,
	}, "  "))
	report.close()
	print("[StartHero] review ", path, " next=", garage.next_button.get_global_rect())


func _complete_setup(garage, pixels: Vector2i) -> void:
	var before := starts.size()
	var expected: Dictionary = garage.setup.duplicate(true)
	for step in range(5):
		print("[StartHero] touch journey ", pixels, " step=", step)
		_check(garage.step == step, "touch navigation reaches setup step %d" % step)
		_check(not garage.quick_start_button.is_visible_in_tree(), "no duplicate quick-start")
		_check(_inside(garage.next_button, pixels), "single primary action remains in viewport")
		if pixels == Vector2i(1280, 720) and step == 1:
			_save_review(garage, pixels, "driver-1280x720")
		if garage.has_saved_race and garage.setup.mode == "cup" and step == 2:
			_save_review(garage, pixels, "kart-saved-320x568")
		if not _inside(garage.next_button, pixels):
			print("[StartHero] viewport=", root.get_visible_rect(), " root=", root.size)
			for control in [garage, garage.page_margin, garage.body_column, garage.header_row,
				garage.setup_row, garage.setup_left, garage.setup_right, garage.preview_container,
				garage.choices, garage.detail, garage.kart_panel, garage.footer]:
				print("[StartHero] control=", control.name, " rect=", control.get_global_rect(),
					" min=", control.get_combined_minimum_size(), " visible=", control.visible)
			if DisplayServer.get_name() != "headless":
				DirAccess.make_dir_recursive_absolute("res://exports/start-review")
				assert(root.get_texture().get_image().save_png(
					"res://exports/start-review/failing-step-%d.png" % step) == OK)
			return
		_check(
			await _tap_visible(garage.next_button, Rect2(Vector2.ZERO, Vector2(pixels))),
			"real touch reaches the single primary action at step %d" % step
		)
		await _settle()
		_check(starts.size() == before + (1 if step == 4 else 0),
			"only final setup touch emits one race start")
	if starts.size() > before:
		_check(starts[-1] == expected, "race starts with the selected real setup")


func _check_saved_start_at_320() -> void:
	var pixels := Vector2i(320, 568)
	var screen_rect := Rect2(Vector2.ZERO, Vector2(pixels))
	root.size = pixels
	var garage = load(GARAGE).new()
	garage.has_saved_race = true
	garage.reduced_motion = true
	# A different initial mode makes selecting the first card observable.
	# The remaining restored choices must survive both full setup journeys.
	var restored_setup: Dictionary = {
		"mode": "arena",
		"driver": "fox",
		"kart": "comet",
		"track": "zauberwald",
		"difficulty": "flott"
	}
	garage.setup = restored_setup.duplicate(true)
	garage.start_requested.connect(func(setup: Dictionary): starts.append(setup))
	garage.resume_requested.connect(func(): resume_calls += 1)
	root.add_child(garage)
	await _settle()
	garage._apply_responsive_layout()
	await _settle()
	var scroll: ScrollContainer = garage.choices.get_parent()
	var clip: Rect2 = scroll.get_global_rect().intersection(screen_rect)
	_check(
		clip.size.y >= 44.0,
		"saved race leaves at least 44px of visible modes at 320x568 (%.1fpx)" % clip.size.y
	)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://exports/start-review")
		assert(
			(
				root.get_texture().get_image().save_png(
					"res://exports/start-review/start-saved-320x568.png"
				)
				== OK
			)
		)
	var first_mode: Button = garage.choices.get_child(0).get_child(0)
	_check(await _tap_visible(first_mode, clip), "first mode has a real visible 44px touch target")
	await _settle()
	_check(garage.setup.mode == "race", "touch selects the first mode from a different saved mode")
	var resume: Button = garage.footer.get_node_or_null("ResumeRace")
	_check(is_instance_valid(resume), "saved race exposes Fortsetzen")
	if is_instance_valid(resume):
		_check(_inside(resume, pixels), "Fortsetzen stays completely inside 320x568")
		var before_resume := resume_calls
		_check(
			await _tap_visible(resume, screen_rect), "Fortsetzen remains reachable by real touch"
		)
		_check(resume_calls == before_resume + 1, "Fortsetzen touch emits exactly one resume")
	for requested in [
		{"id": "training", "name": "Freies Training"}, {"id": "cup", "name": "Sternen-Cup"}
	]:
		garage.step = 0
		garage._refresh()
		await _settle()
		var card: Button = null
		# Rendered order intentionally follows the user's reference, not CATALOG order.
		for candidate in garage.choices.get_child(0).get_children():
			if candidate.title == requested.name:
				card = candidate
		_check(is_instance_valid(card), "mode card exists for " + str(requested.id))
		if not is_instance_valid(card):
			continue
		scroll.ensure_control_visible(card)
		await _settle()
		clip = scroll.get_global_rect().intersection(screen_rect)
		_check(await _tap_visible(card, clip), "real touch reaches " + str(requested.name))
		await _settle()
		_check(garage.setup.mode == requested.id, "touch selects " + str(requested.id))
		var before_start := starts.size()
		await _complete_setup(garage, pixels)
		_check(starts.size() == before_start + 1, "selected setup emits exactly one start")
		if starts.size() > before_start:
			var expected: Dictionary = restored_setup.duplicate(true)
			expected.mode = requested.id
			_check(
				starts[-1] == expected,
				"setup emits " + str(requested.id) + " with the restored track and tempo"
			)
	garage.queue_free()
	await _settle()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Input.emulate_touch_from_mouse = true
	var garage = load(GARAGE).new()
	garage.reduced_motion = true
	garage.start_requested.connect(func(setup: Dictionary): starts.append(setup))
	root.add_child(garage)
	var sizes: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(800, 480),
		Vector2i(412, 915),
		Vector2i(320, 568),
		Vector2i(900, 1360)
	]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="):
			review_output = arg.trim_prefix("--review-output=")
		if arg == "--saved-only":
			sizes = []
		if arg.begins_with("--only-viewport="):
			var pieces := arg.trim_prefix("--only-viewport=").split("x")
			assert(pieces.size() == 2)
			sizes = [Vector2i(int(pieces[0]), int(pieces[1]))]
	for pixels in sizes:
		root.size = pixels
		garage.step = 0
		garage._refresh()
		await _settle()
		garage._apply_responsive_layout()
		await _settle()
		_check(_inside(garage.next_button, pixels), "setup navigation stays inside " + str(pixels))
		_check(_inside(garage.back_button, pixels), "return navigation stays inside " + str(pixels))
		_check(_inside(garage.preview_container, pixels), "live kart stays inside " + str(pixels))
		if pixels.x < pixels.y:
			_check(
				garage.setup_row.get_child(0) == garage.setup_right,
				"portrait opens with the live Lumo hero"
			)
			_check(
				(
					garage.preview_container.get_global_rect().end.y
					< garage.choices.get_global_rect().position.y
				),
				"mode cards remain below the hero"
			)
		if DisplayServer.get_name() != "headless" and pixels.x in [1280, 800, 412]:
			DirAccess.make_dir_recursive_absolute("res://exports/start-review")
			_check(
				(
					root.get_texture().get_image().save_png(
						"res://exports/start-review/start-%dx%d.png" % [pixels.x, pixels.y]
					)
					== OK
				),
				"save actual menu frame"
			)
		await _complete_setup(garage, pixels)
		if not failures.is_empty():
			garage.queue_free()
			await _settle()
			quit(1)
			return
	garage.step = 0
	garage._refresh()
	await _settle()
	garage.set_process(false)
	garage.reduced_motion = false
	var lowest := INF
	var highest := -INF
	for frame in range(1800):
		garage._process(1.0 / 60.0)
		lowest = minf(lowest, garage.preview_pivot.rotation.y)
		highest = maxf(highest, garage.preview_pivot.rotation.y)
	_check(
		highest - lowest > 0.01 and highest - lowest <= 0.20,
		"idle camera moves gently while keeping Lumo facing the child"
	)
	garage.reduced_motion = true
	garage._process(1.0 / 60.0)
	var still: float = garage.preview_pivot.rotation.y
	for frame in range(120):
		garage._process(1.0 / 60.0)
	_check(
		is_equal_approx(still, garage.preview_pivot.rotation.y),
		"reduced motion holds the start camera still"
	)
	garage.queue_free()
	await _settle()
	await _check_saved_start_at_320()
	print("[StartHero] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print(
			"[StartHero] PASS: live hero, touch race entry, saved resume, selected modes and calm camera"
		)
	quit(0 if failures.is_empty() else 1)
