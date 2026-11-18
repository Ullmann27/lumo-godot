extends Node3D
## Lumo Lauf: Lumo runs through the big Lumo Kart worlds, seen from behind.
## He runs on his own; the child steers, jumps and dashes, collects stars and
## answers three learning stops on the way to the finish gate.
##
## This script only connects the parts and owns the rules of a run:
##   run_course_plan.gd  what lies on the course (deterministic)
##   run_track.gd        live state of the course, pickups and bumps
##   run_player.gd       Lumo's motion (speed, steering, jump, dash)
##   run_props.gd / run_actor.gd / run_camera.gd / run_fx.gd   what is drawn
##   run_hud.gd / run_menus.gd   controls and screens
##   run_session.gd      save file and best results

const WORLD = preload("res://scripts/games/kart_world.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const PLAN = preload("res://scripts/games/run/run_course_plan.gd")
const TRACK = preload("res://scripts/games/run/run_track.gd")
const PLAYER = preload("res://scripts/games/run/run_player.gd")
const PROPS = preload("res://scripts/games/run/run_props.gd")
const ACTOR = preload("res://scripts/games/run/run_actor.gd")
const CAMERA = preload("res://scripts/games/run/run_camera.gd")
const FX = preload("res://scripts/games/run/run_fx.gd")
const HUD = preload("res://scripts/games/run/run_hud.gd")
const MENUS = preload("res://scripts/games/run/run_menus.gd")
const STAGE = preload("res://scripts/games/run/run_menu_stage.gd")
const SESSION = preload("res://scripts/games/run/run_session.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const UI = preload("res://scripts/games/run/run_ui.gd")
const QUESTIONS = preload("res://scripts/games/kart_questions.gd")

enum Phase { MENU, LOADING, COUNTDOWN, RUNNING, FINISHED }

const HINTS: Dictionary = {
	"hurdle": "Hürde! Tippe SPRINGEN.",
	"double": "Zwei Hürden hintereinander!",
	"channel": "Wassergraben! Spring hinüber.",
	"slalom": "Slalom! Lenke um die Hindernisse.",
	"gate": "Lenke durch die Lücke.",
	"bounce": "Sprungfeder! Lauf einfach drauf.",
	"high": "Die Sprungfeder bringt dich auf den Hochweg.",
	"boost": "Turbo-Feld!",
	"crates": "Kisten! FLITZEN zerbricht sie.",
	"roller": "Rollstein! Weich aus oder spring.",
}

var phase: Phase = Phase.MENU
var paused: bool = false
var question_open: bool = false
var abandoned: bool = false
var grade: int = 1
var subject: String = "Mathematik"
var child_scope: String = ""
var reduced_motion: bool = false
var lightweight: bool = false
var course_index: int = -1
var world
var plan
var track
var player
var props
var actor
var camera
var fx
var hud
var menus
var stage
var session_path: String = ""
var result_id: String = ""
var result_payload: Dictionary = {}
var elapsed: float = 0.0
var run_clock: float = 0.0
var countdown_left: float = 0.0
var questions: Dictionary = {}
var active_question: Dictionary = {}
var question_checkpoint: int = -1
var wrong_answers: Array[String] = []
var recent_questions: Array[String] = []
var snapshot: Dictionary = {}
var touch_steer := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var _hinted: Dictionary = {}
var _hint_cursor: int = 0
var _coast: float = 0.0
var _previous_auto_accept_quit: bool = true
var _previous_quit_on_go_back: bool = true


func _ready() -> void:
	rng.randomize()
	var options: Dictionary = SceneRouter.launch_options
	grade = clampi(int(options.get("grade", 1)), 1, 4)
	subject = str(options.get("subject", "Mathematik"))
	if subject not in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]:
		subject = "Mathematik"
	var child_key: String = str(options.get("childKey", HostBridge.launch_options().get("childKey", "")))
	if not child_key.is_empty() and child_key != "standalone":
		child_scope = child_key.sha256_text()
	reduced_motion = bool(options.get("reduceAnimations", false))
	lightweight = SettingsStore.get_profile() == "low"
	result_id = HostBridge.new_result_id()
	_previous_auto_accept_quit = get_tree().auto_accept_quit
	_previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_build_screens()
	var wanted: int = COURSES.index_of(str(options.get("runCourse", "")))
	if wanted >= 0 and bool(options.get("runAutoStart", false)):
		SceneRouter.launch_options.erase("runAutoStart")
		start_course(wanted, false)
	else:
		_show_start()
	print("[LumoRun] ready: grade=%d subject=%s courses=%d" % [grade, subject, COURSES.count()])


func _build_screens() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Screens"
	layer.layer = 5
	add_child(layer)
	hud = HUD.new()
	hud.name = "Hud"
	layer.add_child(hud)
	menus = MENUS.new()
	menus.name = "Menus"
	layer.add_child(menus)
	hud.pause_pressed.connect(pause)
	hud.steer_changed.connect(func(axis: Vector2) -> void: touch_steer = axis)
	hud.jump_changed.connect(_on_jump)
	hud.dash_pressed.connect(_on_dash)
	menus.course_chosen.connect(_on_course_chosen)
	menus.answer_chosen.connect(answer)
	menus.resume_pressed.connect(resume)
	menus.restart_pressed.connect(func() -> void: _reload(course_index, true))
	menus.again_pressed.connect(func() -> void: _reload(course_index, true))
	menus.courses_pressed.connect(func() -> void: _reload(-1, false))
	menus.leave_pressed.connect(return_to_app)
	get_viewport().size_changed.connect(_frame_stage)
	hud.set_playing(false)


# ------------------------------------------------------------------ course selection

func _identity(index: int) -> Dictionary:
	return {
		"child_scope": child_scope,
		"grade": grade,
		"subject": subject,
		"course": str(COURSES.course(index).id),
	}


func _path(index: int) -> String:
	return SESSION.path_for(child_scope, grade, subject, str(COURSES.course(index).id))


func _show_start() -> void:
	phase = Phase.MENU
	hud.set_playing(false)
	stage = STAGE.new()
	stage.name = "MenuStage"
	add_child(stage)
	stage.setup(reduced_motion)
	var cards: Array[Dictionary] = []
	for index in range(COURSES.count()):
		var course: Dictionary = COURSES.course(index)
		var saved: int = SESSION.peek(_path(index), _identity(index))
		var best: Dictionary = SESSION.record(child_scope, str(course.id))
		var best_text: String = "Noch kein Lauf"
		if not best.is_empty():
			best_text = "Bestwert: %s · %s" % ["★".repeat(int(best.rating)), UI.clock(int(best.time_ms))]
		cards.append(
			{
				"index": index,
				"name": course.name,
				"kicker": course.kicker,
				"length": course.length,
				"description": course.description,
				"accent": course.accent,
				"emblem": course.emblem,
				"best": "Gespeichert: Kontrollpunkt %d" % (saved + 1) if saved >= 0 else best_text,
				"resume": saved >= 0,
				"resume_text": "Weiterlaufen",
			}
		)
	menus.open("start", {"cards": cards})
	_frame_stage()


func _frame_stage() -> void:
	if is_instance_valid(stage) and is_instance_valid(menus) and menus.screen == "start":
		stage.frame.call_deferred(menus.hero_rect)


func _on_course_chosen(index: int, with_save: bool) -> void:
	if phase != Phase.MENU:
		return
	phase = Phase.LOADING
	var course: Dictionary = COURSES.course(index)
	menus.open("loading", {"name": course.name, "accent": course.accent})
	# Let the loading card be drawn before the world is built in one go.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and phase == Phase.LOADING:
		start_course(index, with_save)


## Builds the course and puts Lumo on the start line (or at the saved checkpoint).
func start_course(index: int, with_save: bool) -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
		stage = null
	course_index = clampi(index, 0, COURSES.count() - 1)
	var course: Dictionary = COURSES.course(course_index)
	world = WORLD.new()
	world.name = "RunWorld"
	add_child(world)
	world.build(lightweight, str(course.track))
	if world.find_children("*", "WorldEnvironment", true, false).is_empty():
		# Dschungelherz brings no sky or sun of its own; give it the daylight that
		# its track definition describes instead of the project's default dusk.
		world._lighting()
	plan = PLAN.build(world, course)
	track = TRACK.new()
	track.setup(plan, world)
	props = PROPS.new()
	props.name = "RunProps"
	add_child(props)
	props.build(world, plan, COURSES.theme(course_index), lightweight, reduced_motion)
	player = PLAYER.new()
	player.place(plan.start_s, 0.0, 0.0)
	actor = ACTOR.new()
	actor.name = "Lumo"
	add_child(actor)
	actor.setup(reduced_motion)
	camera = CAMERA.new()
	camera.name = "ChaseCamera"
	camera.reduced_motion = reduced_motion
	camera.near = 0.2
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	fx = FX.new()
	fx.name = "RunFx"
	add_child(fx)
	fx.setup(lightweight, reduced_motion)
	PerformanceManager.set_profile(PerformanceManager.current_profile, false)
	session_path = _path(course_index)
	questions.clear()
	active_question = {}
	question_open = false
	snapshot = {}
	elapsed = 0.0
	run_clock = 0.0
	_hinted.clear()
	_hint_cursor = 0
	var restored: bool = with_save and _restore()
	if not restored:
		SESSION.erase(session_path)
	var shares := PackedFloat32Array()
	var flags := PackedByteArray()
	for checkpoint in plan.checkpoints:
		shares.append(_share(float(checkpoint.s)))
		flags.append(1 if bool(checkpoint.question) else 0)
	hud.set_course(shares, flags, plan.star_total)
	menus.close()
	hud.set_playing(true)
	paused = false
	phase = Phase.COUNTDOWN
	countdown_left = 1.0 if reduced_motion else 3.0
	_update_view(0.0, true)
	if not restored:
		actor.greet()
	elif with_save:
		hud.say("Weiter ab Kontrollpunkt %d." % (track.checkpoint + 1), 3.0)
	if with_save and not restored:
		hud.say("Der Spielstand passte nicht mehr. Wir starten neu.", 3.5)
	print("[LumoRun] course %s: %.0f m, %d stars, %d checkpoints" % [course.id, plan.length, plan.star_total, plan.checkpoints.size()])


func _share(s: float) -> float:
	return clampf((s - plan.start_s) / maxf(1.0, plan.finish_s - plan.start_s), 0.0, 1.0)


# ------------------------------------------------------------------ the run

func _process(delta: float) -> void:
	if phase == Phase.MENU or phase == Phase.LOADING or not is_instance_valid(world):
		return
	var left: float = minf(delta, 0.1)
	while left > 0.0001:
		var step: float = minf(left, 1.0 / 60.0)
		advance(step)
		left -= step


## One simulation step. Called per frame; tests call it directly.
func advance(delta: float) -> void:
	if phase == Phase.COUNTDOWN and not paused:
		countdown_left -= delta
		hud.show_countdown(str(ceili(countdown_left)) if countdown_left > 0.0 else "")
		if countdown_left <= 0.0:
			phase = Phase.RUNNING
			player.speed = TUNING.START_SPEED
			if not _reopen_question():
				hud.say("Lenke mit dem Stick. SPRINGEN tippen oder halten!", 3.5)
	elif phase == Phase.RUNNING and not paused and not question_open:
		_step(delta)
	elif phase == Phase.FINISHED and _coast > 0.0:
		_coast = maxf(0.0, _coast - 9.0 * delta)
		player.previous_s = player.s
		player.s += _coast * delta
		player.speed = _coast
	_update_view(delta, false)


func _step(delta: float) -> void:
	elapsed += delta
	run_clock += delta
	var steer := Vector2(
		Input.get_axis("ui_left", "ui_right") + touch_steer.x,
		Input.get_axis("ui_up", "ui_down") + touch_steer.y
	).limit_length(1.0)
	player.step(delta, steer, track)
	var events: Array[Dictionary] = track.resolve(player, run_clock)
	for event in player.events:
		_on_player_event(event)
	player.events.clear()
	for event in events:
		_on_track_event(event)
	if phase != Phase.RUNNING:
		return
	props.advance(delta, run_clock, player.s)
	_hint_ahead()
	hud.set_state(track.kept, _share(player.s), solved_count(), track.checkpoint)
	hud.set_dash_cooldown(player.dash_cooldown / TUNING.DASH_COOLDOWN)


func feet_transform() -> Transform3D:
	if player.loop_u >= 0.0:
		return player.loop_transform(world)
	var basis: Basis = world.frame(player.s)
	var forward: Vector3 = (
		-basis.z + basis.x * clampf(player.lat_v / maxf(player.speed, 5.0), -0.55, 0.55)
	).normalized()
	return Transform3D(
		Basis.looking_at(forward, basis.y), world.position_at(player.s, player.lat) + Vector3.UP * player.h
	)


func _update_view(delta: float, snap: bool) -> void:
	var feet: Transform3D = feet_transform()
	var basis: Basis = world.frame(player.s)
	var floor_height: float = track.ground_at(player.s, player.lat, player.h)
	var ground := Transform3D(
		basis, world.position_at(player.s, player.lat) + Vector3.UP * maxf(floor_height, -40.0)
	)
	actor.apply(feet, ground, player, maxf(delta, 0.0001), paused or question_open or phase == Phase.COUNTDOWN)
	camera.follow(world, player, feet.origin, maxf(delta, 0.0001), snap)


func _on_player_event(event: StringName) -> void:
	var feet: Vector3 = feet_transform().origin
	match event:
		&"jump":
			AudioManager.play_sfx("card_next")
		&"land":
			if player.land_impact > 6.0:
				fx.play("dust", feet + Vector3.UP * 0.15)
			if player.land_impact > 12.0:
				camera.kick(0.35)
		&"dash":
			fx.play("dust", feet + Vector3.UP * 0.3)
			AudioManager.play_sfx("ui_confirm")
		&"loop_start":
			hud.say("Looping!", 2.0)
		&"loop_end":
			fx.play("sparkle", feet + Vector3.UP * 1.0)
			camera.follow(world, player, feet, 0.016, true)


func _on_track_event(event: Dictionary) -> void:
	var feet: Vector3 = feet_transform().origin
	match str(event.type):
		"star":
			props.hide_star(int(event.index))
			fx.play("sparkle", props.star_position(int(event.index)))
			AudioManager.play_sfx("star_collected")
		"stumble":
			camera.kick(0.6)
			AudioManager.play_sfx("ui_cancel")
			hud.say("Hoppla! Weiter geht's.", 1.6)
		"splash", "fall":
			fx.play("splash", feet + Vector3.UP * 0.3)
			AudioManager.play_sfx("ui_cancel")
			if bool(event.helped):
				hud.say("Lumo hilft dir hinüber. Weiter!", 2.6)
			elif str(event.type) == "fall":
				hud.say("Nimm das Turbo-Feld mit, dann klappt der große Sprung!", 3.0)
			else:
				hud.say("Platsch! Spring über den Graben – SPRINGEN halten.", 2.8)
			_update_view(0.016, true)
		"bounce":
			props.press_bounce(int(event.index))
			AudioManager.play_sfx("ui_confirm")
		"boost":
			AudioManager.play_sfx("ui_confirm")
		"crate":
			props.break_crate(int(event.index))
			fx.play("burst", feet + Vector3.UP * 0.9, Color("ffe27a"))
			if int(event.stars) > 0:
				AudioManager.play_sfx("star_collected")
				hud.say("+%d Sterne aus der Kiste!" % int(event.stars), 1.4)
		"roller":
			props.knock_roller(int(event.index))
			fx.play("burst", feet + Vector3.UP * 0.9, Color("d6e2f2"))
		"checkpoint":
			_reach_checkpoint(int(event.index))
		"finish":
			_finish()


func _hint_ahead() -> void:
	while _hint_cursor < plan.beats.size() and float(plan.beats[_hint_cursor].s) < player.s - 4.0:
		_hint_cursor += 1
	if _hint_cursor >= plan.beats.size():
		return
	var beat: Dictionary = plan.beats[_hint_cursor]
	var kind: String = str(beat.kind)
	if float(beat.s) - player.s < 6.0 and HINTS.has(kind) and not _hinted.has(kind):
		_hinted[kind] = true
		hud.say(str(HINTS[kind]), 2.6)


# ------------------------------------------------------------------ checkpoints and learning stops

func _reach_checkpoint(index: int) -> void:
	props.set_checkpoint(index, true)
	fx.play("burst", props.point(float(plan.checkpoints[index].s), 0.0, 3.0), Color("ffe27a"))
	AudioManager.play_sfx("celebrate")
	_take_snapshot()
	if bool(plan.checkpoints[index].question) and not questions.has(index):
		_open_question(index, {})
	else:
		hud.say("Kontrollpunkt %d gespeichert!" % (index + 1), 2.0)
	save()


func _take_snapshot() -> void:
	snapshot = track.snapshot()
	snapshot["elapsed_ms"] = int(elapsed * 1000.0)
	snapshot["questions"] = questions.duplicate(true)


func _open_question(index: int, saved: Dictionary) -> void:
	question_open = true
	question_checkpoint = index
	wrong_answers.clear()
	player.release_inputs()
	touch_steer = Vector2.ZERO
	hud.release_controls()
	hud.set_playing(false)
	if saved.is_empty():
		for attempt in range(30):
			active_question = QUESTIONS.make(grade, subject, rng)
			if not recent_questions.has(str(active_question.prompt)):
				break
		recent_questions.append(str(active_question.prompt))
	else:
		active_question = saved
	_show_question()


## After a resume: the learning stop of the saved checkpoint is still open.
func _reopen_question() -> bool:
	var index: int = track.checkpoint
	if index < 0 or not bool(plan.checkpoints[index].question) or questions.has(index):
		return false
	_open_question(index, active_question)
	return true


func _show_question() -> void:
	var message: String = "Lass dir Zeit. Lumo wartet auf dich."
	var reveal: bool = wrong_answers.size() >= 2
	if reveal:
		message = "Die Lösung ist „%s“. Tippe sie an, dann geht es weiter." % str(active_question.answer)
	elif not wrong_answers.is_empty():
		message = "Fast! Schau noch einmal hin: %s" % str(active_question.get("hint", ""))
	menus.open(
		"question",
		{
			"header": "Lernstopp · %d. Klasse · %s" % [grade, subject],
			"prompt": active_question.prompt,
			"options": active_question.options,
			"answer": active_question.answer,
			"wrong": wrong_answers.duplicate(),
			"reveal": reveal,
			"message": message,
		}
	)


## A right answer gives a small boost and bonus stars. A wrong one costs nothing:
## the child gets a hint and tries again; after two misses the solution is shown.
func answer(text: String) -> void:
	if not question_open or paused or phase != Phase.RUNNING:
		return
	if text != str(active_question.answer):
		if not wrong_answers.has(text):
			wrong_answers.append(text)
		AudioManager.play_sfx("ui_back")
		_show_question()
		return
	var shown: bool = wrong_answers.size() >= 2
	questions[question_checkpoint] = {"correct": not shown, "first": wrong_answers.is_empty()}
	question_open = false
	active_question = {}
	menus.close()
	hud.set_playing(true)
	if shown:
		hud.say("Jetzt weißt du es. Weiter geht's!", 2.4)
	else:
		track.add_bonus(TUNING.QUESTION_BONUS_STARS)
		player.boost(TUNING.ANSWER_BOOST_SECONDS)
		AudioManager.play_sfx("celebrate")
		hud.say("Richtig! +%d Sterne" % TUNING.QUESTION_BONUS_STARS, 2.4)
	_take_snapshot()
	save()


## Learning stops answered correctly (not the ones where the solution was shown).
func solved_count() -> int:
	var count: int = 0
	for index in questions:
		if bool(questions[index].correct):
			count += 1
	return count


func first_try_count() -> int:
	var count: int = 0
	for index in questions:
		if bool(questions[index].correct) and bool(questions[index].first):
			count += 1
	return count


# ------------------------------------------------------------------ pause, save, resume

func pause() -> void:
	if paused or phase not in [Phase.COUNTDOWN, Phase.RUNNING]:
		return
	paused = true
	player.release_inputs()
	touch_steer = Vector2.ZERO
	hud.release_controls()
	hud.set_playing(false)
	save()
	var summary: String = "%s · %d Sterne · %s" % [
		str(COURSES.course(course_index).name), track.kept, UI.clock(int(elapsed * 1000.0))
	]
	menus.open("pause", {"summary": summary})


func resume() -> void:
	if not paused:
		return
	paused = false
	if question_open:
		_show_question()
	else:
		menus.close()
		hud.set_playing(true)


## Writes the state of the last checkpoint. Before the first one there is nothing to keep.
func save() -> void:
	if phase == Phase.FINISHED or abandoned or snapshot.is_empty() or session_path.is_empty():
		return
	var state: Dictionary = snapshot.duplicate(true)
	state["result_id"] = result_id
	state["pending_question"] = active_question if question_open else {}
	state["recent_questions"] = recent_questions
	var identity: Dictionary = _identity(course_index)
	identity["signature"] = plan.signature
	if not SESSION.save(session_path, identity, state):
		push_warning("[LumoRun] checkpoint could not be saved")


func _restore() -> bool:
	var identity: Dictionary = _identity(course_index)
	identity["signature"] = plan.signature
	var state: Dictionary = SESSION.load_valid(session_path, identity, plan)
	if state.is_empty():
		return false
	track.restore(state)
	questions = state.questions
	elapsed = float(state.elapsed_ms) / 1000.0
	result_id = str(state.result_id)
	recent_questions.assign(state.recent_questions)
	active_question = state.pending_question
	player.place(track.checkpoint_s(track.checkpoint), 0.0, 0.0)
	props.sync(track)
	_take_snapshot()
	return true


func _reload(index: int, auto_start: bool) -> void:
	if abandoned:
		return
	if auto_start and phase != Phase.FINISHED:
		# "Strecke neu starten": the old checkpoint is given up on purpose.
		abandoned = true
		SESSION.erase(session_path)
	else:
		save()
		abandoned = true
	var options: Dictionary = SceneRouter.launch_options.duplicate(true)
	options.erase("runCourse")
	options.erase("runAutoStart")
	if index >= 0 and auto_start:
		options["runCourse"] = str(COURSES.course(index).id)
		options["runAutoStart"] = true
	SceneRouter.launch_options = options
	SceneRouter.goto("run")


# ------------------------------------------------------------------ finish and return

func _finish() -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	_coast = player.speed
	player.release_inputs()
	hud.release_controls()
	hud.set_playing(false)
	var course: Dictionary = COURSES.course(course_index)
	var solved: int = solved_count()
	var stars_rating: int = TUNING.rating(track.kept, plan.star_total)
	var reward: int = TUNING.reward(solved, stars_rating)
	var time_ms: int = int(elapsed * 1000.0)
	ProgressStore.add_stars(reward)
	result_payload = {
		"game": "run",
		"sessionId": str(SceneRouter.launch_options.get("sessionId", "")),
		"resultId": result_id,
		"status": "completed",
		"stars": reward,
		"solved": solved,
		"grade": grade,
		"subject": subject,
		"course": str(course.id),
		"rating": stars_rating,
		"collected": track.kept,
		"collectible": plan.star_total,
		"timeMs": time_ms,
		"firstTry": first_try_count(),
		"stumbles": track.stumbles,
	}
	var accepted: bool = HostBridge.reward(result_payload)
	if HostBridge.reward_is_recoverable(result_id):
		SESSION.erase(session_path)
	SESSION.store_record(child_scope, str(course.id), stars_rating, time_ms)
	AudioManager.play_sfx("celebrate")
	fx.play("burst", feet_transform().origin + Vector3.UP * 2.2, Color("ffe27a"))
	actor.celebrate()
	camera.show_front()
	var content: Dictionary = {
		"course": course.name,
		"accent": course.accent,
		"rating": stars_rating,
		"facts": [
			["Sterne", "%d von %d" % [track.kept, plan.star_total]],
			["Zeit", UI.clock(time_ms)],
			["Aufgaben", "%d von %d richtig" % [solved, plan.question_checkpoints().size()]],
			["Belohnung", "+%d Sterne" % reward],
		],
		"thresholds": "★ Ziel · ★★ ab %d %% · ★★★ ab %d %% der Sterne" % [
			roundi(TUNING.RATING_TWO * 100.0), roundi(TUNING.RATING_THREE * 100.0)
		],
	}
	if HostBridge.is_embedded() and not accepted:
		content["notice"] = HostBridge.SAVE_FAILURE
	menus.open("result", content)
	print("[LumoRun] finished: course=%s reward=%d rating=%d kept=%d/%d solved=%d time=%s" % [
		course.id, reward, stars_rating, track.kept, plan.star_total, solved, UI.clock(time_ms)
	])


## Leaves to the app. A finished run reports its reward (once, by result id); a
## paused or abandoned run reports no stars.
func return_to_app(destination: String) -> void:
	save()
	if phase == Phase.FINISHED:
		HostBridge.reward(result_payload)
		if HostBridge.reward_is_recoverable(result_id):
			SESSION.erase(session_path)
	var payload: Dictionary = result_payload
	if phase != Phase.FINISHED:
		payload = {
			"game": "run",
			"resultId": result_id,
			"status": "paused",
			"stars": 0,
			"solved": 0,
			"grade": grade,
			"subject": subject,
		}
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app(destination, payload):
			_show_save_failure()
		return
	SceneRouter.goto("learn" if destination == "learn" else "games")


func _show_save_failure() -> void:
	if menus.screen in ["pause", "result"]:
		var content: Dictionary = menus.data.duplicate(true)
		content["notice"] = HostBridge.SAVE_FAILURE
		menus.open(menus.screen, content)
	else:
		hud.say(HostBridge.SAVE_FAILURE, 4.0)


# ------------------------------------------------------------------ input and lifecycle

func _on_jump(held: bool) -> void:
	if phase != Phase.RUNNING or paused or question_open:
		return
	if held:
		player.press_jump()
	else:
		player.release_jump()


func _on_dash() -> void:
	if phase == Phase.RUNNING and not paused and not question_open:
		player.press_dash()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			_back()
		elif event.keycode in [KEY_SPACE, KEY_W]:
			_on_jump(event.pressed)
		elif event.keycode in [KEY_SHIFT, KEY_X] and event.pressed:
			_on_dash()


func _back() -> void:
	if phase == Phase.LOADING:
		return
	if phase == Phase.MENU or phase == Phase.FINISHED or paused:
		return_to_app("games")
	else:
		pause()


func _notification(what: int) -> void:
	if not is_instance_valid(menus):
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_frame_stage):
		get_viewport().size_changed.disconnect(_frame_stage)
	save()
	get_tree().auto_accept_quit = _previous_auto_accept_quit
	get_tree().quit_on_go_back = _previous_quit_on_go_back
