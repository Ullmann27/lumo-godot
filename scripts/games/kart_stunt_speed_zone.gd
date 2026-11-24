extends RefCounted
## Visible braking approach for Sonnenhafen's precision jump. The speed envelope
## uses the same normal brakes as the race. It never moves a kart or changes its
## ballistic flight, and mounted brakes decide where slowing begins.
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const PARTS = preload("res://scripts/games/kart_part_catalog.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
const RULES = preload("res://scripts/games/kart_items/kart_race_rules.gd")
const FINE = preload("res://scripts/games/kart_fine_tuning.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const META: StringName = &"kart_precision_speed_zone"
## _gameplay_speed_factor: Nordlicht OR normal magnet, never both. Extended XL
## boost and an already active magnet-pull may coexist briefly with Nordlicht.
## The conservative envelope also covers speed carried in after a mod expires.
const AURORA_MAX: float = 1.22
const EXT_TURBO_MAX: float = 1.08
const EXT_MAGNET_MAX: float = 1.07
const MAX_PHYSICS_STEP: float = 0.10
const ENTRY_MARGIN: float = 8.0
const SETTLE_BEFORE_RAMP: float = 4.0
static var _limits: Dictionary = {}


static func _weakest_brake_multiplier() -> float:
	var multiplier: float = 1.0
	for slot in PARTS.SLOTS:
		var minimum: float = 1.0
		for item in PARTS.options(slot):
			minimum = minf(minimum, float(item.get("mul", {}).get("brake", 1.0)))
		multiplier *= minimum
	for setting in FINE.SETTINGS:
		var per_step: float = float(setting.per_step.get("brake", 0.0))
		multiplier *= 1.0 - absf(per_step) * FINE.STEPS
	return clampf(multiplier, float(PARTS.PART_LIMITS.brake[0]), float(PARTS.PART_LIMITS.brake[1]))


static func hardware_limits() -> Dictionary:
	if not _limits.is_empty():
		return _limits
	var maximum: float = 0.0
	var boosted: float = 0.0
	var weakest_brake: float = INF
	var minimum_brake_parts: float = _weakest_brake_multiplier()
	for kart in FLEET.KARTS:
		var stats: Dictionary = FLEET.base_stats(str(kart.id))
		var stock: Dictionary = FLEET.multipliers(stats, kart.traits)
		weakest_brake = minf(weakest_brake, POWERTRAIN.acceleration(
			{"brake": float(stock.brake) * minimum_brake_parts}, true))
		for upgrade in TUNING.PARTS:
			for key in upgrade.bonus:
				stats[key] = minf(FLEET.MAX_STAT, float(stats[key]) + float(upgrade.bonus[key]) * TUNING.MAX_LEVEL)
		var factors: Dictionary = FLEET.multipliers(stats, kart.traits)
		factors.speed = float(factors.speed) * float(PARTS.PART_LIMITS.speed[1])
		factors.boost_power = float(factors.boost_power) * float(PARTS.PART_LIMITS.boost_power[1])
		var speed: float = POWERTRAIN.top_speed(factors, POWERTRAIN.race_pace())
		maximum = maxf(maximum, speed)
		boosted = maxf(boosted, speed * POWERTRAIN.boost_scale(factors))
	var catch_up: float = 1.0
	for amount in RULES.PLAYER_CATCH_UP_MAX.values():
		catch_up = maxf(catch_up, 1.0 + float(amount))
	_limits = {"cruise": maximum, "entry": boosted * AURORA_MAX * EXT_TURBO_MAX * EXT_MAGNET_MAX * catch_up,
		"brake": weakest_brake}
	return _limits


static func of(world) -> Dictionary:
	if not is_instance_valid(world) or str(world.track_id) != "sonnenhafen":
		return {}
	return world.get_meta(META, {})


## Reserve against the entire actual road elevation range, not a flat-ground
## guess at the old ramp location. This also covers a descending landing road.
static func configure(world, tunnel: float, ramp_length: float, ramp_height: float, angle: float, gravity: float) -> Dictionary:
	var limits: Dictionary = hardware_limits()
	var lowest: float = INF
	var highest: float = -INF
	for sample in world._road_samples:
		lowest = minf(lowest, sample.y)
		highest = maxf(highest, sample.y)
	var relief: float = maxf(0.0, highest - lowest) if is_finite(lowest) else 0.0
	var flight: Dictionary = {"height": ramp_height + relief, "angle": angle,
		"flight_gravity": gravity, "lift_bonus": 0.0}
	var landing: float = PRECISION.landing_distance(float(limits.cruise), flight)
	var take_off: float = tunnel - maxf(80.0, ceilf(landing + ENTRY_MARGIN))
	var safe_at: float = take_off - ramp_length - SETTLE_BEFORE_RAMP
	var braking_metres: float = (pow(float(limits.entry), 2.0) - pow(float(limits.cruise), 2.0)) / (2.0 * float(limits.brake))
	var zone_length: float = ceilf(braking_metres + float(limits.entry) * MAX_PHYSICS_STEP + ENTRY_MARGIN)
	var data: Dictionary = {"start": safe_at - zone_length, "safe_at": safe_at,
		"take_off": take_off, "end": take_off, "tunnel": tunnel, "limit": limits.cruise,
		"max_entry": limits.entry, "minimum_brake": limits.brake,
		"landing_reserve": landing, "height_relief": relief}
	world.set_meta(META, data)
	return data


## Physically reachable upper speed along the visible approach. Each kart uses
## its own braking force. The margin absorbs a coarse frame at the zone boundary.
static func speed_limit(world, distance: float, factors: Dictionary) -> float:
	var data: Dictionary = of(world)
	if data.is_empty() or distance < float(data.start) or distance > float(data.end):
		return INF
	var remaining: float = maxf(0.0, float(data.safe_at) - distance - ENTRY_MARGIN)
	var brake: float = POWERTRAIN.acceleration(factors, true)
	return sqrt(pow(float(data.limit), 2.0) + 2.0 * brake * remaining)


static func build(world) -> void:
	var data: Dictionary = of(world)
	if data.is_empty():
		return
	var orange := Color("ffad44")
	var navy := Color("24354a")
	var start: float = float(data.start)
	var ramp: float = float(data.safe_at)
	for d in [start, ramp - 55.0]:
		var basis: Basis = world.frame(d)
		var half: float = world.road_width_at(d) * 0.5 + 1.3
		for side in [-1.0, 1.0]:
			var foot: Vector3 = world.position_at(d, side * half)
			world._prop("box", foot + basis.y * 3.4, Vector3(0.35, 6.8, 0.4), navy, basis)
		var at: Vector3 = world.position_at(d) + basis.y * 6.6
		world._prop("box", at, Vector3(half * 2.0 + 0.4, 0.9, 0.45), navy, basis)
		world._prop("box", at + basis.y * 0.51, Vector3(half * 2.0 + 0.6, 0.08, 0.50), orange, basis, true)
		world._sign(at + basis.z * 0.24, basis, "PRÄZISIONSSPRUNG\nBREMSHILFE", 0.015)
	var along: float = start
	while along < ramp:
		var basis: Basis = world.frame(along)
		for side in [-1.0, 1.0]:
			var half: float = world.road_width_at(along) * 0.5
			world._prop("box", world.position_at(along, side * (half - 0.65)) + basis.y * 0.035,
				Vector3(0.28, 0.04, 3.0), orange, basis, true)
			if along > ramp - 70.0:
				world._prop("box", world.position_at(along, side * 2.6) + basis.y * 0.035,
					Vector3(2.2, 0.035, 0.32), orange, basis, true)
		along += 9.0 if along > ramp - 70.0 else 18.0
