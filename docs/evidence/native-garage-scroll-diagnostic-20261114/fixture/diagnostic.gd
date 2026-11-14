extends SceneTree

# Isolated engine-input diagnostic. These are measured Android image bounds,
# not a claim that this small desktop scene is the Android application.
const CARD = preload("res://scripts/games/kart_vehicle_card.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const CLIP_PX := Rect2(42.0, 416.0, 720.0, 249.0)
const DENSITY := 2.625
const GLYPH_HEIGHT := 29.0
var scroll: ScrollContainer
var cards: Array[Button] = []
var pixel_scale := Vector2.ONE
var glyph_offset := 0.0
var scroll_starts := 0
var scroll_ends := 0
var activations: Array[String] = []
var report: Dictionary = {}

func _initialize() -> void:
	Input.emulate_touch_from_mouse = true
	Engine.max_fps = 60
	call_deferred("_run")

func _settle(frames: int = 4) -> void:
	for unused in range(frames):
		await process_frame

func _physical_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	return Rect2(rect.position * pixel_scale, rect.size * pixel_scale)

func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _glass(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.30, 0.42, 0.96) if selected else Color(0.025, 0.085, 0.18, 0.89)
	style.border_color = Color("65e7f0") if selected else Color(0.4, 0.7, 0.9, 0.26)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(15)
	style.shadow_color = Color(0, 0.02, 0.06, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	return style

func _caption_boxes() -> Array:
	var result: Array = []
	for card in cards:
		var title_rect := _physical_rect(card.title_label)
		var glyph := Rect2(title_rect.position.x, title_rect.position.y + glyph_offset, title_rect.size.x, GLYPH_HEIGHT)
		result.append({"id": card.item.id, "text": card.item.name, "inferred_glyph_box": _rect_data(glyph), "fully_inside_clip": CLIP_PX.encloses(glyph)})
	return result

func _swipe(start: Vector2, finish: Vector2) -> Dictionary:
	var before: int = scroll.scroll_vertical
	var started_before: int = scroll_starts
	var ended_before: int = scroll_ends
	var activated_before: int = activations.size()
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start
	press.pressed = true
	Input.parse_input_event(press)
	await _settle(2)
	var started: int = Time.get_ticks_usec()
	var last := start
	var samples := 0
	while true:
		await process_frame
		var fraction := minf(1.0, float(Time.get_ticks_usec() - started) / 650000.0)
		var next := start.lerp(finish, fraction)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = next
		drag.relative = next - last
		Input.parse_input_event(drag)
		last = next
		samples += 1
		if fraction >= 1.0:
			break
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = finish
	release.pressed = false
	Input.parse_input_event(release)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	await _settle(2)
	var released_offset: int = scroll.scroll_vertical
	await create_timer(1.0).timeout
	return {
		"start_px": [start.x, start.y], "finish_px": [finish.x, finish.y],
		"duration_ms": elapsed_ms, "motion_samples": samples,
		"offset_before_local": before, "offset_after_release_local": released_offset,
		"offset_after_1s_local": scroll.scroll_vertical,
		"offset_after_1s_px": float(scroll.scroll_vertical) * pixel_scale.y,
		"scroll_started_count": scroll_starts - started_before,
		"scroll_ended_count": scroll_ends - ended_before,
		"button_activations": activations.size() - activated_before,
		"captions_after": _caption_boxes()
	}

func _run_case(distance: float, original: bool) -> Dictionary:
	scroll.scroll_vertical = 0
	await _settle(5)
	var actions: Array = []
	var stop_reason := "five_gestures_exhausted"
	for attempt in range(1 if original else 5):
		var visible: Dictionary = {}
		for box in _caption_boxes():
			if box.fully_inside_clip:
				visible = box
				break
		if visible.is_empty():
			stop_reason = "no_complete_caption_after_actual_input"
			break
		if visible.id == "gecko_velo" and not original:
			stop_reason = "gecko_caption_inside_clip"
			break
		var start := Vector2(374, 486)
		if not original:
			var box: Array = visible.inferred_glyph_box
			start.y = float(box[1]) + GLYPH_HEIGHT - (GLYPH_HEIGHT - distance) * 0.5
		var action := await _swipe(start, start - Vector2(0, distance))
		action["attempt"] = attempt + 1
		action["anchor"] = visible
		actions.append(action)
	if original:
		stop_reason = "one_original_distance_completed"
	return {"distance_px": distance, "original_distance": original, "actions": actions, "stop_reason": stop_reason, "final_captions": _caption_boxes()}

func _run() -> void:
	root.size = Vector2i(2400, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await _settle()
	pixel_scale = Vector2(root.size) / root.get_visible_rect().size
	var scale_factor := maxf(root.get_visible_rect().size.x / (float(root.size.x) / DENSITY), root.get_visible_rect().size.y / (float(root.size.y) / DENSITY))
	var surface := Control.new()
	surface.theme = UI.create()
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(surface)
	surface.size = root.get_visible_rect().size
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = CLIP_PX.position / pixel_scale
	scroll.size = CLIP_PX.size / pixel_scale
	surface.add_child(scroll)
	scroll.scroll_started.connect(func(): scroll_starts += 1)
	scroll.scroll_ended.connect(func(): scroll_ends += 1)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 9)
	scroll.add_child(choices)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	choices.add_child(grid)
	for index in range(3):
		var item: Dictionary = FLEET.KARTS[index]
		var card := CARD.new()
		card.item = item
		card.locked = int(item.unlock) > 0
		card.missing_stars = int(item.unlock)
		card.stats = FLEET.base_stats(str(item.id))
		card.custom_minimum_size = Vector2(0, ceilf(90.0 * scale_factor))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.disabled = card.locked
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			card.add_theme_stylebox_override(state, _glass(index == 0))
		card.pressed.connect(func(): activations.append(str(item.id)))
		grid.add_child(card)
		card.apply_size(scale_factor, true)
		cards.append(card)
	await _settle(10)
	glyph_offset = 471.0 - _physical_rect(cards[0].title_label).position.y
	var card_geometry: Array = []
	for card in cards:
		card_geometry.append({"id": card.item.id, "card_rect_px": _rect_data(_physical_rect(card)), "title_control_rect_px": _rect_data(_physical_rect(card.title_label)), "locked": card.locked})
	report = {
		"scope": "Desktop headless Godot touch-input fixture with exact e9a9 card dependencies; not Android, not a screenshot, not full Garage runtime.",
		"source_commit": "e9a9f60f20403ffa6b2b26d1437f958b2704d2aa",
		"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(),
		"touchscreen_available": DisplayServer.is_touchscreen_available(),
		"emulate_touch_from_mouse": Input.emulate_touch_from_mouse,
		"emulate_mouse_from_touch": Input.emulate_mouse_from_touch,
		"scroll_deadzone": scroll.scroll_deadzone,
		"window_px": [root.size.x, root.size.y],
		"viewport": _rect_data(root.get_visible_rect()), "pixels_per_unit": [pixel_scale.x, pixel_scale.y],
		"density": DENSITY, "ui_scale_factor": scale_factor,
		"original_observed_clip_px": _rect_data(CLIP_PX), "actual_fixture_clip_px": _rect_data(_physical_rect(scroll)),
		"inferred_caption_calibration": {"comet_original_ocr_top": 471, "original_ocr_height": GLYPH_HEIGHT, "title_control_glyph_offset": glyph_offset},
		"cards": card_geometry, "initial_captions": _caption_boxes(), "cases": []
	}
	for settings in [[145.0, true], [25.0, false], [27.0, false]]:
		report.cases.append(await _run_case(float(settings[0]), bool(settings[1])))
	var output := FileAccess.open("res://input-diagnostic-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("[GarageInputDiagnostic] " + JSON.stringify(report))
	surface.queue_free()
	await _settle()
	quit(0)
