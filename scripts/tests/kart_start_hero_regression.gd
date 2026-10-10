extends SceneTree
## Real start-menu layout, touch-to-race and bounded camera motion.
const GARAGE := "res://scripts/games/kart_garage_menu.gd"
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
var checks: int = 0
var failures: Array[String] = []
var starts: Array[Dictionary] = []
var resume_calls: int = 0


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


func _check_saved_start_at_320() -> void:
	var pixels := Vector2i(320, 568)
	var screen_rect := Rect2(Vector2.ZERO, Vector2(pixels))
	root.size = pixels
	var garage = load(GARAGE).new()
	garage.has_saved_race = true
	garage.reduced_motion = true
	# A different initial mode makes selecting the first card observable.
	# The remaining restored choices must survive both quick-start actions.
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
		var card: Button = null
		for candidate in garage.choices.get_child(0).get_children():
			if str(candidate.title) == str(requested.name):
				card = candidate
				break
		_check(is_instance_valid(card), "mode card exists for " + str(requested.id))
		if not is_instance_valid(card):
			continue
		scroll.ensure_control_visible(card)
		await _settle()
		clip = scroll.get_global_rect().intersection(screen_rect)
		_check(await _tap_visible(card, clip), "real touch reaches " + str(requested.name))
		await _settle()
		_check(garage.setup.mode == requested.id, "touch selects " + str(requested.id))
		var play: Button = garage.quick_start_button
		_check(
			play.text == "Spielen · " + str(requested.name), "quick-start names the selected mode"
		)
		_check(_inside(play, pixels), str(requested.name) + " quick-start stays inside 320x568")
		var before_start := starts.size()
		_check(await _tap_visible(play, screen_rect), "real touch reaches the selected quick-start")
		_check(starts.size() == before_start + 1, "selected quick-start emits exactly one start")
		if starts.size() > before_start:
			var expected: Dictionary = restored_setup.duplicate(true)
			expected.mode = requested.id
			_check(
				starts[-1] == expected,
				"quick-start emits " + str(requested.id) + " with the restored track and tempo"
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
	for pixels in [
		Vector2i(1280, 720),
		Vector2i(800, 480),
		Vector2i(412, 915),
		Vector2i(320, 568),
		Vector2i(900, 1360)
	]:
		root.size = pixels
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
		var play: Button = garage.get("quick_start_button")
		_check(is_instance_valid(play), "start screen exposes a playable race entry")
		if is_instance_valid(play):
			_check(
				_inside(play, pixels) and play.size.y >= 44,
				"play has a visible touch target " + str(pixels)
			)
			var before := starts.size()
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = play.get_global_rect().get_center()
			touch.pressed = true
			Input.parse_input_event(touch)
			await process_frame
			touch = touch.duplicate()
			touch.pressed = false
			Input.parse_input_event(touch)
			await process_frame
			_check(starts.size() == before + 1, "real touch emits exactly one race start")
			if starts.size() > before:
				_check(starts[-1] == garage.setup, "race starts with the selected real setup")
		if DisplayServer.get_name() != "headless" and pixels.x in [1280, 800, 412]:
			DirAccess.make_dir_recursive_absolute("res://exports/start-review")
			await _settle()
			_check(
				(
					root.get_texture().get_image().save_png(
						"res://exports/start-review/start-%dx%d.png" % [pixels.x, pixels.y]
					)
					== OK
				),
				"save actual menu frame"
			)
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
