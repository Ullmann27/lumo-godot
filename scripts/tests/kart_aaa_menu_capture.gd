extends SceneTree
## Same actual runtime, fixed state/seed/pose/camera input for before and after.
var output := "res://exports/aaa-menu"
var evidence: Array[Dictionary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	call_deferred("_run")


func _settle(frames := 8) -> void:
	for index in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	seed(1923)
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	var garage = game.garage
	garage.stars = 48
	garage.setup.mode = "race"
	garage.step = 0
	garage.reduced_motion = true
	garage.set_process(false)
	for dimensions in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(1200, 896)]:
		root.size = dimensions
		garage._refresh()
		garage._apply_responsive_layout()
		garage.preview_idle_time = 0
		garage.preview_angle = -0.25
		garage.preview_pivot.rotation.y = -0.25
		garage.preview_kart.reduced_motion = true
		garage.preview_kart.set_process(false)
		await _settle(16)
		var cards: GridContainer = garage.choices.get_child(0)
		var clip: Rect2 = garage.choices.get_parent().get_global_rect()
		assert(cards.get_child_count() == 5)
		for card in cards.get_children():
			assert(clip.encloses(card.get_global_rect()), "All five modes must be visible")
		assert(root.get_visible_rect().encloses(garage.next_button.get_global_rect()))
		assert(not garage.quick_start_button.visible)
		var image := root.get_texture().get_image()
		assert(image.get_size() == dimensions)
		var file := "menu-%dx%d.png" % [dimensions.x, dimensions.y]
		assert(image.save_png(output.path_join(file)) == OK)
		evidence.append({
			"image": file, "size": [dimensions.x, dimensions.y], "seed": 1923,
			"engine": Engine.get_version_info().string,
			"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(),
			"menu_step": 0, "mode": "race", "stars": 48,
			"pose_yaw": -0.25, "idle_time": 0,
			"camera_position": str(garage.preview_camera.position),
			"camera_fov": garage.preview_camera.fov,
			"preview_rect": str(garage.preview_container.get_global_rect()),
			"next_rect": str(garage.next_button.get_global_rect()),
			"render_capture": true, "physical_android_device": false,
		})
		print("[AAAMenuCapture] SCREENSHOT ", output.path_join(file))
	var report := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(evidence, "  "))
	report.close()
	game.queue_free()
	await _settle(6)
	print("[AAAMenuCapture] PASS: three fixed-state real menu captures, five visible modes")
	quit(0)
