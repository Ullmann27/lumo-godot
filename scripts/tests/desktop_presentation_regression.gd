extends SceneTree
## Exercise an actual renderer and scene switch. Use --expect= to specify
## which mode this invocation should accept for the current OS and renderer.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var expected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--expect="):
			expected = argument.trim_prefix("--expect=")
	var manager := root.get_node("PerformanceManager")
	assert(manager.desktop_presentation == expected)
	var store := root.get_node("SettingsStore")
	var saved_choice: String = store.get_graphics_choice()
	var scene := Node3D.new()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	scene.add_child(world)
	assert(change_scene_to_node(scene) == OK)
	await scene_changed
	await process_frame
	if not expected.is_empty():
		assert(manager.get_graphics_choice() == "ultra")
		assert(world.environment.ssr_enabled and world.environment.ssao_enabled)
		assert(world.environment.ssil_enabled == (expected == "cinematic"))
		assert(root.use_taa)
		manager.set_graphics_choice("low", false)
		assert(not world.environment.ssr_enabled and not world.environment.ssil_enabled)
	else:
		assert(not world.environment.ssr_enabled and not world.environment.ssil_enabled)
	assert(store.get_graphics_choice() == saved_choice)
	print("[DesktopPresentation] PASS ", RenderingServer.get_current_rendering_method(), " mode=", expected)
	quit(0)
