extends Node3D
## LUMO Abenteuer-Parcours (Kart-Modus): Weltwahl, Fahren mit dem gewählten Kart, kurze
## Fußabschnitte mit dem echten geriggten Lumo, Checkpoints mit freundlicher Rettung,
## Zeitlauf oder entspanntes Erkunden, Pause/Neustart/Zurück, Fortsetzen und genau ein
## Ergebnis je Lauf an den Host. Fahrzeug, Werkstatt-Faktoren, Lenkstick, Pedale,
## Kart-Musik und Belohnungsweg (HostBridge, ProgressStore) sind dieselben wie im Rennen.

const WORLDS = preload("res://scripts/games/parcours/parcours_worlds.gd")
const RUN = preload("res://scripts/games/parcours/parcours_run.gd")
const BUILDER = preload("res://scripts/games/parcours/parcours_builder.gd")
const PROGRESS = preload("res://scripts/games/parcours/parcours_progress.gd")
const HUD = preload("res://scripts/games/parcours/parcours_hud.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const VISUAL_GRADE = preload("res://scripts/games/kart_visual_grade.gd")
const KART_AUDIO = preload("res://scripts/games/kart_audio.gd")
const ACTOR = preload("res://scripts/games/run/run_actor.gd")
const PREFERENCES: String = "user://kart_preferences.cfg"
const START_COUNTDOWN: float = 2.4
const SAVE_EVERY: float = 4.0

var world_id: String = ""
var play_style: String = "zeitlauf"
var child_key: String = "standalone"
var progress
var run
var course
var builder: Node3D
var kart: LumoRaceKart
var lumo: Node3D
var camera: Camera3D
var hud
var kart_audio: Node
var workshop
var selected_kart: String = "comet"
var selected_driver: String = "fox"
var difficulty: String = "gemuetlich"
var reduced_motion: bool = false
var lightweight: bool = false
var auto_gas: bool = true
var muted: bool = false
var playing: bool = false
var paused: bool = false
var finished: bool = false
var countdown: float = 0.0
var result_id: String = ""
var result_payload: Dictionary = {}
var reward_sent: bool = false
var reward_accepted: bool = false
var rewards_booked: int = 0
var save_timer: float = 0.0
var steer: Vector2 = Vector2.ZERO
var gas_held: bool = false
var brake_held: float = 0.0
var camera_yaw: float = 0.0
var last_result: Dictionary = {}
var previous_scale := Vector2i(720, 1280)
var previous_size := Vector2i(720, 1280)
var previous_orientation: int = DisplayServer.SCREEN_PORTRAIT
var previous_auto_accept_quit: bool = true
var previous_quit_on_go_back: bool = true
## Für Tests: Bild-für-Bild-Ereignisse der letzten Sekunden.
var event_log: Array[Dictionary] = []


func _ready() -> void:
	set_physics_process(false)
	var options: Dictionary = SceneRouter.launch_options.duplicate(true)
	options.merge(HostBridge.launch_options(), true)
	child_key = str(options.get("childKey", "standalone"))
	selected_kart = str(options.get("kart", options.get("parcoursKart", "comet")))
	selected_driver = str(options.get("driver", "fox"))
	progress = PROGRESS.new(child_key)
	previous_auto_accept_quit = get_tree().auto_accept_quit
	previous_quit_on_go_back = get_tree().quit_on_go_back
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	previous_scale = get_window().content_scale_size
	previous_size = get_window().size
	previous_orientation = DisplayServer.screen_get_orientation()
	get_window().content_scale_size = Vector2i(1280, 720)
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_load_preferences(options)
	kart_audio = KART_AUDIO.new()
	kart_audio.name = "KartAudio"
	add_child(kart_audio)
	kart_audio.set_muted(muted or not bool(options.get("soundEnabled", true)))
	hud = HUD.new()
	hud.name = "ParcoursHud"
	hud.game = self
	add_child(hud)
	camera = Camera3D.new()
	camera.name = "ParcoursCamera"
	camera.fov = 70.0
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	var requested: String = str(options.get("parcoursWorld", ""))
	if requested in WORLDS.playable_ids():
		start_world(requested, str(options.get("parcoursStyle", "zeitlauf")))
	else:
		show_world_choice()
	set_physics_process(true)
	print("[Parcours] ready: %d spielbare Welten" % WORLDS.playable_ids().size())


func _load_preferences(options: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(PREFERENCES)
	reduced_motion = (
		bool(config.get_value("race", "reduced_motion", false))
		or bool(options.get("reduceAnimations", false))
	)
	muted = bool(config.get_value("race", "muted", false))
	var touch_device: bool = OS.has_feature("android") or OS.has_feature("ios")
	auto_gas = bool(config.get_value("race", "auto_gas", not touch_device))
	var profile: String = str(config.get_value("race", "graphics_profile", "high"))
	lightweight = profile == "low" or PerformanceManager.software_rendered_mobile()
	var level_key: String = (child_key if not child_key.is_empty() else "standalone").sha256_text()
	difficulty = str(config.get_value("levels", level_key, "gemuetlich"))
	if difficulty not in ["gemuetlich", "flott", "pro"]:
		difficulty = "gemuetlich"
	var music: float = clampf(float(config.get_value("race", "music_volume", 1.0)), 0.0, 1.0)
	var effects: float = clampf(float(config.get_value("race", "effects_volume", 1.0)), 0.0, 1.0)
	set_meta("volumes", Vector2(music, effects))


func _ensure_workshop():
	if workshop == null:
		workshop = TUNING.new(child_key, ProgressStore.lifetime_stars())
	return workshop


## Weltwahl: nur spielbare Welten, mit Bestzeit und Geheimwegen dieses Kindes.
func show_world_choice() -> void:
	playing = false
	paused = false
	finished = false
	_clear_world()
	if is_instance_valid(kart_audio):
		kart_audio.play_menu()
	hud.show_choice(WORLDS.ENTRIES, progress, play_style, not progress.load_session().is_empty())


func _clear_world() -> void:
	for node in [builder, kart, lumo]:
		if is_instance_valid(node):
			node.queue_free()
	builder = null
	kart = null
	lumo = null
	run = null
	course = null


func start_world(id: String, style: String, resume: Dictionary = {}) -> void:
	_clear_world()
	world_id = id if id in WORLDS.playable_ids() else WORLDS.playable_ids()[0]
	play_style = style if style in RUN.PLAY_STYLES else "zeitlauf"
	course = WORLDS.build(world_id)
	run = RUN.new()
	run.setup(course, play_style)
	run.drive.factors = _ensure_workshop().multipliers(selected_kart)
	run.drive.difficulty = difficulty
	result_id = HostBridge.new_result_id()
	if not resume.is_empty():
		run.restore(resume)
		result_id = str(resume.get("result_id", result_id))
	reward_sent = false
	reward_accepted = false
	result_payload = {}
	finished = false
	paused = false
	builder = BUILDER.new()
	add_child(builder)
	builder.build(course, lightweight, reduced_motion)
	kart = VEHICLE.new()
	kart.name = "PlayerKart"
	var driver: Dictionary = CATALOG.entry(CATALOG.DRIVERS, selected_driver)
	kart.set_look(_ensure_workshop().look(selected_kart))
	kart.configure(selected_driver, driver.color, selected_kart)
	kart.set_animated_lumo_enabled(true)
	kart.reduced_motion = reduced_motion
	kart.set_graphics_quality("low" if lightweight else "high")
	add_child(kart)
	lumo = ACTOR.new()
	lumo.name = "LumoOnFoot"
	add_child(lumo)
	lumo.setup(reduced_motion)
	lumo.visible = false
	_place_visuals(0.0)
	camera_yaw = run.drive.heading
	_update_camera(0.0, true)
	hud.show_play(course, play_style)
	countdown = START_COUNTDOWN if resume.is_empty() else 1.0
	playing = true
	kart_audio.play_track(str(course.theme.get("music", "bergwelt")))
	hud.say(
		"%s! %s" % [course.title, "Fahr los, wenn das Licht grün wird."]
		if resume.is_empty() else "Weiter geht's am letzten Checkpoint."
	)
	_save_session()
	print("[Parcours] start: world=%s style=%s kart=%s" % [world_id, play_style, selected_kart])


func _physics_process(delta: float) -> void:
	if not playing or run == null:
		return
	if paused or finished:
		_update_visuals(0.0)
		return
	if countdown > 0.0:
		var before: int = ceili(countdown)
		countdown = maxf(0.0, countdown - delta)
		if ceili(countdown) != before:
			kart_audio.effect("start" if countdown <= 0.0 else "countdown")
		hud.set_countdown(countdown)
		_update_visuals(0.0)
		return
	var axis: float = steer.x
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		axis += 1.0
	axis = clampf(axis, -1.0, 1.0)
	var braking: float = brake_held
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		braking = 1.0
	var manual_gas: bool = gas_held or Input.is_physical_key_pressed(KEY_W)
	step_game(delta, axis, braking, manual_gas, _foot_move())


## Ein Spielschritt mit fertigen Eingaben (auch von Tests und dem Bild-Bot genutzt).
func step_game(delta: float, axis: float, braking: float, manual_gas: bool, move: Vector2) -> void:
	run.step(delta, axis, braking, manual_gas, auto_gas, move)
	for e in run.events:
		_on_event(e)
	save_timer += delta
	if save_timer >= SAVE_EVERY:
		save_timer = 0.0
		_save_session()
	if run.finished and not finished:
		_finish()
	_update_visuals(delta)


func _foot_move() -> Vector2:
	if run == null or not run.on_foot:
		return Vector2.ZERO
	var stick: Vector2 = steer
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		stick.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		stick.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		stick.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		stick.y += 1.0
	return camera_relative(stick)


## Stick (x rechts, y nach unten) relativ zur Kamera in Weltrichtung (x, z).
func camera_relative(stick: Vector2) -> Vector2:
	if stick.length() < 0.12:
		return Vector2.ZERO
	var ahead := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var world: Vector3 = right * stick.x - ahead * stick.y
	return Vector2(world.x, world.z).limit_length(1.0)


func _on_event(e: Dictionary) -> void:
	event_log.append(e)
	if event_log.size() > 80:
		event_log.pop_front()
	match str(e.kind):
		"checkpoint":
			hud.say("Checkpoint! Hier fängt dich die Lumo-Wolke auf.")
			kart_audio.effect("gate_bell")
			_save_session()
		"star":
			kart_audio.effect("item", 1.2)
		"secret":
			hud.say(str(e.text))
			kart_audio.effect("confetti")
		"skill", "station", "leave", "near_lever", "lever", "enter":
			hud.say(str(e.text))
			if str(e.kind) == "lever":
				kart_audio.effect("switch_chime")
		"reset":
			hud.say(str(e.text))
			kart_audio.effect("whoosh")
			camera_yaw = run.drive.heading
			_update_camera(0.0, true)
		"land":
			kart_audio.effect("land_thump")
		"rail":
			kart_audio.effect("rail_hit_soft")
		"bump":
			kart_audio.effect("collision")
			hud.say("Hoppla! Weiter geht's.")
		"drift_turbo":
			kart_audio.effect("drift")
	hud.refresh_context()


func _update_visuals(delta: float) -> void:
	if run == null:
		return
	builder.advance(run.t, run.state, run)
	_place_visuals(delta)
	_update_camera(delta, false)
	hud.update_hud(run, play_style)
	var moving: bool = playing and not paused and not finished and countdown <= 0.0
	var ratio: float = clampf(absf(run.drive.speed) / 22.0, 0.0, 1.0)
	kart_audio.set_loop("engine_mid", (0.25 + ratio * 0.6) if moving and not run.on_foot else 0.0, 0.8 + ratio * 0.6)


func _place_visuals(delta: float) -> void:
	var drive = run.drive
	kart.transform = Transform3D(drive.basis, drive.position)
	var enabled: bool = playing and not paused and not finished and not run.on_foot
	kart.set_motion(drive.speed if enabled else 0.0, steer.x, drive.boost_time > 0.0 and enabled, drive.drifting and enabled)
	kart.set_braking(brake_held if enabled else 0.0)
	kart.set_driver_runtime_state(drive.airborne, drive.bump_time > 0.0, paused)
	if is_instance_valid(kart.driver):
		kart.driver.visible = not run.on_foot
	lumo.visible = run.on_foot
	if run.on_foot:
		var w = run.walker
		var ground_y: float = float(w.hit.get("height", w.position.y)) if not w.hit.is_empty() else w.position.y - 3.0
		var feet := Transform3D(Basis(Vector3.UP, w.heading), w.position)
		var ground := Transform3D(Basis.IDENTITY, Vector3(w.position.x, ground_y, w.position.z))
		lumo.apply(feet, ground, w, maxf(delta, 0.0001), paused)


func _update_camera(delta: float, snap: bool) -> void:
	if run == null or not is_instance_valid(camera):
		return
	var follow: Vector3
	var heading: float
	var distance: float
	var height: float
	if run.on_foot:
		follow = run.walker.position
		heading = run.walker.heading
		distance = 6.2
		height = 3.1
		if steer.length() < 0.15 or snap:
			camera_yaw = lerp_angle(camera_yaw, heading, 1.0 if snap else minf(1.0, delta * 1.2))
	else:
		follow = run.drive.position
		heading = run.drive.heading
		var ratio: float = clampf(absf(run.drive.speed) / 25.0, 0.0, 1.0)
		distance = VISUAL_GRADE.camera_distance(ratio) * 1.35
		height = VISUAL_GRADE.CAMERA_HEIGHT * 1.25
		camera_yaw = lerp_angle(camera_yaw, heading, 1.0 if snap else minf(1.0, delta * 5.0))
	var ahead := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var desired: Vector3 = follow - ahead * distance + Vector3.UP * height
	var target: Vector3 = follow + ahead * (VISUAL_GRADE.CAMERA_LOOK_AHEAD + 1.5) + Vector3.UP * VISUAL_GRADE.CAMERA_TARGET_HEIGHT
	camera.position = desired if snap else camera.position.lerp(desired, minf(1.0, delta * VISUAL_GRADE.CAMERA_LERP))
	if camera.position.distance_to(target) > 0.1:
		camera.look_at(target)


# --- Bedienung (vom HUD aufgerufen) ---------------------------------------------------

func press_drift() -> void:
	if run != null and not run.on_foot:
		run.drive.press_drift()


func release_drift() -> void:
	if run != null and not run.on_foot and run.drive.release_drift() >= 0:
		kart_audio.effect("drift")
		hud.say("Drift-Turbo!")


func use_boost() -> void:
	if run != null and not run.on_foot and countdown <= 0.0 and run.drive.use_boost():
		kart_audio.effect("boost")
		hud.say("Lumo-Boost!")


## Kontexttaste: Aussteigen, Hebel, Einsteigen – je nachdem, was gerade geht.
func context_action() -> void:
	if run == null or paused or finished or countdown > 0.0:
		return
	if run.can_leave_kart():
		run.leave_kart()
	elif run.on_foot and run.use_lever():
		pass
	elif run.can_enter_kart():
		run.enter_kart()
		camera_yaw = run.drive.heading
	for e in run.events:
		_on_event(e)
	run.events.clear()
	hud.refresh_context()


func context_label() -> String:
	if run == null:
		return ""
	if run.can_leave_kart():
		return "AUSSTEIGEN"
	if run.on_foot:
		var s: Dictionary = course.stations[run.station]
		if not run.station_done.has(run.station):
			return "HEBEL" if run.walker.position.distance_to(s.lever as Vector3) <= 2.4 else ""
		if run.can_enter_kart():
			return "EINSTEIGEN"
	return ""


func jump_pressed(down: bool) -> void:
	if run == null or not run.on_foot:
		return
	if down:
		run.walker.press_jump()
	else:
		run.walker.release_jump()


func manual_reset() -> void:
	if run == null or paused or finished or countdown > 0.0:
		return
	if run.on_foot:
		return
	run.reset_to_checkpoint(false)
	for e in run.events:
		_on_event(e)
	run.events.clear()


func pause_game() -> void:
	if not playing or finished or paused:
		return
	paused = true
	kart_audio.set_paused(true)
	_save_session()
	hud.show_pause()


func resume_game() -> void:
	if not paused:
		return
	paused = false
	kart_audio.set_paused(false)
	hud.hide_modal()


func restart_world() -> void:
	progress.clear_session()
	start_world(world_id, play_style)


func continue_saved() -> void:
	var data: Dictionary = progress.load_session()
	if data.is_empty() or str(data.get("course", "")) not in WORLDS.playable_ids():
		show_world_choice()
		return
	start_world(str(data.course), str(data.get("style", "zeitlauf")), data)


func leave_to_choice() -> void:
	if playing and not finished:
		_save_session()
	kart_audio.set_paused(false)
	show_world_choice()


func leave_to_kart_menu() -> void:
	if playing and not finished:
		_save_session()
	SceneRouter.launch_options["kartEntryPrepared"] = true
	SceneRouter.goto("kart")


func _finish() -> void:
	if finished:
		return
	finished = true
	kart_audio.effect("finish")
	var earned: int = 3
	result_payload = {
		"game": "kart", "mode": "parcours", "world": world_id, "style": play_style,
		"sessionId": str(SceneRouter.launch_options.get("sessionId", "")),
		"resultId": result_id, "status": "completed", "stars": earned, "solved": 0,
		"elapsedSeconds": snappedf(run.elapsed, 0.001), "starTokens": run.stars_taken.size(),
		"starTotal": course.stars.size(), "secrets": _found_secret_ids(),
		"checkpoints": run.reached.size(), "resets": run.resets, "kart": selected_kart,
		"driver": selected_driver
	}
	_book_reward()
	last_result = progress.record(result_payload)
	progress.clear_session()
	if is_instance_valid(kart):
		kart.celebrate(1)
	hud.show_result(result_payload, progress.world(world_id), last_result, reward_accepted or not HostBridge.is_embedded())
	print("[Parcours] completed: world=%s style=%s seconds=%.1f stars=%d/%d" % [
		world_id, play_style, run.elapsed, run.stars_taken.size(), course.stars.size()
	])


## Belohnung genau einmal je Ergebnis-ID: Sterne gutschreiben und an den Host melden.
func _book_reward() -> void:
	if reward_sent:
		return
	reward_sent = true
	rewards_booked += 1
	ProgressStore.add_stars(int(result_payload.stars))
	reward_accepted = HostBridge.reward(result_payload)


## Speichern fehlgeschlagen: erneut melden (gleiche Ergebnis-ID, der Host bucht nur einmal).
func retry_reward() -> void:
	if finished and not result_payload.is_empty():
		reward_accepted = HostBridge.reward(result_payload)
		hud.show_result(result_payload, progress.world(world_id), last_result, reward_accepted or not HostBridge.is_embedded())


func _found_secret_ids() -> Array[String]:
	var ids: Array[String] = []
	for index in run.secrets_found:
		ids.append(str(course.secrets[int(index)].id))
	return ids


func _save_session() -> void:
	if run == null or finished or not playing:
		return
	var data: Dictionary = run.snapshot()
	data["result_id"] = result_id
	data["kart"] = selected_kart
	progress.save_session(data)


func return_to_app(destination: String) -> void:
	_save_session()
	if HostBridge.is_embedded():
		var payload: Dictionary = result_payload.duplicate(true) if finished else {
			"game": "kart", "status": "paused", "resultId": result_id, "stars": 0, "solved": 0
		}
		if finished:
			HostBridge.reward(result_payload)
		HostBridge.return_to_app(destination, payload)
		return
	SceneRouter.goto("learn" if destination == "learn" else "games")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if playing and not finished and not paused:
			pause_game()


## Android-Zurück: Fahrt -> Pause, Pause -> weiterfahren, Ergebnis/Weltwahl -> Kart-Menü.
func handle_back() -> void:
	if hud.close_overlay():
		return
	if playing and not finished:
		if paused:
			resume_game()
		else:
			pause_game()
		return
	if playing and finished:
		show_world_choice()
		return
	leave_to_kart_menu()


func _exit_tree() -> void:
	_save_session()
	get_tree().auto_accept_quit = previous_auto_accept_quit
	get_tree().quit_on_go_back = previous_quit_on_go_back
	get_window().content_scale_size = previous_scale
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(previous_orientation)
