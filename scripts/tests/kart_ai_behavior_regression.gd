extends SceneTree
## Rivals never teleport, never rubber-band, and the three difficulties stay ordered.
const STEP: float = 1.0 / 60.0
## At 60 Hz even Sternen-Profi travels ~0.4 m plus a recover slide of similar size.
## A reset_transform snap from several metres off the road exceeds this cap.
const MAX_FRAME_DELTA_M: float = 1.50
const SIM_SECONDS: float = 8.0

var game


func _initialize() -> void:
	call_deferred("_run")


func _start(difficulty: String) -> void:
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": difficulty,
		}
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


func _snapshot() -> Dictionary:
	var transforms: Array[Transform3D] = []
	var distances: Array[float] = []
	var headings: Array[float] = []
	var lanes: Array[float] = []
	for i in range(game.opponents.size()):
		transforms.append(game.opponents[i].transform)
		distances.append(game.opponent_distances[i])
		headings.append(game.opponent_headings[i])
		lanes.append(game.opponent_lanes[i])
	return {
		"transforms": transforms,
		"distances": distances,
		"headings": headings,
		"lanes": lanes,
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
	assert(game.opponents.size() >= 1, "Race must spawn rivals to measure AI motion")

	var baseline: Dictionary = _snapshot()
	# Push the lead rival several metres off the road: the old code snapped back
	# with reset_transform, which this cap must reject.
	var sampled: Dictionary = game.world.sample_road(
		game.opponents[0].position, fposmod(game.opponent_distances[0], game.track_length)
	)
	game.opponents[0].position += (sampled.basis as Basis).x * 8.0
	var recover_delta: float = _max_frame_delta(180)
	assert(
		recover_delta <= MAX_FRAME_DELTA_M,
		"AI must recover without teleporting (max frame delta %.3f m > %.2f m)"
		% [recover_delta, MAX_FRAME_DELTA_M]
	)
	print("[KartAI] off-road recover max frame delta: %.3f m" % recover_delta)

	_restore(baseline)
	var cruise_delta: float = _max_frame_delta(180)
	assert(
		cruise_delta <= MAX_FRAME_DELTA_M,
		"AI cruise must not teleport (max frame delta %.3f m > %.2f m)"
		% [cruise_delta, MAX_FRAME_DELTA_M]
	)
	print("[KartAI] cruise max frame delta: %.3f m" % cruise_delta)

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
	assert(
		absf(travel_ahead - travel_behind) <= 0.45,
		"No rubber-banding: ahead travel %.3f m vs behind travel %.3f m"
		% [travel_ahead, travel_behind]
	)
	print(
		"[KartAI] rubber-band check: ahead %.3f m, behind %.3f m (diff %.3f m)"
		% [travel_ahead, travel_behind, absf(travel_ahead - travel_behind)]
	)

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
		for _frame in range(frames):
			game._drive_opponents(STEP)
			error_sum += absf(game.opponent_lanes[0] - assigned)
		progress[difficulty] = game.opponent_distances[0] - start
		mean_error[difficulty] = error_sum / float(frames)
		print(
			"[KartAI] %s: +%.2f m in %.1f s, mean |lateral-line| %.3f m"
			% [difficulty, progress[difficulty], SIM_SECONDS, mean_error[difficulty]]
		)

	assert(
		float(progress["gemuetlich"]) < float(progress["flott"]),
		"Entdecken must cover less ground than Abenteuer (%.2f vs %.2f)"
		% [progress["gemuetlich"], progress["flott"]]
	)
	assert(
		float(progress["flott"]) < float(progress["pro"]),
		"Abenteuer must cover less ground than Sternen-Profi (%.2f vs %.2f)"
		% [progress["flott"], progress["pro"]]
	)
	# Inverse of progress over a fixed window is the projected lap-time order.
	var estimated_lap: Dictionary = {}
	for difficulty in progress.keys():
		estimated_lap[difficulty] = (
			game.track_length * SIM_SECONDS / maxf(float(progress[difficulty]), 0.001)
		)
	assert(float(estimated_lap["gemuetlich"]) > float(estimated_lap["flott"]))
	assert(float(estimated_lap["flott"]) > float(estimated_lap["pro"]))
	print(
		"[KartAI] estimated lap times: Entdecken %.2f s, Abenteuer %.2f s, Sternen-Profi %.2f s"
		% [estimated_lap["gemuetlich"], estimated_lap["flott"], estimated_lap["pro"]]
	)
	assert(
		float(mean_error["gemuetlich"]) > float(mean_error["flott"]),
		"Entdecken must wander more than Abenteuer (%.3f vs %.3f)"
		% [mean_error["gemuetlich"], mean_error["flott"]]
	)
	assert(
		float(mean_error["flott"]) > float(mean_error["pro"]),
		"Abenteuer must wander more than Sternen-Profi (%.3f vs %.3f)"
		% [mean_error["flott"], mean_error["pro"]]
	)

	print("[KartAI] PASS: no teleport, no rubber-band, difficulty order holds")
	game.queue_free()
	quit(0)
