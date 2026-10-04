extends SceneTree
## Rails are real walls on every course, drift has two turbo tiers, driving against the course
## is announced, and neither reversing over the line nor jumping ahead creates lap progress.
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


func _steer_towards(target: Vector3) -> void:
	var direction: Vector3 = target - game.player.position
	var heading: float = atan2(-direction.x, -direction.z)
	game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)


func _face(heading: float, speed: float) -> void:
	game.player_heading = heading
	game.speed = speed
	game.physical_velocity = Vector3(-sin(heading), 0, -cos(heading)) * speed


func _test_walls(track: String) -> void:
	for side in [1.0, -1.0]:
		await _start("training", track)
		var start_distance: float = game.distance
		var widest: float = 0.0
		for frame in range(300):
			# Aim far beyond the rail at full turbo speed: the worst case for tunnelling.
			_steer_towards(game.world.position_at(game.previous_road_distance + 14.0, side * 14.0))
			game.boost_time = 3.0
			game._physics_process(STEP)
			widest = maxf(widest, absf(game.lane))
		var wall: float = game.WORLD.WALL_LATERAL
		assert(
			widest <= wall + 0.02, "%s: the kart stays inside the rail (%.2f m)" % [track, widest]
		)
		assert(game.wall_contacts > 10, "%s: the rail was actually hit" % track)
		assert(game.reset_count == 0, "%s: a rail hit never drops the kart" % track)
		assert(game.distance - start_distance > 25.0, "%s: the kart slides along the rail" % track)
		print(
			(
				"[KartPhysics] %s side %+d: widest %.2f m, %d wall contacts, %.0f m along the rail"
				% [track, int(side), widest, game.wall_contacts, game.distance - start_distance]
			)
		)


func _test_drift_tiers() -> void:
	await _start("training", "sonnenhafen")
	_face(game._heading(0), 15.0)
	game.drifting = true
	for frame in range(60):
		game.steering = 1.0
		game._physics_process(STEP)
	assert(game.drift_charge >= 0.8 and game.drift_charge < 1.8, "One second of drift charges blue")
	game.boost_time = 0
	game._release_drift()
	assert(is_equal_approx(game.boost_time, 1.0) and game.drift_tier_count == [1, 0])
	assert("Blauer" in game.message.text)
	game.drifting = true
	game.drift_charge = 1.9
	game.boost_time = 0
	game._release_drift()
	assert(game.boost_time >= 1.8 and game.drift_tier_count == [1, 1], "A long drift is orange")
	game.drifting = true
	game.drift_charge = 0.5
	game.boost_time = 0
	game._release_drift()
	assert(game.boost_time == 0 and game.drift_tier_count == [1, 1], "A short drift gives nothing")


func _test_wrong_way() -> void:
	await _start("training", "sonnenhafen")
	var d: float = game.track_length * 0.25
	game.player.transform = game.world.reset_transform(d)
	game.previous_road_distance = d
	game.distance = d
	_face(game._heading(d) + PI, 12.0)
	for frame in range(150):
		_steer_towards(game.world.position_at(game.previous_road_distance - 12.0))
		game._physics_process(STEP)
	assert(game.wrong_way, "Driving backwards is detected")
	assert("Falsche Richtung" in game.message.text, "Driving backwards is announced")
	_face(game._heading(game.previous_road_distance), 12.0)
	for frame in range(30):
		_steer_towards(game.world.position_at(game.previous_road_distance + 12.0))
		game._physics_process(STEP)
	assert(not game.wrong_way, "The warning clears once the kart turns around")


func _test_lap_validity() -> void:
	await _start("time_trial", "sonnenhafen")
	_face(game._heading(0) + PI, 10.0)
	for frame in range(240):
		_steer_towards(game.world.position_at(game.previous_road_distance - 12.0))
		game._physics_process(STEP)
	assert(game.distance < 1.0 and game.checkpoint_index == 0, "Reversing over the line is no lap")
	assert(not game.finished)
	var before: float = game.distance
	game.player.position = game.world.position_at(game.track_length * 0.9)
	game._physics_process(STEP)
	assert(game.distance - before < 5.0, "Jumping ahead gives no progress")
	assert(game.checkpoint_index == 0)
	assert(not game.finished)


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for track in game.CATALOG.TRACKS:
		await _test_walls(str(track.id))
	await _test_drift_tiers()
	await _test_wrong_way()
	await _test_lap_validity()
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	print(
		(
			"[KartPhysics] PASS: rail walls on four courses at full turbo, sliding contact, "
			+ "blue/orange drift tiers, wrong-way warning, reverse line and jump-ahead give no lap"
		)
	)
	# The audio mix thread releases the course music late.
	await create_timer(0.5).timeout
	quit(0)
