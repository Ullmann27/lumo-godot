extends SceneTree
## Genuine engine frames. Unmodified physics, real gas/steering input; no teleport.
var game
var output: String

func _initialize() -> void:
	call_deferred("_run")

func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for i in range(8):
		await process_frame
	await _save("kart-menu")
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "gemuetlich"})
	game._end_preview()
	game.set_physics_process(false)
	game.auto_gas = false
	game.countdown = 0
	game.racing = true
	game.modal.hide()
	game._update_hud()
	for i in range(4):
		await process_frame
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = game.gas_button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	assert(game.gas_held)
	var trace: Array = []
	for step in range(600):
		var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
		var target: float = game._heading(float(road.distance) + 8.0)
		game.steering = clampf(-angle_difference(game.player_heading, target) * 1.8 - float(road.lateral) * 0.12, -1, 1)
		game._physics_process(1.0 / 60.0)
		if step % 3 == 0:
			await process_frame
		if step in [59, 149, 299, 599]:
			await _save("kart-race-%03d" % step)
			trace.append({"step": step, "speed": game.speed, "distance": game.distance,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"rendered_primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	assert(game.distance > 30 and game.speed > 0)
	var proof := {"engine": Engine.get_version_info().string, "renderer": "desktop GL compatibility / software Mesa",
		"android_performance": false, "physics_step": "1/60", "teleported": false, "trace": trace}
	var file := FileAccess.open(output.path_join("runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(proof, "  "))
	file.close()
	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[HarborVisual] PASS: ", output)
	quit(0)
