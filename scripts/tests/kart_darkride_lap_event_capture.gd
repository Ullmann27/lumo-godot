extends SceneTree
## Real GL-Compatibility before/after screenshots: lap-2 energy affects pixels.
const WORLD = preload("res://scripts/games/kart_world.gd")
const DIRECTOR = preload("res://scripts/games/kart_darkride_event_director.gd")
const OUTPUT := "res://artifacts/darkride-event"

func _initialize() -> void:
	call_deferred("_run")

func _photo(camera: Camera3D, name: String) -> Image:
	for frame in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	assert(img != null and not img.is_empty())
	assert(img.get_width() == 1280 and img.get_height() == 720)
	var file: String = ProjectSettings.globalize_path(OUTPUT).path_join(name + ".png")
	assert(img.save_png(file) == OK)
	return img

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world: LumoRaceWorld = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen", false)
	var progress: Dictionary = world.get_meta("sonnenhafen_darkride")
	var d: float = lerpf(float(progress.start_m), float(progress.end_m), 0.42)
	var camera := Camera3D.new()
	camera.fov = 73.0
	camera.far = 520.0
	root.add_child(camera)
	camera.current = true
	camera.global_position = world.position_at(d) + world.frame(d).y * 2.4
	camera.look_at(world.position_at(d + 31.0) + world.frame(d + 31.0).y * 2.6)
	var director = DIRECTOR.new()
	director.bind_world(world)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var normal_frame: Image = await _photo(camera, "lap_one")
	director.tick(world.length * 1.74, world.length, 0.35, false)
	var surge_frame: Image = await _photo(camera, "lap_two_neon_surge")
	var changed: int = 0
	var delta_sum: float = 0.0
	for y in range(0, 720, 12):
		for x in range(0, 1280, 12):
			var a: Color = normal_frame.get_pixel(x, y)
			var b: Color = surge_frame.get_pixel(x, y)
			var intensity: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if intensity > 0.026:
				changed += 1
				delta_sum += intensity
	print("[DarkrideEventRender] changed_pixels=", changed, " color_delta=", delta_sum)
	assert(changed > 25, "Surge must visibly affect actual Godot GPU output")
	print("[DarkrideEventRender] PASS: real lap-one and lap-two neon event images differ")
	quit(0)
