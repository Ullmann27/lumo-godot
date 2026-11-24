extends SceneTree
## Real-engine review sheet for every kart driver: 3/4 face close-up plus a side
## cockpit view (seat, hands on the rim, steering column). Usage:
##   godot --rendering-method gl_compatibility --script res://scripts/tests/kart_driver_fit_capture.gd -- <out.png> [steer]
## Draws the actual LumoRaceKart renderer; it starts no race and writes no save.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const ANIMALS: Array[String] = ["fox", "rabbit", "frog", "lion", "owl", "squirrel", "turtle", "otter", "badger", "cat"]
const CELL := Vector2i(420, 420)
const COLUMNS := 5


func _initialize() -> void:
	call_deferred("_capture")


func _view(stage_color: Color) -> Array:
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = stage_color
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9dcf2")
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 150, 0)
	key.light_energy = 1.2
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, -35, 0)
	rim.light_energy = 0.5
	stage.add_child(rim)
	return [viewport, stage]


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "/tmp/lumo-driver-fit.png"
	var steer: float = float(args[1]) if args.size() > 1 else 0.0
	var views: Array = []
	var karts: Array = []
	var models: Array[Dictionary] = []
	for index in range(ANIMALS.size()):
		for shot in range(3):
			var pair: Array = _view([Color("13213a"), Color("1b2c47"), Color("223a52")][shot])
			var kart = VEHICLE.new()
			kart.configure(ANIMALS[index], CATALOG.entry(CATALOG.DRIVERS, ANIMALS[index]).color, "comet")
			pair[1].add_child(kart)
			if ANIMALS[index] == "fox":
				kart.set_animated_lumo_enabled(true)
				assert(is_instance_valid(kart.lumo_animation), "Capture requires the original animated Lumo")
			kart.set_motion(0.0, steer, false, false)
			if ANIMALS[index] != "fox":
				assert(is_instance_valid(kart.production_driver) and kart.production_driver.is_usable(),
					"Capture requires the actual imported driver: " + ANIMALS[index])
				if shot == 0:
					models.append({"driver": ANIMALS[index], "path": kart.production_driver.model_path,
						"sha256": FileAccess.get_sha256(kart.production_driver.model_path)})
			karts.append(kart)
			var camera := Camera3D.new()
			pair[1].add_child(camera)
			if shot == 0:
				camera.fov = 26.0
				camera.look_at_from_position(Vector3(-1.05, 2.05, -2.55), Vector3(0, 1.62, -0.05))
			elif shot == 1:
				camera.fov = 30.0
				camera.look_at_from_position(Vector3(-3.6, 1.45, -0.35), Vector3(0, 1.05, -0.12))
			else:
				camera.fov = 34.0
				camera.look_at_from_position(Vector3(0.9, 2.6, 3.4), Vector3(0, 1.0, -0.4))
			camera.current = true
			views.append(pair[0])
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var groups := ceili(float(ANIMALS.size()) / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * 3 * groups, false, Image.FORMAT_RGBA8)
	for index in range(views.size()):
		var image: Image = views[index].get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var animal_index: int = index / 3
		var group: int = animal_index / COLUMNS
		var column: int = animal_index % COLUMNS
		var row: int = group * 3 + index % 3
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	assert(sheet.save_png(output) == OK)
	print("[DriverFit] PASS ", JSON.stringify({"image": output, "drivers": ANIMALS, "models": models, "steer": steer}))
	for view in views:
		view.free()
	await process_frame
	quit(0)
