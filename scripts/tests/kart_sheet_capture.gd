extends SceneTree
## Echtes Engine-„Fahrzeugblatt“: Front, Seite, Heck, Oben, Dreiviertel und Detail eines Karts
## (wie die Referenzblätter, nur aus dem Spiel gerendert, ohne Bildbearbeitung).
## Aufruf:
## godot --rendering-method gl_compatibility --script scripts/tests/kart_sheet_capture.gd -- <out.png> [kart] [driver] [--no-driver] [--tuning=json] [--views=a,b,c]
## Ansichten: front, side, rear, top, three, three_rear, wheel, close_front, seat

const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")
const CELL := Vector2i(720, 540)
const VIEW_SET := {
	"front": [Vector3(0.0, 1.0, -4.6), Vector3(0.0, 0.62, 0.0), Vector3.UP, 30.0],
	"side": [Vector3(-5.0, 0.85, 0.05), Vector3(0.0, 0.6, 0.05), Vector3.UP, 30.0],
	"rear": [Vector3(0.0, 1.15, 4.8), Vector3(0.0, 0.7, 0.0), Vector3.UP, 30.0],
	"top": [Vector3(0.0, 6.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0, 0, 1), 28.0],
	"three": [Vector3(-3.3, 1.75, -4.1), Vector3(0.0, 0.62, 0.0), Vector3.UP, 31.0],
	"three_rear": [Vector3(3.4, 1.85, 4.0), Vector3(0.0, 0.68, 0.0), Vector3.UP, 31.0],
	"wheel": [Vector3(-2.2, 0.55, -1.9), Vector3(-0.8, 0.38, -0.66), Vector3.UP, 26.0],
	"close_front": [Vector3(-1.5, 0.95, -2.5), Vector3(0.0, 0.55, -0.85), Vector3.UP, 30.0],
	"seat": [Vector3(-2.4, 1.6, 2.2), Vector3(0.0, 0.8, 0.3), Vector3.UP, 30.0],
}

var viewport: SubViewport
var kart: Node3D
var camera: Camera3D
var views: Array = ["front", "side", "rear", "top", "three", "three_rear"]
## Mehrere Karts nacheinander (--karts=a,b,c): je Kart eine Ansicht (erste aus --views).
var karts: Array = []
var jobs: Array = []
var index: int = 0
var wait: int = 0
var kart_id: String = "comet"
var driver_id: String = "fox"
var hide_driver: bool = false
var sheet: Image
var out_path: String = "res://exports/screenshots/kart-sheet.png"
var columns: int = 3
var tuning: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var positional: Array = []
	for arg in args:
		if arg == "--no-driver":
			hide_driver = true
		elif arg.begins_with("--views="):
			views = Array(arg.substr(8).split(","))
		elif arg.begins_with("--karts="):
			karts = Array(arg.substr(8).split(","))
		elif arg.begins_with("--tuning="):
			var parsed: Variant = JSON.parse_string(arg.substr(9))
			if parsed is Dictionary:
				tuning = parsed
		else:
			positional.append(arg)
	if positional.size() > 0:
		out_path = positional[0]
	if positional.size() > 1:
		kart_id = positional[1]
	if positional.size() > 2:
		driver_id = positional[2]
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.transparent_bg = true
	var world := Node3D.new()
	viewport.add_child(world)
	# Dieselbe Bühne wie Garage und Werkstatt, ohne Podest; dazu ein dunkler, leicht spiegelnder Boden.
	var built: Dictionary = STAGE.build(world, Color("45d9ef"), false)
	(built.camera as Camera3D).queue_free()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("142540")
	floor_material.metallic = 0.0
	floor_material.roughness = 0.85
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	kart = Node3D.new()
	kart.set_script(load("res://scripts/games/kart_vehicle.gd"))
	world.add_child(kart)
	if karts.is_empty():
		for view_name in views:
			jobs.append([kart_id, str(view_name)])
	else:
		for kart_name in karts:
			jobs.append([str(kart_name), str(views[0])])
	columns = mini(3, jobs.size())
	var rows: int = ceili(float(jobs.size()) / float(columns))
	sheet = Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGBA8)
	_place()


func _place() -> void:
	var job: Array = jobs[index]
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, driver_id)
	if not tuning.is_empty():
		kart.call("set_look", tuning)
	kart.call("configure", driver_id, driver.color, str(job[0]))
	kart.call("set_motion", 0.0, 0.0, false, false)
	if hide_driver and kart.get("driver") != null:
		(kart.get("driver") as Node3D).hide()
	var view: Array = VIEW_SET.get(str(job[1]), VIEW_SET["three"])
	camera.fov = float(view[3])
	camera.look_at_from_position(view[0], view[1], view[2])
	wait = 0


func _process(_delta: float) -> bool:
	wait += 1
	if wait < 20:
		return false
	var shot: Image = viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	var backdrop := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	for row in range(CELL.y):
		var t: float = float(row) / float(CELL.y)
		backdrop.fill_rect(Rect2i(0, row, CELL.x, 1), Color("2f4a74").lerp(Color("14243f"), t))
	backdrop.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
	sheet.blit_rect(backdrop, Rect2i(Vector2i.ZERO, CELL), Vector2i((index % columns) * CELL.x, (index / columns) * CELL.y))
	index += 1
	if index >= jobs.size():
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		assert(sheet.save_png(out_path) == OK)
		print("[KartSheet] PASS: ", out_path, " ", jobs)
		quit(0)
		return true
	_place()
	return false
