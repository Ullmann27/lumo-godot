extends SceneTree
## Renders Lumo Lauf with the real renderer (xvfb) for visual review: for every
## course the start screen, a running frame, a jump, a learning stop and the
## result screen, in portrait and landscape; plus draw calls and primitives of a
## running frame per course at MEDIUM and LOW. Desktop evidence only – not an
## Android frame-rate claim.
##
##   LUMO_CAPTURE_DIR=<dir> xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_run_capture.gd
##   LUMO_RUN_EXTRAS=1 adds set-piece frames (loop, big jump, high path, tunnel).

const BOT = preload("res://scripts/tests/helpers/lumo_run_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const SIZES: Array[Vector2i] = [Vector2i(720, 1600), Vector2i(1600, 720)]
## Both sizes stand for a phone with 2 px per dp: 360x800 dp and 800x360 dp.
const DENSITY: float = 2.0
const STEP: float = 1.0 / 60.0

var capture_dir: String = ""
var failures: Array[String] = []
var checks: int = 0
var saved: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[LumoRunCapture] " + label)


func _capture(name: String) -> void:
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and frame.get_size() == root.size, name + " has real viewport pixels")
	if frame == null:
		return
	var path: String = capture_dir.path_join(name + ".png")
	_check(frame.save_png(path) == OK, name + " saved")
	saved.append(path)


func _new_game(low: bool = false):
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
	var game = load("res://scenes/games/lumo_run.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.lightweight = low
	return game


func _free_game(game) -> void:
	game.abandoned = true
	current_scene = null
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


## Steps the real game with the scripted player until `done` says so.
func _drive(game, bot, done: Callable, limit: int = 60 * 600) -> bool:
	for _i in range(limit):
		if done.call():
			return true
		if game.question_open:
			return done.call()
		bot.drive(game, STEP)
		game.advance(STEP)
	return done.call()


## Steps one frame at a time with the renderer running, so effects on screen are
## the ones a child would see (fast-forwarding leaves stale particles behind).
func _live(game, bot, done: Callable, limit: int = 110) -> void:
	for _i in range(limit):
		if done.call() or game.question_open or game.phase == game.Phase.FINISHED:
			return
		bot.drive(game, STEP)
		game.advance(STEP)
		await process_frame


## Like _drive, but answers learning stops on the way.
func _drive_on(game, bot, done: Callable) -> void:
	for _i in range(40):
		if _drive(game, bot, done) and not game.question_open:
			return
		if game.question_open:
			game.answer(str(game.active_question.answer))
		elif game.phase == game.Phase.FINISHED:
			return


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LumoRunCapture] Real display required; refusing headless capture")
		quit(1)
		return
	capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
	if capture_dir.is_empty() or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		push_error("[LumoRunCapture] LUMO_CAPTURE_DIR must be writable")
		quit(1)
		return
	var only: String = OS.get_environment("LUMO_RUN_ONLY")
	var extras: bool = OS.get_environment("LUMO_RUN_EXTRAS") == "1"
	for index in range(COURSES.count()):
		DirAccess.remove_absolute("user://run_session_%s.cfg" % str(COURSES.course(index).id))
	var bridge: Node = root.get_node("HostBridge")
	var had_density: bool = bridge._options.has("displayDensity")
	var old_density: Variant = bridge._options.get("displayDensity")
	bridge._options["displayDensity"] = DENSITY
	var only_size: String = OS.get_environment("LUMO_RUN_SIZE")
	if OS.get_environment("LUMO_RUN_MEASURE_ONLY") == "1":
		only_size = "none"
	for size in SIZES:
		if not only_size.is_empty() and only_size != "%dx%d" % [size.x, size.y]:
			continue
		root.size = size
		var tag: String = "%dx%d" % [size.x, size.y]
		for index in range(COURSES.count()):
			var id: String = str(COURSES.course(index).id)
			if not only.is_empty() and only != id:
				continue
			var game = _new_game()
			for _i in range(20):
				await process_frame
			_check(game.menus.screen == "start", id + " start screen is shown")
			await _capture("%s_%s_1_start" % [id, tag])
			game.set_process(false)
			game.start_course(index, false)
			game.countdown_left = 0.0
			var bot = BOT.new()
			var player = game.player
			_drive(game, bot, func() -> bool: return player.s > game.plan.start_s + 110.0 and player.grounded)
			var from: float = player.s
			await _live(game, bot, func() -> bool: return player.s > from + 18.0 and player.grounded)
			await _capture("%s_%s_2_run" % [id, tag])
			var jump_at: float = _next_jump(game)
			_drive(game, bot, func() -> bool: return player.s > jump_at - 16.0)
			await _live(game, bot, func() -> bool: return not player.grounded and player.h > 1.1 and player.vy < 4.0)
			await _capture("%s_%s_3_jump" % [id, tag])
			_drive(game, bot, func() -> bool: return game.question_open)
			_check(game.question_open, id + " reaches a learning stop")
			await _capture("%s_%s_4_learning" % [id, tag])
			if extras:
				await _extras(game, bot, id, tag)
			if OS.get_environment("LUMO_RUN_QUICK") == "1":
				await _free_game(game)
				continue
			_drive_on(game, bot, func() -> bool: return game.phase == game.Phase.FINISHED)
			_check(game.phase == game.Phase.FINISHED, id + " reaches the finish")
			for _i in range(150):
				game.advance(STEP)
			await _capture("%s_%s_5_result" % [id, tag])
			await _free_game(game)
	if OS.get_environment("LUMO_RUN_SKIP_MEASURE") != "1":
		await _measure()
	if had_density:
		bridge._options["displayDensity"] = old_density
	else:
		bridge._options.erase("displayDensity")
	for path in saved:
		print("[LumoRunCapture] saved " + path)
	if failures.is_empty():
		print("[LumoRunCapture] PASS: %d checks, %d images" % [checks, saved.size()])
		quit(0)
	else:
		print("[LumoRunCapture] FAIL: %d of %d checks: %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)


## Road distance of the next hurdle or water channel ahead of Lumo.
func _next_jump(game) -> float:
	var best: float = INF
	for hurdle in game.plan.hurdles:
		if float(hurdle.s) > game.player.s + 20.0:
			best = minf(best, float(hurdle.s))
			break
	for gap in game.plan.channels:
		if not bool(gap.real) and float(gap.s0) > game.player.s + 20.0:
			best = minf(best, float(gap.s0))
			break
	return best


## Set pieces in the order they come on the course.
func _extras(game, bot, id: String, tag: String) -> void:
	var player = game.player
	var plan = game.plan
	var shots: Array[Dictionary] = []
	for platform in plan.platforms:
		if float(platform.s0) > player.s + 40.0:
			shots.append({"name": "highpath", "from": float(platform.s0) - 22.0, "at": float(platform.s0) + 7.0})
			break
	for kind in ["rock", "crate", "roller"]:
		for blocker in plan.blockers:
			if str(blocker.kind) == kind and float(blocker.s) > player.s + 40.0:
				shots.append({"name": kind, "from": float(blocker.s) - 30.0, "at": float(blocker.s) - 13.0})
				break
	for hurdle in plan.hurdles:
		if float(hurdle.s) > player.s + 40.0:
			shots.append({"name": "hurdle", "from": float(hurdle.s) - 26.0, "at": float(hurdle.s) - 11.0})
			break
	for pad in plan.bounces:
		if not bool(pad.get("band", false)) and float(pad.s) > player.s + 40.0:
			shots.append({"name": "bounce", "from": float(pad.s) - 24.0, "at": float(pad.s) + 5.0})
			break
	if not plan.loop.is_empty() and float(plan.loop.start) > player.s + 20.0:
		shots.append({"name": "loop", "from": float(plan.loop.start) - 14.0, "loop": true})
	for gap in plan.channels:
		if bool(gap.real) and float(gap.s0) > player.s + 40.0:
			shots.append({"name": "bigjump", "from": float(gap.s0) - 26.0, "at": float(gap.s0) + 4.0})
	if not plan.covered.is_empty() and plan.covered[0].y > player.s + 40.0:
		var inside: float = maxf(player.s + 30.0, (plan.covered[0].x + plan.covered[0].y) * 0.5)
		shots.append({"name": "covered", "from": inside - 14.0, "at": inside})
	shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.from) < float(b.from))
	for shot in shots:
		if float(shot.from) < player.s:
			continue
		_drive_on(game, bot, func() -> bool: return player.s > float(shot.from))
		if shot.has("loop"):
			await _live(game, bot, func() -> bool: return player.loop_u > 0.42)
		else:
			await _live(game, bot, func() -> bool: return player.s > float(shot.at))
		await _capture("%s_%s_x_%s" % [id, tag, str(shot.name)])


## Draw calls and primitives of one running frame per course and profile.
func _measure() -> void:
	root.size = Vector2i(720, 1600)
	var performance: Node = root.get_node("PerformanceManager")
	var original: int = performance.current_profile
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		for profile in ["MEDIUM", "LOW"]:
			var low: bool = profile == "LOW"
			var game = _new_game(low)
			await process_frame
			game.set_process(false)
			game.start_course(index, false)
			performance.set_profile(performance.Profile.LOW if low else performance.Profile.MEDIUM, false)
			game.countdown_left = 0.0
			var bot = BOT.new()
			var player = game.player
			_drive(game, bot, func() -> bool: return player.s > game.plan.start_s + 240.0 and player.grounded)
			for _i in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			print(
				"[LumoRunCapture] %s %s: draw_calls=%d primitives=%d objects=%d (720x1600, s=%.0f m)"
				% [
					id, profile,
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
					player.s
				]
			)
			await _free_game(game)
	performance.set_profile(original, false)
