extends SceneTree
## Pure math + layout checks for the Sonnenhafen precision jump model.
## Runs headless. Driving checks live in kart_sonnenhafen_stunt_regression.gd.
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[PrecisionJump] FAIL: ", label)


func _run() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	var kicker: Dictionary = {}
	for candidate in world.action.kickers:
		if bool(candidate.get("precision_jump", false)):
			kicker = candidate
	_check(not kicker.is_empty(), "Sonnenhafen has a precision kicker")
	if kicker.is_empty():
		_finish()
		return
	_check(float(kicker.lift_bonus) == 0.0, "No hidden lift bonus")
	_check(float(kicker.max_lift) >= 1000.0, "No hidden lift cap")
	_check(is_equal_approx(float(kicker.gap_end) - float(kicker.take_off), float(kicker.landing_min)),
		"Road resumes exactly where the landing zone begins")
	# Monotonic: more speed always means a longer flight.
	var previous: float = -1.0
	var monotonic: bool = true
	for step in range(1, 81):
		var d: float = PRECISION.landing_distance(float(step) * 0.5, kicker)
		monotonic = monotonic and d > previous
		previous = d
	_check(monotonic, "Landing distance grows with speed")
	# Closed form against an explicit 1 ms Euler integration of the same rules.
	for speed in [12.0, 16.0, 20.5, 26.0, 30.0]:
		var y: float = float(kicker.height)
		var vy: float = PRECISION.launch_vertical(speed, kicker)
		var x: float = 0.0
		var dt: float = 0.001
		while true:
			vy -= float(kicker.flight_gravity) * dt
			y += vy * dt
			x += speed * dt
			if y <= float(kicker.landing_slope) * x:
				break
		var model: float = PRECISION.landing_distance(speed, kicker)
		_check(absf(model - x) < 0.08, "Integration matches model at %.1f m/s (%.2f vs %.2f)" % [speed, model, x])
	var min_speed: float = PRECISION.speed_for_distance(float(kicker.landing_min), kicker)
	var max_speed: float = PRECISION.speed_for_distance(float(kicker.landing_max), kicker)
	_check(absf(PRECISION.landing_distance(min_speed, kicker) - float(kicker.landing_min)) < 0.01, "Inverse at zone start")
	_check(absf(PRECISION.landing_distance(max_speed, kicker) - float(kicker.landing_max)) < 0.01, "Inverse at zone end")
	# Undershoot / zone / overshoot at given speeds.
	_check(PRECISION.prediction(min_speed - 1.0, kicker).status == PRECISION.STATUS_SLOW, "Too slow -> langsam")
	_check(PRECISION.prediction((min_speed + max_speed) * 0.5, kicker).status == PRECISION.STATUS_GOOD, "Middle -> passend")
	_check(PRECISION.prediction(max_speed + 1.0, kicker).status == PRECISION.STATUS_FAST, "Too fast -> schnell")
	_check(PRECISION.classify_landing(float(kicker.landing_min) - 0.1, kicker) == PRECISION.LANDING_SHORT, "Short landing")
	_check(PRECISION.classify_landing(float(kicker.landing_max) + 0.1, kicker) == PRECISION.LANDING_LONG, "Long landing")
	_check(PRECISION.classify_landing(20.0, kicker) == PRECISION.LANDING_ZONE, "Zone landing")
	_check(PRECISION.hint(PRECISION.STATUS_SLOW).text == "Gib Gas!", "Red hint text")
	_check(PRECISION.hint(PRECISION.STATUS_GOOD).text == "Tempo passt!", "Green hint text")
	_check(PRECISION.hint(PRECISION.STATUS_FAST).text == "Etwas bremsen!", "Orange hint text")
	# Fairness: every kart at plain top speed lands in the zone on every difficulty,
	# while a turbo at the lip (Abenteuer, neutral kart) overshoots.
	var factors_range: Array[float] = [0.97, 1.0, 1.09 * 1.012]
	for difficulty in CATALOG.DIFFICULTIES:
		for factor in factors_range:
			var top: float = POWERTRAIN.top_speed({"speed": factor}, float(difficulty.speed))
			var status: String = PRECISION.prediction(top, kicker).status
			_check(status == PRECISION.STATUS_GOOD,
				"%s x%.3f: %.1f m/s lands in zone (%.1f m)" % [difficulty.id, factor, top, PRECISION.landing_distance(top, kicker)])
	var turbo: float = POWERTRAIN.top_speed({}, 1.0) * 1.42
	_check(PRECISION.prediction(turbo, kicker).status == PRECISION.STATUS_FAST, "Turbo at the lip overshoots")
	# Loop placement: run-up, ramp after loop exit, landing before the tunnel.
	var layout: Dictionary = world.loop_layout
	var tunnel: float = STUNT.tunnel_start(world)
	_check(float(kicker.start) - (float(layout.start) + 7.0) > 60.0, "At least 60 m between loop exit and ramp")
	_check(float(kicker.take_off) + float(kicker.landing_max) + 20.0 < tunnel, "Landing zone ends 20 m before tunnel")
	for i in range(STUNT.ARC_STARS.size()):
		var star: Vector3 = STUNT.star_positions(world)[STUNT.STAR_FRACTIONS.size() + 4 + i]
		_check(star.y > world.position_at(float(kicker.take_off)).y + 3.0, "Arc star %d hangs above the lip" % i)
	world.free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("[PrecisionJump] PASS: %d checks" % checks)
		quit(0)
	else:
		print("[PrecisionJump] FAIL: %d of %d checks failed" % [failures.size(), checks])
		quit(1)
