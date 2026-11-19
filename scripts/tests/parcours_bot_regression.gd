extends SceneTree
## Abenteuer-Parcours: jede Welt per Prüf-Bot vom Start bis ins Ziel (Kind mit 250–400 ms
## Reaktion und Lenkrauschen), Sturz -> Checkpoint -> weiter, feste Phase der beweglichen
## Teile, Checkpoint-Abstand höchstens ~15 s, Fußabschnitt mit Aus-/Einsteigen.
## Aufruf: --script res://scripts/tests/parcours_bot_regression.gd [-- --world=wolkenwerkstatt]

const STEP: float = 1.0 / 60.0
var failures: int = 0
var checks: int = 0
var trace: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ParcoursBot] FAIL: " + text)


func _factors() -> Dictionary:
	var tuning = load("res://scripts/games/kart_tuning.gd").new("parcours_bot_test", 0)
	return tuning.multipliers("comet")


func _drive_world(world_id: String, seed_value: int, reaction: float, level: String) -> Dictionary:
	var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
	var course = worlds.build(world_id)
	var run = load("res://scripts/games/parcours/parcours_run.gd").new()
	run.setup(course, "zeitlauf")
	run.drive.factors = _factors()
	run.drive.difficulty = level
	var bot = load("res://scripts/games/parcours/parcours_bot.gd").new(seed_value, reaction, 0.14)
	var cp_times: Array[float] = [0.0]
	var longest_gap: float = 0.0
	var steps: int = 0
	var left_kart: int = 0
	var entered: int = 0
	var levers: int = 0
	while not run.finished and steps < 60 * 420:
		if run.on_foot:
			var f: Dictionary = bot.foot_input(run)
			if bool(f.jump):
				run.walker.press_jump()
			if bool(f.lever) and run.use_lever():
				levers += 1
			if run.can_enter_kart() and run.enter_kart():
				entered += 1
				bot.foot_target = 0
			run.step(STEP, 0.0, 0.0, false, false, f.move)
			if bool(f.jump):
				run.walker.release_jump()
		else:
			if run.can_leave_kart() and run.leave_kart():
				left_kart += 1
			var input: Dictionary = bot.drive_input(run, STEP)
			run.step(STEP, float(input.axis), float(input.brake), bool(input.gas), true)
		for e in run.events:
			if str(e.kind) == "reset":
				cp_times.append(run.elapsed)
			if str(e.kind) == "checkpoint":
				var gap: float = run.elapsed - cp_times[-1]
				longest_gap = maxf(longest_gap, gap)
				cp_times.append(run.elapsed)
		steps += 1
		if trace and steps % 120 == 0:
			print(
				(
					"[trace] t=%.0f pos=%s tgt=%d cp=%d v=%.1f air=%s hold=%s slab=%s"
					% [
						run.elapsed,
						run.drive.position.snapped(Vector3.ONE * 0.1),
						bot.target,
						run.checkpoint,
						run.drive.speed,
						run.drive.airborne,
						run.drive.holding,
						str(run.drive.hit.get("slab", -1)) + " " + str(run.state)
					]
				)
			)
	var tail: float = run.elapsed - cp_times[-1]
	longest_gap = maxf(longest_gap, tail)
	return {
		"run": run,
		"finished": run.finished,
		"seconds": run.elapsed,
		"falls": run.falls,
		"resets": run.resets,
		"longest_gap": longest_gap,
		"stars": run.stars_taken.size(),
		"star_total": course.stars.size(),
		"left": left_kart,
		"entered": entered,
		"levers": levers,
		"stations": course.stations.size(),
		"course": course,
		"rails": run.drive.rail_hits,
		"bumps": run.drive.bumps,
		"jumps": run.drive.jumps
	}


func _fall_test(world_id: String) -> void:
	var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
	var course = worlds.build(world_id)
	var run = load("res://scripts/games/parcours/parcours_run.gd").new()
	run.setup(course, "erkunden")
	run.drive.factors = _factors()
	run.drive.difficulty = "flott"
	# Am zweiten Checkpoint stehend absichtlich seitlich hinunterfahren.
	var cp: Dictionary = course.checkpoints[1]
	run.checkpoint = 1
	run.drive.place(cp.pos, float(cp.heading) + 1.3)
	var star_before: int = 0
	run.stars_taken[0] = true
	star_before = run.stars_taken.size()
	var fell: bool = false
	var reset_event: Dictionary = {}
	for i in range(60 * 12):
		run.step(STEP, 0.0, 0.0, true, true)
		for e in run.events:
			if str(e.kind) == "reset":
				fell = true
				reset_event = e
		if fell:
			break
	_check(fell, "%s: Sturz vom Rand löst die Rettung aus" % world_id)
	_check(
		run.drive.position.distance_to(cp.pos) < 0.5, "%s: Rettung landet am Checkpoint" % world_id
	)
	_check(run.stars_taken.size() == star_before, "%s: Sturz kostet keine Sterne" % world_id)
	_check(not str(reset_event.get("text", "")).is_empty(), "%s: Lumo sagt einen Satz" % world_id)
	# Danach geht es normal weiter: auf dem Boden, fährt an.
	for i in range(60):
		run.step(STEP, 0.0, 0.0, true, true)
	_check(
		not run.drive.airborne and run.drive.speed > 3.0,
		"%s: nach Rettung fährt das Kart weiter" % world_id
	)


func _phase_test(world_id: String) -> void:
	var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
	var a = worlds.build(world_id)
	var b = worlds.build(world_id)
	var same: bool = true
	for index in range(a.slabs.size()):
		if (a.slabs[index].get("motion", {}) as Dictionary).is_empty():
			continue
		for t in [0.0, 1.7, 13.25, 99.0]:
			if not a.slab_transform(index, t).is_equal_approx(b.slab_transform(index, t)):
				same = false
	_check(same, "%s: bewegliche Teile haben eine feste Phase" % world_id)
	var moving: int = 0
	for slab in a.slabs:
		if not (slab.get("motion", {}) as Dictionary).is_empty():
			moving += 1
	_check(moving >= 3, "%s: mindestens drei bewegliche Platten (%d)" % [world_id, moving])
	_check(
		a.skills.size() >= 3 and a.skills.size() <= 5, "%s: 3–5 Geschicklichkeitsstellen" % world_id
	)
	_check(a.secrets.size() >= 1, "%s: Geheimweg vorhanden" % world_id)
	var ids: Dictionary = {}
	for c in a.checkpoints:
		ids[str(c.id)] = true
	_check(ids.size() == a.checkpoints.size(), "%s: Checkpoint-IDs eindeutig" % world_id)
	for skill in a.skills:
		_check(
			not str(skill.intro).is_empty() and not str(skill.retry).is_empty(),
			"%s: Ansage und Hilfe für %s" % [world_id, skill.id]
		)


func _run() -> void:
	var worlds = load("res://scripts/games/parcours/parcours_worlds.gd")
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace":
			trace = true
		if arg.begins_with("--world="):
			only = arg.trim_prefix("--world=")
	var summary: PackedStringArray = []
	for world_id in worlds.playable_ids():
		if not only.is_empty() and world_id != only:
			continue
		_phase_test(world_id)
		_fall_test(world_id)
		var runs: Array = [[11, 0.25, "gemuetlich"], [23, 0.40, "gemuetlich"], [37, 0.32, "flott"]]
		for spec in runs:
			var r: Dictionary = _drive_world(world_id, int(spec[0]), float(spec[1]), str(spec[2]))
			var label: String = (
				"%s seed=%d reaction=%.2f %s" % [world_id, spec[0], spec[1], spec[2]]
			)
			_check(r.finished, label + ": Start bis Ziel")
			_check(r.longest_gap <= 16.0, label + ": Checkpoint-Abstand %.1f s" % r.longest_gap)
			_check(r.left == r.stations and r.entered == r.stations, label + ": Aus-/Einsteigen")
			_check(r.levers == r.stations, label + ": Aufgaben zu Fuß gelöst")
			(
				summary
				. append(
					(
						"%s: %.1f s, Stürze %d, Sterne %d/%d, längster CP-Abstand %.1f s, Geländer %d, Stöße %d, Sprünge %d"
						% [
							label,
							r.seconds,
							r.falls,
							r.stars,
							r.star_total,
							r.longest_gap,
							r.rails,
							r.bumps,
							r.jumps
						]
					)
				)
			)
	for line in summary:
		print("[ParcoursBot] ", line)
	if failures == 0:
		print("[ParcoursBot] PASS: %d Prüfungen" % checks)
	else:
		print("[ParcoursBot] FAIL: %d von %d Prüfungen" % [failures, checks])
	quit(1 if failures > 0 else 0)
