extends SceneTree
## Exercises the actual Android Kart entry, native cards and production camera.
## --capture writes real renderer pixels; headless mode checks room occlusion only.
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const FOLD := Vector2i(1384, 1400)
const CAPTURE_KARTS := ["comet", "boru_rally", "gecko_velo", "glider", "blitz", "phantom"]
var output := "res://exports/device-fix"
var capture := false
var scan_all := false
var density := 1.0
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var game


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture":
			capture = true
		elif argument == "--all":
			scan_all = true
		elif argument.begins_with("--density="):
			density = float(argument.trim_prefix("--density="))
		else:
			output = argument
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("[KartDeviceFix] " + label)


func _settle(frames: int = 5) -> void:
	for _frame in range(frames):
		await process_frame
	if capture:
		await RenderingServer.frame_post_draw


func _tap(button: Control) -> void:
	_check(button.is_visible_in_tree(), str(button.name) + " visible for native touch")
	var pixel := button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pixel
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	await _settle()


func _room_obstructions(menu) -> Dictionary:
	var result := {}
	if not menu.garage_interior.root.is_visible_in_tree():
		return result
	var origin: Vector3 = menu.preview_camera.get_camera_transform().origin
	var points: Array[Vector3] = menu._stage_subject_points(true)
	# Host fitting uses padded bone bounds, whose bottom corners extend into
	# the floor. Walls and ceiling must not cross any sightline to the subject.
	for room_part in ["GarageLeftWall", "GarageRightWall", "GarageBackWall", "GarageCeiling"]:
		var mesh: MeshInstance3D = menu.garage_interior.root.get_node_or_null(room_part)
		if mesh == null or not mesh.is_visible_in_tree():
			continue
		var local_from_world := mesh.global_transform.affine_inverse()
		var bounds := mesh.get_aabb()
		var blocked := 0
		for point in points:
			if bounds.intersects_segment(local_from_world * origin, local_from_world * point) != null:
				blocked += 1
		if blocked > 0:
			result[room_part] = blocked
	return result


func _record(label: String, menu) -> void:
	await _settle(2)
	var blocked := _room_obstructions(menu)
	_check(blocked.is_empty(), label + " room does not occlude kart or host: " + str(blocked))
	var camera: Camera3D = menu.preview_camera
	var record := {
		"name": label, "viewport": [root.size.x, root.size.y], "display_density": density,
		"kart": str(menu.setup.kart), "driver": str(menu.setup.driver), "section": menu.step,
		"camera_transform": str(camera.transform), "optical_origin": str(camera.get_camera_transform().origin),
		"fov": camera.fov, "offset": [camera.h_offset, camera.v_offset],
		"stage_region": str(menu._visible_stage_region()), "room_obstructions": blocked,
		"renderer": RenderingServer.get_current_rendering_method(),
		"physical_android_device": false
	}
	if capture:
		var image := root.get_texture().get_image()
		_check(image != null and image.get_size() == root.size, label + " actual viewport pixels")
		if image != null:
			_check(image.save_png(output.path_join(label + ".png")) == OK, label + " image saved")
			var preview: Image = menu.preview_viewport.get_texture().get_image()
			_check(preview.save_png(output.path_join(label + "-preview.png")) == OK, label + " scene image saved")
			record["image"] = label + ".png"
	records.append(record)
	print("[KartDeviceFix] ", JSON.stringify(record))


func _run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		push_error("[KartDeviceFix] --capture requires an actual renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = FOLD
	var host = root.get_node("HostBridge")
	host._options["displayDensity"] = density
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	game._apply_safe_area(Rect2(0, 0, 0, 0), Vector2(FOLD))
	var menu = game.garage
	_check(menu.get_script().resource_path.ends_with("kart_spatial_menu.gd"), "actual production spatial menu")
	menu.stars = 500
	menu.reduced_motion = true
	menu._refresh()
	game._show_reference_landing(true)
	await _settle()
	await _record("home-comet-1384x1400", menu)
	await _tap(game.reference_landing._navigation.get_node("Open_garage"))
	_check(menu.step == 2, "home Garage button opens real Karts tab")
	var ids: Array = FLEET.ids() if scan_all else CAPTURE_KARTS
	for id in ids:
		var cards: GridContainer = menu.choices.get_child(0)
		var selected: Button = cards.get_node("KartCard_" + id)
		menu.choices.get_parent().ensure_control_visible(selected)
		await _settle(2)
		await _tap(selected)
		_check(str(menu.setup.kart) == id and menu.preview_kart.kart_style == id, "native selection installs " + id)
		await _record("garage-" + id + "-1384x1400", menu)
	await _tap(menu.back_button)
	await _record("home-selected-1384x1400", menu)
	var report := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "frames": records}, "  "))
	report.close()
	game.queue_free()
	await _settle()
	print("[KartDeviceFix] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
