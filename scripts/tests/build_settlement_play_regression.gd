extends SceneTree
## Actual Bauwelt -> Wettbau navigation, 3D plot input, paid facilities, fair
## neighbor turns, persistence, lifecycle and responsive action targets.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var city
const CHILD := "settlement_production_regression"
const SLOT := 3


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[SettlementPlay] " + message)


func _frames(count := 6) -> void:
	for _i in range(count):
		await physics_frame


func _tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 4
		event.position = point * Vector2(root.size) / root.get_visible_rect().size
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await _frames(2)


func _world_release_over_hud() -> void:
	var from: Vector2 = city.camera.unproject_position(city.plot_position(4) + Vector3.UP * 0.08)
	var to: Vector2 = city.day_button.get_global_rect().get_center()
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.position = from * factor
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = to * factor
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _frames(2)
	_check(city.pointer == -1, "World touch releases ownership over HUD")
	_check(city.selected_plot == -1 and city.model.day == 1, "World release cannot buy or advance a day through the HUD")


func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _button(child, caption)
		if found != null:
			return found
	return null


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == Vector2i(1280, 720), "Actual renderer image: " + name)
	if image != null:
		_check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture saved: " + name)


func _buy_plot(index: int, kind: String) -> void:
	var target: Vector3 = city.plot_position(index) + Vector3.UP * 0.08
	var point: Vector2 = city.camera.unproject_position(target)
	_check(root.get_visible_rect().has_point(point), "Requested plot is visibly projected")
	await _tap(point)
	_check(city.selected_plot == index, "Real terrain ray selects plot " + str(index))
	var button: Button = city.purchase_buttons[kind]
	_check(root.get_visible_rect().encloses(button.get_global_rect()), "Purchase control fits visible screen")
	await _tap(button.get_global_rect().get_center())
	var found := false
	for building in city.model.player().buildings:
		found = found or (building.plot == index and building.kind == kind)
	_check(found, "Real purchase button builds " + kind)


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		if DisplayServer.get_name() == "headless" or capture_dir.is_empty():
			push_error("[SettlementPlay] Capture requires real renderer and LUMO_CAPTURE_DIR")
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1280, 720)
	var free_save := "user://lumo_build_" + CHILD + "_3.json"
	var city_save := "user://lumo_settlement_" + CHILD + "_3_rival.json"
	DirAccess.remove_absolute(free_save)
	DirAccess.remove_absolute(city_save)
	var router = root.get_node("SceneRouter")
	router.launch_options = {"childKey": CHILD, "buildSlot": SLOT}
	var build = load("res://scenes/creative/build_world.tscn").instantiate()
	root.add_child(build)
	current_scene = build
	await _frames(10)
	_check(build.save_world(false), "Existing creative world saved before variation")
	var preserved := FileAccess.get_file_as_string(free_save)
	var entry := _button(build, "Wettbau")
	_check(entry != null and entry.is_visible_in_tree(), "Wettbau is an actual Bauwelt action")
	if entry == null:
		quit(1)
		return
	await _tap(entry.get_global_rect().get_center())
	await _frames(20)
	city = current_scene
	_check(city != null and city.scene_file_path == "res://scenes/creative/build_settlement_world.tscn", "Actual scene route reaches the city game")
	if city == null or not city.has_method("_buy"):
		quit(1)
		return
	_check(city.mode == "rival" and city.model.mode == "rival", "Wettbau mode reaches deterministic rules")
	_check(city.slot == SLOT and city.child_key == CHILD, "Route preserves the selected child and project slot")
	_check(FileAccess.get_file_as_string(free_save) == preserved, "Entering a city variation preserves original construction bytes")
	_check(city.model.player().resources == city.model.rival().resources, "Both towns start with identical resources")
	_check(city.plot_nodes.size() == 18, "Both nine-plot towns exist in live 3D")
	await _capture("01_settlement_start")
	await _world_release_over_hud()
	var initial: Dictionary = city.model.snapshot()
	await _buy_plot(4, "house")
	_check(city.model.player().resources.wood == initial.player.resources.wood - 4, "Real purchase debits wood exactly")
	_check(city.facility_nodes.size() == 1 and city.facility_nodes.has("p_b1"), "Paid house is actual scene geometry")
	await _buy_plot(5, "farm")
	_check(city.facility_nodes.size() == 2, "Distinct string IDs create two distinct buildings")
	var purchased: Dictionary = city.model.snapshot()
	await _capture("02_settlement_purchases")
	await _tap(_button(city, "Rückgängig").get_global_rect().get_center())
	_check(city.model.player().buildings.size() == 1 and city.facility_nodes.size() == 1, "Undo removes facility and restores its resources")
	await _tap(_button(city, "Wiederholen").get_global_rect().get_center())
	_check(city.model.snapshot() == purchased, "Redo restores full paid transaction")
	await _frames(25)
	_check(city.model.snapshot() == purchased, "Rendering and time alone do not farm resources")
	await _tap(city.day_button.get_global_rect().get_center())
	_check(city.model.day == 2, "Actual Next Day advances exactly one day")
	_check(city.model.rival().buildings.size() == 3, "Fair AI spends its own starting supplies on visible facilities")
	_check(city.facility_nodes.size() == 5, "Every AI purchase has an actual neighboring 3D building")
	_check(city.model.player().resources.food == int(purchased.player.resources.food) + 5 - 2, "Farm output pays the real daily food need")
	city.focus = Vector3(0, 0, 0)
	city.radius = 53
	city._camera_update(true)
	await _frames(10)
	await _capture("03_settlement_rival_day")
	var saved: Dictionary = city.model.snapshot()
	_check(city._save(), "Dedicated city save is written atomically")
	_check(FileAccess.get_file_as_string(free_save) == preserved, "City purchases and days never alter creative save")
	var project: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(city_save))
	var restored = city.restore_project(project, CHILD, SLOT, "rival")
	_check(restored != null and restored.snapshot() == saved, "Disk reload retains both towns, exact resources and day")
	_check(city.restore_project(project, "other_child", SLOT, "rival") == null, "City save cannot cross child profiles")
	_check(city.restore_project(project, CHILD, 1, "rival") == null, "City save cannot cross project slots")
	_check(city.restore_project(project, CHILD, SLOT, "settlement") == null, "City save cannot cross game variations")
	var unsupported: Dictionary = project.duplicate(true)
	unsupported.version = 2
	_check(city.restore_project(unsupported, CHILD, SLOT, "rival") == null, "Unknown city project version is rejected")
	city._toggle_pause()
	city._next_day()
	await _frames(12)
	_check(city.model.snapshot() == saved, "Paused Next Day and elapsed frames do not advance rules")
	city._toggle_pause()
	await _tap(city.walk_button.get_global_rect().get_center())
	await _frames(25)
	_check(city.walking and city.explorer.is_on_floor(), "Original Lumo enters actual city ground")
	_check(city.explorer.original_lumo.is_usable(), "City walking uses the original animated rig")
	await _capture("04_settlement_lumo")
	await _tap(city.walk_button.get_global_rect().get_center())
	_check(not city.walking and city.model.snapshot() == saved, "City walkthrough preserves the economy")
	for dimensions in [Vector2i(412, 915), Vector2i(690, 829), Vector2i(914, 411)]:
		root.size = dimensions
		await _frames(8)
		for button in [city.day_button, city.walk_button, _button(city, "‹ Bauwelt"), _button(city, "Ⅱ")]:
			_check(root.get_visible_rect().encloses(button.get_global_rect()), "Required city control fits " + str(dimensions))
			_check(button.size.x >= 48 and button.size.y >= 48, "City touch target stays >=48dp " + str(dimensions))
		_check(not city.top.get_global_rect().intersects(city.bottom.get_global_rect()), "Top and bottom controls remain separate " + str(dimensions))
	await _tap(_button(city, "‹ Bauwelt").get_global_rect().get_center())
	await _frames(15)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/creative/build_world.tscn", "Return reaches the original creative world")
	_check(FileAccess.get_file_as_string(free_save) == preserved, "Returned creative world keeps original bytes")
	_check(current_scene.slot == SLOT and current_scene.save_path == free_save, "Return restores the same creative project slot")
	# A malformed city save must stay byte-for-byte recoverable. The player can
	# return and choose another project; no autosave may overwrite this file.
	var invalid_bytes := "{corrupted project retained for recovery}"
	var invalid_file := FileAccess.open(city_save, FileAccess.WRITE)
	invalid_file.store_string(invalid_bytes)
	invalid_file.close()
	current_scene._open_settlement("rival")
	await _frames(15)
	city = current_scene
	_check(city.save_blocked, "Malformed city file blocks replacement")
	var untouched: Dictionary = city.model.snapshot()
	city._buy("house")
	city._next_day()
	_check(city.model.snapshot() == untouched and not city._save(), "Unreadable file cannot receive a misleading purchase or save")
	_check(FileAccess.get_file_as_string(city_save) == invalid_bytes, "Malformed city bytes remain intact")
	city._leave()
	await _frames(15)
	_check(current_scene.scene_file_path == "res://scenes/creative/build_world.tscn", "Unreadable city still allows safe return to Bauwelt")
	current_scene.queue_free()
	await _frames(3)
	DirAccess.remove_absolute(free_save)
	DirAccess.remove_absolute(city_save)
	if failures.is_empty():
		print("[SettlementPlay] PASS checks=", checks, ": actual routes, plot touch, paid builds, fair visible AI, save isolation, pause and layouts")
		quit(0)
	else:
		print("[SettlementPlay] FAIL ", failures)
		quit(1)
