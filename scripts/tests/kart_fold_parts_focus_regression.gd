extends SceneTree
## Real Fold cover dimensions and press/release through the normal garage UI.

const TUNING = preload("res://scripts/games/kart_tuning.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")

var output := ""
var game
var menu
var bay


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	_run.call_deferred()


func _settle(count := 5) -> void:
	for frame in range(count):
		await process_frame


func _capture(name: String) -> void:
	await _settle()
	if output.is_empty():
		return
	RenderingServer.force_draw(true)
	var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	assert(result == OK)


func _tap(control: Control) -> void:
	assert(control.is_visible_in_tree(), str(control.name))
	var position := control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This Fold garage check needs the native display and touch coordinates.")
		quit(1)
		return
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.render_loop_enabled = false
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	root.get_node("HostBridge")._options["displayDensity"] = 2.625
	game = (load("res://scenes/games/kart_island.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.reduced_motion = true
	await _settle(10)
	root.size = Vector2i(904, 2316)
	await _settle(12)
	menu = game.garage
	menu.reduced_motion = true
	menu.set_landing_active(false)
	menu.step = 2
	game._apply_safe_area(Rect2(12, 48, 12, 36), Vector2(root.size))
	game._apply_responsive_layout()
	assert(root.size == Vector2i(904, 2316))
	menu._refresh()
	menu._apply_responsive_layout()
	await _settle(14)
	bay = menu.parts_bay
	await _tap(bay.open_button)
	bay.category.item_selected.emit(TUNING.PART_SLOTS.find("tires"))
	await _settle()
	assert(bay.is_open())
	var wide_camera: float = menu.preview_camera.size
	var tall_drawer: float = bay.panel.size.y
	await _capture("reifen-auswahl")
	var tile: Button = bay.tiles["haft"]
	bay.tile_scroll.ensure_control_visible(tile)
	await _settle()
	await _tap(tile)
	assert(bay.pending.get("tires") == "haft")
	assert(not bay.dyno_values.is_empty())
	assert(menu.preview_camera.size < wide_camera * 0.85)
	assert(bay.panel.size.y < tall_drawer)
	for control in [bay.back_button, bay.mount_button]:
		var bounds: Rect2 = control.get_global_rect()
		var physical_scale := Vector2(root.size) / root.get_visible_rect().size
		assert((bounds.size * physical_scale / 2.625).y >= 48.0)
	print("[FoldParts] Reifen ausgewählt ", bay.panel.get_global_rect(), " ", menu._visible_stage_region(), " ", menu.preview_camera.size)
	await _capture("reifen-nah")
	assert(not bay.category.visible and not bay.tile_scroll.visible)
	assert(is_instance_valid(bay.get("_lift")) and bay.get("_lift").is_visible_in_tree())
	assert(menu.preview_problem().is_empty())
	menu.preview_kart.hide()
	assert(menu.preview_problem() == "kart_unsichtbar")
	assert(menu.repair_preview("kart_unsichtbar"))
	await _settle()
	assert(menu.preview_problem().is_empty() and bay.pending.get("tires") == "haft")
	assert(menu.preview_kart.production_vehicle.mounted_parts.get("tires") == "haft")
	assert(is_instance_valid(bay.get("_lift")) and bay.get("_lift").is_visible_in_tree())
	await _tap(bay.back_button)
	assert(bay.is_open() and bay.category.visible and bay.pending.get("tires") == "haft")
	bay.category.item_selected.emit(TUNING.PART_SLOTS.find("suspension"))
	await _settle()
	var springs: Button = bay.tiles["sprung"]
	bay.tile_scroll.ensure_control_visible(springs)
	await _settle()
	await _tap(springs)
	assert(bay.pending.get("suspension") == "sprung")
	var shape: Vector3 = menu.preview_kart.position
	assert(shape.y > 0.2)
	await _capture("fahrwerk-nah")
	await _tap(bay.back_button)
	await _tap(bay.back_button)
	assert(not bay.is_open() and bay.pending.is_empty())
	assert(menu.preview_kart.position.y < 0.12 and not is_instance_valid(bay.get("_lift")))
	game.abandoned = true
	assert(await TEARDOWN.release_scene(self, game, "[FoldParts]"))
	print("[FoldParts] PASS")
	quit()
