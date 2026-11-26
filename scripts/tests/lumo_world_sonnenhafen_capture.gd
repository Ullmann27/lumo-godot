extends SceneTree
## Real-renderer captures of Sonnenhafen in the production World (day and
## evening, Fold7 inner 2176x1812 and outer 1080x2340). Requires a display:
##   xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_world_sonnenhafen_capture.gd -- --out=<dir>
## The camera is the World's own follow camera behind the original Lumo.
const PROFILE := "lumo_c12_sonnenhafen_capture"
const FOLD_INNER := Vector2i(2176, 1812)
const FOLD_OUTER := Vector2i(1080, 2340)
var output := "/tmp/sonnenhafen-capture"
var scene: Node
var harbour: Node
var written: Array[String] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	_run.call_deferred()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[SonnenhafenCapture] FAIL a real renderer is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.remove_absolute("user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json")
	root.size = FOLD_INNER
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 2, "reduceAnimations": false}
	router.goto("world")
	await _frames(40)
	scene = current_scene
	harbour = scene.sonnenhafen if is_instance_valid(scene) else null
	if harbour == null:
		print("[SonnenhafenCapture] FAIL World or Sonnenhafen missing")
		quit(1)
		return
	# Let the residents leave their first spots so the town is in motion.
	_set_hour(10.5)
	await _frames(240)
	# Camera yaw 0 looks south (-Z), PI north, -PI/2 east, PI/2 west.
	await _view("01_day_bridge_inner", FOLD_INNER, Vector3(200, 0, -90), 0.0, 0.36, 9.0)
	await _view("02_day_market_inner", FOLD_INNER, Vector3(205, 0, -168), PI + 0.15, 0.42, 9.5)
	await _view("03_day_lane_outer", FOLD_OUTER, Vector3(140, 0, -140), -PI * 0.5, 0.40, 8.0)
	await _view(
		"04_day_shop_inside_outer", FOLD_OUTER, Vector3(168.5, 0, -154), PI * 0.5, 0.62, 6.5
	)
	await _view(
		"05_day_kontor_inside_inner", FOLD_INNER, Vector3(231.5, 0, -154), -PI * 0.5, 0.66, 6.5
	)
	await _view("06_day_harbour_inner", FOLD_INNER, Vector3(150, 0, -173), -0.3, 0.30, 11.0)
	_set_hour(20.2)
	harbour.evening = harbour.evening_target(20.2)
	await _frames(60)
	await _view("07_evening_quay_inner", FOLD_INNER, Vector3(236, 0, -173), -0.47, 0.28, 11.0)
	await _view("08_evening_market_outer", FOLD_OUTER, Vector3(200, 0, -167), PI, 0.40, 10.0)
	await _view("09_evening_lighthouse_inner", FOLD_INNER, Vector3(258, 0, -190), 0.0, 0.30, 12.0)
	print("[SonnenhafenCapture] PASS %d images in %s" % [written.size(), output])
	for path in written:
		print("  " + path)
	quit(0)


func _set_hour(hour: float) -> void:
	var elapsed := (hour - 8.0) / 14.0 * 720.0
	scene.open_world.routines.elapsed = elapsed


func _view(
	label: String, size: Vector2i, at: Vector3, yaw: float, pitch: float, zoom: float
) -> void:
	root.size = size
	if scene.paused:
		scene._close_dialog()
	scene.player.position = at + Vector3.UP * 0.1
	scene.player.velocity = Vector3.ZERO
	scene.last_safe = scene.player.position
	scene.camera_yaw = yaw
	scene.camera_pitch = pitch
	scene.person_zoom = zoom
	scene.fox.rotation.y = yaw
	await _frames(70)
	var path := output.path_join(label + ".jpg")
	root.get_texture().get_image().save_jpg(path, 0.86)
	written.append(path)
