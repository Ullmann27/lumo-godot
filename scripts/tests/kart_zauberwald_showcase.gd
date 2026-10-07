extends SceneTree
## Runtime review captures for the first scaled Zauberwald quality pass.
const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")

var world
var camera: Camera3D
var kart
var shots: Array = []
var index: int = 0
var frame_index: int = 0
var out_dir: String = "res://exports/zauberwald"


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "zauberwald")
	camera = Camera3D.new()
	camera.far = 900
	camera.fov = 58
	world.add_child(camera)
	camera.make_current()
	kart = VEHICLE.new()
	world.add_child(kart)
	kart.configure("fox", Color("3586bc"), "comet")
	kart.set_process(false)
	shots = [
		["01_glow_arch", 0.235, 0.0, Vector3(0.0, 4.0, 10.2), 18.0],
		["02_tree_tunnel", 0.51, 0.0, Vector3(-1.5, 4.2, 10.0), 17.0],
		["03_lichterhain", 0.63, 0.5, Vector3(2.1, 4.0, 9.6), 16.0],
		["04_mushroom_glade", 0.72, -0.4, Vector3(-2.1, 4.1, 9.6), 16.0],
		["05_second_arch", 0.785, 0.0, Vector3(1.4, 4.0, 9.7), 17.0],
		["06_overview", 0.0, 0.0, Vector3.ZERO, 0.0],
	]
	_place()


func _place() -> void:
	var shot: Array = shots[index]
	if shot[0] == "06_overview":
		kart.visible = false
		camera.position = Vector3(148, 112, 154)
		camera.look_at(Vector3(0, 4, -4))
		camera.fov = 54
	else:
		var d: float = fposmod(float(shot[1]) * world.length, world.length)
		kart.visible = true
		kart.transform = world.reset_transform(d, float(shot[2]))
		camera.position = kart.position + world.frame(d) * shot[3]
		camera.look_at(world.position_at(d + float(shot[4])) + Vector3.UP * 1.5)
		camera.fov = 58
	frame_index = 0


func _process(_delta: float) -> bool:
	frame_index += 1
	if frame_index == 10:
		var shot_name: String = str(shots[index][0])
		assert(root.get_texture().get_image().save_png(out_dir + "/" + shot_name + ".png") == OK)
		print("[ZauberwaldShots] captured ", shot_name)
		index += 1
		if index >= shots.size():
			quit(0)
		else:
			_place()
	return false
