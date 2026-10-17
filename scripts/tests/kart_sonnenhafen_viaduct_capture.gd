extends SceneTree
## True 1280x720 Godot GL Compatibility captures of the actual Sonnenhafen.
## Same camera formulas also run on frozen baseline for pixel-level comparison.
const WORLD = preload("res://scripts/games/kart_world.gd")
var world
var camera: Camera3D
var directory: String
var poses: Array[Dictionary] = []
var frame_count: int = 0
var pose_index: int = 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	directory = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not directory.is_empty(), "Capture output must be explicitly set")
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 750.0
	world.add_child(camera)
	camera.make_current()
	_poses()
	_aim()

func _poses() -> void:
	for i in range(2):
		var fraction: float = 0.66 if i == 0 else 0.79
		var side: float = 1.0 if i == 0 else -1.0
		var d: float = world.length * fraction
		var b: Basis = world.frame(d)
		var road: Vector3 = world.position_at(d - 24.0)
		var feature: Vector3 = world.position_at(d, side * 18.0) + Vector3.UP * 8.0
		poses.append({
			"name": "01_chase_viaduct" if i == 0 else "03_second_viaduct",
			"position": road + Vector3.UP * 3.6,
			"target": feature
		})
		if i == 0:
			poses.append({
				"name": "02_coast_observation",
				"position": world.position_at(d + 12.0, side * 44.0) + Vector3.UP * 22.0,
				"target": feature
			})

func _aim() -> void:
	var p: Dictionary = poses[pose_index]
	camera.position = p.position
	camera.look_at(p.target, Vector3.UP)
	frame_count = 0

func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 20:
		return false
	var name: String = str(poses[pose_index].name)
	var image: Image = root.get_texture().get_image()
	assert(image.get_width() == 1280 and image.get_height() == 720)
	assert(image.save_png(directory + "/" + name + ".png") == OK)
	print("[CoastalViaductCapture] ", name)
	pose_index += 1
	if pose_index == poses.size():
		quit(0)
	else:
		_aim()
	return false
