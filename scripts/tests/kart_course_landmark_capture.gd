extends SceneTree
## Fahrtansichten bei der Anfahrt auf jede Steilkurve. -- --out=<Ordner> [--track=<ID>].
const TRACKS = preload("res://scripts/games/kart_tracks.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var out := ""
var only := ""
var failed := false
var quick := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick":
			quick = true
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg.begins_with("--track="):
			only = arg.trim_prefix("--track=")
	call_deferred("_run")


func _run() -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	for track in TRACKS.IDS:
		if track == "riesengarten_2400" or (not only.is_empty() and not track in only.split(",")):
			continue
		var game = load("res://scenes/games/kart_island.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet",
			"track": track, "difficulty": "flott"})
		game._end_preview()
		game.racing = true
		game.countdown = 0.0
		var prop: Node3D = game.world.find_child("Kurvenwahrzeichen", true, false)
		if prop == null:
			printerr("Fehlendes Wahrzeichen auf ", track)
			failed = true
		else:
			for size in [Vector2i(2176, 1812), Vector2i(1080, 2340)]:
				root.size = Vector2i(Vector2(size) / 3.0) if quick else size
				await process_frame
				if not await _approach(game, prop, track):
					failed = true
		await TEARDOWN.release_scene(self, game, "[CourseLandmarks]")
	print("[CourseLandmarks] ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _approach(game, prop: Node3D, track: String) -> bool:
	var focus := prop.global_position + Vector3.UP * 4.0
	var leads := [25.0, 36.0, 49.0, 22.0, 28.0, 56.0, 70.0, 86.0]
	if track == "volcano_night":
		leads = [56.0, 49.0, 70.0, 36.0]
	for lead in leads:
		var at := float(prop.get_meta("distance")) - float(lead)
		game.distance = at
		game.previous_road_distance = at
		game.player.transform = game.world.reset_transform(at)
		game.player_heading = game._heading(at)
		game._update_vehicles(1.0 / 60.0)
		game._update_camera(1.0, true)
		game._update_hud()
		await process_frame
		var uv: Vector2 = game.camera.unproject_position(focus) / root.get_visible_rect().size
		if game.camera.is_position_in_frustum(focus) and uv.x > .08 and uv.x < .92 and uv.y > .14 and uv.y < .78:
			await process_frame
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			var mesh := prop.find_child("%s_lod0" % track, true, false) as MeshInstance3D
			print("[LandmarkView] ", track, " ", root.size, " projected=", uv,
				" road=", at, " model=", mesh.global_position, " bounds=", mesh.get_aabb().size,
				" camera=", game.camera.global_position, " visible=", mesh.is_visible_in_tree())
			if not await _silhouette(prop):
				continue
			return frame.save_png(out.path_join("%s_%dx%d.png" % [track, frame.get_width(), frame.get_height()])) == OK
	printerr("Wahrzeichen außerhalb der Rennkamera: ", track, " ", root.size)
	return false

## Die Rennkamera muss das echte Modell sehen, auch hinter Bäumen, Bergen und HUD.
## Zwei Markierungsfarben unterscheiden seine Pixel von bewegten Kulissenteilen.
func _silhouette(prop: Node3D) -> bool:
	var meshes := prop.find_children("*", "MeshInstance3D", true, false)
	var diagnostic := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, fog_disabled; uniform vec3 id_color; void fragment(){ALBEDO=id_color;}"
	diagnostic.shader = shader
	for mesh in meshes:
		mesh.material_override = diagnostic
	var marks: Array[Image] = []
	for color in [Vector3(1,0,1), Vector3(0,1,0)]:
		diagnostic.set_shader_parameter("id_color", color)
		await process_frame
		await RenderingServer.frame_post_draw
		var marker := root.get_texture().get_image()
		marker.resize(320, 256)
		marks.append(marker)
	for mesh in meshes:
		mesh.material_override = null
	var count := 0
	for y in 256:
		for x in 320:
			var first := marks[0].get_pixel(x,y)
			if first.r < .60 or first.b < .60:
				continue
			var second := marks[1].get_pixel(x,y)
			if second.g - first.g > .35 and maxf(first.r - second.r, first.b - second.b) > .35:
				count += 1
	print("[LandmarkMask] ", prop.get_meta("section"), " ", count, "/81920")
	return count >= 160
