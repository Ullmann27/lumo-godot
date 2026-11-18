extends SceneTree
## Turnaround review of one kart with its driver in the real engine: side,
## front three-quarter, rear chase and top view. Writes PNG files for a human
## look at seat position, proportions and model quality.
## Usage (native renderer):
##   LUMO_KART_TURNAROUND_DIR=/abs/dir godot --path . \
##     --script res://tools/art/render_kart_turnaround.gd -- [kart ...] [--driver=fox] [--steer=0.6]
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const VIEWS: Dictionary = {
	"side": [Vector3(4.6, 1.1, 0.0), Vector3(0, 0.75, 0)],
	"front": [Vector3(2.6, 1.7, -3.9), Vector3(0, 0.8, 0)],
	"rear": [Vector3(-1.5, 2.2, 4.4), Vector3(0, 0.9, 0)],
	"top": [Vector3(0.01, 6.2, 0.0), Vector3(0, 0, 0)],
}
var destination: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	destination = OS.get_environment("LUMO_KART_TURNAROUND_DIR")
	if destination.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[KartTurnaround] Needs LUMO_KART_TURNAROUND_DIR and a native rendering window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(900, 700)
	root.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c9d6e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6edf7")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -35, 0)
	key.light_energy = 1.05
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 140, 0)
	fill.light_energy = 0.35
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("8f9aa8")
	ground_material.roughness = 0.9
	ground.material_override = ground_material
	stage.add_child(ground)
	# One metre grid marks for scale.
	for i in range(-3, 4):
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.002, 6.0)
		mark.mesh = box
		mark.position = Vector3(float(i), 0.002, 0)
		stage.add_child(mark)
	var camera := Camera3D.new()
	camera.fov = 32.0
	stage.add_child(camera)
	camera.current = true
	var driver := "fox"
	var steer := 0.0
	var karts: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--driver="):
			driver = argument.trim_prefix("--driver=")
		elif argument.begins_with("--steer="):
			steer = float(argument.trim_prefix("--steer="))
		elif FLEET.has(argument):
			karts.append(argument)
	if karts.is_empty():
		karts.append("comet")
	var saved := 0
	for id in karts:
		var kart: Node3D = load("res://scripts/games/kart_vehicle.gd").new()
		stage.add_child(kart)
		kart.configure(driver, Color("327cbe"), id)
		kart.set_motion(12.0, steer, false, false)
		for i in range(20):
			await process_frame
		for view in VIEWS:
			camera.look_at_from_position(VIEWS[view][0], VIEWS[view][1],
				Vector3.FORWARD if view == "top" else Vector3.UP)
			for i in range(3):
				await process_frame
				await RenderingServer.frame_post_draw
			var file := destination.path_join("%s_%s_%s.png" % [id, driver, view])
			if root.get_texture().get_image().save_png(file) == OK:
				saved += 1
				print("[KartTurnaround] " + file)
		kart.queue_free()
		await process_frame
	print("[KartTurnaround] %d pictures" % saved)
	quit(0 if saved == karts.size() * VIEWS.size() else 1)
