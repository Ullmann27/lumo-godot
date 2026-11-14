extends SceneTree
## Screenshots from the real Godot scene, not prerendered design mockups.
var output_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	output_dir = OS.get_environment("LUMO_HUB_CAPTURE_DIR")
	if output_dir.is_empty() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("[LumoHubCapture] Missing writable evidence directory")
		quit(1)
		return
	root.get_node("SceneRouter").launch_options = {
		"grade": 2, "subject": "Mathematik",
		"childKey": "capture-no-production-save", "reduceAnimations": false
	}
	root.size = Vector2i(1080, 1920)
	var hub := load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(hub)
	for spec in [
		{"size": Vector2i(1080, 1920), "name": "hub_portrait.png"},
		{"size": Vector2i(2400, 1080), "name": "hub_fold_landscape.png"},
	]:
		root.size = spec.size
		for frame in range(32):
			await process_frame
		var actual: Image = root.get_texture().get_image()
		if actual == null or actual.is_empty():
			printerr("[LumoHubCapture] GPU failed to return a rendered frame")
			quit(1)
			return
		if actual.get_size() != spec.size:
			printerr("[LumoHubCapture] Wrong rendered dimensions: ", actual.get_size())
			quit(1)
			return
		var path := output_dir.path_join(spec.name)
		if actual.save_png(path) != OK:
			printerr("[LumoHubCapture] Cannot write original screenshot ", path)
			quit(1)
			return
		print("[LumoHubCapture] screenshot ", spec.name, " ", spec.size)
	hub.queue_free()
	print("[LumoHubCapture] PASS 2 original current-source rendered PNGs")
	quit(0)
