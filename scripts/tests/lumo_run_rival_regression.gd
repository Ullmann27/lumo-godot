extends SceneTree
## Fips the rival, the finale and the medals of Lumo Lauf, headless, for all
## three worlds (Dschungelherz, Zauberwald, Sonnenhafen):
##
##   godot --headless --path . --script res://scripts/tests/lumo_run_rival_regression.gd
##       [-- --course=<id>]
##
## Rival (run_rival.gd): a clean scripted run beats Fips; a run with two falls
## or bumps can still beat him; a child who holds back loses; Fips never runs
## faster than his own pace, never stands in Lumo's place and is in view at the
## start and at the finish; he runs with his own sprint cycle on his skeleton.
## Finale: every world has one, it is announced with ENDSPURT and mastered by a
## child's inputs, and the finish line is a moment of its own.
## Medals (run_medals.gd): the rule, the medal of each run, saving per child,
## keeping the best one, a child switch and interrupted runs.

const BOT = preload("res://scripts/tests/helpers/lumo_run_bot.gd")
const JUNGLE_BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const CHILD_PLAYER = preload("res://scripts/tests/helpers/lumo_run_child.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const SESSION = preload("res://scripts/games/run/run_session.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const MEDALS = preload("res://scripts/games/run/run_medals.gd")
const GAIT = preload("res://scripts/games/run/run_rival_gait.gd")
const STEP: float = 1.0 / 60.0
const CHILD_A: String = "lumo-run-rival-a"
const CHILD_B: String = "lumo-run-rival-b"

var checks: int = 0
var failures: Array[String] = []
var scene: PackedScene
var router: Node
var bridge: Node
var happenings: Array[Dictionary] = []


## A scripted player that, on purpose, does not dodge or jump the first
## `blunders` things in its way (each costs one bump or fall).
class Clumsy:
	extends RefCounted
	var base
	var blunders: int = 2
	var _seen: int = 0
	var _next: float = -INF

	func _init(path: bool, count: int) -> void:
		base = JUNGLE_BOT.new(2) if path else BOT.new()
		blunders = count

	func drive(game, delta: float) -> void:
		var player = game.player
		var bumps: int = game.track.stumbles
		var from: float = (game.plan.intro_end if game.plan.adventure else game.plan.start_s) + 40.0
		if bumps > _seen:
			# One more blunder made: play properly for a while.
			_seen = bumps
			_next = player.s + 60.0
		if bumps >= blunders or player.s < from or player.s < _next or player.is_riding():
			base.drive(game, delta)
			return
		# Eyes closed: straight on, no jump, no dash, until something is hit.
		game.touch_steer = Vector2.ZERO
		player.release_jump()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[LumoRival] FAILED CHECK: " + label)


func _options(child: String) -> Dictionary:
	return {"grade": 2, "subject": "Deutsch", "childKey": child, "sessionId": "rival-test"}


func _new_game(child: String = CHILD_A):
	router.launch_options = _options(child)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.moment.connect(
		func(kind: String, detail: Dictionary) -> void:
			happenings.append({"kind": kind, "t": float(game.elapsed), "detail": detail})
	)
	return game


func _free(game, keep_save: bool = false) -> void:
	if not keep_save:
		game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


func _open(index: int, child: String = CHILD_A, with_save: bool = false):
	var game = await _new_game(child)
	game.set_process(false)
	happenings.clear()
	game.start_course(index, with_save)
	return game


func _count(kind: String) -> int:
	return happenings.filter(func(item: Dictionary) -> bool: return item.kind == kind).size()


## Plays to the finish, answering learning stops; returns sampled facts.
func _play(game, driver, limit_s: float = 900.0) -> Dictionary:
	var facts: Dictionary = {
		"max_speed": 0.0, "touching": 0, "steps": 0, "start_seen": false, "shown_run": 0
	}
	var steps: int = 0
	game.countdown_left = 0.0
	while game.phase != game.Phase.FINISHED and steps < int(limit_s * 60.0):
		if game.question_open:
			game.answer(str(game.active_question.answer))
		elif driver != null:
			driver.drive(game, STEP)
		game.advance(STEP)
		steps += 1
		var rival = game.rival
		if rival.started and not bool(facts.start_seen) and int(facts.get("start_checked", 0)) == 0:
			facts["start_checked"] = 1
			facts.start_seen = game.camera.is_position_in_frustum(
				game.rival_view.global_position + Vector3.UP
			)
		facts.max_speed = maxf(float(facts.max_speed), float(rival.speed))
		if (
			rival.started
			and absf(rival.s - game.player.s) < 1.2
			and absf(rival.lat - game.player.lat) < 0.9
			and absf(rival.h - game.player.h) < 1.2
		):
			facts.touching = int(facts.touching) + 1
		if steps % 30 == 0 and is_instance_valid(game.rival_view):
			if (
				game.rival_view._clip == "run"
				and game.rival_view.player.current_animation == GAIT.clip(GAIT.RUN)
			):
				facts.shown_run = int(facts.shown_run) + 1
	facts.steps = steps
	return facts


func _run() -> void:
	scene = load("res://scenes/games/lumo_run.tscn")
	router = root.get_node("SceneRouter")
	bridge = root.get_node("HostBridge")
	_clean()
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--course="):
			only = argument.trim_prefix("--course=")
	_test_medal_rule()
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		if not only.is_empty() and id != only:
			continue
		await _test_rival(index)
		await _test_finale(index)
	await _test_medal_store()
	_clean()
	print("[LumoRival] %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		print("[LumoRival] FAIL: " + failure)
	print("LUMO_RUN_RIVAL_REGRESSION %s" % ("PASS" if failures.is_empty() else "FAIL"))
	if root.has_node("GameSoundscape"):
		root.get_node("GameSoundscape").release_audio()
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)


func _clean() -> void:
	for child in [CHILD_A, CHILD_B]:
		var scope: String = child.sha256_text()
		for index in range(COURSES.count()):
			SESSION.erase(SESSION.path_for(scope, 2, "Deutsch", str(COURSES.course(index).id)))
		var records: ConfigFile = SESSION.read_sealed(SESSION.RECORDS)
		if records != null and records.has_section(SESSION._record_section(scope)):
			records.erase_section(SESSION._record_section(scope))
			SESSION.write_sealed(SESSION.RECORDS, records)


func _test_medal_rule() -> void:
	_check(
		MEDALS.medal_for(false, true, 0) == TUNING.MEDAL_NONE, "medal: an unfinished run has none"
	)
	_check(
		MEDALS.medal_for(true, false, 0) == TUNING.MEDAL_BRONZE,
		"medal: finish behind Fips = bronze"
	)
	_check(
		MEDALS.medal_for(true, true, 1) == TUNING.MEDAL_SILVER,
		"medal: before Fips with a bump = silver"
	)
	_check(
		MEDALS.medal_for(true, true, 0) == TUNING.MEDAL_GOLD,
		"medal: before Fips without a bump = gold"
	)
	_check(
		MEDALS.rule_text("Fips").contains("Gold: vor Fips und ohne Sturz"), "medal rule in words"
	)


func _pace(game) -> float:
	return TUNING.PATH_TIME_SCALE if game.plan.adventure else TUNING.ROAD_TIME_SCALE


# ------------------------------------------------------------------ the rival


func _test_rival(index: int) -> void:
	var course: Dictionary = COURSES.course(index)
	var id: String = str(course.id)
	var path: bool = bool(course.get("path", false))
	# Start: Fips is there, in view, and stands still during the countdown.
	var game = await _open(index)
	var rival = game.rival
	_check(rival.enabled() and str(rival.display_name) == "Fips", "%s: Fips races" % id)
	_check(
		is_instance_valid(game.rival_view) and game.rival_view.has_gait,
		"%s: Fips has his sprint cycle" % id
	)
	if not path:
		game.advance(STEP)
		_check(
			game.camera.is_position_in_frustum(game.rival_view.global_position + Vector3.UP),
			"%s: Fips is in view at the start line" % id
		)
		_check(rival.speed == 0.0 and not rival.started, "%s: Fips waits for the countdown" % id)
	# The sprint cycle really moves his legs.
	var skeleton: Skeleton3D = game.rival_view.skeleton
	var thigh: int = skeleton.find_bone("Thigh.L")
	game.rival_view.player.play(GAIT.clip(GAIT.RUN))
	game.rival_view.player.seek(0.0, true)
	var first: Quaternion = skeleton.get_bone_pose_rotation(thigh)
	game.rival_view.player.seek(GAIT.RUN_SECONDS * 0.5, true)
	var second: Quaternion = skeleton.get_bone_pose_rotation(thigh)
	_check(
		rad_to_deg(first.angle_to(second)) > 50.0,
		"%s: his thigh swings %.0f° in half a stride" % [id, rad_to_deg(first.angle_to(second))]
	)
	game.rival_view.player.play("idle")
	# A clean scripted run beats him.
	var driver = JUNGLE_BOT.new(2) if path else BOT.new()
	var facts: Dictionary = await _play(game, driver)
	var won: bool = bool(game.beat_rival)
	var target: float = rival.race_seconds() / _pace(game)
	print(
		(
			"[LumoRival] %s clean: %.1f s, stumbles %d, won %s, %s, Fips target %.1f s, medal %s"
			% [
				id,
				game.elapsed,
				game.track.stumbles,
				str(won),
				str(game.result_payload.get("rival", {})),
				target,
				MEDALS.id_of(game.medal)
			]
		)
	)
	_check(game.phase == game.Phase.FINISHED, "%s: the clean run finishes" % id)
	_check(won, "%s: a clean scripted run beats Fips" % id)
	_check(
		float(facts.max_speed) <= rival.pace + 0.001,
		"%s: Fips never runs faster than his pace (%.2f)" % [id, float(facts.max_speed)]
	)
	_check(
		int(facts.touching) == 0,
		"%s: Fips never stands in Lumo's place (%d)" % [id, int(facts.touching)]
	)
	_check(
		int(facts.shown_run) > 20,
		"%s: Fips is seen running with his cycle (%d samples)" % [id, int(facts.shown_run)]
	)
	_check(bool(facts.start_seen), "%s: Fips is in view when the race starts" % id)
	_check(
		_count("rival_start") == 1, "%s: the race starts once (%d)" % [id, _count("rival_start")]
	)
	_check(
		game.medal >= TUNING.MEDAL_SILVER,
		"%s: the clean run earns silver or gold (%s)" % [id, MEDALS.id_of(game.medal)]
	)
	# At the finish he runs into his place beside the gate and is in view.
	for _i in range(240):
		game.advance(STEP)
	_check(
		(
			rival.s >= game.plan.finish_s
			and game.camera.is_position_in_frustum(
				game.rival_view.global_position + Vector3.UP * 0.8
			)
		),
		"%s: Fips is in view at the finish (s=%.0f)" % [id, rival.s]
	)
	await _free(game)
	# Two falls or bumps: not lost automatically.
	game = await _open(index)
	var clumsy := Clumsy.new(path, 2)
	await _play(game, clumsy)
	print(
		(
			"[LumoRival] %s two blunders: %.1f s, stumbles %d, won %s"
			% [id, game.elapsed, game.track.stumbles, str(game.beat_rival)]
		)
	)
	_check(
		game.track.stumbles >= 2,
		"%s: the clumsy run really fell or bumped (%d)" % [id, game.track.stumbles]
	)
	_check(game.beat_rival, "%s: two falls do not lose the race by themselves" % id)
	_check(
		game.medal == TUNING.MEDAL_SILVER,
		"%s: before Fips with falls = silver (%s)" % [id, MEDALS.id_of(game.medal)]
	)
	await _free(game)
	# A child who holds back loses: it is a real race.
	game = await _open(index)
	var slow = JUNGLE_BOT.new(2) if path else BOT.new()
	var dawdle := DawdleDriver.new(slow, path)
	await _play(game, dawdle)
	print(
		(
			"[LumoRival] %s holding back: %.1f s, won %s, medal %s"
			% [id, game.elapsed, str(game.beat_rival), MEDALS.id_of(game.medal)]
		)
	)
	_check(
		game.phase == game.Phase.FINISHED and not game.beat_rival,
		"%s: holding back loses against Fips" % id
	)
	_check(game.medal == TUNING.MEDAL_BRONZE, "%s: behind Fips = bronze" % id)
	await _free(game)


## Holds the stick back every other few seconds (a dawdling child).
class DawdleDriver:
	extends RefCounted
	var base
	var path: bool = false
	var clock: float = 0.0

	func _init(driver, on_path: bool) -> void:
		base = driver
		path = on_path

	func drive(game, delta: float) -> void:
		clock += delta
		base.drive(game, delta)
		if fmod(clock, 4.0) < (1.6 if path else 2.6):
			game.touch_steer.y = 1.0


# ------------------------------------------------------------------ the finale


func _test_finale(index: int) -> void:
	var course: Dictionary = COURSES.course(index)
	var id: String = str(course.id)
	var path: bool = bool(course.get("path", false))
	var game = await _open(index)
	var finale: int = -1
	for spot in range(game.plan.moments.size()):
		if bool(game.plan.moments[spot].get("finale", false)):
			finale = spot
	_check(finale >= 0, "%s has a finale" % id)
	if finale < 0:
		await _free(game)
		return
	var spot: Dictionary = game.plan.moments[finale]
	_check(finale == game.plan.moments.size() - 1, "%s: the finale is the last moment" % id)
	_check(
		game.plan.finish_s - float(spot.cue) <= 140.0,
		(
			"%s: the finale is a short last stretch (%.0f m)"
			% [id, game.plan.finish_s - float(spot.cue)]
		)
	)
	_check(
		game.moment_props.find_children("FinaleLane", "", true, false).size() == 2,
		"%s: light posts line the finale" % id
	)
	var child := CHILD_PLAYER.new(path, 2)
	var banner_seen: Array[bool] = [false]
	var steps: int = 0
	game.countdown_left = 0.0
	while game.phase != game.Phase.FINISHED and steps < 60 * 900:
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			child.drive(game, STEP)
		game.advance(STEP)
		steps += 1
		if game.hud.banner_label.visible and game.hud.banner_label.text == "ENDSPURT!":
			banner_seen[0] = true
	var done: Array = happenings.filter(
		func(item: Dictionary) -> bool:
			return item.kind == "moment_done" and str(item.detail.get("id", "")) == str(spot.id)
	)
	var cued: Array = happenings.filter(
		func(item: Dictionary) -> bool:
			return item.kind == "moment_cue" and str(item.detail.get("id", "")) == str(spot.id)
	)
	_check(not cued.is_empty() and banner_seen[0], "%s: the finale is called ENDSPURT" % id)
	_check(not done.is_empty(), "%s: a child masters the finale %s" % [id, str(spot.name)])
	_check(_count("finish_line") == 1, "%s: the finish line is a moment of its own" % id)
	if not done.is_empty():
		var before_finish: float = float(game.elapsed) - float(done[0].t)
		_check(
			before_finish < 6.0,
			"%s: the finale ends right before the finish (%.1f s)" % [id, before_finish]
		)
	var menu = game.menus
	_check(
		menu.screen == "result" and menu.find_child("Medal", true, false) != null,
		"%s: the result shows the medal" % id
	)
	_check(
		menu.find_child("MedalRule", true, false) != null,
		"%s: the result explains the medal rule" % id
	)
	print(
		(
			"[LumoRival] %s finale %s: done %s, medal %s"
			% [id, str(spot.name), str(not done.is_empty()), MEDALS.id_of(game.medal)]
		)
	)
	await _free(game)


# ------------------------------------------------------------------ medals per child


func _record(child: String, id: String) -> Dictionary:
	return SESSION.record(child.sha256_text(), id)


func _test_medal_store() -> void:
	_clean()
	var id: String = "zauberwald"
	var scope_a: String = CHILD_A.sha256_text()
	SESSION.store_record(scope_a, id, 2, 90000, TUNING.MEDAL_SILVER)
	_check(int(_record(CHILD_A, id).medal) == TUNING.MEDAL_SILVER, "medal is saved for the child")
	SESSION.store_record(scope_a, id, 3, 95000, TUNING.MEDAL_BRONZE)
	var best: Dictionary = _record(CHILD_A, id)
	_check(
		int(best.medal) == TUNING.MEDAL_SILVER and int(best.rating) == 3,
		"a worse medal never replaces a better one"
	)
	_check(_record(CHILD_B, id).is_empty(), "another child has no medal of child A")
	# A finished run of child B books its own medal; child A keeps hers.
	var index: int = COURSES.index_of("sonnenhafen")
	var game = await _open(index, CHILD_B)
	await _play(game, BOT.new())
	var medal_b: int = int(game.medal)
	await _free(game)
	_check(
		int(_record(CHILD_B, "sonnenhafen").get("medal", -1)) == medal_b and medal_b > 0,
		"child B's finished run saves its medal"
	)
	_check(_record(CHILD_A, "sonnenhafen").is_empty(), "child A is untouched by child B's run")
	# The course choice shows each child's own medal.
	var start = await _new_game(CHILD_A)
	await process_frame
	var card: Node = start.menus.find_child("Course%d" % COURSES.index_of(id), true, false)
	_check(
		card != null and card.find_child("Medal", true, false) != null,
		"course choice shows child A's medal"
	)
	var label: Label = card.find_child("Best", true, false) if card != null else null
	_check(
		label != null and label.text.contains("Silber"),
		"the card names the medal (%s)" % (label.text if label != null else "-")
	)
	var other: Node = start.menus.find_child("Course%d" % index, true, false)
	_check(
		other != null and other.find_child("Medal", true, false) == null,
		"no medal on a course child A never finished"
	)
	await _free(start)
	var start_b = await _new_game(CHILD_B)
	await process_frame
	var card_b: Node = start_b.menus.find_child("Course%d" % index, true, false)
	_check(
		card_b != null and card_b.find_child("Medal", true, false) != null,
		"after the child switch child B sees her medal"
	)
	await _free(start_b)
	# An interrupted run changes nothing: pause, leave, abandon.
	var before: Dictionary = _record(CHILD_A, id)
	game = await _open(COURSES.index_of(id), CHILD_A)
	game.countdown_left = 0.0
	var bot = BOT.new()
	for _i in range(60 * 40):
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			bot.drive(game, STEP)
		game.advance(STEP)
	game.pause()
	game.return_to_app("games")
	await _free(game, true)
	_check(
		_record(CHILD_A, id) == before,
		"an interrupted run leaves the medal and the best result as they were"
	)
	# Resuming the saved run and finishing it books the medal of that run.
	game = await _open(COURSES.index_of(id), CHILD_A, true)
	_check(game.track.checkpoint >= 0, "the interrupted run resumes at its checkpoint")
	await _play(game, BOT.new())
	_check(
		game.phase == game.Phase.FINISHED and game.medal > 0,
		"the resumed run finishes with a medal (%s)" % MEDALS.id_of(game.medal)
	)
	_check(
		int(_record(CHILD_A, id).medal) == maxi(TUNING.MEDAL_SILVER, game.medal),
		"the best medal is kept after the resumed run"
	)
	await _free(game)
