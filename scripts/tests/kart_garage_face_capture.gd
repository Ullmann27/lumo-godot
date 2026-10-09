extends SceneTree
## Real, unretouched Godot frames of the selected Lumo fox's 3D face.
## The 3D driver remains the same geometry as in the race.
const OUTPUT := "res://exports/face-showroom"


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 12) -> void:
	for index in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Requires a real rendering window")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	var garage = game.garage
	assert(garage.view_choice.item_count == 7, "Real face view must be selectable")
	garage.reduced_motion = true
	garage.setup.driver = "fox"
	garage.setup.kart = "comet"
	garage.step = 2
	garage._refresh()
	garage._choose_preview_view(6)
	assert(garage.preview_kart != null and garage.preview_kart.head != null)
	assert(garage.preview_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(garage.preview_camera.position.z < -2.0)
	assert(garage.inspection_view == 6)
	await _settle(16)
	for pixels in [Vector2i(1280, 720), Vector2i(800, 480), Vector2i(412, 915)]:
		root.size = pixels
		await _settle(12)
		garage._apply_responsive_layout()
		garage._choose_preview_view(6)
		await _settle(14)
		var center: Vector2 = garage.preview_camera.unproject_position(
			garage.preview_kart.head.global_position
		)
		var frame: Vector2 = Vector2(garage.preview_viewport.size)
		assert(center.x > frame.x * 0.15 and center.x < frame.x * 0.85)
		assert(center.y > frame.y * 0.10 and center.y < frame.y * 0.90)
		var img: Image = root.get_texture().get_image()
		assert(img.get_width() > 0 and img.get_height() > 0)
		var path := "%s/lumo-face-%dx%d.png" % [OUTPUT, pixels.x, pixels.y]
		assert(img.save_png(path) == OK)
		print("[LumoFaceCapture] captured actual 3D menu: ", path)
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	await _settle(3)
	await create_timer(0.20).timeout
	print("[LumoFaceCapture] PASS: three actual face views at tablet/compact/phone sizes")
	quit(0)
