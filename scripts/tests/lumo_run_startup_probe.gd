extends SceneTree
## Start of Lumo Lauf the way the app does it: the boot scene with
## `--scene=run`, the course menu, the tap on Dschungelherz, the loading card,
## the countdown and a few seconds of a real run with the scripted player.
## Meant for a real renderer (xvfb + gl_compatibility) with the quality profile
## given on the command line; prints the longest frames and the phases it saw.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_run_startup_probe.gd -- --scene=run --profile=high
##
## Options after `--`: --profile=low|medium|high, --run-seconds=8, --break-art=1
## (forces the jungle art to fail, to see the fallback in a real start).

const BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")

var options: Dictionary = {}
var frame_log: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	var profile: String = str(options.get("profile", "medium"))
	var run_seconds: float = float(options.get("run-seconds", "8"))
	var settings: Node = root.get_node("SettingsStore")
	settings.set_profile(profile)
	var perf: Node = root.get_node("PerformanceManager")
	perf.set_profile({"low": 0, "medium": 1, "high": 2}.get(profile, 1), false)
	if str(options.get("break-art", "")) == "1":
		var scenery = load("res://scripts/games/run/jungle/run_jungle_scenery.gd")
		scenery.force_failure = "any"
	print(
		(
			"[RunStartProbe] adapter=%s renderer=%s profile=%s"
			% [
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_current_rendering_method(),
				profile
			]
		)
	)
	var started: int = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/app/boot.tscn")
	var game: Node = null
	var last: int = Time.get_ticks_usec()
	var frames: int = 0
	while game == null and Time.get_ticks_msec() - started < 60000:
		await process_frame
		last = _frame(last, "boot")
		frames += 1
		var scene: Node = current_scene
		if scene != null and scene.has_method("start_course"):
			game = scene
	if game == null:
		print("[RunStartProbe] FAIL: run scene never opened")
		quit(1)
		return
	print(
		"[RunStartProbe] menu after %d ms (%d frames)" % [Time.get_ticks_msec() - started, frames]
	)
	for i in range(20):
		await process_frame
		last = _frame(last, "menu")
	var tapped: int = Time.get_ticks_msec()
	game._on_course_chosen(COURSES.index_of("dschungelherz"), false)
	var phases: Array[String] = []
	var bot = BOT.new(1)
	var running_since: int = -1
	while Time.get_ticks_msec() - tapped < 400000:
		await process_frame
		var name: String = str(game.Phase.keys()[game.phase])
		last = _frame(last, name)
		if game.phase == game.Phase.COUNTDOWN and str(options.get("short-countdown", "1")) == "1":
			# The container renders in software (seconds per frame): skip the 3 s count.
			game.countdown_left = minf(game.countdown_left, 0.05)
		if phases.is_empty() or phases[-1] != name:
			phases.append(name)
			print("[RunStartProbe] phase %s at +%d ms" % [name, Time.get_ticks_msec() - tapped])
		if game.phase == game.Phase.RUNNING:
			if running_since < 0:
				running_since = Time.get_ticks_msec()
			if game.question_open:
				game.answer(str(game.active_question.answer))
			else:
				bot.drive(game, get_process_delta_time_safe())
			if Time.get_ticks_msec() - running_since > int(run_seconds * 1000.0):
				break
	frame_log.sort_custom(func(a, b): return a[0] > b[0])
	var worst: Array = frame_log.slice(0, 6).map(
		func(entry): return "%s:%d ms" % [entry[1], entry[0]]
	)
	var ok: bool = running_since >= 0 and game.player.s > game.plan.start_s + 2.0
	print(
		(
			"[RunStartProbe] phases=%s build=%d ms worst_frames=%s"
			% [str(phases), int(game.load_ms), str(worst)]
		)
	)
	print("[RunStartProbe] build steps (ms): %s" % str(game.world.scenery.step_ms))
	print(
		(
			"[RunStartProbe] art_fallback=%s s=%.1f speed=%.1f"
			% [str(game.world.get("art_fallback")), float(game.player.s), float(game.player.speed)]
		)
	)
	print("[RunStartProbe] %s profile=%s" % ["PASS" if ok else "FAIL", profile])
	game.abandoned = true
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	quit(0 if ok else 1)


func get_process_delta_time_safe() -> float:
	return clampf(float(frame_log[-1][0]) / 1000.0, 1.0 / 120.0, 0.1)


func _frame(last: int, label: String) -> int:
	var now: int = Time.get_ticks_usec()
	frame_log.append([int((now - last) / 1000), label])
	return now
