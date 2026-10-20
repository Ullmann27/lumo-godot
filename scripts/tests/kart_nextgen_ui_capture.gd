extends SceneTree
## Screenshots from the ACTUAL Godot 3D hub, not generated concept art.
## Usage: xvfb-run ... godot --script res://scripts/tests/kart_nextgen_ui_capture.gd
## Load the scene after Godot registers project autoloads.

func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := "res://exports/nextgen-ui"
	DirAccess.make_dir_recursive_absolute(output)
	var hub := load("res://scenes/games/game_hub.tscn").instantiate()
	root.add_child(hub)
	for dimensions in [Vector2i(1280, 720), Vector2i(690, 829)]:
		root.size = dimensions
		await _settle()
		assert(hub.find_child("OriginalAnimatedLumo", true, false) != null)
		var viewport_image := root.get_texture().get_image()
		assert(viewport_image.get_size() == dimensions)
		var filename := "spielewelt-%dx%d.png" % [dimensions.x, dimensions.y]
		assert(viewport_image.save_png(output.path_join(filename)) == OK)
		print("[NextGenHub] CAPTURE ", output.path_join(filename))
	hub.queue_free()
	await _settle()
	print("[NextGenHub] PASS: two actual rendered game hub screenshots")
	quit(0)
