extends SceneTree
## Himmelsinseln jump: race speed clears the gap and lands with a turbo, a crawl falls and is
## carried just past the gap, checkpoints stay ordered, rivals fly the same arc, and courses
## without a ramp never leave the ground.
const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _start(mode: String, track: String) -> void:
	game._start_selected_race(
		{"mode": mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	game.countdown = 0
	game.racing = true
	await process_frame


func _place(distance: float, speed: float) -> void:
	game.player.transform = game.world.reset_transform(distance)
	game.previous_road_distance = distance
	game.distance = distance
	game.player_heading = game._heading(distance)
	game.speed = speed
	var heading: float = game.player_heading
	game.physical_velocity = Vector3(-sin(heading), 0, -cos(heading)) * speed
	game.checkpoint_index = 3


func _drive(frames: int, braking: float = 0.0, stop_on_fall: bool = false) -> Dictionary:
	var longest_air: float = 0.0
	var landing_boost: float = 0.0
	var lowest_gap_height: float = INF
	for frame in range(frames):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 10.0, 0)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
		game.brake = braking
		var landings: int = game.landing_count
		game._physics_process(STEP)
		longest_air = maxf(longest_air, game.air_time)
		if game.landing_count > landings:
			landing_boost = game.boost_time
		if stop_on_fall and game.gap_falls > 0:
			break
		if game.world.in_gap(game.previous_road_distance) and game.airborne:
			var road: Dictionary = game.world.sample_road(game.player.position)
			lowest_gap_height = minf(lowest_gap_height, game.player.position.y - float(road.height))
	return {"air": longest_air, "boost": landing_boost, "lowest": lowest_gap_height}


func _test_clean_jump() -> void:
	await _start("training", "bergwelt")
	var jump: Dictionary = game.world.jump
	assert(not jump.is_empty(), "Himmelsinseln has a jump")
	_place(jump.ramp_start - 25.0, 17.0)
	var flight: Dictionary = _drive(150)
	assert(game.jump_count == 1 and game.landing_count == 1, "One take-off, one landing")
	assert(game.gap_falls == 0 and game.reset_count == 0, "Race speed clears the gap")
	assert(flight.air > 0.5, "A real flight (%.2f s)" % flight.air)
	assert(flight.boost >= 1.0, "A good landing gives a turbo")
	assert(fposmod(game.previous_road_distance, game.track_length) > jump.gap_end)
	assert(game.checkpoint_index == 4, "The checkpoint after the landing still counts")
	print(
		(
			"[KartJump] clean jump: %.2f s in the air, landing turbo %.1f s"
			% [flight.air, flight.boost]
		)
	)


func _test_too_slow() -> void:
	await _start("training", "bergwelt")
	var jump: Dictionary = game.world.jump
	_place(jump.ramp_start - 4.0, 4.0)
	var distance_before: float = game.distance
	_drive(600, 0.85, true)
	assert(game.gap_falls == 1 and game.reset_count == 1, "A crawl falls into the gap once")
	assert(not game.airborne)
	var landing: float = fposmod(game.previous_road_distance, game.track_length)
	assert(landing >= jump.gap_end and landing < jump.gap_end + 12.0, "Carried just past the gap")
	assert(game.distance - distance_before < 40.0, "The rescue is no shortcut")
	var road: Dictionary = game.world.sample_road(game.player.position)
	assert(absf(game.player.position.y - float(road.height)) < 0.2, "Back on the road surface")
	print(
		(
			"[KartJump] too slow: fell once, carried to %.1f m (gap ends %.1f m)"
			% [landing, jump.gap_end]
		)
	)


func _test_rival_arc() -> void:
	var world = game.world
	var jump: Dictionary = world.jump
	assert(world.rival_arc(jump.ramp_start - 1.0) == 0.0)
	assert(
		world.rival_arc(jump.take_off - 0.001) > jump.height * 0.95,
		"The arc starts at the ramp top"
	)
	assert(world.rival_arc((jump.take_off + jump.gap_end) * 0.5) > jump.height)
	assert(world.rival_arc(jump.gap_end + 0.5) == 0.0)
	await _start("race", "bergwelt")
	# The race start rebuilds the course; use the new world, not the freed one.
	world = game.world
	jump = world.jump
	game.opponent_distances[0] = jump.ramp_start - 6.0
	game.opponents[0].transform = world.reset_transform(jump.ramp_start - 6.0)
	var lowest: float = INF
	for frame in range(200):
		game._drive_opponents(STEP)
		var road: Dictionary = world.sample_road(game.opponents[0].position)
		lowest = minf(lowest, game.opponents[0].position.y - float(road.height))
	assert(
		fposmod(game.opponent_distances[0], game.track_length) > jump.gap_end,
		"The rival crossed the gap"
	)
	assert(lowest > -0.1, "Rivals never sink below the road")


func _test_no_ramp_elsewhere() -> void:
	await _start("training", "sonnenhafen")
	assert(game.world.jump.is_empty())
	_place(40.0, 17.0)
	_drive(120)
	assert(game.jump_count == 0 and not game.airborne, "Courses without a ramp stay grounded")


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await _test_clean_jump()
	await _test_too_slow()
	await _test_rival_arc()
	await _test_no_ramp_elsewhere()
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	print(
		(
			"[KartJump] PASS: take-off, flight, landing turbo, cloud rescue past the gap, "
			+ "ordered checkpoints across the jump, rival arc, no ramp elsewhere"
		)
	)
	await create_timer(0.5).timeout
	quit(0)
