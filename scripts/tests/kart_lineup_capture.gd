extends SceneTree
## Echte Engine-Renderings aller Karts: Dreiviertelansicht als Kontaktbogen.
## Rendert in einen eigenen SubViewport fester Größe (unabhängig vom Fenster).
## Keine Bildbearbeitung. Aufruf:
## godot --rendering-method gl_compatibility --script scripts/tests/kart_lineup_capture.gd -- <out.png> [driver] [id1,id2,...]

const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const CELL := Vector2i(640, 480)

var viewport: SubViewport
var kart: Node3D
var camera: Camera3D
var ids: Array = []
var index: int = 0
var wait: int = 0
var driver_id: String = "fox"
var sheet: Image
var out_path: String = "res://exports/screenshots/kart-lineup.png"
var columns: int = 3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	if args.size() > 1:
		driver_id = args[1]
	if args.size() > 2:
		ids = Array(args[2].split(","))
	else:
		for item in CATALOG.KARTS:
			ids.append(str(item.id))
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("17294a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fb4e8")
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, -35, 0)
	rim.light_color = Color("7fe8ff")
	rim.light_energy = 0.6
	world.add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("22375e")
	floor_material.metallic = 0.4
	floor_material.roughness = 0.45
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 32
	world.add_child(camera)
	camera.current = true
	kart = Node3D.new()
	kart.set_script(load("res://scripts/games/kart_vehicle.gd"))
	world.add_child(kart)
	columns = mini(3, ids.size())
	var rows: int = ceili(float(ids.size()) / float(columns))
	sheet = Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGBA8)
	_place()


func _place() -> void:
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, driver_id)
	kart.call("configure", driver_id, driver.color, str(ids[index]))
	kart.call("set_motion", 0.0, 0.0, false, false)
	camera.look_at_from_position(Vector3(-3.9, 2.0, -4.9), Vector3(0, 0.62, 0))
	wait = 0


func _process(_delta: float) -> bool:
	wait += 1
	if wait < 18:
		return false
	var shot: Image = viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i((index % columns) * CELL.x, (index / columns) * CELL.y))
	index += 1
	if index >= ids.size():
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		assert(sheet.save_png(out_path) == OK)
		print("[KartLineup] PASS: ", out_path, " ", ids)
		quit(0)
		return true
	_place()
	return false
