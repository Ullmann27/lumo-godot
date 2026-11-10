extends RefCounted
## Real rival take-off/flight/landing using the player's ramp and gravity model.
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const STATE_KEY: StringName = &"lumo_ballistic_flight"
var active: bool = true
var kicker: Dictionary = {}
var speed: float = 0.0
var vertical_speed: float = 0.0
var elapsed: float = 0.0
var launch_lane: float = 0.0
var entry_progress: float = 0.0


static func clear(game) -> void:
	for rival in game.opponents:
		if rival.has_meta(STATE_KEY):
			rival.remove_meta(STATE_KEY)
		if rival.has_meta(&"lumo_physical_loop"):
			rival.remove_meta(&"lumo_physical_loop")
		rival.set_meta(&"racecraft_drift_charge", 0.0)


static func try_launch(
	game, index: int, before: Dictionary, after: Dictionary, momentum: float
) -> bool:
	var ramp: Dictionary = ACTION.kicker_crossed(
		game.world.action, float(before.distance), float(after.distance)
	)
	var jump: Dictionary = game.world.jump
	if (
		ramp.is_empty()
		and not jump.is_empty()
		and float(before.distance) >= float(jump.ramp_start)
		and float(before.distance) < float(jump.take_off)
		and float(after.distance) >= float(jump.take_off)
		and float(after.distance) < float(jump.gap_end)
	):
		ramp = {
			"start": jump.ramp_start,
			"take_off": jump.take_off,
			"height": jump.height,
			"angle": jump.angle,
			"flight_gravity": game.JUMP_GRAVITY,
			"max_lift": game.JUMP_MAX_LIFT
		}
	if ramp.is_empty():
		return false
	var rival = game.opponents[index]
	var state = load("res://scripts/games/kart_rival_flight.gd").new()
	state.kicker = ramp
	state.speed = momentum
	state.vertical_speed = PRECISION.launch_vertical(momentum, ramp) if momentum > 6.0 else 0.0
	state.launch_lane = float(after.lateral)
	state.entry_progress = game.opponent_distances[index]
	rival.set_meta(STATE_KEY, state)
	rival.set_meta(&"racecraft_drift_charge", 0.0)
	rival.position.y = float(after.height) + float(ramp.height) + 0.035
	rival.set_motion(momentum, 0.0, false, false)
	_set_pitch(rival, after, state.vertical_speed)
	return true


static func update(game, index: int, delta: float) -> bool:
	var rival = game.opponents[index]
	if not rival.has_meta(STATE_KEY):
		return false
	var state = rival.get_meta(STATE_KEY)
	if not state.active:
		return false
	game._update_rival_item_tactics(index, game.player.position - rival.position, delta)
	game.opponent_stuns[index] = maxf(0.0, game.opponent_stuns[index] - delta)
	var local: float = fposmod(game.opponent_distances[index], game.track_length)
	var target: Vector3 = game.world.position_at(local + 12.0, state.launch_lane)
	var heading: float = atan2(-(target.x - rival.position.x), -(target.z - rival.position.z))
	game.opponent_headings[index] += clampf(
		angle_difference(game.opponent_headings[index], heading), -0.65 * delta, 0.65 * delta
	)
	var forward := Vector3(
		-sin(game.opponent_headings[index]), 0.0, -cos(game.opponent_headings[index])
	)
	var velocity: Vector3 = forward * state.speed
	var projected: Dictionary = game.world.sample_road(rival.position + velocity * delta, local)
	if bool(state.kicker.get("precision_jump", false)):
		# Same velocity-only two-metre air-steering envelope as the player.
		var shift: float = float(projected.lateral) - state.launch_lane
		var excess: float = (
			shift - clampf(shift, -game.PRECISION_AIR_LATERAL_M, game.PRECISION_AIR_LATERAL_M)
		)
		if absf(excess) > 0.0001:
			velocity -= (projected.basis as Basis).x * (excess / maxf(delta, 0.0001))
	rival.position += velocity * delta
	state.vertical_speed -= float(state.kicker.flight_gravity) * delta
	rival.position.y += state.vertical_speed * delta
	state.elapsed += delta
	var road: Dictionary = game.world.sample_road(rival.position, local)
	var travel: float = (
		fposmod(float(road.distance) - local + game.track_length * 0.5, game.track_length)
		- game.track_length * 0.5
	)
	game.opponent_distances[index] += travel
	game.opponent_lanes[index] = float(road.lateral)
	var ground: float = float(road.height) + 0.035 + game.world.ramp_height(float(road.distance))
	var in_gap: bool = game.world.in_gap(float(road.distance))
	var precision: bool = bool(state.kicker.get("precision_jump", false))
	var missed_edge: bool = precision and not in_gap and rival.position.y < ground - 0.5
	if (in_gap and rival.position.y < ground - 2.5) or missed_edge:
		var recovery: float = game.world.gap_exit_distance(float(road.distance))
		game.opponent_distances[index] += fposmod(
			recovery - float(road.distance), game.track_length
		)
		game.opponent_headings[index] = game._heading(recovery)
		game.opponent_lanes[index] = 0.0
		rival.transform = game.world.reset_transform(recovery)
		game.opponent_stuns[index] = maxf(game.opponent_stuns[index], 1.0)
		state.active = false
		rival.set_meta(&"lumo_flight_result", PRECISION.LANDING_SHORT)
		rival.set_meta(&"lumo_flight_rescues", int(rival.get_meta(&"lumo_flight_rescues", 0)) + 1)
		rival.set_motion(8.0, 0.0, false, false)
		return true
	if not in_gap and rival.position.y <= ground:
		var flown: float = fposmod(
			float(road.distance) - float(state.kicker.take_off), game.track_length
		)
		var result: String = (
			PRECISION.classify_landing(flown, state.kicker) if precision else "landed"
		)
		state.active = false
		rival.position.y = ground
		rival.set_meta(&"lumo_flight_result", result)
		rival.set_meta(&"lumo_flight_distance", flown)
		rival.set_meta(&"lumo_flight_landings", int(rival.get_meta(&"lumo_flight_landings", 0)) + 1)
		if result == PRECISION.LANDING_LONG:
			state.speed *= 0.6
			game.opponent_stuns[index] = maxf(game.opponent_stuns[index], 0.45)
		elif result == PRECISION.LANDING_ZONE or state.elapsed > 0.35:
			game.opponent_boost_times[index] = maxf(game.opponent_boost_times[index], 1.2)
		rival.set_motion(state.speed, 0.0, false, false)
		_set_pitch(rival, road, 0.0)
		return true
	rival.set_motion(state.speed, 0.0, false, false)
	_set_pitch(rival, road, state.vertical_speed)
	return true


static func _set_pitch(rival, road: Dictionary, vertical: float) -> void:
	var basis: Basis = road.basis
	rival.basis = basis.rotated(basis.x, clampf(vertical * 0.05, -0.32, 0.32)).orthonormalized()


static func save_positions(game, config: ConfigFile) -> void:
	var positions: Array = config.get_value("race", "opponent_positions", []).duplicate()
	var distances: Array = config.get_value("race", "opponent_distances", []).duplicate()
	var lanes: Array = config.get_value("race", "opponent_lanes", []).duplicate()
	var headings: Array = config.get_value("race", "opponent_headings", []).duplicate()
	for index in range(game.opponents.size()):
		var rival = game.opponents[index]
		if not rival.has_meta(STATE_KEY):
			continue
		var state = rival.get_meta(STATE_KEY)
		if not state.active:
			continue
		var start: float = float(state.kicker.start)
		var current: float = fposmod(game.opponent_distances[index], game.track_length)
		distances[index] = (
			game.opponent_distances[index] - fposmod(current - start, game.track_length)
		)
		lanes[index] = state.launch_lane
		headings[index] = game._heading(start)
		positions[index] = game.world.reset_transform(start, state.launch_lane).origin
	config.set_value("race", "opponent_positions", positions)
	config.set_value("race", "opponent_distances", distances)
	config.set_value("race", "opponent_lanes", lanes)
	config.set_value("race", "opponent_headings", headings)
