extends SceneTree
## Real Control layout and input checks for the read-only World atlas.
## Runs without the 3D world, its assets, autoloads or any profile saves.

const MAP = preload("res://scripts/creative/lumo_world_map.gd")
const BOUNDS := Rect2(-36, -238, 992, 476)
var checks := 0
var failures: Array[String] = []
var atlas: VBoxContainer
var scroll: ScrollContainer


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("[WorldMap] " + description)


func _run() -> void:
	var original_mission := {"id": "meet_nelli", "title": "Ein neues Zuhause", "at": Vector3(90, 0, 20)}
	var original_completed: Array = []
	var original_missions: Array = [original_mission, {"id": "school_numbers", "title": "Der Plan für den Garten", "at": Vector3(110, 0, -24)}]
	var original_portals: Array = [
		{"game": "kart", "at": Vector3(77, 0, 11)},
		{"game": "cards", "at": Vector3(218, 0, -17)},
		{"game": "settlement", "at": Vector3(500, 0, 6)}]
	var original_bytes := var_to_bytes([original_mission, original_completed, original_missions, original_portals])
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scroll)
	atlas = MAP.new()
	scroll.add_child(atlas)
	# Configure after entering the tree as well as before is supported.
	atlas.configure(BOUNDS, Vector3(0, 0, 6), 0.0, original_mission, original_completed, original_missions, original_portals, true)
	await _frames(3)
	_check(atlas.place_buttons.size() == 4, "all four places are available after configure-on-tree")
	_check(atlas.focus_id == "player", "atlas opens at the player's neighbourhood")
	_check(atlas.location_label.text.contains("Schatzinsel"), "player location has a readable textual name")
	_check(atlas.view_bounds.size.x <= 330, "nearby view keeps original towns readable beside the much larger village")
	for dimensions in [Vector2i(280, 640), Vector2i(360, 800), Vector2i(640, 360), Vector2i(720, 840), Vector2i(1280, 720)]:
		root.size = dimensions
		scroll.size = Vector2(dimensions)
		scroll.scroll_vertical = 0
		await _frames(4)
		var buttons: Array = atlas.focus_buttons.values() + atlas.place_buttons.values()
		for button in buttons:
			_check(button.size.x >= 48 and button.size.y >= 48, "48px target %s at %s" % [button.name, dimensions])
			_check(button.get_global_rect().position.x >= -0.1 and button.get_global_rect().end.x <= dimensions.x + 0.1, "no horizontal clipping %s at %s" % [button.name, dimensions])
		_check(atlas.canvas.size.x <= dimensions.x, "map fits available width at %s" % dimensions)
		for legend_item in atlas.get_node("WorldMapLegend").get_children():
			var legend_text := legend_item.get_child(1) as Label
			_check(legend_text.get_line_count() == 1, "legend remains a readable single line at %s" % dimensions)
		var rect: Rect2 = atlas.atlas_rect(atlas.canvas.size)
		_check(is_equal_approx(rect.size.x / atlas.view_bounds.size.x, rect.size.y / atlas.view_bounds.size.y), "map preserves distance scale in both axes at %s" % dimensions)
		await _tap(atlas.focus_buttons["objective"])
		_check(atlas.focus_id == "objective", "real click focuses objective at %s" % dimensions)
		_check(atlas.view_bounds.has_point(Vector2(90, 20)), "objective is inside its focused view")
		await _tap(atlas.focus_buttons["world"])
		_check(atlas.view_bounds == BOUNDS, "real click reveals complete world at %s" % dimensions)
		await _tap(atlas.place_buttons["own_village"])
		_check(atlas.focus_id == "own_village", "scrolled place button is reachable at %s" % dimensions)
		await _tap(atlas.focus_buttons["player"])
		_check(atlas.focus_id == "player", "player focus is reachable again after scrolling")
	_check(var_to_bytes([original_mission, original_completed, original_missions, original_portals]) == original_bytes, "all map interactions leave source state byte-identical")
	atlas.focus_place("city")
	var retained: Rect2 = atlas.view_bounds
	atlas.focus_place("missing_place")
	_check(atlas.view_bounds == retained, "unknown place does not redirect the view")
	_check(atlas.location_name(Vector3(49, 0, 6)) == "Inselbrücke", "bridge has its own location name")
	atlas.configure(BOUNDS, Vector3(911, 0, 221), PI, {}, ["meet_nelli"], original_missions, original_portals, true)
	_check(BOUNDS.encloses(atlas.view_bounds), "edge-of-world local view stays within world bounds")
	_check(atlas.view_bounds.has_point(Vector2(911, 221)), "local view still contains player at far village edge")
	_check(atlas.focus_buttons["objective"].disabled, "completed chapter has no stale objective action")
	var complete_view: Rect2 = atlas.view_bounds
	atlas.focus_objective()
	_check(atlas.view_bounds == complete_view, "objective action cannot change a completed chapter's view")
	_check(atlas.objective_label.text.contains("Alle Aufträge geschafft"), "completed chapter has an explicit readable state")
	# A later caller mutation cannot alter the map's isolated input snapshot.
	original_missions[0]["title"] = "CHANGED OUTSIDE"
	_check(str(atlas.missions[0].title) == "Ein neues Zuhause", "nested mission data is copied rather than held by mutable reference")
	var rect := Rect2(10, 20, 200, 100)
	var horizontal: PackedVector2Array = atlas._clip_segment(Vector2(-50, 50), Vector2(400, 50), rect)
	_check(horizontal.size() == 2 and horizontal[0].is_equal_approx(Vector2(10, 50)) and horizontal[1].is_equal_approx(Vector2(210, 50)), "road clipping keeps both visible ends inside map")
	_check(atlas._clip_segment(Vector2(-50, 0), Vector2(400, 0), rect).is_empty(), "outside parallel road is not drawn")
	await _capture_if_requested(original_missions, original_portals)
	scroll.queue_free()
	await _frames(3)
	print("[WorldMap] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _tap(button: Button) -> void:
	scroll.ensure_control_visible(button)
	await _frames(3)
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame


func _capture_if_requested(mission_list: Array, portals: Array) -> void:
	var target := OS.get_environment("LUMO_WORLD_MAP_CAPTURE")
	if target.is_empty() or DisplayServer.get_name() == "headless":
		return
	root.size = Vector2i(600, 590)
	scroll.size = Vector2(600, 590)
	scroll.scroll_vertical = 0
	mission_list[0].title = "Ein neues Zuhause"
	atlas.configure(BOUNDS, Vector3(70, 0, 18), PI * 0.5, mission_list[0], [], mission_list, portals, true)
	await _frames(5)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame.save_png(target) == OK, "renderer screenshot is saved")


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
