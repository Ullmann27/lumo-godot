extends SceneTree
## Beide Linien aus demselben Anlauf mit realem Lenken, Bremsen und Fahrbahnkontakt.

const WORLDS = preload("res://scripts/games/parcours/parcours_worlds.gd")
const RUN = preload("res://scripts/games/parcours/parcours_run.gd")
const PILOT = preload("res://scripts/games/parcours/parcours_bot.gd")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	for id in WORLDS.playable_ids():
		var course = WORLDS.build(id)
		_validate_distances(course)
		for hz in [30, 60]:
			for alternative in [false, true]:
				_drive(course, alternative, hz)
	print("PARCOURS_FORKS_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)


func _validate_distances(course) -> void:
	var segments: Array = course.slabs.filter(func(s): return s.get("race_fork", false))
	var previous_distance: float = float(segments.front().route_from)
	var continuous := true
	for s in segments:
		continuous = continuous and is_equal_approx(float(s.route_from), previous_distance)
		continuous = continuous and float(s.race_distance_span) > 0.0
		previous_distance = float(s.route_from) + float(s.race_distance_span)
	var merge: Vector3 = course.route[course.race_branch.exit].pos - Vector3.UP * 0.3
	var main_after_merge: Array = course.slabs.filter(
		func(s): return not s.get("race_fork", false) and s.base.origin.is_equal_approx(merge)
	)
	_check(continuous and not main_after_merge.is_empty(), course.id + " Wertung auf Seitenstrecke")
	_check(is_equal_approx(previous_distance, float(main_after_merge.front().route_from)), course.id + " Wertung nach Ausfahrt")


func _drive(course, alternative: bool, hz: int) -> void:
	var fork: Dictionary = course.race_branch
	var run = RUN.new()
	run.setup(course, "rennen")
	var pilot = PILOT.new(17, 0.25, 0.08)
	var line: Array = course.route.slice(fork.entry, fork.exit + 1)
	if alternative:
		line = [course.route[fork.entry]] + fork.points + [course.route[fork.exit]]
	var entry: Vector3 = line.front().pos
	var merge: Vector3 = line.back().pos
	var previous: Vector3 = course.route[fork.entry - 1].pos
	var heading := (entry - previous).normalized()
	var next: Vector3 = course.route[fork.exit + 1].pos
	var merge_heading := (next - merge).normalized()
	line.append({"pos": merge + merge_heading * 6.0, "cap": 12.0})
	pilot.racing_line = line
	run.drive.place(entry - heading * 5.5, atan2(-heading.x, -heading.z))
	var slabs: Dictionary = {}
	var furthest: float = 0.0
	var crossed := false
	for frame in range(hz * 40):
		var dt := 1.0 / hz
		var input: Dictionary = pilot.drive_input(run, dt)
		run.step(dt, input.axis, input.brake, input.gas, false)
		var hit: Dictionary = run.drive.hit
		if not hit.is_empty() and course.slabs[hit.slab].get("race_fork", false):
			slabs[hit.slab] = true
		var delta: Vector3 = run.drive.position - merge
		furthest = maxf(furthest, run.drive.position.distance_to(entry))
		if delta.dot(merge_heading) > 1.0 and delta.length() < 7.0:
			crossed = true
			break
		if run.falls > 0:
			break
	var context := "%s %s %dHz" % [course.id, "Abzweig" if alternative else "Hauptweg", hz]
	print("%s zusammen=%s Wegplatten=%d Meter=%.1f Stürze=%d Sekunden=%.1f" % [context, crossed, slabs.size(), furthest, run.falls, run.t])
	_check(crossed and run.falls == 0, context + " gemeinsame Ausfahrt")
	_check(slabs.size() >= 6 if alternative else slabs.size() <= 4, context + " unterscheidbare Fahrbahn")


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
