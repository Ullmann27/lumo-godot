extends SceneTree
## Real world plans and real player flights across the added continuous-road
## kickers. Initial setup sets a launch pace; subsequent motion is the engine's.
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const LASSO = preload("res://scripts/games/kart_roadside_lasso.gd")
const WORLD = preload("res://scripts/games/kart_world.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const STEP: float = 1.0 / 60.0
var failures: int = 0
var checks: int = 0
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[RoadsideAction] " + label)


func _run() -> void:
	var world = WORLD.new()
	root.add_child(world)
	world.build(true, "sonnenhafen", true)
	var extras: Array[Dictionary] = []
	for ramp in world.action.kickers:
		if bool(ramp.get("action_expansion", false)):
			extras.append(ramp)
	_check(extras.size() == 2, "Sonnenhafen receives two additional actual ramp surfaces")
	for ramp in extras:
		_check(world.ramp_height(float(ramp.start) + 6.0) > 0.7, "Physical ramp matches its rising deck")
		for offset in range(1, 64):
			_check(not world.in_gap(float(ramp.take_off) + offset), "Added ramp landing corridor has continuous road")
	var encounters: Array[Dictionary] = LASSO.plan(world)
	_check(encounters.size() == 2, "Two independently placed roadside crews fit the harbour course")
	for entry in encounters:
		_check(absf(float(entry.lateral)) > LASSO.RULES.HALF_WIDTH + 0.5, "Central driving lane remains clear")
		for ramp in world.action.kickers:
			_check(float(entry.distance) < float(ramp.start) - 80.0 or float(entry.distance) > float(ramp.take_off) + 80.0, "Lasso never catches a ramp approach or landing")
	var geometry = LASSO.new()
	world.add_child(geometry)
	geometry.setup(world)
	_check(geometry.views.size() == encounters.size(), "Every playable hazard has a real visual crew and target")
	for view in geometry.views:
		_check(view.actor.animal == "badger" and is_instance_valid(view.marker.mesh), "Existing character geometry and a physical-position warning marker are present")
	world.free()
	var fast_course := {"kickers": [{"start": 90.0, "take_off": 100.0}], "gates": [{"distance": 100.0}]}
	_check(not ACTION.kicker_crossed(fast_course, 99.0, 108.0).is_empty(), "Fast frame cannot tunnel through a ramp lip")
	_check(ACTION.gates_crossed(fast_course, 99.0, 108.0).size() == 1, "Fast frame cannot skip a slalom plane")
	_check(ACTION.kicker_crossed(fast_course, 95.0, 140.0).is_empty(), "A rescue cannot manufacture a ramp jump")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race({"mode": "training", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"})
	game._end_preview()
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	await _live_encounter()
	for ramp in extras:
		for pace in [20.5, 48.0, 70.0]:
			await _fly(ramp, pace)
	game.abandoned = true
	game.queue_free()
	await process_frame
	if failures == 0:
		print("[RoadsideAction] PASS: %d assertions; two new drivable ramps at 20.5/48/70 m/s, visible fair encounter plans" % checks)
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)


func _live_encounter() -> void:
	var encounter = game.world.get_node_or_null("RoadsideLasso")
	_check(encounter != null, "Production race creates and owns the roadside module")
	if encounter == null:
		return
	var target_lane: float = float(encounter.layout[0].lateral)
	var at: float = float(encounter.layout[0].distance) - 75.0
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at, target_lane)
	game.player_heading = game._heading(at)
	game.player.rotation = Vector3(0.0, game.player_heading, 0.0)
	game.speed = 30.0
	game.physical_velocity = Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * 30.0
	game.kart_factors = {"speed": 30.0 / POWERTRAIN.top_speed({}), "turn": 2.0, "grip": 2.0}
	for frame in range(300):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 10.0, target_lane)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.0, -1, 1)
		game._physics_process(STEP)
		if encounter.catches > 0:
			break
		if frame % 30 == 29:
			await process_frame
	_check(encounter.catches == 1, "Production adapter catches a real driven lane crossing")
	_check(game.speed < 25.0 and float(game.player.get_meta(LASSO.SPEED_META, 1.0)) < 1.0, "Catch changes actual player velocity and drive target")
	_check(encounter.views[0].marker.visible and encounter.views[0].beams[0].visible, "Actual catch exposes the target and connecting rope geometry")
	await _capture("lasso-catch")
	var stopped_clock: float = encounter.clock
	game.paused = true
	game._physics_process(1.0)
	_check(encounter.clock == stopped_clock, "Controller pause freezes encounter animation and rules")
	game.paused = false
	game.boost_time = 1.0
	game._physics_process(STEP)
	_check(float(game.player.get_meta(LASSO.SPEED_META, 0.0)) == 1.0, "Actual boost immediately restores the drive target")


func _fly(ramp: Dictionary, pace: float) -> void:
	var at: float = float(ramp.start) - 3.0
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at, 0.0)
	game.player_heading = game._heading(at)
	game.player.rotation = Vector3(0.0, game.player_heading, 0.0)
	game.speed = pace
	game.physical_velocity = Vector3(-sin(game.player_heading), 0.0, -cos(game.player_heading)) * pace
	game.kart_factors = {"speed": pace / POWERTRAIN.top_speed({}), "turn": 2.0, "grip": 2.0}
	game.airborne = false
	game.boost_time = 0.0
	game.shield_time = 0.0
	game.precision_kicker = {}
	game.steering = 0.0
	var initial_landings: int = game.landing_count
	var initial_resets: int = game.reset_count
	var initial_jumps: int = game.action_kicker_jumps
	var flew: bool = false
	var peak: float = 0.0
	var captured: bool = false
	for frame in range(220):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + maxf(10.0, pace * 0.30))
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.0, -1.0, 1.0)
		game._physics_process(STEP)
		flew = flew or game.airborne
		if game.airborne:
			peak = maxf(peak, game.player.position.y - float(game.world.sample_road(game.player.position, game.previous_road_distance).height))
			if not captured and game.air_time > 0.15:
				await _capture("ramp-%d-speed-%d" % [int(ramp.start), int(pace)])
				captured = true
		if flew and not game.airborne:
			break
		if frame % 30 == 29:
			await process_frame
	_check(flew and game.action_kicker_jumps == initial_jumps + 1, "New ramp causes an actual take-off at %s m/s" % pace)
	_check(game.landing_count == initial_landings + 1 and not game.airborne, "Flight lands physically at %s m/s" % pace)
	_check(game.reset_count == initial_resets, "Flight needs no rescue at %s m/s" % pace)
	_check(peak > 1.5, "Flight has a visible airborne arc at %s m/s" % pace)
	print("[RoadsideActionFlight] ramp=%.1f pace=%.1f peak=%.2f landings=%d resets=%d" % [float(ramp.start), pace, peak, game.landing_count - initial_landings, game.reset_count - initial_resets])


func _capture(label: String) -> void:
	var output: String = OS.get_environment("LUMO_ACTION_CAPTURE_DIR")
	if output.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "Requested visual capture requires an actual rendering server")
		return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "Actual renderer capture: " + label)
