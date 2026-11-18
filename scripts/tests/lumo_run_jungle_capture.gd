extends SceneTree
## Real-renderer pictures and draw-call measurements of the Dschungelherz
## adventure path, played by the scripted jungle player. Needs a display:
##
##   LUMO_CAPTURE_DIR=/some/dir xvfb-run -a -s '-screen 0 2560x2560x24' \
##     godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_run_jungle_capture.gd
##
## LUMO_RUN_SIZE=1600x720 limits it to one window size; LUMO_SEED picks the
## player's ways (default 4: upper ways, niches and the treasure hall).
## LUMO_PROFILE=low|medium|high picks the quality profile (not saved).

const BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const SIZES: Array[Vector2i] = [Vector2i(1600, 720), Vector2i(720, 1600)]
const STEP: float = 1.0 / 60.0

var capture_dir: String = ""
var saved: Array[String] = []
var failures: Array[String] = []
var game
var bot
var tag: String = ""
var measures: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.get_size() != root.size:
		failures.append(name + " has no pixels")
		return
	var path: String = capture_dir.path_join("%s_%s.jpg" % [tag, name])
	if frame.save_jpg(path, 0.86) != OK:
		failures.append(name + " not saved")
		return
	saved.append(path)
	print("[JungleCapture] saved " + path)


## Plays (with rendering) until `done` is true, answering learning stops if `answer`.
func _play_until(done: Callable, limit: int = 60 * 400, answer: bool = true, render_every: int = 0) -> bool:
	for step in range(limit):
		if done.call():
			return true
		if game.phase == game.Phase.FINISHED:
			return done.call()
		if game.question_open:
			if not answer:
				return done.call()
			game.answer(str(game.active_question.answer))
		bot.drive(game, STEP)
		game.advance(STEP)
		if render_every > 0 and step % render_every == 0:
			await process_frame
	return done.call()


## A few live frames so particles, animals and the camera settle, then a picture.
func _live_shot(name: String, frames: int = 20) -> void:
	for _i in range(frames):
		if game.question_open or game.phase == game.Phase.FINISHED:
			break
		bot.drive(game, STEP)
		game.advance(STEP)
		await process_frame
	await _capture(name)


func _measure(label: String) -> void:
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	measures.append(
		{
			"label": label,
			"s": game.player.s,
			"section": game.world.section_at(maxf(0.0, game.player.s)),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		}
	)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[JungleCapture] Real display required")
		quit(1)
		return
	capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
	if capture_dir.is_empty() or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		push_error("[JungleCapture] LUMO_CAPTURE_DIR must be writable")
		quit(1)
		return
	var only: String = OS.get_environment("LUMO_RUN_SIZE")
	var seed: int = int(OS.get_environment("LUMO_SEED")) if not OS.get_environment("LUMO_SEED").is_empty() else 4
	var profile: String = OS.get_environment("LUMO_PROFILE")
	if profile in ["low", "medium", "high"]:
		root.get_node("SettingsStore")._profile = profile
		var manager: Node = root.get_node("PerformanceManager")
		manager.current_profile = ["low", "medium", "high"].find(profile)
		print("[JungleCapture] profile " + profile)
	var bridge: Node = root.get_node("HostBridge")
	bridge._options["displayDensity"] = 2.0
	var index: int = COURSES.index_of("dschungelherz")
	for size in SIZES:
		tag = "%dx%d" % [size.x, size.y]
		if not only.is_empty() and only != tag:
			continue
		root.size = size
		root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik", "childKey": "capture-" + tag}
		game = load("res://scenes/games/lumo_run.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		for _i in range(10):
			await process_frame
		await _capture("00_start_menu")
		game.set_process(false)
		var started: int = Time.get_ticks_msec()
		game.start_course(index, false)
		print("[JungleCapture] %s level built in %d ms" % [tag, Time.get_ticks_msec() - started])
		game.countdown_left = 0.0
		bot = BOT.new(seed)
		var player = game.player
		var plan = game.plan
		await _play_until(func() -> bool: return player.s > 14.0)
		await _live_shot("01_intro_jump_coach", 6)
		await _play_until(func() -> bool: return player.s > plan.coaches[2].s0 + 4.0)
		await _live_shot("02_intro_stomp", 4)
		var next_measure: float = 0.0
		var shots: Dictionary = {}
		for section in plan.sections:
			var span: float = float(section.s1) - float(section.s0)
			shots[float(section.s0) + span * 0.3] = "%02d_section%d_%s_a" % [10 + int(section.index) * 2, int(section.index), str(section.name)]
			shots[float(section.s0) + span * 0.72] = "%02d_section%d_%s_b" % [11 + int(section.index) * 2, int(section.index), str(section.name)]
		var specials: Dictionary = {
			"barrel": false, "vine": false, "zip": false, "chase": false, "gate": false, "bonus": false, "cart": false,
		}
		var guard: int = 0
		while game.phase != game.Phase.FINISHED and guard < 60 * 600:
			guard += 1
			if game.question_open:
				if not specials.gate:
					specials.gate = true
					await _capture("30_puzzle_gate_question")
				game.answer(str(game.active_question.answer))
				if not specials.has("gate_open"):
					specials["gate_open"] = true
					for _i in range(50):
						bot.drive(game, STEP)
						game.advance(STEP)
						await process_frame
						if player.s > float(plan.checkpoints[game.track.checkpoint].s) + 1.5:
							break
					await _capture("31_puzzle_gate_open")
				continue
			bot.drive(game, STEP)
			game.advance(STEP)
			if player.s >= next_measure and player.s >= 0.0 and size.x > size.y:
				next_measure = player.s + 25.0
				await _measure("path")
			for at in shots.keys():
				if player.s >= float(at) and player.s >= 0.0 and player.grounded:
					await _live_shot(str(shots[at]), 10)
					shots.erase(at)
			if player.is_riding():
				var kind: String = str(player.ride.kind)
				if kind == "barrel" and player.ride_fired and player.ride_t > 0.25 and not specials.barrel:
					specials.barrel = true
					await _capture("32_barrel_flight")
				elif kind == "vine" and player.ride_t > 0.55 and not specials.vine:
					specials.vine = true
					await _capture("33_vine_swing")
				elif kind == "zip" and player.ride_t > 1.0 and not specials.zip:
					specials.zip = true
					await _capture("34_zip_line")
			if game.track.chase_active and player.s > float(plan.chase.s0) + 40.0 and not specials.chase:
				specials.chase = true
				await _capture("35_chase_stone_ball")
			if player.s < 0.0 and player.s > float(plan.bonus.s0) + 22.0 and not specials.bonus:
				specials.bonus = true
				await _live_shot("36_treasure_hall", 8)
				await _measure("treasure hall")
			if player.in_cart and player.s > float(plan.cart.s0) + 40.0 and not specials.cart:
				specials.cart = true
				await _live_shot("37_mine_cart", 6)
		for _i in range(150):
			game.advance(STEP)
		await _capture("40_result")
		for key in specials:
			if not bool(specials[key]):
				failures.append("%s: no %s picture" % [tag, key])
		game.abandoned = true
		current_scene = null
		root.remove_child(game)
		game.queue_free()
		for _i in range(3):
			await process_frame
	_report()
	quit(0 if failures.is_empty() else 1)


func _report() -> void:
	if measures.is_empty():
		return
	var by_section: Dictionary = {}
	var worst: Dictionary = {}
	for entry in measures:
		var key: int = int(entry.section) if str(entry.label) == "path" else 99
		if not by_section.has(key):
			by_section[key] = []
		by_section[key].append(entry)
		if worst.is_empty() or float(entry.draws) > float(worst.draws):
			worst = entry
	for key in by_section:
		var list: Array = by_section[key]
		var draws: Array = list.map(func(e: Dictionary) -> float: return float(e.draws))
		var prims: Array = list.map(func(e: Dictionary) -> float: return float(e.primitives))
		print(
			"[JungleCapture] measure section=%s samples=%d draws avg=%.0f max=%.0f primitives avg=%.0f max=%.0f"
			% [str(key), list.size(), _avg(draws), draws.max(), _avg(prims), prims.max()]
		)
	print("[JungleCapture] worst draw calls %.0f at s=%.0f" % [float(worst.draws), float(worst.s)])
	print("[JungleCapture] %d pictures, %d failures: %s" % [saved.size(), failures.size(), " | ".join(failures)])


func _avg(values: Array) -> float:
	var total: float = 0.0
	for value in values:
		total += float(value)
	return total / maxf(1.0, float(values.size()))
