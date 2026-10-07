extends SceneTree
## Rendered evidence for the authoring-only Sky Halo loop. This is NOT a driveability claim.
const AUTHORING_SCENE = preload("res://scenes/games/track_authoring/sky_halo_loop_authoring.tscn")
var scene: Node3D
var camera: Camera3D
var shots := [
	["01_side", Vector3(31, 15, 0), Vector3(0, 12, 0), 52.0],
	["02_three_quarter", Vector3(25, 19, 31), Vector3(0, 11, 0), 54.0],
]
var index := 0
var frames := 0
const OUT := "res://exports/sky-halo-authoring"


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = AUTHORING_SCENE.instantiate()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07152f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8dcff")
	env.ambient_light_energy = 0.85
	environment.environment = env
	scene.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_color = Color("d8ecff")
	key.light_energy = 1.25
	scene.add_child(key)
	camera = Camera3D.new()
	camera.far = 300
	scene.add_child(camera)
	camera.make_current()
	_place()


func _place() -> void:
	var shot: Array = shots[index]
	camera.position = shot[1]
	camera.fov = float(shot[3])
	camera.look_at(shot[2])
	frames = 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		var name := str(shots[index][0])
		assert(root.get_texture().get_image().save_png(OUT + "/" + name + ".png") == OK)
		print("[SkyHaloShots] captured ", name, " AUTHORING_ONLY")
		index += 1
		if index >= shots.size():
			quit(0)
		else:
			_place()
	return false
