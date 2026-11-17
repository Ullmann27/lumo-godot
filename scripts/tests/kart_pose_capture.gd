extends SceneTree
## Real renderer captures of Sonnenhafen from fixed camera poses.
## LUMO_POSES (JSON list of {name, position, target}) makes before/after renders
## of different source revisions use identical cameras. Without it, poses are
## derived from the container crane site and written next to the images.
const WORLD = preload("res://scripts/games/kart_world.gd")
var world
var camera: Camera3D
var poses: Array = []
var index: int = 0
var frames: int = 0
var directory: String = "res://exports/sonnenhafen-crane"


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	directory = OS.get_environment("LUMO_CAPTURE_DIR") if OS.get_environment("LUMO_CAPTURE_DIR") != "" else directory
	DirAccess.make_dir_recursive_absolute(directory)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	var source: String = OS.get_environment("LUMO_POSES")
	if source != "":
		poses = JSON.parse_string(FileAccess.get_file_as_string(source))
	else:
		poses = _crane_poses()
		var file := FileAccess.open(directory + "/poses.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(poses, "  "))
		file.close()
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 900.0
	world.add_child(camera)
	camera.make_current()
	_aim()


func _crane_poses() -> Array:
	var frame: Transform3D = world.get_meta("sonnenhafen_crane_frame")
	var crane = load("res://scripts/games/kart_harbor_crane.gd")
	var nearest: Vector2 = world._nearest_horizontal(frame.origin)
	var road: Vector3 = world._road_samples[int(nearest.y)]
	var result: Array = []
	result.append(_pose("01_trackside_view", road + Vector3.UP * 3.4, crane._p(frame, 4.0, 15.0, 0.0)))
	result.append(_pose("02_harbor_overview", crane._p(frame, -48.0, 26.0, -40.0), crane._p(frame, 6.0, 14.0, 0.0)))
	result.append(_pose("03_seaside_boom", crane._p(frame, 46.0, 12.0, 30.0), crane._p(frame, 4.0, 17.0, 0.0)))
	return result


func _pose(name: String, at: Vector3, target: Vector3) -> Dictionary:
	return {"name": name, "position": [at.x, at.y, at.z], "target": [target.x, target.y, target.z]}


func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _aim() -> void:
	camera.position = _vector(poses[index]["position"])
	camera.look_at(_vector(poses[index]["target"]), Vector3.UP)
	frames = 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		var file: String = "%s.png" % poses[index]["name"]
		var image: Image = root.get_texture().get_image()
		assert(image.get_width() == 1280 and image.get_height() == 720)
		assert(image.save_png(directory + "/" + file) == OK)
		print("[SonnenhafenCraneImages] captured ", file)
		index += 1
		if index == poses.size():
			quit(0)
		else:
			_aim()
	return false
