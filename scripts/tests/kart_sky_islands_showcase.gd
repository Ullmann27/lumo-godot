extends SceneTree
## Reference-matched views of the Himmelsinseln Sprint course (k07) for visual review.
const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var world
var camera: Camera3D
var kart
var shots: Array = []
var index: int = 0
var frame_index: int = 0
var out_dir: String = "res://exports/sky-islands"


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = WORLD.new()
	root.add_child(world)
	world.build(OS.get_cmdline_user_args().has("--lightweight"), "bergwelt")
	print(
		"[SkyShots] length=",
		world.length,
		" batches=",
		world.get_child_count(),
		" instances=",
		world.decoration_count
	)
	camera = Camera3D.new()
	camera.far = 900
	camera.fov = 62
	world.add_child(camera)
	camera.make_current()
	kart = VEHICLE.new()
	world.add_child(kart)
	kart.configure("fox", Color("3586bc"), "comet")
	kart.set_process(false)
	var item_preview: Node = load("res://scripts/games/kart_island.gd").new()
	item_preview.set("world", world)
	var item_root := Node3D.new()
	item_root.name = "RuntimeMysteryPrisms"
	root.add_child(item_root)
	item_preview.set("race_root", item_root)
	var item_layout: Array = [
		[0.18, -2.7],
		[0.34, 2.7],
		[0.53, 0.0],
		[0.69, -2.7],
		[0.86, 2.7],
	]
	for entry in item_layout:
		item_preview.call("_item_box", float(entry[0]) * world.length, float(entry[1]))
	assert(item_preview.get("item_boxes").size() == item_layout.size())
	print("[SkyShots] runtime Mystery Prisms=", item_layout.size())
	# name, track fraction, lateral kart, camera offset (local), look-ahead distance
	shots = [
		["01_start_gate", -0.035, 0.0, Vector3(0.0, 3.8, 9.5), 22.0],
		["02_waterfall_bridge", 0.19, 1.0, Vector3(0.0, 3.6, 8.5), 16.0],
		["03_floating_town", 0.31, -1.0, Vector3(1.0, 3.6, 8.0), 14.0],
		["04_suspension_bridge", 0.585, 0.0, Vector3(0.0, 3.6, 9.0), 18.0],
		["05_crystal_cave", 0.46, 0.0, Vector3(0.0, 3.8, 9.0), 16.0],
		["06_temple_ruins", 0.69, 1.0, Vector3(-1.0, 3.6, 8.5), 14.0],
		["07_overview", 0.0, 0.0, Vector3(0.0, 0.0, 0.0), 0.0],
		["08_mystery_prisms", 0.16, -2.7, Vector3(0.0, 3.4, 8.5), 13.0]
	]
	_place()


func _place() -> void:
	var shot: Array = shots[index]
	var d: float = fposmod(float(shot[1]) * world.length, world.length)
	if shot[0] == "07_overview":
		kart.visible = false
		camera.position = Vector3(150, 120, 170)
		camera.look_at(Vector3(0, 0, -5))
		camera.fov = 55
	else:
		kart.visible = true
		kart.transform = world.reset_transform(d, float(shot[2]))
		camera.position = kart.position + world.frame(d) * shot[3]
		camera.look_at(world.position_at(d + float(shot[4])) + Vector3.UP * 1.6)
		camera.fov = 62
	frame_index = 0


func _process(_delta: float) -> bool:
	frame_index += 1
	if frame_index == 10:
		var name: String = str(shots[index][0])
		assert(root.get_texture().get_image().save_png(out_dir + "/" + name + ".png") == OK)
		print("[SkyShots] captured ", name)
		index += 1
		if index >= shots.size():
			quit(0)
		else:
			_place()
	return false
