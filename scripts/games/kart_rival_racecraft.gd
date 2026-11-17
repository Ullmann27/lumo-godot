extends RefCounted
## Local, deterministic driving decisions. No place, player lead or race outcome
## enters the speed policy: rivals win by road awareness and their actual kart.
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const LANES: Array[float] = [-3.4, -2.55, -1.7, -0.85, 0.0, 0.85, 1.7, 2.55, 3.4]
const STYLES: Array[Dictionary] = [
	{"id": "precise", "clearance": 1.85, "line": 0.65, "corner": 1.02},
	{"id": "attacker", "clearance": 1.65, "line": 0.85, "corner": 1.05},
	{"id": "patient", "clearance": 2.10, "line": 0.40, "corner": 0.93},
	{"id": "flow", "clearance": 1.80, "line": 0.95, "corner": 1.00},
	{"id": "defender", "clearance": 1.95, "line": 0.50, "corner": 0.97},
]
static var _kart_factors: Dictionary = {}


static func style(index: int) -> Dictionary:
	return STYLES[posmod(index, STYLES.size())]


static func factors(kart_id: String) -> Dictionary:
	if not _kart_factors.has(kart_id):
		_kart_factors[kart_id] = FLEET.multipliers(
			FLEET.base_stats(kart_id), FLEET.entry(kart_id).traits
		)
	return _kart_factors[kart_id]


static func cruise_speed(kart_id: String, rules: Dictionary) -> float:
	return POWERTRAIN.top_speed(factors(kart_id), float(rules.speed)) * float(rules.rival)


## Signed horizontal curvature over several real road samples, in radians/m.
## The largest upcoming bend is used; a tight bend cannot hide behind an S turn.
static func curvature(world, road_distance: float) -> float:
	var previous: Vector3 = world.forward(road_distance)
	var previous_offset: float = 0.0
	var sharpest: float = 0.0
	for offset in [8.0, 20.0, 36.0]:
		var ahead: Vector3 = world.forward(road_distance + offset)
		var turn: float = (
			angle_difference(atan2(previous.x, previous.z), atan2(ahead.x, ahead.z))
			/ (offset - previous_offset)
		)
		if absf(turn) > absf(sharpest):
			sharpest = turn
		previous = ahead
		previous_offset = offset
	return sharpest


static func corner_speed(bend: float, difficulty: String, kart_id: String, index: int) -> float:
	if absf(bend) < 0.0001:
		return INF
	var grip: float = 17.0 if difficulty == "pro" else 12.5 if difficulty == "flott" else 8.0
	grip *= POWERTRAIN.DYNAMICS_SCALE
	grip *= float(factors(kart_id).grip) * float(style(index).corner)
	return maxf(7.0, sqrt(grip / absf(bend)))


## Traffic entries are Vector3(forward metres, lateral metres, speed m/s).
## Obstacles have speed zero. Every racer, including the player, is evaluated
## by the same geometry. Cars on another stacked deck are filtered by caller.
static func choose_lane(
	current: float, preferred: float, traffic: PackedVector3Array, look_ahead: float, index: int
) -> float:
	var best: float = clampf(preferred, -3.4, 3.4)
	var best_cost: float = _lane_cost(best, current, preferred, traffic, look_ahead, index)
	for candidate in LANES:
		var cost: float = _lane_cost(candidate, current, preferred, traffic, look_ahead, index)
		if cost < best_cost - 0.001:
			best = candidate
			best_cost = cost
	return best


static func _lane_cost(
	candidate: float,
	current: float,
	preferred: float,
	traffic: PackedVector3Array,
	look_ahead: float,
	index: int
) -> float:
	var cost: float = absf(candidate - preferred) * 0.26 + absf(candidate - current) * 0.12
	var clearance: float = float(style(index).clearance)
	for obstacle in traffic:
		if obstacle.x < -4.0 or obstacle.x > look_ahead:
			continue
		# Account for the lane-change path, not just its final lane. A rival at
		# our shoulder cannot be crossed while targeting an apparently free lane.
		var lane_at_contact: float = lerpf(current, candidate, clampf(obstacle.x / 9.0, 0.0, 1.0))
		var separation: float = minf(
			absf(candidate - obstacle.y), absf(lane_at_contact - obstacle.y)
		)
		if separation < clearance:
			cost += (clearance - separation) * 22.0 / maxf(absf(obstacle.x), 2.0)
	return cost


static func traffic_speed(current: float, traffic: PackedVector3Array, desired: float) -> float:
	var limit: float = desired
	for obstacle in traffic:
		if obstacle.x <= 0.0 or absf(obstacle.y - current) >= 1.5:
			continue
		# Brake while the overtake is still taking shape. The cap permits a
		# smooth approach but reaches the lead car's speed at a two-metre gap.
		var closing: float = sqrt(2.0 * 8.0 * maxf(0.0, obstacle.x - 2.0))
		limit = minf(limit, maxf(0.0, obstacle.z) + closing)
	return limit


## Braking behind a stationary racer must not prevent an already chosen safe
## pass forever. Turn toward the free lane first, then creep through checked
## physical space; never add progress or displace the kart sideways directly.
static func manoeuvre_speed(
	current: float,
	target: float,
	traffic: PackedVector3Array,
	speed: float,
	direction: Vector2,
	delta: float
) -> float:
	if speed >= 2.0 or absf(target - current) < 0.6:
		return speed
	if direction.y * signf(target - current) < 0.75:
		return speed
	var step: Vector2 = direction * 2.0 * delta
	for obstacle in traffic:
		var separation := Vector2(obstacle.x, obstacle.y - current)
		if (separation - step).length() < 1.65:
			return speed
	return 2.0


static func may_boost(
	bend: float,
	heading_error: float,
	current: float,
	traffic: PackedVector3Array,
	cruise: float,
	precision_ahead: bool,
	stunned: bool
) -> bool:
	if precision_ahead or stunned or absf(heading_error) > 0.30 or absf(bend) > 0.012:
		return false
	for obstacle in traffic:
		if obstacle.x > 0.0 and obstacle.x < cruise * 1.6 and absf(obstacle.y - current) < 1.8:
			return false
	return true
