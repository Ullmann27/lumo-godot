extends SceneTree
## Bauwelt look capture (run under xvfb, gl_compatibility like CI).
## Per tier: overview from the default camera and a close-up of the castle,
## then a hover/placement frame. Works on builds before and after the
## Welten-Optik cycle. Output: BAUWELT_CAPTURE_DIR (PNG + metrics.json).
## llvmpipe numbers are not device performance; draw calls/objects compare.


func _initialize() -> void:
	call_deferred("_run")


func _stats() -> Dictionary:
	return {
		"draw_calls":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
		"primitives":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		),
		"objects":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}


func _save(dir: String, name: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	await process_frame
	await RenderingServer.frame_post_draw
	var stats: Dictionary = _stats()
	print("[BauweltCapture] %s %s" % [name, JSON.stringify(stats)])
	return stats


func _run() -> void:
	var dir: String = OS.get_environment("BAUWELT_CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://bauwelt_capture")
	DirAccess.make_dir_recursive_absolute(dir)
	var performance: Node = root.get_node("PerformanceManager")
	var metrics: Dictionary = {}
	await process_frame
	for tier in [0, 1, 2]:
		var tier_name: String = ["low", "medium", "high"][tier]
		performance.call("set_profile", tier, false)
		DirAccess.remove_absolute("user://lumo_build_optikcapture_1.json")
		root.get_node("SceneRouter").launch_options = {"childKey": "optikcapture"}
		var started: int = Time.get_ticks_usec()
		var build: Node = load("res://scenes/creative/build_world.tscn").instantiate()
		root.add_child(build)
		var build_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		current_scene = build
		performance.call("set_profile", tier, false)
		for frame in range(30):
			await process_frame
		var entry: Dictionary = {"build_ms": build_ms}
		entry["overview"] = await _save(dir, "bauwelt_%s_overview" % tier_name)
		build.orbit = 0.35
		build.tilt = 0.42
		build.radius = 17.0
		build.focus = Vector3(-6, 1.5, -2)
		build._camera_update()
		for frame in range(6):
			await process_frame
		entry["closeup"] = await _save(dir, "bauwelt_%s_closeup" % tier_name)
		# Hover + real placement through the public tap path (particles, pop).
		var cam: Camera3D = build.camera
		var spot: Vector2 = cam.unproject_position(Vector3(-11.5, 0.2, 5.5))
		build.chosen = "stone"
		build._preview_at(spot)
		build._tap(spot)
		build._preview_at(cam.unproject_position(Vector3(-9.5, 0.2, 5.5)))
		for frame in range(8):
			await process_frame
		entry["place"] = await _save(dir, "bauwelt_%s_place" % tier_name)
		# Extra 2013 landmark frames (in addition to the required three views).
		build.orbit = 0.85
		build.tilt = 0.38
		build.radius = 11.0
		build.focus = Vector3(8.2, 1.4, 6.0)
		build._camera_update()
		for frame in range(6):
			await process_frame
		entry["workshop"] = await _save(dir, "bauwelt_%s_workshop" % tier_name)
		build.orbit = 0.55
		build.tilt = 0.40
		build.radius = 12.0
		build.focus = Vector3(10.0, 2.0, -0.5)
		build._camera_update()
		for frame in range(6):
			await process_frame
		entry["observatory"] = await _save(dir, "bauwelt_%s_observatory" % tier_name)
		build.orbit = 0.15
		build.tilt = 0.28
		build.radius = 14.0
		build.focus = Vector3(2.0, -1.0, 14.0)
		build._camera_update()
		for frame in range(6):
			await process_frame
		entry["canyon"] = await _save(dir, "bauwelt_%s_canyon" % tier_name)
		entry["pieces"] = build.model.pieces.size()
		build.queue_free()
		await process_frame
		DirAccess.remove_absolute("user://lumo_build_optikcapture_1.json")
		metrics[tier_name] = entry
	var file := FileAccess.open(dir.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("[BauweltCapture] PASS %s" % dir)
	quit(0)
