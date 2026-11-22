extends SceneTree
## Shoot four connected setups on the released track with the actual rigged cast.
## The camera is the film crew. The world, road materials, karts and lighting are
## shared with the race; no debug overlays or enlarged characters are used.
const WORLD = preload("res://scripts/games/kart_world.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const FPS := 24
const FRAMES := 144
var camera: Camera3D
var world: Node3D
var cars: Array[Node3D] = []


func _initialize() -> void:
	call_deferred("_shoot")


func _pose(i: int, distance: float, lane: float, speed: float, boost: bool) -> void:
	cars[i].transform = world.reset_transform(distance, lane)
	cars[i].set_motion(speed, -0.10 + .06*i, boost, false)
	cars[i]._process(1.0 / FPS)


func _shoot() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var directory := args[0]
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_4X
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "windwerk_3000")
	for row in [["fox","comet","3c7590"],["rabbit","gecko_velo","a88cba"],["lion","boru_rally","c8a06b"]]:
		var kart := VEHICLE.new()
		kart.set_preview_detail(true)
		kart.set_animated_lumo_enabled(true)
		kart.configure(row[0], Color(row[2]), row[1])
		kart.set_graphics_quality("high")
		world.add_child(kart)
		kart.set_process(false)
		cars.append(kart)
	camera = Camera3D.new()
	camera.near = .085
	camera.far = 1600
	root.add_child(camera)
	camera.make_current()
	for i in range(4):
		await process_frame
	var stride := 1 if args.size() < 2 else maxi(1,int(args[1]))
	for frame in range(0,FRAMES,stride):
		var t := float(frame)/FPS
		var distance: float
		var eye: Vector3
		var aim: Vector3
		var pace: float
		if t < 1.25:
			# Tight three-quarter tracking shot: wheel and driver's face resolve together.
			var u := t / 1.25
			distance = 118.0 + 3.0*u
			pace = 3.0
			eye = Vector3(1.47 + 1.86*u, .62 + .74*u, -2.48 - 1.65*u)
			aim = Vector3(.22-.22*u,.65+.42*u,-.33+.18*u)
			camera.fov = 34.0
		elif t < 3.0:
			# The close movement cuts into the field racing across the steel viaduct.
			var u := (t - 1.25)/1.75
			distance = 1310.0 + 40.0*u
			pace = 23.0
			eye = Vector3(3.65-4.70*u,1.42+.83*u, -8.10-1.25*u)
			aim = Vector3(-.35,1.05,1.5)
			camera.fov = 44.0
		elif t < 4.5:
			# Reveal the Windwal on its mooring, then pass beneath the wind railway.
			var u := (t-3.0)/1.5
			distance = 720.0 + 22.0*u
			pace = 17.0
			eye = Vector3(3.0-u,2.65+.55*u,8.6)
			aim = Vector3(-4.2,2.1,-7)
			camera.fov = 60.0
		else:
			# Close descending crane into the hero and the illuminated station gantry.
			var u := (t-4.5)/1.5
			distance = 2808.0 + 25.0*u
			pace = 18.0
			eye = Vector3(-5.3+1.9*u,2.10-.82*u,-6.75+1.67*u)
			aim = Vector3(0,1.00,0)
			camera.fov = 38.0
		_pose(0,distance,0,pace,t>=1.25 and t<3)
		_pose(1,distance-2.5+sin(t)*.35, -2.7,pace,false)
		_pose(2,distance-4.2,2.8,pace,false)
		var car := cars[0].global_transform
		camera.look_at_from_position(car * eye, car * aim, car.basis.y)
		await process_frame
		await RenderingServer.frame_post_draw
		var im := root.get_texture().get_image()
		if im == null or im.save_jpg(directory.path_join("frame-%03d.jpg" % frame), .95) != OK:
			quit(1)
			return
	world.free()
	camera.free()
	await process_frame
	print("[WindwerkFilm] Rasterbilder gespeichert. Schrittweite ", stride)
	quit(0)
