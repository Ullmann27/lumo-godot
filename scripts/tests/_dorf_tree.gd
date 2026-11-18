extends SceneTree
const ART = preload("res://scripts/creative/build_village_art.gd")
func _initialize():
	call_deferred("_run")
func _run():
	root.size = Vector2i(900, 600)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("9cc4dc")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("aac2da"); e.ambient_light_energy = 0.35; e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38, -32, 0); sun.light_energy = 1.7; sun.shadow_enabled = true; root.add_child(sun)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm; var gm := StandardMaterial3D.new(); gm.albedo_color = Color("587a35"); g.material_override = gm; root.add_child(g)
	var i := 0
	for n in ["tree_oak", "tree_fir", "tree_birch", "bush", "camp"]:
		var t := ART.instance(n); t.position = Vector3(i * 5.0 - 10.0, 0, 0); root.add_child(t); i += 1
	var cam := Camera3D.new(); root.add_child(cam); cam.position = Vector3(0, 5, 14); cam.look_at(Vector3(0, 2.5, 0)); cam.current = true
	for _k in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("DORF_CAPTURE_DIR") + "/trees.png")
	quit()
