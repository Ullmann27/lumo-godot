extends SceneTree
## Real renderer shots of Sonnenhafen: race camera, elevated overview, landmark.
## Requires a display (xvfb + gl_compatibility). Not a concept image.
const WORLD = preload("res://scripts/games/kart_world.gd")
const NAMES: Array[String] = ["01_race_camera", "02_elevated_overview", "03_landmark_wow"]
var world
var camera: Camera3D
var folder: String
var frame_count: int = 0
var shot_index: int = 0


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280, 720)
	folder = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not folder.is_empty(), "LUMO_CAPTURE_DIR is required")
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 1400.0
	world.add_child(camera)
	camera.make_current()
	_aim()


func _aim() -> void:
	match shot_index:
		0:
			var start: Vector3 = world.position_at(18.0, 0.0)
			var ahead: Vector3 = world.position_at(28.0, 0.0)
			camera.fov = 56.0
			camera.position = start + Vector3.UP * 2.55 - world.forward(18.0) * 4.4
			camera.look_at(ahead + Vector3.UP * 1.15, Vector3.UP)
		1:
			camera.fov = 62.0
			camera.position = Vector3(0.0, 210.0, 268.0)
			camera.look_at(Vector3(12.0, 2.0, 8.0), Vector3.UP)
		2:
			var target := Vector3(110.0, 16.0, -41.0)
			if world.has_meta("harbor_lighthouse"):
				target = world.get_meta("harbor_lighthouse") + Vector3.UP * 16.0
			var sites: Array = world.get_meta("sonnenhafen_hero_landmarks", [])
			for site in sites:
				if str(site["kind"]) == "celestial_wheel":
					target = site["position"] + Vector3.UP * 24.0
					break
			camera.fov = 50.0
			camera.position = target + Vector3(38.0, 18.0, 46.0)
			camera.look_at(target, Vector3.UP)
	frame_count = 0


func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 28:
		return false
	var png: String = folder + "/" + NAMES[shot_index] + ".png"
	var snapshot: Image = root.get_texture().get_image()
	assert(snapshot.get_width() == 1280 and snapshot.get_height() == 720)
	assert(snapshot.save_png(png) == OK)
	print("[SonnenhafenGenerationCapture] ", NAMES[shot_index], " -> ", png)
	shot_index += 1
	if shot_index == NAMES.size():
		quit(0)
	else:
		_aim()
	return false
