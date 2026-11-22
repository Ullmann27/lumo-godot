extends SceneTree
## The finale of every Lumo-Lauf world, headless:
##
##   godot --headless --path . --script res://scripts/tests/lumo_run_finale_regression.gd
##       [-- --course=<id>]
##
## Dschungelherz „Tempeltor“, Zauberwald „Sternentor“, Sonnenhafen „Hafensprung“
## (a run_moments.gd moment flagged `finale`):
## 1. exactly one finale per world: the last moment, a short last stretch right
##    before the finish, with no learning stop, checkpoint or other highlight
##    inside it; the early highlight stays the first moment;
## 2. light posts in the world colour line it, a landing target waits where
##    Lumo really comes down, the launch covers the whole width of the way;
## 3. a child with a normal reaction hears ENDSPURT, masters it without a miss
##    and crosses the finish line a few seconds later; the finish line is a
##    moment of its own (ZIEL!, slow motion) and the result card waits until
##    Lumo is through (no tap goes through meanwhile), then shows the medal of
##    the star rating;
## 4. nobody falls in right before the finish: not at the edge of the way, not
##    with an early SPRINGEN, not while holding back;
## 5. the personal best-time ghost records the whole run with the finale and is
##    in the race on the next start;
## 6. "ruhige Bewegung": no slow motion at the finish.

const CHILD_PLAYER = preload("res://scripts/tests/helpers/lumo_run_child.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const SESSION = preload("res://scripts/games/run/run_session.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const STEP: float = 1.0 / 60.0
const CHILD: String = "lumo-run-finale"
const NAMES: Dictionary = {
	"dschungelherz": "Tempeltor", "zauberwald": "Sternentor", "sonnenhafen": "Hafensprung"
}

var checks: int = 0
var failures: Array[String] = []
var scene: PackedScene
var happenings: Array[Dictionary] = []


## Plays like the child player, but at the finale does one thing on purpose:
## "edge" keeps to the very edge of the way, "early" presses SPRINGEN a few
## metres before the launch, "slow" holds the stick back the whole time (on
## the path only part way: pulled right back Lumo stands still there; 0.66 is
## the really slow runner of 40 % the jumps are built for).
class FinaleRunner:
	extends RefCounted
	var child
	var spot: Dictionary
	var launch_s: float = 0.0
	var mode: String = ""
	var jumped: bool = false
	var hold_back: float = 1.0

	func _init(path: bool, finale: Dictionary, launch: float, how: String) -> void:
		child = CHILD_PLAYER.new(path, 2)
		hold_back = 0.66 if path else 1.0
		spot = finale
		launch_s = launch
		mode = how

	func drive(game, delta: float) -> void:
		var player = game.player
		if player.s < float(spot.cue) or player.s > float(spot.s1) + 2.0:
			child.drive(game, delta)
			return
		match mode:
			"edge":
				var half: float = float(game.world.wall_lateral_at(player.s)) + 0.25
				game.touch_steer = Vector2(clampf((half - player.lat) * 1.5, -1.0, 1.0), 0.0)
			"early":
				child.drive(game, delta)
				if not jumped and player.grounded and player.s >= launch_s - 3.0:
					jumped = true
					player.press_jump()
			"slow":
				child.drive(game, delta)
				game.touch_steer.y = hold_back


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[LumoFinale] FAILED CHECK: " + label)
	else:
		print("[LumoFinale] ok: " + label)


func _open(index: int, calm: bool = false):
	root.get_node("SceneRouter").launch_options = {
		"grade": 2, "subject": "Deutsch", "childKey": CHILD, "sessionId": "finale",
		"reducedMotion": calm
	}
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	if calm:
		game.reduced_motion = true
	happenings.clear()
	game.moment.connect(
		func(kind: String, detail: Dictionary) -> void:
			happenings.append(
				{"kind": kind, "t": float(game.elapsed), "s": float(game.player.s), "detail": detail}
			)
	)
	game.start_course(index, false)
	game.countdown_left = 0.0
	game.advance(STEP)
	return game


func _free(game) -> void:
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


func _of(kind: String, id: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for item in happenings:
		if str(item.kind) == kind and (id.is_empty() or str(item.detail.get("id", "")) == id):
			found.append(item)
	return found


func _finale_index(plan) -> int:
	var found: int = -1
	for index in range(plan.moments.size()):
		if bool(plan.moments[index].get("finale", false)):
			found = index if found < 0 else -2
	return found


## The launch pads of the finale (all at the same place along the way).
func _launch(plan, spot: Dictionary) -> Array[Dictionary]:
	var pads: Array[Dictionary] = []
	for pad in plan.bounces:
		if float(pad.s) >= float(spot.s0) - 3.0 and float(pad.s) <= float(spot.s1):
			pads.append(pad)
	return pads


## Steps the real game with `driver`, answering learning stops, until the
## finish or `done`. Returns facts sampled on the way.
func _play(game, driver, limit_s: float, done: Callable = Callable()) -> Dictionary:
	var facts: Dictionary = {"endspurt": false, "ziel": false, "slowmo": false, "coach": false, "land_s": -1.0}
	var steps: int = 0
	var flying: bool = false
	var finale: int = _finale_index(game.plan)
	var spot: Dictionary = game.plan.moments[finale] if finale >= 0 else {}
	# Watched from the call until a little behind the landing target.
	var watch_to: float = 0.0
	if not spot.is_empty():
		watch_to = maxf(float(spot.s1), float(spot.get("land_s", spot.s1))) + 6.0
	while game.phase != game.Phase.FINISHED and steps < int(limit_s * 60.0):
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			driver.drive(game, STEP)
		game.advance(STEP)
		steps += 1
		if game.hud.banner_label.visible and game.hud.banner_label.text == "ENDSPURT!":
			facts.endspurt = true
		var player = game.player
		if not spot.is_empty() and player.s >= float(spot.cue) and player.s <= watch_to:
			facts.coach = bool(facts.coach) or not game.hud.coach_icon.is_empty()
			if not player.grounded and player.h > 2.0:
				flying = true
			elif flying and player.grounded and float(facts.land_s) < 0.0:
				facts.land_s = float(player.s)
		if done.is_valid() and done.call():
			break
	if game.phase == game.Phase.FINISHED:
		facts.ziel = game.hud.banner_label.visible and game.hud.banner_label.text == "ZIEL!"
		facts.slowmo = float(game._slowmo_left) > 0.0
	return facts


func _run() -> void:
	scene = load("res://scenes/games/lumo_run.tscn")
	_clean()
	var only: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--course="):
			only = argument.trim_prefix("--course=")
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		if not only.is_empty() and id != only:
			continue
		await _test_layout(index)
		await _test_child_run(index)
		for mode in ["edge", "early", "slow"]:
			await _test_no_fall(index, mode)
	if only.is_empty() or only == "sonnenhafen":
		await _test_calm(COURSES.index_of("sonnenhafen"))
	_clean()
	scene = null
	happenings.clear()
	if failures.is_empty():
		print("[LumoFinale] PASS: %d checks" % checks)
	else:
		print(
			(
				"[LumoFinale] FAIL: %d of %d checks failed: %s"
				% [failures.size(), checks, " | ".join(failures)]
			)
		)
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	var effects: Node = root.get_node_or_null("AudioManager")
	if effects != null and effects.get("_pool") != null:
		for voice in effects._pool:
			voice.stop()
			voice.stream = null
		effects._samples.clear()
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)


func _clean() -> void:
	var scope: String = CHILD.sha256_text()
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		SESSION.erase(SESSION.replay_path(scope, id))
		for subject in ["Deutsch", "Mathematik"]:
			SESSION.erase(SESSION.path_for(scope, 2, subject, id))
	var records: ConfigFile = SESSION.read_sealed(SESSION.RECORDS)
	if records != null and records.has_section(SESSION._record_section(scope)):
		records.erase_section(SESSION._record_section(scope))
		SESSION.write_sealed(SESSION.RECORDS, records)


# ------------------------------------------------------------------ 1 + 2: where the finale lies


func _test_layout(index: int) -> void:
	var id: String = str(COURSES.course(index).id)
	var game = await _open(index)
	var plan = game.plan
	var finale: int = _finale_index(plan)
	_check(finale >= 0, "%s has exactly one finale" % id)
	if finale < 0:
		await _free(game)
		return
	var spot: Dictionary = plan.moments[finale]
	_check(str(spot.name) == str(NAMES[id]), "%s: the finale is the %s" % [id, str(NAMES[id])])
	_check(
		finale == plan.moments.size() - 1 and finale > 0,
		"%s: the early highlight stays first, the finale comes last" % id
	)
	var stretch: float = plan.finish_s - float(spot.cue)
	_check(
		stretch >= 50.0 and stretch <= 150.0,
		"%s: the finale is a short last stretch (%.0f m before the finish)" % [id, stretch]
	)
	var inside: Array[String] = []
	for point in plan.checkpoints:
		if float(point.s) >= float(spot.cue) - 10.0:
			inside.append("checkpoint %d" % int(point.index))
	for other in range(finale):
		if float(plan.moments[other].s1) >= float(spot.cue) - 20.0:
			inside.append(str(plan.moments[other].id))
	for passage in plan.passages:
		if float(passage.s1) >= float(spot.cue) - 10.0:
			inside.append("passage %s" % str(passage.get("name", "")))
	for list in [plan.hurdles, plan.blockers, plan.enemies, plan.waits]:
		for item in list:
			if float(item.s) >= float(spot.cue) and float(item.s) <= plan.finish_s:
				inside.append("obstacle at %.0f" % float(item.s))
	_check(inside.is_empty(), "%s: nothing else is in the way or announced inside the finale %s" % [id, str(inside)])
	_check(
		float(spot.s1) < plan.finish_s and float(spot.land_s) < plan.finish_s - 10.0,
		"%s: the landing comes well before the finish gate" % id
	)
	var posts: Array[Node] = game.moment_props.find_children("FinaleLane*", "MultiMeshInstance3D", true, false)
	var lamps: int = 0
	for node in posts:
		lamps += (node as MultiMeshInstance3D).multimesh.instance_count
	_check(
		posts.size() == 2 and lamps >= 2 * 2 * 5,
		"%s: light posts line both sides of the finale (%d)" % [id, lamps / 2]
	)
	var target: bool = false
	var land: Vector3 = game.world.position_at(float(spot.land_s), float(spot.get("land_lat", 0.0)))
	for node in game.moment_props.find_children("*", "Node3D", false, false):
		if str(node.name).contains("LandingTarget"):
			target = target or (node as Node3D).global_position.distance_to(land) < 0.5
	_check(target, "%s: a landing target waits behind the finale jump" % id)
	# The launch: over the whole width, early jumps and slow runners included.
	var pads: Array[Dictionary] = _launch(plan, spot)
	var at: float = float(pads[0].s) if not pads.is_empty() else 0.0
	var wall: float = float(game.world.wall_lateral_at(at)) + 0.25
	var covered: bool = not pads.is_empty()
	var lane: float = -wall
	while covered and lane <= wall:
		var hit: bool = false
		for pad in pads:
			hit = hit or absf(lane - float(pad.lat)) <= float(pad.half)
		covered = hit
		lane += 0.1
	var fair: bool = not pads.is_empty()
	for pad in pads:
		fair = fair and bool(pad.get("catch", false)) and bool(pad.get("carry", false))
	_check(covered, "%s: the launch covers the whole way (%d pads, ±%.1f m)" % [id, pads.size(), wall])
	_check(fair, "%s: the launch takes early jumps and carries slow runners" % id)
	var rescue: bool = false
	for item in plan.respawns:
		rescue = rescue or (float(item.s) >= float(spot.cue) - 30.0 and float(item.s) < float(spot.s0))
	for channel in plan.channels:
		if float(channel.s0) >= float(spot.s0) - 2.0 and float(channel.s0) <= float(spot.s1):
			rescue = rescue or float(channel.respawn) >= float(spot.cue) - 30.0
	_check(rescue, "%s: a fall in the finale would be caught right before its jump" % id)
	await _free(game)


# ------------------------------------------------------------------ 3 + 5: a child runs it


func _test_child_run(index: int) -> void:
	var course: Dictionary = COURSES.course(index)
	var id: String = str(course.id)
	var path: bool = bool(course.get("path", false))
	for attempt in range(2):
		var game = await _open(index)
		var finale: int = _finale_index(game.plan)
		if finale < 0:
			await _free(game)
			return
		var spot: Dictionary = game.plan.moments[finale]
		if attempt == 1:
			_check(
				game.ghost.best_time_ms() > 0 and game.hud.ghost_progress >= 0.0,
				"%s: the next start races the ghost of the run with the finale" % id
			)
		var child := CHILD_PLAYER.new(path, 2)
		child.reaction = 0.32
		var facts: Dictionary = _play(game, child, 600.0)
		var tag: String = "%s %s (run %d)" % [id, str(spot.name), attempt + 1]
		var cued: Array[Dictionary] = _of("moment_cue", str(spot.id))
		var done: Array[Dictionary] = _of("moment_done", str(spot.id))
		var missed: Array[Dictionary] = _of("moment_missed", str(spot.id))
		_check(
			game.phase == game.Phase.FINISHED,
			"%s: the course is finished (%.0f s)" % [tag, float(game.elapsed)]
		)
		_check(cued.size() == 1 and bool(facts.endspurt), "%s: announced once with ENDSPURT" % tag)
		_check(not bool(facts.coach), "%s: no coach icon covers the ENDSPURT banner" % tag)
		_check(done.size() == 1 and missed.is_empty(), "%s: mastered by a child without a miss" % tag)
		_check(_of("finish_line").size() == 1, "%s: the finish line is a moment of its own" % tag)
		var landed: float = float(facts.land_s)
		_check(
			landed > 0.0 and absf(landed - float(spot.land_s)) <= 4.0,
			"%s: Lumo comes down at the landing target (%.1f m off)" % [tag, landed - float(spot.land_s)]
		)
		if not done.is_empty() and not cued.is_empty():
			var to_finish: float = float(game.elapsed) - float(done[0].t)
			var length: float = float(game.elapsed) - float(cued[0].t)
			_check(
				to_finish >= 0.5 and to_finish <= 4.0,
				"%s: the finish line follows the finale jump (%.1f s later)" % [tag, to_finish]
			)
			_check(
				length >= 3.0 and length <= 10.0,
				"%s: the whole finale takes %.1f s" % [tag, length]
			)
			print(
				(
					"[LumoFinale] %s: cue at %.1f s, done at %.1f s, finish at %.1f s, landed %.1f m from the target"
					% [tag, float(cued[0].t), float(done[0].t), float(game.elapsed), landed - float(spot.land_s)]
				)
			)
		_check(bool(facts.ziel), "%s: ZIEL! is called at the finish line" % tag)
		_check(bool(facts.slowmo), "%s: the finish line slows the picture down" % tag)
		var rating: int = int(game.result_payload.get("rating", 0))
		_check(
			(
				game.menus.screen == "result" and rating >= 1
				and game.menus.data.get("medal") == TUNING.MEDAL_NAMES[rating - 1]
			),
			"%s: the result is the medal of the star rating (%s)" % [tag, str(game.menus.data.get("medal", ""))]
		)
		if attempt == 0:
			await _test_hold(game, tag)
			var replay: Dictionary = SESSION.replay(game.replay_path, game.plan.signature)
			_check(
				not replay.is_empty() and int(replay.time_ms) == int(game.result_payload.timeMs),
				"%s: the best-time ghost recorded the run with the finale" % tag
			)
		await _free(game)


## The result card waits until Lumo is through the gate: invisible, and a tap
## on its buttons does nothing; then it fades in and the buttons work.
func _test_hold(game, tag: String) -> void:
	var menus: Control = game.menus
	var leave: Button = menus.find_child("LeaveGames", true, false) as Button
	var pressed: Array[int] = [0]
	if leave != null:
		leave.pressed.connect(func() -> void: pressed[0] += 1)
	_check(
		menus.hold_left > 0.0 and menus.modulate.a < 0.01,
		"%s: the result card waits while Lumo crosses the line" % tag
	)
	await _tap(leave)
	_check(leave != null and pressed[0] == 0, "%s: a tap during the finish moment presses nothing" % tag)
	var waited: float = 0.0
	while menus.hold_left > 0.0 or menus.modulate.a < 1.0:
		game.advance(STEP)
		waited += STEP
		if waited > 5.0:
			break
	_check(
		waited >= 1.0 and waited <= 2.5 and menus.modulate.a >= 1.0,
		"%s: then the card fades in (after %.1f s)" % [tag, waited]
	)
	_check(menus.get_node_or_null("Hold") == null, "%s: nothing covers the buttons any more" % tag)


func _tap(control: Control) -> void:
	for _i in range(4):
		await process_frame
	if not is_instance_valid(control):
		return
	var point: Vector2 = control.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event)
		await process_frame


# ------------------------------------------------------------------ 4: nobody falls in


func _test_no_fall(index: int, mode: String) -> void:
	var course: Dictionary = COURSES.course(index)
	var id: String = str(course.id)
	var game = await _open(index)
	var finale: int = _finale_index(game.plan)
	if finale < 0:
		await _free(game)
		return
	var spot: Dictionary = game.plan.moments[finale]
	var pads: Array[Dictionary] = _launch(game.plan, spot)
	var launch: float = float(pads[0].s) if not pads.is_empty() else float(spot.s0)
	var runner := FinaleRunner.new(bool(course.get("path", false)), spot, launch, mode)
	_play(game, runner, 600.0)
	var falls: int = 0
	for item in happenings:
		if (
			str(item.kind) in ["fall", "splash", "rescue"]
			and float(item.s) >= float(spot.cue) and float(item.s) <= plan_end(game)
		):
			falls += 1
	_check(
		game.phase == game.Phase.FINISHED and not _of("moment_done", str(spot.id)).is_empty(),
		"%s (%s): the finale is mastered and the finish reached" % [id, mode]
	)
	_check(
		_of("moment_missed", str(spot.id)).is_empty() and falls == 0,
		"%s (%s): nobody falls in right before the finish (%d falls)" % [id, mode, falls]
	)
	await _free(game)


func plan_end(game) -> float:
	return float(game.plan.finish_s)


# ------------------------------------------------------------------ 6: calm


func _test_calm(index: int) -> void:
	var course: Dictionary = COURSES.course(index)
	var game = await _open(index, true)
	var child := CHILD_PLAYER.new(bool(course.get("path", false)), 2)
	var facts: Dictionary = _play(game, child, 600.0)
	_check(
		game.phase == game.Phase.FINISHED and bool(facts.ziel) and not bool(facts.slowmo),
		"calm mode: ZIEL! without slow motion"
	)
	_check(game.camera.reduced_motion, "calm mode reaches the camera (no kick)")
	await _free(game)
