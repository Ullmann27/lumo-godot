extends SceneTree
## Deterministic renderer proof for the authored harbor; no fake gameplay/FPS.
const WORLD = preload("res://scripts/games/kart_world.gd")
var world
var camera: Camera3D
var out: String
var views: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames(5)
	var image: Image = root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(out.path_join(name + ".png")) == OK)
	(
		views
		. append(
			{
				"name": name,
				"draw_calls":
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				),
				"primitives":
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
				),
				"camera": str(camera.transform),
				"fov": camera.fov,
			}
		)
	)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	seed(2014)
	out = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not out.is_empty())
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	root.get_node("PerformanceManager").set_profile(2, false)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	# Keep random fireworks out of both comparison stills, identically.
	for child in world.get_children():
		if child is GPUParticles3D:
			child.emitting = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 1400.0
	var start: Vector3 = world.position_at(18.0)
	camera.fov = 56.0
	camera.position = start + Vector3.UP * 2.55 - world.forward(18.0) * 4.4
	camera.look_at(world.position_at(28.0) + Vector3.UP * 1.15)
	await _shot("01_race_camera")
	var sites: Array = world.get_meta("sonnenhafen_generation_sites")
	for site in sites:
		if site.kind == "villa" and float(site.fraction) < 0.007:
			var at: Vector3 = site.position
			var frame: Basis = world.frame(world.length * float(site.fraction))
			camera.fov = 53.0
			camera.position = at + frame * Vector3(10.0, 5.0, 18.0)
			camera.look_at(at + Vector3.UP * 4.5)
			break
	await _shot("02_harbor_shopfront")
	var stage: Vector3 = world.get_meta("sonnenhafen_wow_landmark")
	var target := Vector3(stage.x, world._ground_height(stage.x, stage.z) + 22.0, stage.z)
	camera.fov = 50.0
	camera.position = target + Vector3(38.0, 18.0, 46.0)
	camera.look_at(target)
	await _shot("03_harbor_wheel")
	var attraction = world.get_node_or_null("SonnenhafenHarborAttraction")
	if attraction != null:
		for i in range(240):
			attraction.advance(1.0 / 60.0, world.position_at(95.0), true, false)
		await _shot("04_wheel_after_4s")
		if OS.get_environment("LUMO_CAPTURE_MOVIE") == "1":
			root.size = Vector2i(640, 360)
			DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
			for i in range(72):
				attraction.advance(1.0 / 12.0, world.position_at(95.0), true, false)
				await _frames(1)
				root.get_texture().get_image().save_png(out.path_join("frames/%03d.png" % i))
	var file := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"engine": Engine.get_version_info().string,
						"renderer": RenderingServer.get_current_rendering_method(),
						"gpu": RenderingServer.get_video_adapter_name(),
						"quality": "HIGH",
						"size": [1280, 720],
						"is_device_performance_measurement": false,
						"static_parts": world.get_meta("sonnenhafen_generation_parts"),
						"views": views,
					},
					"\t"
				)
			)
		)
	)
	file.close()
	print("[HarborLivingCapture] PASS ", out)
	quit(0)
