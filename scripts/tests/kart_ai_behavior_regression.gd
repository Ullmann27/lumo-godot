extends SceneTree
## Rivals never teleport, never rubber-band, and the three difficulties stay ordered.
const STEP: float = 1.0 / 60.0
const CRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
## At doubled pace even an earned extreme turbo remains below this physical cap.
## A reset_transform snap from several metres off the road exceeds this cap.
const MAX_FRAME_DELTA_M: float = 1.50
const SIM_SECONDS: float = 8.0

var game
var failed: bool = false


func _check(ok: bool, message: String = "") -> void:
	if ok:
		return
	failed = true
	push_error("[KartAI] FAIL: " + (message if not message.is_empty() else "assertion failed"))
	quit(1)


func _stop_if_failed() -> bool:
	if failed:
		return true
	return false


func _initialize() -> void:
	call_deferred("_run")


func _start(difficulty: String) -> void:
	(
		game
		. _start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": "sonnenhafen",
				"difficulty": difficulty,
			}
		)
	)
	if game.has_method("_end_preview"):
		game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.speed = 0.0
	await process_frame


func _restore(snapshot: Dictionary) -> void:
	for i in range(game.opponents.size()):
		game.opponents[i].transform = snapshot.transforms[i]
		game.opponent_distances[i] = snapshot.distances[i]
		game.opponent_headings[i] = snapshot.headings[i]
		game.opponent_lanes[i] = snapshot.lanes[i]
		game.opponent_stuns[i] = 0.0
		game.opponent_items[i] = ""
		game.opponent_item_cooldowns[i] = 0.0
		game.opponent_boost_times[i] = 0.0
		game.opponent_shield_times[i] = 0.0
		game.opponent_pulse_warning_times[i] = 0.0
		game.opponents[i].set_motion(snapshot.motion_speeds[i], 0.0, false, false)
		game.opponents[i].set_meta("racecraft_drift_charge", snapshot.drift_charges[i])


func _snapshot() -> Dictionary:
	var transforms: Array[Transform3D] = []
	var distances: Array[float] = []
	var headings: Array[float] = []
	var lanes: Array[float] = []
	var motion_speeds: Array[float] = []
	var drift_charges: Array[float] = []
	for i in range(game.opponents.size()):
		transforms.append(game.opponents[i].transform)
		distances.append(game.opponent_distances[i])
		headings.append(game.opponent_headings[i])
		lanes.append(game.opponent_lanes[i])
		motion_speeds.append(game.opponents[i].motion_speed)
		drift_charges.append(float(game.opponents[i].get_meta("racecraft_drift_charge", 0.0)))
	return {
		"transforms": transforms,
		"distances": distances,
		"headings": headings,
		"lanes": lanes,
		"motion_speeds": motion_speeds,
		"drift_charges": drift_charges,
	}


func _max_frame_delta(frames: int) -> float:
	var previous: Vector3 = game.opponents[0].position
	var widest: float = 0.0
	for _frame in range(frames):
		game._drive_opponents(STEP)
		var now: Vector3 = game.opponents[0].position
		widest = maxf(widest, previous.distance_to(now))
		previous = now
	return widest


func _run() -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await _start("flott")
	_check(game.opponents.size() >= 1, "Race must spawn rivals to measure AI motion")

	var baseline: Dictionary = _snapshot()
	# Push the lead rival several metres off the road: the old code snapped back
	# with reset_transform, which this cap must reject.
	var sampled: Dictionary = game.world.sample_road(
		game.opponents[0].position, fposmod(game.opponent_distances[0], game.track_length)
	)
	game.opponents[0].position += (sampled.basis as Basis).x * 8.0
	var recover_delta: float = _max_frame_delta(180)
	_check(
		recover_delta <= MAX_FRAME_DELTA_M,
		(
			"AI must recover without teleporting (max frame delta %.3f m > %.2f m)"
			% [recover_delta, MAX_FRAME_DELTA_M]
		)
	)
	print("[KartAI] off-road recover max frame delta: %.3f m" % recover_delta)
	if failed:
		return

	_restore(baseline)
	var cruise_delta: float = _max_frame_delta(180)
	_check(
		cruise_delta <= MAX_FRAME_DELTA_M,
		(
			"AI cruise must not teleport (max frame delta %.3f m > %.2f m)"
			% [cruise_delta, MAX_FRAME_DELTA_M]
		)
	)
	print("[KartAI] cruise max frame delta: %.3f m" % cruise_delta)
	if failed:
		return

	# No rubber-banding: the same stretch at the same difficulty must yield the
	# same travel whether the player is far ahead or far behind. Place the field
	# far enough along the course that "80 m behind" does not clamp to 0.
	_restore(baseline)
	var rb_start: float = game.opponent_distances[0] + 200.0
	for i in range(game.opponents.size()):
		var placed: float = rb_start + float(i) * 2.0
		game.opponent_distances[i] = placed
		game.opponent_lanes[i] = -2.8 + float(i) * 1.35
		game.opponents[i].transform = game.world.reset_transform(placed, game.opponent_lanes[i])
		game.opponent_headings[i] = game._heading(placed)
	var rb: Dictionary = _snapshot()
	var saved_boxes: Array = game.item_box_distances.duplicate()
	game.item_box_distances.clear()

	game.distance = rb.distances[0] + 80.0
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(game.distance, 0.0)
	var before_ahead: float = game.opponent_distances[0]
	for _frame in range(45):
		game._drive_opponents(STEP)
	var travel_ahead: float = game.opponent_distances[0] - before_ahead

	_restore(rb)
	game.distance = rb.distances[0] - 80.0
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(game.distance, 0.0)
	var before_behind: float = game.opponent_distances[0]
	for _frame in range(45):
		game._drive_opponents(STEP)
	var travel_behind: float = game.opponent_distances[0] - before_behind
	game.item_box_distances = saved_boxes
	_check(
		absf(travel_ahead - travel_behind) <= 0.45,
		(
			"No rubber-banding: ahead travel %.3f m vs behind travel %.3f m"
			% [travel_ahead, travel_behind]
		)
	)
	print(
		(
			"[KartAI] rubber-band check: ahead %.3f m, behind %.3f m (diff %.3f m)"
			% [travel_ahead, travel_behind, absf(travel_ahead - travel_behind)]
		)
	)
	if failed:
		return

	var progress: Dictionary = {}
	var mean_error: Dictionary = {}
	var frames: int = int(SIM_SECONDS / STEP)
	for difficulty in ["gemuetlich", "flott", "pro"]:
		game.difficulty = difficulty
		_restore(baseline)
		game.auto_gas = false
		game.speed = 0.0
		game.distance = baseline.distances[0]
		game.player.transform = game.world.reset_transform(game.distance, 0.0)
		var start: float = game.opponent_distances[0]
		var error_sum: float = 0.0
		var assigned: float = -2.8
		game.elapsed = 0.0
		for _frame in range(frames):
			# Production ticks elapsed in _physics_process before _drive_opponents.
			# Direct calls must do the same or wobble/mistakes stay frozen.
			game.elapsed += STEP
			game._drive_opponents(STEP)
			error_sum += absf(game.opponent_lanes[0] - assigned)
		progress[difficulty] = game.opponent_distances[0] - start
		mean_error[difficulty] = error_sum / float(frames)
		print(
			(
				"[KartAI] %s: +%.2f m in %.1f s, mean |lateral-line| %.3f m"
				% [difficulty, progress[difficulty], SIM_SECONDS, mean_error[difficulty]]
			)
		)

	_check(
		float(progress["gemuetlich"]) < float(progress["flott"]),
		(
			"Entdecken must cover less ground than Abenteuer (%.2f vs %.2f)"
			% [progress["gemuetlich"], progress["flott"]]
		)
	)
	_check(
		float(progress["flott"]) < float(progress["pro"]),
		(
			"Abenteuer must cover less ground than Extrem (%.2f vs %.2f)"
			% [progress["flott"], progress["pro"]]
		)
	)
	# Inverse of progress over a fixed window is the projected lap-time order.
	var estimated_lap: Dictionary = {}
	for difficulty in progress.keys():
		estimated_lap[difficulty] = (
			game.track_length * SIM_SECONDS / maxf(float(progress[difficulty]), 0.001)
		)
	_check(float(estimated_lap["gemuetlich"]) > float(estimated_lap["flott"]))
	_check(float(estimated_lap["flott"]) > float(estimated_lap["pro"]))
	print(
		(
			"[KartAI] estimated lap times: Entdecken %.2f s, Abenteuer %.2f s, Extrem %.2f s"
			% [estimated_lap["gemuetlich"], estimated_lap["flott"], estimated_lap["pro"]]
		)
	)
	# Overtakes and ring pickups are deliberate departures from the grid lane,
	# not driving errors. Compare line keeping over the same actual 50 m road,
	# without traffic or pickups, rather than different sections covered within 8 s race windows.
	var line_error: Dictionary = _measure_unobstructed_line()
	var faster_worst: float = maxf(float(line_error["flott"]), float(line_error["pro"]))
	_check(
		float(line_error["gemuetlich"]) > faster_worst * 1.5,
		(
			"Entdecken must have visibly less precise free-road line keeping (%.3f vs worst faster %.3f)"
			% [line_error["gemuetlich"], faster_worst]
		)
	)

	if failed:
		return
	print("[KartAI] PASS: no teleport, no rubber-band, difficulty order holds")
	game.queue_free()
	quit(0)


func _measure_unobstructed_line() -> Dictionary:
	for i in range(game.opponents.size() - 1, 0, -1):
		game.opponents[i].queue_free()
	game.opponents.resize(1)
	game.item_box_distances.clear()
	game.world.action_obstacles.clear()
	var start: float = 30.0
	var best: float = INF
	# Choose a measured, gentle road corridor before the mandatory stunts.
	for at in range(30, 800, 10):
		var curvature: float = 0.0
		for offset in [0.0, 20.0, 40.0, 60.0]:
			curvature = maxf(curvature, absf(CRAFT.curvature(game.world, float(at) + offset)))
		if curvature < best:
			best = curvature
			start = float(at)
	var errors: Dictionary = {}
	for level in ["gemuetlich", "flott", "pro"]:
		game.difficulty = level
		game.elapsed = 0.0
		game.opponents[0].transform = game.world.reset_transform(start, -2.8)
		game.opponent_distances[0] = start
		game.opponent_lanes[0] = -2.8
		game.opponent_headings[0] = game._heading(start)
		game.opponents[0].set_motion(0.0, 0.0, false, false)
		game.opponents[0].set_meta("racecraft_drift_charge", 0.0)
		game.opponent_items[0] = ""
		game.opponent_boost_times[0] = 0.0
		game.opponent_stuns[0] = 0.0
		game.opponent_pulse_warning_times[0] = 0.0
		game.player.transform = game.world.reset_transform(start, 20.0)
		var total: float = 0.0
		var frames: int = 0
		while game.opponent_distances[0] < start + 50.0 and frames < 600:
			game.elapsed += STEP
			game._drive_opponents(STEP)
			total += absf(game.opponent_lanes[0] + 2.8)
			frames += 1
		_check(frames > 0 and frames < 600, "Free-road 50 m line test must physically finish")
		errors[level] = total / maxf(1.0, float(frames))
	print("[KartAI] same unobstructed 50 m road: ", errors)
	return errors
