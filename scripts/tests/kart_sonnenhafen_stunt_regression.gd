extends SceneTree
## Sonnenhafen stunt loop (Position A, 108 m before the crystal tunnel):
## layout on the real road, then real driving through _physics_process with
## gas and steering only: boost pad, loop entry, full 360 degrees on the
## rendered path, stars collected, safe exit and onward drive into the
## tunnel. A too-slow kart never falls: it is set back onto the main lane.
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const STEP: float = 1.0 / 60.0
var game
## A failed assert aborts its check; PASS needs every check to reach its end.
var completed_checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame


func _check_layout() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	var layout: Dictionary = world.loop_layout
	var tunnel: float = STUNT.tunnel_start(world)
	assert(
		not layout.is_empty() and bool(layout.get("stunt", false)), "Sonnenhafen has the stunt loop"
	)
	assert(
		is_equal_approx(float(layout.start), tunnel - STUNT.LOOP_LEAD_M), "Loop sits at Position A"
	)
	var structure_end: float = float(layout.start) + LOOP.ADVANCE + STUNT.LOOP_RADIUS + 2.0
	assert(structure_end < tunnel - 80.0, "Loop ends well before the tunnel mouth")
	assert(LOOP.radius_of(layout) > LOOP.RADIUS, "Stunt loop is larger than the side loops")
	var pads: Array = world.action.pads
	assert(pads.size() == 1, "Exactly one stunt boost pad")
	var pad: Dictionary = pads[0]
	assert(float(pad.end) < float(layout.start) - 10.0, "Pad ends before the loop entry")
	assert(is_equal_approx(float(pad.lateral), STUNT.LOOP_LANE), "Pad lies on the loop lane")
	var kicker: Dictionary = world.action.kickers[0]
	assert(float(pad.start) > float(kicker.take_off) + 40.0, "Panorama jump stays untouched")
	# Riding line: continuous, closed circle, upside down at the top.
	var top: Basis = LOOP.frame_at(world, layout, 0.5)
	assert(top.y.dot(Vector3.UP) < -0.95, "Kart is upside down at the top of the loop")
	var previous: Vector3 = LOOP.point(world, layout, 0.0)
	var longest: float = 0.0
	for i in range(1, 201):
		var p: Vector3 = LOOP.point(world, layout, float(i) / 200.0)
		longest = maxf(longest, p.distance_to(previous))
		previous = p
	assert(longest < 0.4, "Riding line has no gaps (%.2f m)" % longest)
	var peak: float = LOOP.point(world, layout, 0.5).y - world.position_at(float(layout.start)).y
	assert(peak > 2.0 * STUNT.LOOP_RADIUS - 0.5, "Loop height %.1f m" % peak)
	var star_count: int = STUNT.STAR_FRACTIONS.size() + 4 + STUNT.ARC_STARS.size()
	assert(STUNT.star_positions(world).size() == star_count)
	assert(world.get_node_or_null("StuntLoopDeck") is MeshInstance3D, "Deck mesh is built")
	# Other tracks keep their loops and rules.
	for track in ["zauberwald", "candy_cloud", "holo_city"]:
		var other = WORLD.new()
		root.add_child(other)
		other.build(true, track, true)
		if track == "candy_cloud":
			assert(is_equal_approx(LOOP.radius_of(other.loop_layout), LOOP.RADIUS))
			assert(not other.loop_layout.has("stunt"))
		else:
			assert(other.loop_layout.is_empty(), "%s has no loop" % track)
		other.free()
	world.free()
	completed_checks += 1
	print(
		(
			"[SonnenhafenStunt] layout: loop at %.1f m, tunnel at %.1f m, peak %.1f m"
			% [float(layout.start), tunnel, peak]
		)
	)


func _start() -> void:
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "flott"
		}
	)
	game._end_preview()
	await _settle()
	game.countdown = 0
	game.racing = true
	game.auto_gas = true


func _place(at: float, lateral: float, speed: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at, lateral)
	game.player_heading = game._heading(at)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = speed
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	)
	game.airborne = false
	game.boost_time = 0.0
	game.steering = 0.0


func _steer_to(lateral: float) -> void:
	var target: Vector3 = game.world.position_at(game.previous_road_distance + 8.0, lateral)
	var direction: Vector3 = target - game.player.position
	game.steering = clampf(
		-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3, -1, 1
	)


func _stunt_stars() -> int:
	var count: int = 0
	for key in game.collected.keys():
		if int(key) >= 1000000:
			count += 1
	return count


func _check_full_loop() -> void:
	await _start()
	var layout: Dictionary = game.world.loop_layout
	var pad: Dictionary = game.world.action.pads[0]
	_place(float(pad.start) - 14.0, STUNT.LOOP_LANE, 15.0)
	var pads_before: int = game.action_pads_triggered
	var loops_before: int = game.loop_count
	var resets_before: int = game.reset_count
	var entered: bool = false
	var entry_speed: float = 0.0
	var max_height: float = 0.0
	var worst_alignment: float = 1.0
	var last_progress: float = -1.0
	var last_distance: float = game.distance
	for frame in range(900):
		if not game.loop_state.active:
			_steer_to(STUNT.LOOP_LANE)
		else:
			game.steering = 0.0
		game._physics_process(STEP)
		assert(game.distance >= last_distance - 0.001, "Race distance never runs backwards")
		last_distance = game.distance
		if game.loop_state.active:
			if not entered:
				entry_speed = game.speed
			entered = true
			var p: Vector3 = game.player.position
			assert(is_finite(p.x) and is_finite(p.y) and is_finite(p.z))
			var expected: Basis = LOOP.frame_at(game.world, layout, game.loop_state.progress)
			worst_alignment = minf(
				worst_alignment, game.player.basis.y.normalized().dot(expected.y)
			)
			assert(game.loop_state.progress >= last_progress, "Loop progress is monotonic")
			last_progress = game.loop_state.progress
			max_height = maxf(max_height, p.y - game.world.position_at(float(layout.start)).y)
		elif entered:
			break
	assert(game.action_pads_triggered == pads_before + 1, "Boost pad fired on the loop lane")
	assert(entered, "Kart entered the loop")
	assert(game.loop_count == loops_before + 1, "Loop completed")
	assert(game.reset_count == resets_before, "No rescue reset")
	assert(worst_alignment > 0.98, "Kart orientation follows the loop (%.3f)" % worst_alignment)
	assert(max_height > 2.0 * STUNT.LOOP_RADIUS - 1.5, "Kart reached the top (%.1f m)" % max_height)
	var stars: int = _stunt_stars()
	assert(stars >= 5, "Stars on the riding line collected (%d)" % stars)
	# Onward: back on the road, fast, and into the tunnel without a reset.
	var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
	assert(absf(float(road.lateral) - STUNT.LOOP_LANE) < 0.6, "Exit on the loop lane")
	assert(absf(game.player.position.y - float(road.height)) < 0.3, "Exit on the road surface")
	assert(game.speed > 12.0, "Kart keeps speed after the loop (%.1f)" % game.speed)
	var tunnel: float = STUNT.tunnel_start(game.world)
	var frames: int = 0
	while fposmod(game.previous_road_distance, game.track_length) < tunnel + 10.0 and frames < 900:
		_steer_to(0.0)
		game._physics_process(STEP)
		frames += 1
	assert(frames < 900, "Kart reaches the tunnel")
	assert(game.reset_count == resets_before, "No reset on the way into the tunnel")
	completed_checks += 1
	print(
		(
			(
				"[SonnenhafenStunt] loop: entry %.1f m/s, top %.1f m, alignment %.3f,"
				+ " %d stars, exit %.1f m/s, tunnel after %d frames"
			)
			% [entry_speed, max_height, worst_alignment, stars, game.speed, frames]
		)
	)


func _check_too_slow() -> void:
	await _start()
	var layout: Dictionary = game.world.loop_layout
	# Barely fast enough to enter, then braking hard: the climb fails safely.
	_place(float(layout.start) - 0.8, STUNT.LOOP_LANE, 14.0)
	game.auto_gas = false
	game.gas_held = false
	var loops_before: int = game.loop_count
	var entered: bool = false
	var fell_below: bool = false
	for frame in range(600):
		game.steering = 0.0
		if game.loop_state.active:
			entered = true
			game.control_brake = 1.0
		game._physics_process(STEP)
		if entered and not game.loop_state.active:
			break
	game.control_brake = 0.0
	assert(entered, "Slow kart entered and failed inside the loop")
	assert(game.loop_count == loops_before, "Failed attempt is not counted")
	var road: Dictionary = game.world.sample_road(game.player.position, game.previous_road_distance)
	assert(absf(float(road.lateral)) < 0.6, "Set back onto the main lane")
	assert(absf(game.player.position.y - float(road.height)) < 0.3, "Back on the road surface")
	assert("Schwung" in game.message.text)
	# It must not re-enter or bounce: drive on along the main lane.
	for frame in range(240):
		_steer_to(0.0)
		game._physics_process(STEP)
		fell_below = fell_below or game.loop_state.active
	assert(not fell_below, "No re-entry from the main lane")
	completed_checks += 1
	print("[SonnenhafenStunt] too slow: safe set-back to the main lane")


func _check_stunt_jump() -> void:
	await _start()
	var kickers: Array = game.world.action.kickers
	var jump: Dictionary = {}
	for kicker in kickers:
		if bool(kicker.get("stunt", false)):
			jump = kicker
	assert(not jump.is_empty(), "Stunt jump exists")
	var tunnel: float = STUNT.tunnel_start(game.world)
	assert(is_equal_approx(float(jump.take_off), tunnel - STUNT.JUMP_LEAD_M), "Jump at Position B")
	assert(
		float(jump.start) > float(game.world.loop_layout.start) + LOOP.ADVANCE,
		"Ramp after the loop exit"
	)
	_place(float(jump.start) - 14.0, 0.0, 20.0)
	var jumps_before: int = game.action_kicker_jumps
	var landings_before: int = game.landing_count
	var resets_before: int = game.reset_count
	var stars_before: int = _stunt_stars()
	var entered_air: bool = false
	var max_height: float = 0.0
	var air: float = 0.0
	var flight_start: float = 0.0
	var flight_end: float = 0.0
	for frame in range(300):
		_steer_to(0.0)
		game._physics_process(STEP)
		if game.airborne:
			if not entered_air:
				flight_start = game.distance
			entered_air = true
			air = maxf(air, game.air_time)
			var road: Dictionary = game.world.sample_road(
				game.player.position, game.previous_road_distance
			)
			max_height = maxf(max_height, game.player.position.y - float(road.height))
		elif entered_air:
			flight_end = game.distance
			break
	assert(
		entered_air and game.action_kicker_jumps == jumps_before + 1,
		"Kart launched from the stunt jump"
	)
	assert(game.landing_count == landings_before + 1 and not game.airborne, "Safe landing")
	assert(game.reset_count == resets_before, "No rescue on the stunt jump")
	assert(max_height > 3.0 and flight_end - flight_start > 15.0, "Real flight")
	var road_after: Dictionary = game.world.sample_road(
		game.player.position, game.previous_road_distance
	)
	assert(absf(float(road_after.lateral)) < 4.5, "Landed on the road")
	var arc_stars: int = _stunt_stars() - stars_before
	assert(fposmod(flight_end, game.track_length) < tunnel - 5.0, "Landing before the tunnel mouth")
	completed_checks += 1
	print(
		(
			"[SonnenhafenStunt] jump: %.1f m flight, %.1f m high, %.2f s air, %d arc stars"
			% [flight_end - flight_start, max_height, air, arc_stars]
		)
	)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	await _check_layout()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _check_full_loop()
	await _check_too_slow()
	await _check_stunt_jump()
	if completed_checks != 4:
		print("[SonnenhafenStunt] FAIL: %d of 4 checks completed" % completed_checks)
		quit(1)
		return
	print("[SonnenhafenStunt] PASS: real loop, boost pad, stars, safe exit and safe failure")
	quit(0)
