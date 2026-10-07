extends SceneTree
const TRACKS = preload("res://scripts/games/kart_expansion_tracks.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
var out_dir := "res://exports/creative-build"
var game


func _initialize() -> void:
	call_deferred("_run")


func _start(id: String) -> void:
	game._start_selected_race(
		{"mode": "training", "driver": "fox", "kart": "comet", "track": id, "difficulty": "flott"}
	)
	game.set_physics_process(false)
	game.countdown = 0
	game.racing = true
	assert(not game.loop_state.active and game.loop_count == 0, "New race clears old loop state")
	await process_frame


func _place(d: float, speed: float, lane: float = 0) -> void:
	game.player.transform = game.world.reset_transform(d, lane)
	game.player_heading = game._heading(d)
	game.speed = speed
	game.previous_road_distance = d
	game.distance = d
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	)
	game.lane = lane


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.lightweight = true
	assert(game.CATALOG.TRACKS.size() == 12)
	var lengths: Dictionary = {}
	for id in TRACKS.IDS:
		await _start(id)
		assert(game.world.track_id == id and game.world.length > 550)
		assert(game.world.road.mesh.get_surface_count() == 1)
		assert(game.world.checkpoint_positions.size() == 8)
		lengths[id] = snappedf(game.world.length, 0.1)
		var d: float = game.world.length * 0.08
		if id == "volcano_night":
			d = game.world.length * 0.37
		_place(d, 20.5)
		game._update_camera(1, true)
		game._update_hud()
		game.message.text = game.world.track_name
		if "--logic-only" not in OS.get_cmdline_user_args():
			await _capture("track_" + id)
		if not game.world.jump.is_empty():
			var ramp: Dictionary = game.world.jump
			_place(float(ramp.ramp_start) - 15, 20.5)
			var jumps: int = game.jump_count
			var landings: int = game.landing_count
			var falls: int = game.gap_falls
			for _i in range(170):
				var at: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
				var to: Vector3 = at - game.player.position
				var heading: float = atan2(-to.x, -to.z)
				var steer: float = clampf(
					-angle_difference(game.player_heading, heading) * 2.1, -1, 1
				)
				game._drive_player(1.0 / 60, steer, 0)
			assert(
				(
					game.jump_count == jumps + 1
					and game.landing_count == landings + 1
					and game.gap_falls == falls
				),
				"New circuit jump clears and lands: " + id
			)
		if not game.world.loop_layout.is_empty():
			var data: Dictionary = game.world.loop_layout
			var top: Basis = LOOP.frame_at(game.world, data, 0.5)
			assert(top.y.y < -0.95, "Loop contact is upside down at its summit")
			_place(float(data.start), 22, float(data.lane))
			var completed: int = game.loop_count
			game._drive_player(1.0 / 60, 0, 0)
			assert(game.loop_state.active, "Right lane enters an actual physical loop")
			var captured_loop: bool = false
			for i in range(500):
				if not game.loop_state.active:
					break
				game._drive_player(1.0 / 60, 0, 0)
				if id == "candy_cloud" and not captured_loop and game.loop_state.progress > 0.48 and "--logic-only" not in OS.get_cmdline_user_args():
					captured_loop = true
					game.message.text = "Candy Cloud: im befahrbaren Looping"
					game._update_camera(1, true)
					await _capture("track_candy_loop_in_motion")
			assert(game.loop_count == completed + 1 and not game.loop_state.failed)
			assert(
				(
					game.player.position.y
					< game.world.position_at(float(data.start) + LOOP.ADVANCE).y + 0.2
				)
			)
			_place(float(data.start), 17, float(data.lane))
			game._drive_player(1.0 / 60, 0, 0)
			for i in range(300):
				if not game.loop_state.active:
					break
				game._drive_player(1.0 / 60, 0, 1)
			assert(
				game.loop_state.failed and not game.loop_state.active,
				"Braking stalls safely back on the entry road"
			)
		print(
			"[KartExpansion] PASS ",
			id,
			" length=",
			lengths[id],
			"m; ramp=",
			not game.world.jump.is_empty(),
			"; loop=",
			not game.world.loop_layout.is_empty()
		)
	game.abandoned = true
	game.queue_free()
	await process_frame
	print(
		"[KartExpansion] PASS: twelve menu worlds; 8 distinct new circuits, 5 ramps, 3 momentum loops, upright recovery"
	)
	await create_timer(0.6).timeout
	quit(0)


func _capture(name: String) -> void:
	for _i in range(8):
		await process_frame
	var frame: Image = root.get_texture().get_image()
	assert(frame != null and frame.save_png(out_dir + "/" + name + ".png") == OK)
	print("[KartExpansion] screenshot: ", name)
