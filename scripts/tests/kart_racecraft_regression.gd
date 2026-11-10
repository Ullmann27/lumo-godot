extends SceneTree
## Decision invariants plus actual production movement past a real course cone.
const CRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const STEP: float = 1.0 / 60.0
var game
var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[KartRacecraft] " + message)


func _run() -> void:
	var styles: Dictionary = {}
	for i in range(5):
		styles[CRAFT.style(i).id] = true
	_check(styles.size() == 5, "Five rivals must have distinct racecraft styles")
	var free := PackedVector3Array()
	var blocked := PackedVector3Array([Vector3(12.0, 0.0, 4.0)])
	var lane: float = CRAFT.choose_lane(0.0, 0.0, blocked, 26.0, 1)
	_check(absf(lane) >= 1.65, "A slower racer ahead must cause a real passing line")
	var mirrored := PackedVector3Array([Vector3(12.0, -2.0, 4.0)])
	_check(
		CRAFT.choose_lane(-2.0, -2.0, mirrored, 26.0, 1) > -0.5,
		"Passing must respect the road edge"
	)
	var boxed := PackedVector3Array([Vector3(2.0, 0.0, 4.0)])
	_check(
		CRAFT.traffic_speed(0.0, boxed, 25.0) <= 4.0, "Blocked rival must brake to traffic speed"
	)
	_check(
		CRAFT.traffic_speed(3.0, boxed, 25.0) == 25.0,
		"Traffic in a free adjacent lane must not slow us"
	)
	_check(
		CRAFT.may_boost(0.0, 0.0, 0.0, free, 22.0, false, false),
		"A leader may boost on a safe straight"
	)
	_check(
		not CRAFT.may_boost(0.0, 0.0, 0.0, blocked, 22.0, false, false),
		"Do not boost into a slower kart"
	)
	_check(
		not CRAFT.may_boost(0.04, 0.0, 0.0, free, 22.0, false, false), "Save boost for a safe exit"
	)
	_check(
		not CRAFT.may_boost(0.0, 0.0, 0.0, free, 22.0, true, false),
		"Do not overshoot a precision landing"
	)
	var previous: float = 0.0
	for level in ["gemuetlich", "flott", "pro"]:
		var rules: Dictionary = CATALOG.entry(CATALOG.DIFFICULTIES, level)
		var cruise: float = CRAFT.cruise_speed("comet", rules)
		_check(cruise > previous, "Cruise difficulty ordering")
		_check(
			CRAFT.corner_speed(0.08, level, "comet", 0) < cruise,
			"A genuinely tight turn requires braking"
		)
		previous = cruise
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "pro"
		}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	await process_frame
	for i in range(game.opponents.size() - 1, 0, -1):
		game.opponents[i].queue_free()
	game.opponents.resize(1)
	game.item_box_distances.clear()
	game.world.action_obstacles.clear()
	# Choose a measured straight in the actual road, not an invented test map.
	var start: float = 30.0
	var best: float = INF
	for d in range(30, 450, 5):
		var bend: float = absf(CRAFT.curvature(game.world, float(d)))
		if bend < best:
			best = bend
			start = float(d)
	var obstacle: Vector3 = game.world.position_at(start + 18.0, 0.0)
	game.world.action_obstacles.append(obstacle)
	game.opponents[0].transform = game.world.reset_transform(start, 0.0)
	game.opponent_distances[0] = start
	game.opponent_lanes[0] = 0.0
	game.opponent_headings[0] = game._heading(start)
	game.opponents[0].set_motion(20.0, 0.0, false, false)
	game.distance = start + 300.0
	game.player.transform = game.world.reset_transform(game.distance, 0.0)
	game.speed = 0.0
	var clearance: float = INF
	for _frame in range(180):
		game.elapsed += STEP
		game._drive_opponents(STEP)
		var gap: Vector3 = game.opponents[0].position - obstacle
		gap.y = 0.0
		clearance = minf(clearance, gap.length())
	_check(
		game.opponent_distances[0] > start + 25.0,
		"Production rival must pass the obstacle, not stop forever"
	)
	_check(clearance > 1.2, "Production rival must actually avoid the cone: %.3fm" % clearance)
	print(
		(
			"[KartRacecraft] production cone clearance %.3fm; travelled %.2fm"
			% [clearance, game.opponent_distances[0] - start]
		)
	)
	# Leadership never disables an earned item. Place the same physical scene
	# far from traffic, then put the player far behind without changing road data.
	game.world.action_obstacles.clear()
	game.opponents[0].transform = game.world.reset_transform(start, 0.0)
	game.opponent_distances[0] = start
	game.opponent_headings[0] = game._heading(start)
	game.distance = start - 100.0
	game.player.transform = game.world.reset_transform(game.distance, 0.0)
	game.opponent_items[0] = "boost"
	game.opponent_boost_times[0] = 0.0
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, STEP)
	_check(
		game.opponent_boost_times[0] > 0.0,
		"Production leader must use its earned safe-straight boost"
	)
	game.abandoned = true
	game.queue_free()
	await process_frame
	if not failed:
		print(
			"[KartRacecraft] PASS: styles, traffic, curve braking, safe boost and real cone overtake"
		)
	quit(1 if failed else 0)
