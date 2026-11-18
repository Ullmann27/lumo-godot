extends RefCounted
## Live state of one run on a planned course: which stars are taken, which crates
## are broken, how often a gap was missed. Answers the motion model's questions
## (ground, side limits, slope) and resolves everything Lumo touches.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")

var plan
var world
var taken := PackedByteArray()
var broken: Dictionary = {}
var misses: Dictionary = {}
var kept: int = 0
var gathered: int = 0
var stumbles: int = 0
var checkpoint: int = -1
var finished: bool = false
## Adventure path state (Dschungelherz).
var clock: float = 0.0
var letters: int = 0
var bonus_found: bool = false
var rescue: int = -1
var falls: Dictionary = {}
var defeated: Dictionary = {}
var enemy_hits: Dictionary = {}
var crumbled: Dictionary = {}
## Stretches before precise platforms where the second flow stage pauses.
var precise: Array[Vector2] = []
var ride_ready_at: Dictionary = {}
var waits_done: Dictionary = {}
var chase_active: bool = false
var chase_done: bool = false
var chase_catches: int = 0
var boulder_s: float = -INF
var rescues: int = 0
var stomps: int = 0
var _riding: int = -1
var _wait_clock: float = 0.0
var _last_clock: float = 0.0
var _cursors: Dictionary = {}
var _last_s: float = -1.0


func setup(course_plan, race_world) -> void:
	plan = course_plan
	world = race_world
	taken.resize(plan.star_s.size())
	taken.fill(0)
	broken.clear()
	misses.clear()
	kept = 0
	gathered = 0
	stumbles = 0
	checkpoint = -1
	finished = false
	_reset_path_state()
	_cursors.clear()
	_last_s = -1.0


func _reset_path_state() -> void:
	letters = 0
	bonus_found = false
	rescue = -1
	falls.clear()
	defeated.clear()
	enemy_hits.clear()
	crumbled.clear()
	precise.clear()
	if plan.adventure:
		for platform in plan.platforms:
			var small: bool = float(platform.s1) - float(platform.s0) < 4.5
			var tricky: bool = not str(platform.get("axis", "")).is_empty() or bool(platform.get("crumble", false))
			if (small or tricky) and not bool(platform.get("tempo", false)):
				precise.append(Vector2(float(platform.s0) - TUNING.PATH_PRECISE_LEAD, float(platform.s1) + 2.0))
		# Where obstacles follow each other closely, the top stage pauses as well:
		# it is meant for the open stretches, never to shorten the time to react.
		var items: Array[Vector2] = []
		for gap in world.level.gaps:
			items.append(gap)
		for list in [plan.hurdles, plan.blockers]:
			for item in list:
				items.append(Vector2(float(item.s) - 1.0, float(item.s) + 1.0))
		for enemy in plan.enemies:
			items.append(Vector2(float(enemy.s) - absf(float(enemy.get("span", 0.0))) - 1.0, float(enemy.s) + 1.0))
		items.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for index in range(items.size() - 1):
			if items[index + 1].x - items[index].y < TUNING.PATH_DENSE_SPACING:
				precise.append(Vector2(items[index].x - TUNING.PATH_PRECISE_LEAD, items[index + 1].y))
	ride_ready_at.clear()
	waits_done.clear()
	chase_active = false
	chase_done = false
	chase_catches = 0
	boulder_s = -INF
	rescues = 0
	stomps = 0
	_riding = -1
	_wait_clock = 0.0


# ------------------------------------------------------------------ questions of the motion model

func grade_at(s: float) -> float:
	return float(world.forward(s).y)


## Height of the surface Lumo can stand on, relative to the road. `feet` is the
## height his feet come from, so platforms only catch him from above.
func ground_at(s: float, lat: float, feet: float) -> float:
	if plan.adventure:
		return _path_ground(s, lat, feet)
	if world.in_gap(s):
		return -INF
	var ground: float = float(world.ramp_height(s))
	for platform in plan.platforms:
		if s < float(platform.s0):
			break
		if s > float(platform.s1) or absf(lat - float(platform.lat)) > float(platform.half):
			continue
		if feet >= float(platform.top) - 0.4:
			ground = maxf(ground, float(platform.top))
	return ground


## Adventure path: holes are open; platforms may drift, bob or crumble.
func _path_ground(s: float, lat: float, feet: float) -> float:
	var ground: float = -INF if world.in_gap(s) else 0.0
	for index in range(plan.platforms.size()):
		var platform: Dictionary = plan.platforms[index]
		if s < float(platform.s0) - 4.0 or s > float(platform.s1) + 4.0:
			continue
		var offset: Vector3 = platform_offset(platform, clock)
		if s < float(platform.s0) + offset.x or s > float(platform.s1) + offset.x:
			continue
		if absf(lat - float(platform.lat) - offset.y) > float(platform.half):
			continue
		if not platform_solid(index):
			continue
		var top: float = float(platform.top) + offset.z
		if feet >= top - 0.4:
			ground = maxf(ground, top)
	return ground


## How far a moving platform is from its rest place: x along, y across, z up.
func platform_offset(platform: Dictionary, time: float) -> Vector3:
	var axis: String = str(platform.get("axis", ""))
	if axis.is_empty():
		return Vector3.ZERO
	var value: float = float(platform.amp) * sin(time * float(platform.rate) + float(platform.phase))
	match axis:
		"lat":
			return Vector3(0.0, value, 0.0)
		"h":
			return Vector3(0.0, 0.0, value)
	return Vector3(value, 0.0, 0.0)


## A crumbling platform gives way 0.75 s after Lumo steps on it (or after its own
## "hold" seconds, see the adventure passages) and is back 3 s later.
func platform_solid(index: int) -> bool:
	if not crumbled.has(index):
		return true
	var hold: float = float(plan.platforms[index].get("hold", 0.75))
	var since: float = clock - float(crumbled[index])
	return since < hold or since > hold + 3.0


func crumble_progress(index: int) -> float:
	if not crumbled.has(index):
		return 0.0
	var hold: float = float(plan.platforms[index].get("hold", 0.75))
	var since: float = clock - float(crumbled[index])
	if since > hold + 3.0:
		return 0.0
	return clampf(since / hold, 0.0, 1.0) + (1.0 if since >= hold else 0.0)


## Highest flow stage allowed here: 1 before precise platforms, otherwise 2.
func flow_cap(s: float) -> int:
	for zone in precise:
		if s >= zone.x and s <= zone.y:
			return 1
	return 2


## Highest speed allowed here: Lumo waits at the first stream until SPRINGEN.
func speed_cap(s: float, _lat: float) -> float:
	for index in range(plan.waits.size()):
		if waits_done.has(index):
			continue
		var at: float = float(plan.waits[index].s)
		if s > at - 10.0 and s <= at + 0.2:
			return maxf(0.0, (at - s) * 2.4)
	return INF


## Keeps Lumo between the rails and out of the loop's two feet.
func confine(s: float, wanted: float, _current: float) -> float:
	var wall: float = float(world.wall_lateral_at(s)) + 0.25
	var lat: float = clampf(wanted, -wall, wall)
	for zone in plan.zones:
		var lead: float = float(zone.lead)
		if s < float(zone.s0) - lead or s > float(zone.s1):
			continue
		var low: float = float(zone.lat0)
		var high: float = minf(float(zone.lat1), wall + 1.0)
		var open: float = 1.0 if lead <= 0.0 else clampf((s - (float(zone.s0) - lead)) / lead, 0.0, 1.0)
		var centre: float = (low + high) * 0.5
		var half: float = (high - low) * 0.5 * open
		if absf(lat - centre) >= half:
			continue
		if high >= wall:
			lat = centre - half
		else:
			lat = centre - half if lat < centre else centre + half
	return clampf(lat, -wall, wall)


func wants_loop(previous_s: float, s: float, lat: float) -> bool:
	if plan.loop.is_empty():
		return false
	var start: float = float(plan.loop.start)
	return previous_s < start and s >= start and absf(lat - float(plan.loop.lane)) <= float(plan.loop.tolerance)


# ------------------------------------------------------------------ everything Lumo touches

## Applies pickups, pads, obstacles and gaps for one step of `player` and returns
## what happened as a list of small dictionaries for sound, effects and HUD.
func resolve(player, time: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if finished:
		return events
	var s: float = player.s
	if s < _last_s - 0.5:
		_cursors.clear()
	_last_s = s
	_collect(player, events)
	if player.loop_u >= 0.0:
		return events
	if plan.adventure:
		if _resolve_path(player, events):
			return events
	var on_ground: bool = player.grounded
	if not plan.adventure and _resolve_gaps(player, events):
		return events
	for index in range(_cursor("bounce", plan.bounces, "s", s - 3.0), plan.bounces.size()):
		var pad: Dictionary = plan.bounces[index]
		if float(pad.s) > s + 3.0:
			break
		var reach: float = 0.9 if bool(pad.get("band", false)) else float(pad.radius)
		if on_ground and absf(s - float(pad.s)) <= reach and absf(player.lat - float(pad.lat)) <= float(pad.half):
			player.bounce(float(pad.power))
			events.append({"type": "bounce", "index": index})
			on_ground = false
	for index in range(_cursor("boost", plan.boosts, "s1", s - 0.5), plan.boosts.size()):
		var strip: Dictionary = plan.boosts[index]
		if float(strip.s0) > s:
			break
		if on_ground and s <= float(strip.s1) and absf(player.lat - float(strip.lat)) <= float(strip.half):
			if player.boost(float(strip.get("seconds", TUNING.BOOST_SECONDS))):
				events.append({"type": "boost", "index": index})
	_resolve_hurdles(player, events)
	_resolve_blockers(player, time, events)
	if plan.adventure:
		_resolve_enemies(player, events)
	while checkpoint + 1 < plan.checkpoints.size() and s >= float(plan.checkpoints[checkpoint + 1].s):
		checkpoint += 1
		events.append({"type": "checkpoint", "index": checkpoint})
	if s >= plan.finish_s:
		finished = true
		events.append({"type": "finish"})
	return events


func _collect(player, events: Array[Dictionary]) -> void:
	var s: float = player.s
	var reach: float = TUNING.PICKUP_ALONG + maxf(0.0, s - player.previous_s)
	var index: int = _star_cursor(s - reach - 0.5)
	var centre: float = player.h + TUNING.BODY_CENTRE
	while index < plan.star_s.size() and plan.star_s[index] <= s + reach:
		if (
			taken[index] == 0
			and plan.star_s[index] >= player.previous_s - TUNING.PICKUP_ALONG
			and absf(plan.star_lat[index] - player.lat) <= TUNING.PICKUP_ACROSS
			and absf(plan.star_h[index] - centre) <= TUNING.PICKUP_HEIGHT
			and player.loop_u < 0.0
		):
			take_star(index)
			events.append({"type": "star", "index": index, "value": plan.star_value[index]})
		index += 1


## Marks one star as collected. A star can only ever be counted once.
func take_star(index: int) -> bool:
	if index < 0 or index >= taken.size() or taken[index] != 0:
		return false
	taken[index] = 1
	kept += plan.star_value[index]
	gathered += plan.star_value[index]
	return true


func add_bonus(amount: int) -> void:
	kept += maxi(0, amount)
	gathered += maxi(0, amount)


func _lose_stars() -> int:
	if plan.adventure:
		return 0
	var lost: int = mini(TUNING.STUMBLE_STAR_LOSS, kept)
	kept -= lost
	return lost


func _resolve_gaps(player, events: Array[Dictionary]) -> bool:
	var s: float = player.s
	for index in range(_cursor("channel", plan.channels, "s1", s - 14.0), plan.channels.size()):
		var gap: Dictionary = plan.channels[index]
		if float(gap.s0) > s + 1.0:
			break
		var missed: bool = false
		if bool(gap.real):
			# The road really ends here: Lumo falls and is caught below the deck.
			missed = player.h < -3.5 and s >= float(gap.s0) - 1.0
		else:
			missed = player.grounded and s > float(gap.s0) + 0.3 and s < float(gap.s1) - 0.3
		if not missed:
			continue
		var count: int = int(misses.get(index, 0)) + 1
		misses[index] = count
		stumbles += 1
		var helped: bool = count > TUNING.GAP_HELP_AFTER_MISSES
		var lost: int = _lose_stars()
		player.respawn(float(gap.exit) if helped else float(gap.respawn), _safe_lateral(player.lat))
		_cursors.clear()
		_last_s = player.s
		events.append(
			{"type": "fall" if bool(gap.real) else "splash", "index": index, "helped": helped, "lost": lost}
		)
		return true
	# A fall anywhere else (should not happen) is still never the end of the run.
	if player.h < -8.0:
		stumbles += 1
		player.respawn(maxf(plan.start_s, s - 10.0), _safe_lateral(player.lat))
		_cursors.clear()
		_last_s = player.s
		events.append({"type": "fall", "index": -1, "helped": false, "lost": _lose_stars()})
		return true
	return false


func _safe_lateral(lat: float) -> float:
	return clampf(lat, -2.5, 2.5)


func _resolve_hurdles(player, events: Array[Dictionary]) -> void:
	var s: float = player.s
	for index in range(_cursor("hurdle", plan.hurdles, "s", s - 2.0), plan.hurdles.size()):
		var hurdle: Dictionary = plan.hurdles[index]
		var at: float = float(hurdle.s)
		if at > s + 0.4:
			break
		var crossing: bool = (player.previous_s < at and s >= at) or absf(s - at) < 0.3
		if not crossing or player.h >= float(hurdle.height) - 0.1:
			continue
		if absf(player.lat - float(hurdle.lat)) > float(hurdle.half) + 0.3:
			continue
		if player.stumble():
			stumbles += 1
			events.append({"type": "stumble", "cause": "hurdle", "lost": _lose_stars()})


func _resolve_blockers(player, time: float, events: Array[Dictionary]) -> void:
	var s: float = player.s
	for index in range(_cursor("blocker", plan.blockers, "s", s - 3.0), plan.blockers.size()):
		var blocker: Dictionary = plan.blockers[index]
		var at: float = float(blocker.s)
		if at > s + 3.0:
			break
		if broken.has(index) or player.h >= float(blocker.height):
			continue
		var reach: float = float(blocker.radius) + TUNING.BODY_RADIUS
		if absf(s - at) > reach:
			continue
		var centre: float = blocker_lateral(blocker, time)
		var across: float = player.lat - centre
		if absf(across) > reach:
			continue
		var kind: String = str(blocker.kind)
		if kind == "crate":
			broken[index] = true
			if player.dash_time > 0.0:
				kept += TUNING.CRATE_STARS
				gathered += TUNING.CRATE_STARS
				events.append({"type": "crate", "index": index, "stars": TUNING.CRATE_STARS})
			else:
				events.append({"type": "crate", "index": index, "stars": 0})
				if player.stumble():
					stumbles += 1
					events.append({"type": "stumble", "cause": "crate", "lost": _lose_stars()})
			continue
		if kind == "roller" and player.dash_time > 0.0:
			broken[index] = true
			events.append({"type": "roller", "index": index})
			continue
		# Solid from the side: Lumo slides past instead of running through.
		var side: float = 1.0 if across >= 0.0 else -1.0
		player.lat = confine(s, centre + side * (reach + 0.02), player.lat)
		player.lat_v = 0.0
		if absf(across) < reach - 0.3 and player.stumble():
			stumbles += 1
			events.append({"type": "stumble", "cause": kind, "lost": _lose_stars()})


func blocker_lateral(blocker: Dictionary, time: float) -> float:
	if float(blocker.amp) == 0.0:
		return float(blocker.lat)
	return float(blocker.lat) + float(blocker.amp) * sin(time * float(blocker.rate) + float(blocker.phase))


# ------------------------------------------------------------------ cursors

## First index of `list` whose `key` is not behind `from`. Lists are sorted along
## the course, so each step only looks at the handful of things near Lumo.
func _cursor(name: String, list: Array, key: String, from: float) -> int:
	var index: int = int(_cursors.get(name, 0))
	while index < list.size() and float(list[index][key]) < from:
		index += 1
	_cursors[name] = index
	return index


func _star_cursor(from: float) -> int:
	var index: int = int(_cursors.get("star", 0))
	while index < plan.star_s.size() and plan.star_s[index] < from:
		index += 1
	_cursors["star"] = index
	return index


# ------------------------------------------------------------------ checkpoints, save, restore

## Road distance where Lumo is set down for a checkpoint (-1 is the start line).
func checkpoint_s(index: int) -> float:
	if index < 0 or index >= plan.checkpoints.size():
		return plan.start_s
	return float(plan.checkpoints[index].s) + 2.0


func taken_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for index in range(taken.size()):
		if taken[index] != 0:
			ids.append(index)
	return ids


func snapshot() -> Dictionary:
	var crates: Array[int] = []
	for index in broken:
		crates.append(int(index))
	crates.sort()
	var missed: Dictionary = {}
	for index in misses:
		missed[int(index)] = int(misses[index])
	return {
		"checkpoint": checkpoint,
		"kept": kept,
		"gathered": gathered,
		"stumbles": stumbles,
		"taken": taken_ids(),
		"broken": crates,
		"misses": missed,
		"letters": letters,
		"bonus": bonus_found,
	}


## Restores a snapshot that run_session.gd has already validated against the plan.
func restore(state: Dictionary) -> void:
	taken.fill(0)
	for index in state.get("taken", PackedInt32Array()):
		taken[int(index)] = 1
	broken.clear()
	for index in state.get("broken", []):
		broken[int(index)] = true
	misses.clear()
	var missed: Dictionary = state.get("misses", {})
	for index in missed:
		misses[int(index)] = int(missed[index])
	kept = int(state.get("kept", 0))
	gathered = int(state.get("gathered", kept))
	stumbles = int(state.get("stumbles", 0))
	checkpoint = int(state.get("checkpoint", -1))
	finished = false
	_reset_path_state()
	letters = int(state.get("letters", 0))
	bonus_found = bool(state.get("bonus", false))
	_cursors.clear()
	_last_s = -1.0


# ------------------------------------------------------------------ adventure path

func letter_count() -> int:
	var count: int = 0
	for bit in range(plan.letters.size()):
		if letters & (1 << bit):
			count += 1
	return count


func enemy_position(enemy: Dictionary, time: float) -> Vector2:
	var wave: float = sin(time * float(enemy.rate) + float(enemy.phase))
	match str(enemy.kind):
		"crab":
			return Vector2(float(enemy.s), float(enemy.lat) + float(enemy.amp) * wave)
		"beetle":
			return Vector2(float(enemy.s) + float(enemy.amp) * wave, float(enemy.lat))
		"coconut":
			var rolled: float = fposmod(time * float(enemy.rate) + float(enemy.phase), float(enemy.span))
			return Vector2(float(enemy.s) - rolled, float(enemy.lat))
	return Vector2(float(enemy.s), float(enemy.lat))


## Rides, letters, holes, the chase, the mine cart and the rescue points.
## True when Lumo was set back and nothing else should happen this step.
func _resolve_path(player, events: Array[Dictionary]) -> bool:
	var step: float = maxf(0.0, clock - _last_clock)
	_last_clock = clock
	var s: float = player.s
	if s < 0.0 and not bonus_found and not player.is_riding():
		bonus_found = true
		events.append({"type": "bonus"})
	if not player.is_riding() and _riding >= 0:
		ride_ready_at[_riding] = clock + 1.0
		_riding = -1
	var found: int = plan.respawn_index(s)
	if not player.is_riding() and player.tumble_time <= 0.0 and found >= 0:
		var was_bonus: bool = rescue >= 0 and float(plan.respawns[rescue].s) < 0.0
		if s < 0.0 or found > rescue or was_bonus:
			rescue = found
	_carry(player)
	if player.h < -0.3 and not player.is_riding() and world.in_gap(player.previous_s) and not world.in_gap(player.s):
		# Down in a hole Lumo bumps into its wall instead of running into the ground.
		player.s = player.previous_s
		player.speed = 0.0
	_resolve_letters(player, events)
	if player.tumbled and player.tumble_time <= 0.0:
		_rescue(player, events, "hit", false)
		return true
	if player.tumble_time > 0.0:
		return false
	if not player.is_riding():
		_grab_rides(player, events)
	if player.is_riding():
		return false
	_resolve_waits(player, step, events)
	if not plan.cart.is_empty():
		var wanted: bool = s >= float(plan.cart.s0) and s < float(plan.cart.s1)
		if wanted != player.in_cart:
			player.in_cart = wanted
			player.cart_lat = float(plan.cart.lat)
			events.append({"type": "cart_on" if wanted else "cart_off"})
	if _resolve_chase(player, step, events):
		return true
	var depth: float = world.fall_depth_at(player.s) if world.has_method("fall_depth_at") else TUNING.FALL_DEPTH
	if player.h < -depth:
		_rescue(player, events, "splash" if depth < 3.0 else "fall", true)
		return true
	return false


func _carry(player) -> void:
	if not player.grounded:
		return
	for index in range(plan.platforms.size()):
		var platform: Dictionary = plan.platforms[index]
		if str(platform.get("axis", "")).is_empty() and not bool(platform.get("crumble", false)):
			continue
		var offset: Vector3 = platform_offset(platform, clock)
		if player.s < float(platform.s0) + offset.x or player.s > float(platform.s1) + offset.x:
			continue
		if absf(player.lat - float(platform.lat) - offset.y) > float(platform.half) + 0.05:
			continue
		if absf(player.h - float(platform.top) - offset.z) > 0.08:
			continue
		if bool(platform.get("crumble", false)) and not crumbled.has(index):
			crumbled[index] = clock
		var before: Vector3 = platform_offset(platform, clock - 1.0 / 60.0)
		player.lat += offset.y - before.y
		player.s += offset.x - before.x


func _resolve_letters(player, events: Array[Dictionary]) -> void:
	var centre: float = player.h + TUNING.BODY_CENTRE
	for index in range(plan.letters.size()):
		if letters & (1 << index):
			continue
		var letter: Dictionary = plan.letters[index]
		if absf(player.s - float(letter.s)) > 1.4 or absf(player.lat - float(letter.lat)) > 1.4:
			continue
		if absf(centre - float(letter.h)) > 1.7:
			continue
		letters |= 1 << index
		events.append({"type": "letter", "index": index, "char": str(letter.char)})


func _grab_rides(player, events: Array[Dictionary]) -> void:
	var centre := Vector3(player.s, player.lat, player.h + TUNING.BODY_CENTRE)
	for index in range(plan.rides.size()):
		var ride: Dictionary = plan.rides[index]
		if absf(player.s - float(ride.s)) > 3.0 or clock < float(ride_ready_at.get(index, -INF)):
			continue
		var offset: Vector3 = centre - Vector3(float(ride.s), float(ride.lat), float(ride.h))
		var grab: bool = false
		match str(ride.kind):
			"barrel", "warp":
				grab = offset.length() <= TUNING.RIDE_GRAB_RADIUS
			"vine":
				grab = absf(offset.x) < 1.2 and absf(offset.y) < 1.4 and offset.z > -1.7 and offset.z < 1.5
			"zip":
				grab = absf(offset.x) < 1.2 and absf(offset.y) < 1.4 and absf(offset.z) < 1.4
		if grab:
			player.begin_ride(index, ride)
			_riding = index
			ride_ready_at[index] = INF
			events.append({"type": "ride", "index": index, "kind": str(ride.kind)})
			return


func _resolve_waits(player, step: float, events: Array[Dictionary]) -> void:
	for index in range(plan.waits.size()):
		if waits_done.has(index):
			continue
		var wait: Dictionary = plan.waits[index]
		var at: float = float(wait.s)
		if player.s < at - 10.0:
			continue
		if player.s > at + 0.3 or not player.grounded:
			waits_done[index] = true
			_wait_clock = 0.0
			continue
		if player.speed < 0.4:
			_wait_clock += step
			if _wait_clock >= float(wait.get("auto", 4.0)):
				# Nothing pressed for a while: Lumo shows it himself.
				player.press_jump()
				player.release_jump()
				events.append({"type": "demo", "action": str(wait.action)})
				_wait_clock = 0.0


func _resolve_chase(player, step: float, events: Array[Dictionary]) -> bool:
	if plan.chase.is_empty() or chase_done:
		return false
	var chase: Dictionary = plan.chase
	if not chase_active:
		if player.s >= float(chase.s0) and player.s < float(chase.s1):
			chase_active = true
			boulder_s = player.s - float(chase.gap)
			events.append({"type": "chase_start"})
		return false
	# The ball rolls up close behind Lumo and then stays there: it only catches
	# a Lumo who stops. Every catch makes it a little slower.
	var factor: float = maxf(0.55, float(chase.factor) - 0.08 * float(chase_catches))
	var roll: float = factor * TUNING.PATH_CRUISE
	if player.s - boulder_s > float(chase.get("near", 6.5)):
		roll = maxf(roll, maxf(player.speed, 3.0) + 2.5)
	boulder_s += roll * step
	if player.s >= float(chase.s1):
		chase_active = false
		chase_done = true
		events.append({"type": "chase_end", "escaped": true})
		return false
	if boulder_s + float(chase.radius) >= player.s - 0.2 and player.h < 2.2:
		chase_catches += 1
		chase_active = false
		if chase_catches >= TUNING.CHASE_HELP_AFTER_CATCHES:
			chase_done = true
		events.append({"type": "caught", "stuck": chase_done})
		rescues += 1
		player.respawn(float(chase.respawn), 0.0)
		player.in_cart = false
		_cursors.clear()
		_last_s = player.s
		return true
	return false


## Sets Lumo down at the last rescue point. After a few falls at the same spot
## he is carried to the next one: nobody gets stuck.
func _rescue(player, events: Array[Dictionary], cause: String, count_fall: bool) -> void:
	var index: int = maxi(0, rescue)
	var helped: bool = false
	if count_fall:
		var count: int = int(falls.get(index, 0)) + 1
		falls[index] = count
		if count > TUNING.PATH_HELP_AFTER_FALLS and index + 1 < plan.respawns.size():
			if float(plan.respawns[index + 1].s) > 0.0 or player.s < 0.0:
				index += 1
				helped = true
				rescue = index
	var point: Dictionary = plan.respawns[index] if index < plan.respawns.size() else {"s": plan.start_s, "lat": 0.0, "cart": false}
	rescues += 1
	stumbles += 1
	player.respawn(float(point.s), float(point.lat))
	player.in_cart = bool(point.get("cart", false))
	player.cart_lat = float(plan.cart.get("lat", 0.0))
	if chase_active:
		chase_active = false
	_cursors.clear()
	_last_s = player.s
	events.append({"type": "rescue", "cause": cause, "helped": helped, "index": index})


func _resolve_enemies(player, events: Array[Dictionary]) -> void:
	if player.is_riding() or player.tumble_time > 0.0:
		return
	for index in range(plan.enemies.size()):
		if defeated.has(index):
			continue
		var enemy: Dictionary = plan.enemies[index]
		if absf(player.s - float(enemy.s)) > float(enemy.amp) + float(enemy.span) + 4.0:
			continue
		var at: Vector2 = enemy_position(enemy, clock)
		var reach: float = float(enemy.radius) + 0.4
		if absf(player.s - at.x) > reach or absf(player.lat - at.y) > reach:
			continue
		var top: float = float(enemy.top)
		if player.h >= top:
			continue
		if not player.grounded and player.vy <= 0.0 and player.h >= top * 0.3:
			defeated[index] = true
			stomps += 1
			player.bounce(TUNING.STOMP_SPEED)
			events.append({"type": "stomp", "index": index, "kind": str(enemy.kind)})
			continue
		if player.invulnerable > 0.0:
			continue
		var hits: int = int(enemy_hits.get(index, 0)) + 1
		enemy_hits[index] = hits
		if hits >= TUNING.ENEMY_HELP_AFTER_HITS:
			defeated[index] = true
		if player.tumble():
			events.append({"type": "hit", "index": index, "kind": str(enemy.kind), "leaves": defeated.has(index)})
		return
