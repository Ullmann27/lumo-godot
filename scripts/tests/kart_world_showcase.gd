extends SceneTree
## Reproducible, actual-engine course and vehicle photographs.
const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var world
var kart
var camera: Camera3D
var frame_index: int = 0
var index: int = 0
var ids: Array[String] = ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]
var capture_cover: bool = false

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	root.size=Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="): ids=[arg.trim_prefix("--track=")]
	capture_cover=OS.get_cmdline_user_args().has("--cover")
	DirAccess.make_dir_recursive_absolute("res://exports/screenshots")
	_next_world()

func _next_world() -> void:
	if is_instance_valid(world):
		root.remove_child(world)
		world.queue_free()
	world=WORLD.new()
	root.add_child(world)
	world.build(OS.get_cmdline_user_args().has("--lightweight"),ids[index])
	var arrays: Array=world.road.mesh.surface_get_arrays(0)
	print("[WorldRender] ",ids[index]," length=",world.length," road normal=",arrays[Mesh.ARRAY_NORMAL][0]," batches=",world.get_child_count()," instances=",world.decoration_count)
	camera=Camera3D.new()
	world.add_child(camera)
	camera.far=700
	camera.fov=58
	var d: float=world.length*0.09
	if ids[index]=="zauberwald": d=world.length*0.465
	if ids[index]=="bergwelt": d=world.length*0.46
	if ids[index]=="holo_city": d=world.length*0.03
	kart=VEHICLE.new()
	world.add_child(kart)
	kart.configure("fox",Color("3586bc"),"comet")
	kart.transform=world.reset_transform(d,0.0)
	kart.set_process(false)
	if capture_cover:
		d=world.length*0.63
		kart.transform=world.reset_transform(d,-1.5)
		camera.fov=43
		camera.position=kart.position+world.frame(d)*Vector3(3.2,1.8,-5.4)
		camera.look_at(kart.position+Vector3.UP*1.05)
	else:
		camera.position=kart.position+world.frame(d)*Vector3(0.0,4.3,9.0)
		camera.look_at(world.position_at(d+12.0)+Vector3.UP*1.5)
	camera.make_current()
	frame_index=0

func _process(_delta: float) -> bool:
	if not is_instance_valid(world): return false
	frame_index+=1
	if frame_index==8:
		var filename: String="lumo-holo-cover" if capture_cover else "world-"+ids[index]
		if world.low_detail: filename+="-lightweight"
		var capture: Image=root.get_texture().get_image()
		assert(capture.save_png("res://exports/screenshots/"+filename+".png")==OK)
		print("[WorldRender] captured ",filename)
		index+=1
		if index>=ids.size():
			quit(0)
		else:
			call_deferred("_next_world")
	return false
