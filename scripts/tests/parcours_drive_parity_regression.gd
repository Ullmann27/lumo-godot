extends SceneTree
## Der Parcours fährt mit der Fahrphysik von LUMO Kart: dieselben Eingaben ergeben in
## kart_island.gd (Kristall-Arena, flacher Boden) und in parcours_drive.gd (Faktor 0,68
## wie die Arena) Bild für Bild dasselbe Tempo und dieselbe Fahrtrichtung, auch mit
## Drift, Bremse und Turbo.

const STEP: float = 1.0 / 60.0
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ParcoursParity] FAIL: " + text)


func _inputs(frame: int) -> Dictionary:
	# Anfahren, Linkskurve, Drift, Bremsen, Turbo, Rechtskurve.
	var axis: float = 0.0
	var brake: float = 0.0
	var drift: bool = false
	var boost: bool = frame == 260
	if frame >= 60 and frame < 140:
		axis = -0.7
	if frame >= 140 and frame < 220:
		axis = 0.9
		drift = true
	if frame >= 220 and frame < 250:
		brake = 1.0
	if frame >= 300 and frame < 380:
		axis = 0.5
	return {"axis": axis, "brake": brake, "drift": drift, "boost": boost}


func _run() -> void:
	var game: Node = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race({"mode": "arena", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"})
	game._end_preview()
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	game.player.position = Vector3(0, 0.035, 0)
	game.arena.obstacles.clear()
	game.player_heading = 0.0
	game.speed = 0.0
	game.physical_velocity = Vector3.ZERO
	await process_frame
	var drive = load("res://scripts/games/parcours/parcours_drive.gd").new()
	drive.factors = game.kart_factors.duplicate()
	if drive.factors.is_empty():
		game._refresh_kart_factors()
		drive.factors = game.kart_factors.duplicate()
	drive.difficulty = "flott"
	drive.boosts = 1
	game.boosts = 1
	var worst_speed: float = 0.0
	var worst_heading: float = 0.0
	for frame in range(420):
		var input: Dictionary = _inputs(frame)
		# kart_island: echte Eingabewege (Lenkachse, Bremspedal, Drift-, Boostknopf).
		game.steering = float(input.axis)
		game.control_brake = float(input.brake)
		if bool(input.drift) and not game.drifting:
			game._press_drift()
		if not bool(input.drift) and game.drifting:
			game._release_drift()
		if bool(input.boost):
			game._boost()
		game.boost_time = maxf(0.0, game.boost_time)
		var before_boost: float = game.boost_time
		game._drive_player(STEP, float(input.axis), float(input.brake))
		game.boost_time = maxf(0.0, before_boost - STEP)
		# Tempo und Richtung hängen in der Arena nicht vom Ort ab: in der Mitte halten,
		# damit Rand und Säulen den Vergleich nicht stören.
		game.player.position = Vector3(0, 0.035, 0)
		# Parcours-Fahren mit denselben Eingaben (Arena-Faktor 0,68, ebener Boden).
		if bool(input.drift) and not drive.drifting:
			drive.press_drift()
		if not bool(input.drift) and drive.drifting:
			drive.release_drift()
		if bool(input.boost):
			drive.use_boost()
		drive.planar_step(STEP, float(input.axis), float(input.brake), 1.0, false, 0.68)
		drive.boost_time = maxf(0.0, drive.boost_time - STEP)
		worst_speed = maxf(worst_speed, absf(game.speed - drive.speed))
		worst_heading = maxf(worst_heading, absf(angle_difference(game.player_heading, drive.heading)))
	_check(worst_speed < 0.01, "Tempo gleich (größte Abweichung %.4f m/s)" % worst_speed)
	_check(worst_heading < 0.001, "Richtung gleich (größte Abweichung %.5f rad)" % worst_heading)
	_check(drive.drift_tier_count == game.drift_tier_count, "Driftstufen gleich %s / %s" % [drive.drift_tier_count, game.drift_tier_count])
	print("[ParcoursParity] max Δv=%.5f m/s, max Δh=%.6f rad, v_end=%.2f/%.2f" % [worst_speed, worst_heading, game.speed, drive.speed])
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	if failures == 0:
		print("[ParcoursParity] PASS: %d Prüfungen" % checks)
	else:
		print("[ParcoursParity] FAIL: %d von %d Prüfungen" % [failures, checks])
	quit(1 if failures > 0 else 0)
