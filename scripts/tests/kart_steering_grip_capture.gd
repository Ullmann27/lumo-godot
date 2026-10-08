extends SceneTree
## Actual rotating rim/driver contact views, paired unchanged with baseline.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var output: String = OS.get_environment("LUMO_GRIP_CAPTURE_DIR")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	assert(DisplayServer.get_name() != "headless")
	if output.is_empty():
		output = "res://exports/steering-grip"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
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
	scene.add_child(vehicle)
	vehicle.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 37
	camera.position = Vector3(0.48, 1.72, -2.3)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1.17, -0.20))
	for state in [
		{"name": "rest", "steer": 0.0, "place": 0, "speed": 0.0},
		{"name": "neutral", "steer": 0.0, "place": 0, "speed": 18.0},
		{"name": "left", "steer": -1.0, "place": 0, "speed": 18.0},
		{"name": "right", "steer": 1.0, "place": 0, "speed": 18.0},
		{"name": "victory", "steer": 0.0, "place": 1, "speed": 18.0},
	]:
		vehicle.celebrate(state.place)
		vehicle.animation_time = 1.0
		vehicle.set_motion(state.speed, state.steer, false, absf(state.steer) > 0.5)
		for _frame in range(60):
			vehicle._process(1.0 / 60.0)
		for _frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(state.name + ".png")) == OK)
		print("[KartSteeringGripCapture] actual model: ", state.name)
	root.world_3d.fallback_environment = null
	scene.free()
	await process_frame
	print("[KartSteeringGripCapture] PASS: five real driver/rim views")
	quit()
