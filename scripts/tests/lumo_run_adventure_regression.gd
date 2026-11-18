extends SceneTree
## Tempo and adventure passages of Lumo Lauf on the Dschungelherz path (headless).
##
##   godot --headless --path . --script res://scripts/tests/lumo_run_adventure_regression.gd
##
## 1. Measures the motion model on flat ground: pace, both flow stages, jump
##    lengths held and tapped at five speeds (the numbers the passages use).
## 2. Warning time before every obstacle at the pace Lumo can have there.
## 3. Each of the three passages: announced early, rescue point shortly before,
##    a safe and a brave line, and the arithmetic (jump vs. gap, reserve).
## 4. The scripted player crosses every passage at normal pace for 30 seeds.
## 5. A deliberately slow player falls only at the passage, gets back in just
##    before it and then makes it; a moderately slow one makes the safe line.

const BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const METER = preload("res://scripts/tests/helpers/lumo_run_tempo_meter.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const PLAYER = preload("res://scripts/games/run/run_player.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const STEP: float = 1.0 / 60.0
const SCALE: float = TUNING.PATH_TIME_SCALE
## Seconds a child of 6 to 10 needs between seeing an obstacle and pressing:
## choice reaction about 0.6-0.8 s, plus a margin for steering and the thumb.
const REACTION: float = 1.0
const SEEDS: int = 30
## Stick held back this far makes Lumo run at about 40 % of his pace.
const SLOW_PULL: float = 0.66
## ... and this far at about 70 %.
const EASY_PULL: float = 0.48

var checks: int = 0
var failures: Array[String] = []
var jumps: Dictionary = {}


class FlatTrack:
	extends RefCounted
	var plan = null

	func grade_at(_s: float) -> float:
		return 0.0

	func speed_cap(_s: float, _lat: float) -> float:
		return INF

	func ground_at(_s: float, _lat: float, _feet: float) -> float:
		return 0.0

	func confine(_s: float, wanted: float, _current: float) -> float:
		return wanted

	func wants_loop(_a: float, _b: float, _lat: float) -> bool:
		return false

	func flow_cap(_s: float) -> int:
		return 2


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[LumoAdventure] ok: " + label)
	else:
		failures.append(label)
		print("[LumoAdventure] FAILED CHECK: " + label)


func _run() -> void:
	_measure_motion()
	var game = await _open()
	_measure_warnings(game)
	_check_passages(game)
	if OS.get_environment("LUMO_QUICK") != "1":
		_bots_cross(game)
		_slow_players(game)
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	print("[LumoAdventure] %s: %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	for failure in failures:
		print("[LumoAdventure] failed: " + failure)
	quit(0 if failures.is_empty() else 1)


func _open():
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik", "childKey": "adventure"}
	var game = load("res://scenes/games/lumo_run.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.start_course(COURSES.index_of("dschungelherz"), false)
	game.countdown_left = 0.0
	game.advance(STEP)
	return game


# ------------------------------------------------------------------ 1. the motion model

func _measure_motion() -> void:
	var track := FlatTrack.new()
	var player = PLAYER.new()
	player.use_path_feel()
	player.place(0.0, 0.0, TUNING.PATH_CRUISE)
	var stage_one: float = -1.0
	var stage_two: float = -1.0
	var top: float = 0.0
	for frame in range(int(12.0 / STEP)):
		player.step(STEP, Vector2.ZERO, track)
		top = maxf(top, player.speed)
		if stage_one < 0.0 and player.flow >= 1.0:
			stage_one = float(frame) * STEP / SCALE
		if stage_two < 0.0 and player.flow2 >= 1.0:
			stage_two = float(frame) * STEP / SCALE
	var cruise: float = TUNING.PATH_CRUISE * SCALE
	var sprint: float = (TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS) * SCALE
	print("[LumoAdventure] tempo on screen: pace %.1f m/s, flow stage 1 %.1f m/s after %.1f s, stage 2 %.1f m/s after %.1f s, pad %.1f m/s, cart %.1f m/s" % [
		cruise, sprint, stage_one, top * SCALE, stage_two, (TUNING.PATH_CRUISE + TUNING.BOOST_BONUS) * SCALE, TUNING.CART_SPEED * SCALE,
	])
	_check(cruise >= 11.5, "the pace is faster than before (%.1f m/s on screen, was 11.1)" % cruise)
	_check(top * SCALE >= 18.0, "clean running reaches a top pace (%.1f m/s on screen, was 15.0)" % (top * SCALE))
	_check(stage_two > stage_one and stage_two < 7.0, "the top pace takes a few seconds of clean running (%.1f s)" % stage_two)
	# Jump lengths (metres, the same in course and screen time) at five speeds.
	var speeds: Dictionary = {
		"slow40": TUNING.PATH_CRUISE * 0.4, "easy70": TUNING.PATH_CRUISE * 0.7, "pace": TUNING.PATH_CRUISE,
		"stage1": TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS,
		"stage2": TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS + TUNING.PATH_FLOW2_BONUS,
	}
	var rows: Array[String] = []
	for key in speeds:
		var held: float = _jump(float(speeds[key]), true)
		var tapped: float = _jump(float(speeds[key]), false)
		jumps[key] = {"speed": float(speeds[key]), "held": held, "tapped": tapped}
		rows.append("%s %.1f m/s: held %.2f m, tapped %.2f m" % [key, float(speeds[key]) * SCALE, held, tapped])
	print("[LumoAdventure] jump lengths: " + " | ".join(rows))
	var formula: float = TUNING.PATH_CRUISE * 0.877
	_check(absf(float(jumps.pace.held) - formula) < 0.4, "held jump at pace matches the passage arithmetic (%.2f m, formula %.2f m)" % [float(jumps.pace.held), formula])


## Flight length on flat ground at a fixed running speed.
func _jump(speed: float, held: bool) -> float:
	var track := FlatTrack.new()
	var player = PLAYER.new()
	player.use_path_feel()
	player.flow_bonus = 0.0
	player.cruise = speed
	player.place(0.0, 0.0, speed)
	player.step(STEP, Vector2.ZERO, track)
	var from: float = player.s
	player.press_jump()
	if not held:
		player.release_jump()
	var left: bool = false
	for _frame in range(240):
		player.step(STEP, Vector2.ZERO, track)
		if not player.grounded:
			left = true
		if held and player.jump_hold >= TUNING.JUMP_HOLD_SECONDS:
			player.release_jump()
		if left and player.grounded:
			return player.s - from
	return -1.0


# ------------------------------------------------------------------ 2. warning times

func _speed_at(game, at: float) -> float:
	var bonus: float = TUNING.PATH_FLOW_BONUS
	if game.track.flow_cap(at) >= 2:
		bonus += TUNING.PATH_FLOW2_BONUS
	return (TUNING.PATH_CRUISE + bonus) * SCALE


func _measure_warnings(game) -> void:
	var items: Array = METER.obstacles(game.plan, game.world.level.gaps)
	var ups: Array = METER.run_ups(items, float(game.plan.intro_end))
	var at_pace: Dictionary = METER.summary(ups, TUNING.PATH_CRUISE * SCALE)
	var tight: Array = ups.duplicate()
	tight.sort_custom(func(a, b) -> bool: return float(a[1]) < float(b[1]))
	var listing: Array[String] = []
	for up in tight.slice(0, 10):
		listing.append("%s@%.0f %.1f m" % [str(up[2]), float(up[0]), float(up[1])])
	print("[LumoAdventure] tightest run-ups: " + ", ".join(listing))
	var lowest: float = INF
	var where: Array = []
	var below: int = 0
	for up in ups:
		var seconds: float = float(up[1]) / _speed_at(game, float(up[0]))
		if seconds < lowest:
			lowest = seconds
			where = up
		if seconds < REACTION:
			below += 1
	print("[LumoAdventure] warning time before %d obstacle groups: at pace min %.2f s / 10%% %.2f s / median %.2f s; at the top pace allowed there min %.2f s (%s at s=%.0f), %d below %.1f s" % [
		ups.size(), float(at_pace.min), float(at_pace.p10), float(at_pace.median), lowest, str(where[2]), float(where[0]), below, REACTION,
	])
	var before_pace: Dictionary = METER.summary(ups, 8.5 * 1.3)
	var before_sprint: Dictionary = METER.summary(ups, 11.5 * 1.3)
	var sprint_now: Dictionary = METER.summary(ups, (TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS) * SCALE)
	print("[LumoAdventure] free run-up (same obstacles): before pace 11.1 m/s min %.2f / 10%% %.2f / median %.2f s, sprint 15.0 m/s min %.2f / 10%% %.2f s; now pace min %.2f / 10%% %.2f, sprint 16.1 m/s min %.2f / 10%% %.2f s" % [
		float(before_pace.min), float(before_pace.p10), float(before_pace.median), float(before_sprint.min), float(before_sprint.p10),
		float(at_pace.min), float(at_pace.p10), float(sprint_now.min), float(sprint_now.p10),
	])
	# The top stage never runs into a dense stretch: wherever it is allowed the
	# free run-up alone leaves the reaction time.
	_check(lowest >= REACTION or game.track.flow_cap(float(where[0]) - 1.0) < 2, "the top pace only where the run-up leaves %.1f s (lowest %.2f s at s=%.0f)" % [REACTION, lowest, float(where[0])])
	var open_low: float = INF
	for up in ups:
		if game.track.flow_cap(float(up[0]) - 1.0) >= 2:
			open_low = minf(open_low, float(up[1]) / _speed_at(game, float(up[0])))
	_check(open_low >= REACTION, "on open stretches at top pace every obstacle leaves %.1f s or more (lowest %.2f s)" % [REACTION, open_low])
	# What the child sees: from how far the camera shows each obstacle group.
	var sight_low: float = INF
	var sight_where: float = 0.0
	var sights: Array[float] = []
	for up in ups:
		var seen: float = _sight(game, float(up[0]))
		var seconds: float = seen / _speed_at(game, float(up[0]) - 1.0)
		sights.append(seconds)
		if seconds < sight_low:
			sight_low = seconds
			sight_where = float(up[0])
	sights.sort()
	print("[LumoAdventure] in view before each obstacle group at the pace allowed there: min %.2f s (s=%.0f), 10%% %.2f s, median %.2f s" % [sight_low, sight_where, sights[int(sights.size() * 0.1)], sights[sights.size() / 2]])
	_check(sight_low >= 1.5 * REACTION, "every obstacle is in view at least %.1f s before Lumo gets there (%.2f s)" % [1.5 * REACTION, sight_low])


## Metres before `at` from which the chase camera shows the spot (checked from
## 40 m in steps of 2 m, with the real camera placement).
func _sight(game, at: float) -> float:
	var seen: float = 0.0
	var distance: float = 40.0
	while distance >= 4.0:
		_place(game, at - distance, 0.0, TUNING.PATH_CRUISE)
		game._update_view(0.0, true)
		var point: Vector3 = game.world.position_at(at, 0.0) + Vector3.UP * 0.5
		if game.camera.is_position_in_frustum(point):
			seen = distance if seen <= 0.0 else seen
		else:
			seen = 0.0
		distance -= 2.0
	return seen


# ------------------------------------------------------------------ 3. the passages

func _check_passages(game) -> void:
	var plan = game.plan
	_check(plan.passages.size() == 3, "three adventure passages (%d)" % plan.passages.size())
	var pace: Dictionary = jumps.pace
	var slow: Dictionary = jumps.slow40
	var easy: Dictionary = jumps.easy70
	var stage1: Dictionary = jumps.stage1
	for passage in plan.passages:
		var name: String = str(passage.name)
		var lead: float = float(passage.s0) - float(passage.announce)
		var top_speed: float = (TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS + TUNING.PATH_FLOW2_BONUS) * SCALE
		_check(lead / top_speed >= 2.4, "%s: announced %.0f m ahead (%.1f s even at top pace)" % [name, lead, lead / top_speed])
		var rescue_s: float = -INF
		for point in plan.respawns:
			if float(point.s) < float(passage.s0):
				rescue_s = maxf(rescue_s, float(point.s))
		var back: float = float(passage.s0) - rescue_s
		_check(back <= 40.0, "%s: rescue point %.0f m before the passage (%.1f s at pace)" % [name, back, back / (TUNING.PATH_CRUISE * SCALE)])
		var brave_gold: bool = false
		for index in range(plan.star_s.size()):
			if plan.star_value[index] > 1 and plan.star_route[index] == "upper" and absf(plan.star_s[index] - float(passage.s0)) < 30.0:
				brave_gold = true
		_check(brave_gold, "%s: the brave line has gold stars" % name)
		var safe_gap: float = float(passage.safe_gap)
		var brave_gap: float = float(passage.brave_gap)
		print("[LumoAdventure] %s: safe gap %.1f m (pace held %.2f / tapped %.2f, reserve %.2f m; 70 %% held %.2f) - brave gap %.1f m (pace held %.2f, reserve %.2f; sprint held %.2f, reserve %.2f) - 40 %% held %.2f" % [
			name, safe_gap, float(pace.held), float(pace.tapped), float(pace.held) - safe_gap, float(easy.held), brave_gap, float(pace.held), float(pace.held) - brave_gap,
			float(stage1.held), float(stage1.held) - brave_gap, float(slow.held),
		])
		# Downhill (the slide) Lumo runs faster by himself: up to GRADE_MAX times his pace.
		var lift: float = float(passage.get("downhill", 1.0))
		var pace_held: float = float(pace.held) * lift
		var sprint_held: float = float(stage1.held) * lift
		if lift > 1.0:
			print("[LumoAdventure] %s: downhill pace x%.2f: held %.2f m, with sprint %.2f m" % [name, lift, pace_held, sprint_held])
		_check(pace_held - safe_gap >= 2.5 and float(easy.held) - safe_gap >= 0.5, "%s: safe line has room at pace (%.2f m) and still works at 70 %% (%.2f m)" % [name, pace_held - safe_gap, float(easy.held) - safe_gap])
		_check(sprint_held - brave_gap >= 1.4 and pace_held >= brave_gap + 0.3, "%s: brave line works held at pace (%.2f m), comfortably with the sprint (%.2f m)" % [name, pace_held - brave_gap, sprint_held - brave_gap])
		_check(float(slow.held) < safe_gap, "%s: a really slow runner (40 %%) does not get across" % name)
		if float(passage.plank) > 0.0:
			var plank: float = float(passage.plank)
			var safe_need: float = plank / float(passage.safe_hold)
			var brave_need: float = plank / float(passage.brave_hold)
			print("[LumoAdventure] %s: planks %.1f m hold %.2f s (safe, needs %.1f m/s) and %.2f s (brave, needs %.1f m/s; course time)" % [name, plank, float(passage.safe_hold), safe_need, float(passage.brave_hold), brave_need])
			_check(safe_need < TUNING.PATH_CRUISE * 0.7 and safe_need > TUNING.PATH_CRUISE * 0.4, "%s: safe planks hold for anyone at 70 %% pace, not for a dawdler" % name)
			_check(brave_need > TUNING.PATH_CRUISE and brave_need < TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS, "%s: brave planks need the sprint" % name)


# ------------------------------------------------------------------ 4. normal players

func _place(game, s: float, lat: float, speed: float) -> void:
	var passed: int = -1
	for checkpoint in game.plan.checkpoints:
		if float(checkpoint.s) < s:
			passed = int(checkpoint.index)
	game.track.checkpoint = maxi(game.track.checkpoint, passed)
	game.track.rescue = game.plan.respawn_index(s)
	game.track.chase_active = false
	game.track.falls.clear()
	game.track.crumbled.clear()
	game.player.place(s, lat, speed)
	game.player.invulnerable = 0.0
	game.touch_steer = Vector2.ZERO
	game.player.release_jump()


## Plays from `from` until Lumo is `past` metres beyond the passage; returns
## the number of rescues on the way and whether he got there.
func _attempt(game, bot, passage: Dictionary, from: float, seconds: float = 14.0) -> Dictionary:
	_place(game, from, 0.0, TUNING.PATH_CRUISE)
	var before: int = game.track.rescues
	var first_fall_s: float = -1.0
	var frames: int = 0
	while frames < int(seconds / STEP) and game.player.s < float(passage.s1) + 8.0:
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			bot.drive(game, STEP)
		var was: float = game.player.s
		game.advance(STEP)
		if game.track.rescues != before and first_fall_s < 0.0:
			first_fall_s = was
		frames += 1
	return {
		"rescues": game.track.rescues - before, "across": game.player.s >= float(passage.s1) + 8.0,
		"fall_s": first_fall_s, "routes": bot.routes.duplicate(),
	}


func _bots_cross(game) -> void:
	for passage in game.plan.passages:
		var name: String = str(passage.name)
		var clean: int = 0
		var brave: int = 0
		var only: String = OS.get_environment("LUMO_PASSAGE")
		if not only.is_empty() and only != name:
			continue
		for seed in range(1, SEEDS + 1):
			var bot = BOT.new(seed)
			var result: Dictionary = _attempt(game, bot, passage, float(passage.announce) - 10.0)
			if int(result.rescues) == 0 and bool(result.across):
				clean += 1
			else:
				print("[LumoAdventure] %s seed %d: %d falls (first at s=%.1f), route %s" % [name, seed, int(result.rescues), float(result.fall_s), str(result.routes.get(name, ""))])
			if str(result.routes.get(name, "")) == "upper":
				brave += 1
		print("[LumoAdventure] %s: %d of %d normal players across without a fall (%d on the brave line)" % [name, clean, SEEDS, brave])
		_check(clean == SEEDS, "%s: the scripted player gets across at normal pace in all %d runs (%d)" % [name, SEEDS, clean])
		_check(brave > 0 and brave < SEEDS, "%s: both lines are taken (%d brave)" % [name, brave])


# ------------------------------------------------------------------ 5. slow players

func _slow_players(game) -> void:
	for passage in game.plan.passages:
		var name: String = str(passage.name)
		if not OS.get_environment("LUMO_PASSAGE").is_empty() and OS.get_environment("LUMO_PASSAGE") != name:
			continue
		var zone := Vector2(float(passage.announce) - 10.0, float(passage.s1))
		# Slow only on the first try: falls at the passage, back in shortly
		# before it, then runs normally and gets across.
		var bot = BOT.new(2)
		bot.hold_back = SLOW_PULL
		bot.slow_zones.append(zone)
		bot.routes[name] = "lower"
		bot.use_dash = false
		_place(game, zone.x, 0.0, TUNING.PATH_CRUISE)
		var before: int = game.track.rescues
		var fall_s: float = -1.0
		var back_at: float = -1.0
		var frames: int = 0
		while frames < int(30.0 / STEP) and game.player.s < float(passage.s1) + 8.0:
			bot.drive(game, STEP)
			var was: float = game.player.s
			game.advance(STEP)
			if game.track.rescues != before and fall_s < 0.0:
				fall_s = was
				back_at = game.player.s
				bot.hold_back = 0.0
			frames += 1
		var falls: int = game.track.rescues - before
		var across: bool = game.player.s >= float(passage.s1) + 8.0
		print("[LumoAdventure] %s: slow player fell at s=%.1f (passage %.1f-%.1f), back in at s=%.1f (%.0f m before), %d falls, across=%s" % [
			name, fall_s, float(passage.s0), float(passage.s1), back_at, float(passage.s0) - back_at, falls, str(across),
		])
		_check(fall_s >= float(passage.s0) - 1.0 and fall_s <= float(passage.s1) + 1.0, "%s: a really slow runner falls exactly at the passage (s=%.1f)" % [name, fall_s])
		_check(back_at > 0.0 and float(passage.s0) - back_at <= 40.0, "%s: back in shortly before the passage (%.0f m)" % [name, float(passage.s0) - back_at])
		_check(across and falls == 1, "%s: after getting back in at normal pace he makes it (%d falls)" % [name, falls])
		# Stays slow: the passage helps after a few tries, nobody gets stuck.
		var stubborn = BOT.new(4)
		stubborn.hold_back = SLOW_PULL
		stubborn.slow_zones.append(zone)
		stubborn.routes[name] = "lower"
		stubborn.use_dash = false
		var tries: Dictionary = _attempt(game, stubborn, passage, zone.x, 45.0)
		_check(bool(tries.across) and int(tries.rescues) <= TUNING.PATH_HELP_AFTER_FALLS + 1, "%s: who stays slow is carried across after %d falls" % [name, int(tries.rescues)])
		# Moderately slow (about 70 %): the safe line is enough.
		var easy = BOT.new(6)
		easy.hold_back = EASY_PULL
		easy.slow_zones.append(zone)
		easy.routes[name] = "lower"
		easy.use_dash = false
		var calm: Dictionary = _attempt(game, easy, passage, zone.x)
		_check(bool(calm.across) and int(calm.rescues) == 0, "%s: at about 70 %% pace the safe line works (%d falls)" % [name, int(calm.rescues)])
