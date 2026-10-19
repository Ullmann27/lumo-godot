extends SceneTree
## Actual production race and HUD, rendered with the Compatibility renderer.
## Fixed countdown states for review; this is not a frame-rate benchmark.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.intro_mode = "off"
	root.add_child(game)
	for i in range(6):
		await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"})
	game.preview_left = 0.0
	game.set_process(false)
	game._update_camera(0.1)
	DirAccess.make_dir_recursive_absolute("res://exports/start-lights")
	for count in [2.8, 0.0]:
		game.countdown = count
		game.start_green_left = 1.0 if count == 0.0 else 0.0
		game._update_start_lights(0.0)
		for i in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var name: String = "go" if count == 0.0 else "countdown"
		assert(root.get_texture().get_image().save_png("res://exports/start-lights/" + name + ".png") == OK)
	game.queue_free()
	await process_frame
	print("[StartLightsCapture] PASS: two actual Sonnenhafen race screenshots")
	quit()
