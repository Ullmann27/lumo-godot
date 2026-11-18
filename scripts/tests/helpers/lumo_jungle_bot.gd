extends RefCounted
## A scripted player for the Dschungelherz adventure path, used by the tests and
## the picture captures. It only uses the game's own inputs (stick, SPRINGEN,
## FLITZEN). Before it jumps it tries its options on a copy of Lumo's motion model
## against the real track (holes, moving and crumbling platforms, enemies), the
## way a careful child looks before leaping. The seed decides which ways it takes
## (upper or lower branch, hidden niches) and how it times its presses.

const PLAYER = preload("res://scripts/games/run/run_player.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const STEP: float = 1.0 / 60.0
## Jump options: seconds to wait, seconds to hold SPRINGEN, air time of FLITZEN (-1: none).
const OPTIONS: Array = [
	[0.0, 0.0, -1.0], [0.0, 0.15, -1.0], [0.0, 0.3, -1.0], [0.0, 0.45, -1.0], [0.0, 0.45, 0.32],
	[0.12, 0.3, -1.0], [0.12, 0.45, -1.0], [0.25, 0.45, -1.0], [0.25, 0.45, 0.32],
]

var rng := RandomNumberGenerator.new()
var upper_share: float = 0.5
var explore: bool = true
var jumps: int = 0
var dashes: int = 0
var brakes: int = 0
var routes: Dictionary = {}
var _hold_left: float = 0.0
var _dash_in: float = -1.0
var _jump_in: float = -1.0
var _pending: Array = []
var _think: int = 0
var _braking: bool = false
## A deliberately slow player: holds the stick back this much (0 = never) in
## the stretches given by `slow_zones` ([s0, s1] in metres; empty = everywhere).
var hold_back: float = 0.0
var slow_zones: Array[Vector2] = []


func _init(seed: int = 1) -> void:
	rng.seed = seed
	upper_share = [0.0, 1.0, 0.5][seed % 3]
	explore = seed % 2 == 0


func drive(game, delta: float) -> void:
	var player = game.player
	var plan = game.plan
	_tick_inputs(player, delta)
	if player.is_riding() or player.tumble_time > 0.0:
		game.touch_steer = Vector2.ZERO
		if player.is_riding() and str(player.ride.kind) == "barrel" and not player.ride_fired and player.ride_t > 0.5 and rng.randf() < 0.01:
			player.press_jump()
			player.release_jump()
		return
	var target: float = _target_lat(game)
	var steer: float = clampf((target - player.lat) * 1.5, -1.0, 1.0)
	if player.in_cart:
		steer = 0.0
	_think += 1
	if player.grounded and _jump_in < 0.0 and _hold_left <= 0.0 and _think % 2 == 0:
		_decide(game, steer)
	game.touch_steer = Vector2(steer, 1.0 if _braking else _hold_back_at(player.s))


func _hold_back_at(at: float) -> float:
	if hold_back <= 0.0:
		return 0.0
	if slow_zones.is_empty():
		return hold_back
	for zone in slow_zones:
		if at >= zone.x and at <= zone.y:
			return hold_back
	return 0.0


func _tick_inputs(player, delta: float) -> void:
	if _jump_in >= 0.0:
		_jump_in -= delta
		if _jump_in < 0.0 and not _pending.is_empty():
			player.press_jump()
			jumps += 1
			_hold_left = maxf(float(_pending[1]), 0.01)
			_dash_in = float(_pending[2])
			_pending = []
	if _hold_left > 0.0:
		_hold_left -= delta
		if _hold_left <= 0.0:
			player.release_jump()
	if _dash_in >= 0.0 and not player.grounded:
		_dash_in -= delta
		if _dash_in < 0.0 and player.press_dash():
			dashes += 1


# ------------------------------------------------------------------ where to go

func _route(game, branch: Dictionary) -> String:
	var key: String = str(branch.name)
	if not routes.has(key):
		routes[key] = "upper" if rng.randf() < upper_share else "lower"
		# An adventure passage: the brave line only with the pace it needs.
		if routes[key] == "upper" and game.player.speed < float(branch.get("brave_speed", 0.0)):
			routes[key] = "lower"
	return str(routes[key])


func _target_lat(game) -> float:
	var player = game.player
	var plan = game.plan
	var allowed: Array[String] = ["main", "bonus"]
	var fallback: float = player.lat * 0.9 if player.s >= 0.0 else 0.0
	for branch in plan.branches:
		if player.s > float(branch.s0) - 18.0 and player.s < float(branch.s1):
			var route: String = _route(game, branch)
			allowed.append(route)
			fallback = float(branch.upper_lat) if route == "upper" else float(branch.lower_lat)
			if route == "upper" and player.h > 1.5:
				# Up on the ledges: stay up there until they end.
				allowed.erase("main")
	if explore:
		allowed.append("niche")
	for ride in plan.rides:
		if explore and str(ride.kind) == "warp" and bool(ride.get("bonus", false)):
			var ahead: float = float(ride.s) - player.s
			if ahead > 0.0 and ahead < 16.0 and not game.track.bonus_found:
				return float(ride.lat)
	for index in range(plan.star_s.size()):
		var along: float = plan.star_s[index]
		if along < player.s + 2.0:
			continue
		if along > player.s + 14.0:
			break
		if game.track.taken[index] != 0 or not allowed.has(plan.star_route[index]):
			continue
		if plan.star_h[index] > player.h + 5.5:
			continue
		return plan.star_lat[index]
	for blocker in plan.blockers:
		var ahead: float = float(blocker.s) - player.s
		if ahead > 0.0 and ahead < 10.0 and absf(float(blocker.lat) - fallback) < float(blocker.radius) + 1.0:
			return float(blocker.lat) - signf(float(blocker.lat)) * 2.4
	return fallback


# ------------------------------------------------------------------ when to jump

func _decide(game, steer: float) -> void:
	var straight: Dictionary = _simulate(game, steer, -1.0, 0.0, -1.0, 1.1)
	if straight.ok and not straight.drop:
		_braking = false
		return
	var fallback: Array = []
	for option in OPTIONS:
		var trial: Dictionary = _simulate(game, steer, float(option[0]), float(option[1]), float(option[2]), 1.6)
		if trial.ok and trial.drop and fallback.is_empty():
			fallback = option
		if trial.ok and not trial.drop:
			_braking = false
			if float(option[0]) <= 0.0:
				game.player.press_jump()
				jumps += 1
				_hold_left = maxf(float(option[1]), 0.01)
				_dash_in = float(option[2])
			else:
				_jump_in = float(option[0])
				_pending = option
			return
	if straight.ok:
		# Only a drop to the lower way is left: just run on.
		_braking = false
		return
	if not fallback.is_empty() and float(straight.danger_in) < 0.5:
		_braking = false
		game.player.press_jump()
		jumps += 1
		_hold_left = maxf(float(fallback[1]), 0.01)
		_dash_in = float(fallback[2])
		return
	# Nothing works from here yet: wait for the platform (or the crab) to come round.
	if float(straight.danger_in) < 0.6:
		if not _braking:
			brakes += 1
		_braking = true


## Runs a copy of Lumo forward against the real track. `jump_at` < 0: no jump.
func _simulate(game, steer: float, jump_at: float, hold: float, dash_at: float, seconds: float) -> Dictionary:
	var source = game.player
	var track = game.track
	var plan = game.plan
	var copy = PLAYER.new()
	for field in [
		"s", "previous_s", "lat", "lat_v", "h", "vy", "speed", "grounded", "jumping", "coyote", "ground_rate",
		"dash_time", "dash_cooldown", "boost_time", "stumble_time", "invulnerable", "cruise", "lateral_speed",
		"slow_factor", "air_dash", "air_dash_ready", "in_cart", "cart_lat", "flow", "flow2", "flow_bonus", "acceleration",
		"coyote_window", "buffer_window",
	]:
		copy.set(field, source.get(field))
	copy.jump_held = false
	copy.jump_buffer = 0.0
	var saved_clock: float = track.clock
	var clock: float = saved_clock
	var start_h: float = source.h
	var result: Dictionary = {"ok": true, "drop": false, "danger_in": 99.0}
	var airborne: bool = false
	var t: float = 0.0
	var landed_for: float = 0.0
	var pull: float = 1.0 if _braking and jump_at < 0.0 else _hold_back_at(source.s)
	var stomped: Array[int] = []
	while t < seconds:
		if jump_at >= 0.0 and t >= jump_at and t < jump_at + STEP:
			copy.press_jump()
		if copy.jump_held and t >= jump_at + hold:
			copy.release_jump()
		if dash_at >= 0.0 and jump_at >= 0.0 and t >= jump_at + dash_at and not copy.grounded and copy.air_dash_ready:
			copy.press_dash()
		clock += STEP
		track.clock = clock
		copy.step(STEP, Vector2(steer, pull), track)
		t += STEP
		if not copy.grounded:
			airborne = true
		if copy.h < -1.2:
			result = {"ok": false, "drop": false, "danger_in": t}
			break
		if _touches_ride(copy, plan):
			break
		var harm: String = _harm(copy, track, clock, plan, stomped)
		if harm.begins_with("stomp"):
			# The stomp throws Lumo up again: follow that flight as well.
			stomped.append(int(harm.substr(6)))
			copy.bounce(TUNING.STOMP_SPEED)
			airborne = true
			continue
		if not harm.is_empty():
			result = {"ok": false, "drop": false, "danger_in": t}
			break
		if airborne and copy.grounded:
			landed_for += STEP
			if copy.h < start_h - 1.5:
				result.drop = true
			if landed_for > 0.3 and jump_at >= 0.0:
				break
	track.clock = saved_clock
	return result


func _touches_ride(copy, plan) -> bool:
	var centre := Vector3(copy.s, copy.lat, copy.h + TUNING.BODY_CENTRE)
	for ride in plan.rides:
		if absf(copy.s - float(ride.s)) > 2.0:
			continue
		if str(ride.kind) == "warp" and not explore:
			continue
		var offset: Vector3 = centre - Vector3(float(ride.s), float(ride.lat), float(ride.h))
		if offset.length() < TUNING.RIDE_GRAB_RADIUS * 0.9:
			return true
		if str(ride.kind) != "barrel" and str(ride.kind) != "warp" and absf(offset.x) < 1.0 and absf(offset.y) < 1.2 and offset.z > -1.5 and offset.z < 1.3:
			return true
	return false


func _harm(copy, track, clock: float, plan, stomped: Array[int]) -> String:
	for index in range(plan.enemies.size()):
		if track.defeated.has(index) or stomped.has(index):
			continue
		var enemy: Dictionary = plan.enemies[index]
		if absf(copy.s - float(enemy.s)) > float(enemy.amp) + float(enemy.span) + 3.0:
			continue
		var at: Vector2 = track.enemy_position(enemy, clock)
		var reach: float = float(enemy.radius) + 0.55
		if absf(copy.s - at.x) > reach or absf(copy.lat - at.y) > reach or copy.h >= float(enemy.top) + 0.1:
			continue
		if not copy.grounded and copy.vy <= 0.0 and copy.h >= float(enemy.top) * 0.3:
			return "stomp:%d" % index
		return "enemy"
	for hurdle in plan.hurdles:
		var along: float = float(hurdle.s)
		if absf(copy.s - along) < 0.45 and copy.h < float(hurdle.height) - 0.05 and absf(copy.lat - float(hurdle.lat)) <= float(hurdle.half) + 0.3:
			return "log"
	if not plan.chase.is_empty() and track.chase_active:
		var boulder: float = track.boulder_s + 0.8 * TUNING.PATH_CRUISE * (clock - track.clock)
		if boulder + float(plan.chase.radius) >= copy.s - 0.2 and copy.h < 2.2:
			return "boulder"
	return ""
