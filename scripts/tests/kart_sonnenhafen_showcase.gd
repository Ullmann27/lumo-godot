extends SceneTree
## Reference-review captures for the bright Sonnenhafen family-racer visual pass.
const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")

var world
var camera: Camera3D
var kart
var shots: Array = []
var index: int = 0
var frame_index: int = 0
var out_dir: String = "res://exports/sonnenhafen"


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	var preview := "--menu-preview" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	if preview:
		LumoQuality.set_graphics_choice("high", false)
		root.size = Vector2i(1920, 1080)
	else:
		root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	camera = Camera3D.new()
	camera.far = 900
	camera.fov = 58
	world.add_child(camera)
	camera.make_current()
	kart = VEHICLE.new()
	world.add_child(kart)
	kart.configure("fox", Color("3586bc"), "comet")
	kart.set_process(false)
	# name, track fraction, lateral, camera local offset, look-ahead
	shots = [
		["01_start_grid", 0.012, 0.0, Vector3(0.0, 4.0, 10.5), 20.0],
		["02_grandstand", 0.052, -0.7, Vector3(2.6, 4.2, 10.0), 18.0],
		["03_terraced_curve", 0.165, 0.4, Vector3(-1.8, 4.1, 9.2), 17.0],
		["04_waterfall", 0.575, -0.6, Vector3(2.4, 4.0, 9.5), 17.0],
		["05_harbour_run", 0.82, 0.7, Vector3(-1.8, 4.0, 9.4), 17.0],
		["06_overview", 0.0, 0.0, Vector3.ZERO, 0.0],
	]
	if preview:
		shots = [
			["01_harbor_launch", 0.068, 0.2, Vector3(-2.4, 6.1, 14.0), 28.0],
			["02_harbor_turn", 0.177, -0.4, Vector3(3.0, 8.2, 17.0), 30.0],
			["03_sea_bridge", 0.429, 0.2, Vector3(-2.4, 6.2, 13.0), 22.0],
		]
	_place()


func _place() -> void:
	var shot: Array = shots[index]
	if shot[0] == "06_overview":
		kart.visible = false
		camera.position = Vector3(155, 125, 168)
		camera.look_at(Vector3(0, 1, -4))
		camera.fov = 54
	else:
		var d: float = fposmod(float(shot[1]) * world.length, world.length)
		kart.visible = true
		kart.transform = world.reset_transform(d, float(shot[2]))
		camera.position = kart.position + world.frame(d) * shot[3]
		camera.look_at(world.position_at(d + float(shot[4])) + Vector3.UP * 1.4)
		camera.fov = 58
	frame_index = 0


func _process(_delta: float) -> bool:
	frame_index += 1
	if frame_index == 10:
		var name: String = str(shots[index][0])
		assert(root.get_texture().get_image().save_png(out_dir + "/" + name + ".png") == OK)
		print("[SonnenhafenShots] captured ", name)
		index += 1
		if index >= shots.size():
			quit(0)
		else:
			_place()
	return false
