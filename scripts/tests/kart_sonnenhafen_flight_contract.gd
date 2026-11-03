extends SceneTree
## Release-blocking contract: honest speed-dependent leap, non-cheating
## prediction, contiguous mainline loop and a physically absent road gap.
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
const BALLISTICS = preload("res://scripts/games/kart_stunt_ballistics.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")


func _initialize() -> void:
	call_deferred("_run")


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
	quit(0)
