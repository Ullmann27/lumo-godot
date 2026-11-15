extends SceneTree
## Real Godot viewport evidence; NOT an Android device proof.
const STAGE := "res://scenes/learning/nextgen/lumo_learning_stage.tscn"
const OUTPUT := "res://exports/lumo-nextgen-chat3/runtime"


func _initialize() -> void:
	call_deferred("_run")


func _require(value: bool, what: String) -> bool:
	if value:
		return true
	push_error("[LumoChat3Runtime] FAILED: " + what)
	quit(1)
	return false


func _capture(name: String) -> void:
	for i in range(6):
		await process_frame
	var image := root.get_texture().get_image()
	var path := OUTPUT + "/" + name + ".png"
	var err := image.save_png(path)
	assert(err == OK, "Unable to write native screenshot " + path)


func _targets_inside_viewport(stage: Node3D, layout_name: String) -> bool:
	var size := stage.get_viewport().get_visible_rect().size
	for object_id in stage.get_target_ids():
		var point := stage._targets.get(object_id) as Node3D
		if not _require(point != null, "stable target exists in " + layout_name):
			return false
		if not _require(not stage._camera.is_position_behind(point.global_position),
				"3D lesson object behind camera in " + layout_name):
			return false
		var pixel: Vector2 = stage._camera.unproject_position(point.global_position)
		if not _require(pixel.x >= 12.0 and pixel.x < size.x - 12.0
				and pixel.y >= 12.0 and pixel.y < size.y - 12.0,
				"3D target " + object_id + " clipped in " + layout_name):
			return false
	return true


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var source := ResourceLoader.load(STAGE, "PackedScene") as PackedScene
	if not _require(source != null, "learning scene must load"):
		return
	var stage := source.instantiate()
	root.add_child(stage)
	for i in range(12):
		await process_frame
	if not _require(stage._actor != null and stage._player != null,
			"original model, new actions and animation player must import"):
		return
	if not _require(stage._face != null,
			"MouthVisemes morph mesh must import"):
		return
	if not _require(stage.get_counted_amount() == 13,
			"8+5 must contain exactly 13 countable objects"):
		return
	var original_ids: Array[String] = stage.get_target_ids()
	stage.bridge_to_ten()
	for i in range(30):
		await process_frame
	if not _require(stage.get_counted_amount() == 13
			and stage.get_target_ids() == original_ids,
			"ten bridge must move existing objects without changing identities"):
		return
	if not _require(stage.point_at_object("math:8plus5:right:03"),
			"pointing uses a valid stable 3D target"):
		return
	if not _require(not stage.point_at_object("not_a_real_object"),
			"unresolved IDs must never produce a fake point"):
		return
	stage.apply_speech_frame(0.22, "viseme_A", true)
	if not _require(stage.character_state == "speak" and stage.speech_active,
			"speaking requires real time event input"):
		return
	stage.interrupt()
	if not _require(not stage.speech_active and stage._current_mouth == "",
			"interruption must immediately stop speech and clear mouth"):
		return
	stage.configure_lesson("math_8_plus_5")
	await _capture("01_math_8_plus_5")
	stage.configure_lesson("reading_ba_na_ne")
	if not _require(stage.get_target_ids().size() == 3,
			"Ba-na-ne must have three syllable targets"):
		return
	await _capture("02_reading_ba_na_ne")
	stage.configure_lesson("patterns_circle_square_triangle")
	if not _require(stage.get_target_ids().size() == 8,
			"pattern has eight existing shapes and one non-counting question"):
		return
	await _capture("03_shapes_pattern")
	root.size = Vector2i(412, 900)
	for i in range(12):
		await process_frame
	stage.configure_lesson("math_8_plus_5")
	if not _require(is_equal_approx(stage._camera.size, 7.0),
			"phone portrait must use its own stacked orthographic stage"):
		return
	if not _targets_inside_viewport(stage, "phone_portrait_math"):
		return
	if not _require(stage._board_background.position == stage._board.position,
			"portrait panel must follow stable 3D learning-board transform"):
		return
	await _capture("04_phone_portrait_math")
	root.size = Vector2i(920, 820)
	for i in range(12):
		await process_frame
	stage.configure_lesson("reading_ba_na_ne")
	if not _require(is_equal_approx(stage._camera.size, 5.9),
			"fold-like opened layout must retain wide screen framing"):
		return
	if not _targets_inside_viewport(stage, "fold_like_syllables"):
		return
	await _capture("05_fold_like_opened_syllables")
	print("[LumoChat3Runtime] PASS: avatar imported; 13 math objects; ten bridge; three syllables; eight shapes; stable ID targeting; speech cancellation; 5 native screenshots including phone portrait and opened fold-like viewports")
	quit(0)
