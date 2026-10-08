extends SceneTree
## Real model renders for comparison with the supplied front/rear references.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(900, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b1c32")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("f1f3ff")
	settings.ambient_light_energy = 0.42
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = settings
	scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.light_color = Color("fff2e5")
	key.light_energy = 1.0
	scene.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-26, 148, 0)
	rim.light_color = Color("76e5ff")
	rim.light_energy = 0.5
	scene.add_child(rim)
	var vehicle = VEHICLE.new()
	vehicle.configure("fox", Color("76d9ff"), "comet")
	vehicle.reduced_motion = true
	scene.add_child(vehicle)
	vehicle.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 34
	scene.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://exports/reference-design")
	for view in [
		{"name": "lumo_front", "at": Vector3(0, 1.95, -5.6)},
		{"name": "lumo_rear", "at": Vector3(0, 2.65, 5.7)},
		{"name": "lumo_three_quarter", "at": Vector3(3.9, 2.65, -5.3)},
		{"name": "lumo_side", "at": Vector3(5.9, 2.0, 0.1)},
	]:
		camera.position = view.at
		camera.look_at(Vector3(0, 1.11, 0))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://exports/reference-design/%s.png" % view.name)
	print("[ReferenceCapture] PASS: four actual 3D model views")
	scene.free()
	await process_frame
	quit()
