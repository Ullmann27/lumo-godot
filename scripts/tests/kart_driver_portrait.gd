extends SceneTree
## Echte Engine-Renderings des Lumo-Fahrers aus Front-, Seiten-, Rück- und
## Dreiviertelansicht als Kontaktbogen. Keine Bildbearbeitung.
## Aufruf: godot --rendering-method gl_compatibility --script scripts/tests/kart_driver_portrait.gd -- <out.png>

const VIEWS := [
	["front", Vector3(0.0, 2.1, -5.6)],
	["dreiviertel", Vector3(-3.7, 2.2, -4.2)],
	["seite", Vector3(-5.6, 1.7, 0.1)],
	["hinten", Vector3(0.0, 2.4, 5.6)],
]

var kart: Node3D
var camera: Camera3D
var view_index: int = 0
var wait: int = 0
var sheet: Image
var out_path: String = "res://exports/screenshots/lumo-driver-views.png"
## --cheer: Lumo jubelt (Platz 1) – Arm oben, winkt.
var cheer: bool = false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	cheer = args.has("--cheer")
	root.size = Vector2i(640, 640)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0b1f45")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fb4e8")
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 150, 0)
	sun.light_energy = 1.25
	world.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -30, 0)
	rim.light_color = Color("7fe8ff")
	rim.light_energy = 0.55
	world.add_child(rim)
	kart = Node3D.new()
	kart.set_script(load("res://scripts/games/kart_vehicle.gd"))
	world.add_child(kart)
	kart.call("configure", "fox", Color("1d4fa0"))
	kart.call("set_motion", 0.0, 0.0, false, false)
	if cheer:
		kart.call("celebrate", 1)
	camera = Camera3D.new()
	camera.fov = 34
	world.add_child(camera)
	camera.current = true
	sheet = Image.create(1280, 1280, false, Image.FORMAT_RGBA8)
	_place()


func _place() -> void:
	camera.look_at_from_position(VIEWS[view_index][1], Vector3(0, 0.95, 0))
	wait = 0


func _process(_delta: float) -> bool:
	wait += 1
	if wait < (70 if view_index == 0 else 12):
		return false
	var shot: Image = root.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i((view_index % 2) * 640, (view_index / 2) * 640))
	view_index += 1
	if view_index >= VIEWS.size():
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		assert(sheet.save_png(out_path) == OK)
		print("[DriverPortrait] PASS: ", out_path)
		quit(0)
		return true
	_place()
	return false
