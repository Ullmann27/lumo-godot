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
	_cursors.clear()
	_last_s = -1.0


# ------------------------------------------------------------------ questions of the motion model

func grade_at(s: float) -> float:
	return float(world.forward(s).y)


## Height of the surface Lumo can stand on, relative to the road. `feet` is the
## height his feet come from, so platforms only catch him from above.
func ground_at(s: float, lat: float, feet: float) -> float:
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
	var on_ground: bool = player.grounded
	if _resolve_gaps(player, events):
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
			if player.boost(TUNING.BOOST_SECONDS):
				events.append({"type": "boost", "index": index})
	_resolve_hurdles(player, events)
	_resolve_blockers(player, time, events)
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
	_cursors.clear()
	_last_s = -1.0
