extends SceneTree
## Silent model orbit captured in Godot Movie Maker.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
var stage: Node3D
var camera: Camera3D
var kart
var frames: int = 0
var current: int = -1


func _initialize() -> void:
	root.size = Vector2i(960, 540)
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07182b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d4e3ff")
	env.ambient_light_energy = 0.55
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -34, 0)
	key.light_energy = 1.5
	stage.add_child(key)
	camera = Camera3D.new()
	camera.fov = 36
	stage.add_child(camera)
	camera.make_current()


func _process(_delta: float) -> bool:
	var index: int = mini(5, frames / 36)
	if index != current:
		if is_instance_valid(kart):
			kart.free()
		kart = VEHICLE.new()
		kart.configure("fox", Color("76d9ff"), FLEET.IDS[index])
		stage.add_child(kart)
		kart.set_motion(4.0, 0.0, false, false)
		current = index
	var angle: float = float(frames % 36) / 36.0 * TAU
	camera.position = Vector3(sin(angle) * 5.8, 2.5, -cos(angle) * 5.8)
	camera.look_at(Vector3(0, 0.9, 0))
	frames += 1
	if frames >= 216:
		quit()
	return false
