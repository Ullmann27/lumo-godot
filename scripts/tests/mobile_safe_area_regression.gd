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
		"checks": checks, "failures": failures, "targets": targets, "events": events, "images": images}
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("MOBILE_SAFE_AREA_%s checks=%d failures=%d controls=%d images=%d scope=platform_boundary_fixture" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size(), targets.size(), images.size()])
	quit(0 if failures.is_empty() else 1)
