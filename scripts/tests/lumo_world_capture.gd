extends SceneTree
## Actual playable-scene capture. Requires a real display/rendering driver.
## The synthetic village fixture uses the real settlement schema and loader.
## No user profile, building state or runtime art is substituted for the capture.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const VILLAGE = preload("res://scripts/creative/lumo_world_village.gd")
const SETTLEMENT = preload("res://scripts/creative/build_settlement_state.gd")
const PROFILE := "lumo_world_capture_20261123"
var output := "/tmp/lumo-world-capture"
var scene: Node3D
var captures: Array[Dictionary] = []
var world_path := ""
var village_path := ""
var fixture_bytes := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("A real GL/Vulkan renderer is required; headless cannot produce gameplay evidence")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create capture directory")
		return
	world_path = "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"
	village_path = VILLAGE.save_path_for(PROFILE, 1)
	DirAccess.remove_absolute(world_path)
	var village = SETTLEMENT.new("settlement", true)
	for plot in range(9):
		village.try_build("house", plot)
		if village.player().buildings.size() >= 3:
			break
	fixture_bytes = JSON.stringify({"version": 1, "child": PROFILE, "mode": "settlement", "slot": 1, "settlement": village.snapshot(), "village_meta": {}})
	var fixture := FileAccess.open(village_path, FileAccess.WRITE)
	if fixture == null:
		_fail("Cannot write isolated village fixture")
		return
	fixture.store_string(fixture_bytes)
	fixture.close()
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.msaa_3d = Viewport.MSAA_2X
	root.get_node("SceneRouter").launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": false}
	scene = load("res://scenes/creative/lumo_world.tscn").instantiate()
	root.add_child(scene)
	for index in range(20):
		await process_frame
	if not scene.fox.is_real() or scene.own_village.source_status != "loaded":
		_fail("Original Lumo or actual village fixture did not load")
		return
	var views: Array[Dictionary] = [
		{"name": "treasure_foundation", "size": Vector2i(1280, 720), "at": STATE.SPAWN, "drive": false},
		{"name": "village_walking", "size": Vector2i(1280, 720), "at": Vector3(91, 0.2, 20), "drive": false},
		{"name": "school_portrait", "size": Vector2i(720, 1280), "at": Vector3(110, 0.2, -20), "drive": false},
		{"name": "kart_driving", "size": Vector2i(1280, 720), "at": Vector3(77, 0.2, 18), "drive": true},
		{"name": "saved_village", "size": Vector2i(1280, 720), "at": scene.own_village.doorway(), "drive": false}
	]
	for view in views:
		if not await _capture(view):
			return
	if FileAccess.get_file_as_string(village_path) != fixture_bytes:
		_fail("Capture changed the projected village save")
		return
	var report := {
		"kind": "actual gameplay viewport capture", "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(),
		"sourceCommit": OS.get_environment("LUMO_PRODUCT_SHA"), "profile": "synthetic isolated fixture",
		"originalLumo": scene.fox.is_real(), "sameVillageSave": true,
		"captures": captures, "performanceScope": "Measurements describe this capture machine only, not Android device performance"
	}
	var file := FileAccess.open(output.path_join("world-capture.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write capture report")
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	_cleanup()
	print("[LumoWorldCapture] PASS views=", captures.size(), " renderer=", RenderingServer.get_current_rendering_method())
	quit(0)


func _capture(view: Dictionary) -> bool:
	if scene.driving:
		scene.drive_speed = 0.0
		scene._toggle_vehicle()
	root.size = view.size
	scene.player.position = view.at
	scene.player.velocity = Vector3.ZERO
	scene.last_safe = view.at
	scene.camera.position = view.at + Vector3(4.6, 5, 10)
	scene.own_village.update_focus(view.at, 0.0)
	scene._layout()
	if bool(view.drive):
		scene.kart_body.position = view.at
		scene._toggle_vehicle()
		if not scene.driving:
			_fail("Kart entry failed in production scene")
			return false
		scene.joystick.axis = Vector2(0, -0.35)
		scene.joystick.target = Vector2(0, -0.35)
	for index in range(40):
		await process_frame
	var durations: Array[float] = []
	var started := Time.get_ticks_usec()
	for index in range(60):
		await process_frame
		var finished := Time.get_ticks_usec()
		durations.append(float(finished - started) / 1000.0)
		started = finished
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	if pixels.is_empty() or pixels.get_width() != view.size.x or pixels.get_height() != view.size.y:
		_fail("Invalid image dimensions for " + str(view.name))
		return false
	var colors: Dictionary = {}
	for y in range(12):
		for x in range(12):
			colors[pixels.get_pixel((pixels.get_width() - 1) * x / 11, (pixels.get_height() - 1) * y / 11).to_html()] = true
	if colors.size() < 10:
		_fail("Viewport appears blank for " + str(view.name))
		return false
	var filename: String = "world-" + str(view.name) + ".webp"
	if pixels.save_webp(output.path_join(filename), true, 0.9) != OK:
		_fail("Cannot save " + filename)
		return false
	durations.sort()
	var at: Vector3 = scene._active_position()
	captures.append({"file": filename, "view": view.name, "width": view.size.x, "height": view.size.y,
		"position": [at.x, at.y, at.z], "driving": scene.driving, "camera": "normal gameplay follow camera",
		"frames": durations.size(), "frameMsMedian": durations[30], "frameMsP95": durations[56], "frameMsMax": durations[59],
		"drawCalls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "sampledColors": colors.size()})
	scene.joystick.axis = Vector2.ZERO
	scene.joystick.target = Vector2.ZERO
	print("[LUMO_WORLD_CAPTURE] ", filename)
	return true


func _fail(message: String) -> void:
	printerr("[LumoWorldCapture] FAIL ", message)
	_cleanup()
	quit(1)


func _cleanup() -> void:
	if not world_path.is_empty():
		DirAccess.remove_absolute(world_path)
	if not village_path.is_empty():
		DirAccess.remove_absolute(village_path)
