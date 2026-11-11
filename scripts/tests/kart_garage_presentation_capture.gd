extends SceneTree
## Identical camera/pose/settings for original and changed source trees.
## Copy this helper unchanged into a 2014 tree to capture its baseline.
const METADATA = preload("res://tools/aaa_capture_metadata.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
var output := "res://exports/garage-presentation"
var capture_clip := false


func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		output = OS.get_cmdline_user_args()[0]
	capture_clip = "--clip" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _settle(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	seed(2014)
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array[Dictionary] = []
	var garage = load("res://scripts/games/kart_garage_menu.gd").new()
	garage.stars = 60
	garage.reduced_motion = true
	garage.graphics_profile = "high"
	garage.workshop = TUNING.new("technical_art_capture", 60)
	garage.workshop.save_enabled = false
	garage.workshop.upgrade("comet", "motor")
	garage.workshop.upgrade("comet", "motor")
	garage.workshop.upgrade("comet", "turbo")
	root.add_child(garage)
	garage.step = 2
	garage._refresh()
	for dimensions in [Vector2i(1280, 720), Vector2i(412, 915), Vector2i(690, 829)]:
		root.size = dimensions
		garage._apply_responsive_layout()
		await _settle(3)
		var perf = root.get_node("PerformanceManager")
		perf.set_profile(perf.Profile.HIGH)
		garage._choose_preview_view(0)
		garage.set_process(false)
		garage.preview_idle_time = 0.0
		garage.preview_angle = -0.25
		garage.preview_pivot.rotation.y = -0.25
		garage.preview_kart.set_process(false)
		garage.preview_kart.reduced_motion = true
		var adapter = garage.preview_kart.lumo_animation
		adapter.set_reduced_motion(true)
		adapter.clear_celebration()
		adapter.advance_visual(0.0)
		adapter.set_process(false)
		await _settle(2)
		assert(garage.preview_container.get_global_rect().grow(1.0).encloses(garage.view_choice.get_global_rect()),
			"The real inspection dropdown must remain inside the preview at every captured size")
		var name := "garage-%dx%d" % [dimensions.x, dimensions.y]
		assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
		assert(garage.preview_viewport.get_texture().get_image().save_png(output.path_join(name + "-preview.png")) == OK)
		var record: Dictionary = METADATA.source()
		record.merge({"image": name + ".png", "resolution": [dimensions.x, dimensions.y],
			"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(), "quality": "high", "seed": 2014,
			"camera_transform": str(garage.preview_camera.transform), "fov": garage.preview_camera.fov,
			"preview_resolution": str(garage.preview_viewport.size), "yaw": -0.25,
			"animation": "kart_seated", "animation_position": 0.3,
			"draw_calls": garage.preview_draw_calls(), "physical_android_device": false})
		records.append(record)
		print("[GaragePresentationCapture] ", name, " draw_calls=", garage.preview_draw_calls())
	var report := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(records, "  "))
	report.close()
	if capture_clip:
		root.size = Vector2i(1280, 720)
		garage._apply_responsive_layout()
		await _settle(3)
		garage.reduced_motion = false
		garage._choose_preview_view(0, false)
		var clip_dir := output.path_join("selection-camera-frames")
		DirAccess.make_dir_recursive_absolute(clip_dir)
		for frame in range(36):
			if frame == 4:
				garage._select("kart", "gecko_velo")
				await _settle(2)
			if frame == 12:
				garage._choose_preview_view(1)
			if frame == 20:
				garage._choose_preview_view(2)
			if frame == 28:
				garage._choose_preview_view(0)
			garage.preview_kart.set_process(false)
			var adapter = garage.preview_kart.lumo_animation
			adapter.set_process(false)
			adapter.set_reduced_motion(false)
			adapter.advance_visual(1.0 / 15.0)
			garage._advance_preview_camera(1.0 / 15.0)
			await _settle(1)
			assert(root.get_texture().get_image().save_png(clip_dir.path_join("%03d.png" % frame)) == OK)
		print("[GaragePresentationCapture] CLIP 36 actual frames at fixed 15 Hz")
	garage.queue_free()
	await _settle(3)
	print("[GaragePresentationCapture] PASS: three exact-state rendered comparisons")
	quit(0)
