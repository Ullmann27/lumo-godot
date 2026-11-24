extends RefCounted
## Deterministic content of one Lumo-Lauf course, derived from the kart world it runs
## through. Everything is expressed in road space: metres along the course (`s`),
## metres to the right of the centre line (`lat`) and metres above the road (`h`).
##
## The plan only describes; the view (run_props.gd) draws it and the track state
## (run_track.gd) plays it. The same course and seed always give the same plan.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const ACTION = preload("res://scripts/games/kart_action_course.gd")
const LOOP = preload("res://scripts/games/kart_physical_loop.gd")

const START_S: float = 14.0
const FINISH_MARGIN: float = 12.0
const STAR_HEIGHT: float = 1.0
const STAR_SPACING: float = 3.0
## Metres of the last stretch of a road course that belong to its finale
## (see _place_finale): the call, the run-up to the launch, the flight and the
## run-in through the finish gate.
const FINALE_LENGTH: float = 140.0
## Metres from the ENDSPURT call to where the launch is in reach (`go`).
const FINALE_CALL: float = 48.0
## Metres from `go` to the launch.
const FINALE_RUN_UP: float = 16.0
## Covered stretches of Dschungelherz (waterfall cave and root grotto): no high flights.
const JUNGLE_COVERED: Array[Vector2] = [Vector2(920.0, 1520.0)]

var course: Dictionary = {}
var length: float = 0.0
var start_s: float = START_S
var finish_s: float = 0.0
var star_s := PackedFloat32Array()
var star_lat := PackedFloat32Array()
var star_h := PackedFloat32Array()
var star_value := PackedInt32Array()
var star_total: int = 0
var hurdles: Array[Dictionary] = []
var blockers: Array[Dictionary] = []
var channels: Array[Dictionary] = []
var bounces: Array[Dictionary] = []
var boosts: Array[Dictionary] = []
var platforms: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var loop: Dictionary = {}
var covered: Array[Vector2] = []
var beats: Array[Dictionary] = []
## Adventure courses (Dschungelherz): a hand-built path with more mechanics.
var adventure: bool = false
var star_route := PackedStringArray()
var enemies: Array[Dictionary] = []
var rides: Array[Dictionary] = []
var letters: Array[Dictionary] = []
var respawns: Array[Dictionary] = []
var waits: Array[Dictionary] = []
var coaches: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var branches: Array[Dictionary] = []
var passages: Array[Dictionary] = []
## Early highlights: announce, act, react (see run_moments.gd).
var moments: Array[Dictionary] = []
var decor: Array[Dictionary] = []
var chase: Dictionary = {}
var cart: Dictionary = {}
var bonus: Dictionary = {}
var intro_end: float = 0.0
var signature: String = ""
var _reserved: Array[Vector2] = []
var _opening_highlight: bool = false
var _rng := RandomNumberGenerator.new()
var _world


static func build(world, selected: Dictionary):
	var plan = new()
	plan._generate(world, selected)
	return plan


func _generate(world, selected: Dictionary) -> void:
	_world = world
	course = selected
	length = float(world.length)
	finish_s = length - FINISH_MARGIN
	_rng.seed = int(selected.get("seed", 1))
	if world.get("level") != null:
		_adopt_level(world.level)
	else:
		_reserve(finish_s - 38.0, length)
		_adopt_world_features()
		_place_finale(str(selected.get("theme", "")))
		var opening_end: float = _place_opening(str(selected.get("theme", "")))
		_reserve(0.0, opening_end)
		_place_checkpoints()
		_place_beats()
		# The opening stretch is reserved from procedural obstacles. Give both
		# road courses an immediate, centered speed strip before the first beat.
		boosts.append({"s0": start_s + 8.0, "s1": start_s + 12.0,
			"lat": 0.0, "half": 3.0, "seconds": TUNING.PATH_PAD_SECONDS})
	_sort_all()
	moments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.cue) < float(b.cue))
	star_total = 0
	for value in star_value:
		star_total += value
	for blocker in blockers:
		if str(blocker.kind) == "crate":
			star_total += TUNING.CRATE_STARS
	# Bonus stars of the learning stops count towards the full score as well.
	star_total += question_checkpoints().size() * TUNING.QUESTION_BONUS_STARS
	signature = _signature()
	_world = null


# ------------------------------------------------------------------ hand-built adventure path

func _adopt_level(level) -> void:
	adventure = true
	start_s = float(level.start_s)
	finish_s = float(level.finish_s)
	intro_end = float(level.intro_end)
	for star in level.stars:
		star_s.append(float(star.s))
		star_lat.append(float(star.lat))
		star_h.append(float(star.h))
		star_value.append(int(star.value))
		star_route.append(str(star.route))
	hurdles.assign(level.hurdles.duplicate(true))
	blockers.assign(level.blockers.duplicate(true))
	bounces.assign(level.bounces.duplicate(true))
	platforms.assign(level.platforms.duplicate(true))
	enemies.assign(level.enemies.duplicate(true))
	rides.assign(level.rides.duplicate(true))
	letters.assign(level.letters.duplicate(true))
	respawns.assign(level.respawns.duplicate(true))
	waits.assign(level.waits.duplicate(true))
	coaches.assign(level.coaches.duplicate(true))
	sections.assign(level.sections.duplicate(true))
	branches.assign(level.branches.duplicate(true))
	passages.assign(level.passages.duplicate(true))
	if level.get("moments") != null:
		moments.assign(level.moments.duplicate(true))
	decor.assign(level.decor.duplicate(true))
	checkpoints.assign(level.checkpoints.duplicate(true))
	for roof in level.ceilings:
		covered.append(Vector2(roof.x, roof.y))
	chase = level.chase.duplicate(true)
	cart = level.cart.duplicate(true)
	bonus = level.bonus.duplicate(true)
	_speed_pads(level)


## Speed pads (Sonic-like) at the start of long stretches with nothing to dodge
## or jump: no hole, log, enemy, platform, pad, ride, wait or gate for
## PATH_PAD_CLEAR metres. Deterministic; a few dozen metres apart at least.
func _speed_pads(level) -> void:
	var busy: Array[Vector2] = []
	for gap in level.gaps:
		busy.append(Vector2(gap.x - 6.0, gap.y + 2.0))
	for list in [level.hurdles, level.blockers, level.bounces, level.waits]:
		for item in list:
			busy.append(Vector2(float(item.s) - 6.0, float(item.s) + 3.0))
	for enemy in level.enemies:
		var reach: float = absf(float(enemy.get("span", 0.0))) + 4.0
		busy.append(Vector2(float(enemy.s) - reach - 6.0, float(enemy.s) + reach))
	for platform in level.platforms:
		busy.append(Vector2(float(platform.s0) - 8.0, float(platform.s1) + 2.0))
	for ride in level.rides:
		busy.append(Vector2(float(ride.s) - 8.0, float(ride.get("ts", ride.s)) + 4.0))
	for point in level.checkpoints:
		busy.append(Vector2(float(point.s) - 8.0, float(point.s) + 4.0))
	for surface in level.surfaces:
		if str(surface.kind) in ["rail", "gap"]:
			busy.append(Vector2(float(surface.s0) - 4.0, float(surface.s1) + 4.0))
	if not level.chase.is_empty():
		busy.append(Vector2(float(level.chase.s0) - 10.0, float(level.chase.s1) + 4.0))
	var at: float = maxf(float(level.intro_end) + 10.0, 40.0)
	var last: float = -INF
	while at < float(level.finish_s) - TUNING.PATH_PAD_CLEAR:
		var clear: bool = at - last >= TUNING.PATH_PAD_SPACING
		if clear:
			for span in busy:
				if span.x < at + TUNING.PATH_PAD_CLEAR and span.y > at:
					clear = false
					break
		if clear:
			boosts.append({"s0": at, "s1": at + TUNING.PATH_PAD_LENGTH, "lat": 0.0, "half": 3.0, "pad": true, "seconds": TUNING.PATH_PAD_SECONDS})
			last = at
			at += TUNING.PATH_PAD_LENGTH
		at += 2.0


## Index of the last rescue point at or behind `at` (on the main path or in the bonus hall).
func respawn_index(at: float) -> int:
	var found: int = -1
	for index in range(respawns.size()):
		if float(respawns[index].s) <= at + 0.01:
			found = index
	return found


# ------------------------------------------------------------------ what the world already has

func _adopt_world_features() -> void:
	var world = _world
	if str(world.track_id) == "jungle_emerald_3600":
		covered.append_array(JUNGLE_COVERED)
	for dive in world.action.get("dives", []):
		covered.append(Vector2(float(dive.start) - 6.0, float(dive.end) + 6.0))
	if not world.adventure_tunnel.is_empty():
		covered.append(
			Vector2(float(world.adventure_tunnel.start) - 8.0, float(world.adventure_tunnel.end) + 8.0)
		)
	if not world.production_tunnel_layout.is_empty():
		covered.append(
			Vector2(
				float(world.production_tunnel_layout.start) - 8.0,
				float(world.production_tunnel_layout.end) + 8.0
			)
		)
	# Cones and rocks the kart course already shows are solid for Lumo as well.
	for at in world.action_obstacles:
		var road: Dictionary = world.sample_road(at)
		var along: float = float(road.distance)
		blockers.append(_blocker(along, float(road.lateral), 0.7, 1.3, "existing"))
		_reserve(along - 14.0, along + 10.0)
	var gates: Array = world.action.get("gates", [])
	for gate in gates:
		var along: float = float(gate.distance)
		for lateral in ACTION.pylon_laterals(gate):
			blockers.append(_blocker(along, float(lateral), ACTION.PYLON_RADIUS, 1.3, "existing"))
		_reserve(along - 12.0, along + 10.0)
		_star(along, float(gate.lateral), STAR_HEIGHT)
		_star(along - 5.0, float(gate.lateral) * 0.6, STAR_HEIGHT)
	for pad in world.action.get("pads", []):
		boosts.append(
			{
				"s0": float(pad.start),
				"s1": float(pad.end),
				"lat": float(pad.lateral),
				"half": ACTION.PAD_HALF_WIDTH,
				"existing": true,
			}
		)
		_reserve(float(pad.start) - 10.0, float(pad.end) + 14.0)
	for kicker in world.action.get("kickers", []):
		if bool(kicker.get("precision_jump", false)):
			_adopt_big_jump(kicker)
		else:
			_adopt_ramp(kicker)
	if not world.loop_layout.is_empty():
		_adopt_loop(world.loop_layout)


## A kart ramp with road underneath: a star line up the ramp and an arc over the flight.
func _adopt_ramp(kicker: Dictionary) -> void:
	var start: float = float(kicker.start)
	var lip: float = float(kicker.take_off)
	var height: float = float(kicker.height)
	_reserve(start - 16.0, lip + 26.0)
	# The line runs to one side of the ramp, so it has to be steered for.
	var lane: float = (2.2 + _rng.randf() * 0.8) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	_trail(start - 12.0, start - 1.0, 0.0, lane)
	for step in range(3):
		var along: float = start + (lip - start) * (float(step) + 0.5) / 3.0
		_star(along, lane, height * (along - start) / (lip - start) + STAR_HEIGHT)
	for step in range(4):
		var u: float = (float(step) + 0.5) / 4.0
		_star(lip + 0.6 + u * 7.0, lane, height * (1.0 - u) + STAR_HEIGHT + 1.2 * 4.0 * u * (1.0 - u))


## Sonnenhafen's real opening in the road. A full-width boost strip and a launch
## band at the lip carry Lumo across; missing it is caught like every other gap.
func _adopt_big_jump(kicker: Dictionary) -> void:
	var start: float = float(kicker.start)
	var lip: float = float(kicker.take_off)
	var height: float = float(kicker.height)
	var gap_end: float = float(kicker.gap_end)
	var strip_start: float = start - 26.0
	_reserve(strip_start - 16.0, gap_end + 30.0)
	boosts.append({"s0": strip_start, "s1": strip_start + 6.0, "lat": 0.0, "half": 20.0})
	var launch_s: float = lip - 0.9
	bounces.append(
		{"s": launch_s, "lat": 0.0, "radius": 1.3, "half": 20.0, "power": TUNING.LAUNCH_SPEED, "band": true}
	)
	channels.append(
		{
			"s0": float(kicker.gap_start) - 0.2,
			"s1": gap_end,
			"real": true,
			"respawn": strip_start - 5.0,
			"exit": gap_end + 4.0,
		}
	)
	var lane: float = 2.4 if _rng.randf() < 0.5 else -2.4
	_trail(strip_start - 8.0, start - 1.0, 0.0, lane)
	var flight: float = TUNING.flight_seconds(TUNING.LAUNCH_SPEED, height)
	var speed: float = TUNING.CRUISE + TUNING.BOOST_BONUS * 0.6
	for step in range(8):
		var t: float = flight * (float(step) + 0.6) / 8.6
		var above: float = height + TUNING.flight_height(TUNING.LAUNCH_SPEED, t)
		var value: int = TUNING.GOLD_STAR_VALUE if step == 3 else 1
		_star(launch_s + speed * t, lane, maxf(STAR_HEIGHT, above + 0.6), value)


## Adopt the complete shared path, including the exterior approach and return.
## Legacy in-road loops still need their two feet kept clear; a branch only
## needs a choice of entry lane and a free main-road bypass.
func _adopt_loop(layout: Dictionary) -> void:
	var start: float = float(layout.start)
	var lane: float = float(layout.lane)
	var half: float = LOOP.half_width_of(layout)
	var exit_lane: float = LOOP.exit_lane(layout)
	var exit_s: float = LOOP.road_distance_at(layout, 1.0)
	var branch: bool = bool(layout.get("branch", false))
	var distances := PackedFloat32Array()
	distances.resize(LOOP.ARC_SEGMENTS + 1)
	distances[0] = 0.0
	var previous: Vector3 = LOOP.point(_world, layout, 0.0)
	for index in range(1, LOOP.ARC_SEGMENTS + 1):
		var current: Vector3 = LOOP.point(_world, layout, float(index) / LOOP.ARC_SEGMENTS)
		distances[index] = distances[index - 1] + previous.distance_to(current)
		previous = current
	loop = {
		"start": start,
		"lane": lane,
		"tolerance": maxf(0.1, half - TUNING.BODY_RADIUS - 0.08) if branch else half + 0.35,
		"exit_s": exit_s,
		"exit_lane": exit_lane,
		"layout": layout,
		"branch": branch,
		"arc_lengths": distances,
	}
	_reserve(start - 52.0, exit_s + 27.0)
	_trail(start - 46.0, start - 3.0, 0.0, lane)
	_star(exit_s + 1.2, exit_lane, STAR_HEIGHT, TUNING.GOLD_STAR_VALUE)
	_trail(exit_s + 5.0, exit_s + 23.0, exit_lane, 0.0)
	if branch:
		return
	# Rising quarter above the entry lane and descending quarter above the exit lane.
	zones.append(
		{"s0": start - 0.5, "s1": start + 9.0, "lat0": lane - half - 0.45, "lat1": 99.0, "lead": 0.0, "rider": true}
	)
	zones.append(
		{
			"s0": start - 3.0,
			"s1": start + 7.0,
			"lat0": exit_lane - half - 0.45,
			"lat1": exit_lane + half + 0.45,
			"lead": 14.0,
			"rider": false,
		}
	)


# ------------------------------------------------------------------ checkpoints

func _place_checkpoints() -> void:
	var count: int = clampi(roundi(length / 400.0), 4, 9)
	var questions: Array[int] = []
	for share in [0.25, 0.5, 0.75]:
		var index: int = clampi(roundi(float(count + 1) * float(share)) - 1, 0, count - 1)
		while questions.has(index) and index < count - 1:
			index += 1
		questions.append(index)
	for index in range(count):
		var wish: float = lerpf(start_s, finish_s, float(index + 1) / float(count + 1))
		var along: float = wish
		for attempt in range(30):
			if _free(along - 16.0, along + 14.0):
				break
			along = wish + float(attempt / 2 + 1) * 8.0 * (1.0 if attempt % 2 == 0 else -1.0)
		checkpoints.append({"s": along, "question": questions.has(index), "index": index})
		_reserve(along - 18.0, along + 16.0)
	checkpoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))
	for index in range(checkpoints.size()):
		checkpoints[index]["index"] = index
		checkpoints[index]["question"] = questions.has(index)


# ------------------------------------------------------------------ opening highlights

## The first metres of a road course: a choice of two star lines within the
## first seconds, then the world's own highlight (announce, act, react).
## Returns where the reserved opening ends (the beats follow after it).
func _place_opening(look: String) -> float:
	var plain: float = start_s + 34.0
	if look != "forest" and look != "harbour":
		return plain
	var end: float = start_s + 140.0
	if not _free(start_s, end):
		return plain
	var usable: float = float(_world.wall_lateral_at(start_s + 70.0)) - 0.9
	var lane: float = clampf(usable * 0.55, 1.6, 2.4)
	_opening_highlight = true
	if look == "forest":
		# The mushroom way on the right: the left verge has low branches.
		return _mushroom_hops(start_s + 70.0, lane, -lane) + 4.0
	return _wave_jump(start_s + 94.0, lane) + 4.0


## Zauberwald: three glowing mushrooms on one side (`upper`, the right since
## 19.11.) hop Lumo up onto the upper way with gold stars; on the other side
## the low way with a log to jump. Both ways
## meet again behind the upper way.
func _mushroom_hops(first: float, upper: float, lower: float) -> float:
	var flight: float = TUNING.flight_seconds(TUNING.BOUNCE_SPEED)
	var hop: float = TUNING.CRUISE * flight
	var third: float = first + 2.0 * hop
	var top: float = 2.6
	var deck_end: float = third + 28.0
	_trail(start_s + 20.0, first - 3.0, 0.0, upper)
	_trail(start_s + 26.0, first + 6.0, 0.0, lower)
	for index in range(3):
		var at: float = first + float(index) * hop
		var power: float = TUNING.HIGH_PATH_BOUNCE_SPEED if index == 2 else TUNING.BOUNCE_SPEED
		bounces.append({"s": at, "lat": upper, "radius": 1.3, "half": 1.3, "power": power, "look": "glow_mushroom"})
		if index < 2:
			for step in range(5):
				var t: float = flight * (float(step) + 0.8) / 5.6
				var value: int = TUNING.GOLD_STAR_VALUE if index == 1 and step == 2 else 1
				_star(at + TUNING.CRUISE * t, upper, STAR_HEIGHT + TUNING.flight_height(TUNING.BOUNCE_SPEED, t), value)
	platforms.append({"s0": third + 5.5, "s1": deck_end, "lat": upper, "half": 1.8, "top": top})
	var along: float = third + 9.0
	while along < deck_end - 2.0:
		_star(along, upper, top + STAR_HEIGHT)
		along += STAR_SPACING
	_star(deck_end - 1.0, upper, top + STAR_HEIGHT + 0.2, TUNING.GOLD_STAR_VALUE)
	# The low way: a log to jump, a plain line of stars.
	_hurdle(first + hop, lower, 1.6)
	_arc(first + hop - 3.6, first + hop + 3.6, lower, 2.1, 5)
	_trail(first + hop + 6.0, deck_end - 2.0, lower, lower)
	_trail(deck_end + 2.0, deck_end + 9.0, upper, 0.0)
	moments.append({
		"id": "pilzsprung", "name": "Leuchtpilz-Sprünge", "need": "upper", "height": 2.0, "look": "mushroom",
		"cue": start_s + 24.0, "go": first - 14.0, "s0": first - 2.0, "s1": deck_end,
		"lat": upper, "arch_s": first - 5.0, "colour": "7dffe6", "coach": "bounce",
		"say": "Leuchtpilze! Rechts hüpfen – oben warten Goldsterne.",
		"done_say": "Der obere Weg – Goldsterne!", "miss_say": "Unten lang – auch gut!",
	})
	return deck_end + 9.0


## Sonnenhafen: first the choice between a line of stars (left) and a turbo
## strip (right), then the wave: a full-width turbo strip, SPRINGEN at the glowing
## ring and over the rolling wave onto the landing target.
func _wave_jump(edge: float, lane: float) -> float:
	var gap: float = 5.0
	var strip: float = edge - 22.0
	_trail(start_s + 20.0, start_s + 50.0, 0.0, -lane)
	boosts.append({"s0": start_s + 34.0, "s1": start_s + 39.0, "lat": lane, "half": 1.5, "seconds": 0.8})
	_trail(start_s + 22.0, start_s + 32.0, 0.0, lane, 2.5)
	_trail(start_s + 52.0, strip - 3.0, -lane, 0.0)
	boosts.append({"s0": strip, "s1": strip + 6.0, "lat": 0.0, "half": 20.0})
	channels.append({"s0": edge, "s1": edge + gap, "real": false, "respawn": strip + 8.0, "exit": edge + gap + 3.0, "look": "wave"})
	var land: float = edge + gap + 4.5
	# Star arc over the wave, the gold star at its top.
	for step in range(7):
		var u: float = float(step) / 6.0
		var value: int = TUNING.GOLD_STAR_VALUE if step == 3 else 1
		_star(lerpf(edge - 3.0, land - 1.0, u), 0.0, STAR_HEIGHT + 2.0 * 4.0 * u * (1.0 - u), value)
	_trail(land + 4.0, land + 14.0, 0.0, lane * 0.6)
	moments.append({
		"id": "wellensprung", "name": "Wellensprung", "need": "clear", "look": "wave",
		"cue": start_s + 56.0, "go": edge - 12.5, "s0": edge - 4.0, "s1": edge + gap,
		"lat": 0.0, "arch_s": edge - 0.6, "colour": "ffb648", "coach": "jump",
		"land_s": land, "land_lat": 0.0, "boost": 1.0,
		"say": "Welle voraus! Über den Turbostreifen – am Ring SPRINGEN!",
		"done_say": "Toller Wellensprung!", "miss_say": "Platsch! Nochmal – am Ring springen.",
	})
	return land + 14.0


# ------------------------------------------------------------------ finale

## The last stretch of a road course, its own moment (run_moments.gd, flagged
## `finale`), FINALE_LENGTH metres before the finish:
##   ANKÜNDIGUNG  ENDSPURT, one sentence, light posts in the world colour on
##                both sides from here to the finish gate (run_moment_props.gd)
##   AKTION       a full-width turbo strip, then the world's last launch
##                across the whole way: Lumo only has to run onto it
##   REAKTION     a high flight over water along a star arc with a gold star at
##                its top, a landing target ("Volltreffer!"), a push and a star
##                line through the finish gate, where ZIEL! slows the picture
##                down (lumo_run.gd, _finish_moment).
##   Zauberwald "Sternentor": a row of glowing mushrooms over the whole width
##     throws Lumo over the star brook (BOUNCE_SPEED: 1.02 s in the air, the
##     brook is 6 m and begins 2 m behind the caps).
##   Sonnenhafen "Hafensprung": the launch band across the quay throws him over
##     the harbour basin with its rolling wave (LAUNCH_SPEED: 1.12 s in the air,
##     the basin is 8 m and begins 1.5 m behind the band).
## The launch is fair for every child: it covers the whole width, takes Lumo
## after an early SPRINGEN as well (`catch`) and carries a slow runner
## (`carry`); should he still splash, the moment stays armed a few metres back.
## No coach icon: the launch speaks for itself (and nothing covers the banner).
func _place_finale(look: String) -> void:
	if look != "forest" and look != "harbour":
		return
	var start: float = finish_s - FINALE_LENGTH
	for attempt in range(8):
		if _free(start - 6.0, finish_s - 38.0):
			break
		start -= 12.0
	if not _free(start - 6.0, finish_s - 38.0):
		return
	_reserve(start - 6.0, finish_s)
	var forest: bool = look == "forest"
	var gap: float = 6.0 if forest else 8.0
	var launch: float = start + FINALE_CALL + FINALE_RUN_UP
	var edge: float = launch + (2.0 if forest else 1.5)
	var power: float = TUNING.BOUNCE_SPEED if forest else TUNING.LAUNCH_SPEED
	boosts.append({"s0": start + 14.0, "s1": start + 20.0, "lat": 0.0, "half": 20.0})
	_trail(start + 2.0, start + 12.0, 0.0, 0.0)
	_trail(start + 23.0, launch - 3.0, 0.0, 0.0)
	if forest:
		# Glowing mushrooms side by side from rail to rail.
		var half: float = float(_world.wall_lateral_at(launch)) + 0.25
		var count: int = ceili(half * 2.0 / 2.2)
		var spacing: float = half * 2.0 / float(count)
		for lane in range(count):
			bounces.append(
				{
					"s": launch, "lat": -half + spacing * (float(lane) + 0.5), "radius": 1.3,
					"half": spacing * 0.5 + 0.1, "power": power, "look": "glow_mushroom",
					"catch": true, "carry": true,
				}
			)
	else:
		bounces.append(
			{
				"s": launch, "lat": 0.0, "radius": 1.3, "half": 20.0, "power": power, "band": true,
				"catch": true, "carry": true,
			}
		)
	channels.append(
		{
			"s0": edge, "s1": edge + gap, "real": false, "respawn": start + 24.0, "exit": edge + gap + 3.0,
			"look": "" if forest else "wave",
		}
	)
	# The arc follows the flight at the pace the turbo and the launch leave him.
	var flight: float = TUNING.flight_seconds(power)
	var speed: float = TUNING.CRUISE + TUNING.BOOST_BONUS * 0.6
	var land: float = launch + speed * flight
	for step in range(9):
		var t: float = flight * (float(step) + 0.7) / 9.4
		var value: int = TUNING.GOLD_STAR_VALUE if step == 4 else 1
		_star(launch + speed * t, 0.0, STAR_HEIGHT + TUNING.flight_height(power, t), value)
	_trail(land + 4.0, finish_s - 6.0, 0.0, 0.0)
	_star(finish_s - 4.0, 0.0, STAR_HEIGHT + 0.6, TUNING.GOLD_STAR_VALUE)
	moments.append(
		{
			"id": "sternentor" if forest else "hafensprung",
			"name": "Sternentor" if forest else "Hafensprung",
			"finale": true, "need": "clear", "look": "" if forest else "wave",
			"cue": start, "go": start + FINALE_CALL, "s0": launch - 2.0, "s1": edge + gap,
			"lat": 0.0, "arch_s": launch - 4.0, "colour": "b9a6ff" if forest else "ffd23a",
			"coach": "", "land_s": land, "land_lat": 0.0, "boost": 1.0, "lane_to": finish_s,
			"say": (
				"Über die Leuchtpilze ins Sternentor!" if forest
				else "Übers Sprungband – mit einem Satz ins Ziel!"
			),
			"done_say": "Was für ein Zielsprung!",
			"miss_say": (
				"Platsch! Noch einmal – lauf über die Pilze." if forest
				else "Platsch! Noch einmal – lauf übers Sprungband."
			),
		}
	)


# ------------------------------------------------------------------ beats

func _place_beats() -> void:
	var along: float = start_s + 20.0
	var lateral: float = 0.0
	var last: String = ""
	var opening: Array[String] = ["trail", "hurdle", "boost", "channel"]
	if _opening_highlight:
		# Right after a highlight the next task follows without an empty stretch.
		opening = ["hurdle", "boost", "channel"]
	var end: float = finish_s - 40.0
	while along < end:
		var blocked_until: float = _blocked_until(along, along + 30.0)
		if blocked_until > along:
			along = blocked_until + 2.0
			continue
		var kind: String
		if not opening.is_empty():
			kind = opening.pop_front()
		else:
			kind = _pick(along, last)
		var span: float = _span_of(kind)
		if _blocked_until(along, along + span) > along:
			kind = "trail"
			span = 30.0
		var usable: float = float(_world.wall_lateral_at(along + span * 0.5)) - 0.9
		lateral = clampf(lateral, -usable * 0.8, usable * 0.8)
		beats.append({"s": along, "kind": kind})
		lateral = _place(kind, along, span, lateral, usable)
		last = kind
		along += span


func _span_of(kind: String) -> float:
	match kind:
		"double":
			return 38.0
		"bounce":
			return 40.0
		"high":
			return 46.0
		"slalom":
			return 36.0
	return 30.0 + _rng.randf() * 6.0


func _pick(along: float, last: String) -> String:
	var progress: float = (along - start_s) / maxf(1.0, finish_s - start_s)
	# Reserving a complete exterior loop can remove a procedural beat. Keep
	# the established four jump-practice hurdles on the remaining main road.
	if bool(loop.get("branch", false)) and progress > 0.55 and hurdles.size() < 4 and last != "hurdle":
		return "hurdle"
	var roofed: bool = _is_covered(along - 4.0, along + 48.0)
	var bend: float = acos(
		clampf(_world.forward(along + 6.0).dot(_world.forward(along + 26.0)), -1.0, 1.0)
	)
	var weights: Dictionary = {"trail": 1.6, "hurdle": 2.2, "boost": 1.1, "crates": 1.2}
	if bend < 0.42:
		weights["channel"] = 1.8
		weights["slalom"] = 1.4
		weights["gate"] = 1.2
		if progress > 0.2:
			weights["double"] = 1.0
		if progress > 0.3:
			weights["roller"] = 1.0
		if not roofed:
			weights["bounce"] = 1.2
			if progress > 0.12:
				weights["high"] = 1.1
	weights.erase(last)
	var total: float = 0.0
	for key in weights:
		total += float(weights[key])
	var roll: float = _rng.randf() * total
	for key in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return str(key)
	return "trail"


## Places one beat and returns the lateral position where its star line ends.
func _place(kind: String, a: float, span: float, lat: float, usable: float) -> float:
	var progress: float = (a - start_s) / maxf(1.0, finish_s - start_s)
	var b: float = a + span
	match kind:
		"hurdle":
			var at: float = a + 17.0
			var across: bool = progress > 0.08 and _rng.randf() < 0.45
			var centre: float = 0.0 if across else clampf(lat, -(usable - 1.6), usable - 1.6)
			_hurdle(at, centre, 30.0 if across else 2.4)
			_trail(a + 3.0, at - 5.5, lat, centre)
			_arc(at - 3.6, at + 3.6, centre, 2.1, 5)
			return _drift(at + 6.5, b, centre, usable)
		"double":
			var centre: float = clampf(lat, -(usable - 1.6), usable - 1.6)
			var across: bool = _rng.randf() < 0.4
			_trail(a + 3.0, a + 7.0, lat, centre)
			for at in [a + 12.0, a + 26.0]:
				_hurdle(at, 0.0 if across else centre, 30.0 if across else 2.4)
				_arc(at - 3.6, at + 3.6, centre, 2.1, 5)
			_trail(a + 17.0, a + 21.0, centre, centre)
			return _drift(a + 31.0, b, centre, usable)
		"channel":
			var gap: float = 3.6 + 1.0 * clampf(progress * 1.6, 0.0, 1.0)
			var s0: float = a + 15.0
			channels.append(
				{"s0": s0, "s1": s0 + gap, "real": false, "respawn": s0 - 12.0, "exit": s0 + gap + 3.0}
			)
			_trail(a + 3.0, s0 - 5.0, lat, lat)
			_arc(s0 - 2.4, s0 + gap + 2.4, lat, 2.3, 6)
			return _drift(s0 + gap + 5.5, b, lat, usable)
		"slalom":
			var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
			var reach: float = minf(usable * 0.5, 2.4)
			var points: Array[Vector2] = [Vector2(a + 3.0, lat)]
			for index in range(3):
				var at: float = a + 9.0 + float(index) * 9.0
				var rock: float = side * reach * (1.0 if index % 2 == 0 else -1.0)
				blockers.append(_blocker(at, rock, 0.9, 1.6, "rock"))
				points.append(Vector2(at, -rock))
			points.append(Vector2(b - 3.0, points[points.size() - 1].y))
			_path(points)
			return points[points.size() - 1].y
		"gate":
			var at: float = a + 17.0
			var centre: float = clampf(lat + _rng.randf_range(-2.0, 2.0), -(usable - 2.4), usable - 2.4)
			for side in [-1.0, 1.0]:
				blockers.append(_blocker(at, centre + side * 2.5, 0.9, 1.6, "rock"))
			_trail(a + 3.0, b - 3.0, lat, centre)
			return centre
		"bounce":
			var at: float = a + 12.0
			var centre: float = clampf(lat + _rng.randf_range(-1.5, 1.5), -usable * 0.7, usable * 0.7)
			bounces.append({"s": at, "lat": centre, "radius": 1.3, "half": 1.3, "power": TUNING.BOUNCE_SPEED})
			_trail(a + 3.0, at - 3.0, lat, centre)
			var flight: float = TUNING.flight_seconds(TUNING.BOUNCE_SPEED)
			for step in range(7):
				var t: float = flight * (float(step) + 0.7) / 7.6
				var value: int = TUNING.GOLD_STAR_VALUE if step == 3 else 1
				_star(
					at + (TUNING.CRUISE + 0.5) * t,
					centre,
					STAR_HEIGHT + TUNING.flight_height(TUNING.BOUNCE_SPEED, t),
					value
				)
			return _drift(at + (TUNING.CRUISE + 0.5) * flight + 4.0, b, centre, usable)
		"high":
			var at: float = a + 8.0
			var centre: float = clampf(lat, -(usable - 2.0), usable - 2.0)
			var top: float = 2.6
			bounces.append(
				{"s": at, "lat": centre, "radius": 1.3, "half": 1.3, "power": TUNING.HIGH_PATH_BOUNCE_SPEED}
			)
			platforms.append({"s0": at + 5.5, "s1": at + 25.5, "lat": centre, "half": 1.8, "top": top})
			_trail(a + 2.0, at - 2.5, lat, centre)
			var along: float = at + 8.0
			while along < at + 23.0:
				_star(along, centre, top + STAR_HEIGHT)
				along += STAR_SPACING
			_star(at + 24.5, centre, top + STAR_HEIGHT + 0.2, TUNING.GOLD_STAR_VALUE)
			# A small line on the ground keeps the low way worth running, too.
			var low: float = centre + (3.2 if centre < 0.0 else -3.2)
			_trail(at + 10.0, at + 19.0, low, low)
			return _drift(at + 31.0, b, centre, usable)
		"boost":
			var next: float = clampf(lat + _rng.randf_range(-1.0, 1.0) * usable * 0.5, -usable * 0.8, usable * 0.8)
			boosts.append({"s0": a + 5.0, "s1": a + 11.0, "lat": lat, "half": 1.7})
			_trail(a + 2.0, a + 12.0, lat, lat, 2.5)
			_trail(a + 14.5, b - 3.0, lat, next, 2.5)
			return next
		"crates":
			var at: float = a + 17.0
			var centre: float = clampf(lat, -(usable - 2.4), usable - 2.4)
			for offset in [-1.9, 0.0, 1.9]:
				blockers.append(_blocker(at, centre + float(offset), 0.8, 1.5, "crate"))
			_trail(a + 3.0, at - 4.0, lat, centre)
			return _drift(at + 4.0, b, centre, usable)
		"roller":
			var at: float = a + 18.0
			var roller: Dictionary = _blocker(at, 0.0, 0.95, 1.6, "roller")
			roller["amp"] = usable * 0.72
			roller["rate"] = 1.9
			roller["phase"] = _rng.randf() * TAU
			blockers.append(roller)
			_trail(a + 3.0, at - 6.0, lat, lat)
			return _drift(at + 6.0, b, lat, usable)
	var target: float = clampf(lat + _rng.randf_range(-1.0, 1.0) * usable * 0.9, -usable * 0.8, usable * 0.8)
	_trail(a + 3.0, b - 3.0, lat, target)
	return target


# ------------------------------------------------------------------ helpers

## Star line from the end of an obstacle to the end of its beat. It wanders to a
## new place across the road, so collecting stars always means steering.
func _drift(from: float, beat_end: float, lat: float, usable: float) -> float:
	var next: float = clampf(lat + _rng.randf_range(-1.0, 1.0) * usable * 0.75, -usable * 0.8, usable * 0.8)
	_trail(from, beat_end - 3.0, lat, next)
	return next


func _blocker(along: float, lateral: float, radius: float, height: float, kind: String) -> Dictionary:
	return {
		"s": along,
		"lat": lateral,
		"radius": radius,
		"height": height,
		"kind": kind,
		"amp": 0.0,
		"rate": 0.0,
		"phase": 0.0,
	}


func _hurdle(along: float, centre: float, half: float) -> void:
	hurdles.append({"s": along, "lat": centre, "half": half, "height": 0.65})


func _star(along: float, lateral: float, height: float, value: int = 1) -> void:
	if along <= start_s + 4.0 or along >= finish_s - 3.0:
		return
	star_s.append(along)
	star_lat.append(lateral)
	star_h.append(height)
	star_value.append(value)


func _trail(from: float, to: float, lat0: float, lat1: float, spacing: float = STAR_SPACING) -> void:
	if to <= from:
		return
	var along: float = from
	while along <= to + 0.01:
		var u: float = (along - from) / (to - from)
		_star(along, lerpf(lat0, lat1, smoothstep(0.0, 1.0, u)), STAR_HEIGHT)
		along += spacing


func _arc(from: float, to: float, lateral: float, peak: float, count: int) -> void:
	for step in range(count):
		var u: float = float(step) / float(count - 1)
		_star(lerpf(from, to, u), lateral, STAR_HEIGHT + (peak - STAR_HEIGHT) * 4.0 * u * (1.0 - u))


func _path(points: Array[Vector2]) -> void:
	for index in range(points.size() - 1):
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		_trail(from.x, to.x - (STAR_SPACING if index < points.size() - 2 else 0.0), from.y, to.y)


func _reserve(from: float, to: float) -> void:
	_reserved.append(Vector2(from, to))


func _free(from: float, to: float) -> bool:
	return _blocked_until(from, to) <= from


## End of the reserved stretch that overlaps [from, to]; `from` when it is free.
func _blocked_until(from: float, to: float) -> float:
	var until: float = from
	for zone in _reserved:
		if from < zone.y and to > zone.x:
			until = maxf(until, zone.y)
	return until


func _is_covered(from: float, to: float) -> bool:
	for zone in covered:
		if from < zone.y and to > zone.x:
			return true
	return false


func _sort_all() -> void:
	var order: Array[int] = []
	for index in range(star_s.size()):
		order.append(index)
	# Ties are broken by position across and height: the same plan always gives
	# every star the same index, which saved runs rely on.
	order.sort_custom(
		func(a: int, b: int) -> bool:
			if star_s[a] != star_s[b]:
				return star_s[a] < star_s[b]
			if star_lat[a] != star_lat[b]:
				return star_lat[a] < star_lat[b]
			return star_h[a] < star_h[b]
	)
	var s2 := PackedFloat32Array()
	var lat2 := PackedFloat32Array()
	var h2 := PackedFloat32Array()
	var value2 := PackedInt32Array()
	var route2 := PackedStringArray()
	for index in order:
		s2.append(star_s[index])
		lat2.append(star_lat[index])
		h2.append(star_h[index])
		value2.append(star_value[index])
		route2.append(star_route[index] if index < star_route.size() else "main")
	star_s = s2
	star_lat = lat2
	star_h = h2
	star_value = value2
	star_route = route2
	var by_s := func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s)
	var by_start := func(a: Dictionary, b: Dictionary) -> bool: return float(a.s0) < float(b.s0)
	hurdles.sort_custom(by_s)
	blockers.sort_custom(by_s)
	bounces.sort_custom(by_s)
	channels.sort_custom(by_start)
	boosts.sort_custom(by_start)
	platforms.sort_custom(by_start)


func _signature() -> String:
	var parts: Array[String] = [
		str(course.get("id", "")),
		str(roundi(length * 10.0)),
		str(star_s.size()),
		str(star_total),
		str(hurdles.size()),
		str(blockers.size()),
		str(channels.size()),
		str(bounces.size()),
		str(platforms.size()),
		str(enemies.size()),
		str(rides.size()),
		str(letters.size()),
		str(respawns.size()),
	]
	for checkpoint in checkpoints:
		parts.append(str(roundi(float(checkpoint.s))))
	return "|".join(parts).sha256_text().substr(0, 16)


## Indices of the checkpoints that hold a learning stop.
func question_checkpoints() -> Array[int]:
	var result: Array[int] = []
	for checkpoint in checkpoints:
		if bool(checkpoint.question):
			result.append(int(checkpoint.index))
	return result
