extends SceneTree
## Rendert je Fahrer des Katalogs ein eigenes Kartenbild aus den echten Spielmodellen
## (Lumo = geriggtes Originalmodell, Nova/Milo = importierte Rivalenfiguren) in
## einheitlicher Dreiviertel-Nahansicht mit transparentem Hintergrund.
## Aufruf: godot --rendering-method gl_compatibility --script
##   res://scripts/tests/kart_driver_card_render.gd -- [--out=<res-ordner>] [--sheet=<png>]
const CELL := Vector2i(640, 640)
var out_dir := "res://assets/kart/menu/drivers"
var sheet_path := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--sheet="):
			sheet_path = arg.trim_prefix("--sheet=")
	call_deferred("_run")


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _run() -> void:
	var catalog = load("res://scripts/games/kart_catalog.gd")
	var vehicle_script = load("res://scripts/games/kart_vehicle.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var sheet := Image.create(CELL.x * catalog.DRIVERS.size(), CELL.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1f45"))
	var written := 0
	for index in range(catalog.DRIVERS.size()):
		var driver: Dictionary = catalog.DRIVERS[index]
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
		kart.configure(str(driver.id), driver.color, "comet")
		kart.set_animated_lumo_enabled(true)
		kart.set_reference_rival_enabled(true)
		kart.set_motion(0.0, 0.0, false, false)
		var camera := Camera3D.new()
		camera.fov = 30.0
		viewport.add_child(camera)
		camera.look_at_from_position(Vector3(-1.55, 1.75, -2.9), Vector3(0.0, 1.05, 0.0))
		camera.current = true
		await _frames(45)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var path := out_dir.path_join(str(driver.id) + ".webp")
		var small := image.duplicate()
		small.resize(384, 384, Image.INTERPOLATE_LANCZOS)
		if small.save_webp(ProjectSettings.globalize_path(path), true, 0.9) == OK:
			written += 1
			print("[DriverCards] ", path)
		sheet.blend_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(index * CELL.x, 0))
		viewport.queue_free()
		await _frames(2)
	if not sheet_path.is_empty():
		sheet.save_png(sheet_path)
	print("[DriverCards] bilder=%d" % written)
	quit(0 if written == catalog.DRIVERS.size() else 1)
