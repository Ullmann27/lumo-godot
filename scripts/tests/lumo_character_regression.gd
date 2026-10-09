extends SceneTree
## Regression for the disconnected torso and oversized mouth found in app captures.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lumo = load("res://scenes/characters/lumo/lumo_character.tscn").instantiate()
	lumo.auto_idle_on_ready = false
	var body: Node3D = lumo.get_node("VisualRoot/Body")
	var mouth: MeshInstance3D = lumo.get_node("VisualRoot/Head/MouthSystem/MouthMesh")
	var body_y: float = body.position.y
	root.add_child(lumo)
	await process_frame
	for behavior in LumoAnimationState.STATES:
		lumo.play_behavior(behavior)
		await process_frame
		assert(is_equal_approx(body.position.y, body_y), "Animation separated torso from head")
		assert(mouth.scale.x < 0.3 and mouth.scale.z <= 0.1001, "Mouth exceeds facial dimensions")
	lumo.play_behavior("idle_bounce")
	await create_timer(0.35).timeout
	assert(lumo.get_node("VisualRoot").position.y > 0.001, "Idle must remain visibly animated")
	assert(is_equal_approx(body.position.y, body_y))
	for shape in lumo._mouth.SHAPE_SCALES:
		lumo.set_mouth_shape(shape)
		assert(mouth.scale.x < 0.3 and mouth.scale.y < 0.05 and mouth.scale.z <= 0.1001)
	lumo.play_behavior("encourage")
	assert(lumo._mouth.get_mouth_shape() == "grin", "Changing behavior must retain expression")
	lumo.queue_free()
	await process_frame
	print(
		"[LumoCharacterTests] PASS: attached torso, proportionate visemes, expressions, live idle"
	)
	quit(0)
