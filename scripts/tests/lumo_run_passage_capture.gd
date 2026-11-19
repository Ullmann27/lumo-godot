extends SceneTree
## Picture series of the three adventure passages of Dschungelherz, played by
## the scripted player on the safe and on the brave line. Needs a display:
##
##   LUMO_CAPTURE_DIR=/some/dir xvfb-run -a -s '-screen 0 2400x2400x24' \
##     godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_run_passage_capture.gd
##
## LUMO_RUN_SIZE=1600x720 or 1080x2340 limits it to one window size.

const BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const SIZES: Array[Vector2i] = [Vector2i(1600, 720), Vector2i(1080, 2340)]
const STEP: float = 1.0 / 60.0

var capture_dir: String = ""
var failures: Array[String] = []
var saved: int = 0
var game
var bot
var tag: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	# A learning stop opened on the way would cover the picture: answer it first.
	var guard: int = 0
	while game.question_open and guard < 10:
		game.answer(str(game.active_question.answer))
		game.advance(STEP)
		guard += 1
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame == null:
		failures.append(name + " has no pixels")
		return
	var path: String = capture_dir.path_join("%s_%s.jpg" % [tag, name])
	if frame.save_jpg(path, 0.85) != OK:
		failures.append(name + " not saved")
		return
	saved += 1
	print("[PassageCapture] saved " + path)


## Steps the game without drawing until `done`, then lets a few frames render.
func _until(done: Callable, limit: int = 60 * 30) -> bool:
	for _step in range(limit):
		if done.call() or game.phase == game.Phase.FINISHED:
			break
		if game.question_open:
			game.answer(str(game.active_question.answer))
		bot.drive(game, STEP)
		game.advance(STEP)
	return done.call()


func _place(s: float, speed: float) -> void:
	var passed: int = -1
	# Checkpoints up to the passage count as reached: no learning stop (and no
	# fading question card) gets into the pictures of the passage.
	for checkpoint in game.plan.checkpoints:
		if float(checkpoint.s) < s + 60.0:
			passed = int(checkpoint.index)
	game.track.checkpoint = maxi(game.track.checkpoint, passed)
	game.track.rescue = game.plan.respawn_index(s)
	game.track.chase_active = false
	game.track.falls.clear()
	game.track.crumbled.clear()
	game.player.place(s, 0.0, speed)
	# No section banner from the jump: the run is already in this section.
	game._section = game.world.section_at(s)
	game.player.invulnerable = 0.0
	game.player.release_jump()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[PassageCapture] Real display required")
		quit(1)
		return
	capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
	if capture_dir.is_empty() or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		push_error("[PassageCapture] LUMO_CAPTURE_DIR must be writable")
		quit(1)
		return
	var only: String = OS.get_environment("LUMO_RUN_SIZE")
	root.get_node("HostBridge")._options["displayDensity"] = 2.0
	for size in SIZES:
		tag = "%dx%d" % [size.x, size.y]
		if not only.is_empty() and only != tag:
			continue
		root.size = size
		root.get_node("SceneRouter").launch_options = {
			"grade": 2, "subject": "Mathematik", "childKey": "passage-" + tag
		}
		game = load("res://scenes/games/lumo_run.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		for _i in range(4):
			await process_frame
		game.set_process(false)
		game.start_course(COURSES.index_of("dschungelherz"), false)
		game.countdown_left = 0.0
		game.advance(STEP)
		var number: int = 0
		for passage in game.plan.passages:
			number += 1
			var only_passage: String = OS.get_environment("LUMO_PASSAGE")
			if not only_passage.is_empty() and only_passage != str(passage.name):
				continue
			for line in ["lower", "upper"]:
				bot = BOT.new(3)
				bot.routes[str(passage.name)] = line
				var label: String = (
					"p%d_%s_%s"
					% [
						number,
						str(passage.name).to_lower().replace("-", "_").replace("ü", "ue"),
						"sicher" if line == "lower" else "mutig"
					]
				)
				_place(float(passage.announce) - 30.0, TUNING.PATH_CRUISE)
				if line == "upper":
					game.player.flow = 1.0
				game._hinted.clear()
				var player = game.player
				if line == "lower":
					await _until(func() -> bool: return player.s > float(passage.announce) + 6.0)
					await _capture(label + "_1_ansage")
				await _until(func() -> bool: return player.s > float(passage.s0) - 9.0)
				await _capture(label + "_2_anlauf")
				var middle: float = (
					float(passage.s0)
					+ (
						(float(passage.safe_gap) if line == "lower" else float(passage.brave_gap))
						* 0.45
					)
				)
				if float(passage.plank) > 0.0:
					middle = (
						float(passage.s1)
						- (
							(
								float(passage.safe_gap)
								if line == "lower"
								else float(passage.brave_gap)
							)
							* 0.6
						)
					)
				await _until(func() -> bool: return player.s > middle)
				await _capture(label + "_3_sprung")
				await _until(
					func() -> bool: return player.s > float(passage.s1) + 4.0 and player.grounded
				)
				await _capture(label + "_4_drueben")
		game.abandoned = true
		root.remove_child(game)
		game.queue_free()
		for _i in range(3):
			await process_frame
	print("[PassageCapture] %d pictures, %d problems %s" % [saved, failures.size(), str(failures)])
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)
