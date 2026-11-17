extends SceneTree
## Renders real frames of Lumo moving in the 3D Jump scene (xvfb + GL):
## gait_game.png = gameplay camera while running on island 1,
## gait_side_N.png = side close-up sequence over one stride on a flat strip.
## Output directory: LUMO_CAPTURE_DIR (default user://gait_capture).


func _initialize() -> void:
	call_deferred("_run")


func _save(name: String, dir: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(dir.path_join(name))
	print("[LumoGaitCapture] saved %s" % name)


func _run() -> void:
	var dir: String = OS.get_environment("LUMO_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://gait_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
	var game: Node = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	for frame in range(40):
		await physics_frame
	game.message.text = ""
	# Gameplay camera: run diagonally across island 1 toward island 2.
	game.touch_direction = Vector2(0.45, -0.9).normalized()
	for frame in range(32):
		await physics_frame
	await _save("gait_game.png", dir)
	game.touch_direction = Vector2.ZERO
	# Side close-up on a long flat strip, fixed camera beside the path.
	var strip := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(200, 0.5, 8)
	strip.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(200, 0.5, 8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("64b58d")
	mesh.material_override = material
	strip.add_child(mesh)
	strip.position = Vector3(300, 20, 0)
	game.add_child(strip)
	game.actor.position = strip.position + Vector3(-60, 0.4, 0)
	game.actor.velocity = Vector3.ZERO
	game.set_physics_process(true)
	game.touch_direction = Vector2(1.0, 0.0)
	for frame in range(60):
		await physics_frame
	var side := Camera3D.new()
	side.fov = 34
	game.add_child(side)
	side.current = true
	for i in range(6):
		side.position = game.actor.position + Vector3(0, 0.75, 5.2)
		side.look_at(game.actor.position + Vector3(0, 0.7, 0))
		await _save("gait_side_%d.png" % i, dir)
		for frame in range(3):
			await physics_frame
	print("[LumoGaitCapture] PASS frames written to %s" % dir)
	quit(0)
