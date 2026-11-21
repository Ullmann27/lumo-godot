extends RefCounted
## Fips the squirrel races Lumo in every world of Lumo Lauf. This is only his
## race (where he is, how fast, when he hops); his look is run_rival_view.gd.
##
## Fips is the same squirrel the children know from the card table ("Fips",
## cards_seat.gd). In Lumo Kart the squirrel has no name of its own, so nobody
## else is meant by him.
##
## Fair by construction, everything in course time (the same clock that drives
## Lumo, so learning stops and the pause stop him as well):
##   * he runs his own steady pace (`pace` of the course in run_courses.gd) and
##     never adapts it to Lumo: no catching up from behind, no waiting ahead,
##     no shortcuts and no pushing - he keeps to his own lane;
##   * his pace is set per world so that a clean run wins clearly and a run
##     with two falls can still win (lumo_run_rival_regression measures both
##     with the real inputs), while a child who holds back loses the race;
##   * he hops over everything in his lane (hurdles, rocks, ditches, holes) at
##     his pace, so his time is the same in every race: a fixed, honest target;
##   * while Lumo is in the secret treasure hall of an adventure path, Fips
##     waits at his place (exploring never costs the race).
## On road courses he starts beside Lumo at the start line; on an adventure
## path he waits where the introduction ends and starts as Lumo comes by.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")

var plan
var world
var track
var display_name: String = ""
## Course-time pace in m/s (0: no rival on this course).
var pace: float = 0.0
var s: float = 0.0
var lat: float = 0.0
var h: float = 0.0
var speed: float = 0.0
var start_s: float = 0.0
var started: bool = false
var finished: bool = false
## Course time of the race start and of his arrival (or -1).
var start_clock: float = -1.0
var finish_clock: float = -1.0
## True while Lumo is in front of him.
var behind: bool = false
var overtakes: int = 0
var passes: int = 0
var waiting: bool = false
var hopping: bool = false
var _hop_from: float = 0.0
var _hop_to: float = 0.0
var _hop_height: float = 0.0
var _spans: Array[Vector2] = []
var _swap_cooldown: float = 0.0
var _lane: float = 0.0


func setup(course_plan, race_world, race_track, course: Dictionary) -> void:
	plan = course_plan
	world = race_world
	track = race_track
	var rival: Dictionary = course.get("rival", {})
	display_name = str(rival.get("name", ""))
	pace = float(rival.get("pace", 0.0))
	start_s = plan.intro_end if plan.adventure else plan.start_s
	_collect_spans()
	reset()


func enabled() -> bool:
	return pace > 0.0 and not display_name.is_empty()


func reset() -> void:
	started = false
	finished = false
	start_clock = -1.0
	finish_clock = -1.0
	behind = false
	waiting = false
	hopping = false
	overtakes = 0
	passes = 0
	speed = 0.0
	s = start_s
	_lane = TUNING.RIVAL_LANE
	lat = _lane
	h = 0.0


## Holes, ditches and gaps along the way: he hops over each in one go.
func _collect_spans() -> void:
	_spans.clear()
	if plan.adventure and world.get("level") != null:
		for gap in world.level.gaps:
			_spans.append(Vector2(gap.x, gap.y))
	for channel in plan.channels:
		_spans.append(Vector2(float(channel.s0), float(channel.s1)))
	_spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)


## Course seconds he needs from his start to the finish (his fixed target).
func race_seconds() -> float:
	if not enabled():
		return 0.0
	var distance: float = plan.finish_s - start_s
	# Accelerating from standstill costs half the time of the run-up.
	var run_up: float = pace / TUNING.RIVAL_ACCELERATION
	return distance / pace + run_up * 0.5


## Called at the end of the countdown: on a road course the race starts now.
func start_road_race(clock: float) -> void:
	if enabled() and not plan.adventure and not started:
		_begin(clock)


func _begin(clock: float) -> void:
	started = true
	start_clock = clock
	speed = 0.0


## One step in course time. Returns what happened for the game to show.
func step(delta: float, player, clock: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not enabled() or finished:
		return events
	_swap_cooldown = maxf(0.0, _swap_cooldown - delta)
	if not started:
		_steer(delta, player)
		if plan.adventure and player.s >= start_s - TUNING.RIVAL_PATH_CALL:
			_begin(clock)
			events.append({"type": "rival_start"})
		return events
	waiting = plan.adventure and (player.s < 0.0 or world.is_bonus(player.s))
	if waiting:
		speed = 0.0
		return events
	speed = minf(pace, speed + TUNING.RIVAL_ACCELERATION * delta)
	s += speed * delta
	_steer(delta, player)
	_hop()
	if _swap_cooldown <= 0.0:
		if not behind and player.s > s + 1.0:
			behind = true
			passes += 1
			_swap_cooldown = TUNING.RIVAL_SWAP_COOLDOWN
			events.append({"type": "rival_passed"})
		elif behind and s > player.s + 1.0:
			behind = false
			overtakes += 1
			_swap_cooldown = TUNING.RIVAL_SWAP_COOLDOWN
			events.append({"type": "rival_ahead"})
	if s >= plan.finish_s:
		s = plan.finish_s
		finished = true
		finish_clock = clock - (s - plan.finish_s) / maxf(speed, 0.1)
		events.append({"type": "rival_finish"})
	return events


## After the finish: he runs on into his place beside the finish gate.
func coast(delta: float) -> void:
	if not enabled():
		return
	var stop: float = plan.finish_s + TUNING.RIVAL_FINISH_SPOT
	if s >= stop:
		speed = 0.0
		h = 0.0
		return
	if not finished:
		speed = minf(pace, speed + TUNING.RIVAL_ACCELERATION * delta)
	else:
		speed = clampf((stop - s) * 1.6, 0.0, maxf(speed, 2.0))
	s = minf(stop, s + speed * delta)
	_hop()
	_lane = TUNING.RIVAL_LANE
	lat = move_toward(lat, _lane, 2.0 * delta)


## Course time of his arrival: known when he is in, else computed from his pace.
func arrival_clock(clock: float) -> float:
	if finish_clock >= 0.0:
		return finish_clock
	if not started:
		return INF
	var left: float = maxf(0.0, plan.finish_s - s)
	var run_up: float = maxf(0.0, pace - speed) / TUNING.RIVAL_ACCELERATION
	return clock + left / pace + run_up * 0.5


## Metres he is ahead of Lumo (negative: behind).
func gap_to(player_s: float) -> float:
	return s - player_s


## He keeps to his own lane, on the other side from Lumo when they are close,
## so he never stands in Lumo's way or hides what Lumo has to read.
func _steer(delta: float, player) -> void:
	var half: float = maxf(0.0, float(world.wall_lateral_at(s)) - (0.6 if plan.adventure else 0.9))
	var wish: float = TUNING.RIVAL_LANE
	if absf(s - player.s) < TUNING.RIVAL_KEEP_AWAY:
		var side: float = signf(player.lat) if absf(player.lat) > 0.3 else -signf(_lane)
		if side == 0.0:
			side = -1.0
		wish = -side * TUNING.RIVAL_LANE
	if not plan.loop.is_empty():
		var loop_s: float = float(plan.loop.start)
		if s > loop_s - 40.0 and s < loop_s + 20.0:
			wish = -signf(float(plan.loop.lane)) * TUNING.RIVAL_LANE * 1.2
	_lane = move_toward(_lane, clampf(wish, -half, half), 3.0 * delta)
	lat = clampf(_lane, -half, half)


## Height above the way: a hop over every hole, ditch, hurdle and rock in his lane.
func _hop() -> void:
	if hopping:
		if s >= _hop_to:
			hopping = false
		else:
			var u: float = clampf((s - _hop_from) / maxf(0.1, _hop_to - _hop_from), 0.0, 1.0)
			h = _ground(s) + _hop_height * 4.0 * u * (1.0 - u)
			return
	h = _ground(s)
	var reach: float = maxf(speed, 4.0) * 0.18 + 0.6
	var block: Vector2 = _obstacle(s, s + reach)
	if block.y <= block.x:
		return
	hopping = true
	_hop_from = s
	_hop_to = block.y + 0.9
	var span: float = _hop_to - _hop_from
	_hop_height = clampf(0.7 + 0.16 * span, 0.9, 3.6)
	if plan.adventure:
		var roof: float = float(world.ceiling_at((_hop_from + _hop_to) * 0.5))
		if roof < INF:
			_hop_height = clampf(roof - 1.9, 0.6, _hop_height)


func _ground(at: float) -> float:
	if plan.adventure:
		return 0.0
	return float(world.ramp_height(at))


## The next thing in his lane between `from` and `to`, as the stretch to clear.
func _obstacle(from: float, to: float) -> Vector2:
	for span in _spans:
		if span.y < from:
			continue
		if span.x > to:
			break
		return Vector2(maxf(from, span.x), span.y)
	for hurdle in plan.hurdles:
		var at: float = float(hurdle.s)
		if at < from - 0.5:
			continue
		if at > to:
			break
		if absf(lat - float(hurdle.lat)) <= float(hurdle.half) + 0.4:
			return Vector2(at - 0.6, at + 0.6)
	for index in range(plan.blockers.size()):
		var blocker: Dictionary = plan.blockers[index]
		var at: float = float(blocker.s)
		if at < from - 0.8:
			continue
		if at > to:
			break
		if track.broken.has(index):
			continue
		var centre: float = track.blocker_lateral(blocker, track.clock)
		if absf(lat - centre) <= float(blocker.radius) + 0.45:
			return Vector2(at - float(blocker.radius), at + float(blocker.radius))
	return Vector2.ZERO


func snapshot() -> Dictionary:
	return {"rival_s": s, "rival_started": started, "rival_behind": behind}


## Puts him back where he was at the saved checkpoint.
func restore(state: Dictionary, clock: float) -> void:
	if not enabled() or not state.has("rival_s"):
		return
	s = clampf(float(state.rival_s), start_s, plan.finish_s - 0.1)
	started = bool(state.get("rival_started", false))
	behind = bool(state.get("rival_behind", false))
	if started:
		speed = pace
		start_clock = clock
