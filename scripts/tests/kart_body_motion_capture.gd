extends SceneTree
## Bildfolge der Kart-Federung im echten Renderer: Ruhe, Bremsen, Gas, Kurve, Landung.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --script \
##   res://scripts/tests/kart_body_motion_capture.gd -- --out=/tmp/body.jpg \
##   [--kart=comet] [--driver=otter]

const DT := 1.0 / 60.0
var out_path := "user://kart_body_motion.jpg"
var kart_style := "comet"
var driver := "otter"
var cell := Vector2i(480, 360)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--kart="):
			kart_style = arg.trim_prefix("--kart=")
		elif arg.begins_with("--driver="):
			driver = arg.trim_prefix("--driver=")
	_run.call_deferred()


func _drive(
	kart: LumoRaceKart,
	seconds: float,
	speed_from: float,
	speed_to: float,
	steer: float,
	brake: float
) -> void:
	var steps := int(round(seconds / DT))
	for step in range(steps):
		kart.set_motion(
			lerpf(speed_from, speed_to, float(step + 1) / float(steps)), steer, false, false
		)
		kart.set_braking(brake)
		kart._process(DT)


func _run() -> void:
	root.size = cell
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("dfe7f0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d3e0")
	env.ambient_light_energy = 0.8
	environment.environment = env
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("9aa6b2")
	floor_mesh.material_override = floor_material
	root.add_child(floor_mesh)
	var kart := LumoRaceKart.new()
	kart.configure(driver, Color("7760ef"), kart_style)
	root.add_child(kart)
	kart.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 34
	root.add_child(camera)
	var stages := [
		["Ruhe", func() -> void: _drive(kart, 1.5, 15.0, 15.0, 0.0, 0.0)],
		["Bremsen", func() -> void: _drive(kart, 0.35, 15.0, 6.0, 0.0, 1.0)],
		[
			"Gas",
			func() -> void:
				_drive(kart, 1.2, 6.0, 6.0, 0.0, 0.0)
				_drive(kart, 0.45, 6.0, 16.0, 0.0, 0.0)
		],
		["Kurve rechts", func() -> void: _drive(kart, 1.0, 16.0, 16.0, 1.0, 0.0)],
		[
			"Landung",
			func() -> void:
				kart.set_driver_runtime_state(true, false, false)
				_drive(kart, 0.6, 16.0, 16.0, 0.0, 0.0)
				kart.set_driver_runtime_state(false, false, false)
				_drive(kart, 0.12, 16.0, 16.0, 0.0, 0.0)
		],
	]
	var sheet := Image.create(cell.x * stages.size(), cell.y * 2, false, Image.FORMAT_RGB8)
	for index in range(stages.size()):
		(stages[index][1] as Callable).call()
		for row in range(2):
			var at := kart.global_position + Vector3(0, 0.55, 0)
			var eye := at + (Vector3(-4.4, 0.45, 0.0) if row == 0 else Vector3(0.0, 0.8, 4.8))
			camera.look_at_from_position(eye, at)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(
				image, Rect2i(Vector2i.ZERO, cell), Vector2i(index * cell.x, row * cell.y)
			)
		print("[BodyCapture] ", stages[index][0], " ", kart.production_vehicle.body_motion())
	var error := sheet.save_jpg(out_path, 0.9)
	print("[BodyCapture] out=", out_path, " err=", error)
	quit(0 if error == OK else 1)
