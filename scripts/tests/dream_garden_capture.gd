extends SceneTree
## Actual renderer captures of the unchanged lesson camera and new sculptures.
var output := "res://exports/dream-garden"
var failures := 0
var portrait_only := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--portrait":
			portrait_only = true
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[DreamGardenCapture] requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var bridge := root.get_node("HostBridge")
	var saved: Dictionary = bridge.get("_options").duplicate(true)
	var profiles := [Vector2i(412, 915)] if portrait_only else [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(2400, 1080)]
	for dimensions in profiles:
		root.size = dimensions
		var options: Dictionary = bridge.get("_options")
		options["displayDensity"] = 2.625 if dimensions.x == 2400 else 1.0
		var game: Node3D = load("res://scenes/learning/learning_world.tscn").instantiate()
		game.set("capture_options", {"learning": {"kind": "bridge_ten", "a": 8, "b": 5}, "reduceAnimations": true})
		root.add_child(game)
		for frame in range(14):
			await process_frame
		await RenderingServer.frame_post_draw
		var props := game.get_node("LearningGardenAtelier/LumoDreamGardenSculptures")
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != dimensions:
			failures += 1
		else:
			var path := output.path_join("learning-dream-%dx%d.png" % [dimensions.x, dimensions.y])
			if image.save_png(path) != OK:
				failures += 1
			print("[DreamGardenCapture] ", path, " surfaces=", _surface_count(props), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		game.queue_free()
		await process_frame
	bridge.set("_options", saved)
	print("[DreamGardenCapture] failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _surface_count(props: Node) -> int:
	var count := 0
	for node: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
		count += node.mesh.get_surface_count()
	return count
