extends SceneTree
## Real production scenes and cache; only the asynchronous Android observation
## boundary is isolated. This is not an Android device or JNI execution proof.

const DENSITY := 2.625
const LANDSCAPE := Vector2i(2400, 1080)
const LANDSCAPE_INSETS := Rect2(136, 63, 0, 63)

class AndroidBoundary extends RefCounted:
	var requests: Array[Callable] = []

	func request(completed: Callable) -> bool:
		requests.append(completed)
		return true

	func complete(index: int, observation: Dictionary) -> void:
		requests[index].call_deferred(observation)


class VillageHostBoundary extends Node:
	var returns: Array[String] = []

	# Match the existing native host API at this explicit test boundary.
	# gdlint: disable=function-name
	func returnToApp(destination: String, _payload: String) -> int:
		returns.append(destination)
		return 0
	# gdlint: enable=function-name


var checks := 0
var failures: Array[String] = []
var targets: Array[Dictionary] = []
var images: Array[Dictionary] = []
var events: Array[Dictionary] = []
var mobile: Node
var boundary := AndroidBoundary.new()
var changes := 0
var capture := false
var output := "res://exports/mobile-safe-area"
var village_hud_only := false
var village_hud: Dictionary = {}


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	village_hud_only = "--village-hud-only" in OS.get_cmdline_user_args()
	if not OS.get_environment("LUMO_CAPTURE_DIR").is_empty():
		output = OS.get_environment("LUMO_CAPTURE_DIR")
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[MobileSafeArea] " + label)


func _frames(count: int = 6) -> void:
	for frame in range(count):
		await process_frame


func _observed(window: Vector2i, insets: Rect2) -> Dictionary:
	return {"view_size": Vector2(window), "decor_size": Vector2(window),
		"render_rect": Rect2(Vector2.ZERO, Vector2(window)), "system_insets": insets,
		"insets": insets}


func _changed() -> void:
	changes += 1
	events.append({"event": "safe_area_changed", "ready": mobile.safe_area_is_ready(),
		"window": [root.size.x, root.size.y]})


func _complete_current(insets: Rect2) -> void:
	mobile.request_safe_area_refresh()
	boundary.complete(boundary.requests.size() - 1, _observed(root.size, insets))
	await _frames()


func _cache_contract() -> void:
	mobile.request_safe_area_refresh()
	_check(boundary.requests.size() == 1, "one actual platform request starts")
	_check(not mobile.safe_area_is_ready(), "unmeasured modern Android is not a safe zero-inset result")
	mobile.request_safe_area_refresh()
	_check(boundary.requests.size() == 1, "pending request is shared, not multiplied by consumers")
	await _complete_current(LANDSCAPE_INSETS)
	_check(mobile.safe_area_is_ready(), "deferred View result makes cache ready")
	_check(mobile.get_safe_area_insets() == LANDSCAPE_INSETS, "left cutout is not moved to the right")
	_check(changes == 1, "first actual observation emits one layout signal")
	var copy: Dictionary = mobile.get_safe_area_observation()
	copy["insets"] = Rect2()
	_check(mobile.get_safe_area_insets() == LANDSCAPE_INSETS, "consumers cannot mutate cached observation")
	await _complete_current(LANDSCAPE_INSETS)
	_check(changes == 1, "identical observation does not relayout scenes each poll")
	var old_request: int = boundary.requests.size() - 1
	root.size = Vector2i(1080, 2400)
	await _frames()
	_check(not mobile.safe_area_is_ready(), "portrait rotation invalidates landscape cache immediately")
	var new_request: int = boundary.requests.size() - 1
	boundary.complete(old_request, _observed(LANDSCAPE, LANDSCAPE_INSETS))
	await _frames()
	_check(not mobile.safe_area_is_ready(), "late landscape response cannot replace rotated View")
	_check(mobile._safe_area_request_pending, "late response cannot clear a newer pending request")
	boundary.complete(new_request, _observed(root.size, Rect2(0, 136, 0, 63)))
	await _frames()
	_check(mobile.get_safe_area_insets() == Rect2(0, 136, 0, 63), "current portrait response is accepted")
	var before := changes
	await _complete_current(Rect2(0, 63, 0, 136))
	_check(root.size == Vector2i(1080, 2400) and changes == before + 1,
		"180-degree inset change relayouts without any window-size event")
	_check(mobile.get_safe_area_insets() == Rect2(0, 63, 0, 136), "opposite cutout remains on its actual edge")
	mobile.request_safe_area_refresh()
	boundary.complete(boundary.requests.size() - 1, {})
	await _frames()
	_check(not mobile.safe_area_is_ready(), "detached/missing View invalidates previous valid cache")
	await _complete_current(Rect2(0, 136, 0, 63))
	_check(mobile.safe_area_is_ready(), "subsequent attached View recovers")
	mobile.request_safe_area_refresh()
	var pending: int = boundary.requests.size() - 1
	mobile._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(not mobile.safe_area_is_ready(), "app pause invalidates View observation")
	boundary.complete(pending, _observed(root.size, Rect2(0, 136, 0, 63)))
	await _frames()
	_check(not mobile.safe_area_is_ready(), "late pre-pause callback stays rejected")
	mobile.request_safe_area_refresh()
	_check(boundary.requests.size() - 1 == pending, "paused app starts no new platform requests")
	mobile._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _complete_current(Rect2(0, 136, 0, 63))
	_check(mobile.safe_area_is_ready(), "resume requires and accepts a new actual View observation")
	var malformed := _observed(root.size, Rect2())
	malformed["view_size"] = Vector2.ZERO
	mobile.request_safe_area_refresh()
	boundary.complete(boundary.requests.size() - 1, malformed)
	await _frames()
	_check(not mobile.safe_area_is_ready(), "unlaid-out View is not divided into a fabricated safe area")
	root.size = LANDSCAPE
	await _frames()
	await _complete_current(LANDSCAPE_INSETS)


func _pixels(control: Control) -> Rect2:
	var factor := Vector2(root.size) / root.get_visible_rect().size
	var transform := control.get_global_transform_with_canvas()
	var rect := Rect2((transform * Vector2.ZERO) * factor, Vector2.ZERO)
	for point in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		rect = rect.expand((transform * point) * factor)
	return rect


func _values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _record(module: String, control: Control, caption: String) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), module + " " + caption + " remains visible")
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var safe := Rect2(LANDSCAPE_INSETS.position,
		Vector2(root.size) - LANDSCAPE_INSETS.position - LANDSCAPE_INSETS.size)
	var rect := _pixels(control)
	var exposed := rect.intersection(safe)
	var dp := rect.size / DENSITY
	targets.append({"module": module, "caption": caption, "rect_px": _values(rect),
		"target_dp": [dp.x, dp.y], "exposed_dp": [exposed.size.x / DENSITY, exposed.size.y / DENSITY],
		"fully_inside_true_safe_area": safe.grow(0.51).encloses(rect)})
	_check(safe.grow(0.51).encloses(rect), module + " " + caption + " lies outside all four system edges")
	_check(dp.x >= 47.95 and dp.y >= 47.95, module + " " + caption + " preserves at least 48 dp")


func _capture(module: String) -> void:
	if not capture:
		return
	_check(DisplayServer.get_name() != "headless", "capture requires an actual rendering surface")
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	var path := output.path_join(module + "-landscape-cutout.png")
	_check(pixels.get_size() == LANDSCAPE, module + " capture matches actual window pixels")
	_check(pixels.save_png(path) == OK, module + " actual viewport PNG saved")
	images.append({"module": module, "path": path.get_file(), "width": pixels.get_width(),
		"height": pixels.get_height(), "sha256": FileAccess.get_sha256(path)})


func _scene_contract() -> void:
	for spec in [
		["jump", "res://scenes/games/jump_islands.tscn", "_layout_ui"],
		["build", "res://scenes/creative/build_world.tscn", "_resize"],
		["puzzle", "res://scenes/creative/puzzle_world.tscn", "_resize_ui"],
		["treasure", "res://scenes/creative/treasure_world.tscn", "_layout"],
	]:
		root.content_scale_size = Vector2i(720, 1280)
		root.get_node("SceneRouter").launch_options = {
			"childKey": "safe-area-contract-%s-%d" % [spec[0], OS.get_process_id()], "grade": 1}
		var before_connections: int = mobile.safe_area_changed.get_connections().size()
		var game = load(spec[1]).instantiate()
		root.add_child(game)
		current_scene = game
		await _frames(12)
		_check(mobile.safe_area_changed.is_connected(Callable(game, spec[2])), spec[0] + " production layout subscribes")
		if spec[0] == "jump":
			for button in game.header_buttons:
				_record(spec[0], button, button.text)
			_record(spec[0], game.movement_stick, "MovementStick")
			_record(spec[0], game.jump_action, "JumpAction")
			game.abandoned = true
		else:
			for button in game.find_children("*", "Button", true, false):
				if button.is_visible_in_tree() and button.text in ["‹ Spiele", "Ⅱ", "Verschieben", "↻ Drehen", "Rucksack", "Springen"]:
					_record(spec[0], button, button.text)
			if spec[0] == "treasure":
				_record(spec[0], game.joystick, "MovementStick")
				_record(spec[0], game.action, "ANSEHEN")
		await _capture(spec[0])
		# The same live scene must receive a same-size 180-degree result and a
		# restored result without another explicit resize call from this test.
		await _complete_current(Rect2(0, 63, 136, 63))
		var safe_control: Control = game.ui_safe if spec[0] == "jump" else game.safe_ui
		if spec[0] == "jump":
			_check(safe_control.get_theme_constant("margin_right") > safe_control.get_theme_constant("margin_left"),
				"jump same-size new cutout moves the actual safe margin")
		else:
			_check(absf(_pixels(safe_control).end.x - (2400 - 136)) < 0.6,
				spec[0] + " same-size new cutout changes actual control layout")
		await _complete_current(LANDSCAPE_INSETS)
		# Queue the real callbacks, remove without immediately freeing, then
		# let queued layout work and a new platform signal run on the exited node.
		game.call_deferred(spec[2])
		if spec[0] == "build":
			game.call_deferred("_layout_camera_tools")
			game.call_deferred("_layout_goal_access")
		elif spec[0] == "puzzle":
			game.call_deferred("_fit_menu")
		root.remove_child(game)
		current_scene = null
		_check(not mobile.safe_area_changed.is_connected(Callable(game, spec[2])), spec[0] + " disconnects before runtime restore")
		mobile.safe_area_changed.emit()
		await _frames()
		_check(mobile.safe_area_changed.get_connections().size() == before_connections,
			spec[0] + " leaves no stale signal subscription")
		game.free()
	_check(targets.size() == 15, "all fifteen original counterexample controls are retained")


func _cache_exit_contract() -> void:
	# Load after autoload registration, just like the production scenes.
	var temporary = load("res://scripts/app/mobile_runtime.gd").new()
	root.add_child(temporary)
	var late := AndroidBoundary.new()
	temporary._android_safe_area_enabled = true
	temporary._safe_area_reader = late.request
	temporary.set_process(false)
	temporary.request_safe_area_refresh()
	root.remove_child(temporary)
	late.complete(0, _observed(root.size, LANDSCAPE_INSETS))
	await _frames()
	_check(temporary.get_safe_area_observation().is_empty(), "late UI callback after cache exits tree cannot publish")
	temporary.free()


func _extra_readers_contract() -> void:
	# Existing layouts must also update when an observation arrives after their
	# initial ready/size event. These checks execute their real callbacks.
	for spec in [
		["learning", "res://scenes/learning/learning_world.tscn", "_layout"],
		["boot", "res://scenes/app/boot.tscn", "_layout"],
		["settlement", "res://scenes/creative/build_settlement_world.tscn", "_layout"],
		["rhythm", "res://scenes/creative/rhythm_world.tscn", "_layout"],
	]:
		root.content_scale_size = Vector2i(720, 1280)
		root.get_node("SceneRouter").launch_options = {"childKey": "safe-extra-" + spec[0]}
		var before: int = mobile.safe_area_changed.get_connections().size()
		var game = load(spec[1]).instantiate()
		if spec[0] == "boot":
			game.auto_begin = false
		elif spec[0] == "learning":
			game.capture_options = {"learning": {"kind": "equal_sharing", "a": 12, "b": 3}}
		root.add_child(game)
		await _frames(12)
		_check(mobile.safe_area_changed.is_connected(Callable(game, spec[2])), spec[0] + " existing callback subscribes")
		var control: Control
		if spec[0] == "learning":
			control = game.header
		elif spec[0] == "boot":
			control = game.get_node("Layer/TopBar")
		else:
			control = game.safe_ui
		var before_rect := _pixels(control)
		_check(before_rect.position.x >= 135.5, spec[0] + " uses actual left cutout")
		await _complete_current(Rect2(0, 63, 136, 63))
		var after_rect := _pixels(control)
		_check(after_rect.end.x <= 2264.5 and after_rect.position.x < before_rect.position.x - 100,
			spec[0] + " updates its existing layout after same-size inset change")
		await _complete_current(LANDSCAPE_INSETS)
		game.call_deferred(spec[2])
		if spec[0] == "learning":
			game.call_deferred("_queue_layout")
		root.remove_child(game)
		mobile.safe_area_changed.emit()
		await _frames()
		_check(mobile.safe_area_changed.get_connections().size() == before, spec[0] + " existing callback disconnects on exit")
		game.free()
	var helper = load("res://scripts/ui/mobile_safe_area.gd")
	var control := Control.new()
	root.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var before: int = mobile.safe_area_changed.get_connections().size()
	helper.apply_safe_margins(control)
	await _frames()
	_check(absf(_pixels(control).position.x - 136) < 0.6, "public UI helper resolves actual autoload and canvas scale")
	await _complete_current(Rect2(0, 63, 136, 63))
	_check(absf(_pixels(control).end.x - 2264) < 0.6, "public UI helper follows asynchronous actual inset change")
	root.remove_child(control)
	_check(mobile.safe_area_changed.get_connections().size() == before, "public UI helper removes bound callback on tree exit")
	control.free()
	await _complete_current(LANDSCAPE_INSETS)


func _kart_readers_contract() -> void:
	var before: int = mobile.safe_area_changed.get_connections().size()
	root.get_node("HostBridge")._options = {"displayDensity": DENSITY,
		"soundEnabled": false, "reduceAnimations": true, "childKey": "safe-kart-contract"}
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _frames(12)
	root.size = LANDSCAPE
	await _frames()
	await _complete_current(LANDSCAPE_INSETS)
	_check(mobile.safe_area_changed.is_connected(game._on_viewport_size_changed), "Kart existing callback subscribes")
	_check(mobile.safe_area_changed.is_connected(game.garage._apply_responsive_layout), "Garage existing callback subscribes")
	var tuning = load("res://scripts/games/kart_tuning.gd").new("safe-kart-contract", 500)
	tuning.save_enabled = false
	game.garage.workshop = tuning
	game.garage._open_workshop()
	await _frames(10)
	var workshop = game.garage.workshop_view
	_check(is_instance_valid(workshop), "existing Garage creates its production workshop")
	if is_instance_valid(workshop):
		_check(mobile.safe_area_changed.is_connected(workshop._apply_layout), "Workshop existing callback subscribes")
		_check(absf(_pixels(game.safe_ui).position.x - 136) < 0.6, "Kart parent applies actual left cutout once")
		await _complete_current(Rect2(0, 63, 136, 63))
		_check(absf(_pixels(game.safe_ui).end.x - 2264) < 0.6, "Kart parent receives same-size right cutout")
		_check(_pixels(workshop.back_button).end.x <= 2264.5, "production workshop header remains within measured parent")
		game.garage._close_workshop()
		await _frames()
	await _complete_current(LANDSCAPE_INSETS)
	game.call_deferred("_on_viewport_size_changed")
	game.garage.call_deferred("_apply_responsive_layout")
	root.remove_child(game)
	mobile.safe_area_changed.emit()
	await _frames()
	_check(mobile.safe_area_changed.get_connections().size() == before, "Kart and nested consumers disconnect on exit")
	game.free()
	root.size = LANDSCAPE
	await _frames()
	await _complete_current(LANDSCAPE_INSETS)


func _village_hud_geometry(game: Node, phase: String) -> void:
	var safe := Rect2(LANDSCAPE_INSETS.position,
		Vector2(root.size) - LANDSCAPE_INSETS.position - LANDSCAPE_INSETS.size)
	var header := _pixels(game.top_backdrop)
	var footer := _pixels(game.bottom_backdrop)
	var task := _pixels(game.goal_label)
	var playfield := Rect2(safe.position.x, header.end.y,
		safe.size.x, maxf(0.0, footer.position.y - header.end.y))
	_check(safe.grow(0.51).encloses(header), phase + " complete upper HUD fits measured Android safe area")
	_check(safe.grow(0.51).encloses(footer), phase + " complete lower HUD fits measured Android safe area")
	_check(not header.intersects(footer), phase + " upper and lower HUD backdrops do not overlap")
	_check(game.goal_label.is_visible_in_tree() and not game.goal_label.text.is_empty(),
		phase + " real chapter/task label remains visible")
	_check(header.grow(0.51).encloses(task) and not task.intersects(footer),
		phase + " complete task label is not covered by the lower HUD")
	_check(playfield.size.y / DENSITY >= 48.0,
		phase + " a central playfield of at least one full touch-target height remains")
	var minimum_button_dp := Vector2(INF, INF)
	var button_count := 0
	for button in game.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			var dp := _pixels(button).size / DENSITY
			minimum_button_dp.x = minf(minimum_button_dp.x, dp.x)
			minimum_button_dp.y = minf(minimum_button_dp.y, dp.y)
			button_count += 1
			_check(dp.x >= 47.95 and dp.y >= 47.95,
				phase + " " + button.text + " retains a 48 dp physical touch target")
	_check(button_count > 0, phase + " retains actual village controls")
	village_hud["geometry"].append({"phase": phase, "safe_px": _values(safe),
		"header_px": _values(header), "footer_px": _values(footer), "task_px": _values(task),
		"playfield_px": _values(playfield), "button_count": button_count,
		"minimum_button_dp": [minimum_button_dp.x, minimum_button_dp.y]})


func _village_screen_touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _village_hud_restore_contract(game: Node) -> void:
	var controls: Array[Control] = [game.plot_label, game.buildings_scroll, game.action_row,
		game.feedback, game.resource_label, game.goal_label]
	var button_connections: Dictionary = {}
	for button in game.find_children("*", "Button", true, false):
		button_connections[button.get_instance_id()] = button.get_signal_connection_list("pressed")
	var snapshot: Dictionary = game.model.snapshot().duplicate(true)
	var selected: int = game.selected_plot
	root.size = Vector2i(1080, 2400)
	await _frames(12)
	await _complete_current(Rect2(0, 136, 0, 63))
	await _frames(12)
	_check(not game.compact_village_hud, "the same livingVillage changes to tall portrait layout")
	var portrait_rects: Array = []
	for index in range(4):
		_check(controls[index].is_visible_in_tree(), "portrait retains original bottom control %d" % index)
		portrait_rects.append(_pixels(controls[index]))
	_check(portrait_rects[0].end.y <= portrait_rects[1].position.y + 0.51,
		"portrait visibly places the plot caption before buildings")
	_check(portrait_rects[1].end.y <= portrait_rects[2].position.y + 0.51,
		"portrait visibly places buildings before the action row")
	_check(portrait_rects[2].end.y <= portrait_rects[3].position.y + 0.51,
		"portrait visibly restores the original action row before feedback")
	_check(controls == [game.plot_label, game.buildings_scroll, game.action_row,
		game.feedback, game.resource_label, game.goal_label],
		"portrait reuses the identical production labels and scroll controls")
	root.size = LANDSCAPE
	await _frames(12)
	await _complete_current(LANDSCAPE_INSETS)
	await _frames(12)
	await physics_frame
	_check(game.compact_village_hud, "the same livingVillage returns to compact landscape")
	_check(controls == [game.plot_label, game.buildings_scroll, game.action_row,
		game.feedback, game.resource_label, game.goal_label],
		"returning to landscape keeps the identical production controls")
	var after_connections: Dictionary = {}
	for button in game.find_children("*", "Button", true, false):
		after_connections[button.get_instance_id()] = button.get_signal_connection_list("pressed")
	_check(button_connections == after_connections,
		"landscape portrait landscape keeps the same pressed callbacks without duplicates")
	_check(game.model.snapshot() == snapshot and game.selected_plot == selected,
		"live orientation changes do not alter the village or its selection")
	_village_hud_geometry(game, "restored-landscape")
	var logical: Vector2 = game.camera.unproject_position(game._plot_world(4) + Vector3(0, 0.1, 0))
	var point := logical * Vector2(root.size) / root.get_visible_rect().size
	await _village_screen_touch(point, true)
	await _village_screen_touch(point, false)
	await physics_frame
	await _frames(12)
	_check(game.selected_plot == 4 and game.pointer == -1,
		"the original world input selects a plot again after the live orientation roundtrip")
	_check(game.model.snapshot() == snapshot, "post-rotation plot selection preserves the village model")
	village_hud["restore"] = {"surface_sequence": [[2400, 1080], [1080, 2400], [2400, 1080]],
		"portrait_plot_px": _values(portrait_rects[0]), "portrait_buildings_px": _values(portrait_rects[1]),
		"portrait_actions_px": _values(portrait_rects[2]), "portrait_feedback_px": _values(portrait_rects[3]),
		"same_pressed_callbacks": button_connections == after_connections,
		"post_rotation_touch_px": [point.x, point.y], "post_rotation_selected_plot": game.selected_plot}


func _village_zoom_pick_contract(game: Node) -> void:
	var before_radius: float = game.radius
	var before_tilt: float = game.tilt
	var before_orbit: float = game.orbit
	var before_focus: Vector3 = game.focus
	var before_offsets := Vector2(game.camera.h_offset, game.camera.v_offset)
	var before_selected: int = game.selected_plot
	var snapshot: Dictionary = game.model.snapshot().duplicate(true)
	var save_path: String = game.save_path
	var had_save := FileAccess.file_exists(save_path)
	var saved := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	# This permitted camera-angle endpoint is an explicit geometry fixture,
	# not a claim that a new Android drag was performed. Plot selection below
	# still enters through real ScreenTouch events and the production raycast.
	game.tilt = 1.1
	for step in range(20):
		if is_equal_approx(game.radius, 94.0):
			break
		game._zoom_village(1)
	game._camera_update(true)
	await _frames(12)
	await physics_frame
	_check(is_equal_approx(game.radius, 94.0) and is_equal_approx(game.tilt, 1.1),
		"existing zoom action reaches radius 94 at the permitted steep tilt endpoint")
	var samples: Array[Dictionary] = []
	for index in range(9):
		var world: Vector3 = game._plot_world(index) + Vector3(0, 0.1, 0)
		var logical: Vector2 = game.camera.unproject_position(world)
		var point := logical * Vector2(root.size) / root.get_visible_rect().size
		var origin: Vector3 = game.camera.project_ray_origin(logical)
		var far_point: Vector3 = game.camera.project_position(logical, game.camera.far)
		_check(not _pixels(game.top_backdrop).has_point(point)
			and not _pixels(game.bottom_backdrop).has_point(point),
			"steep maximum-zoom plot %d remains outside both HUDs" % index)
		await _village_screen_touch(point, true)
		await _village_screen_touch(point, false)
		await physics_frame
		await _frames(12)
		_check(game.selected_plot == index and game.pointer == -1,
			"actual ScreenTouch selects plot %d at radius 94 and tilt 1.1" % index)
		_check(game.model.snapshot() == snapshot,
			"maximum-zoom plot %d selection preserves the village model" % index)
		samples.append({"plot": index, "point_px": [point.x, point.y],
			"target_distance": origin.distance_to(world), "far_plane_distance": origin.distance_to(far_point),
			"selected_plot": game.selected_plot, "pointer_after_release": game.pointer})
	_check(FileAccess.file_exists(save_path) == had_save, "maximum zoom and selection preserve save existence")
	if had_save:
		_check(FileAccess.get_file_as_bytes(save_path) == saved, "maximum zoom and selection preserve save bytes")
	game.radius = before_radius
	game.tilt = before_tilt
	game.orbit = before_orbit
	game.focus = before_focus
	game._camera_update(true)
	await _frames(12)
	if before_selected >= 0:
		var logical: Vector2 = game.camera.unproject_position(game._plot_world(before_selected) + Vector3(0, 0.1, 0))
		var point := logical * Vector2(root.size) / root.get_visible_rect().size
		await _village_screen_touch(point, true)
		await _village_screen_touch(point, false)
		await _frames(12)
	_check(game.radius == before_radius and game.tilt == before_tilt
		and game.orbit == before_orbit and game.focus == before_focus,
		"maximum-zoom fixture restores the prior planning-camera parameters")
	_check(Vector2(game.camera.h_offset, game.camera.v_offset).distance_to(before_offsets) < 0.001,
		"maximum-zoom fixture restores the prior planning-camera offsets")
	_check(game.selected_plot == before_selected and game.model.snapshot() == snapshot,
		"maximum-zoom fixture restores selection through an actual touch without changing the model")
	village_hud["maximum_zoom"] = {"radius": 94.0, "tilt_fixture": 1.1,
		"scope": "permitted camera endpoint fixture and actual ScreenTouch selection; not Android rotation evidence",
		"plots": samples, "restored_radius": game.radius, "restored_tilt": game.tilt,
		"restored_offsets": [game.camera.h_offset, game.camera.v_offset]}


func _village_hud_contract() -> void:
	var packed := load("res://scenes/creative/build_settlement_world.tscn") as PackedScene
	_check(packed != null, "actual village scene is available for the Android HUD counterexample")
	if packed == null:
		return
	var host := root.get_node("HostBridge")
	var router := root.get_node("SceneRouter")
	var old_options: Dictionary = host._options.duplicate(true)
	var old_launch: Dictionary = router.launch_options.duplicate(true)
	var old_host: Variant = host.get("_host")
	var old_current: Node = current_scene
	var old_touch_emulation := Input.emulate_touch_from_mouse
	var fake := VillageHostBoundary.new()
	root.add_child(fake)
	var child := "safe-village-hud-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	host.set("_host", fake)
	host._options = {"scene": "settlement", "livingVillage": true, "settlementMode": "settlement",
		"childKey": child, "buildSlot": 1, "displayDensity": DENSITY, "soundEnabled": false}
	router.launch_options = host._options.duplicate(true)
	Input.emulate_touch_from_mouse = true
	root.size = LANDSCAPE
	await _frames()
	await _complete_current(LANDSCAPE_INSETS)
	var before_connections: int = mobile.safe_area_changed.get_connections().size()
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(12)
	await physics_frame
	var actual_source: String = game.get_script().get_source_code()
	var expected_source := FileAccess.get_file_as_string("res://scripts/creative/build_settlement_world.gd")
	_check(not actual_source.is_empty() and actual_source == expected_source,
		"running village script is the exact current production source, not an older packed GDC")
	_check(game.model.living_village and game.host_entry and game.return_scene == "games",
		"exact embedded livingVillage path retains the Flutter games destination")
	_check(game.model.player().plots == 9 and game.plot_nodes.size() == 9,
		"fresh village exposes the actual nine initial plot colliders")
	_check(mobile.get_safe_area_insets() == LANDSCAPE_INSETS,
		"village uses the original 2400x1080 Android View insets")
	_check(is_equal_approx(mobile.get_ui_density(), DENSITY), "village uses the original 420 dpi density")
	var snapshot: Dictionary = game.model.snapshot().duplicate(true)
	var save_path: String = game.save_path
	var had_save := FileAccess.file_exists(save_path)
	var saved := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	village_hud = {"scope": "production scene, real InputEventScreenTouch and explicit Android/host boundaries; not device execution",
		"surface": [root.size.x, root.size.y], "density": DENSITY,
		"running_world_source_sha256": actual_source.sha256_text(),
		"file_world_source_sha256": FileAccess.get_sha256("res://scripts/creative/build_settlement_world.gd"),
		"system_insets_px": _values(LANDSCAPE_INSETS), "geometry": [], "plots": []}
	_village_hud_geometry(game, "initial")
	if village_hud_only:
		await _capture("village-hud-initial")
	for index in range(9):
		var logical: Vector2 = game.camera.unproject_position(game._plot_world(index) + Vector3(0, 0.1, 0))
		var factor := Vector2(root.size) / root.get_visible_rect().size
		var point := logical * factor
		var safe := Rect2(LANDSCAPE_INSETS.position,
			Vector2(root.size) - LANDSCAPE_INSETS.position - LANDSCAPE_INSETS.size)
		var header := _pixels(game.top_backdrop)
		var footer := _pixels(game.bottom_backdrop)
		_check(safe.has_point(point) and not header.has_point(point) and not footer.has_point(point),
			"initial plot %d projects into actual unobscured world pixels" % index)
		await _village_screen_touch(point, true)
		await _village_screen_touch(point, false)
		await physics_frame
		await _frames(12)
		_check(game.selected_plot == index, "actual screen touch selects initial plot %d" % index)
		_check(game.pointer == -1, "plot %d touch releases its actual world pointer" % index)
		_check(game.model.snapshot() == snapshot, "plot %d selection leaves the village model unchanged" % index)
		_check(FileAccess.file_exists(save_path) == had_save,
			"plot %d selection leaves save existence unchanged" % index)
		if had_save:
			_check(FileAccess.get_file_as_bytes(save_path) == saved,
				"plot %d selection leaves original save bytes unchanged" % index)
		village_hud["plots"].append({"plot": index, "point_px": [point.x, point.y],
			"selected_plot": game.selected_plot, "pointer_after_release": game.pointer})
		_village_hud_geometry(game, "selected-%d" % index)
	_check(fake.returns.is_empty(), "plot touches do not trigger the Flutter return control")
	await _village_hud_restore_contract(game)
	await _village_zoom_pick_contract(game)
	if village_hud_only:
		await _capture("village-hud-selected")
	root.remove_child(game)
	current_scene = old_current
	await _frames()
	_check(mobile.safe_area_changed.get_connections().size() == before_connections,
		"livingVillage HUD leaves no safe-area callback on exit")
	game.free()
	host.set("_host", old_host)
	host._options = old_options
	router.launch_options = old_launch
	Input.emulate_touch_from_mouse = old_touch_emulation
	fake.queue_free()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
	await _complete_current(LANDSCAPE_INSETS)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = LANDSCAPE
	await _frames()
	root.get_node("HostBridge")._options = {"displayDensity": DENSITY, "soundEnabled": false}
	mobile = root.get_node("MobileRuntime")
	var original_reader: Callable = mobile._safe_area_reader
	var original_enabled: bool = mobile._android_safe_area_enabled
	mobile._safe_area_reader = boundary.request
	mobile._android_safe_area_enabled = true
	mobile.set_process(false)
	mobile.safe_area_changed.connect(_changed)
	if village_hud_only:
		await _complete_current(LANDSCAPE_INSETS)
		await _village_hud_contract()
	else:
		await _cache_contract()
		await _scene_contract()
		await _extra_readers_contract()
		await _village_hud_contract()
		await _kart_readers_contract()
		await _cache_exit_contract()
	mobile.safe_area_changed.disconnect(_changed)
	mobile._safe_area_reader = original_reader
	mobile._android_safe_area_enabled = original_enabled
	mobile._safe_area_observation.clear()
	mobile.set_process(original_enabled)
	var file := FileAccess.open(output.path_join("mobile-safe-area.json"), FileAccess.WRITE)
	_check(file != null, "source-bound result file opens")
	var report := {"scope": "production cache and scenes with asynchronous Android boundary fixture; not device execution",
		"surface": [2400, 1080], "density": DENSITY, "observed_system_inset_fixture": [136, 63, 0, 63],
		"checks": checks, "failures": failures, "targets": targets, "events": events, "images": images,
		"village_hud": village_hud, "village_hud_only": village_hud_only}
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("MOBILE_SAFE_AREA_%s checks=%d failures=%d controls=%d images=%d scope=platform_boundary_fixture" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), targets.size(), images.size()])
	quit(0 if failures.is_empty() else 1)
