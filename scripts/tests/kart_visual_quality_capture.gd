extends SceneTree
## Render the actual menu, selected world and driving camera without mock images.
const OUTPUT := "res://exports/video-quality"
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	for _i in range(4):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await _settle()
	if DisplayServer.get_name() == "headless":
		return
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)
	print("[KartVisualQuality] captured: ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _settle()
	game.set_physics_process(false)
	game.lightweight = false
	game.garage.reduced_motion = true
	game.garage.preview_angle = 0.5
	for step in [0, 1, 2, 3, 4]:
		game.garage.step = step
		if step == 3:
			game.garage.setup.track = "candy_cloud"
		game.garage._refresh()
		await _capture("menu-%d" % step)
		assert(root.get_visible_rect().encloses(game.garage.next_button.get_global_rect()))
		if step == 3:
			assert(game.garage.preview_world.track_id == "candy_cloud")
			assert(game.garage.preview_world.get_meta("palace_count") == 5)
	game.garage.step = 0
	game.garage._refresh()
	for pixels in [Vector2i(800, 480), Vector2i(640, 320), Vector2i(320, 720), Vector2i(1080, 900)]:
		root.size = pixels
		await _settle()
		await _capture("menu-%dx%d" % [pixels.x, pixels.y])
		assert(
			root.get_visible_rect().encloses(game.garage.next_button.get_global_rect()),
			"Visible footer"
		)
		assert(
			root.get_visible_rect().encloses(game.garage.preview_container.get_global_rect()),
			"Visible 3D preview"
		)
	root.size = Vector2i(1280, 720)
	await _settle()
	for track in ["candy_cloud", "volcano_night", "sonnenhafen", "desert_drift"]:
		game._start_selected_race(
			{
				"mode": "training",
				"driver": "fox",
				"kart": "comet",
				"track": track,
				"difficulty": "flott"
			}
		)
		game.set_physics_process(false)
		game.countdown = 0
		game.racing = true
		game.auto_gas = false
		await _settle()
		if track == "candy_cloud":
			assert(game.world.get_meta("palace_count") == 5)
		if track == "volcano_night":
			assert(game.world.get_meta("volcano_gate_count") == 4)
		for fraction in [0.025, 0.12, 0.255, 0.37, 0.56]:
			var d: float = game.world.length * fraction
			game.player.transform = game.world.reset_transform(d)
			game.player_heading = game._heading(d)
			game.speed = 20.5
			game.previous_road_distance = d
			game.distance = d
			game.lane = 0
			game.physical_velocity = (
				Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
			)
			game._update_camera(1, true)
			game._update_hud()
			await _capture("%s-%03d" % [track, roundi(fraction * 1000)])
	game.abandoned = true
	# Do not activate the project fallback sky while draining the freed game.
	# Its reflection targets otherwise allocate just before renderer shutdown.
	root.world_3d.fallback_environment = null
	game.queue_free()
	await _settle()
	await create_timer(0.8).timeout
	print("[KartVisualQuality] PASS: menu, four sizes, real previews and four worlds")
	quit(0)
