extends SceneTree
## Exercise the production camera on actual road geometry; this measures no device FPS.

var game: Variant
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(passed: bool, detail: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("[KartCamera] %s: %s" % ["PASS" if passed else "FAIL", detail])


func _start(track: String) -> void:
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": track,
			"difficulty": "flott"
		}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.speed = 20.0
	game.boost_time = 1.0
	game.reduced_motion = false
	game.set_physics_process(false)
	await process_frame


func _sample(steps: int, duration: float, initial: Vector3, initial_fov: float) -> Dictionary:
	game.camera.position = initial
	game.camera.fov = initial_fov
	for _step in range(steps):
		game._update_camera(duration / float(steps))
	return {"position": game.camera.position, "fov": game.camera.fov}


func _schedule_checks(label: String, target: Vector3, target_fov: float) -> void:
	var initial: Vector3 = target + Vector3(5.0, 3.0, 8.0)
	var initial_fov: float = target_fov - 10.0
	var reference: Dictionary = _sample(12, 0.2, initial, initial_fov)
	for steps in [6, 24]:
		var result: Dictionary = _sample(steps, 0.2, initial, initial_fov)
		var error: float = (result.position as Vector3).distance_to(reference.position)
		_check(error < 0.00005, "%s %d Hz position error %.6f m" % [label, steps * 5, error])
		if label == "chase":
			var fov_error: float = absf(float(result.fov) - float(reference.fov))
			_check(fov_error < 0.0001, "chase %d Hz FOV error %.6f" % [steps * 5, fov_error])
	var hitch: Dictionary = _sample(1, 0.25, initial, initial_fov)
	var remaining: float = (hitch.position as Vector3).distance_to(target)
	_check(remaining > 0.1, "%s 250-ms hitch keeps damping (%.4f m left)" % [label, remaining])
	_check(remaining < initial.distance_to(target), "%s hitch still approaches its target" % label)
	if label == "chase":
		_check(absf(float(hitch.fov) - target_fov) > 0.1, "250-ms hitch does not snap boost FOV")
	var zero: Dictionary = _sample(1, 0.0, initial, initial_fov)
	_check(
		(zero.position as Vector3).is_equal_approx(initial), "%s zero step holds position" % label
	)
	_check(is_equal_approx(float(zero.fov), initial_fov), "%s zero step holds FOV" % label)
	game._update_camera(0.0, true)
	_check(
		game.camera.position.distance_to(target) < 0.00005, "%s explicit snap is immediate" % label
	)
	if label == "chase":
		_check(is_equal_approx(game.camera.fov, target_fov), "chase explicit snap includes FOV")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await _start("sonnenhafen")
	var driving_state: Array = [
		game.distance, game.speed, game.player_heading, game.physical_velocity
	]
	game._update_camera(0.0, true)
	_schedule_checks("chase", game.camera.position, game.camera.fov)
	_check(
		driving_state == [game.distance, game.speed, game.player_heading, game.physical_velocity],
		"camera does not modify driving state"
	)
	game.reduced_motion = true
	game._update_camera(0.0, true)
	var quiet_fov: float = game.camera.fov
	game.boost_time = 0.0
	game._update_camera(0.0, true)
	_check(is_equal_approx(game.camera.fov, quiet_fov), "reduced motion keeps boost FOV steady")
	_check(game.speed_fx.visual_state().visible_count == 0, "reduced motion hides speed streaks")

	await _start("candy_cloud")
	_check(not game.world.loop_layout.is_empty(), "loop probe uses an actual loop course")
	game.loop_state.active = true
	var origin: Vector3 = game.world.position_at(
		float(game.world.loop_layout.start), float(game.world.loop_layout.lane)
	)
	var frame: Basis = game.world.frame(float(game.world.loop_layout.start))
	var loop_target: Vector3 = origin + frame.x * 12.0 + frame.z * 15.0 + Vector3.UP * 11.0
	_schedule_checks("loop", loop_target, game.camera.fov)
	game.loop_state.active = false
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print(
		(
			"[KartCamera] %s: %d checks, %d failures"
			% ["PASS" if failures == 0 else "FAIL", checks, failures]
		)
	)
	quit(0 if failures == 0 else 1)
