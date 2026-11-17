extends SceneTree
## Deterministic *real renderer* B3 art evidence. The exact same script runs
## against the original B2 Godot SHA and the B3 HEAD for five 1280x720 PNGs.
const WORLD = preload("res://scripts/games/kart_world.gd")
const STATIONS: Array[float] = [0.10, 0.28, 0.46, 0.65, 0.84]
const SIDES: Array[float] = [1.0, -1.0, 1.0, -1.0, 1.0]
const NAMES: Array[String] = [
	"01_sun_observatory", "02_cliff_amphitheater", "03_harbor_sails",
	"04_celestial_wheel", "05_wind_garden"
]
var world
var camera: Camera3D
var folder: String
var frame_count: int = 0
var shot_index: int = 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	folder = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not folder.is_empty(), "Screenshot directory is required")
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.1
	camera.far = 1200.0
	world.add_child(camera)
	camera.make_current()
	_aim()

func _aim() -> void:
	var d: float = STATIONS[shot_index] * world.length
	var sign: float = SIDES[shot_index]
	var road: Vector3 = world.position_at(d - 36.0, 0.0)
	var focal: Vector3 = world.position_at(d, sign * 40.0)
	camera.position = road + Vector3.UP * 4.8
	camera.look_at(
		Vector3(focal.x, world._ground_height(focal.x, focal.z) + 18.0, focal.z),
		Vector3.UP
	)
	frame_count = 0

func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 26:
		return false
	var png: String = folder + "/" + NAMES[shot_index] + ".png"
	var snapshot: Image = root.get_texture().get_image()
	assert(snapshot.get_width() == 1280 and snapshot.get_height() == 720)
	assert(snapshot.save_png(png) == OK)
	print("[SonnenhafenHeroCapture] ", NAMES[shot_index])
	shot_index += 1
	if shot_index == STATIONS.size():
		quit(0)
	else:
		_aim()
	return false
