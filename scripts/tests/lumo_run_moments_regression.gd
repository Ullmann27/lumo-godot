extends SceneTree
## The early highlights of Lumo Lauf (run_moments.gd), one per world, headless:
##
##   godot --headless --path . --script res://scripts/tests/lumo_run_moments_regression.gd
##
## For Dschungelherz (vine), Zauberwald (glowing mushrooms, upper way) and
## Sonnenhafen (wave jump):
## 1. the highlight is announced and mastered within the first 30 seconds, and
##    the first active decision comes within 8 seconds;
## 2. a player who reacts like a child (sees the coach icon, presses after
##    0.25, 0.32 or 0.40 s, holds briefly) masters it with the real inputs;
## 3. a miss costs a short way back, never the run, and the moment stays armed;
## 4. a rescue point or checkpoint follows the highlight;
## 5. the whole course is finished with exactly one booked reward;
## 6. with "ruhige Bewegung" the beacon glows without pulsing.

const CHILD_PLAYER = preload("res://scripts/tests/helpers/lumo_run_child.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const STEP: float = 1.0 / 60.0
const REACTIONS: Array[float] = [0.25, 0.32, 0.4]
const CHILD: String = "lumo-run-moments"

var checks: int = 0
var failures: Array[String] = []
var scene: PackedScene
var bridge: Node
var rewards: Array[Dictionary] = []
var happenings: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[LumoMoments] FAILED CHECK: " + label)
	else:
		print("[LumoMoments] ok: " + label)


func _open(index: int, calm: bool = false):
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {
		"grade": 2,
		"subject": "Deutsch",
		"childKey": CHILD,
		"sessionId": "moments",
		"reducedMotion": calm
	}
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	if calm:
		game.reduced_motion = true
	game.start_course(index, false)
	game.countdown_left = 0.0
	game.advance(STEP)
	happenings.clear()
	game.moment.connect(
		func(kind: String, detail: Dictionary) -> void:
			happenings.append(
				{
					"kind": kind,
					"t": float(game.elapsed),
					"s": float(game.player.s),
					"id": str(detail.get("id", ""))
				}
			)
	)
	return game


func _free(game) -> void:
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


func _first(kind: String) -> Dictionary:
	for item in happenings:
		if str(item.kind) == kind:
			return item
	return {}


func _count(kind: String) -> int:
	return happenings.filter(func(item: Dictionary) -> bool: return str(item.kind) == kind).size()


## Runs until `seconds` of course time or until `done` says so.
func _play(game, child, seconds: float, done: Callable = Callable()) -> void:
	var steps: int = 0
	while game.phase == game.Phase.RUNNING and float(game.elapsed) < seconds and steps < 60 * 900:
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			child.drive(game, STEP)
		game.advance(STEP)
		steps += 1
		if done.is_valid() and done.call():
			return


func _run() -> void:
	scene = load("res://scenes/games/lumo_run.tscn")
	bridge = root.get_node("HostBridge")
	var counter: Callable = func(payload: Dictionary) -> void: rewards.append(payload)
	bridge.reward_reported.connect(counter)
	for id in ["dschungelherz", "zauberwald", "sonnenhafen"]:
		await _test_world(id)
	await _test_calm()
	bridge.reward_reported.disconnect(counter)
	_clean()
	scene = null
	happenings.clear()
	if failures.is_empty():
		print("[LumoMoments] PASS: %d checks" % checks)
	else:
		print(
			(
				"[LumoMoments] FAIL: %d of %d checks failed: %s"
				% [failures.size(), checks, " | ".join(failures)]
			)
		)
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	# The app-wide effects of the road courses: let go of the cached samples.
	var effects: Node = root.get_node_or_null("AudioManager")
	if effects != null and effects.get("_pool") != null:
		for voice in effects._pool:
			voice.stop()
			voice.stream = null
		effects._samples.clear()
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)


func _clean() -> void:
	var session = load("res://scripts/games/run/run_session.gd")
	for index in range(COURSES.count()):
		for subject in ["Deutsch", "Mathematik"]:
			session.erase(
				session.path_for(CHILD.sha256_text(), 2, subject, str(COURSES.course(index).id))
			)


func _test_world(id: String) -> void:
	var index: int = COURSES.index_of(id)
	var path: bool = bool(COURSES.course(index).get("path", false))
	# 1 + 2: a child with a normal reaction masters the highlight early.
	for reaction in REACTIONS:
		var game = await _open(index)
		_check(not game.plan.moments.is_empty(), "%s has an early highlight" % id)
		if game.plan.moments.is_empty():
			await _free(game)
			return
		var spot: Dictionary = game.plan.moments[0]
		var child := CHILD_PLAYER.new(path, 2)
		child.reaction = reaction
		var decision_at: float = _decision_s(game.plan)
		var reached: Array[float] = [-1.0]
		var watch: Callable = func() -> bool:
			if reached[0] < 0.0 and float(game.player.s) >= decision_at:
				reached[0] = float(game.elapsed)
			return not _first("moment_done").is_empty()
		_play(game, child, 40.0, watch)
		var cue: Dictionary = _first("moment_cue")
		var done: Dictionary = _first("moment_done")
		var tag: String = "%s (%s, reaction %.2f s)" % [id, str(spot.name), reaction]
		_check(
			not cue.is_empty() and float(cue.t) < 15.0,
			"%s: announced early (%.1f s)" % [tag, float(cue.get("t", -1.0))]
		)
		_check(
			not done.is_empty() and float(done.t) <= 30.0,
			(
				"%s: mastered with real inputs in the first 30 s (%.1f s, %d misses)"
				% [tag, float(done.get("t", -1.0)), _count("moment_missed")]
			)
		)
		_check(_count("moment_missed") == 0, "%s: no miss at a normal reaction" % tag)
		if reaction == REACTIONS[0]:
			_check(
				(
					game.player.boost_time > 0.0
					or float(game.player.speed) > float(game.player.cruise)
				),
				"%s: the reward is a push forward" % tag
			)
			var decision: float = reached[0]
			_check(
				decision >= 0.0 and decision <= 8.0,
				"%s: first active decision within 8 s (%.1f s)" % [id, decision]
			)
		await _free(game)
	# 3: doing nothing costs a short way back, never the run.
	var game = await _open(index)
	var spot: Dictionary = game.plan.moments[0]
	var idle := CHILD_PLAYER.new(path, 2)
	idle.refuse = true
	if str(spot.need) == "upper":
		idle.lane = -float(spot.lat)
	_play(game, idle, 30.0, func() -> bool: return not _first("moment_missed").is_empty())
	var missed: Dictionary = _first("moment_missed")
	_check(not missed.is_empty(), "%s: doing nothing at the highlight counts as a miss" % id)
	_check(game.phase == game.Phase.RUNNING, "%s: a miss never ends the run" % id)
	if str(spot.need) != "upper":
		_check(
			float(game.player.s) < float(spot.s1) and game.moments.calling(0),
			(
				"%s: after a miss Lumo is back before it and it stays armed (s=%.0f)"
				% [id, float(game.player.s)]
			)
		)
		idle.refuse = false
		_play(game, idle, 60.0, func() -> bool: return not _first("moment_done").is_empty())
		_check(not _first("moment_done").is_empty(), "%s: the next try works" % id)
	await _free(game)
	# 4: a safe point after the highlight.
	game = await _open(index)
	spot = game.plan.moments[0]
	var after: bool = false
	for item in game.plan.respawns:
		after = after or (float(item.s) > float(spot.s1) and float(item.s) < float(spot.s1) + 60.0)
	for item in game.plan.checkpoints:
		after = after or float(item.s) > float(spot.s1)
	_check(after, "%s: a rescue point or checkpoint follows the highlight" % id)
	# 5: the whole course, one reward.
	var before: int = rewards.size()
	var child := CHILD_PLAYER.new(path, 2)
	_play(game, child, 600.0)
	_check(
		game.phase == game.Phase.FINISHED,
		"%s: the course is finished (%.0f s)" % [id, float(game.elapsed)]
	)
	await process_frame
	_check(
		rewards.size() == before + 1,
		"%s: exactly one reward is booked (%d)" % [id, rewards.size() - before]
	)
	await _free(game)


## Where the child first has to act: jump, dodge, stomp, bounce, choose a way.
func _decision_s(plan) -> float:
	var first: float = INF
	for list in [plan.hurdles, plan.blockers, plan.bounces, plan.enemies, plan.waits]:
		for item in list:
			if float(item.s) > plan.start_s:
				first = minf(first, float(item.s) - 1.5)
	for list in [plan.channels, plan.platforms, plan.branches]:
		for item in list:
			if float(item.s0) > plan.start_s:
				first = minf(first, float(item.s0) - 1.5)
	return first


## "Ruhige Bewegung": the beacon glows but does not pulse, no camera kick.
func _test_calm() -> void:
	var index: int = COURSES.index_of("sonnenhafen")
	var game = await _open(index, true)
	var child := CHILD_PLAYER.new(false, 2)
	_play(game, child, 40.0, func() -> bool: return not _first("moment_done").is_empty())
	var cued: bool = not _first("moment_cue").is_empty()
	var arch: Node3D = (
		game.moment_props._arches[0] if not game.moment_props._arches.is_empty() else null
	)
	_check(
		cued and arch != null and arch.scale.is_equal_approx(Vector3.ONE),
		"calm mode: the beacon does not pulse"
	)
	_check(game.camera.reduced_motion, "calm mode reaches the camera (no kick)")
	await _free(game)
