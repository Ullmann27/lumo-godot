extends SceneTree
## Checks actual GPU batches: colour fidelity, spatial separation, no lost props.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scripts/games/kart_world.gd").new()
	root.add_child(world)
	world._prop("box", Vector3(1, 1, 1), Vector3.ONE, Color.RED)
	world._prop("box", Vector3(2, 1, 1), Vector3.ONE, Color.BLUE)
	world._prop("box", Vector3(80, 1, 1), Vector3.ONE, Color.GREEN)
	world._prop("ball", Vector3(1, 40, 1), Vector3(4, 2, 3), Color.WHITE)
	assert(world.groups.size() == 3)
	var color_pair: bool = false
	for group in world.groups.values():
		if group.transforms.size() == 2:
			assert(group.colors == [Color.RED, Color.BLUE])
			assert(group.transforms[1].origin == Vector3(2, 1, 1))
			color_pair = true
	assert(color_pair)
	world._flush_instances()
	var total: int = 0
	var matched_pair: bool = false
	for child in world.get_children():
		assert(child is MultiMeshInstance3D)
		var batch: MultiMesh = child.multimesh
		total += batch.instance_count
		assert(batch.use_colors)
		assert(child.material_override.vertex_color_use_as_albedo)
		# The dummy headless server does not retain GPU buffers. CI also runs
		# this test with OpenGL, where uploaded transforms and colours are read.
		if batch.instance_count == 2 and DisplayServer.get_name() != "headless":
			assert(batch.get_instance_color(0).is_equal_approx(Color.RED))
			assert(batch.get_instance_color(1).is_equal_approx(Color.BLUE))
			assert(batch.get_instance_transform(1).origin == Vector3(2, 1, 1))
			matched_pair = true
		if child.name.contains("background"):
			assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(total == 4)
	assert(matched_pair or DisplayServer.get_name() == "headless")
	world.queue_free()
	await process_frame
	print("[KartWorldTests] PASS: colours, spatial culling batches, transforms, background shadows")
	quit(0)
