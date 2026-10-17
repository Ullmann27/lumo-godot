extends SceneTree
## Real in-engine review of the three newly authored 3D Sonnenhafen towers.
const WORLD = preload("res://scripts/games/kart_world.gd")
var world
var camera: Camera3D
var anchors: Array = []
var index: int = 0
var frames: int = 0
const DIRECTORY := "res://exports/sonnenhafen-lookouts"

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	anchors = world.get_meta("sonnenhafen_lookouts")
	assert(anchors.size() == 3)
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.near = 0.1
	camera.far = 750.0
	world.add_child(camera)
	camera.make_current()
	_aim()

func _aim() -> void:
	var base: Vector3 = anchors[index]
	camera.position = base + Vector3(20.0, 14.0, 26.0)
	camera.look_at(base + Vector3.UP * 11.0, Vector3.UP)
	frames = 0

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 16:
		var file: String = "%02d_tower.png" % (index + 1)
		var img: Image = root.get_texture().get_image()
		assert(img.get_width() == 1280 and img.get_height() == 720)
		assert(img.save_png(DIRECTORY + "/" + file) == OK)
		print("[SonnenhafenTowerImages] captured ", file)
		index += 1
		if index == anchors.size():
			quit(0)
		else:
			_aim()
	return false
