extends SceneTree
## Real-engine art review, same camera and light for the current and previous kart.
var stage: Node3D
var kart: Node3D
var frames: int = 0
var capture_path: String = "/tmp/lumo-kart-current.png"

func _initialize() -> void:
	call_deferred("_build_scene")

func _build_scene() -> void:
	root.size = Vector2i(600, 600)
	root.content_scale_size = Vector2i(600, 600)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("071326")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e5f5")
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_color = Color("fff9f1")
	key.light_energy = 0.95
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 130, 0)
	fill.light_color = Color("d0e9ff")
	fill.light_energy = 0.35
	stage.add_child(fill)
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-65, 175, 0)
	back.light_color = Color("91b8ff")
	back.light_energy = 0.18
	stage.add_child(back)
	var floor := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.2
	cylinder.bottom_radius = 2.3
	cylinder.height = 0.16
	cylinder.radial_segments = 64
	floor.mesh = cylinder
	floor.position.y = -0.085
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("153455")
	mat.roughness = 0.25
	mat.metallic = 0.5
	floor.material_override = mat
	stage.add_child(floor)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(3.65, 2.85, -4.8)
	camera.look_at_from_position(camera.position, Vector3(0, 1.12, 0))
	camera.fov = 38.0
	camera.current = true
	var arguments := OS.get_cmdline_user_args()
	var factory: Script = load("res://scripts/games/kart_vehicle.gd")
	if "--before" in arguments:
		factory = GDScript.new()
		factory.source_code = FileAccess.get_file_as_string("/tmp/lumo-kart-vehicle-before.gd").replace("class_name LumoRaceKart", "")
		factory.reload()
		capture_path = "/tmp/lumo-kart-before.png"
	kart = factory.new()
	stage.add_child(kart)
	kart.configure("fox", Color("327cbe"))
	kart.set_motion(0, 0, false, false)
	kart.set_process(false)
	if "--companion" in arguments:
		kart.configure_companion("fox")
		kart.set_companion_pose(0.6, "help", 0.0)
		camera.position = Vector3(2.5, 2.5, -5)
		camera.look_at_from_position(camera.position, Vector3(0, 1.2, 0))
		capture_path = "/tmp/lumo-companion-current.png"
	if "--front" in arguments:
		camera.position = Vector3(0, 2.0, -5.8)
		camera.look_at_from_position(camera.position, Vector3(0, 1.15, 0))
		capture_path = "/tmp/lumo-front-current.png"
	if "--rear" in arguments:
		camera.position = Vector3(3.8, 2.6, 4.9)
		camera.look_at_from_position(camera.position, Vector3(0, 1.12, 0))
		capture_path = "/tmp/lumo-rear-current.png"
	if "--rabbit" in arguments:
		kart.configure("rabbit", Color("afa7ef"), "glider")
		kart.set_process(false)
		capture_path = "/tmp/lumo-nova-current.png"
	if "--otter" in arguments:
		kart.configure("otter", Color("4cacbd"), "turbo")
		kart.set_process(false)
		capture_path = "/tmp/lumo-milo-current.png"

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 24:
		root.get_texture().get_image().save_png(capture_path)
		print("REAL_ENGINE_CAPTURE=" + capture_path)
		quit()
	return false
