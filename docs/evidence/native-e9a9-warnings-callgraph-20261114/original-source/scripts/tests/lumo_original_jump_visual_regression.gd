extends SceneTree
## The 3D Jump must render the imported original Lumo fox, not a procedural
## replacement. Verify real skeleton, scale, floor alignment, walking, pause
## and preserved collisions in the actual scene, not a static model fixture.
var capture_dir: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		assert(DisplayServer.get_name() != "headless", "Jump captures require a real GL display")
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		assert(not capture_dir.is_empty(), "A capture directory must be supplied")
		assert(DirAccess.make_dir_recursive_absolute(capture_dir) == OK)
		root.size = Vector2i(720, 1280)
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
	var game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	for _frame in range(45):
		await physics_frame
	assert(is_instance_valid(game.actor), "Real CharacterBody exists")
	assert(game.actor.is_on_floor(), "Player remains grounded on first island")
	var original = game.original_lumo
	assert(is_instance_valid(original) and original.is_usable(),
		"Actual 65-bone GLB is selected as visible player")
	assert(original.skeleton.get_bone_count() == 65)
	assert(original.visible and original.model_load_kind == "imported_packed_scene")
	var procedural: Node3D = game.actor.get_node("LumoCharacter")
	assert(not procedural.visible, "There must not be two visible foxes")
	assert(game.actor.get_child_count() >= 3, "Collision, fallback and real actor")
	assert(original.scale.y > 0.07 and original.scale.y <= 3.0)
	if not capture_dir.is_empty():
		await _capture("01_jump_original_grounded")
	var original_rest: Vector3 = original.position
	var starting: Vector3 = game.actor.global_position
	game.touch_direction = Vector2(0.35, 0)
	for _frame in range(34):
		await physics_frame
	assert(game.actor.global_position.distance_to(starting) > 0.35,
		"Real 3D Jump is moving under touch")
	assert(original.walking and original.get_current_behavior() == "walk_loop",
		"Imported original fox animates its actual skinned bones")
	assert(original.position.is_equal_approx(original_rest),
		"Visual gait must not fake root motion or alter collision")
	if not capture_dir.is_empty():
		await _capture("02_jump_original_walking")
	game.touch_direction = Vector2.ZERO
	for _frame in range(35):
		await physics_frame
	assert(not original.walking, "Original 3D fox stops stepping when still")
	game._pause()
	for _frame in range(3):
		await physics_frame
	assert(original.suspended, "Pause suspends the visible original rig")
	if not capture_dir.is_empty():
		await _capture("03_jump_original_paused")
	game._resume()
	for _frame in range(3):
		await physics_frame
	assert(not original.suspended, "Resume restores real rig animation")
	if not capture_dir.is_empty():
		await _capture("04_jump_original_resumed")
	game.abandoned = true
	game.queue_free()
	await process_frame
	await process_frame
	print("[JumpOriginalLumo] PASS: original 65-bone GLB visible, grounded, moving, paused and resumed")
	if not capture_dir.is_empty():
		print("[JumpOriginalLumoCapture] PASS: 4 actual 720x1280 gameplay frames")
	quit(0)


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and frame.get_size() == Vector2i(720, 1280))
	assert(frame.save_png(capture_dir.path_join(name + ".png")) == OK)
	print("[JumpOriginalLumoCapture] saved ", name)
