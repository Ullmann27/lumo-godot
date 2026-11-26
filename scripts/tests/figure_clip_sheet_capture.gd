extends SceneTree
## Bildfolgen (Kontaktbogen) einzelner Figuren-Clips mit dem echten Renderer.
## Lädt das importierte GLB als PackedScene, spielt jeden Clip an N Zeitpunkten
## und legt die Bilder nebeneinander. Keine Spiellogik, nur Sichtprüfung.
##
## xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . --rendering-method gl_compatibility \
##   --audio-driver Dummy --script res://scripts/tests/figure_clip_sheet_capture.gd -- \
##   --model=res://assets/kart/production/drivers/lion/driver.glb --clips=idle,celebrate \
##   --frames=6 --view=side --out=/tmp/sheet.jpg

var model_path := ""
var clips: Array[String] = []
var frames := 6
var view := "three"
var out_path := ""
var cell := Vector2i(360, 480)
var ground := true
var travel := 0.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			model_path = arg.trim_prefix("--model=")
		elif arg.begins_with("--clips="):
			for clip in arg.trim_prefix("--clips=").split(",", false):
				clips.append(clip)
		elif arg.begins_with("--frames="):
			frames = maxi(1, int(arg.trim_prefix("--frames=")))
		elif arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--cell="):
			var parts := arg.trim_prefix("--cell=").split("x")
			cell = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--no-ground":
			ground = false
	_run.call_deferred()


func _typed(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _typed(child, type_name)
		if found != null:
			return found
	return null


func _studio() -> Node3D:
	var studio := Node3D.new()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e9eef4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d3e0")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	studio.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.85, 0.65, 0.0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	studio.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.35, 2.6, 0.0)
	rim.light_energy = 0.45
	studio.add_child(rim)
	if ground:
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(12, 12)
		floor_mesh.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("b9c4cf")
		material.roughness = 0.9
		floor_mesh.material_override = material
		studio.add_child(floor_mesh)
		# Raster alle 25 cm: Fußkontakt und Gleiten werden sichtbar.
		for index in range(-12, 13):
			for axis in [0, 1]:
				var line := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.006, 0.002, 6.0) if axis == 0 else Vector3(6.0, 0.002, 0.006)
				line.mesh = box
				line.position = (
					Vector3(index * 0.25, 0.001, 0)
					if axis == 0
					else Vector3(0, 0.001, index * 0.25)
				)
				var line_material := StandardMaterial3D.new()
				line_material.albedo_color = Color("8d99a6")
				line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				line.material_override = line_material
				studio.add_child(line)
	return studio


func _run() -> void:
	if model_path.is_empty() or out_path.is_empty():
		push_error("--model und --out angeben")
		quit(2)
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("Kein PackedScene: " + model_path)
		quit(2)
		return
	root.size = cell
	var studio := _studio()
	root.add_child(studio)
	var figure := packed.instantiate() as Node3D
	studio.add_child(figure)
	var player := _typed(figure, "AnimationPlayer") as AnimationPlayer
	if player == null:
		await _static_views(studio, figure)
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if clips.is_empty():
		for clip in player.get_animation_list():
			clips.append(str(clip))
	var bounds := AABB()
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	var height := maxf(bounds.size.y, 0.5)
	var target := Vector3(0, height * 0.5, 0)
	var direction := Vector3(1, 0.18, 0)
	match view:
		"front":
			direction = Vector3(0, 0.15, -1)
		"back":
			direction = Vector3(0, 0.2, 1)
		"three":
			direction = Vector3(0.75, 0.25, -0.75)
		"top":
			direction = Vector3(0.3, 1.2, -0.3)
	var camera := Camera3D.new()
	camera.fov = 30.0
	studio.add_child(camera)
	camera.look_at_from_position(target + direction.normalized() * height * 2.6, target)
	var sheet := Image.create(cell.x * frames, cell.y * clips.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE)
	var report: Dictionary = {}
	for row in range(clips.size()):
		var clip := clips[row]
		if not player.has_animation(clip):
			push_warning("Clip fehlt: " + clip)
			continue
		var animation := player.get_animation(clip)
		report[clip] = {"length": animation.length, "loop": animation.loop_mode}
		player.play(clip, 0.0)
		for column in range(frames):
			var t := (
				animation.length
				* float(column)
				/ float(maxi(1, frames - (0 if animation.loop_mode != Animation.LOOP_NONE else 1)))
			)
			player.seek(minf(t, animation.length), true)
			player.advance(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(
				image, Rect2i(Vector2i.ZERO, cell), Vector2i(column * cell.x, row * cell.y)
			)
	var error := (
		sheet.save_jpg(out_path, 0.88) if out_path.ends_with(".jpg") else sheet.save_png(out_path)
	)
	print(
		"[ClipSheet] ",
		model_path,
		" clips=",
		clips.size(),
		" frames=",
		frames,
		" out=",
		out_path,
		" err=",
		error,
		" ",
		JSON.stringify(report)
	)
	quit(0 if error == OK else 1)


## Statische Modelle (Karosserien): eine Zeile mit Front, Seite, Dreiviertel, Heck, Oben.
func _static_views(studio: Node3D, figure: Node3D) -> void:
	var bounds := AABB()
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	var radius := maxf(bounds.size.length() * 0.5, 0.3)
	var target := bounds.get_center()
	var camera := Camera3D.new()
	camera.fov = 30.0
	studio.add_child(camera)
	var directions := [
		Vector3(0, 0.15, -1),
		Vector3(1, 0.1, 0),
		Vector3(0.8, 0.45, -0.8),
		Vector3(0, 0.25, 1),
		Vector3(0.01, 1, 0)
	]
	var sheet := Image.create(cell.x * directions.size(), cell.y, false, Image.FORMAT_RGB8)
	for index in range(directions.size()):
		var direction: Vector3 = directions[index]
		camera.look_at_from_position(
			target + direction.normalized() * radius * 3.9,
			target,
			Vector3.UP if index < 4 else Vector3.FORWARD
		)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i(index * cell.x, 0))
	var error := sheet.save_jpg(out_path, 0.88)
	print(
		"[ClipSheet] static ", model_path, " size=", bounds.size, " out=", out_path, " err=", error
	)
	quit(0 if error == OK else 1)
