extends SceneTree
## The 3D Jump must render the imported original Lumo fox, not a procedural
## replacement. Verify real skeleton, scale, floor alignment, walking, pause
## and preserved collisions in the actual scene, not a static model fixture.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	game.touch_direction = Vector2.ZERO
	for _frame in range(35):
		await physics_frame
	assert(not original.walking, "Original 3D fox stops stepping when still")
	game._pause()
	for _frame in range(3):
		await physics_frame
	assert(original.suspended, "Pause suspends the visible original rig")
	game._resume()
	for _frame in range(3):
		await physics_frame
	assert(not original.suspended, "Resume restores real rig animation")
	game.abandoned = true
	game.queue_free()
	await process_frame
	await process_frame
	print("[JumpOriginalLumo] PASS: original 65-bone GLB visible, grounded, moving, paused and resumed")
	quit(0)
