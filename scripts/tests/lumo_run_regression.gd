extends SceneTree
# Native Java API method names intentionally match the actual plugin contract.
# gdlint: disable=function-name
## Regression of Lumo Lauf against the real scene (headless).
## Touch input goes through Godot's real event dispatch; long stretches are
## stepped with the game's own `advance()` so the test does not depend on how
## fast this machine renders.
##
##   godot --headless --script scripts/tests/lumo_run_regression.gd

const BOT = preload("res://scripts/tests/helpers/lumo_run_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const PLAN = preload("res://scripts/games/run/run_course_plan.gd")
const SESSION = preload("res://scripts/games/run/run_session.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const ROUTES = preload("res://scripts/games/game_hub_routes.gd")
const STEP: float = 1.0 / 60.0
const CHILD: String = "lumo-run-regression"


class FakeHost:
	extends Node
	var rewards: Array[Dictionary] = []
	var returns: Array[Dictionary] = []
	var accept_rewards: bool = true

	func getLaunchOptions() -> String:
		return JSON.stringify(
			{"game": "run", "grade": 2, "subject": "Deutsch", "sessionId": "run-test", "childKey": CHILD}
		)

	func reward(payload: String) -> bool:
		if not accept_rewards:
			return false
		rewards.append(JSON.parse_string(payload))
		return true

	func returnToApp(destination: String, payload: String) -> bool:
		returns.append({"destination": destination, "payload": JSON.parse_string(payload)})
		return true


var checks: int = 0
var failures: Array[String] = []
var scene: PackedScene
var bridge: Node
var router: Node
var fake: FakeHost


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[LumoRun] FAILED CHECK: " + label)


func _options(extra: Dictionary = {}) -> Dictionary:
	var options: Dictionary = {"grade": 2, "subject": "Deutsch", "childKey": CHILD, "sessionId": "run-test"}
	options.merge(extra, true)
	return options


func _new_game(extra: Dictionary = {}):
	router.launch_options = _options(extra)
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	return game


func _free_game(game, keep_save: bool = false) -> void:
	if not keep_save:
		game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


## Opens a course without the menu and skips the countdown.
func _open(index: int, with_save: bool = false, extra: Dictionary = {}):
	var game = await _new_game(extra)
	game.set_process(false)
	game.start_course(index, with_save)
	game.countdown_left = 0.0
	game.advance(STEP)
	return game


func _steps(game, count: int, bot = null) -> void:
	for _i in range(count):
		if bot != null and not game.question_open:
			bot.drive(game, STEP)
		game.advance(STEP)


func _until(game, done: Callable, bot = null, limit: int = 60 * 900) -> bool:
	for _i in range(limit):
		if done.call():
			return true
		if bot != null and not game.question_open:
			bot.drive(game, STEP)
		game.advance(STEP)
	return done.call()


## Runs to the finish, answering learning stops; `bot` may be null (no input).
func _complete(game, bot, sampler: Callable = Callable()) -> int:
	var steps: int = 0
	while game.phase != game.Phase.FINISHED and steps < 60 * 900:
		if game.question_open:
			game.answer(str(game.active_question.answer))
		elif bot != null:
			bot.drive(game, STEP)
		game.advance(STEP)
		steps += 1
		if sampler.is_valid() and steps % 20 == 0:
			sampler.call()
	return steps


func _window_point(point: Vector2) -> Vector2:
	return point * Vector2(root.size) / root.get_visible_rect().size


func _touch(point: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = _window_point(point)
	event.index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _drag(point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = _window_point(point)
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


## A real tap on a button (touch is delivered as a click, like on the device).
func _tap(control: Control) -> void:
	# Let containers finish their layout before aiming at the button.
	for _i in range(4):
		await process_frame
	if not is_instance_valid(control):
		_check(false, "button to tap exists")
		return
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = _window_point(point)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _button(game, path: String) -> Button:
	return game.menus.get_node_or_null(path) as Button


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found: Node = _find(child, wanted)
		if found != null:
			return found
	return null


func _clean() -> void:
	var scope: String = CHILD.sha256_text()
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		for subject in ["Deutsch", "Mathematik"]:
			SESSION.erase(SESSION.path_for(scope, 2, subject, id))
	var records := ConfigFile.new()
	if records.load(SESSION.RECORDS) == OK and records.has_section(SESSION._record_section(scope)):
		records.erase_section(SESSION._record_section(scope))
		records.save(SESSION.RECORDS)


func _run() -> void:
	scene = load("res://scenes/games/lumo_run.tscn")
	bridge = root.get_node("HostBridge")
	router = root.get_node("SceneRouter")
	_clean()
	_test_registration()
	await _test_start_screen_and_controls()
	await _test_obstacles_and_gaps()
	await _test_learning_and_save()
	await _test_corrupt_saves()
	await _test_host_contract()
	await _test_all_courses()
	await _test_layouts_and_calm_mode()
	bridge._host = null
	bridge._options = {}
	bridge._return_pending = false
	_clean()
	if failures.is_empty():
		print("[LumoRun] PASS: %d checks" % checks)
		quit(0)
	else:
		print("[LumoRun] FAIL: %d of %d checks failed: %s" % [failures.size(), checks, " | ".join(failures)])
		quit(1)


# ------------------------------------------------------------------ registration

func _test_registration() -> void:
	_check(router.SCENES.get("run", "") == "res://scenes/games/lumo_run.tscn", "router knows the scene id run")
	_check(bridge.validated_options({"game": "run"}).scene == "run", "host launch option game=run is accepted")
	_check(bridge.validated_options({"game": "unknown"}).scene == "kart", "unknown host games keep their fallback")
	var boot: Script = load("res://scripts/app/app_boot.gd")
	_check(boot.TITLE_BY_SCENE.get("run", "") == "LUMO LAUF", "boot screen titles the game LUMO LAUF")
	var listed: bool = false
	for entry in ROUTES.ENTRIES:
		listed = listed or str(entry.destination) == "run"
	_check(listed, "in-engine game hub lists Lumo Lauf")
	_check(not ROUTES.launch_options_for("run", {}, 3, "Deutsch").is_empty(), "hub builds launch options for run")
	_check(COURSES.count() >= 3, "at least three courses")
	var tracks: Array[String] = []
	for index in range(COURSES.count()):
		tracks.append(str(COURSES.course(index).track))
		_check(str(COURSES.course(index).description).length() > 20, "course %d has a description" % index)
	_check(
		tracks.has("jungle_emerald_3600") and tracks.has("zauberwald") and tracks.has("sonnenhafen"),
		"Dschungelherz, Zauberwald and Sonnenhafen are selectable"
	)
	_check(TUNING.rating(0, 100) == 1 and TUNING.rating(50, 100) == 2 and TUNING.rating(79, 100) == 2, "rating thresholds low")
	_check(TUNING.rating(80, 100) == 3 and TUNING.rating(130, 100) == 3, "rating thresholds high")
	_check(TUNING.reward(0, 1) == 3 and TUNING.reward(3, 3) == 15, "reward range 3..15")


# ------------------------------------------------------------------ menu, start, steering, jump

func _test_start_screen_and_controls() -> void:
	root.size = Vector2i(720, 1600)
	var game = await _new_game()
	_check(game.phase == game.Phase.MENU and game.menus.screen == "start", "scene opens on the course selection")
	_check(is_instance_valid(game.stage), "start screen has its live backdrop")
	for index in range(3):
		var card: Node = game.menus.get_node_or_null("Course%d" % index)
		_check(card != null, "course card %d exists" % index)
		if card != null:
			var start: Button = _find(card, "Start") as Button
			_check(start != null and start.text == "Los!", "course card %d offers Los!" % index)
			_check(
				start != null and start.size.y >= 48.0 * game.menus._unit - 0.5,
				"course card %d start button is at least 48 dp high" % index
			)
			_check(_find(card, "Resume") == null, "course card %d offers no resume without a save" % index)
	# Choose Zauberwald with a real tap on its button.
	var chosen: Button = _find(game.menus.get_node("Course1"), "Start") as Button
	await _tap(chosen)
	_check(game.phase in [game.Phase.LOADING, game.Phase.COUNTDOWN], "tap on Los! starts loading")
	for _i in range(8):
		await process_frame
	_check(game.phase == game.Phase.COUNTDOWN and game.course_index == 1, "course is built after loading")
	_check(str(game.world.track_id) == "zauberwald", "Zauberwald runs through the zauberwald world")
	_check(not is_instance_valid(game.stage), "menu backdrop is released when the course starts")
	_check(game.actor.uses_original, "the original rigged Lumo is used")
	_check(game.camera.current, "chase camera is active")
	game.set_process(false)
	var start_s: float = game.player.s
	_steps(game, 30)
	_check(game.phase == game.Phase.COUNTDOWN and is_equal_approx(game.player.s, start_s), "Lumo waits during the countdown")
	_check(game.hud.countdown.visible, "countdown is shown")
	game.countdown_left = 0.0
	_steps(game, 1)
	_check(game.phase == game.Phase.RUNNING and not game.hud.countdown.visible, "run starts after the countdown")
	_steps(game, 120)
	_check(game.player.s > start_s + 12.0, "Lumo runs forward on his own")
	_check(game.player.speed > TUNING.START_SPEED + 4.0, "Lumo builds up speed")
	_steps(game, 240)
	_check(absf(game.player.speed - TUNING.CRUISE) < 3.5, "speed settles near cruise on level ground")
	# Controls on screen.
	var hud = game.hud
	var view: Rect2 = root.get_visible_rect()
	var dp: float = hud._unit
	var rects: Dictionary = {
		"stick": hud.stick.get_global_rect(),
		"jump": hud.jump_button.get_global_rect(),
		"dash": hud.dash_button.get_global_rect(),
		"pause": hud.pause_button.get_global_rect(),
	}
	for key in rects:
		var rect: Rect2 = rects[key]
		_check(view.encloses(rect), "%s control is completely on screen" % key)
		_check(minf(rect.size.x, rect.size.y) >= 48.0 * dp - 0.5, "%s control is at least 48 dp" % key)
	_check(not rects.stick.intersects(rects.jump) and not rects.stick.intersects(rects.dash), "stick and action buttons do not overlap")
	_check(not rects.jump.intersects(rects.dash), "jump and dash do not overlap")
	_check(rects.jump.size.x > rects.dash.size.x, "jump is the bigger button")
	_check(rects.stick.get_center().x < view.size.x * 0.5 and rects.jump.get_center().x > view.size.x * 0.5, "stick left, jump right")
	# Steering with a real finger on the stick.
	game.player.place(game.plan.start_s + 20.0, 0.0, TUNING.CRUISE)
	var centre: Vector2 = rects.stick.get_center()
	await _touch(centre, 3, true)
	await _drag(centre + Vector2(rects.stick.size.x * 0.4, 0), 3)
	_check(game.touch_steer.x > 0.8, "dragging the stick right steers right")
	_steps(game, 20)
	_check(game.player.lat > 1.0, "steering moves Lumo to the right")
	_steps(game, 150)
	var wall: float = float(game.world.wall_lateral_at(game.player.s))
	_check(game.player.lat > wall - 0.6 and game.player.lat <= wall + 0.26, "Lumo can reach the road edge but not leave the road")
	var road: Dictionary = game.world.sample_road(game.feet_transform().origin, game.player.s)
	_check(absf(float(road.lateral)) <= float(road.width) * 0.5 + 0.3, "Lumo's world position stays on the road")
	await _drag(centre - Vector2(rects.stick.size.x * 0.4, 0), 3)
	_steps(game, 150)
	_check(game.player.lat < -wall + 0.6 and game.player.lat >= -wall - 0.26, "steering works across the whole road width")
	await _drag(centre + Vector2(rects.stick.size.x * 0.12, 0), 3)
	var analogue: float = game.touch_steer.x
	_check(analogue > 0.1 and analogue < 0.8, "steering is analogue, not three lanes")
	await _touch(centre, 3, false)
	_check(game.touch_steer == Vector2.ZERO, "releasing the stick stops steering")
	# Jump with a real finger: tap = small, hold = high.
	game.player.place(game.plan.start_s + 6.0, 0.0, TUNING.CRUISE)
	_steps(game, 2)
	var jump_at: Vector2 = rects.jump.get_center()
	await _touch(jump_at, 4, true)
	_steps(game, 1)
	_check(not game.player.grounded and game.player.vy > 0.0, "touching SPRINGEN makes Lumo jump at once")
	await _touch(jump_at, 4, false)
	var tap_peak: float = 0.0
	for _i in range(120):
		_steps(game, 1)
		tap_peak = maxf(tap_peak, game.player.h)
		if game.player.grounded:
			break
	_check(game.player.grounded, "Lumo lands again after a tap jump")
	await _touch(jump_at, 4, true)
	var hold_peak: float = 0.0
	var air_steps: int = 0
	for _i in range(160):
		_steps(game, 1)
		hold_peak = maxf(hold_peak, game.player.h)
		air_steps += 1
		if game.player.grounded and air_steps > 3:
			break
	await _touch(jump_at, 4, false)
	_check(tap_peak > 0.8 and tap_peak < 1.6, "tap jump is low but clears a hurdle (%.2f m)" % tap_peak)
	_check(hold_peak > tap_peak + 0.8, "holding jumps higher (%.2f m vs %.2f m)" % [hold_peak, tap_peak])
	_check(float(air_steps) * STEP * TUNING.CRUISE > 8.0, "a held jump carries far")
	# Jump buffering: pressed shortly before landing, Lumo jumps again on touchdown.
	game.player.press_jump()
	game.player.release_jump()
	_until(game, func() -> bool: return not game.player.grounded, null, 10)
	_until(game, func() -> bool: return game.player.vy < 0.0 and game.player.h < 0.45, null, 200)
	game.player.press_jump()
	var rejumped: bool = false
	for _i in range(12):
		_steps(game, 1)
		rejumped = rejumped or (game.player.vy > 5.0 and game.player.h < 1.0)
	_check(rejumped, "a jump pressed just before landing is buffered")
	game.player.release_jump()
	_until(game, func() -> bool: return game.player.grounded, null, 200)
	# Coyote time: running off a high path, a late press still jumps.
	if not game.plan.platforms.is_empty():
		var platform: Dictionary = game.plan.platforms[0]
		_teleport(game, float(platform.s1) - 1.0, float(platform.lat))
		game.player.h = float(platform.top)
		game.player.invulnerable = 5.0
		_until(game, func() -> bool: return not game.player.grounded, null, 30)
		_check(not game.player.grounded and game.player.h > float(platform.top) - 0.3, "Lumo runs off the end of a high path")
		_steps(game, 3)
		game.player.press_jump()
		_steps(game, 1)
		_check(game.player.jumping and game.player.vy > 5.0, "coyote time allows a jump just after the edge")
		game.player.release_jump()
	# Dash with a real finger, and its cooldown.
	_until(game, func() -> bool: return game.player.grounded, null, 300)
	game.player.dash_cooldown = 0.0
	var before_dash: float = game.player.speed
	await _touch(rects.dash.get_center(), 5, true)
	await _touch(rects.dash.get_center(), 5, false)
	_steps(game, 6)
	_check(game.player.dash_time > 0.0 and game.player.speed > before_dash + 1.0, "FLITZEN gives a burst of speed")
	_check(not game.player.press_dash(), "dash has a cooldown")
	_steps(game, int((TUNING.DASH_COOLDOWN + 0.1) / STEP))
	_check(game.player.dash_cooldown <= 0.0 and game.player.press_dash(), "dash is ready again after its cooldown")
	# Momentum from the terrain.
	_check(_target_speed(game, 0.08) < _target_speed(game, 0.0) and _target_speed(game, -0.08) > _target_speed(game, 0.0), "uphill is slower, downhill faster")
	# Pause button and back key.
	await _tap(hud.pause_button)
	_check(game.paused and game.menus.screen == "pause", "pause button opens the pause menu")
	var frozen: float = game.player.s
	_steps(game, 30)
	_check(is_equal_approx(game.player.s, frozen), "nothing moves while paused")
	_check(not hud.stick.visible and not hud.jump_button.enabled, "controls are off while paused")
	for wanted in ["Resume", "Restart", "Courses", "LeaveGames", "LeaveLearn"]:
		_check(_find(game.menus, wanted) != null, "pause menu has the button " + wanted)
	await _tap(_find(game.menus, "Resume") as Button)
	_check(not game.paused and game.menus.screen == "" and hud.stick.visible, "Weiterlaufen resumes the run")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.paused, "the run pauses when the app goes to the background")
	game.resume()
	await _free_game(game)


func _target_speed(game, grade: float) -> float:
	return TUNING.CRUISE * clampf(1.0 - grade * TUNING.GRADE_GAIN, TUNING.GRADE_MIN, TUNING.GRADE_MAX)


# ------------------------------------------------------------------ hurdles, gaps, pickups

func _test_obstacles_and_gaps() -> void:
	var game = await _open(2)
	var plan = game.plan
	var track = game.track
	var player = game.player
	_check(str(game.world.track_id) == "sonnenhafen", "Sonnenhafen runs through the sonnenhafen world")
	# Content is deterministic.
	var again = PLAN.build(game.world, COURSES.course(2))
	_check(again.signature == plan.signature and again.star_s == plan.star_s, "the same course always gets the same content")
	_check(again.star_lat == plan.star_lat and again.hurdles.size() == plan.hurdles.size(), "content positions are reproducible")
	var kinds: Dictionary = {}
	for beat in plan.beats:
		kinds[str(beat.kind)] = true
	_check(kinds.size() >= 7, "a course mixes many different challenges (%d kinds)" % kinds.size())
	_check(plan.star_s.size() > 200 and plan.hurdles.size() >= 4 and plan.channels.size() >= 3, "stars, hurdles and gaps are placed")
	_check(not plan.bounces.is_empty() and not plan.boosts.is_empty(), "bounce pads and boost strips are placed")
	_check(plan.checkpoints.size() >= 4 and plan.question_checkpoints().size() == 3, "checkpoints with exactly three learning stops")
	var spacing_ok: bool = true
	for index in range(1, plan.checkpoints.size()):
		var gap: float = float(plan.checkpoints[index].s) - float(plan.checkpoints[index - 1].s)
		spacing_ok = spacing_ok and gap > 150.0 and gap < 600.0
	_check(spacing_ok, "checkpoints come every few hundred metres")
	# Pickups count once.
	var star: int = 0
	_teleport(game, plan.star_s[star] - 6.0, plan.star_lat[star], TUNING.CRUISE)
	_until(game, func() -> bool: return player.s > plan.star_s[star] + 2.0)
	var value: int = plan.star_value[star]
	_check(track.taken[star] == 1 and track.kept >= value, "running through a star collects it")
	var held: int = track.kept
	var gathered: int = track.gathered
	_teleport(game, plan.star_s[star] - 6.0, plan.star_lat[star], TUNING.CRUISE)
	_until(game, func() -> bool: return player.s > plan.star_s[star] + 1.0)
	_check(track.gathered == gathered and track.kept == held, "a collected star does not count again")
	_check(not track.take_star(star), "a star can be taken exactly once")
	_check(track.kept >= held, "passing the same spot again never removes stars")
	# Hurdle: jumping clears it.
	var hurdle: Dictionary = plan.hurdles[0]
	var bot = BOT.new()
	_teleport(game, float(hurdle.s) - 14.0, float(hurdle.lat), TUNING.CRUISE)
	player.invulnerable = 0.0
	var stumbles: int = track.stumbles
	_until(game, func() -> bool: return player.s > float(hurdle.s) + 3.0, bot)
	_check(track.stumbles == stumbles and bot.jumps >= 1, "a jump clears a hurdle")
	# Hurdle: bumping it only costs a little speed.
	_idle(game)
	_teleport(game, float(hurdle.s) - 8.0, float(hurdle.lat), TUNING.CRUISE)
	player.invulnerable = 0.0
	var stars_before: int = track.kept
	_until(game, func() -> bool: return player.s > float(hurdle.s) + 0.5)
	_check(track.stumbles == stumbles + 1, "running into a hurdle is a stumble")
	_check(player.speed < TUNING.CRUISE * 0.75 and player.speed >= TUNING.MIN_SPEED - 0.01, "a stumble costs a little speed")
	_check(stars_before - track.kept >= 0 and stars_before - track.kept <= TUNING.STUMBLE_STAR_LOSS, "a stumble costs at most a few stars")
	_check(game.phase == game.Phase.RUNNING, "a stumble never ends the run")
	var after_bump: float = player.s
	_steps(game, 150)
	_check(player.s > after_bump + 15.0 and player.speed > TUNING.CRUISE * 0.8, "Lumo recovers and runs on")
	# Water channel: jumping clears it.
	var channel_index: int = -1
	for index in range(plan.channels.size()):
		if not bool(plan.channels[index].real):
			channel_index = index
			break
	_check(channel_index >= 0, "course has a jumpable water channel")
	var channel: Dictionary = plan.channels[channel_index]
	bot = BOT.new()
	_teleport(game, float(channel.s0) - 14.0, 0.0, TUNING.CRUISE)
	player.invulnerable = 0.0
	_until(game, func() -> bool: return player.s > float(channel.s1) + 2.0, bot)
	_check(not track.misses.has(channel_index) and bot.jumps >= 1, "a jump clears a gap")
	# Water channel: missing it sets Lumo back safely, never ends the run.
	_idle(game)
	_teleport(game, float(channel.s0) - 10.0, 0.0, TUNING.CRUISE)
	_until(game, func() -> bool: return int(track.misses.get(channel_index, 0)) >= 1)
	_check(int(track.misses.get(channel_index, 0)) == 1, "running into a gap counts as a miss")
	_check(player.s < float(channel.s0) - 5.0 and player.grounded and player.h == 0.0, "after a miss Lumo stands on the road before the gap")
	_check(game.phase == game.Phase.RUNNING and player.invulnerable > 0.0, "a miss never ends the run")
	_until(game, func() -> bool: return int(track.misses.get(channel_index, 0)) >= 2)
	_check(player.s < float(channel.s0), "second miss: one more try")
	_until(game, func() -> bool: return int(track.misses.get(channel_index, 0)) >= 3)
	_check(player.s >= float(channel.s1), "third miss: Lumo is carried across, nobody gets stuck")
	# The real opening in the Sonnenhafen road.
	var real_index: int = -1
	for index in range(plan.channels.size()):
		if bool(plan.channels[index].real):
			real_index = index
	_check(real_index >= 0, "Sonnenhafen keeps its real gap in the road")
	if real_index >= 0:
		var real_gap: Dictionary = plan.channels[real_index]
		_check(game.world.in_gap((float(real_gap.s0) + float(real_gap.s1)) * 0.5), "the gap is a real hole of the kart world")
		track.misses.clear()
		_teleport(game, float(real_gap.respawn), 0.0, TUNING.CRUISE)
		var highest: float = 0.0
		for _i in range(600):
			_steps(game, 1)
			highest = maxf(highest, player.h)
			if player.s > float(real_gap.s1) + 3.0 and player.grounded:
				break
		_check(not track.misses.has(real_index) and player.s > float(real_gap.s1), "boost strip and launch band carry Lumo over the big gap")
		_check(highest > 5.0, "the big jump is a big jump (%.1f m)" % highest)
		# Falling in (launch band skipped) is caught like any other gap.
		_teleport(game, float(real_gap.s0) + 1.0, 0.0, TUNING.MIN_SPEED)
		player.h = 3.0
		player.grounded = false
		player.vy = 0.0
		_until(game, func() -> bool: return track.misses.has(real_index), null, 600)
		_check(int(track.misses.get(real_index, 0)) == 1, "falling into the real gap is caught")
		_check(player.grounded and player.s < float(real_gap.s0) - 10.0 and game.phase == game.Phase.RUNNING, "Lumo is set back before the big jump")
	# Bounce pad and boost strip.
	var pad: Dictionary = {}
	for candidate in plan.bounces:
		if not bool(candidate.get("band", false)):
			pad = candidate
			break
	if not pad.is_empty():
		_teleport(game, float(pad.s) - 4.0, float(pad.lat), TUNING.CRUISE)
		var top: float = 0.0
		for _i in range(200):
			_steps(game, 1)
			top = maxf(top, player.h)
			if player.s > float(pad.s) + 3.0 and player.grounded:
				break
		_check(top > 3.0, "a bounce pad throws Lumo high (%.1f m)" % top)
	var strip: Dictionary = plan.boosts[0]
	_teleport(game, float(strip.s0) - 3.0, float(strip.lat), TUNING.CRUISE)
	player.boost_time = 0.0
	_until(game, func() -> bool: return player.s > float(strip.s1) + 4.0)
	_check(player.speed > TUNING.CRUISE + 3.0, "a boost strip makes Lumo faster")
	# Rocks are solid from the side and only stumble Lumo head-on.
	var rock: Dictionary = {}
	for blocker in plan.blockers:
		if str(blocker.kind) == "rock":
			rock = blocker
			break
	if not rock.is_empty():
		stumbles = track.stumbles
		_teleport(game, float(rock.s) - 6.0, float(rock.lat), TUNING.CRUISE)
		player.invulnerable = 0.0
		_until(game, func() -> bool: return player.s > float(rock.s) + 2.0)
		_check(track.stumbles == stumbles + 1, "running into a rock is a stumble")
		_check(absf(player.lat - float(rock.lat)) >= float(rock.radius), "Lumo slides past the rock, not through it")
	# Crates break on a dash and give their stars once.
	var crate: int = -1
	for index in range(plan.blockers.size()):
		if str(plan.blockers[index].kind) == "crate":
			crate = index
			break
	if crate >= 0:
		var box: Dictionary = plan.blockers[crate]
		_teleport(game, float(box.s) - 4.0, float(box.lat), TUNING.CRUISE)
		player.invulnerable = 0.0
		player.dash_cooldown = 0.0
		var kept: int = track.kept
		_check(player.press_dash(), "dash is available in front of a crate")
		_until(game, func() -> bool: return player.s > float(box.s) + 2.0)
		_check(track.broken.has(crate) and track.kept >= kept + TUNING.CRATE_STARS, "dashing breaks a crate for bonus stars")
		kept = track.kept
		_teleport(game, float(box.s) - 4.0, float(box.lat), TUNING.CRUISE)
		_until(game, func() -> bool: return player.s > float(box.s) + 2.0)
		_check(track.kept == kept, "a broken crate gives nothing the second time")
	# The stunt loop.
	if not plan.loop.is_empty():
		_teleport(game, float(plan.loop.start) - 12.0, float(plan.loop.lane), TUNING.CRUISE)
		_until(game, func() -> bool: return player.loop_u >= 0.0, null, 200)
		_check(player.loop_u >= 0.0, "arriving in the loop lane starts the loop")
		var loop_top: float = -INF
		var base: float = game.feet_transform().origin.y
		for _i in range(600):
			_steps(game, 1)
			loop_top = maxf(loop_top, game.feet_transform().origin.y - base)
			if player.loop_u < 0.0:
				break
		_check(loop_top > 10.0, "Lumo runs up and over the loop (%.1f m)" % loop_top)
		_check(player.loop_u < 0.0 and player.grounded and player.s >= float(plan.loop.exit_s), "Lumo leaves the loop on the road")
		_teleport(game, float(plan.loop.start) - 30.0, 1.0, TUNING.CRUISE)
		_until(game, func() -> bool: return player.s > float(plan.loop.start) + 12.0, null, 400)
		_check(player.loop_u < 0.0 and player.lat < 0.0, "Lumo is guided past the loop when he is not in its lane")
	await _free_game(game)


## Puts Lumo somewhere on the course for a focused check. Checkpoints that lie
## behind the new place are treated as passed, so no learning stop opens.
func _teleport(game, s: float, lat: float, speed: float = TUNING.CRUISE) -> void:
	var passed: int = -1
	for checkpoint in game.plan.checkpoints:
		if float(checkpoint.s) < s:
			passed = int(checkpoint.index)
	game.track.checkpoint = maxi(game.track.checkpoint, passed)
	game.player.place(s, lat, speed)
	game.player.invulnerable = 0.0
	_idle(game)


## Hands off the controls (after a stretch driven by the scripted player).
func _idle(game) -> void:
	game.touch_steer = Vector2.ZERO
	game.player.release_jump()
	game.player.jump_buffer = 0.0


# ------------------------------------------------------------------ learning stops, save and resume

func _test_learning_and_save() -> void:
	var game = await _open(1)
	var plan = game.plan
	var track = game.track
	var player = game.player
	var bot = BOT.new()
	var path: String = game.session_path
	_check(not FileAccess.file_exists(path), "no save file before the first checkpoint")
	game.save()
	_check(not FileAccess.file_exists(path), "nothing is saved before the first checkpoint")
	_until(game, func() -> bool: return track.checkpoint >= 0, bot)
	_check(track.checkpoint == 0 and FileAccess.file_exists(path), "reaching a checkpoint saves the run")
	_check(not game.snapshot.is_empty() and int(game.snapshot.checkpoint) == 0, "the snapshot holds the checkpoint")
	var saved_kept: int = int(game.snapshot.kept)
	_check(saved_kept == track.kept and saved_kept > 20, "the snapshot holds the collected stars")
	# First learning stop.
	var stops: Array[int] = plan.question_checkpoints()
	_until(game, func() -> bool: return game.question_open, bot)
	_check(game.question_open and track.checkpoint == stops[0], "the learning stop opens at its checkpoint")
	_check(game.menus.screen == "question" and not game.hud.stick.visible, "question screen replaces the controls")
	var question: Dictionary = game.active_question
	_check(question.options.has(question.answer) and question.options.size() >= 3, "question comes from the shared question bank")
	_check(str(game.menus.data.header).contains("2. Klasse") and str(game.menus.data.header).contains("Deutsch"), "grade and subject of the launch are used")
	var clock: float = game.elapsed
	var where: float = player.s
	_steps(game, 120)
	_check(is_equal_approx(game.elapsed, clock) and is_equal_approx(player.s, where), "no time pressure: the clock stands still at a learning stop")
	for _i in range(4):
		await process_frame
	var answers: Node = _find(game.menus, "Answers")
	_check(answers != null and answers.get_child_count() == question.options.size(), "every option has its own button")
	var big: bool = true
	for button in answers.get_children():
		big = big and button.size.y >= 56.0 * game.menus._unit - 0.5
	_check(big, "answer buttons are big")
	# Wrong answer: hint, one more try, no penalty.
	var kept: int = track.kept
	var wrong_button: Button
	var right_button: Button
	for button in answers.get_children():
		if button.text == str(question.answer):
			right_button = button
		elif wrong_button == null:
			wrong_button = button
	await _tap(wrong_button)
	_check(game.question_open and game.wrong_answers.size() == 1, "a wrong answer keeps the question open")
	_check(track.kept == kept and track.stumbles == int(game.snapshot.stumbles), "a wrong answer is never punished")
	var hint: Label = _find(game.menus, "Hint") as Label
	_check(hint != null and hint.text.begins_with("Fast!"), "a wrong answer gets a friendly hint")
	answers = _find(game.menus, "Answers")
	for button in answers.get_children():
		if button.text == str(question.answer):
			right_button = button
		elif game.wrong_answers.has(button.text):
			_check(button.disabled, "the wrong option is greyed out for the second try")
	await _tap(right_button)
	_check(not game.question_open and game.menus.screen == "", "the right answer closes the learning stop")
	_check(track.kept == kept + TUNING.QUESTION_BONUS_STARS, "the right answer gives bonus stars")
	_check(player.boost_time > 0.0, "the right answer gives a small boost")
	_check(game.solved_count() == 1 and game.first_try_count() == 0, "solved on the second try counts as solved, not as first try")
	_check(game.hud.stick.visible and game.hud.jump_button.enabled, "controls return after the learning stop")
	# Second stop: pause inside the question, leave, come back.
	_until(game, func() -> bool: return game.question_open, bot)
	_check(track.checkpoint == stops[1], "second learning stop")
	var prompt: String = str(game.active_question.prompt)
	var answer: String = str(game.active_question.answer)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.paused and game.question_open and game.menus.screen == "pause", "Back pauses even inside a learning stop")
	var result_id: String = game.result_id
	var elapsed_ms: int = int(game.snapshot.elapsed_ms)
	var kept_at_stop: int = int(game.snapshot.kept)
	var taken: int = game.track.taken_ids().size()
	await _free_game(game, true)
	# Course selection now offers to continue.
	game = await _new_game()
	var card: Node = game.menus.get_node_or_null("Course1")
	var resume: Button = _find(card, "Resume") as Button
	_check(resume != null, "course selection offers to continue the saved run")
	_check(_find(game.menus.get_node("Course0"), "Resume") == null, "other courses have no save")
	if resume != null:
		await _tap(resume)
	for _i in range(8):
		await process_frame
	game.set_process(false)
	_check(game.phase == game.Phase.COUNTDOWN and game.course_index == 1, "continue rebuilds the course")
	_check(game.track.checkpoint == stops[1], "resume starts at the saved checkpoint")
	_check(absf(game.player.s - game.track.checkpoint_s(stops[1])) < 0.01, "Lumo stands at the checkpoint flag")
	_check(game.track.kept == kept_at_stop and game.track.taken_ids().size() == taken, "stars of the saved run are restored")
	_check(game.result_id == result_id, "the run keeps its result id across a resume")
	_check(int(game.elapsed * 1000.0) == elapsed_ms, "the clock continues from the checkpoint")
	_check(game.solved_count() == 1, "answered learning stops are restored")
	game.countdown_left = 0.0
	_steps(game, 2)
	_check(game.question_open and str(game.active_question.prompt) == prompt, "the open learning stop comes back with the same question")
	# Right on the first try.
	game.answer(answer)
	_check(game.solved_count() == 2 and game.first_try_count() == 1, "first-try answers are recorded")
	# Third stop: two wrong answers show the solution; it does not count as solved.
	bot = BOT.new()
	_until(game, func() -> bool: return game.question_open, bot)
	_check(game.track.checkpoint == stops[2], "third learning stop")
	var third: Dictionary = game.active_question
	var bonus_before: int = game.track.kept
	var wrong: Array = third.options.filter(func(option) -> bool: return str(option) != str(third.answer))
	game.answer(str(wrong[0]))
	game.answer(str(wrong[1]))
	_check(game.question_open and bool(game.menus.data.reveal), "after two wrong answers the solution is shown")
	_check(str(game.menus.data.message).contains(str(third.answer)), "the shown solution names the answer")
	game.answer(str(third.answer))
	_check(not game.question_open, "tapping the shown solution continues the run")
	_check(game.solved_count() == 2, "a shown solution is not reported as solved")
	_check(game.track.kept == bonus_before, "a shown solution gives no bonus stars and costs none")
	await _free_game(game)


# ------------------------------------------------------------------ damaged or foreign saves

func _test_corrupt_saves() -> void:
	var game = await _open(1)
	var plan = game.plan
	var path: String = game.session_path
	var identity: Dictionary = game._identity(1)
	identity["signature"] = plan.signature
	var bot = BOT.new()
	_until(game, func() -> bool: return game.track.checkpoint >= 0, bot)
	var good: Dictionary = SESSION.load_valid(path, identity, plan)
	_check(not good.is_empty() and int(good.checkpoint) == 0, "a real save is accepted")
	var state: Dictionary = game.snapshot.duplicate(true)
	state["result_id"] = game.result_id
	state["pending_question"] = {}
	state["recent_questions"] = []
	await _free_game(game)
	var cases: Dictionary = {
		"checkpoint out of range": {"checkpoint": 99},
		"negative checkpoint": {"checkpoint": -3},
		"checkpoint of wrong type": {"checkpoint": "2"},
		"star index out of range": {"taken": PackedInt32Array([0, 999999])},
		"duplicate star": {"taken": PackedInt32Array([1, 1])},
		"stars from beyond the checkpoint": {"taken": PackedInt32Array([plan.star_s.size() - 1])},
		"more stars than collected": {"kept": 100000},
		"negative stars": {"kept": -5},
		"empty result id": {"result_id": ""},
		"absurd time": {"elapsed_ms": 999999999},
		"negative time": {"elapsed_ms": -1},
		"broken index that is no crate": {"broken": [0, 999]},
		"question at a plain checkpoint": {"questions": {0: {"correct": true, "first": true}}},
		"malformed question entry": {"questions": {plan.question_checkpoints()[0]: "yes"}},
		"malformed pending question": {"pending_question": {"prompt": "x", "answer": "1", "options": ["2"]}},
	}
	for label in cases:
		var broken: Dictionary = state.duplicate(true)
		broken.merge(cases[label], true)
		SESSION.save(path, identity, broken)
		_check(SESSION.load_valid(path, identity, plan).is_empty(), "save is rejected: " + str(label))
	SESSION.save(path, identity, state)
	for key in ["child_scope", "course", "signature", "subject"]:
		var other: Dictionary = identity.duplicate(true)
		other[key] = "other"
		_check(SESSION.load_valid(path, other, plan).is_empty(), "save of another %s is rejected" % key)
	var other_grade: Dictionary = identity.duplicate(true)
	other_grade["grade"] = 3
	_check(SESSION.load_valid(path, other_grade, plan).is_empty(), "save of another grade is rejected")
	var wrong_version := ConfigFile.new()
	wrong_version.load(path)
	wrong_version.set_value("run", "version", 99)
	wrong_version.save(path)
	_check(SESSION.load_valid(path, identity, plan).is_empty(), "save of another version is rejected")
	# Garbage on disk: the game starts fresh and removes the file.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\u0000\u0001 this is { not a [save file\n\n===")
	file.close()
	_check(SESSION.load_valid(path, identity, plan).is_empty(), "garbage is rejected")
	_check(SESSION.peek(path, game_identity(1)) == -1, "garbage is not offered as a saved run")
	game = await _open(1, true)
	_check(game.phase == game.Phase.RUNNING and game.track.checkpoint == -1, "a corrupt save is ignored safely")
	_check(absf(game.player.s - game.plan.start_s) < 1.0 and game.track.kept == 0, "the run starts fresh from the start line")
	_check(not FileAccess.file_exists(path), "the corrupt save file is removed")
	await _free_game(game)


func game_identity(index: int) -> Dictionary:
	return {
		"child_scope": CHILD.sha256_text(),
		"grade": 2,
		"subject": "Deutsch",
		"course": str(COURSES.course(index).id),
	}


# ------------------------------------------------------------------ host contract

func _test_host_contract() -> void:
	fake = FakeHost.new()
	root.add_child(fake)
	bridge._host = fake
	bridge._options = bridge.validated_options(JSON.parse_string(fake.getLaunchOptions()))
	bridge._return_pending = false
	_check(bridge.is_embedded() and bridge.launch_options().scene == "run", "fake host launches the game run")
	# Paused return: no stars, no reward.
	var game = await _open(2)
	var bot = BOT.new()
	_until(game, func() -> bool: return game.track.checkpoint >= 0, bot)
	_check(game.track.kept > 0, "stars were collected before the pause")
	await _tap(game.hud.pause_button)
	_check(game.paused, "paused through the pause button")
	await _tap(_find(game.menus, "LeaveGames") as Button)
	_check(fake.returns.size() == 1 and fake.returns[0].destination == "games", "pause menu returns to the games")
	var paused: Dictionary = fake.returns[0].payload
	_check(paused.game == "run" and paused.status == "paused", "paused return reports status paused")
	_check(int(paused.stars) == 0 and int(paused.solved) == 0, "paused return reports no stars")
	_check(paused.resultId == game.result_id and paused.sessionId == "run-test", "paused return carries result and session id")
	_check(fake.rewards.is_empty(), "a paused run books no reward")
	_check(FileAccess.file_exists(game.session_path), "the paused run stays saved")
	bridge._return_pending = false
	await _free_game(game, true)
	# Abandoned from the menu: also nothing.
	game = await _new_game()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(fake.returns.size() == 2 and int(fake.returns[1].payload.stars) == 0, "Back on the course selection returns without stars")
	_check(fake.returns[1].payload.status == "paused" and fake.rewards.is_empty(), "leaving the menu books no reward")
	bridge._return_pending = false
	await _free_game(game)
	# Finished run: exactly one reward. The host refuses the first write.
	game = await _open(2, true)
	_check(game.track.checkpoint >= 0, "the paused run is resumed for the finish")
	var id: String = game.result_id
	bot = BOT.new()
	fake.accept_rewards = false
	_complete(game, bot)
	_check(game.phase == game.Phase.FINISHED, "the scripted player reaches the finish gate")
	_check(fake.rewards.is_empty(), "a refused reward is not counted")
	_check(game.menus.screen == "result" and game.menus.data.has("notice"), "a failed save is shown on the result screen")
	fake.accept_rewards = true
	var payload: Dictionary = game.result_payload
	_check(payload.game == "run" and payload.status == "completed", "finish payload: game run, status completed")
	_check(payload.resultId == id and not id.is_empty() and payload.sessionId == "run-test", "finish payload: result id and session id")
	_check(int(payload.grade) == 2 and payload.subject == "Deutsch", "finish payload: grade and subject")
	_check(payload.course == "sonnenhafen", "finish payload: course id")
	_check(int(payload.solved) == game.solved_count() and int(payload.solved) == 3, "finish payload: solved = correctly answered stops")
	_check(int(payload.rating) >= 1 and int(payload.rating) <= 3, "finish payload: rating 1..3")
	_check(int(payload.rating) == TUNING.rating(game.track.kept, game.plan.star_total), "rating follows the star thresholds")
	_check(int(payload.stars) == TUNING.reward(int(payload.solved), int(payload.rating)), "finish payload: stars follow the reward rule")
	_check(int(payload.collected) == game.track.kept and int(payload.collectible) == game.plan.star_total, "finish payload: collected of collectible")
	_check(int(payload.collected) <= int(payload.collectible), "collected never exceeds collectible")
	_check(int(payload.timeMs) > 30000 and int(payload.timeMs) == int(game.elapsed * 1000.0), "finish payload: time in milliseconds")
	for wanted in ["Again", "Courses", "LeaveGames", "LeaveLearn", "Rating", "Facts"]:
		_check(_find(game.menus, wanted) != null, "result screen has " + wanted)
	_check(str(game.menus.data.thresholds).contains("50 %") and str(game.menus.data.thresholds).contains("80 %"), "result screen names the star thresholds")
	var facts: String = str(game.menus.data.facts)
	_check(facts.contains("Sterne") and facts.contains("Zeit") and facts.contains("Aufgaben"), "result screen shows stars, time and tasks")
	game._finish()
	game._finish()
	await _tap(_find(game.menus, "LeaveLearn") as Button)
	_check(fake.rewards.size() == 1, "the reward is reported to the host exactly once")
	_check(fake.rewards[0].resultId == id and fake.rewards[0].game == "run", "the reported reward is this run")
	_check(int(fake.rewards[0].stars) == int(payload.stars), "the reported stars match the result screen")
	_check(fake.returns.size() == 3 and fake.returns[2].destination == "learn", "Zum Lernen returns to learning")
	_check(fake.returns[2].payload.status == "completed" and fake.returns[2].payload.resultId == id, "the return carries the completed result")
	bridge._return_pending = false
	game.return_to_app("games")
	game._finish()
	_check(fake.rewards.size() == 1, "returning again does not report a second reward")
	_check(not FileAccess.file_exists(game.session_path), "a finished run leaves no save behind")
	bridge._return_pending = false
	await _free_game(game)
	bridge._host = null
	bridge._options = {}
	root.remove_child(fake)
	fake.queue_free()


# ------------------------------------------------------------------ all courses, start to finish

func _test_all_courses() -> void:
	var rewards: Array[Dictionary] = []
	var counter: Callable = func(payload: Dictionary) -> void: rewards.append(payload)
	bridge.reward_reported.connect(counter)
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		# The simple scripted player.
		var game = await _open(index)
		var bot = BOT.new()
		var lost: Array[int] = [0]
		var samples: Array[int] = [0]
		var low: Array[int] = [0]
		var sampler: Callable = func() -> void:
			samples[0] += 1
			if not game.camera.is_position_in_frustum(game.actor.body_position()):
				lost[0] += 1
			if game.camera.global_position.y < game.world.position_at(game.player.s - 6.0).y + 0.8:
				low[0] += 1
		var before: int = rewards.size()
		var steps: int = _complete(game, bot, sampler)
		var seconds: float = float(steps) * STEP
		_check(game.phase == game.Phase.FINISHED, "%s: scripted player finishes the course" % id)
		_check(seconds < game.plan.length / 9.0, "%s: finished in a sane time (%.0f s for %.0f m)" % [id, seconds, game.plan.length])
		_check(game.track.checkpoint == game.plan.checkpoints.size() - 1, "%s: every checkpoint was passed" % id)
		_check(game.solved_count() == 3, "%s: three learning stops on the way" % id)
		_check(float(game.track.kept) / float(game.plan.star_total) > 0.6, "%s: following the star trails collects most stars (%d of %d)" % [id, game.track.kept, game.plan.star_total])
		_check(game.track.stumbles <= 12, "%s: the course is fair for a simple player (%d stumbles)" % [id, game.track.stumbles])
		_check(samples[0] > 100 and lost[0] == 0, "%s: the camera never loses Lumo (%d samples)" % [id, samples[0]])
		_check(low[0] == 0, "%s: the camera never dips into the road" % id)
		_check(rewards.size() == before + 1 and rewards[rewards.size() - 1].course == id, "%s: one reward for the finished run" % id)
		print("[LumoRun] %s bot: %.0f s, %d/%d stars, %d stumbles, rating %d, reward %d" % [id, seconds, game.track.kept, game.plan.star_total, game.track.stumbles, int(game.result_payload.rating), int(game.result_payload.stars)])
		await _free_game(game)
		# A child who touches nothing still arrives: no softlock anywhere.
		game = await _open(index)
		steps = _complete(game, null)
		seconds = float(steps) * STEP
		_check(game.phase == game.Phase.FINISHED, "%s: even without any input the finish is reached" % id)
		_check(seconds < game.plan.length / 6.0, "%s: no-input run needs %.0f s" % [id, seconds])
		_check(int(game.result_payload.rating) < 3, "%s: three stars need real play" % id)
		print("[LumoRun] %s no input: %.0f s, %d/%d stars, %d stumbles, rating %d" % [id, seconds, game.track.kept, game.plan.star_total, game.track.stumbles, int(game.result_payload.rating)])
		await _free_game(game)
	bridge.reward_reported.disconnect(counter)


# ------------------------------------------------------------------ window sizes, calm mode

func _test_layouts_and_calm_mode() -> void:
	var sizes: Array = [
		[Vector2i(720, 1600), 2.0, "phone portrait"],
		[Vector2i(1600, 720), 2.0, "phone landscape"],
		[Vector2i(1768, 2208), 2.6, "unfolded, near square"],
		[Vector2i(2208, 1768), 2.6, "unfolded, landscape"],
		[Vector2i(412, 915), 1.0, "small window"],
	]
	var had_density: bool = bridge._options.has("displayDensity")
	for sample in sizes:
		root.size = sample[0]
		bridge._options["displayDensity"] = sample[1]
		var label: String = str(sample[2])
		var game = await _new_game()
		var view: Rect2 = root.get_visible_rect()
		var dp: float = game.menus._unit
		var inside: bool = true
		for index in range(3):
			var card: Control = game.menus.get_node("Course%d" % index)
			inside = inside and view.grow(1.0).encloses(card.get_global_rect())
			var start: Button = _find(card, "Start") as Button
			inside = inside and view.grow(1.0).encloses(start.get_global_rect())
			_check(start.size.y >= 46.0 * dp - 0.5, "%s: start button %d is a real touch target" % [label, index])
		_check(inside, "%s: course cards and their buttons fit the screen" % label)
		game.set_process(false)
		game.start_course(2, false)
		game.countdown_left = 0.0
		_steps(game, 30)
		for control in [game.hud.stick, game.hud.jump_button, game.hud.dash_button, game.hud.pause_button]:
			var rect: Rect2 = control.get_global_rect()
			_check(view.encloses(rect), "%s: %s is on screen" % [label, control.name])
			_check(minf(rect.size.x, rect.size.y) >= 48.0 * dp - 0.5, "%s: %s is at least 48 dp" % [label, control.name])
		_check(not game.hud.stick.get_global_rect().intersects(game.hud.jump_button.get_global_rect()), "%s: thumbs do not collide" % label)
		_check(not game.hud.dash_button.get_global_rect().intersects(game.hud.jump_button.get_global_rect()), "%s: dash and jump are separate" % label)
		_check(game.camera.is_position_in_frustum(game.actor.body_position()), "%s: Lumo is in the picture" % label)
		game.pause()
		for _i in range(4):
			await process_frame
		_check(view.grow(1.0).encloses(game.menus.dialog_rect()), "%s: pause menu fits the screen" % label)
		game.resume()
		game._finish()
		for _i in range(4):
			await process_frame
		_check(view.grow(1.0).encloses(game.menus.dialog_rect()), "%s: result screen fits the screen" % label)
		var again: Button = _find(game.menus, "Again") as Button
		_check(again != null and again.size.y >= 46.0 * dp - 0.5, "%s: result buttons are real touch targets" % label)
		await _free_game(game)
	if not had_density:
		bridge._options.erase("displayDensity")
	root.size = Vector2i(720, 1280)
	# Reduced motion and no sound.
	var audio: Node = root.get_node("AudioManager")
	var was_muted: bool = audio._muted
	audio._muted = true
	var calm = await _open(1, false, {"reduceAnimations": true})
	_check(calm.reduced_motion and calm.camera.reduced_motion and calm.actor.reduced_motion, "reduced motion reaches camera and Lumo")
	_check(calm.fx.get_child_count() == 0, "reduced motion shows no particle effects")
	var fov: float = calm.camera.fov
	var bot = BOT.new()
	calm.player.boost(2.0)
	_until(calm, func() -> bool: return calm.track.checkpoint >= 0, bot)
	_check(absf(calm.camera.fov - fov) < 0.01, "reduced motion keeps the field of view steady")
	_check(calm.track.kept > 20 and calm.phase == calm.Phase.RUNNING, "the game plays normally with reduced motion and without sound")
	await _free_game(calm)
	audio._muted = was_muted
