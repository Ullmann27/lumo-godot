extends SceneTree
## Cold Godot scene entry followed by live idle frames. Start a new process per route.
const Stats = preload("res://scripts/learning/learning_frame_probe.gd")
# Usage with isolated settings:
# XDG_DATA_HOME="$(mktemp -d)" LUMO_PROBE_SOURCE="$(git rev-parse HEAD)" godot \
#   --rendering-method gl_compatibility --script res://scripts/tests/console_scene_probe.gd \
#   -- --scene=cards
const WARMUP_FRAMES := 24
const SAMPLE_FRAMES := 60

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A rendering driver is required")
		quit(2)
		return
	var data_dir := OS.get_environment("XDG_DATA_HOME")
	if OS.get_name() != "Linux" or data_dir.is_empty() or FileAccess.file_exists("user://settings.cfg"):
		push_error("Start the Linux probe with a fresh XDG_DATA_HOME")
		quit(2)
		return
	var route := ""
	var direct := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			route = arg.trim_prefix("--scene=")
		elif arg == "--probe-direct-scene":
			direct = true
	var router := root.get_node("SceneRouter")
	if not router.SCENES.has(route):
		push_error("Unknown scene " + route)
		quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(960, 540)
	root.get_node("SettingsStore").set_graphics_choice("medium")
	# Measure from just before loading the real boot scene to the first draw
	# of the target. The real boot cover may still be fading at that draw.
	var before := _residency()
	var started := Time.get_ticks_usec()
	if direct:
		router.goto(route)
		await process_frame
	else:
		change_scene_to_file(router.SCENES.boot)
	var deadline := Time.get_ticks_msec() + 45000
	while (router.current_scene_id != route or current_scene == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	if router.current_scene_id != route or current_scene == null or current_scene.scene_file_path != router.SCENES[route]:
		printerr("SCENE_PROBE_FAILED ", route, ": ", router.current_scene_id)
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var first_draw_ms := (Time.get_ticks_usec() - started) / 1000.0
	for _i in WARMUP_FRAMES:
		await process_frame
	var monitor_ids := {
		"process_ms": Performance.TIME_PROCESS, "physics_ms": Performance.TIME_PHYSICS_PROCESS,
		"navigation_ms": Performance.TIME_NAVIGATION_PROCESS,
		"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
		"primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
		"render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
		"physics_active_3d": Performance.PHYSICS_3D_ACTIVE_OBJECTS,
	}
	var samples := {"frame_ms": PackedFloat64Array()}
	for key in monitor_ids:
		samples[key] = PackedFloat64Array()
	var viewport := root.get_viewport_rid()
	# RenderingDevice exposes delayed timestamp queries. The reported GPU
	# time still belongs to a software device when using lavapipe.
	var timed_viewport := RenderingServer.get_rendering_device() != null
	if timed_viewport:
		RenderingServer.viewport_set_measure_render_time(viewport, true)
		samples["viewport_cpu_ms"] = PackedFloat64Array()
		samples["viewport_gpu_ms"] = PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for _i in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.frame_ms.append((now - last) / 1000.0)
		last = now
		if timed_viewport:
			var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(viewport)
			var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			if cpu_ms > 0.0:
				samples.viewport_cpu_ms.append(cpu_ms)
			if gpu_ms > 0.0:
				samples.viewport_gpu_ms.append(gpu_ms)
		for key in monitor_ids:
			var value := Performance.get_monitor(monitor_ids[key])
			samples[key].append(value * 1000.0 if key.ends_with("_ms") else value)
	var result := {}
	for key in samples:
		if not samples[key].is_empty():
			result[key] = Stats.statistics(samples[key])
			result[key]["observations"] = samples[key].size()
	if timed_viewport:
		RenderingServer.viewport_set_measure_render_time(viewport, false)
	var active := _residency()
	var structure := _structure(current_scene)
	unload_current_scene()
	for _i in WARMUP_FRAMES:
		await process_frame
	var report := {
		"route": route, "scene": router.SCENES[route], "viewport": str(root.size),
		"entry": "native_router" if direct else "native_boot",
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string,
		"profile": root.get_node("PerformanceManager").get_graphics_choice(),
		"source": OS.get_environment("LUMO_PROBE_SOURCE"),
		"first_draw_ms": first_draw_ms,
		"warmup_frames": WARMUP_FRAMES, "sample_frames": SAMPLE_FRAMES,
		"before": before, "active": active, "after_unload": _residency(),
		"structure": structure, "samples": result,
	}
	print("LUMO_SCENE_METRICS ", JSON.stringify(report))
	quit(0)

func _residency() -> Dictionary:
	var output: Array = []
	var status := OS.execute("/bin/ps", ["-o", "rss=", "-p", str(OS.get_process_id())], output)
	var rss_kib := str(output[0]).strip_edges().to_int() if status == 0 and not output.is_empty() else -1
	return {
		"resident_kib_linux": rss_kib,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
	}

func _structure(scene: Node) -> Dictionary:
	var materials := {}
	var shaders := {}
	var counts := {"mesh_instances": 0, "multimesh_nodes": 0, "lights": 0, "shadow_lights": 0,
		"particle_emitters": 0, "particle_capacity": 0, "animation_players": 0,
		"playing_animation_players": 0, "skeletons": 0, "navigation_agents": 0}
	var remaining: Array[Node] = [scene]
	while not remaining.is_empty():
		var node: Node = remaining.pop_back()
		remaining.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh != null:
			counts.mesh_instances += 1
			for index in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(index)
				if material != null:
					materials[material.get_instance_id()] = true
					if material is ShaderMaterial and material.shader != null:
						shaders[material.shader.get_instance_id()] = true
		elif node is MultiMeshInstance3D:
			counts.multimesh_nodes += 1
		elif node is Light3D and node.is_visible_in_tree():
			counts.lights += 1
			counts.shadow_lights += int(node.shadow_enabled)
		elif (node is GPUParticles3D or node is CPUParticles3D) and node.emitting:
			counts.particle_emitters += 1
			counts.particle_capacity += node.amount
		elif node is AnimationPlayer:
			counts.animation_players += 1
			counts.playing_animation_players += int(node.is_playing())
		elif node is Skeleton3D:
			counts.skeletons += 1
		elif node is NavigationAgent3D:
			counts.navigation_agents += 1
	counts["mesh_material_instances"] = materials.size()
	counts["custom_mesh_shaders"] = shaders.size()
	return counts
