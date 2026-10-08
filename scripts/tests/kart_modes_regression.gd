extends SceneTree
## Complete mode transitions, ordered gates, durable ghosts and earned unlocks.
var scene: PackedScene
var game

func _initialize() -> void:
	call_deferred("_run")

func _start(mode: String, track: String = "sonnenhafen") -> void:
	game._start_selected_race({"mode": mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": "gemuetlich"})
	game._end_preview()
	game.countdown = 0
	game.racing = true
	await process_frame

func _run() -> void:
	scene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await _start("training")
	assert(game.opponents.is_empty())
	game.elapsed = 48
	game._pause()
	game._finish()
	assert(game.finished and game.result_payload.mode == "training")
	await _start("race")
	game.checkpoint_index = 0
	game.distance = game.track_length * 0.5
	game._update_checkpoints()
	assert(game.checkpoint_index == 0, "Skipping four ordered gates must not create progress")
	await _start("cup")
	var cup_track_count: int = game.CATALOG.TRACKS.size()
	assert(cup_track_count >= 4)
	for round_index in range(cup_track_count):
		assert(game.track_id == game.CATALOG.TRACKS[round_index].id)
		game.distance = game.track_length * 2
		game.checkpoint_index = 16
		game.elapsed = 80 + round_index
		game._finish()
		assert(game.finished and not game.racing, "A cup race ends directly with its result, no task")
		var position: Vector3 = game.player.position
		game._physics_process(1)
		assert(game.player.position == position)
		assert(game.cup_results.size() == round_index + 1)
		assert(game.cup_points[0] == (round_index + 1) * 12)
		assert(game.result_payload.stars == 3 and game.result_payload.solved == 0)
		if round_index < cup_track_count - 1:
			assert(game.pending_cup_next)
			game._next_cup_race()
			game._end_preview()
			assert(game.boosts == 1, "Every cup race starts with the same single boost")
			await process_frame
	assert(not game.pending_cup_next and game.cup_index == cup_track_count - 1)
	# Saved setups from older builds may still name the removed learning cup.
	await _start("learn_cup")
	assert(game.mode == "cup" and game.track_id == game.CATALOG.TRACKS[0].id)
	await _start("arena")
	assert(game.gems.size() == 30 and game.opponents.size() == 5)
	game.player.position = game.gems[0].position
	game._update_arena(0.01)
	assert(game.arena_scores == 1 and game.arena_pickup_timers[0] > 0)
	game.item = "shield"
	game._use_item()
	assert(game.shield_time == 6 and game.item.is_empty())
	game.item = "pulse"
	game.opponents[0].position = game.player.position + Vector3.RIGHT * 3
	game._use_item()
	assert(game.opponent_stuns[0] > 0)
	# Run the entire arena clock through the real simulation, with a steering-only driver.
	var arena_frames: int = 0
	while not game.finished and arena_frames < 4600:
		var closest: float = INF
		var target: Vector3 = Vector3.ZERO
		for i in range(game.gems.size()):
			var d: float = game.player.position.distance_squared_to(game.gems[i].position)
			if game.arena_pickup_timers[i] <= 0 and d < closest:
				closest = d
				target = game.gems[i].position
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.2, -1, 1)
		game._physics_process(0.02)
		arena_frames += 1
		if arena_frames % 60 == 0:
			await process_frame
	assert(game.elapsed >= 90 and game.arena_scores > 1)
	var rival_total: int = 0
	for score in game.opponent_scores:
		rival_total += score
	assert(rival_total > 5, "Arena AI must actively collect during the complete 90-second match")
	assert(game.finished and game.result_payload.mode == "arena")
	await _start("time_trial")
	assert(game.opponents.is_empty())
	var records = load("res://scripts/games/kart_records.gd").new()
	records.begin("test_track", "comet", "pro")
	records.previous_best = 0
	records.capture(.1, .1, Vector3(0, 0, 0), Vector3.ZERO, 0, 12)
	records.capture(.1, .2, Vector3(0, 0, -2), Vector3(0, .1, 0), .2, 15)
	assert(records.finish(.2, true))
	var reloaded = load("res://scripts/games/kart_records.gd").new()
	reloaded.begin("test_track", "comet", "pro")
	var sample: Dictionary = reloaded.sample(.15)
	assert(sample.position.is_equal_approx(Vector3(0, 0, -1)), "Ghost interpolates recorded physical positions")
	reloaded.begin("test_track", "comet", "gemuetlich")
	assert(reloaded.replay.is_empty(), "Difficulty separates best-time ghosts")
	reloaded.begin("test_track", "glider", "pro")
	assert(reloaded.replay.is_empty(), "Kart performance separates best-time ghosts")
	reloaded.update_unlocks(20, game.CATALOG.DRIVERS, game.CATALOG.KARTS)
	assert(reloaded.earned_unlocks.has("turbo") and reloaded.earned_unlocks.has("otter"))
	reloaded.update_unlocks(0, game.CATALOG.DRIVERS, game.CATALOG.KARTS)
	assert(reloaded.earned_unlocks.has("turbo"), "Earned unlocks survive a lower host-wallet snapshot")
	game.abandoned = true
	game.queue_free()
	await process_frame
	print(
		(
			"[KartModesTests] PASS: %d-race star cup without tasks, legacy learn_cup -> cup, "
			+ "arena completion, training completion, ordered gates, persistent interpolated ghost, "
			+ "durable earned unlocks"
		)
		% cup_track_count
	)
	# AudioServer releases stopped stream playbacks on its asynchronous mix thread.
	await create_timer(0.12).timeout
	quit(0)
