extends SceneTree
## Belegbild: die vier Soldaten groß vor neutralem Hintergrund (echte Blender-Modelle,
## Soldaten-Shader). Aufruf mit Renderer (xvfb, gl_compatibility):
##   -- <ausgabe.png> [zustand=stehen] [breite=1800] [hoehe=1000] [zeit=0.6] [nah=0]
## Zusätzlich die Erzeugung der Tafelbilder (Verbände-Tafel):
##   -- cards   -> assets/creative/village3d/ui/troop_<art>.png
const SOLDIERS = preload("res://scripts/creative/build_village_soldiers.gd")
const KINDS := ["schild", "bogen", "speer", "reiter"]
const CARD_DIR := "res://assets/creative/village3d/ui/"


func _initialize() -> void:
	call_deferred("_run")


func _scene(viewport: Node, clear: Color) -> Camera3D:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = clear
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d6e4")
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	env.environment = environment
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = OS.get_environment("NOSHADOW").is_empty()
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -150, 0)
	fill.light_energy = 0.6
	fill.light_color = Color("ffe2c0")
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 28
	viewport.add_child(camera)
	camera.current = true
	return camera


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "cards":
		await _cards()
		quit(0)
		return
	var out := args[0] if args.size() > 0 else "user://soldaten.png"
	var state := args[1] if args.size() > 1 else "stehen"
	var width := int(args[2]) if args.size() > 2 else 1800
	var height := int(args[3]) if args.size() > 3 else 1000
	var wait := float(args[4]) if args.size() > 4 else 0.6
	var near := int(args[5]) if args.size() > 5 else 0
	root.size = Vector2i(width, height)
	var camera := _scene(root, Color("8f9aa6"))
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("7d858d")
	floor_material.roughness = 0.95
	floor_mesh.material_override = floor_material
	root.add_child(floor_mesh)
	var spacing := 1.45
	for index in range(KINDS.size()):
		var figure: Node3D = (
			load("res://scripts/creative/build_village_art.gd").instance("soldier_" + KINDS[index])
			if state == "dorf"
			else SOLDIERS.figure(KINDS[index], state)
		)
		figure.position = Vector3(
			(float(index) - 1.5) * spacing + (0.35 if KINDS[index] == "reiter" else 0.0), 0, 0
		)
		figure.rotation.y = -0.32 if KINDS[index] == "reiter" else -0.18
		root.add_child(figure)
	if near == 1:
		camera.fov = 22
		camera.position = Vector3(-2.2, 1.62, 2.1)
		camera.look_at(Vector3(-1.9, 1.55, 0))
	else:
		camera.position = Vector3(0.2, 1.75, 8.6)
		camera.look_at(Vector3(0.2, 1.15, 0))
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(wait * 1000.0):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out)
	print("soldiers_capture_saved:", out)
	quit(0)


func _cards() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := _scene(viewport, Color(0, 0, 0, 0))
	(viewport.get_child(0) as WorldEnvironment).environment.background_mode = (
		Environment.BG_CLEAR_COLOR
	)
	for kind in KINDS:
		var figure := SOLDIERS.figure(kind, "stehen")
		figure.rotation.y = -0.45 if kind == "reiter" else -0.3
		viewport.add_child(figure)
		var tall := 2.65 if kind == "reiter" else 1.85
		camera.fov = 30
		camera.position = Vector3(0.0, tall * 0.6, tall * 1.8)
		camera.look_at(Vector3(0.05, tall * 0.5, 0))
		for _i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		image.save_png(ProjectSettings.globalize_path(CARD_DIR + "troop_" + kind + ".png"))
		print("troop_card_saved:", kind)
		figure.queue_free()
		await process_frame
