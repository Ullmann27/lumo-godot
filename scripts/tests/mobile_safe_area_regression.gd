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


var checks := 0
var failures: Array[String] = []
var targets: Array[Dictionary] = []
var kart_minimap_layouts: Array[Dictionary] = []
var kart_minimap_images: Array[Dictionary] = []
var kart_minimap_transitions: Array[Dictionary] = []
var images: Array[Dictionary] = []
var events: Array[Dictionary] = []
var mobile: Node
var boundary := AndroidBoundary.new()
var changes := 0
var capture := false
var output := "res://exports/mobile-safe-area"


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
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


func _capture_kart_minimap(label: String) -> void:
	# Additional originals have a separate explicit destination. The existing
	# four mandatory Safe-Area rasters and their verifier remain unchanged.
	var directory := OS.get_environment("LUMO_KART_MINIMAP_CAPTURE_DIR")
	if directory.is_empty():
		return
	_check(capture and DisplayServer.get_name() != "headless",
		"Kart minimap capture requires the actual renderer")
	if not capture or DisplayServer.get_name() == "headless":
		return
	_check(DirAccess.make_dir_recursive_absolute(directory) == OK,
		"Kart minimap original capture directory opens")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == root.size,
		label + " Kart minimap capture has actual window pixels")
	if image == null:
		return
	var path := directory.path_join(label + ".png")
	_check(image.save_png(path) == OK, label + " Kart minimap original PNG saves")
	kart_minimap_images.append({"label": label, "path": path,
		"width": image.get_width(), "height": image.get_height(),
		"sha256": FileAccess.get_sha256(path)})


func _observe_kart_minimap(
	game, label: String, dimensions: Vector2i, density: float, insets: Rect2,
	expect_visible: bool
) -> Dictionary:
	var safe := Rect2(insets.position,
		Vector2(dimensions) - insets.position - insets.size)
	var shown: bool = game.map_panel.is_visible_in_tree()
	_check(shown == expect_visible, label + " preserves the usable map visibility")
	var map_rect: Rect2 = _pixels(game.map_panel)
	var content_rect: Rect2 = _pixels(game.map)
	var controls: Array = [game.top_menu_button, game.top_reset_button,
		game.top_pause_button, game.joystick, game.gas_button,
		game.brake_button, game.drift_button, game.boost_button, game.item_button]
	var control_rects: Array[Dictionary] = []
	for control in controls:
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = _pixels(control)
		var dp: Vector2 = rect.size / density
		_check(safe.grow(0.51).encloses(rect),
			label + " " + str(control.name) + " remains inside the true safe area")
		_check(minf(dp.x, dp.y) >= 47.95,
			label + " " + str(control.name) + " retains a 48 dp touch target")
		var artwork := rect
		if control.get_parent() == game.pedal_pad:
			# kart_touch_action draws its existing art at 1.12 of the hit box.
			artwork = rect.grow(maxf(rect.size.x, rect.size.y) * 0.06)
		control_rects.append({"name": str(control.name),
			"rect_px": _values(rect), "artwork_rect_px": _values(artwork),
			"target_dp": [dp.x, dp.y]})
		if shown:
			_check(not map_rect.intersects(artwork),
				label + " minimap leaves " + str(control.name) + " and its artwork unobscured")
	var notice_rects: Array[Dictionary] = []
	var header: Control = game.top_pause_button.get_parent()
	for notice in [header, game.message, game.jump_hint]:
		if not notice.is_visible_in_tree():
			continue
		var rectangle: Rect2 = _pixels(notice)
		notice_rects.append({"name": str(notice.name), "rect_px": _values(rectangle)})
		if shown:
			_check(not map_rect.intersects(rectangle),
				label + " minimap leaves header, instructions and jump hint unobscured")
	if shown:
		_check(safe.grow(0.51).encloses(map_rect),
			label + " entire minimap stays inside the true safe area")
		_check(map_rect.grow(0.51).encloses(content_rect),
			label + " actual map canvas stays inside its panel")
		_check(content_rect.size.x / density >= 79.95
				and content_rect.size.y / density >= 63.95,
			label + " visible map retains a readable overview")
	return {"label": label, "surface": [dimensions.x, dimensions.y],
		"density": density, "insets_px": _values(insets), "safe_rect_px": _values(safe),
		"visible": shown, "map_rect_px": _values(map_rect),
		"content_rect_px": _values(content_rect), "controls": control_rects,
		"notice_rects_px": notice_rects}


func _kart_minimap_hint_transition(game, density: float, insets: Rect2) -> void:
	var unchanged_surface: Vector2i = root.size
	var original_map: Rect2 = _pixels(game.map_panel)
	# Only the speed-hint's display input is a fixture. Exercise its real public
	# show/hide methods and Container signals without a resize or layout call.
	game.jump_hint.show_for(0.0, {"angle": 0.0, "height": 0.0,
		"flight_gravity": 1.0, "landing_min": 1.0, "landing_max": 2.0})
	await _frames(12)
	_check(root.size == unchanged_surface and game.jump_hint.is_visible_in_tree(),
		"jump hint appears in the unchanged live viewport")
	kart_minimap_transitions.append(_observe_kart_minimap(game,
		"expanded-hint-visible", unchanged_surface, density, insets, true))
	var moved_map: Rect2 = _pixels(game.map_panel)
	_check(moved_map.position.distance_to(original_map.position) > 1.0,
		"showing the real hint repositions the existing map without a resize")
	await _capture_kart_minimap("expanded-hint-visible")
	game.jump_hint.hide_hint()
	await _frames(12)
	_check(root.size == unchanged_surface and not game.jump_hint.is_visible_in_tree(),
		"jump hint hides in the unchanged live viewport")
	kart_minimap_transitions.append(_observe_kart_minimap(game,
		"expanded-hint-hidden", unchanged_surface, density, insets, true))
	var restored_map: Rect2 = _pixels(game.map_panel)
	_check(restored_map.position.distance_to(original_map.position) < 0.6
			and restored_map.size.distance_to(original_map.size) < 0.6,
		"hiding the real hint restores the available map space without a resize")
	await _capture_kart_minimap("expanded-hint-hidden")


func _kart_minimap_contract() -> void:
	var bridge := root.get_node("HostBridge")
	bridge._options = {"displayDensity": DENSITY, "soundEnabled": false,
		"reduceAnimations": true, "childKey": "safe-kart-minimap-contract"}
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.lightweight = true
	root.add_child(game)
	await _frames(12)
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet",
		"track": "candy_cloud", "difficulty": "gemuetlich"})
	game._end_preview()
	game.set_physics_process(false)
	game.auto_gas = false
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game.modal.hide()
	game._update_hud()
	var profiles: Array[Dictionary] = [
		{"label": "dense-left-cutout", "size": LANDSCAPE, "density": DENSITY,
			"insets": LANDSCAPE_INSETS, "map_visible": true},
		{"label": "dense-right-cutout", "size": LANDSCAPE, "density": DENSITY,
			"insets": Rect2(0, 63, 136, 63), "map_visible": true},
		{"label": "same-pixels-density-one", "size": LANDSCAPE, "density": 1.0,
			"insets": LANDSCAPE_INSETS, "map_visible": true},
		{"label": "expanded-inner-display", "size": Vector2i(2176, 1812), "density": 2.0,
			"insets": Rect2(48, 48, 36, 42), "map_visible": true},
		{"label": "compact-portrait", "size": Vector2i(360, 800), "density": 1.0,
			"insets": Rect2(8, 24, 8, 20), "map_visible": false},
		{"label": "short-landscape", "size": Vector2i(1280, 640), "density": 2.0,
			"insets": Rect2(0, 24, 0, 24), "map_visible": false},
		{"label": "dense-restored", "size": LANDSCAPE, "density": DENSITY,
			"insets": LANDSCAPE_INSETS, "map_visible": true},
	]
	for profile in profiles:
		var label: String = profile["label"]
		var dimensions: Vector2i = profile["size"]
		var density: float = profile["density"]
		var insets: Rect2 = profile["insets"]
		bridge._options["displayDensity"] = density
		root.size = dimensions
		await _frames()
		await _complete_current(insets)
		# A density configuration can change without new pixel dimensions.
		# Exercise the production callback, then let real Containers settle.
		game._on_viewport_size_changed()
		await _frames(12)
		kart_minimap_layouts.append(_observe_kart_minimap(
			game, label, dimensions, density, insets, bool(profile["map_visible"])))
		await _capture_kart_minimap(label)
		if label == "expanded-inner-display":
			await _kart_minimap_hint_transition(game, density, insets)
	_check(kart_minimap_layouts.size() == profiles.size(),
		"all seven Kart minimap density, cutout and resize observations execute")
	_check(kart_minimap_transitions.size() == 2,
		"both live jump-hint visibility transitions execute without a resize")
	game.abandoned = true
	root.remove_child(game)
	game.free()
	bridge._options["displayDensity"] = DENSITY
	root.size = LANDSCAPE
	await _frames()
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
	await _cache_contract()
	await _scene_contract()
	await _extra_readers_contract()
	await _kart_readers_contract()
	await _kart_minimap_contract()
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
		"kart_minimap_layouts": kart_minimap_layouts, "kart_minimap_images": kart_minimap_images,
		"kart_minimap_transitions": kart_minimap_transitions}
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("MOBILE_SAFE_AREA_%s checks=%d failures=%d controls=%d images=%d scope=platform_boundary_fixture" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), targets.size(), images.size()])
	quit(0 if failures.is_empty() else 1)
