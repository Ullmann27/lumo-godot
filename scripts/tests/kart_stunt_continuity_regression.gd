extends "res://scripts/tests/kart_sonnenhafen_stunt_regression.gd"
## Drive into the loop using only throttle/steering after one scenario setup.
## Assert every movement step, then prove two real AI drivers ride the ring.
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")


func _capture(label: String) -> void:
	var output: String = OS.get_environment("LUMO_GEOMETRY_CAPTURE_DIR")
	if output.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	assert(error == OK, "Actual renderer capture saved")


func _continuous_player_loop() -> void:
	await _start()
	var layout: Dictionary = game.world.loop_layout
	_place(float(layout.start) - 45.0, STUNT.LOOP_LANE + 0.65, 15.0)
	var previous: Vector3 = game.player.position
	var entered: bool = false
	var captured_top: bool = false
	var exit_offset: float = 0.0
	var maximum_step: float = 0.0
	var record: bool = OS.get_environment("LUMO_GEOMETRY_RECORD") == "1"
	game._update_camera(1.0)
	await _capture("loop-approach")
	for frame in range(900):
		if not game.loop_state.active:
			_steer_to(STUNT.LOOP_LANE + 0.65)
		else:
			game.steering = 0.0
		var before_speed: float = game.speed
		game._physics_process(STEP)
		var travel: float = previous.distance_to(game.player.position)
		maximum_step = maxf(maximum_step, travel)
		assert(
			travel <= maxf(before_speed, game.speed) * STEP + 0.15,
			"No entry, ride or exit teleport: %.3f m at %.2f m/s" % [travel, game.speed]
		)
		previous = game.player.position
		if record and frame % 4 == 0:
			await _capture("drive-%04d" % (frame / 4))
		if game.loop_state.active:
			entered = true
			exit_offset = game.loop_state.lateral
			if game.loop_state.progress > 0.49 and not captured_top:
				captured_top = true
				await _capture("loop-inverted")
		elif entered:
			break
	assert(
		entered and game.loop_count == 1 and game.reset_count == 0,
		"Complete player loop without rescue"
	)
	assert(
		absf(game.lane - STUNT.LOOP_LANE - exit_offset) < 0.01, "Exit preserves steering position"
	)
	await _capture("loop-exit")
	completed_checks += 1
	print(
		(
			"[StuntContinuity] player: full loop without position snaps; largest step %.3f m"
			% maximum_step
		)
	)


func _continuous_rival_loops() -> void:
	for level in ["flott", "pro"]:
		game._start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": "sonnenhafen",
				"difficulty": level
			}
		)
		game._end_preview()
		await _settle()
		game.countdown = 0
		game.racing = true
		assert(game.opponents.size() == 5, "Scenario contains five real rivals")
		var start: float = float(game.world.loop_layout.start) - 52.0
		var highest: Dictionary = {1: 0.0, 3: 0.0}
		var inverted: Dictionary = {1: false, 3: false}
		for index in range(game.opponents.size()):
			var at: float = start - float(index) * 2.0
			game.opponent_distances[index] = at
			game.opponent_headings[index] = game._heading(at)
			game.opponent_lanes[index] = 0.0
			game.opponents[index].transform = game.world.reset_transform(at)
			game.opponents[index].set_motion(20.0, 0.0, false, false)
		var completed: int = 0
		var saved_at_apex: bool = false
		for frame in range(1800):
			game._drive_opponents(STEP)
			completed = 0
			for index in [1, 3]:
				var rival = game.opponents[index]
				highest[index] = maxf(
					highest[index],
					rival.position.y - game.world.position_at(float(game.world.loop_layout.start)).y
				)
				inverted[index] = inverted[index] or rival.basis.y.dot(Vector3.UP) < -0.98
				if inverted[index] and not saved_at_apex:
					var at_save: Vector3 = rival.position
					game._save_session()
					var snapshot := ConfigFile.new()
					assert(snapshot.load(game.SESSION) == OK, "Real race snapshot saved")
					var saved_positions: Array = snapshot.get_value("race", "opponent_positions")
					var saved_distances: Array = snapshot.get_value("race", "opponent_distances")
					var saved_lanes: Array = snapshot.get_value("race", "opponent_lanes")
					var entry: float = float(game.world.loop_layout.start)
					assert(
						(
							saved_positions[index].distance_to(
								game.world.reset_transform(entry, saved_lanes[index]).origin
							)
							< 0.01
						),
						"Interrupted AI loop saves on entry road"
					)
					assert(
						saved_distances[index] <= game.opponent_distances[index],
						"Snapshot awards no shortcut"
					)
					assert(rival.position == at_save, "Saving never teleports the live rival")
					saved_at_apex = true
				completed += int(rival.get_meta(&"lumo_completed_loops", 0))
			if completed >= 2:
				break
		assert(completed == 2, "%s: both adventurous rivals drive a complete loop" % level)
		assert(saved_at_apex, "A real upside-down rival was saved safely")
		for index in [1, 3]:
			assert(
				highest[index] > 15.0 and inverted[index], "AI physically reaches apex upside down"
			)
		print(
			(
				"[StuntContinuity] %s: 2 AI loop completions, apex heights %.2f / %.2f m"
				% [level, highest[1], highest[3]]
			)
		)
	completed_checks += 1


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _continuous_player_loop()
	await _continuous_rival_loops()
	if completed_checks != 2:
		quit(1)
		return
	if not await TEARDOWN.release_scene(self, game, "[StuntContinuity]"):
		push_error("[StuntContinuity] FAIL: scene teardown did not complete")
		quit(1)
		return
	game = null
	print("[StuntContinuity] PASS: continuous player contact and real AI loop traversal")
	quit(0)
