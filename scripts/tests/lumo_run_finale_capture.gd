extends SceneTree
## Pictures of the finale of every Lumo-Lauf world with the real renderer
## (xvfb + gl_compatibility), for visual review: the ENDSPURT stretch, the
## finale jump, the finish line and the result card with the medal. Desktop
## evidence only, no frame-rate claim.
##
##   LUMO_CAPTURE_DIR=<dir> xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_run_finale_capture.gd -- [--course=<id>] \
##     [--size=1080x2340] [--density=2.625]

const CHILD_PLAYER = preload("res://scripts/tests/helpers/lumo_run_child.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const SESSION = preload("res://scripts/games/run/run_session.gd")
const SIZES: Array[Vector2i] = [Vector2i(1080, 2340), Vector2i(2176, 1812)]
const STEP: float = 1.0 / 60.0
const CHILD: String = "lumo-run-finale-capture"

var capture_dir: String = ""
var failures: Array[String] = []
var saved: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_warning("[LumoFinaleCapture] " + label)


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


## Steps the game without drawing (answering learning stops) until `done`.
func _drive(game, child, done: Callable, limit: int = 60 * 600) -> void:
	for _i in range(limit):
		if done.call() or game.phase == game.Phase.FINISHED:
			return
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			child.drive(game, STEP)
		game.advance(STEP)


## Steps one frame at a time with the renderer running.
func _live(game, child, done: Callable, limit: int = 90) -> void:
	for _i in range(limit):
		if done.call() or game.phase == game.Phase.FINISHED:
			return
		child.drive(game, STEP)
		game.advance(STEP)
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LumoFinaleCapture] Real display required")
		quit(1)
		return
	capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
	if capture_dir.is_empty() or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		push_error("[LumoFinaleCapture] LUMO_CAPTURE_DIR must be writable")
		quit(1)
		return
	var options: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	var sizes: Array[Vector2i] = SIZES.duplicate()
	if options.has("size"):
		var parts: PackedStringArray = str(options.size).split("x")
		sizes = [Vector2i(int(parts[0]), int(parts[1]))]
	var bridge: Node = root.get_node("HostBridge")
	bridge._options["displayDensity"] = float(options.get("density", "2.625"))
	for size in sizes:
		root.size = size
		var tag: String = "%dx%d" % [size.x, size.y]
		for index in range(COURSES.count()):
			var course: Dictionary = COURSES.course(index)
			var id: String = str(course.id)
			if options.has("course") and str(options.course) != id:
				continue
			await _world(index, course, tag)
	bridge._options.erase("displayDensity")
	_clean()
	for path in saved:
		print("[LumoFinaleCapture] saved " + path)
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	if failures.is_empty():
		print("[LumoFinaleCapture] PASS: %d images" % saved.size())
		quit(0)
	else:
		print("[LumoFinaleCapture] FAIL: %s" % ", ".join(failures))
		quit(1)


func _world(index: int, course: Dictionary, tag: String) -> void:
	var id: String = str(course.id)
	root.get_node("SceneRouter").launch_options = {
		"grade": 2, "subject": "Mathematik", "childKey": CHILD, "sessionId": "finale-capture"
	}
	var game = load("res://scenes/games/lumo_run.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for _i in range(4):
		await process_frame
	game.set_process(false)
	game.start_course(index, false)
	game.countdown_left = 0.0
	var spot: Dictionary = {}
	for moment in game.plan.moments:
		if bool(moment.get("finale", false)):
			spot = moment
	_check(not spot.is_empty(), id + " has a finale")
	if spot.is_empty():
		await _free(game)
		return
	var child := CHILD_PLAYER.new(bool(course.get("path", false)), 2)
	var player = game.player
	# 1. The ENDSPURT stretch: the call is out, the jump lies ahead.
	_drive(game, child, func() -> bool: return player.s >= float(spot.cue) + 2.0)
	await _live(game, child, func() -> bool: return player.s >= float(spot.go) - 6.0, 40)
	_check(game.hud.banner_label.text == "ENDSPURT!", id + " calls ENDSPURT")
	await _capture("%s_%s_1_finale" % [id, tag])
	# 2. The finale jump, high above the gap.
	_drive(game, child, func() -> bool: return player.s >= float(spot.s0) - 8.0)
	await _live(
		game, child, func() -> bool: return not player.grounded and player.s > float(spot.s0) + 2.0, 80
	)
	await _capture("%s_%s_2_jump" % [id, tag])
	# 3. The finish line itself (slow motion, sparkles, ZIEL!).
	_drive(game, child, func() -> bool: return player.s >= game.plan.finish_s - 14.0)
	await _live(game, child, func() -> bool: return false, 120)
	for _i in range(8):
		game.advance(STEP)
		await process_frame
	_check(game.phase == game.Phase.FINISHED, id + " reaches the finish")
	await _capture("%s_%s_3_ziel" % [id, tag])
	# 4. The result card with the medal.
	for _i in range(150):
		game.advance(STEP)
	for _i in range(20):
		await process_frame
	_check(game.menus.screen == "result", id + " shows the result")
	await _capture("%s_%s_4_result" % [id, tag])
	await _free(game)


func _free(game) -> void:
	game.abandoned = true
	current_scene = null
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame


func _clean() -> void:
	var scope: String = CHILD.sha256_text()
	for index in range(COURSES.count()):
		var id: String = str(COURSES.course(index).id)
		SESSION.erase(SESSION.replay_path(scope, id))
		for subject in ["Deutsch", "Mathematik"]:
			SESSION.erase(SESSION.path_for(scope, 2, subject, id))
