extends SceneTree
## Tempo and flow of Lumo Lauf on the Dschungelherz path (headless).
##
##   godot --headless --path . --script res://scripts/tests/lumo_run_flow_regression.gd
##
## Measures the speed curve (start, cruise, sprint from momentum, speed pads,
## mine cart), the kind jump windows (coyote time, jump buffer), that braking
## or a bump costs the momentum, the motion blends of the real Lumo (no state
## change without a crossfade), the tasks of every section and one full run of
## the scripted player. Prints the numbers it measures.

const JUNGLE_BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const STEP: float = 1.0 / 60.0
## On screen the path plays this much faster than course time.
const SCALE: float = TUNING.PATH_TIME_SCALE

var checks: int = 0
var failures: Array[String] = []
var scene: PackedScene
var router: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[LumoFlow] FAILED CHECK: " + label)
	else:
		print("[LumoFlow] ok: " + label)


func _open():
	router.launch_options = {"grade": 2, "subject": "Mathematik", "childKey": "lumo-flow-regression", "sessionId": "flow-test"}
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.start_course(COURSES.index_of("dschungelherz"), false)
	game.countdown_left = 0.0
	game.advance(STEP)
	return game


func _free(game) -> void:
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


func _place(game, s: float, speed: float, lat: float = 0.0) -> void:
	var passed: int = -1
	for checkpoint in game.plan.checkpoints:
		if float(checkpoint.s) < s:
			passed = int(checkpoint.index)
	game.track.checkpoint = maxi(game.track.checkpoint, passed)
	game.track.rescue = game.plan.respawn_index(s)
	game.track.chase_active = false
	game.player.place(s, lat, speed)
	game.player.invulnerable = 0.0
	game.touch_steer = Vector2.ZERO
	game.player.release_jump()
	game.player.jump_buffer = 0.0


func _steps(game, count: int) -> void:
	for _i in range(count):
		if game.question_open:
			game.answer(str(game.active_question.answer))
		game.advance(STEP)


func _pads(game) -> Array:
	return game.plan.boosts.filter(func(strip: Dictionary) -> bool: return bool(strip.get("pad", false)))


func _run() -> void:
	scene = load("res://scenes/games/lumo_run.tscn")
	router = root.get_node("SceneRouter")
	var game = await _open()
	_test_tempo(game)
	_test_jump_windows(game)
	await _free(game)
	await _test_full_run()
	if failures.is_empty():
		print("[LumoFlow] PASS: %d checks" % checks)
		quit(0)
	else:
		print("[LumoFlow] FAIL: %d of %d checks failed: %s" % [failures.size(), checks, " | ".join(failures)])
		quit(1)


# ------------------------------------------------------------------ tempo

func _test_tempo(game) -> void:
	var player = game.player
	var pads: Array = _pads(game)
	_check(pads.size() >= 2, "speed pads on the long safe stretches of the dense path (%d)" % pads.size())
	_check(TUNING.PATH_CRUISE * SCALE >= 11.0, "the base pace on the path is higher than before (%.1f m/s on screen, was 8.5)" % (TUNING.PATH_CRUISE * SCALE))
	# From a standstill right behind a pad: the speed curve of a free run.
	var pad: Dictionary = pads[1] if pads.size() > 1 else pads[0]
	_place(game, float(pad.s1) + 0.5, 0.0)
	var curve: Array[String] = []
	var reached_cruise: float = -1.0
	var top: float = 0.0
	var peak_flow: float = 0.0
	for frame in range(int(4.0 / STEP)):
		_steps(game, 1)
		var t: float = float(frame + 1) * STEP
		if reached_cruise < 0.0 and player.speed >= TUNING.PATH_CRUISE - 0.05:
			reached_cruise = t
		top = maxf(top, player.speed)
		peak_flow = maxf(peak_flow, player.flow)
		if (frame + 1) % 30 == 0:
			curve.append("%.1fs %.1f" % [t, player.speed * SCALE])
	print("[LumoFlow] speed curve from standstill (m/s on screen): " + ", ".join(curve))
	_check(reached_cruise > 0.0 and reached_cruise < 1.4, "Lumo is at cruise speed quickly (%.2f s)" % reached_cruise)
	_check(top >= TUNING.PATH_CRUISE + TUNING.PATH_FLOW_BONUS * 0.75 and peak_flow > 0.8, "running on freely builds a sprint (top %.1f m/s on screen, flow %.2f)" % [top * SCALE, peak_flow])
	# Braking takes the momentum away (a stop is a stop).
	# Judged at the moment he stands: a creature of the path may bump the standing
	# Lumo afterwards (at the 1.5 path tempo one reaches him within the second).
	game.touch_steer = Vector2(0.0, 1.0)
	var stopped_after: int = -1
	for brake_step in range(60):
		_steps(game, 1)
		if stopped_after < 0 and absf(player.speed) < 0.5:
			stopped_after = brake_step + 1
	_check(stopped_after > 0 and player.flow < 0.1, "pulling back stops Lumo and ends the sprint (flow %.2f, stopped after %d frames)" % [player.flow, stopped_after])
	game.touch_steer = Vector2.ZERO
	# A speed pad.
	_place(game, float(pad.s0) - 2.0, TUNING.PATH_CRUISE)
	var pad_top: float = 0.0
	for _i in range(90):
		_steps(game, 1)
		pad_top = maxf(pad_top, player.speed)
	print("[LumoFlow] speed pad: %.1f m/s on screen" % (pad_top * SCALE))
	_check(pad_top >= TUNING.PATH_CRUISE + TUNING.BOOST_BONUS * 0.8, "a speed pad shoots Lumo forward (%.1f m/s on screen)" % (pad_top * SCALE))
	# A bump costs the momentum but not the run.
	player.flow = 1.0
	player.stumble()
	_check(player.flow == 0.0, "a bump costs the sprint")
	# The mine cart.
	_check(TUNING.CART_SPEED * SCALE >= 15.0, "the mine cart is fast (%.1f m/s on screen, was 13)" % (TUNING.CART_SPEED * SCALE))


# ------------------------------------------------------------------ jump windows

func _test_jump_windows(game) -> void:
	var player = game.player
	_check(player.coyote_window / SCALE >= 0.15 and player.buffer_window / SCALE >= 0.2, "kind jump windows on the path (coyote %.2f s, buffer %.2f s on screen; were 0.12 and 0.18)" % [player.coyote_window / SCALE, player.buffer_window / SCALE])
	# Coyote time: running off the edge of a hole, a late press still jumps.
	var gap: Vector2 = Vector2.ZERO
	for candidate in game.world.level.gaps:
		if candidate.x > float(game.plan.intro_end) + 5.0 and candidate.y - candidate.x > 2.0:
			gap = candidate
			break
	_place(game, gap.x - 12.0, TUNING.PATH_CRUISE)
	var left_ground: int = -1
	var jumped: bool = false
	for frame in range(120):
		_steps(game, 1)
		if left_ground < 0 and not player.grounded:
			left_ground = frame
		if left_ground >= 0 and frame == left_ground + 7:
			player.press_jump()
		if player.events.has(&"jump") or (player.jumping and player.vy > 5.0):
			jumped = true
			break
	player.release_jump()
	_check(left_ground >= 0 and jumped, "a jump 0.12 s after running off the edge still works (coyote time)")
	# Jump buffer: a press shortly before landing jumps right after landing.
	_place(game, gap.y + 2.0, TUNING.PATH_CRUISE)
	_steps(game, 20)
	player.press_jump()
	player.release_jump()
	_steps(game, 2)
	var buffered: bool = false
	for frame in range(90):
		if player.vy < -2.0 and player.h < game.track.ground_at(player.s, player.lat, player.h) + 1.0 and not buffered:
			player.press_jump()
			player.release_jump()
			buffered = true
			var again: bool = false
			for _i in range(int(0.2 / STEP)):
				_steps(game, 1)
				if player.jumping and player.vy > 3.0:
					again = true
					break
			_check(again, "a press just before landing jumps again right away (jump buffer)")
			break
		_steps(game, 1)
	if not buffered:
		_check(false, "the buffer test came down to the ground")


# ------------------------------------------------------------------ a whole run

func _test_full_run() -> void:
	var game = await _open()
	var bot = JUNGLE_BOT.new(3)
	var steps: int = 0
	var top: float = 0.0
	var moving: float = 0.0
	while game.phase != game.Phase.FINISHED and steps < 60 * 600:
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			bot.drive(game, STEP)
		game.advance(STEP)
		steps += 1
		if not game.question_open and game.player.s > 0.0:
			top = maxf(top, game.player.speed)
			moving += STEP
	var finished: bool = game.phase == game.Phase.FINISHED
	var length: float = float(game.plan.finish_s) - float(game.plan.start_s)
	print("[LumoFlow] scripted run: %.0f s, %.0f m, average %.1f m/s, top %.1f m/s" % [moving, length, length / maxf(moving, 1.0), top])
	_check(finished, "the scripted player reaches the goal (%.0f s)" % moving)
	_check(top >= 15.0, "the run has real speed moments (top %.1f m/s)" % top)
	await _free(game)
