extends SceneTree
## Modellschau der Dorf-Modelle (Blender-GLB) unter Tages- und Abendlicht.
## Ausgabe: DORF_CAPTURE_DIR/modelle_*.png. Nur Bildprüfung, keine Spielregeln.
const ART = preload("res://scripts/creative/build_village_art.gd")
const NAMES := [
	"house_a", "house_b", "house_c", "farm", "lumber", "quarry", "market", "school", "well", "grain",
	"bakery", "road", "clinic", "watermill", "watchtower", "warehouse", "workshop", "scaffold", "cart",
	"boat", "lantern", "fence", "tree_oak", "tree_fir", "tree_birch", "bush", "rock_a", "rock_b",
	"flowers", "reeds", "sheep", "cow", "chicken", "beacon", "dock", "bridge"
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := OS.get_environment("DORF_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9cc4dc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8cde0")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("7fa452")
	ground.material_override = ground_mat
	world.add_child(ground)
	var columns := 9
	for index in range(NAMES.size()):
		var node := ART.instance(NAMES[index])
		node.position = Vector3((index % columns) * 7.0 - 28.0, 0, (index / columns) * 8.0 - 12.0)
		if NAMES[index] == "bridge":
			node.position = Vector3(0, 4.8, 24.0)
		world.add_child(node)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var views := [
		["modelle_ueberblick", Vector3(0, 30, 42), Vector3(0, 0, 4)],
		["modelle_nah_a", Vector3(-18, 6, 1), Vector3(-18, 1.8, -12)],
		["modelle_nah_b", Vector3(7, 6, 9), Vector3(7, 1.8, -4)],
	]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		for _i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join(view[0] + ".png"))
	ART.material().set_shader_parameter("night", 1.0)
	environment.ambient_light_energy = 0.18
	sun.light_energy = 0.15
	camera.position = views[1][1]
	camera.look_at(views[1][2])
	for _i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join("modelle_abend.png"))
	print("[VillageModels] PASS")
	quit(0)
