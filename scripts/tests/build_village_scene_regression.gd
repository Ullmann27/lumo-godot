extends SceneTree
## Real scene integration for the separately launched living village.
## Confirms chapter/UI/3D/market/saving without replacing legacy save slots.
const CHILD := "village_native_scene_regression"
const SLOT := 6
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var density := 1.0
var touch_targets: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageScene] " + message)


func _frames(count := 6) -> void:
	for _index in range(count):
		await process_frame


func _rect(transform: Transform2D, local: Rect2) -> Rect2:
	var rect := Rect2(transform * local.position, Vector2.ZERO)
	for point in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		rect = rect.expand(transform * point)
	return rect


func _pixels(control: Control) -> Rect2:
	return _rect(
		control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas(),
		Rect2(Vector2.ZERO, control.size)
	)


func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null:
			return found
	return null


func _scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _scroll(child)
		if found != null:
			return found
	return null


func _target(control: Control, label: String, exposed := true) -> void:
	_check(is_instance_valid(control), label + " exists")
	if not is_instance_valid(control):
		return
	var pixels := _pixels(control)
	var dp := pixels.size / density
	_check(control.is_visible_in_tree(), label + " is visible")
	_check(minf(dp.x, dp.y) >= 47.99, "%s actual hit area is %s dp" % [label, dp])
	if exposed:
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(0.51).encloses(pixels), label + " fits the display")
		var window := control.get_window()
		_check(_rect(window.get_screen_transform(), window.get_visible_rect()).grow(0.51).encloses(pixels),
			label + " fits its own viewport")
		var ancestor := control.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents:
				_check(_pixels(ancestor).grow(0.51).encloses(pixels), label + " is fully exposed inside its scroll viewport")
			ancestor = ancestor.get_parent()
	touch_targets.append({"surface": [root.size.x, root.size.y], "density": density,
		"label": label, "physical_size": [pixels.size.x, pixels.size.y], "dp": [dp.x, dp.y],
		"fully_exposed_required": exposed})


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _tap(control: Control) -> void:
	var point := _pixels(control).get_center()
	await _touch(point, true)
	await _touch(point, false)
	await _frames()


func _drag(start: Vector2, end: Vector2) -> void:
	await _touch(start, true)
	var previous := start
	for step in range(1, 9):
		var point := start.lerp(end, float(step) / 8.0)
		var event := InputEventScreenDrag.new()
		event.index = 4
		event.position = point
		event.relative = point - previous
		event.screen_relative = event.relative
		event.velocity = event.relative * 60.0
		event.screen_velocity = event.velocity
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		previous = point
		await process_frame
	await _touch(end, false)
	await _frames()


func _reveal_toolbar(village: Node, control: Button) -> bool:
	var ancestor := control.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	_check(ancestor is ScrollContainer, "Village actions use the production scroll toolbar")
	if not ancestor is ScrollContainer:
		return false
	var scroll: ScrollContainer = ancestor
	var before: Dictionary = village.model.snapshot()
	var camera_before: Array = [village.orbit, village.tilt, village.radius, village.focus]
	for attempt in range(24):
		var viewport := _pixels(scroll)
		var target := _pixels(control)
		if viewport.grow(0.51).encloses(target):
			break
		var left := target.end.x > viewport.end.x
		var gap := target.end.x - viewport.end.x if left else viewport.position.x - target.position.x
		var travel := minf(viewport.size.x * 0.64, maxf(24.0 * density, gap + 16.0 * density))
		var start := viewport.position + viewport.size * Vector2(0.82 if left else 0.18, 0.4)
		await _drag(start, start + Vector2(-travel if left else travel, 0.0))
	var exposed := _pixels(scroll).grow(0.51).encloses(_pixels(control))
	_check(exposed, "Real horizontal drags expose " + control.text)
	_check(village.model.snapshot() == before, "Toolbar drags preserve village state")
	_check([village.orbit, village.tilt, village.radius, village.focus] == camera_before,
		"Toolbar drags do not rotate or pan the village underneath")
	if not exposed:
		print("[VillageScene] toolbar diagnostic caption=", control.text, " scroll=", scroll.scroll_horizontal,
			" viewport=", _pixels(scroll), " target=", _pixels(control), " density=", density)
	return exposed


func _capture(stage: String) -> void:
	if capture_dir.is_empty():
		return
	await _frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == root.size, "Actual full renderer surface for " + stage)
	if image != null:
		var name := "village-%s-%dx%d.png" % [stage, root.size.x, root.size.y]
		_check(image.save_png(capture_dir.path_join(name)) == OK, "Saved original renderer image " + name)


func _dialog_scroll(dialog: Window, close: Button) -> void:
	var scroll := _scroll(dialog)
	_check(scroll != null, "Village dialog has a bounded vertical scroll viewport")
	if scroll == null or scroll.get_child_count() == 0:
		return
	var body := scroll.get_child(0)
	var last: Control = body.get_child(body.get_child_count() - 1)
	if scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 1.0:
		var initial := scroll.scroll_vertical
		for attempt in range(12):
			if _pixels(scroll).grow(0.51).encloses(_pixels(last)):
				break
			var area := _pixels(scroll)
			await _drag(area.position + area.size * Vector2(0.5, 0.82), area.position + area.size * Vector2(0.5, 0.18))
		_check(scroll.scroll_vertical > initial, "Actual touch drags scroll the complete village dialog")
		_check(_pixels(scroll).grow(0.51).encloses(_pixels(last)), "The last village description is fully reachable")
		for attempt in range(12):
			if _pixels(scroll).grow(0.51).encloses(_pixels(close)):
				break
			var area := _pixels(scroll)
			await _drag(area.position + area.size * Vector2(0.5, 0.18), area.position + area.size * Vector2(0.5, 0.82))
	_target(close, "close after actual dialog scrolling")


func _surface_checks(village: Node) -> void:
	var original_options: Dictionary = root.get_node("HostBridge")._options.duplicate(true)
	var previous_touch_emulation := Input.emulate_touch_from_mouse
	# Desktop fixtures must enable ScrollContainer's touchscreen path before
	# genuine ScreenTouch/ScreenDrag injection, just like BuildDialogDensity.
	Input.emulate_touch_from_mouse = true
	_check(DisplayServer.is_touchscreen_available() and Input.emulate_mouse_from_touch,
		"The isolated desktop fixture enables Android-style touch routing")
	var profiles := [
		[Vector2i(1280, 720), 1.0, "", "overview"],
		[Vector2i(412, 915), 1.0, "Kapitel", "chapters"],
		[Vector2i(2176, 1812), 2.25, "Tilda · Lieferung", "trader"],
		[Vector2i(640, 360), 1.0, "Stadtkasse", "treasury"],
	]
	for profile in profiles:
		root.size = profile[0]
		density = float(profile[1])
		root.get_node("HostBridge")._options["displayDensity"] = density
		village._layout()
		await _frames(12)
		_check(root.gui_embed_subwindows, "Production village embeds its own dialogs")
		_target(village.day_button, "next village day")
		var before: Dictionary = village.model.snapshot()
		var saved := FileAccess.get_file_as_string(village.save_path)
		var last_purchase: Button = village.purchase_buttons.values()[-1]
		if await _reveal_toolbar(village, last_purchase):
			_target(last_purchase, "last of eleven village buildings")
		var caption: String = profile[2]
		if caption.is_empty():
			await _capture(profile[3])
			continue
		var entry := _button(village, caption)
		_check(entry != null, "Production toolbar contains " + caption)
		if entry == null:
			continue
		if not await _reveal_toolbar(village, entry):
			continue
		_target(entry, "toolbar " + caption)
		await _tap(entry)
		_check(is_instance_valid(village.village_window), "Actual toolbar touch opens " + caption)
		if not is_instance_valid(village.village_window):
			continue
		var dialog: Window = village.village_window
		_check(dialog.is_embedded(), "Village dialog is embedded by production code")
		_check(_pixels(village.safe_ui).grow(0.51).encloses(_rect(dialog.get_screen_transform(), dialog.get_visible_rect())),
			"Village dialog fits the actual safe display area")
		var close := _button(dialog, "Schließen")
		_target(close, "close at dialog opening")
		for child in dialog.find_children("*", "Button", true, false):
			_target(child, "dialog choice " + str(child.text), false)
			_check(_pixels(child).size.x <= _pixels(_scroll(dialog)).size.x + 0.51,
				"Village action text and target fit the dialog width")
		await _capture(profile[3])
		if close != null:
			await _dialog_scroll(dialog, close)
			if caption == "Tilda · Lieferung":
				var dialog_id := dialog.get_instance_id()
				var content_before: Array[String] = []
				for label in dialog.find_children("*", "Label", true, false):
					content_before.append(label.text)
				root.size = Vector2i(640, 360)
				density = 1.0
				root.get_node("HostBridge")._options["displayDensity"] = density
				village._layout()
				await _frames(12)
				_check(_pixels(village.safe_ui).grow(0.51).encloses(_rect(dialog.get_screen_transform(), dialog.get_visible_rect())),
					"An already open village dialog remains bounded after orientation and density change")
				_check(is_instance_valid(village.village_window) and village.village_window.get_instance_id() == dialog_id,
					"Orientation change preserves the same open village dialog instance")
				var content_after: Array[String] = []
				for label in dialog.find_children("*", "Label", true, false):
					content_after.append(label.text)
				_check(content_after == content_before, "Orientation change preserves complete village dialog content")
				_target(close, "close after live orientation and density change")
			await _tap(close)
			_check(not is_instance_valid(dialog), "Actual close touch dismisses " + caption)
		elif is_instance_valid(dialog):
			dialog.queue_free()
			await _frames()
		_check(village.model.snapshot() == before and FileAccess.get_file_as_string(village.save_path) == saved,
			"Opening, scrolling and closing village dialogs preserves exact state and saved bytes")
	root.get_node("HostBridge")._options = original_options
	Input.emulate_touch_from_mouse = previous_touch_emulation
	root.size = Vector2i(1280, 720)
	village._layout()
	await _frames()
	var evidence_dir := OS.get_environment("LUMO_EVIDENCE_DIR")
	if not evidence_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(evidence_dir)
		var file := FileAccess.open(evidence_dir.path_join("village-touch-targets.json"), FileAccess.WRITE)
		_check(file != null, "Village touch evidence can be written")
		if file != null:
			file.store_string(JSON.stringify({"targets": touch_targets, "checks": checks, "failures": failures,
				"scope": "Production controls, real InputEvents and explicit density fixtures; not physical Android or frame-rate evidence"}, "\t"))
			file.close()


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		if DisplayServer.get_name() == "headless" or capture_dir.is_empty():
			push_error("[VillageScene] Capture requires a real renderer and LUMO_CAPTURE_DIR")
			quit(1)
			return
		if DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
			push_error("[VillageScene] Capture directory cannot be created")
			quit(1)
			return
	root.size = Vector2i(1280, 720)
	# SceneRouter is registered after the SceneTree script has loaded. Do not
	# preload production scenes that refer to this autoload at script parse time.
	var world_script = load("res://scripts/creative/build_settlement_world.gd")
	if world_script == null:
		push_error("[VillageScene] Production scene script did not compile")
		quit(1)
		return
	var save: String = world_script.project_path(CHILD, SLOT, "village")
	var classic_save: String = world_script.project_path(CHILD, SLOT, "settlement")
	DirAccess.remove_absolute(save)
	var router := root.get_node("SceneRouter")
	router.launch_options = {
		"childKey": CHILD, "buildSlot": SLOT,
		"settlementMode": "settlement", "livingVillage": true
	}
	var village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	_check(village.model.living_village, "The real village scene launches a version-two economy")
	_check(village.model.snapshot().version == 2, "Village save state uses version two")
	_check(village.save_path == save, "Village has its own save path")
	_check(village.save_path != classic_save, "Classic settlement file is never replaced")
	_check(village.purchase_buttons.size() == 11, "All eleven village buildings are offered")
	_check(
		village.village_region != null
		and village.village_region.get_meta("max_plots_per_town", 0) == 1089,
		"The 1089-plot region is attached to the production scene"
	)
	_check(
		village.village_residents != null
		and village.village_residents.has_node("VillageFamilies"),
		"Nelli/Bruno/Tilda residents render through the actual scene"
	)
	_check(
		village.model.campaign_status().chapter == 1
		and village.goal_label.text.contains("Kapitel 1/12"),
		"The first chapter is displayed in the real HUD"
	)
	_check(
		not village.purchase_buttons["market"].text.contains("Münzen"),
		"The actual market purchase button uses the coin-free village quote"
	)

	village.model._player.resources.coins = 0
	village.selected_plot = 4
	village._buy("market")
	_check(
		village.model._count(village.model.player(), "market") == 1,
		"The real scene builds a market with zero coins"
	)
	_check(
		village.model.player().resources.coins == 0
		and village.model.player().buildings[0].purchase_cost == {"wood": 6, "stone": 4},
		"The market keeps its exact cost receipt without gaining coins"
	)
	_check(FileAccess.file_exists(save), "Village market is saved to the isolated file")

	village._chapter_dialog()
	await _frames(2)
	_check(
		is_instance_valid(village.village_window),
		"The 12-chapter UI opens as a real native dialog"
	)
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)

	village._tilda_dialog()
	await _frames(2)
	_check(
		is_instance_valid(village.village_window),
		"Tilda deliveries can be opened in the real game"
	)
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)

	village._public_project_dialog()
	await _frames(2)
	_check(
		is_instance_valid(village.village_window),
		"The town treasury and project UI is reachable"
	)
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)

	village._pan_village(1, 0)
	_check(
		village.focus.x > -100.0,
		"The village can pan towards new district plots"
	)
	village._zoom_village(1)
	_check(village.radius > 34.0, "The village can zoom out across its large land")

	village.queue_free()
	await _frames(5)
	var restored = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(restored)
	await _frames(8)
	_check(
		restored.model.living_village
		and restored.model._count(restored.model.player(), "market") == 1,
		"The same child resumes the actual version-two village"
	)
	_check(
		restored.model.player().buildings[0].purchase_cost == {"wood": 6, "stone": 4},
		"Save/reload retains the exact market cost receipt"
	)
	await _surface_checks(restored)
	restored.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(save)
	if failures.is_empty():
		print("[VillageScene] PASS checks=", checks, " : production village, chapter, economy and resume")
		quit(0)
	else:
		print("[VillageScene] FAIL checks=", checks, " failures=", failures)
		quit(1)
