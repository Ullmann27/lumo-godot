extends SceneTree
## A failing jungle look must never stop Lumo Lauf from starting (headless).
##
##   godot --headless --path . --script res://scripts/tests/lumo_run_art_fallback_regression.gd
##
## Checks: the global shader value `jungle_focus` is declared in the project and
## the jungle shaders compile without the runtime registration; a shader that
## does not compile is recognised; the start through the course menu builds the
## path over several frames (no long freeze); and when a piece of the jungle
## fails on purpose - right at the start or half-way - the game logs it, falls
## back to the plain look and the run starts and plays on.

const BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const SCENERY = preload("res://scripts/games/run/jungle/run_jungle_scenery.gd")
const SHADERS = preload("res://scripts/games/run/jungle/run_jungle_shaders.gd")
const STEP: float = 1.0 / 60.0
## Longest frame allowed while the course is loading (container, headless).
const LONGEST_FRAME_MS: int = 2500

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[RunArtFallback] ok: " + label)
	else:
		failures.append(label)
		print("[RunArtFallback] FAILED CHECK: " + label)


func _run() -> void:
	_check(
		ProjectSettings.has_setting("shader_globals/jungle_focus"),
		"jungle_focus is declared under [shader_globals] in project.godot"
	)
	var setting: Dictionary = ProjectSettings.get_setting("shader_globals/jungle_focus", {})
	_check(str(setting.get("type", "")) == "vec3", "jungle_focus is a vec3")
	# Compile the two shaders that read the global value directly, without
	# going through run_jungle_art.gd (which would register it at runtime).
	var direct: Dictionary = {"LEAF": SHADERS.LEAF, "SURFACE": SHADERS.SURFACE}
	for key in direct:
		var shader := Shader.new()
		shader.code = direct[key]
		_check(
			not shader.get_shader_uniform_list().is_empty(),
			"%s shader compiles with the project's global value" % key
		)
	if "--with-broken-shader" in OS.get_cmdline_user_args():
		# Optional (prints a SHADER ERROR on purpose): the check used by the scenery
		# really recognises a shader that does not compile.
		var broken := Shader.new()
		broken.code = (
			"shader_type spatial;\nuniform float a = 1.0;\n"
			+ "void fragment() { ALBEDO = vec3(not_declared); }\n"
		)
		_check(
			broken.get_shader_uniform_list().is_empty(),
			"a shader that does not compile is recognised (no uniforms)"
		)

	var full: Dictionary = await _start("", true)
	_check(
		str(full.fallback).is_empty(),
		"normal start keeps the full jungle (fallback '%s')" % str(full.fallback)
	)
	_check(int(full.placed) > 4000, "normal start: dense jungle (%d instances)" % int(full.placed))
	_check(
		int(full.frames) >= 4,
		"the path is built over several frames (%d frames while loading)" % int(full.frames)
	)
	_check(
		int(full.longest) <= LONGEST_FRAME_MS,
		(
			"no long freeze while loading (longest frame %d ms, limit %d ms)"
			% [int(full.longest), LONGEST_FRAME_MS]
		)
	)
	_check(
		bool(full.running) and float(full.ran) > 30.0,
		"normal start: the run plays (%.0f m)" % float(full.ran)
	)

	for forced in ["any", "_vegetation"]:
		SCENERY.force_failure = forced
		var result: Dictionary = await _start(forced, true)
		SCENERY.force_failure = ""
		var expected: String = "_check_shaders" if forced == "any" else forced
		_check(
			str(result.fallback) == expected,
			"failure in %s: fallback noticed (%s)" % [expected, str(result.fallback)]
		)
		_check(
			bool(result.simple) and int(result.decks) > 10,
			"failure in %s: plain look with path decks (%d decks)" % [expected, int(result.decks)]
		)
		_check(bool(result.sky), "failure in %s: sky and sun are there" % expected)
		_check(
			bool(result.running) and float(result.ran) > 30.0,
			"failure in %s: the run starts and plays on (%.0f m)" % [expected, float(result.ran)]
		)
	# Direct start (as the tests and the auto start use it) also falls back.
	SCENERY.force_failure = "_decor"
	var plain: Dictionary = await _start("_decor", false)
	SCENERY.force_failure = ""
	_check(
		str(plain.fallback) == "_decor" and bool(plain.running),
		"direct start: fallback and run (%s)" % str(plain.fallback)
	)

	print("[RunArtFallback] %s: %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	for failure in failures:
		print("[RunArtFallback] failed: " + failure)
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)


func _start(label: String, through_menu: bool) -> Dictionary:
	root.get_node("SceneRouter").launch_options = {
		"grade": 2, "subject": "Mathematik", "childKey": "art-fallback"
	}
	var game = load("res://scenes/games/lumo_run.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var index: int = COURSES.index_of("dschungelherz")
	var frames: int = 0
	var longest: int = 0
	if through_menu:
		game._on_course_chosen(index, false)
		var last: int = Time.get_ticks_msec()
		while game.phase == game.Phase.LOADING and frames < 2000:
			await process_frame
			var now: int = Time.get_ticks_msec()
			longest = maxi(longest, now - last)
			last = now
			frames += 1
	else:
		game.start_course(index, false)
	game.set_process(false)
	game.countdown_left = 0.0
	var bot = BOT.new(3)
	var from: float = float(game.player.s)
	for i in range(60 * 8):
		if game.question_open:
			game.answer(str(game.active_question.answer))
		else:
			bot.drive(game, STEP)
		game.advance(STEP)
	var scenery = game.world.scenery
	var decks: int = 0
	var sky: bool = false
	for child in scenery.get_children():
		if str(child.name).begins_with("Deck_"):
			decks += 1
		if child is WorldEnvironment:
			sky = true
	var result: Dictionary = {
		"fallback": game.world.art_fallback,
		"simple": scenery.simple,
		"placed": scenery.placed,
		"decks": decks,
		"sky": sky and scenery.find_children("*", "DirectionalLight3D", false, false).size() > 0,
		"slowest": _slowest(scenery.step_ms),
		"running": game.phase == game.Phase.RUNNING,
		"ran": float(game.player.s) - from,
		"frames": frames,
		"longest": longest,
	}
	print(
		(
			"[RunArtFallback] start %s menu=%s: %s build=%d ms"
			% [
				label if not label.is_empty() else "normal",
				str(through_menu),
				str(result),
				int(game.load_ms)
			]
		)
	)
	game.abandoned = true
	root.remove_child(game)
	game.queue_free()
	await process_frame
	await process_frame
	return result


func _slowest(times: Dictionary) -> String:
	var best: String = ""
	for name in times:
		if best.is_empty() or int(times[name]) > int(times[best]):
			best = name
	return "%s %d ms" % [best, int(times.get(best, 0))]
