extends SceneTree
## A real world-rendered six-second architectural/pennant clip. A scripted
## racer-position stimulus proves the visual response, not a driven full lap.
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Streetfront clip requires a real rendering display")
		quit(2)
		return
	var folder := OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not folder.is_empty())
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	seed(2014)
	root.size = Vector2i(960, 540)
	await _frames(2)
	root.get_node("PerformanceManager").set_profile(2, false)
	var world = WORLD.new()
	root.add_child(world)
	world.build(false, "sonnenhafen")
	for child in world.get_children():
		if child is GPUParticles3D:
			child.emitting = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 53.0
	camera.far = 1400.0
	var distance_m := 0.0
	for site in world.get_meta("sonnenhafen_generation_sites"):
		if str(site.kind) == "villa" and float(site.fraction) > 0.02 and float(site.fraction) < 0.03:
			distance_m = world.length * float(site.fraction)
			var at: Vector3 = site.position
			var basis: Basis = world.frame(distance_m)
			camera.position = at + basis * Vector3(6.0, 9.0, 17.0)
			camera.look_at(at + Vector3.UP * 7.6)
			break
	assert(distance_m > 0.0)
	var kit = world.get_node("SonnenhafenStreetfronts")
	var events: Array[Dictionary] = []
	for frame in range(72):
		var nearby: bool = frame >= 12 and frame < 48
		var racer: Vector3 = world.position_at(distance_m if nearby else distance_m - 90.0)
		kit.advance(1.0 / 12.0, racer, true, false)
		await _frames(1)
		var raster: Image = root.get_texture().get_image()
		assert(raster.get_size() == Vector2i(960, 540))
		assert(raster.save_png(folder.path_join("frames/%03d.png" % frame)) == OK)
		if frame in [0, 12, 24, 48, 71]:
			events.append({"frame": frame, "nearby": nearby, "phase": kit.phase, "triggers": kit.trigger_count})
	var record := {
		"source_sha": OS.get_environment("LUMO_SOURCE_SHA"),
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"quality": "HIGH", "resolution": [960, 540], "frames": 72, "timeline_fps": 12,
		"camera": str(camera.transform), "fov": camera.fov, "metrics": kit.metrics, "events": events,
		"is_device_performance_measurement": false,
		"proof_scope": "Actual world and fabric render; deterministic position stimulus, not a driven lap",
	}
	var file := FileAccess.open(folder.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	print("[StreetfrontClip] PASS 72 actual rendered frames ", folder)
	world.queue_free()
	await process_frame
	quit(0)
