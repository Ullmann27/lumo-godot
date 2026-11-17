extends SceneTree
## Actual renderer evidence: automatically picks the five OLD fixed-ring
## mountain positions nearest to the new 1.85-km road, then aims the same
## five cameras in both the frozen B5 source and the repaired B6 source.
const WORLD = preload("res://scripts/games/kart_world.gd")
var world
var camera: Camera3D
var output_dir: String
var poses: Array[Dictionary] = []
var shot: int = 0
var warmup: int = 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	output_dir = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not output_dir.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output_dir) == OK)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	camera = Camera3D.new()
	camera.fov = 76.0
	camera.near = 0.1
	camera.far = 1350.0
	world.add_child(camera)
	camera.make_current()
	var scored: Array[Dictionary] = []
	for i in range(12):
		var angle: float = float(i) * TAU / 12.0
		var old_mountain := Vector3(cos(angle) * 245.0, -5.0, sin(angle) * 220.0)
		var hit: Vector2 = world._nearest_horizontal(old_mountain)
		scored.append({
			"mountain_index": i, "mountain": old_mountain,
			"distance": float(hit.x), "sample_index": int(hit.y)
		})
	scored.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	for i in range(5):
		var item: Dictionary = scored[i]
		var d: float = world._road_distances[int(item["sample_index"])]
		var mountain: Vector3 = item["mountain"]
		var road_at: Vector3 = world.position_at(d)
		var projected: Vector3 = Vector3(mountain.x,road_at.y + 14.0,mountain.z)
		poses.append({
			"name": "road_%02d_old_mountain_%02d" % [i+1,int(item["mountain_index"])],
			"road_distance": d,
			"old_mountain_distance": float(item["distance"]),
			"eye": world.position_at(d - 11.0) + world.frame(d).y * 5.2,
			"focus": road_at.lerp(projected,0.39) + Vector3.UP * 3.0
		})
	_aim()

func _aim() -> void:
	var p: Dictionary = poses[shot]
	camera.position = p["eye"]
	camera.look_at(p["focus"], Vector3.UP)
	warmup = 0

func _process(_delta: float) -> bool:
	warmup += 1
	if warmup < 22:
		return false
	var p: Dictionary = poses[shot]
	var path: String = output_dir + "/" + p["name"] + ".png"
	var picture: Image = root.get_texture().get_image()
	assert(picture.get_width() == 1280 and picture.get_height() == 720)
	assert(picture.save_png(path) == OK)
	print("[RoadObstructionCapture] %s old_mountain_center_distance=%.2f" %
		[p["name"],float(p["old_mountain_distance"])])
	shot += 1
	if shot >= poses.size():
		print("[RoadObstructionCapture] PASS: five actual 1280x720 road-facing mountain frames")
		quit(0)
	else:
		_aim()
	return false
