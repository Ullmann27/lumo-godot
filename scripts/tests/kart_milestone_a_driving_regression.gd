extends SceneTree
## Meilenstein A: exercise actual race driver, rail and rival projection on
## two physically separated levels, plus the vertical tangent singularity.
## Does NOT modify profile data, scoring, rewards or production track assets.
const WORLD = preload("res://scripts/games/kart_world.gd")
const EPS: float = 0.8
const STEP: float = 1.0 / 60.0

func _initialize() -> void:
	call_deferred("_run")

func _install_two_deck_fixture(world) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	for p in [
		Vector3(-85, 2, -36), Vector3(85, 2, 36),
		Vector3(100, 6, 70), Vector3(80, 16, 90),
		Vector3(-80, 16, -90), Vector3(-100, 10, -90),
		Vector3(-85, 2, -36)
	]:
		curve.add_point(p)
	world.curve = curve
	world.length = curve.get_baked_length()
	world._road_samples.clear()
	world._road_distances.clear()
	var count: int = ceili(world.length / 5.0)
	for i in range(count):
		var d: float = float(i) * world.length / float(count)
		world._road_samples.append(curve.sample_baked(d, true))
		world._road_distances.append(d)

func _test_vertical_tangent() -> void:
	var world = WORLD.new()
	var c := Curve3D.new()
	c.bake_interval = 0.25
	for p in [
		Vector3(0, 0, 0), Vector3(0, 30, 0),
		Vector3(0, 60, 0), Vector3(30, 70, -30)
	]:
		c.add_point(p)
	world.curve = c
	world.length = c.get_baked_length()
	for d in [3.0, 11.0, 24.0, 39.0]:
		var basis: Basis = world.frame(d)
		assert(basis.is_finite(), "Vertical tangent produced non-finite frame")
		assert(absf(basis.determinant() - 1.0) < 0.0001,
			"Vertical tangent must produce a proper rotation")
		assert((-basis.z).dot(world.forward(d)) > 0.999,
			"Godot negative Z must remain track forward on vertical segment")
	world.free()

func _test_live_rival_and_wall() -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "flott"
	})
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	await process_frame
	var world = game.world
	_install_two_deck_fixture(world)
	game.track_length = world.length
	var lower: Dictionary = world.sample_road(Vector3(0, 2, 0))
	var upper: Dictionary = world.sample_road(Vector3(0, 16, 0))
	var lower_d: float = float(lower.distance)
	var upper_d: float = float(upper.distance)
	assert(absf(float(upper.height) - float(lower.height)) > 12.0)

	# Existing rail correction must only change lateral position, never deck.
	for d in [lower_d, upper_d]:
		var deck_height: float = world.position_at(d).y
		game.player.position = world.position_at(d, 5.35) + Vector3.UP * 0.035
		game.lane = 5.35
		game.physical_velocity = Vector3.ZERO
		var contact: Dictionary = world.sample_road(game.player.position, d)
		game._collide_with_rail(contact)
		var corrected: Dictionary = world.sample_road(game.player.position, d)
		assert(absf(float(corrected.lateral)) <= world.WALL_LATERAL + 0.08,
			"Rail correction failed to stay inside its lane")
		assert(absf(float(corrected.height) - deck_height) < EPS,
			"Rail contact moved the kart onto the wrong road level")

	# Five actual race rival instances travel on the stacked deck fixture.
	# Heights must remain separated even when their X/Z overlap at the crossing.
	assert(game.opponents.size() == 5)
	for i in range(game.opponents.size()):
		var d: float = upper_d if i == 1 or i == 3 else lower_d
		var offset: float = float(i - 2) * 0.6
		game.opponents[i].position = world.position_at(d, offset) + Vector3.UP * 0.035
		game.opponent_distances[i] = d
		game.opponent_lanes[i] = offset
		game.opponent_headings[i] = game._heading(d)
	game.player.position = Vector3(100, 3, 100)
	for _tick in range(8):
		game._drive_opponents(STEP)
		var sampled_lower: Dictionary = world.sample_road(
			game.opponents[0].position, fposmod(game.opponent_distances[0], world.length)
		)
		var sampled_upper: Dictionary = world.sample_road(
			game.opponents[1].position, fposmod(game.opponent_distances[1], world.length)
		)
		assert(float(sampled_upper.height) - float(sampled_lower.height) > 11.0,
			"Rival AI changed road decks at a 3D crossing")
		assert(float(game.opponents[0].position.y) < 5.0, "Lower AI rival snapped up")
		assert(float(game.opponents[1].position.y) > 13.0, "Upper AI rival dropped down")

	# Physics, not just projected positions: player drives across each deck
	# for multiple simulation ticks without changing to the crossing below.
	for d in [lower_d, upper_d]:
		var start: float = d - 3.0
		game.player.position = world.position_at(start) + Vector3.UP * 0.035
		game.player_heading = game._heading(start)
		game.previous_road_distance = start
		game.distance = start
		game.lane = 0.0
		game.speed = 16.0
		game.physical_velocity = Vector3(
			-sin(game.player_heading), 0.0, -cos(game.player_heading)
		) * game.speed
		game.airborne = false
		game.offroad_seconds = 0.0
		var resets_before: int = game.reset_count
		for _frame in range(32):
			game._drive_player(STEP, 0.0, 0.0)
			var contact: Dictionary = world.sample_road(
				game.player.position, game.previous_road_distance
			)
			assert(absf(float(contact.lateral)) < 1.2,
				"Physical driving drifted off the road while crossing levels")
			assert(absf(float(contact.height) - game.player.position.y) < 0.2,
				"Physical driving snapped away from its own road surface")
			if d == upper_d:
				assert(game.player.position.y > 13.0, "Player lost the upper road")
			else:
				assert(game.player.position.y < 5.0, "Player jumped onto the bridge")
		assert(game.reset_count == resets_before,
			"An ordinary stacked-road pass must not trigger rescue")
		assert(game.distance > start + 2.0,
			"Actual horizontal physics failed to progress on the 3D road")

	# Actual game respawn stays behind current progress, in its checkpoint
	# interval, and restores the correct deck without resetting race rewards.
	for d in [lower_d, upper_d]:
		game.player.position = world.position_at(d) - Vector3.UP * 4.0
		game.distance = d
		game.previous_road_distance = d
		game.checkpoint_index = int(floorf(d / (world.length / 8.0)))
		var checkpoint_before: int = game.checkpoint_index
		var previous_resets: int = game.reset_count
		game.lane = 0.0
		game._reset_kart()
		assert(game.reset_count == previous_resets + 1)
		assert(game.checkpoint_index == checkpoint_before,
			"Respawn must not award checkpoint progress")
		assert(game.distance <= d + 0.001,
			"Respawn must not advance race progress")
		assert(game.distance >= float(checkpoint_before) * world.length / 8.0,
			"Respawn must stay inside current checkpoint interval")
		assert(absf(game.player.position.y - world.position_at(game.distance).y) < 0.2,
			"Respawn height must match its selected road deck")
		assert(float(game.player.position.y) > 12.0 if d == upper_d else float(game.player.position.y) < 5.0,
			"Respawn jumped to the wrong road deck")
	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[MilestoneADriving] PASS: vertical frame, two-deck rail/AI rivals and checkpoint-safe respawn")
	await create_timer(0.12).timeout

func _run() -> void:
	_test_vertical_tangent()
	await _test_live_rival_and_wall()
	quit(0)
