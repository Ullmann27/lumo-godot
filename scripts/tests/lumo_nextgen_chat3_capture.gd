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
	if not _require(stage.get_ten_frame_slot_count() == 10,
			"a ten-frame must have exactly ten decorative, noncountable cells"):
		return
	if not _require(stage._mesh_assets.has("CounterBerryGold"),
			"real PBR amber berry variant must be imported from Blender"):
		return
	await _capture("00_math_8_plus_5_initial")
	var original_ids: Array[String] = stage.get_target_ids()
	stage.bridge_to_ten()
	for i in range(75):
		await process_frame
	if not _require(stage.get_counted_amount() == 13
			and stage.get_target_ids() == original_ids,
			"ten bridge must move existing objects without changing identities"):
		return
	if not _require(stage._math_caption != null
			and stage._math_caption.text == "10 + 3 = 13",
			"only after the actual motion the teacher reveals ten plus three"):
		return
	for index in range(2):
		var moved := stage._targets.get("math:8plus5:right:%02d" % (index + 1)) as Node3D
		var slot := stage._math_slots[8 + index] as Node3D
		if not _require(moved.position.distance_to(slot.position + Vector3(0,0,0.27)) < 0.035,
				"exact two gold berries must occupy two empty frame slots"):
			return
	await _capture("08_math_10_plus_3_bridge")
	if not _require(stage.point_at_object("math:8plus5:right:03"),
			"pointing uses a valid stable 3D target"):
		return
	if not _require(stage.pointer_uses_real_hand_bone and stage._point_line.visible,
			"pointing ray must start at imported Blender Hand.L bone"):
		return
	await _capture("06_hand_bone_target_ray")
	if not _require(not stage.point_at_object("not_a_real_object"),
			"unresolved IDs must never produce a fake point"):
		return
	stage.apply_speech_frame(0.22, "viseme_A", true)
	if not _require(stage.character_state == "speak" and stage.speech_active,
			"speaking requires real time event input"):
		return
	var a_morph_found := false
	for shape_index in range(stage._face.mesh.get_blend_shape_count()):
		if str(stage._face.mesh.get_blend_shape_name(shape_index)) == "viseme_A":
			a_morph_found = stage._face.get_blend_shape_value(shape_index) > 0.99
	if not _require(a_morph_found, "the actual glTF viseme must drive a mesh shape key"):
		return
	await _capture("07_viseme_A_speaking")
	stage.interrupt()
	if not _require(not stage.speech_active and stage._current_mouth == "",
			"interruption must immediately stop speech and clear mouth"):
		return
	for shape_index in range(stage._face.mesh.get_blend_shape_count()):
		if not _require(is_zero_approx(stage._face.get_blend_shape_value(shape_index)),
				"interruption must close every mouth shape in GLB mesh"):
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
	print("[LumoChat3Runtime] PASS: avatar imported; 13 math objects; ten bridge; three syllables; eight shapes; stable ID targeting; speech cancellation; 9 native screenshots including math bridge, real hand pointing, viseme and responsive portrait/fold viewports")
	quit(0)
