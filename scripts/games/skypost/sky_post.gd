extends Node3D
## Lumos Sternenpost: Lumo flies his Sternsegler over Wolkenhafen as the post
## fox. Three modes: Lieferflug (letters and parcels to riddle addresses),
## Wolkenrennen (ring race against three friends) and Freiflug (secret star
## sparks and photo spots). The child steers with one thumb, SCHWUNG gives a
## burst of speed, ABWERFEN drops the letter on its star chute.
##
## This script only connects the parts and owns the rules of a flight:
##   sky_post_world.gd / sky_post_layout.gd   Wolkenhafen (models, shapes, shaders)
##   sky_post_flight.gd                        Lumo's glider motion (never crashes)
##   sky_post_glider.gd                        Sternsegler + real rigged Lumo / rivals
##   sky_post_delivery.gd / sky_post_race.gd   rules of the delivery and the race
##   sky_post_rivals.gd                        three rival pilots on the race line
##   sky_post_camera.gd / sky_post_fx.gd / sky_post_audio.gd   what is seen and heard
##   sky_post_hud.gd / sky_post_menus.gd       controls and screens
##   sky_post_session.gd                       saves, records, album and choices per child

signal moment(kind: String, detail: Dictionary)

enum Phase { LOADING, MENU, COUNTDOWN, FLYING, FINISHED }

const WORLD = preload("res://scripts/games/skypost/sky_post_world.gd")
const LAYOUT = preload("res://scripts/games/skypost/sky_post_layout.gd")
const GLIDER = preload("res://scripts/games/skypost/sky_post_glider.gd")
const FLIGHT = preload("res://scripts/games/skypost/sky_post_flight.gd")
const CAMERA = preload("res://scripts/games/skypost/sky_post_camera.gd")
const FX = preload("res://scripts/games/skypost/sky_post_fx.gd")
const HUD = preload("res://scripts/games/skypost/sky_post_hud.gd")
const MENUS = preload("res://scripts/games/skypost/sky_post_menus.gd")
const RIVALS = preload("res://scripts/games/skypost/sky_post_rivals.gd")
const RACE = preload("res://scripts/games/skypost/sky_post_race.gd")
const DELIVERY = preload("res://scripts/games/skypost/sky_post_delivery.gd")
const SESSION = preload("res://scripts/games/skypost/sky_post_session.gd")
const TUNING = preload("res://scripts/games/skypost/sky_post_tuning.gd")
const MODELS = preload("res://scripts/games/skypost/sky_post_models.gd")
const AUDIO = preload("res://scripts/games/skypost/sky_post_audio.gd")
const ADDRESSES = preload("res://scripts/games/skypost/sky_post_addresses.gd")
const UI = preload("res://scripts/games/run/run_ui.gd")

## Longest piece of world building per frame while the loading card shows (ms).
const BUILD_SLICE_MS: int = 30
const PHOTO_HALF := Vector2(3.8, 2.8)
const SECRET_TINT := Color("ff9fd2")

var phase: Phase = Phase.LOADING
var paused: bool = false
var abandoned: bool = false
var grade: int = 1
var subject: String = "Mathematik"
var child_scope: String = ""
var reduced_motion: bool = false
var profile: String = "medium"
var mode: String = "delivery"
var stage: String = "entdecken"
var colour: String = "sternblau"
var riddles: bool = true
var world
var layout
var glider
var flight
var camera
var fx
var hud
var menus
var audio
var rivals
var race
var delivery
var parcel_node: Node3D
var result_id: String = ""
var result_payload: Dictionary = {}
var reward_sent: bool = false
var reward_accepted: bool = false
var rewards_booked: int = 0
var session_path: String = ""
var elapsed: float = 0.0
var countdown_left: float = 0.0
var touch_steer := Vector2.ZERO
## Test/demo autopilot: Callable(game) -> Vector2 stick, replaces the child's input.
var autopilot: Callable
var sparks_taken: int = 0
var free_secrets: int = 0
var free_photos: int = 0
var album: Dictionary = {"secrets": 0, "photos": 0}
var load_ms: int = 0
var round_index: int = 0
var next_job_left: float = -1.0
var goal: Variant = null
var _build_started: int = 0
var _combo: int = 0
var _combo_left: float = 0.0
var _was_near: bool = false
var _count_shown: int = -1
var _photo_inverse: Array[Transform3D] = []
var _previous_auto_accept_quit: bool = true
var _previous_quit_on_go_back: bool = true


func _ready() -> void:
	var options: Dictionary = SceneRouter.launch_options
	grade = clampi(int(options.get("grade", 1)), 1, 4)
	subject = str(options.get("subject", "Mathematik"))
	if subject not in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]:
		subject = "Mathematik"
	var child_key: String = str(
		options.get("childKey", HostBridge.launch_options().get("childKey", ""))
	)
	if not child_key.is_empty() and child_key != "standalone":
		child_scope = child_key.sha256_text()
	profile = _choose_profile(options)
	result_id = HostBridge.new_result_id()
	var choices: Dictionary = SESSION.choices(child_scope)
	mode = str(options.get("skypostMode", choices.mode))
	stage = str(options.get("skypostStage", choices.stage))
	mode = mode if mode in TUNING.MODES else "delivery"
	stage = stage if stage in TUNING.STAGES else "entdecken"
	colour = str(choices.colour) if GLIDER.COLOURS.has(str(choices.colour)) else "sternblau"
	riddles = bool(choices.riddles)
	_previous_auto_accept_quit = get_tree().auto_accept_quit
	_previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_build_screens()
	audio = AUDIO.new()
	audio.name = "Audio"
	add_child(audio)
	# Erste Einführung je Kind: scripts/games/guides/sky_post_guide.gd
	load("res://scripts/games/guides/sky_post_guide.gd").attach(self)
	world = WORLD.new()
	world.name = "Wolkenhafen"
	add_child(world)
	_build_started = Time.get_ticks_msec()
	world.begin_build(profile, reduced_motion)
	layout = world.layout
	menus.open("loading", {"title": "Wolkenhafen", "text": "Lumo macht den Sternsegler startklar …"})
	print("[SkyPost] ready: grade=%d subject=%s profile=%s" % [grade, subject, profile])


## Graphics profile: launch option (tests), else the Lumo Kart garage choice,
## else the platform profile; software-rendered phones always get LOW.
func _choose_profile(options: Dictionary) -> String:
	var config := ConfigFile.new()
	var has_preferences: bool = config.load("user://kart_preferences.cfg") == OK
	reduced_motion = bool(options.get("reduceAnimations", false))
	if has_preferences:
		reduced_motion = reduced_motion or bool(config.get_value("race", "reduced_motion", false))
	var wanted: String = str(options.get("skypostProfile", ""))
	if wanted in ["low", "medium", "high"]:
		return wanted
	if PerformanceManager.software_rendered_mobile():
		return "low"
	if has_preferences:
		var chosen: String = str(config.get_value("race", "graphics_profile", ""))
		if chosen in ["low", "medium", "high"]:
			return chosen
	var by_platform: String = PerformanceManager.get_profile_name()
	return by_platform if by_platform in ["low", "medium", "high"] else "medium"


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
	hud.boost_pressed.connect(press_boost)
	hud.drop_pressed.connect(press_drop)
	menus.start_pressed.connect(start_flight)
	menus.mode_selected.connect(_choose.bind("mode"))
	menus.stage_selected.connect(_choose.bind("stage"))
	menus.colour_selected.connect(_choose.bind("colour"))
	menus.riddles_toggled.connect(func(value: bool) -> void: _choose(value, "riddles"))
	menus.resume_pressed.connect(resume)
	menus.restart_pressed.connect(restart)
	menus.menu_pressed.connect(to_menu)
	menus.again_pressed.connect(_on_again)
	menus.help_pressed.connect(func() -> void: menus.open("help"))
	menus.help_closed.connect(_close_help)
	menus.leave_pressed.connect(return_to_app)
	get_viewport().size_changed.connect(_frame_stage)
	hud.set_playing(false)


# ------------------------------------------------------------------ loading


func _process(delta: float) -> void:
	if phase == Phase.LOADING:
		var slice: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - slice < BUILD_SLICE_MS:
			if world.build_step():
				_after_build()
				return
		return
	advance(delta)


## Builds the whole world at once (tests); the scene itself spreads it over frames.
func build_now() -> void:
	if phase != Phase.LOADING:
		return
	while not world.build_step():
		pass
	_after_build()


func _after_build() -> void:
	load_ms = Time.get_ticks_msec() - _build_started
	glider = GLIDER.new()
	glider.name = "LumoGlider"
	add_child(glider)
	var paint: Dictionary = GLIDER.COLOURS[colour]
	glider.build("low" if profile == "low" else "hero", paint.paint, paint.trim, reduced_motion)
	if not glider.seat_pilot("lumo"):
		push_warning("[SkyPost] Lumo could not be seated")
	flight = FLIGHT.new()
	flight.setup(layout, stage)
	camera = CAMERA.new()
	camera.name = "Camera"
	camera.reduced_motion = reduced_motion
	add_child(camera)
	camera.current = true
	fx = FX.new()
	fx.name = "Fx"
	add_child(fx)
	fx.setup(profile, reduced_motion)
	parcel_node = MODELS.instance("post", "hero")
	parcel_node.name = "FallingPost"
	parcel_node.visible = false
	add_child(parcel_node)
	print(
		(
			"[SkyPost] world built: %d ms (build steps %d ms), profile %s"
			% [load_ms, world.build_ms, profile]
		)
	)
	show_start()


# ------------------------------------------------------------------ start menu


func _identity() -> Dictionary:
	if mode == "free":
		return {"child_scope": child_scope, "mode": mode}
	return {
		"child_scope": child_scope,
		"grade": grade,
		"subject": subject,
		"mode": mode,
		"stage": stage,
		"riddles": riddles,
	}


func _park() -> void:
	flight.setup(layout, stage)
	flight.place(layout.start_at + Vector3(0, 0, 4.0), layout.start_yaw, 0.0)
	glider.global_transform = flight.transform()
	glider.animate(0.0, Vector2.ZERO, 0.0, false)


func show_start() -> void:
	phase = Phase.MENU
	paused = false
	hud.set_playing(false)
	_clear_mode()
	_park()
	if is_instance_valid(audio):
		audio.set_paused(false)
		audio.start_music(false)
	menus.open("start", _start_data())
	_frame_stage()
	if not reduced_motion:
		glider.wave()


func _start_data() -> Dictionary:
	var saved: String = SESSION.peek(SESSION.path_for(child_scope, mode), _identity())
	var best: Dictionary = {}
	for id in TUNING.MODES:
		best[id] = _best_text(id)
	return {
		"mode": mode,
		"stage": stage,
		"colour": colour,
		"riddles": riddles,
		"grade": grade,
		"subject": subject,
		"save": saved if mode != "race" else "",
		"best": best,
	}


func _best_text(id: String) -> String:
	if id == "free":
		var found: Dictionary = SESSION.album(child_scope)
		var secrets: int = _bits(int(found.secrets))
		var photos: int = _bits(int(found.photos))
		if secrets + photos == 0:
			return ""
		return "%d/%d ★ · %d/%d Fotos" % [
			secrets, LAYOUT.SECRETS.size(), photos, LAYOUT.PHOTOS.size()
		]
	var record: Dictionary = SESSION.record(child_scope, id, stage)
	if record.is_empty():
		return ""
	var text: String = TUNING.MEDAL_NAMES[int(record.rating) - 1].replace("-Siegel", "")
	if id == "race" and int(record.place) > 0:
		text = "Platz %d · %s" % [int(record.place), text]
	return text + " · " + UI.clock(int(record.time_ms))


static func _bits(value: int) -> int:
	var count: int = 0
	while value > 0:
		count += value & 1
		value >>= 1
	return count


func _frame_stage() -> void:
	if phase != Phase.MENU or not is_instance_valid(menus) or menus.screen != "start":
		return
	_frame_now.call_deferred()


func _frame_now() -> void:
	if not is_inside_tree() or phase != Phase.MENU or not is_instance_valid(camera):
		return
	camera.frame_glider(glider, menus.hero_rect, get_viewport().get_visible_rect().size)


func _choose(value: Variant, key: String) -> void:
	if phase != Phase.MENU:
		return
	match key:
		"mode":
			mode = str(value) if str(value) in TUNING.MODES else mode
		"stage":
			stage = str(value) if str(value) in TUNING.STAGES else stage
		"colour":
			if GLIDER.COLOURS.has(str(value)):
				colour = str(value)
				var paint: Dictionary = GLIDER.COLOURS[colour]
				glider.set_colours(paint.paint, paint.trim)
		"riddles":
			riddles = bool(value)
	SESSION.store_choices(
		child_scope, {"mode": mode, "stage": stage, "colour": colour, "riddles": riddles}
	)
	menus.open("start", _start_data())
	_frame_stage()


func _close_help() -> void:
	if paused:
		_open_pause()
	elif phase == Phase.MENU:
		menus.open("start", _start_data())
		_frame_stage()
	else:
		menus.close()


# ------------------------------------------------------------------ starting a flight


func start_flight(resume_save: bool = false) -> void:
	if phase != Phase.MENU:
		return
	_clear_mode()
	paused = false
	abandoned = false
	reward_sent = false
	reward_accepted = false
	result_payload = {}
	result_id = HostBridge.new_result_id()
	elapsed = 0.0
	sparks_taken = 0
	_combo = 0
	_was_near = false
	next_job_left = -1.0
	session_path = SESSION.path_for(child_scope, mode)
	flight.setup(layout, stage)
	flight.place(layout.start_at + Vector3(0, 0, 4.0), layout.start_yaw, 0.0)
	menus.close()
	match mode:
		"race":
			_start_race()
		"free":
			_start_free(resume_save)
		_:
			_start_delivery(resume_save)
	hud.set_mode(mode)
	hud.set_playing(true)
	camera.follow(flight, 0.0, true)
	fx.clear_trails()
	audio.start_music(mode == "race")
	if mode == "race":
		phase = Phase.COUNTDOWN
		countdown_left = TUNING.START_COUNTDOWN
		_count_shown = -1
	else:
		phase = Phase.FLYING
		flight.begin_launch(flight.pos, layout.start_yaw)
	moment.emit("start", {"mode": mode, "stage": stage})
	print("[SkyPost] start: mode=%s stage=%s resume=%s" % [mode, stage, str(resume_save)])


func _clear_mode() -> void:
	if world != null:
		world.clear_mode_objects()
		world.reset_mailboxes()
	if is_instance_valid(rivals):
		remove_child(rivals)
		rivals.queue_free()
	rivals = null
	race = null
	delivery = null
	goal = null
	_photo_inverse.clear()
	if is_instance_valid(parcel_node):
		parcel_node.visible = false
	if is_instance_valid(glider) and glider.pilot != null and glider.pilot_kind == "lumo":
		glider.pilot.clear_attention_target()
		glider.pilot.clear_celebration()


func _delivery_sparks() -> PackedVector3Array:
	var route: Array = []
	for index in range(mini(int(TUNING.DELIVERIES.get(stage, 5)), LAYOUT.DISTRICTS.size())):
		route.append(index)
	return layout.delivery_sparks(route)


func _start_delivery(resume_save: bool) -> void:
	delivery = DELIVERY.new()
	var positions: PackedVector3Array = _delivery_sparks()
	var saved: Dictionary = {}
	if resume_save:
		saved = SESSION.load_delivery(session_path, _identity(), positions.size())
	if not saved.is_empty() and saved.jobs.size() == int(TUNING.DELIVERIES.get(stage, 5)):
		delivery.setup(layout, stage, saved.jobs, int(saved.done), saved.tries)
		result_id = str(saved.result_id)
		elapsed = float(saved.elapsed_ms) / 1000.0
	else:
		var tour: Array = DELIVERY.plan(layout, stage, grade, subject, riddles, randi())
		delivery.setup(layout, stage, tour, 0, null)
		saved = {}
	world.make_sparks(positions)
	if not saved.is_empty():
		var taken: PackedByteArray = saved.taken
		for index in range(taken.size()):
			if taken[index] == 1:
				world.take_spark(index)
				sparks_taken += 1
		for job in range(delivery.done):
			world.mailbox_delivered(_house_of(job))
	_show_job()


func _house_of(job: int) -> int:
	var district: int = int(delivery.jobs[job].district)
	var slot: int = int(delivery.jobs[job].riddle.answer)
	return world.house_index(district, slot)


func _show_job() -> void:
	for index in range(world.boards.size()):
		world.set_board(index, "", false)
	if delivery.finished():
		world.show_beacon(null)
		world.show_targets([], 0.0)
		return
	var job: Dictionary = delivery.current()
	var houses: Array[int] = delivery.district_houses()
	for slot in range(3):
		world.set_board(houses[slot], str(job.riddle.answers[slot]), false)
	world.show_beacon(delivery.centre())
	world.show_targets(houses, delivery.catch_radius())
	world.show_preview(null)
	flight.assist_target = delivery.centre()
	_was_near = false
	var item: String = str(job.item)
	var district_name: String = str(LAYOUT.DISTRICTS[delivery.district()].name)
	hud.set_card(
		item,
		str(job.recipient),
		str(job.riddle.prompt),
		district_name,
		"%d/%d" % [delivery.done + 1, delivery.jobs.size()]
	)
	hud.say("%s für %s – flieg zur %s!" % [item, job.recipient, district_name], 3.2)


func _start_race() -> void:
	round_index += 1
	var laps: int = int(TUNING.LAPS.get(stage, 2))
	rivals = RIVALS.new()
	rivals.name = "Rivals"
	add_child(rivals)
	rivals.setup(layout, stage, laps, reduced_motion, profile, round_index)
	race = RACE.new()
	race.setup(layout, stage, laps)
	world.make_gates()
	world.show_next_gate(0)
	world.make_sparks(layout.race_sparks())
	hud.set_info("Wolkenrennen · %d Runden" % laps, 0)


func _start_free(resume_save: bool) -> void:
	album = SESSION.album(child_scope)
	free_secrets = 0
	free_photos = 0
	var positions := PackedVector3Array(LAYOUT.SECRETS)
	world.make_sparks(positions, SECRET_TINT)
	if resume_save:
		var saved: Dictionary = SESSION.load_free(session_path, _identity(), positions.size())
		if not saved.is_empty():
			result_id = str(saved.result_id)
			elapsed = float(saved.elapsed_ms) / 1000.0
			free_secrets = int(saved.secrets)
			free_photos = int(saved.photos)
			var taken: PackedByteArray = saved.taken
			for index in range(taken.size()):
				if taken[index] == 1:
					world.take_spark(index)
					sparks_taken += 1
	var shown := PackedByteArray()
	shown.resize(LAYOUT.PHOTOS.size())
	for index in range(LAYOUT.PHOTOS.size()):
		shown[index] = 1 if ((int(album.photos) | free_photos) >> index) & 1 else 0
	world.make_photo_frames(shown)
	for frame in world.photo_frames:
		_photo_inverse.append(frame.global_transform.affine_inverse())
	_update_free_info()
	hud.say("Freiflug! Finde geheime Sterne und flieg durch die FOTO-Rahmen.", 3.5)


# ------------------------------------------------------------------ the running flight


## One simulation and presentation step (the scene calls it every frame; tests call it directly).
func advance(delta: float) -> void:
	if flight == null:
		return
	if phase in [Phase.COUNTDOWN, Phase.FLYING] and not paused:
		_simulate(delta)
	elif phase == Phase.FINISHED:
		flight.step(delta, Vector2(0.32, 0.06))
		if is_instance_valid(rivals):
			rivals.advance(delta, rivals.finish_distance() + 1.0, flight.pos)
	_present(delta)


func _stick() -> Vector2:
	if autopilot.is_valid():
		return autopilot.call(self)
	var keys := Vector2(
		Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up")
	)
	return (Vector2(touch_steer.x, -touch_steer.y) + keys).limit_length(1.0)


func _simulate(delta: float) -> void:
	if phase == Phase.COUNTDOWN:
		_countdown(delta)
		if is_instance_valid(rivals):
			rivals.advance(delta, 0.0, flight.pos)
		return
	elapsed += delta
	var before: Vector3 = flight.pos
	flight.step(delta, _stick())
	_flight_events()
	_collect_sparks(delta)
	match mode:
		"race":
			_race_step(delta, before)
		"free":
			_free_step(before)
		_:
			_delivery_step(delta)


func _countdown(delta: float) -> void:
	countdown_left -= delta
	var shown: int = ceili(countdown_left)
	if shown != _count_shown:
		_count_shown = shown
		if shown > 0:
			hud.show_countdown(str(shown))
			audio.effect("countdown")
	if countdown_left <= 0.0:
		hud.show_countdown("LOS!")
		audio.effect("go")
		get_tree().create_timer(0.8).timeout.connect(
			func() -> void:
				if is_instance_valid(hud) and hud.countdown.text == "LOS!":
					hud.show_countdown("")
		)
		phase = Phase.FLYING
		flight.begin_launch(flight.pos, layout.start_yaw)
		rivals.start()
		moment.emit("go", {})


func _flight_events() -> void:
	for event in flight.events:
		match str(event.type):
			"boost":
				audio.effect("boost")
				camera.kick(0.25)
			"liftoff":
				audio.effect("liftoff", 1.0, -4.0)
			"cushion":
				fx.play("puff", flight.pos + Vector3(0, -1.5, 0), Color("ffffff"))
				audio.effect("cushion")
				hud.say("Wolkenpolster! Die Wolken fangen dich auf.", 2.2)
			"bump":
				camera.kick(0.35)
			"wall":
				hud.say("Der Wind bringt dich zurück nach Wolkenhafen.", 2.2)
		moment.emit(str(event.type), event)
	flight.events.clear()


func _collect_sparks(delta: float) -> void:
	_combo_left = maxf(0.0, _combo_left - delta)
	if _combo_left <= 0.0:
		_combo = 0
	var positions: PackedVector3Array = world.spark_positions
	var reach: float = TUNING.SPARK_RADIUS * TUNING.SPARK_RADIUS
	for index in range(positions.size()):
		if world.spark_taken[index] == 1:
			continue
		if positions[index].distance_squared_to(flight.pos) > reach:
			continue
		world.take_spark(index)
		sparks_taken += 1
		audio.play_star(_combo)
		_combo = mini(_combo + 1, 7)
		_combo_left = 1.6
		fx.play("sparkle", positions[index], Color("ffe27a"))
		if mode == "free":
			free_secrets |= 1 << index
			var fresh: bool = not ((int(album.secrets) >> index) & 1)
			if fresh:
				audio.effect("secret", 1.0, -4.0)
				hud.banner("Geheimer Stern!", 1.4)
			_update_free_info()
		moment.emit("spark", {"index": index})


func _delivery_step(delta: float) -> void:
	if next_job_left >= 0.0:
		next_job_left -= delta
		if next_job_left < 0.0:
			if delivery.finished():
				_finish_delivery()
				return
			_show_job()
	if delivery.finished():
		hud.drop_button.set_enabled(false)
		goal = null
		return
	var near: bool = delivery.in_district(flight.pos)
	if near != _was_near:
		_was_near = near
		for slot in range(3):
			var house: int = delivery.house_of(slot)
			world.set_board(house, str(delivery.current().riddle.answers[slot]), near)
		if near:
			hud.say("Welches Haus ist es? Lies die Tafeln und tippe ABWERFEN.", 3.0)
			flight.assist_target = null
		else:
			flight.assist_target = delivery.centre()
	var landing: Variant = null
	if near and delivery.drop.is_empty():
		landing = delivery.predict(flight.pos, flight.velocity)
	var help: bool = stage == "entdecken" or delivery.tries[delivery.done] > 0
	world.show_preview(landing if help else null)
	hud.drop_button.set_enabled(delivery.can_drop(flight.pos))
	hud.drop_button.set_calling(landing != null and delivery.house_at(landing) >= 0)
	delivery.step(delta)
	_show_falling_post()
	for event in delivery.events:
		_delivery_event(event)
	delivery.events.clear()
	goal = null
	if delivery.finished():
		return
	if not near:
		goal = delivery.centre() + Vector3(0, 6, 0)
	elif delivery.tries[delivery.done] >= 2:
		# Help after two misses of the same letter: the arrow shows the house.
		goal = layout.houses[delivery.target_house()].mailbox + Vector3(0, 2, 0)


func _show_falling_post() -> void:
	if delivery.drop.is_empty():
		parcel_node.visible = false
		return
	parcel_node.visible = true
	var drop: Dictionary = delivery.drop
	var item: String = str(drop.item)
	var letter := MODELS.part(parcel_node, "Brief")
	var box := MODELS.part(parcel_node, "Paket")
	var chute := MODELS.part(parcel_node, "Schirm")
	if letter != null:
		letter.visible = item == "Brief"
	if box != null:
		box.visible = item == "Paket"
	var opened: float = clampf((float(drop.t) - TUNING.CHUTE_DELAY) / 0.35, 0.0, 1.0)
	if chute != null:
		chute.visible = opened > 0.0
		chute.scale = Vector3.ONE * maxf(0.05, opened) * (1.3 if item == "Paket" else 1.0)
	var vel: Vector3 = drop.vel
	var sway: float = sin(float(drop.t) * 3.1) * 0.18 * opened
	parcel_node.global_transform = Transform3D(
		Basis(Vector3.UP, flight.yaw) * Basis(Vector3.BACK, sway), drop.pos
	)
	if opened <= 0.0 and vel.length() > 0.5:
		parcel_node.rotate_object_local(Vector3.RIGHT, float(drop.t) * 7.0)


func _delivery_event(event: Dictionary) -> void:
	moment.emit(str(event.type), event)
	match str(event.type):
		"release":
			audio.effect("release")
			hud.drop_button.set_cooldown(1.0)
		"chute":
			audio.effect("chute", 1.0, -3.0)
		"delivered":
			var house: int = int(event.house)
			world.mailbox_delivered(house)
			var box: Vector3 = layout.houses[house].mailbox
			fx.play("delivery", box + Vector3(0, 1.4, 0))
			audio.effect("delivered")
			camera.kick(0.15)
			var job: Dictionary = delivery.jobs[int(event.job)]
			var solution: String = str(job.riddle.get("solution", ""))
			hud.banner("Zugestellt!" if bool(event.first) else "Geschafft!", 1.8)
			hud.say(
				"Danke, %s! %s" % [job.recipient, solution] if not solution.is_empty()
				else "Danke, %s!" % job.recipient,
				3.0
			)
			world.show_targets([], 0.0)
			world.show_preview(null)
			next_job_left = 1.6
			save()
		"wrong":
			fx.play("miss", event.at, Color("ffffff"))
			audio.effect("wrong")
			var hint: String = str(delivery.current().riddle.get("hint", ""))
			hud.say("Das ist das Haus mit „%s“. %s" % [_board_words(str(event.text)), hint], 4.0)
			world.show_targets(delivery.district_houses(), delivery.catch_radius())
		"miss":
			fx.play("miss", event.at, Color("ffffff"))
			audio.effect("miss")
			hud.say("Daneben! Der blaue Kreis zeigt, wo der Brief landet.", 3.0)
			world.show_targets(delivery.district_houses(), delivery.catch_radius())


## Board text as words: a clock board ("clock:2:30") reads "halb drei".
static func _board_words(text: String) -> String:
	if not text.begins_with("clock:"):
		return text
	var parts: PackedStringArray = text.split(":")
	var hour: int = int(parts[1])
	if int(parts[2]) == 30:
		return "halb " + ADDRESSES.HOUR_WORDS[hour + 1]
	return "%d Uhr" % hour


func _race_step(_delta: float, before: Vector3) -> void:
	race.step(before, flight.pos, rivals.clock)
	rivals.advance(_delta, race.distance(flight.pos, rivals), flight.pos)
	for event in race.events:
		moment.emit("gate", event)
		var gate: int = int(event.gate)
		fx.play("ring", event.at, Color("7fe8ff") if gate != 0 else Color("ffd75e"))
		audio.effect("ring", 1.0 + (0.12 if bool(event.hit) else 0.0))
		if bool(event.hit):
			flight.ring_boost()
		if bool(event.finish):
			_finish_race()
			return
		if bool(event.start):
			hud.banner("Los geht's!", 1.2)
		elif bool(event.lap_done):
			var last: bool = race.lap() == race.laps
			hud.banner("Letzte Runde!" if last else "Runde %d!" % race.lap(), 1.8)
		world.show_next_gate(race.next_gate(), gate)
	race.events.clear()
	goal = race.gate_position(race.next_gate())
	var place: int = race.place(flight.pos, rivals)
	var ring: int = race.ring_in_lap()
	var text: String = (
		"Zum Start-Ring!"
		if ring == 0
		else "Runde %d/%d · Ring %d/%d" % [race.lap(), race.laps, ring, race.count]
	)
	hud.set_info(text, place)


func _free_step(before: Vector3) -> void:
	for index in range(_photo_inverse.size()):
		if (free_photos >> index) & 1:
			continue
		var a: Vector3 = _photo_inverse[index] * before
		var b: Vector3 = _photo_inverse[index] * flight.pos
		if signf(a.z) == signf(b.z) or a.z == b.z:
			continue
		var t: float = a.z / (a.z - b.z)
		var cross: Vector3 = a.lerp(b, t)
		if absf(cross.x) > PHOTO_HALF.x or absf(cross.y) > PHOTO_HALF.y:
			continue
		free_photos |= 1 << index
		world.mark_photo(index)
		var spot: Dictionary = LAYOUT.PHOTOS[index]
		fx.play("ring", spot.at, Color("ff9fd2"))
		audio.effect("photo")
		hud.banner("Foto: %s" % spot.name, 2.2)
		camera.kick(0.1)
		moment.emit("photo", {"index": index})
		_update_free_info()
	goal = _nearest_free_goal()


func _nearest_free_goal() -> Variant:
	var best: Variant = null
	var best_d: float = INF
	var known: int = int(album.photos) | free_photos
	for index in range(LAYOUT.PHOTOS.size()):
		if (known >> index) & 1:
			continue
		var at: Vector3 = LAYOUT.PHOTOS[index].at
		var d: float = at.distance_to(flight.pos)
		if d < best_d:
			best_d = d
			best = at
	return best


func _update_free_info() -> void:
	var secrets: int = _bits(int(album.secrets) | free_secrets)
	var photos: int = _bits(int(album.photos) | free_photos)
	hud.set_info(
		(
			"Geheime Sterne %d/%d · Fotos %d/%d"
			% [secrets, LAYOUT.SECRETS.size(), photos, LAYOUT.PHOTOS.size()]
		),
		0
	)


# ------------------------------------------------------------------ presentation


func _present(delta: float) -> void:
	var boosting: bool = flight.boost_time > 0.0
	glider.global_transform = flight.transform()
	var stick: Vector2 = flight.input if phase == Phase.FLYING else Vector2.ZERO
	glider.animate(delta, stick, flight.speed, boosting, false)
	if phase == Phase.FINISHED:
		camera.show_glider(glider, -1.0, 8.5, 2.6)
	elif phase != Phase.MENU:
		camera.follow(flight, delta)
	if is_instance_valid(camera):
		world.advance(delta, camera.global_position)
	if phase in [Phase.COUNTDOWN, Phase.FLYING, Phase.FINISHED]:
		fx.follow(delta, flight, glider.wing_tips(), camera, boosting, flight.cruise)
		audio.update(delta, flight.speed, flight.cruise)
	if phase in [Phase.COUNTDOWN, Phase.FLYING] and not paused:
		_update_hud()


func _update_hud() -> void:
	var total: int = world.spark_positions.size()
	hud.set_stats(sparks_taken, total, int(elapsed * 1000.0))
	hud.boost_button.set_cooldown(flight.boost_cooldown / TUNING.BOOST_COOLDOWN)
	if mode != "delivery":
		hud.drop_button.set_enabled(false)
	var pilot = glider.pilot
	if goal == null:
		hud.set_goal(Vector2.ZERO, false, 0.0, false)
		if pilot != null and glider.pilot_kind == "lumo":
			pilot.clear_attention_target()
		return
	var target: Vector3 = goal
	var view: Vector2 = get_viewport().get_visible_rect().size
	var behind: bool = camera.is_position_behind(target)
	var screen: Vector2 = camera.unproject_position(target)
	if behind:
		screen = view - screen
		screen = view * 0.5 + (screen - view * 0.5).normalized() * view.length()
	var inside: bool = (
		not behind and Rect2(view * 0.08, view * 0.84).has_point(screen)
	)
	hud.set_goal(screen, inside, target.distance_to(flight.pos), true)
	if pilot != null and glider.pilot_kind == "lumo":
		pilot.set_attention_target(target)


# ------------------------------------------------------------------ controls


func press_boost() -> void:
	if phase == Phase.FLYING and not paused:
		flight.press_boost()


func press_drop() -> void:
	if phase != Phase.FLYING or paused or mode != "delivery" or delivery == null:
		return
	if delivery.release(flight.pos, flight.velocity):
		moment.emit("drop", {"at": flight.pos})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_back()
			KEY_SPACE, KEY_SHIFT:
				press_boost()
			KEY_E, KEY_ENTER, KEY_X:
				press_drop()


func _back() -> void:
	if phase == Phase.LOADING:
		return
	if phase == Phase.MENU or phase == Phase.FINISHED or paused:
		if paused:
			resume()
		else:
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


# ------------------------------------------------------------------ pause, save, resume


func pause() -> void:
	if paused or phase not in [Phase.COUNTDOWN, Phase.FLYING]:
		return
	paused = true
	touch_steer = Vector2.ZERO
	hud.release_controls()
	hud.set_playing(false)
	audio.set_paused(true)
	glider.set_suspended(true)
	if is_instance_valid(rivals):
		rivals.set_suspended(true)
	save()
	_open_pause()


func _open_pause() -> void:
	var summary: String = "%s · %s · %s" % [
		TUNING.MODE_NAMES[mode], TUNING.STAGE_NAMES[stage], UI.clock(int(elapsed * 1000.0))
	]
	if mode == "delivery" and delivery != null:
		summary += "\n%d von %d zugestellt" % [delivery.done, delivery.jobs.size()]
	var note: String = ""
	if mode != "race":
		note = "Dein Flug ist gespeichert. Du kannst später weiterfliegen."
	menus.open("pause", {"summary": summary, "save_note": note, "free": mode == "free"})


func resume() -> void:
	if not paused:
		return
	paused = false
	audio.set_paused(false)
	glider.set_suspended(false)
	if is_instance_valid(rivals):
		rivals.set_suspended(false)
	menus.close()
	hud.set_playing(true)


func save() -> void:
	if abandoned or session_path.is_empty() or phase not in [Phase.COUNTDOWN, Phase.FLYING]:
		return
	var state: Dictionary = {
		"result_id": result_id,
		"elapsed_ms": int(elapsed * 1000.0),
		"taken": world.spark_taken,
	}
	if mode == "delivery" and delivery != null and not delivery.finished():
		state.merge(delivery.state())
	elif mode == "free":
		state["secrets"] = free_secrets
		state["photos"] = free_photos
	else:
		return
	if not SESSION.save(session_path, _identity(), state):
		push_warning("[SkyPost] flight could not be saved")


func restart() -> void:
	if phase == Phase.MENU or phase == Phase.LOADING:
		return
	# "Neu starten": the saved flight is given up on purpose.
	if not session_path.is_empty() and phase != Phase.FINISHED:
		SESSION.erase(session_path)
	_leave_flight()
	start_flight(false)


func to_menu() -> void:
	if phase in [Phase.COUNTDOWN, Phase.FLYING]:
		save()
	_leave_flight()
	show_start()


func _leave_flight() -> void:
	paused = false
	audio.set_paused(false)
	glider.set_suspended(false)
	hud.set_playing(false)
	hud.show_countdown("")
	fx.clear_trails()
	phase = Phase.MENU


func _on_again() -> void:
	if paused and mode == "free":
		resume()
		finish_free()
	elif phase == Phase.FINISHED:
		_leave_flight()
		start_flight(false)


# ------------------------------------------------------------------ results


func _finish_delivery() -> void:
	var first: int = delivery.first_try_count()
	var total_sparks: int = world.spark_positions.size()
	var rating: int = TUNING.delivery_rating(first, delivery.jobs.size(), sparks_taken, total_sparks)
	var reward: int = TUNING.delivery_reward(first, rating)
	var time_ms: int = int(elapsed * 1000.0)
	var payload: Dictionary = _payload(reward, first, rating, time_ms)
	payload["deliveries"] = delivery.jobs.size()
	payload["firstTry"] = first
	payload["riddles"] = riddles
	var facts: Array = [
		["Zugestellt", "%d von %d" % [delivery.done, delivery.jobs.size()]],
		["Beim 1. Versuch", "%d" % first],
		["Sternfunken", "%d von %d" % [sparks_taken, total_sparks]],
		["Zeit", UI.clock(time_ms)],
		["Belohnung", "+%d Sterne" % reward],
	]
	var stored: bool = SESSION.store_record(child_scope, "delivery", stage, rating, time_ms)
	_finish(
		payload,
		{
			"title": "Alle Briefe zugestellt!",
			"rating": rating,
			"facts": facts,
			"note": "Neuer Bestwert!" if stored else "",
		}
	)


func _finish_race() -> void:
	var place: int = race.place(flight.pos, rivals)
	var rating: int = TUNING.race_rating(race.hits, race.total())
	var reward: int = TUNING.race_reward(place, rating)
	var time_ms: int = int(race.finish_time * 1000.0)
	var payload: Dictionary = _payload(reward, 0, rating, time_ms)
	payload["place"] = place
	payload["rings"] = race.hits
	var facts: Array = [
		["Platz", "%d von 4" % place],
		["Mitten durch", "%d von %d Ringen" % [race.hits, race.total()]],
		["Sternfunken", "%d" % sparks_taken],
		["Zeit", UI.clock(time_ms)],
		["Belohnung", "+%d Sterne" % reward],
	]
	var stored: bool = SESSION.store_record(child_scope, "race", stage, rating, time_ms, place)
	var titles: Array[String] = ["Sieg im Wolkenrennen!", "Platz 2!", "Platz 3!", "Im Ziel!"]
	_finish(
		payload,
		{
			"title": titles[clampi(place, 1, 4) - 1],
			"rating": rating,
			"facts": facts,
			"note": "Neuer Bestwert!" if stored else "",
		}
	)


## Ends the free flight (from the pause menu). Stars only for what is new.
func finish_free() -> void:
	if phase != Phase.FLYING or mode != "free":
		return
	var new_secrets: int = _bits(free_secrets & ~int(album.secrets))
	var new_photos: int = _bits(free_photos & ~int(album.photos))
	var long_enough: bool = elapsed >= TUNING.FREE_MIN_SECONDS
	var reward: int = 0
	if long_enough or new_secrets + new_photos > 0:
		reward = TUNING.free_reward(new_secrets, new_photos, sparks_taken)
	SESSION.store_album(child_scope, free_secrets, free_photos)
	album = SESSION.album(child_scope)
	var rating: int = TUNING.free_rating(
		_bits(int(album.secrets)),
		LAYOUT.SECRETS.size(),
		_bits(int(album.photos)),
		LAYOUT.PHOTOS.size()
	)
	var time_ms: int = int(elapsed * 1000.0)
	var payload: Dictionary = _payload(reward, 0, rating, time_ms)
	payload["newSecrets"] = new_secrets
	payload["newPhotos"] = new_photos
	var facts: Array = [
		["Neue geheime Sterne", "%d" % new_secrets],
		["Neue Fotos", "%d" % new_photos],
		["Album", "%d/%d ★ · %d/%d Fotos" % [
			_bits(int(album.secrets)), LAYOUT.SECRETS.size(),
			_bits(int(album.photos)), LAYOUT.PHOTOS.size()
		]],
		["Flugzeit", UI.clock(time_ms)],
		["Belohnung", "+%d Sterne" % reward],
	]
	SESSION.store_record(child_scope, "free", stage, rating, maxi(1, time_ms))
	var note: String = ""
	if reward == 0:
		note = "Flieg mindestens %d Sekunden oder finde etwas Neues – dann gibt es Sterne." % int(
			TUNING.FREE_MIN_SECONDS
		)
	_finish(payload, {"title": "Freiflug beendet", "rating": rating, "facts": facts, "note": note})


func _payload(reward: int, solved: int, rating: int, time_ms: int) -> Dictionary:
	return {
		"game": "skypost",
		"sessionId": str(SceneRouter.launch_options.get("sessionId", "")),
		"resultId": result_id,
		"status": "completed",
		"stars": reward,
		"solved": solved,
		"grade": grade,
		"subject": subject,
		"mode": mode,
		"stage": stage,
		"rating": rating,
		"collected": sparks_taken,
		"timeMs": time_ms,
	}


func _finish(payload: Dictionary, content: Dictionary) -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	goal = null
	touch_steer = Vector2.ZERO
	hud.release_controls()
	hud.set_playing(false)
	hud.show_countdown("")
	world.show_beacon(null)
	world.show_preview(null)
	result_payload = payload
	_book_reward()
	if HostBridge.reward_is_recoverable(result_id):
		SESSION.erase(session_path)
	audio.finish()
	audio.effect("finish")
	audio.effect("confetti", 1.0, -6.0)
	fx.play("confetti", flight.pos + Vector3(0, 2.5, 0))
	glider.celebrate()
	var rating: int = int(content.rating)
	content["medal"] = TUNING.MEDAL_NAMES[rating - 1]
	content["medal_colour"] = TUNING.MEDAL_COLOURS[rating - 1]
	if HostBridge.is_embedded() and not reward_accepted:
		content["notice"] = HostBridge.SAVE_FAILURE
	menus.open("result", content)
	moment.emit("finish", payload)
	print(
		(
			"[SkyPost] finished: mode=%s stage=%s reward=%d rating=%d time=%s"
			% [mode, stage, int(payload.stars), rating, UI.clock(int(payload.timeMs))]
		)
	)


## Books the stars of this result exactly once (also when the result is shown again).
func _book_reward() -> void:
	if reward_sent or result_payload.is_empty():
		return
	reward_sent = true
	rewards_booked += 1
	ProgressStore.add_stars(int(result_payload.stars))
	reward_accepted = HostBridge.reward(result_payload)


## Leaves to the app. A finished flight reports its reward (once, by result id);
## a paused or unfinished flight reports no stars.
func return_to_app(destination: String) -> void:
	save()
	var payload: Dictionary = result_payload
	if phase == Phase.FINISHED:
		reward_accepted = HostBridge.reward(result_payload)
		if HostBridge.reward_is_recoverable(result_id):
			SESSION.erase(session_path)
	else:
		payload = {
			"game": "skypost",
			"resultId": result_id,
			"status": "paused",
			"stars": 0,
			"solved": 0,
			"grade": grade,
			"subject": subject,
		}
	abandoned = true
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app(destination, payload):
			abandoned = false
			if menus.screen in ["pause", "result"]:
				var content: Dictionary = menus.data.duplicate(true)
				content["notice"] = HostBridge.SAVE_FAILURE
				menus.open(menus.screen, content)
		return
	SceneRouter.goto("learn" if destination == "learn" else "games")


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_frame_stage):
		get_viewport().size_changed.disconnect(_frame_stage)
	save()
	get_tree().auto_accept_quit = _previous_auto_accept_quit
	get_tree().quit_on_go_back = _previous_quit_on_go_back
