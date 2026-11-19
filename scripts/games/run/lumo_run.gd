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
const PATH_WORLD = preload("res://scripts/games/run/jungle/run_jungle_path.gd")
const AUDIO = preload("res://scripts/games/run/run_audio.gd")
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
## Sections of the adventure path, said once when Lumo enters them.
const SECTION_SAYINGS: Array[String] = [
	"", "Wurzelpfad", "Kronenwege", "Tempelruinen", "Wasserfallhöhle", "Lorenfahrt!"
]

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
var audio
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
var _section: int = -1
var _combo: int = 0
var _combo_left: float = 0.0
var _slowmo_left: float = 0.0
var load_ms: int = 0
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
	lightweight = SettingsStore.get_profile() == "low" or PerformanceManager.software_rendered_mobile()
	result_id = HostBridge.new_result_id()
	_previous_auto_accept_quit = get_tree().auto_accept_quit
	_previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_build_screens()
	var wanted: int = COURSES.index_of(str(options.get("runCourse", "")))
	if wanted >= 0 and bool(options.get("runAutoStart", false)):
		SceneRouter.launch_options.erase("runAutoStart")
		_on_course_chosen(wanted, false)
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
	hud.skip_pressed.connect(skip_intro)
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
	# Finish dispatching the click before removing its focused Button.
	_begin_course_load.call_deferred(index, with_save)


func _begin_course_load(index: int, with_save: bool) -> void:
	if not is_inside_tree() or phase != Phase.LOADING:
		return
	var course: Dictionary = COURSES.course(index)
	menus.open("loading", {"name": course.name, "accent": course.accent})
	_release_stage()
	# queue_free runs at the end of the frame. Give the loading panel a frame
	# of its own before allocating the world and the second rigged fox.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and phase == Phase.LOADING:
		await start_course(index, with_save, true)


func _release_stage() -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
		stage = null


## Direct simulations can build synchronously. Interactive starts and restarts
## yield between expensive stages while the loading panel remains responsive.
func start_course(index: int, with_save: bool, spread_frames: bool = false) -> void:
	_release_stage()
	course_index = clampi(index, 0, COURSES.count() - 1)
	var course: Dictionary = COURSES.course(course_index)
	var load_started: int = Time.get_ticks_msec()
	world = PATH_WORLD.new() if bool(course.get("path", false)) else WORLD.new()
	world.name = "RunWorld"
	add_child(world)
	if bool(course.get("path", false)):
		await world.build(lightweight, str(course.track), spread_frames)
	else:
		await world.build(lightweight, str(course.track), false, spread_frames)
	if spread_frames:
		await get_tree().process_frame
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
	if plan.adventure:
		player.use_path_feel()
	player.place(plan.start_s, 0.0, 0.0)
	props.track = track
	props.player = player
	if props.jungle != null:
		props.jungle.track = track
	if spread_frames:
		await get_tree().process_frame
	actor = ACTOR.new()
	actor.name = "Lumo"
	add_child(actor)
	actor.setup(reduced_motion)
	actor.pace_scale = TUNING.PATH_TIME_SCALE if plan.adventure else 1.0
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
	if not is_instance_valid(audio):
		audio = AUDIO.new()
		audio.name = "RunAudio"
		add_child(audio)
	if spread_frames:
		await get_tree().process_frame
	audio.start_course(str(course.id), plan.adventure)
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
	hud.set_letters(plan.letters.map(func(letter: Dictionary) -> String: return str(letter.char)), track.letters)
	hud.set_skip_visible(plan.adventure and not restored and plan.intro_end > plan.start_s)
	_section = -1
	load_ms = Time.get_ticks_msec() - load_started
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
	print("[LumoRun] course %s: %.0f m, %d stars, %d checkpoints, built in %d ms" % [course.id, plan.length, plan.star_total, plan.checkpoints.size(), load_ms])


func _share(s: float) -> float:
	return clampf((s - plan.start_s) / maxf(1.0, plan.finish_s - plan.start_s), 0.0, 1.0)


# ------------------------------------------------------------------ the run

func _process(delta: float) -> void:
	if phase == Phase.MENU or phase == Phase.LOADING or not is_instance_valid(world):
		return
	var left: float = minf(delta, 0.1)
	if _slowmo_left > 0.0:
		_slowmo_left -= left
		left *= 0.45
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
			if not _reopen_question() and not plan.adventure:
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
	var previous_elapsed := elapsed
	elapsed += delta
	if previous_elapsed < 1.0 and elapsed >= 1.0:
		print("[LumoRun] running %s s=%.2f" % [COURSES.course(course_index).id, player.s])
	# The adventure path plays PATH_TIME_SCALE times faster than it was laid out
	# (see run_tuning.gd), in steps that are no longer than before.
	var pace: float = TUNING.PATH_TIME_SCALE if plan.adventure else 1.0
	var parts: int = maxi(1, ceili(pace - 0.001))
	for _part in range(parts):
		_simulate(delta * pace / float(parts))
		if phase != Phase.RUNNING or paused or question_open:
			break


## One step of the run in course time.
func _simulate(delta: float) -> void:
	run_clock += delta
	var steer := Vector2(
		Input.get_axis("ui_left", "ui_right") + touch_steer.x,
		Input.get_axis("ui_up", "ui_down") + touch_steer.y
	).limit_length(1.0)
	track.clock = run_clock
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
	_combo_left = maxf(0.0, _combo_left - delta)
	if _combo_left <= 0.0:
		_combo = 0
	if plan.adventure:
		_follow_sections()
		hud.set_coach(_coach_icon())
		if hud.skip_visible and player.s > plan.intro_end:
			hud.set_skip_visible(false)
	else:
		_hint_ahead()
	if is_instance_valid(audio):
		audio.update(delta, player, track)
	hud.set_state(track.kept, _share(player.s), solved_count(), track.checkpoint)
	hud.set_dash_cooldown(player.dash_cooldown / TUNING.DASH_COOLDOWN)


func _follow_sections() -> void:
	if player.s < 0.0:
		return
	var index: int = world.section_at(player.s)
	if index == _section:
		return
	_section = index
	if index > 0 and index < SECTION_SAYINGS.size():
		hud.banner(SECTION_SAYINGS[index], index)


func _coach_icon() -> String:
	for coach in plan.coaches:
		if player.s >= float(coach.s0) and player.s <= float(coach.s1):
			return str(coach.icon)
	return ""


## Leaves the introduction and puts Lumo where the adventure begins.
func skip_intro() -> void:
	if not plan.adventure or phase != Phase.RUNNING or paused or question_open or player.s >= plan.intro_end:
		return
	for index in range(plan.waits.size()):
		track.waits_done[index] = true
	player.place(plan.intro_end, 0.0, player.cruise * 0.6)
	track.rescue = plan.respawn_index(player.s)
	hud.set_skip_visible(false)
	_update_view(0.016, true)


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
	camera.chase_view = plan.adventure and track.chase_active
	camera.follow(world, player, feet.origin, maxf(delta, 0.0001), snap)
	if plan.adventure and is_instance_valid(world.scenery):
		world.scenery.follow(camera.global_position, player.s, maxf(delta, 0.0001), feet.origin)


func _on_player_event(event: StringName) -> void:
	var feet: Vector3 = feet_transform().origin
	match event:
		&"jump":
			_sound("jump", "card_next")
			if plan.adventure:
				fx.play("leaves", feet + Vector3.UP * 0.2)
		&"land":
			if player.land_impact > 6.0:
				fx.play("dust", feet + Vector3.UP * 0.15)
				_sound("land", "")
			if player.land_impact > 12.0:
				camera.kick(0.35)
		&"dash":
			fx.play("dust", feet + Vector3.UP * 0.3)
			_sound("dash", "ui_confirm")
		&"air_dash":
			fx.play("leaves", feet + Vector3.UP * 0.8)
			_sound("dash", "ui_confirm")
		&"shoot":
			_sound("barrel_shoot", "ui_confirm")
			fx.play("burst", feet + Vector3.UP * 0.9, Color("ffd27a"))
			camera.kick(0.3)
			if not reduced_motion:
				_slowmo_left = 0.18
		&"warp":
			_update_view(0.016, true)
		&"tumble":
			_sound("hit", "ui_cancel")
			fx.play("burst", feet + Vector3.UP * 0.9, Color("ffffff"))
			camera.kick(0.4)
		&"loop_start":
			hud.say("Looping!", 2.0)
			camera.follow(world, player, feet, 0.016, true)
		&"loop_end":
			fx.play("sparkle", feet + Vector3.UP * 1.0)
			camera.follow(world, player, feet, 0.016, true)


func _on_track_event(event: Dictionary) -> void:
	var feet: Vector3 = feet_transform().origin
	match str(event.type):
		"star":
			props.hide_star(int(event.index))
			fx.play("sparkle", props.star_position(int(event.index)))
			_combo = mini(_combo + 1, 7) if _combo_left > 0.0 else 0
			_combo_left = 0.9
			if is_instance_valid(audio) and audio.has_effects():
				audio.play_star(_combo)
			else:
				AudioManager.play_sfx("star_collected")
		"letter":
			props.take_letter(int(event.index))
			fx.play("burst", props.letter_position(int(event.index)), Color("9ff3ff"))
			_sound("letter", "celebrate")
			hud.set_letters(plan.letters.map(func(letter: Dictionary) -> String: return str(letter.char)), track.letters)
			hud.say("%s! %d von %d Kristallbuchstaben" % [str(event.char), track.letter_count(), plan.letters.size()], 2.2)
		"ride":
			props.grab_ride(int(event.index))
			match str(event.kind):
				"vine", "zip":
					_sound("vine", "card_next")
				_:
					_sound("barrel_in", "card_next")
		"stomp":
			props.squash_enemy(int(event.index))
			fx.play("burst", feet, Color("fff1b0"))
			_sound("stomp", "ui_confirm")
		"hit":
			if bool(event.leaves):
				props.squash_enemy(int(event.index))
			hud.say("Hoppla!", 1.2)
		"rescue":
			fx.play("sparkle", feet + Vector3.UP * 0.8)
			_sound("respawn", "ui_back")
			if bool(event.helped):
				hud.say("Lumo hilft dir weiter!", 2.2)
			props.sync_platforms()
			_update_view(0.016, true)
		"bonus":
			_sound("bonus", "celebrate")
			hud.say("Geheime Schatzhalle!", 2.6)
			if is_instance_valid(audio):
				audio.stinger("bonus")
		"chase_start":
			hud.say("Der Felsball rollt! Lauf!", 2.4)
			if is_instance_valid(audio):
				audio.set_chase(true)
			camera.kick(0.5)
		"chase_end":
			if is_instance_valid(audio):
				audio.set_chase(false)
			camera.kick(0.6)
			fx.play("dust", props.point(player.s - 6.0, 0.0, 0.5))
		"caught":
			if is_instance_valid(audio):
				audio.set_chase(false)
			hud.say("Der Fels bleibt stecken. Weiter!" if bool(event.stuck) else "Schnell weg! Noch einmal.", 2.2)
			_update_view(0.016, true)
		"cart_on":
			_sound("cart", "ui_confirm")
			hud.say("Festhalten! SPRINGEN über die Lücken.", 2.4)
		"demo":
			hud.say("", 0.0)
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
			_sound("checkpoint", "")
		"finish":
			_finish()


## Effect from the run's own sound set, or the shared fallback when there is none.
func _sound(name: String, fallback: String) -> void:
	if is_instance_valid(audio) and audio.has_effects():
		audio.effect(name)
	elif not fallback.is_empty():
		AudioManager.play_sfx(fallback)


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
			"dock": "bottom" if plan.adventure else "center",
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
	props.open_gate(question_checkpoint)
	if plan.adventure:
		# Lumo waits a moment while the puzzle gate opens in front of him.
		player.speed = 0.0
	_sound("gate", "")
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
	if is_instance_valid(audio):
		audio.set_paused(true)
	save()
	var summary: String = "%s · %d Sterne · %s" % [
		str(COURSES.course(course_index).name), track.kept, UI.clock(int(elapsed * 1000.0))
	]
	menus.open("pause", {"summary": summary})


func resume() -> void:
	if not paused:
		return
	paused = false
	if is_instance_valid(audio):
		audio.set_paused(false)
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
	track.rescue = plan.respawn_index(player.s)
	if plan.adventure and track.rescue >= 0:
		player.in_cart = bool(plan.respawns[track.rescue].get("cart", false))
		player.cart_lat = float(plan.cart.get("lat", 0.0))
	props.sync(track)
	for index in questions:
		props.open_gate(int(index))
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
	var best: Dictionary = SESSION.record(child_scope, str(course.id))
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
	if plan.adventure:
		result_payload["letters"] = track.letter_count()
		result_payload["bonusRoom"] = track.bonus_found
	var accepted: bool = HostBridge.reward(result_payload)
	if HostBridge.reward_is_recoverable(result_id):
		SESSION.erase(session_path)
	SESSION.store_record(child_scope, str(course.id), stars_rating, time_ms)
	if is_instance_valid(audio):
		audio.finish()
	_sound("finish", "celebrate")
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
		"letters": "",
		"thresholds": "★ Ziel · ★★ ab %d %% · ★★★ ab %d %% der Sterne" % [
			roundi(TUNING.RATING_TWO * 100.0), roundi(TUNING.RATING_THREE * 100.0)
		],
	}
	if plan.adventure:
		content.facts.insert(2, ["Buchstaben", "%d von %d" % [track.letter_count(), plan.letters.size()]])
		content.facts.insert(3, ["Schatzhalle", "gefunden" if track.bonus_found else "noch geheim"])
		var record_text: String = "neue Bestzeit!" if best.is_empty() or time_ms < int(best.time_ms) else UI.clock(int(best.time_ms))
		content.facts.append(["Bestzeit", record_text])
		var word: String = ""
		for index in range(plan.letters.size()):
			word += str(plan.letters[index].char) if track.letters & (1 << index) else "·"
		content["letters"] = word
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
