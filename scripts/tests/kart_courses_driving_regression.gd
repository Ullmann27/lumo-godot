extends SceneTree
## End-to-end physics course completion. Test input only steers; geometry never moves the kart.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for track in ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]:
		game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"})
		await process_frame
		game.countdown = 0
		game.racing = true
		var frames: int = 0
		while not game.finished and frames < 11000:
			var target: Vector3 = game.world.position_at(game.previous_road_distance + 9.0, 0)
			var direction: Vector3 = target - game.player.position
			var heading: float = atan2(-direction.x, -direction.z)
			game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.3, -1, 1)
			game._physics_process(1.0 / 60)
			frames += 1
			if frames % 60 == 0:
				await process_frame
		assert(game.finished, "All four tracks must be finishable with physical steering")
		assert(game.checkpoint_index == 16, "Two laps cross all sixteen ordered gates")
		assert(game.reset_count == 0, "A smooth centre-line drive must not fall off the course")
		print("[KartCourseDriving] %s: two laps, %.2fs, no resets, place%d" % [track, game.elapsed, int(game.result_payload.place)])
	await process_frame
	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[KartCourseDriving] PASS: four distinct courses completed through physical steering")
	# AudioServer releases stopped stream playbacks on its asynchronous mix thread.
	await create_timer(0.12).timeout
	quit(0)
