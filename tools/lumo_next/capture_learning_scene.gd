extends SceneTree
## Actual product route, actual imported meshes, renderer readback. These desktop
## measurements are not physical Android/Fold7 performance claims.
var output := ""
var scenario := "bridge_ten"
var dimensions := Vector2i(1280, 720)
var lesson: Node3D
var errors: Array[String] = []
var screenshots: Array[Dictionary] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--case="):
			scenario = argument.trim_prefix("--case=")
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func _wait_frames(count: int = 4) -> void:
	for _index in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)


func _capture(name_value: String) -> void:
	await _wait_frames(3)
	var raster := root.get_texture().get_image()
	_check(raster != null and raster.get_size() == dimensions, "Exact viewport readback: " + name_value)
	if raster == null:
		return
	var filename := output.path_join(name_value + ".png")
	_check(raster.save_png(filename) == OK, "Screenshot saved: " + filename)
	var bounds := Rect2(Vector2(0, lesson.header.get_global_rect().end.y), Vector2(dimensions.x, lesson.footer.get_global_rect().position.y - lesson.header.get_global_rect().end.y))
	var visible_ids: Array[String] = []
	for id: String in lesson.fox.registry.target_ids():
		var view: Dictionary = lesson.fox.registry.viewport_visibility(id, lesson.camera, bounds)
		if bool(view.get("visible", false)):
			visible_ids.append(id)
	var controls: Array[Dictionary] = []
	for button in lesson.actions.get_children():
		if button is Button:
			_check(button.size.x >= 48 and button.size.y >= 48, "48 logical px control: " + button.text)
			controls.append({"text": button.text, "width_logical": button.size.x, "height_logical": button.size.y})
	screenshots.append({"file": filename.get_file(), "viewport": [dimensions.x, dimensions.y], "kind": lesson.activity.kind, "placed": lesson.activity.placed.size(), "initial": lesson.activity.initial_count(), "movable": lesson.tokens.size(), "visible_target_ids": visible_ids, "avatar": lesson.fox.director.diagnostics(), "controls": controls, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "process_seconds": Performance.get_monitor(Performance.TIME_PROCESS)})


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("An output directory and real rendering display are required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = dimensions
	var request := {"kind": "bridge_ten", "a": 8, "b": 5}
	if scenario == "syllables":
		request = {"kind": "syllables", "word": "Banane", "syllables": ["Ba", "na", "ne"]}
	elif scenario == "plant_parts":
		request = {"kind": "plant_parts", "plantPart": "leaf"}
	lesson = load("res://scenes/learning/learning_world.tscn").instantiate()
	lesson.capture_options = {"learning": request, "reduceAnimations": false}
	root.add_child(lesson)
	await _wait_frames(8)
	_check(lesson.fox.is_usable(), "Actual learning rig loaded")
	if not lesson.fox.is_usable():
		_write_report()
		quit(1)
		return
	await _capture("01_initial")
	if scenario == "bridge_ten":
		_check(lesson.tokens.size() == 5, "Exactly five added objects")
		_check(lesson.find_children("InitialCube*", "MeshInstance3D", true, false).size() == 8, "Exactly eight initial objects")
		lesson.fox.set_teaching_target_id("ten_frame_primary/slot_8")
		await _wait_frames(10)
		await _capture("02_point_to_ninth_slot")
		for index in range(2):
			_check(lesson.move_token(index), "Two actual tokens fill the first ten")
			await _wait_frames(4)
			await create_timer(0.65).timeout
		await _capture("03_ten_and_three")
		for index in range(2, 5):
			_check(lesson.move_token(index), "Remaining tokens enter the next ten")
			await _wait_frames(4)
			await create_timer(0.65).timeout
		_check(lesson.activity.is_complete(), "Eight plus five is completed by actual object moves")
		await _capture("04_thirteen")
	elif scenario == "syllables":
		for index in range(3):
			lesson.fox.set_teaching_target_id("syllable_%d" % index)
			_check(lesson.move_token(index), "Current syllable moves to its slot")
			await _wait_frames(4)
			await create_timer(0.65).timeout
		_check(lesson.activity.is_complete(), "Ba-na-ne completed by actual placements")
		await _capture("02_ba_na_ne")
	elif scenario == "plant_parts":
		lesson._inspect("leaf")
		await _wait_frames(10)
		_check(lesson.fox.director.target_id == "plant_leaf", "Leaf explanation targets the actual leaf")
		await _capture("02_leaf_target")
	lesson._stop_speech()
	await _wait_frames(5)
	var stopped: Dictionary = lesson.fox.director.diagnostics()
	_check(stopped.target_id.is_empty() and stopped.point_target_id.is_empty(), "Stop clears gaze and pointing target")
	_check(stopped.mouth_mode == "closed", "Stop closes all mouth shapes")
	await _capture("05_stopped")
	_write_report()
	lesson.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)


func _write_report() -> void:
	var report := {"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "scenario": scenario, "errors": errors, "screenshots": screenshots, "evidence_scope": "Desktop Godot production lesson; no Android GPU or speech-output claim."}
	var file := FileAccess.open(output.path_join("runtime_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("LUMO_PRODUCT_CAPTURE ", JSON.stringify({"captures": screenshots.size(), "errors": errors, "output": output}))
