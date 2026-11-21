extends SceneTree
const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _steer(lane: float) -> void:
	var local: float = fposmod(game.previous_road_distance, game.track_length)
	var target: Vector3 = game.world.position_at(local + 8.0, lane)
	var direction: Vector3 = target - game.player.position
	var axis: float = -angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.0
	game.steering = clampf(axis, -1.0, 1.0)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	var t0: int = Time.get_ticks_msec()
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet", "track": "riesengarten_2400", "difficulty": "flott"})
	game._end_preview()
	await process_frame
	print("build ms ", Time.get_ticks_msec() - t0, " length ", game.track_length)
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	var t: float = 0.0
	var air: int = 0
	var was_air: bool = false
	var max_over: float = -INF
	var last_report: float = 0.0
	while game.checkpoint_index < 8 and t < 160.0:
		var lane: float = 0.0
		var d: float = fposmod(game.previous_road_distance, game.track_length)
		if d > 1520.0 and d < 1650.0:
			lane = -8.9
		_steer(lane)
		game._physics_process(STEP)
		t += STEP
		if game.airborne and not was_air:
			air += 1
			print("takeoff at %.1f speed %.1f vs %.1f" % [d, game.speed, game.vertical_speed])
		if was_air and not game.airborne:
			print("landing at %.1f lane %.2f" % [d, game.lane])
		was_air = game.airborne
		max_over = maxf(max_over, absf(game.lane) - game.world.wall_lateral_at(d))
		if t - last_report > 5.0:
			last_report = t
			print("t %.0f d %.0f speed %.1f lane %.2f y %.2f" % [t, d, game.speed, game.lane, game.player.position.y])
	print("lap: checkpoints %d t %.1f resets %d air %d walls %d max_over %.2f" % [game.checkpoint_index, t, game.reset_count, air, game.wall_contacts, max_over])
	game.abandoned = true
	quit(0)
