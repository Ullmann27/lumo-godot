extends SceneTree
## Release-blocking contract: honest speed-dependent leap, non-cheating
## prediction, contiguous mainline loop and a physically absent road gap.
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
const BALLISTICS = preload("res://scripts/games/kart_stunt_ballistics.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")



## Exercise the REAL kart vertical physics, not only the mathematical HUD
## forecast. Horizontal trajectory is fed at a constant measured speed so
## aerodynamic steering/AI/autogas cannot silently hide an incorrect launch.
func _verify_actual_vertical_flight(world, speed_mps: float, expected: String) -> void:
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await process_frame
	game._start_selected_race({
		"mode": "training", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "flott"
	})
	game._end_preview()
	await process_frame
	game.countdown = 0.0
	game.racing = true
	var kicker: Dictionary = {}
	for candidate in game.world.action.kickers:
		if bool(candidate.get("stunt", false)):
			kicker = candidate
	assert(not kicker.is_empty())
	var take_off: float = float(kicker.take_off)
	var gap_end: float = float(kicker.gap_end)
	var d: float = take_off - 0.35
	game.player.transform = game.world.reset_transform(d)
	game.player.position.y = game.world.position_at(d).y + game.world.ramp_height(d) + 0.035
	game.previous_road_distance = d
	game.speed = speed_mps
	var old_resets: int = game.reset_count
	var old_landings: int = game.landing_count
	var started: bool = false
	var recovered: bool = false
	var landed: bool = false
	var distance_landed: float = 0.0
	for i in range(240):
		d += speed_mps / 60.0
		var road_point: Vector3 = game.world.position_at(d)
		game.player.position.x = road_point.x
		game.player.position.z = road_point.z
		game.previous_road_distance = d - speed_mps / 60.0
		var ok: bool = game._move_vertically({"height": road_point.y}, d, 1.0 / 60.0)
		started = started or game.airborne
		if not ok:
			recovered = true
			break
		if started and not game.airborne:
			landed = true
			distance_landed = d
			break
	assert(started, "Actual flight must begin before evaluating failure/landing")
	if expected == "slow":
		assert(recovered and not landed, "Low-speed player must fall and respawn")
		assert(game.reset_count > old_resets, "Slow-speed rescue must be real")
		assert(game.previous_road_distance < take_off,
			"Missed jump retries before the launch, never beyond the gap")
	else:
		assert(landed and not recovered, "At-speed player must land naturally")
		assert(game.landing_count == old_landings + 1, "The runtime records landing")
		if expected == "good":
			assert(distance_landed >= gap_end and distance_landed <= gap_end + STUNT.JUMP_LANDING_BAND_M,
				"Ideal speed must land in the clearly marked safety band")
		else:
			assert(distance_landed > gap_end + STUNT.JUMP_LANDING_BAND_M,
				"Overspeed must travel past ideal band, not be magnetically braked")
	print("[SonnenhafenFlight] %s actual %.1f m/s: %s, landing distance %.1f" % [
		expected, speed_mps, "rescue" if recovered else "landed", distance_landed
	])
	game.abandoned = true
	game.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	assert(is_equal_approx(STUNT.LOOP_LANE, 0.0), "Loop must share central racing line")
	assert(is_equal_approx(float(world.loop_layout.lane), 0.0))
	var aero: Node = world.get_node_or_null("SonnenhafenAeroRunway")
	assert(aero is MeshInstance3D, "Single-piece curved launch runway exists")
	assert(aero.material_override is ShaderMaterial, "Ramp uses loop's luminous metallic shader")
	var jump: Dictionary = {}
	for kicker in world.action.kickers:
		if bool(kicker.get("stunt", false)):
			jump = kicker
	assert(not jump.is_empty())
	assert(is_equal_approx(float(jump.gap_end) - float(jump.take_off), STUNT.JUMP_GAP_M))
	var start: float = float(jump.take_off)
	var end: float = float(jump.gap_end)
	assert(not world.in_gap(start - 0.5), "Solid ramp before the cliff")
	assert(world.in_gap(start + 1.0), "The road actually disappears after take-off")
	assert(world.in_gap((start + end) * 0.5), "Entire stunt gap is physically unsupported")
	assert(not world.in_gap(end + 0.5), "Landing road resumes")
	var min_speed: float = BALLISTICS.required_speed(
		STUNT.JUMP_GAP_M, float(jump.angle), float(jump.height), float(jump.flight_gravity)
	)
	assert(min_speed > 17.0 and min_speed < 21.0, "Jump must be achievable by normal driving")
	var slow: Dictionary = BALLISTICS.forecast(15.0, jump)
	var good: Dictionary = BALLISTICS.forecast(20.5, jump)
	var fast: Dictionary = BALLISTICS.forecast(30.0, jump)
	assert(slow.state == "slow", "Too slow predicts a fall, never a magnet landing")
	assert(good.state == "good", "Normal adventure pace reaches the designated landing")
	assert(fast.state == "fast", "High speed travels past the target landing zone")
	assert(float(slow.range) < STUNT.JUMP_GAP_M)
	assert(float(good.range) > STUNT.JUMP_GAP_M)
	assert(float(fast.range) > STUNT.JUMP_GAP_M + STUNT.JUMP_LANDING_BAND_M)
	assert(BALLISTICS.landing_range(30.0, float(jump.angle), float(jump.height),
			float(jump.flight_gravity)) > float(good.range), "No speed cap")
	assert(BALLISTICS.flight_time(0.0, float(jump.angle), float(jump.height),
			float(jump.flight_gravity)) == 0.0)
	print("[SonnenhafenFlight] PASS: real gap, mainline loop, 15/20.5/30 mps ballistic contract")
	world.free()
	await _verify_actual_vertical_flight(null, 15.0, "slow")
	await _verify_actual_vertical_flight(null, 20.5, "good")
	await _verify_actual_vertical_flight(null, 30.0, "fast")
	print("[SonnenhafenFlight] PASS: 3 real physics profiles + static ballistic contract")
	quit(0)
