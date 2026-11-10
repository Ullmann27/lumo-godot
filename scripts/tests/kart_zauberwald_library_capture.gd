extends SceneTree
## Deterministic renderer proof for the reference-based roadside tree library; no fake gameplay/FPS.
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
	seed(1923)
	out = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not out.is_empty() and not DirAccess.dir_exists_absolute(out))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	root.get_node("PerformanceManager").set_profile(2, false)
	world = WORLD.new()
	root.add_child(world)
	world.build(false, "zauberwald")
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 1400.0
	var sites: Array = world.get_meta("reference_detail_sites")
	assert(not sites.is_empty() and is_equal_approx(float(sites[0].radius), 4.3))
	var site: Dictionary = sites[0]
	var distance: float = site.distance
	var at: Vector3 = site.position
	var frame: Basis = Basis(Vector3.UP, world.frame(distance).get_euler().y)
	# All poses bind to the unchanged accepted site, never to the new mesh bounds.
	camera.fov = 56.0
	camera.position = world.position_at(distance - 12.0) + Vector3.UP * 2.55
	camera.look_at(world.position_at(distance) + Vector3.UP * 1.15)
	await _shot("01_race_camera")
	var road: Vector3 = world.position_at(distance)
	var toward_road := Vector3(road.x - at.x, 0.0, road.z - at.z).normalized()
	camera.fov = 53.0
	camera.position = at + toward_road * 12.0 + Vector3.UP * 5.5
	camera.look_at(at + Vector3.UP * 3.4)
	await _shot("02_roadside_library")
	camera.fov = 53.0
	camera.position = at + frame * Vector3(-4.0, 4.5, -13.0)
	camera.look_at(at + Vector3.UP * 3.5)
	await _shot("03_library_front")
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
						"theme_parts": world.get_meta("reference_detail_count"),
						"capture_kind": "static real world; manually posed camera, no driven race",
						"nature_source_sha256":
						FileAccess.get_sha256(
							"res://scripts/games/track_themes/nature_track_details.gd"
						),
						"views": views,
					},
					"\t"
				)
			)
		)
	)
	file.close()
	print("[ZauberwaldLibraryCapture] PASS ", out)
	world.queue_free()
	await _frames(2)
	quit(0)
