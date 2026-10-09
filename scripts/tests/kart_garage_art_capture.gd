extends SceneTree
## Reproducible garage artwork rendered from the selectable game geometry.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(512, 512)
	root.content_scale_size = Vector2i(512, 512)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute("res://exports/garage-art")
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b233b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4e3ff")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -34, 0)
	light.light_color = Color("ffe5d0")
	light.light_energy = 1.15
	stage.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24, 145, 0)
	rim.light_color = Color("79c5ee")
	rim.light_energy = 0.42
	stage.add_child(rim)
	var camera := Camera3D.new()
	camera.fov = 36
	camera.position = Vector3(3.3, 2.3, -4.9)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.90, 0))
	camera.make_current()
	for entry in CATALOG.KARTS:
		var kart = VEHICLE.new()
		kart.configure("fox", Color("76d9ff"), str(entry.id))
		kart.reduced_motion = true
		stage.add_child(kart)
		kart.set_process(false)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var result := image.save_png("res://exports/garage-art/" + str(entry.id) + ".png")
		assert(result == OK)
		kart.free()
	stage.free()
	await process_frame
	print("[GarageArt] PASS: nine menu portraits from exact selectable geometry")
	quit()
