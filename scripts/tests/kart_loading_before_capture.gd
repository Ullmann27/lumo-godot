extends SceneTree
## Renders the verbatim pre-change cover/layout methods with the same real assets.
## The old one-frame route can leave before a post-draw screenshot is available.
## This explicitly held visual baseline is not a recording of the old startup.
## Supply a git-extracted original GDScript path; never modifies product files.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 2, "Output directory and original controller path are required")
	var output: String = args[0]
	var controller: String = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var boot = load("res://scenes/app/boot.tscn").instantiate()
	# Let the original scene hierarchy enter the tree without either boot route.
	# Attach the historical controller afterwards, invoking only its two original
	# visual methods. This avoids altering or pretending to time the old route.
	boot.set_script(null)
	root.add_child(boot)
	current_scene = boot
	boot.set_script(load(controller))
	boot.call("_show_cover", "kart")
	boot.call("_layout")
	await RenderingServer.frame_post_draw
	assert(is_instance_valid(boot) and current_scene == boot,
		"Capture the held historical visual fixture in the real Godot renderer")
	assert(root.get_texture().get_image().save_png(output.path_join("loading-before-1280x720.png")) == OK)
	FileAccess.open(output.path_join("before-provenance.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"real_godot_frame": true, "original_controller_sha256": FileAccess.get_sha256(controller),
		"same_existing_artwork": true, "physical_android_device": false,
		"controller_replayed_from_git": true, "original_visual_methods": ["_show_cover", "_layout"],
		"historical_ready_route_executed": false, "visual_fixture_held": true,
		"normal_startup_recording": false}, "\t"))
	current_scene = null
	boot.queue_free()
	for frame in range(5):
		await process_frame
	print("[KartLoadingBefore] PASS: real Godot visual fixture of the historical cover, not startup timing")
	quit(0)
