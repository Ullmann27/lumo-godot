extends SceneTree
## Production Garage -> workshop, measured through the actual canvas transform.
## Headless mode checks live controls/input only. --capture requires a renderer.

const TUNING = preload("res://scripts/games/kart_tuning.gd")
const PROFILES := [
	[Vector2i(1280, 720), 1.0],
	[Vector2i(640, 360), 1.0],
	[Vector2i(640, 320), 1.0],
	[Vector2i(412, 915), 1.0],
	[Vector2i(690, 829), 1.0],
	[Vector2i(2400, 1080), 2.625],
	[Vector2i(1080, 2400), 2.625],
	[Vector2i(2176, 1812), 2.25],
]

var game
var workshop
var density := 1.0
var checks := 0
var failures: Array[String] = []
var capture := false
var output := "res://exports/workshop-density"
var images: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var previous_touch_emulation := false
var completed_swipes := 0


func _initialize() -> void:
	# Enable Godot's touchscreen ScrollContainer path on the desktop runner.
	# Gestures below still enter through actual ScreenTouch/ScreenDrag events.
	previous_touch_emulation = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	capture = "--capture" in OS.get_cmdline_user_args()
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("[WorkshopDensity] " + message)


func _settle(frames: int = 4) -> void:
	for frame in range(frames):
		await process_frame


func _pixels_per_unit() -> Vector2:
	return Vector2(root.size) / root.get_visible_rect().size


func _physical_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	return Rect2(rect.position * _pixels_per_unit(), rect.size * _pixels_per_unit())


func _target(control: Control, label: String, in_scroll: bool = false) -> void:
	var rect := _physical_rect(control)
	var dp := rect.size / density
	_check(control.is_visible_in_tree(), label + " is visible")
	_check(
		minf(dp.x, dp.y) >= 47.99,
		"%s actual target is %s dp at %s / %.3f" % [label, dp, root.size, density]
	)
	var surface := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(surface.grow(0.51).encloses(rect), label + " is wholly inside the physical surface")
	_check(
		_physical_rect(game.safe_ui).grow(0.51).encloses(rect),
		label + " is wholly inside the inherited safe area"
	)
	if in_scroll:
		_check(
			_physical_rect(workshop.right_scroll).grow(0.51).encloses(rect),
			(
				"%s is wholly exposed by its real scroll viewport: target=%s viewport=%s"
				% [label, rect, _physical_rect(workshop.right_scroll)]
			)
		)
	targets.append(
		{
			"surface": [root.size.x, root.size.y],
			"density": density,
			"label": label,
			"physical_size": [rect.size.x, rect.size.y],
			"dp": [dp.x, dp.y]
		}
	)


func _reveal(control: Control, label: String) -> void:
	workshop.right_scroll.ensure_control_visible(control)
	await _settle()
	# Scroll offsets are integral canvas units. On the 2.25-density Fold,
	# ensure_control_visible can leave 0.7 physical pixels below the viewport.
	# Scroll the final partial unit into view; keep the full-rectangle gate.
	var rect := control.get_global_rect()
	var viewport: Rect2 = workshop.right_scroll.get_global_rect()
	if rect.end.y > viewport.end.y:
		workshop.right_scroll.scroll_vertical += ceili(rect.end.y - viewport.end.y)
	elif rect.position.y < viewport.position.y:
		workshop.right_scroll.scroll_vertical -= ceili(viewport.position.y - rect.position.y)
	await _settle(2)
	_target(control, label, true)


func _tap(control: Control, edge: bool = false) -> void:
	_check(control.is_visible_in_tree(), "Input target must be visible: " + str(control.name))
	if control is BaseButton:
		_check(not control.disabled, "Input target must be enabled: " + str(control.name))
	var rect := _physical_rect(control)
	var point := rect.get_center()
	if edge:
		# At +/-22dp, the old 24dp-high workshop target cannot receive this tap.
		# This verifies the live hit area, not only a minimum-size declaration.
		point.y += 22.0 * density
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = point
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _settle(2)


func _swipe_without_action(control: Button, label: String) -> void:
	# Start on the actual button, not a blank gap or an assigned scroll value.
	# A drag must scroll and cancel the pending click, including paid actions.
	await _reveal(control, label + " swipe start")
	var before_scroll: int = workshop.right_scroll.scroll_vertical
	var bar: VScrollBar = workshop.right_scroll.get_v_scroll_bar()
	var point := _physical_rect(control).get_center()
	var direction := -1.0 if float(before_scroll) < (bar.max_value - bar.page) * 0.5 else 1.0
	var available_pixels := (
		point.y - 4.0 * density if direction < 0.0 else float(root.size.y) - point.y - 4.0 * density
	)
	var distance := minf(100.0 * density, available_pixels)
	_check(distance >= 20.0 * density, label + " has room for a real finger swipe")
	var balance: int = workshop.tuning.available()
	var levels: Dictionary = workshop.tuning.levels.duplicate(true)
	var looks: Dictionary = workshop.tuning.looks.duplicate(true)
	var owned: Array[String] = workshop.tuning.owned.duplicate()
	var pending: Dictionary = workshop.pending_option.duplicate(true)
	var activations := {"count": 0}
	var on_pressed := func(): activations.count += 1
	control.pressed.connect(on_pressed)
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.position = point
	press.pressed = true
	Input.parse_input_event(press)
	await _settle(2)
	for step in range(5):
		var next := point + Vector2(0.0, direction * distance / 5.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 7
		drag.position = next
		drag.relative = next - point
		Input.parse_input_event(drag)
		point = next
		await _settle(2)
	# A controlled swipe ends with a stationary finger, rather than a fling.
	await create_timer(0.22).timeout
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = point
	release.pressed = false
	Input.parse_input_event(release)
	await _settle(5)
	control.pressed.disconnect(on_pressed)
	var after_scroll: int = workshop.right_scroll.scroll_vertical
	_check(
		(after_scroll - before_scroll) * direction < 0.0,
		label + " finger swipe scrolls in the intended direction"
	)
	_check(activations.count == 0, label + " swipe never activates its button")
	_check(workshop.tuning.available() == balance, label + " swipe never spends or refunds stars")
	_check(
		(
			workshop.tuning.levels == levels
			and workshop.tuning.looks == looks
			and workshop.tuning.owned == owned
		),
		label + " swipe preserves all upgrades and appearance ownership"
	)
	_check(
		workshop.pending_option == pending, label + " swipe never changes the appearance preview"
	)
	print(
		"[WorkshopDensity] SWIPE ",
		label,
		" ",
		before_scroll,
		" -> ",
		after_scroll,
		" activations=",
		activations.count
	)
	completed_swipes += 1


func _shot(stage: String) -> void:
	# The two density-2.625 layouts are the real renderer evidence. Smaller
	# desktop cases still execute every input/layout assertion in the matrix.
	if not capture or not is_equal_approx(density, 2.625):
		return
	await _settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(
		image != null and image.get_size() == root.size,
		"Capture is the actual current renderer surface"
	)
	if image == null:
		return
	_check(
		mini(image.get_width(), image.get_height()) >= 360,
		"Capture is large enough for visual review"
	)
	var name := "workshop-%dx%d-%s.png" % [root.size.x, root.size.y, stage]
	_check(image.save_png(output.path_join(name)) == OK, "Original renderer PNG saved: " + name)
	images.append(
		{
			"filename": name,
			"width": image.get_width(),
			"height": image.get_height(),
			"density": density,
			"renderer": RenderingServer.get_current_rendering_method()
		}
	)


func _exercise_workshop() -> void:
	_target(workshop.back_button, "workshop return")
	await _reveal(workshop.dyno_button, "performance simulation")
	await _swipe_without_action(workshop.dyno_button, "performance simulation")
	_check(
		workshop.dyno_time <= 0.0,
		"Scrolling from the performance button never starts the simulation"
	)
	await _reveal(workshop.dyno_button, "performance simulation after swipe")
	await _shot("performance")
	await _tap(workshop.dyno_button, true)
	_check(workshop.dyno_time > 0.0, "Actual edge tap starts the performance simulation")
	var before_resize := _physical_rect(workshop.back_button).size
	for repeat in range(3):
		workshop._apply_layout()
		await _settle(2)
	_check(
		_physical_rect(workshop.back_button).size.is_equal_approx(before_resize),
		"Repeated layout never compounds the density scale"
	)
	for part in TUNING.PARTS:
		var id := str(part.id)
		var button: Button = workshop.part_rows[id].button
		await _reveal(button, "upgrade " + id)
		if id == str(TUNING.PARTS[0].id):
			await _swipe_without_action(button, "upgrade " + id)
			await _reveal(button, "upgrade after swipe " + id)
		var before: int = workshop.tuning.level(workshop.kart_id, id)
		await _tap(button, true)
		_check(
			workshop.tuning.level(workshop.kart_id, id) == before + 1,
			"Actual edge tap upgrades " + id
		)
	for kind in TUNING.KINDS:
		var row: Dictionary = workshop.swatch_rows[kind]
		for option in TUNING.options(kind):
			var id := str(option.id)
			var swatch: Button = row.buttons[id]
			await _reveal(swatch, kind + " swatch " + id)
			if kind == "paint" and id == "feuer":
				await _swipe_without_action(swatch, "paint swatch")
				await _reveal(swatch, "paint swatch after swipe")
			var balance: int = workshop.tuning.available()
			await _tap(swatch, true)
			_check(
				workshop.tuning.available() == balance,
				"Preview alone never spends stars: " + kind + "/" + id
			)
			if workshop.tuning.has_option(kind, id):
				_check(
					workshop.tuning.chosen(workshop.kart_id, kind) == id,
					"Actual swatch touch selects owned " + kind + "/" + id
				)
			else:
				_check(
					workshop.pending_option.get(kind) == id,
					"Actual swatch touch previews " + kind + "/" + id
				)
				await _reveal(row.buy, "purchase " + kind)
				if kind == "paint" and id == "feuer":
					await _swipe_without_action(row.buy, "paid paint purchase")
					await _reveal(row.buy, "paid purchase after swipe")
					await _shot("paint-purchase")
				await _tap(row.buy, true)
				_check(
					workshop.tuning.has_option(kind, id),
					"Actual edge tap purchases " + kind + "/" + id
				)
				_check(
					workshop.tuning.chosen(workshop.kart_id, kind) == id,
					"Purchase selects its exact appearance"
				)
				_check(
					workshop.tuning.available() == balance - int(option.cost),
					"Purchase preserves exact star accounting"
				)
	await _reveal(workshop.refund_button, "refund all parts")
	await _swipe_without_action(workshop.refund_button, "refund all parts")
	_check(workshop.refund_armed <= 0.0, "Scrolling from refund never arms the confirmation")
	await _reveal(workshop.refund_button, "refund after swipe")
	await _shot("refund")
	var paid: int = workshop.tuning.spent_on_parts()
	var available: int = workshop.tuning.available()
	var looks: Dictionary = workshop.tuning.looks.duplicate(true)
	await _tap(workshop.refund_button, true)
	_check(
		workshop.refund_armed > 0.0 and workshop.tuning.spent_on_parts() == paid,
		"First refund tap only arms confirmation"
	)
	await _reveal(workshop.refund_button, "refund confirmation")
	await _tap(workshop.refund_button, true)
	_check(
		workshop.tuning.spent_on_parts() == 0 and workshop.tuning.available() == available + paid,
		"Second real tap refunds every part exactly"
	)
	_check(workshop.tuning.looks == looks, "Refund preserves all selected appearance options")
	_target(workshop.back_button, "workshop return after bottom scroll")
	await _tap(workshop.back_button, true)
	_check(
		not is_instance_valid(game.garage.workshop_view),
		"Actual 48dp edge return tap closes the production workshop"
	)
	_check(
		game.garage.step == 2 and game.garage.is_visible_in_tree(),
		"Return retains the actual selected garage step"
	)


func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("[WorkshopDensity] --capture requires a real renderer, never headless PNGs")
		quit(1)
		return
	if capture:
		DirAccess.make_dir_recursive_absolute(output)
	var host = root.get_node("HostBridge")
	host._options = {
		"soundEnabled": false, "reduceAnimations": true, "childKey": "workshop-density-regression"
	}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle(12)
	for index in range(PROFILES.size()):
		var sample: Array = PROFILES[index]
		density = float(sample[1])
		host._options["displayDensity"] = density
		root.size = sample[0]
		await _settle(8)
		game._apply_safe_area(Rect2(12, 16, 12, 20), Vector2(root.size))
		game._apply_responsive_layout()
		game._show_reference_landing(true)
		await _settle(8)
		var open_garage: Button = game.reference_landing._navigation.get_node("Open_garage")
		_target(open_garage, "production garage entry")
		await _tap(open_garage)
		_check(game.garage.step == 2, "Real landing touch opens the garage step")
		# Isolated in-memory budget only: no real child state or persisted stars.
		var tuning = TUNING.new("workshop-density-regression-%d" % index, 500)
		tuning.save_enabled = false
		tuning.levels.clear()
		tuning.looks.clear()
		tuning.owned.clear()
		tuning.lifetime_stars = 500
		game.garage.workshop = tuning
		game.garage.setup.kart = "comet"
		game.garage._refresh()
		await _settle(8)
		_target(game.garage.workshop_button, "production workshop entry")
		await _tap(game.garage.workshop_button)
		workshop = game.garage.workshop_view
		_check(
			is_instance_valid(workshop), "Real Garage -> workshop touch opens the connected view"
		)
		if not is_instance_valid(workshop):
			break
		await _settle(8)
		await _exercise_workshop()
		print("[WorkshopDensity] CASE ", sample, " checks=", checks, " failures=", failures.size())
	_check(
		completed_swipes == PROFILES.size() * 5,
		"Every required button swipe completed without an aborted helper"
	)
	if capture:
		_check(
			images.size() == 6,
			"Six genuine performance, palette/purchase and bottom-scroll captures"
		)
		var record := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
		record.store_string(
			JSON.stringify(
				{
					"images": images,
					"targets": targets,
					"scope":
					"desktop renderer + explicit density fixtures, not a physical Android device"
				},
				"\t"
			)
		)
	game.queue_free()
	await _settle(6)
	Input.emulate_touch_from_mouse = previous_touch_emulation
	if failures.is_empty():
		print(
			(
				"[WorkshopDensity] PASS %d checks: eight layouts, actual >=48dp canvas targets, all palette/upgrade/purchase/refund/return touches"
				% checks
			)
		)
		quit(0)
	else:
		push_error("[WorkshopDensity] FAIL %d of %d checks" % [failures.size(), checks])
		quit(1)
