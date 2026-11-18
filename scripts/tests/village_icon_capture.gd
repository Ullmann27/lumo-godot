extends SceneTree
## Erzeugt die Gebäudebilder der Bauleiste aus den echten Blender-Modellen
## (assets/creative/village3d/ui/bld_<art>.png, 192 px, transparent).
## Aufruf mit Renderer (xvfb, gl_compatibility); nur bei Modelländerung nötig.
const ART = preload("res://scripts/creative/build_village_art.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const OUT := "res://assets/creative/village3d/ui/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6d6e6")
	environment.ambient_light_energy = 0.5
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.25
	environment.adjustment_contrast = 1.1
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.25
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30
	viewport.add_child(camera)
	camera.current = true
	for kind in VISUAL.MODELS:
		var model: String = VISUAL.model_for(kind, 0)
		var node := ART.instance(model)
		viewport.add_child(node)
		var box: AABB = ART.bundle(model).aabb
		var center := box.get_center()
		var extent := box.size.length()
		center.y = maxf(center.y, box.size.y * 0.35)
		camera.position = center + Vector3(0.75, 0.55, 1.0).normalized() * extent * 1.5
		camera.look_at(center)
		for _i in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		image.save_png(ProjectSettings.globalize_path(OUT + "bld_" + kind + ".png"))
		node.queue_free()
		await process_frame
	print("[VillageIcons] PASS ", VISUAL.MODELS.size())
	quit(0)
