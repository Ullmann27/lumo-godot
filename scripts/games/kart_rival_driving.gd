extends RefCounted
## Rival driving craft on top of kart_rival_racecraft (lane choice, traffic):
##   * looking ahead: brake early enough for every corner on the real road
##     ahead (v² = v_corner² + 2·a·d), then accelerate out with the kart's own
##     drivetrain. No more instant speed changes: speed follows the same
##     acceleration and braking limits as the child's kart.
##   * slipstream: on Abenteuer/Extrem a rival tucked in behind another kart
##     charges the same tow boost the child gets (kart_race_rules).
##   * believable small mistakes: at some corners a rival runs a little wide or
##     lifts off. Planned from a per-race seed, so a race replays identically;
##     never next to another kart, never off the road.
##   * Entdecken: a rival that sees the child coming from behind makes room.
## Every rule reads only road geometry and the karts nearby; nothing reads the
## standings, so there is no hidden rubber band.

const CRAFT = preload("res://scripts/games/kart_rival_racecraft.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RACE_RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")

## Sampling of the curvature table (metres) and its centred window.
const TABLE_STEP := 2.0
const BEND_WINDOW := 12.0
## A corner worth a mistake: sustained curvature (rad/m) and spacing (m).
const CORNER_MIN := 0.008
const CORNER_SPACING := 40.0
## Per-level driving character.
##   plan_brake   braking the rival plans with (m/s², kart maximum is 80)
##   horizon      how far ahead it reads the road (m)
##   mistake      chance per corner and lap to make a small mistake
##   wide         how far it runs wide in a mistake (m)
##   slipstream   uses another kart's tow
##   yield        makes room for the child coming from behind
const LEVELS := {
	"gemuetlich":
	{
		"plan_brake": 22.0,
		"horizon": 44.0,
		"mistake": 0.16,
		"wide": 1.7,
		"lift": 0.80,
		"slipstream": false,
		"yield": true,
	},
	"flott":
	{
		"plan_brake": 30.0,
		"horizon": 60.0,
		"mistake": 0.07,
		"wide": 1.3,
		"lift": 0.86,
		"slipstream": true,
		"yield": false,
	},
	"pro":
	{
		"plan_brake": 44.0,
		"horizon": 80.0,
		"mistake": 0.025,
		"wide": 0.9,
		"lift": 0.92,
		"slipstream": true,
		"yield": false,
	},
}
const MISTAKE_SECONDS := 1.3
const YIELD_RANGE := 16.0
const YIELD_LANE := 2.6

static var _tables: Dictionary = {}


static func level(difficulty: String) -> Dictionary:
	return LEVELS.get(difficulty, LEVELS.flott)


## Signed curvature (rad/m) every TABLE_STEP metres of this world's centreline,
## averaged over BEND_WINDOW. Built once per world and cached.
static func bend_table(world) -> PackedFloat32Array:
	var key: int = world.get_instance_id()
	if _tables.has(key):
		var cached: Dictionary = _tables[key]
		if is_equal_approx(float(cached.length), float(world.length)):
			return cached.bends
	if _tables.size() > 6:
		_tables.clear()
	var length: float = float(world.length)
	var count: int = maxi(1, ceili(length / TABLE_STEP))
	var bends := PackedFloat32Array()
	bends.resize(count)
	var half: float = BEND_WINDOW * 0.5
	for index in range(count):
		var at: float = float(index) * TABLE_STEP
		var behind: Vector3 = world.forward(at - half)
		var ahead: Vector3 = world.forward(at + half)
		bends[index] = (
			angle_difference(atan2(behind.x, behind.z), atan2(ahead.x, ahead.z)) / BEND_WINDOW
		)
	var corners: PackedFloat32Array = _corners(bends, length)
	_tables[key] = {"length": length, "bends": bends, "corners": corners}
	return bends


static func bend_at(world, distance: float) -> float:
	var bends: PackedFloat32Array = bend_table(world)
	var index: int = posmod(int(roundf(distance / TABLE_STEP)), bends.size())
	return bends[index]


## Corner apexes (metres) of one lap: local curvature maxima above CORNER_MIN.
static func corners(world) -> PackedFloat32Array:
	bend_table(world)
	return _tables[world.get_instance_id()].corners


static func _corners(bends: PackedFloat32Array, length: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var count: int = bends.size()
	var last: float = -INF
	for index in range(count):
		var here: float = absf(bends[index])
		if here < CORNER_MIN:
			continue
		var peak: bool = true
		for offset in range(-6, 7):
			if absf(bends[posmod(index + offset, count)]) > here:
				peak = false
				break
		var at: float = float(index) * TABLE_STEP
		if peak and at - last >= CORNER_SPACING and at > 30.0 and at < length - 20.0:
			result.append(at)
			last = at
	return result


## Highest speed from which this rival still makes every corner on the road
## ahead with its planned braking. Same grip model as racecraft.corner_speed.
static func approach_speed(
	world, distance: float, difficulty: String, kart_id: String, index: int
) -> float:
	var rules: Dictionary = level(difficulty)
	var brake: float = float(rules.plan_brake)
	var horizon: float = float(rules.horizon)
	var best: float = INF
	var along: float = 0.0
	while along <= horizon:
		var corner: float = CRAFT.corner_speed(
			bend_at(world, distance + along), difficulty, kart_id, index
		)
		if corner < INF:
			var reach: float = sqrt(corner * corner + 2.0 * brake * maxf(0.0, along - 2.0))
			best = minf(best, reach)
		along += TABLE_STEP * 2.0
	return best


## Speed after one tick under the kart's own drivetrain. Returns
## Vector2(new speed, brake light 0..1).
static func envelope(current: float, target: float, factors: Dictionary, delta: float) -> Vector2:
	var now: float = maxf(0.0, current)
	if target >= now:
		var thrust: float = POWERTRAIN.acceleration(factors, false)
		return Vector2(move_toward(now, target, thrust * delta), 0.0)
	var brake: float = POWERTRAIN.acceleration(factors, true)
	var next: float = move_toward(now, target, brake * delta)
	var decel: float = (now - next) / maxf(delta, 0.0001)
	return Vector2(next, clampf(decel / (brake * 0.45), 0.0, 1.0))


## Per-race seed for the planned mistakes (a replay with race_seed is identical).
static func race_seed_of(game) -> int:
	if int(game.race_seed) >= 0:
		return int(game.race_seed)
	return hash(str(game.result_id)) & 0x7fffffff


## Deterministic 0..1 roll for rival [param index] at corner [param corner] of [param lap].
static func roll(seed: int, index: int, lap: int, corner: int) -> float:
	return float(posmod(hash([seed, index, lap, corner, 7919]), 100000)) / 100000.0


## Starts or continues a planned mistake. Returns {"lane": lateral shift (m),
## "speed": factor} for this tick; {} while driving cleanly.
static func mistake(game, index: int, road_distance: float, delta: float) -> Dictionary:
	var rival: Node3D = game.opponents[index]
	var left: float = float(rival.get_meta(&"mistake_left", 0.0))
	if left > 0.0:
		left = maxf(0.0, left - delta)
		rival.set_meta(&"mistake_left", left)
		var kind: String = str(rival.get_meta(&"mistake_kind", "wide"))
		var phase: float = 1.0 - left / MISTAKE_SECONDS
		var shape: float = sin(clampf(phase, 0.0, 1.0) * PI)
		var rules: Dictionary = level(str(game.difficulty))
		if kind == "lift":
			return {"lane": 0.0, "speed": lerpf(1.0, float(rules.lift), shape), "kind": kind}
		return {
			"lane": float(rival.get_meta(&"mistake_side", 1.0)) * float(rules.wide) * shape,
			"speed": lerpf(1.0, 0.93, shape),
			"kind": kind,
		}
	var rules: Dictionary = level(str(game.difficulty))
	var length: float = float(game.track_length)
	var apexes: PackedFloat32Array = corners(game.world)
	var progress: float = float(game.opponent_distances[index])
	var lap: int = int(floor(progress / maxf(length, 1.0)))
	for corner in range(apexes.size()):
		var entry: float = float(apexes[corner]) - 18.0
		var ahead: float = entry - road_distance
		if ahead < 0.0 or ahead > absf(float(rival.motion_speed)) * delta + 0.5:
			continue
		var key: int = lap * 1000 + corner
		if int(rival.get_meta(&"mistake_checked", -1)) == key:
			return {}
		rival.set_meta(&"mistake_checked", key)
		if roll(race_seed_of(game), index, lap, corner) >= float(rules.mistake):
			return {}
		var bend: float = bend_at(game.world, float(apexes[corner]))
		var side: float = signf(bend) if bend != 0.0 else 1.0
		if not _room_outside(game, index, side):
			return {}
		var kind: String = (
			"lift" if roll(race_seed_of(game), index, lap, corner + 500) < 0.4 else "wide"
		)
		rival.set_meta(&"mistake_left", MISTAKE_SECONDS)
		rival.set_meta(&"mistake_side", side)
		rival.set_meta(&"mistake_kind", kind)
		rival.set_meta(&"mistakes", int(rival.get_meta(&"mistakes", 0)) + 1)
		if game.has_method("_stat"):
			game._stat("rival_mistakes")
		return {}
	return {}


## A rival only runs wide where nobody drives beside it on the outside.
static func _room_outside(game, index: int, side: float) -> bool:
	var origin: Vector3 = game.opponents[index].position
	var basis: Basis = game.world.frame(float(game.opponent_distances[index]))
	var others: Array[Vector3] = [game.player.position]
	for other in range(game.opponents.size()):
		if other != index:
			others.append(game.opponents[other].position)
	for position in others:
		var gap: Vector3 = position - origin
		var along: float = gap.dot(-basis.z)
		var lateral: float = gap.dot(basis.x) * side
		if absf(along) < 12.0 and lateral > -0.6 and lateral < 3.2:
			return false
	return true


## Entdecken: the child closing in from behind gets a free lane. Returns the
## lane to steer for (INF = no change) and records the courtesy once per pass.
static func yield_lane(game, index: int, rival_lane: float, target_lane: float) -> float:
	if not bool(level(str(game.difficulty)).yield):
		return INF
	var rival: Node3D = game.opponents[index]
	var behind: float = float(game.opponent_distances[index]) - float(game.distance)
	var closing: float = float(game.speed) - absf(float(rival.motion_speed))
	var player_lane: float = float(game.lane)
	if behind <= 0.5 or behind > YIELD_RANGE or closing < 0.5:
		rival.set_meta(&"yielding", false)
		return INF
	if absf(target_lane - player_lane) >= YIELD_LANE:
		return INF
	var side: float = signf(rival_lane - player_lane)
	if side == 0.0:
		side = -signf(player_lane) if player_lane != 0.0 else 1.0
	var wall: float = float(game._wall_lateral_at(float(game.opponent_distances[index]))) - 0.6
	var lane: float = clampf(player_lane + side * YIELD_LANE, -wall, wall)
	if absf(lane - player_lane) < YIELD_LANE * 0.8:
		# No room on that side: pass on the other one.
		lane = clampf(player_lane - side * YIELD_LANE, -wall, wall)
	if not bool(rival.get_meta(&"yielding", false)):
		rival.set_meta(&"yielding", true)
		if game.has_method("_stat"):
			game._stat("rival_yields")
	return lane


## Slipstream for rivals (Abenteuer/Extrem): the same wake geometry and charge
## time as the child's (kart_race_rules), the same tow boost length.
static func update_slipstream(game, index: int, delta: float) -> void:
	if not bool(level(str(game.difficulty)).slipstream):
		return
	var rival: Node3D = game.opponents[index]
	var speed: float = absf(float(rival.motion_speed))
	var heading: float = float(game.opponent_headings[index])
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var towed: bool = RACE_RULES.in_slipstream(rival.position, forward, game.player.position, speed)
	for other in range(game.opponents.size()):
		if towed:
			break
		if other != index:
			towed = RACE_RULES.in_slipstream(
				rival.position, forward, game.opponents[other].position, speed
			)
	var charge: float = float(rival.get_meta(&"slipstream_charge", 0.0))
	charge = charge + delta if towed else maxf(0.0, charge - delta * 2.0)
	if charge >= RACE_RULES.SLIPSTREAM_CHARGE_SECONDS:
		charge = 0.0
		game.opponent_boost_times[index] = maxf(
			game.opponent_boost_times[index], RACE_RULES.SLIPSTREAM_BOOST_SECONDS
		)
		rival.set_meta(&"slipstreams", int(rival.get_meta(&"slipstreams", 0)) + 1)
		if game.has_method("_stat"):
			game._stat("rival_slipstreams")
	rival.set_meta(&"slipstream_charge", charge)
