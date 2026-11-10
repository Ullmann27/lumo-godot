extends SceneTree
## Controller integration proof. The attraction's actual GPU transforms are
## checked separately by kart_harbor_attraction_regression.gd with GL rendering.
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.lightweight = true
	(
		game
		. _start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": "sonnenhafen",
				"difficulty": "flott",
			}
		)
	)
	game.set_physics_process(false)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.speed = 0.0
	game.player.position = game.world.position_at(95.0) + Vector3.UP * 0.035
	game.player_heading = game._heading(95.0)
	game.previous_road_distance = 95.0
	game.physical_velocity = Vector3.ZERO
	var attraction = game.world.get_node_or_null("SonnenhafenHarborAttraction")
	if attraction == null:
		printerr("[HarborRaceHook] FAIL real race world has no harbor attraction")
		quit(1)
		return
	var phase: float = attraction.phase
	# Only the actual game physics loop is called; no direct attraction.advance.
	for i in range(60):
		game._physics_process(1.0 / 60.0)
	_check(
		attraction.phase > phase + 0.04, "Normal racing physics must advance the visible attraction"
	)
	_check(attraction.trigger_count == 1, "The real racer position must reach the attraction")
	game._pause()
	phase = attraction.phase
	for i in range(12):
		game._physics_process(1.0 / 60.0)
	_check(is_equal_approx(phase, attraction.phase), "Race pause must freeze the attraction")
	game._resume()
	game._physics_process(1.0 / 60.0)
	_check(attraction.phase > phase, "Race resume must continue the attraction")
	game.reduced_motion = true
	phase = attraction.phase
	game._physics_process(1.0 / 60.0)
	_check(
		is_equal_approx(phase, attraction.phase),
		"Reduced-motion preference must reach the attraction"
	)
	game.reduced_motion = false
	game.finished = true
	game.finish_cine_left = 0.0
	game._physics_process(1.0 / 60.0)
	_check(is_equal_approx(phase, attraction.phase), "Finished race must freeze the attraction")
	game.abandoned = true
	game.queue_free()
	await process_frame
	for failure in failures:
		printerr("[HarborRaceHook] FAIL ", failure)
	if failures.is_empty():
		print(
			"[HarborRaceHook] PASS: actual race physics, position, pause, resume, reduced motion, finish"
		)
	quit(0 if failures.is_empty() else 1)
