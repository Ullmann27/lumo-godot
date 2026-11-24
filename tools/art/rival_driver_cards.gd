extends SceneTree
## Menükarten der Mitspieler aus den echten Spielmodellen, mit derselben Kamera,
## demselben Licht und derselben Größe (384 px, transparent) wie die Fahrerkarten
## von Lumo, Nova und Milo. Lumos Karte (fox.webp) wird nie überschrieben.
## Aufruf: godot --rendering-method gl_compatibility --script
##   res://tools/art/rival_driver_cards.gd -- [--out=<ordner>] [--sheet=<png>] [id ...]
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const CELL := Vector2i(640, 640)
var out_dir := "res://assets/kart/menu/drivers"
var sheet_path := ""
var wanted: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--sheet="):
			sheet_path = arg.trim_prefix("--sheet=")
		else:
			wanted.append(arg)
	call_deferred("_run")


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _run() -> void:
	var vehicle_script = load("res://scripts/games/kart_vehicle.gd")
	var entries: Array[Dictionary] = []
	for entry in ROSTER.for_game("kart"):
		if wanted.is_empty() or str(entry.id) in wanted:
			entries.append(entry)
	var absolute := out_dir if out_dir.begins_with("/") else ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	var sheet := Image.create(CELL.x * maxi(1, entries.size()), CELL.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1f45"))
	var written := 0
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var id := str(entry.id)
		if id == "fox":
			continue
		var viewport := SubViewport.new()
		viewport.size = CELL
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color("c9d6f2")
		env.environment.ambient_light_energy = 0.7
		env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		viewport.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-30, 200, 0)
		key.light_energy = 1.25
		viewport.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, 20, 0)
		rim.light_color = Color("ffc58a")
		rim.light_energy = 0.8
		viewport.add_child(rim)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-10, 120, 0)
		fill.light_color = Color("7fe8ff")
		fill.light_energy = 0.35
		viewport.add_child(fill)
		var kart: Node3D = vehicle_script.new()
		kart.set_preview_detail(true)
		viewport.add_child(kart)
		kart.configure(id, Color(str(entry.color)), "comet")
		kart.set_reference_rival_enabled(true)
		kart.set_motion(0.0, 0.0, false, false)
		var camera := Camera3D.new()
		camera.fov = 30.0
		viewport.add_child(camera)
		camera.look_at_from_position(Vector3(-1.6, 2.0, -3.4), Vector3(0.0, 1.22, 0.0))
		camera.current = true
		# Freeze the seated pose with open eyes; the blink must not decide the card.
		await _frames(4)
		kart.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(40)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var small := image.duplicate()
		small.resize(384, 384, Image.INTERPOLATE_LANCZOS)
		if small.save_webp(absolute.path_join(id + ".webp"), true, 0.9) == OK:
			written += 1
			print("[RivalCards] ", absolute.path_join(id + ".webp"))
		sheet.blend_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(index * CELL.x, 0))
		viewport.queue_free()
		await _frames(2)
	if not sheet_path.is_empty():
		sheet.save_png(sheet_path)
	print("[RivalCards] bilder=%d" % written)
	quit(0 if written == entries.size() else 1)
