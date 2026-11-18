extends SceneTree
## Quick probe of the Dschungelherz adventure path: plays it with the scripted
## jungle player for the seeds in LUMO_SEEDS (default "1") and prints what
## happened per section. A development tool next to the full regression.
##
##   godot --headless --script res://scripts/tests/lumo_run_jungle_probe.gd

const BOT = preload("res://scripts/tests/helpers/lumo_jungle_bot.gd")
const COURSES = preload("res://scripts/games/run/run_courses.gd")
const STEP: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seeds: PackedStringArray = OS.get_environment("LUMO_SEEDS").split(",", false)
	if seeds.is_empty():
		seeds = PackedStringArray(["1"])
	var index: int = COURSES.index_of("dschungelherz")
	for seed_text in seeds:
		root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik", "childKey": "probe"}
		var game = load("res://scenes/games/lumo_run.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_process(false)
		var started: int = Time.get_ticks_msec()
		game.start_course(index, false)
		var built: int = Time.get_ticks_msec() - started
		game.countdown_left = 0.0
		var bot = BOT.new(int(seed_text))
		var steps: int = 0
		var rescues: Dictionary = {}
		var last_rescues: int = 0
		var furthest: float = 0.0
		var stuck: int = 0
		var wall: int = Time.get_ticks_msec()
		while game.phase != game.Phase.FINISHED and steps < 60 * 900:
			if game.question_open:
				game.answer(str(game.active_question.answer))
			else:
				bot.drive(game, STEP)
			game.advance(STEP)
			steps += 1
			if OS.get_environment("LUMO_TRACE") == "1" and steps % 30 == 0:
				print("[JungleTrace] t=%.1f s=%.1f lat=%.2f h=%.2f v=%.1f g=%s ride=%s" % [float(steps) * STEP, game.player.s, game.player.lat, game.player.h, game.player.speed, str(game.player.grounded), str(game.player.ride.get("kind", ""))])
			if game.track.rescues != last_rescues:
				last_rescues = game.track.rescues
				var key: String = "%d@%.0f" % [roundi(game.player.s), game.run_clock]
				rescues[key] = int(rescues.get(key, 0)) + 1
			if game.player.s > furthest + 0.5:
				furthest = game.player.s
				stuck = 0
			else:
				stuck += 1
			if stuck > 60 * 40:
				print("[JungleProbe] seed %s STUCK at s=%.1f lat=%.2f h=%.2f" % [seed_text, game.player.s, game.player.lat, game.player.h])
				break
		print(
			"[JungleProbe] seed %s: finished=%s game=%.0f s wall=%d ms build=%d ms stars=%d/%d letters=%d bonus=%s rescues=%d stomps=%d jumps=%d brakes=%d routes=%s"
			% [
				seed_text, str(game.phase == game.Phase.FINISHED), float(steps) * STEP, Time.get_ticks_msec() - wall, built,
				game.track.kept, game.plan.star_total, game.track.letter_count(), str(game.track.bonus_found),
				game.track.rescues, game.track.stomps, bot.jumps, bot.brakes, str(bot.routes),
			]
		)
		for section in game.plan.sections:
			print("[JungleProbe] section %s %.0f-%.0f" % [section.name, section.s0, section.s1]) if seed_text == seeds[0] else null
		print("[JungleProbe] chase %s" % str(game.plan.chase)) if seed_text == seeds[0] else null
		print("[JungleProbe] rescue spots (s: count): %s letters=%d" % [str(rescues), game.track.letters])
		for letter in game.plan.letters:
			print("[JungleProbe] letter %s at s=%.1f lat=%.1f h=%.1f" % [letter.char, letter.s, letter.lat, letter.h]) if seed_text == seeds[0] else null
		game.abandoned = true
		root.remove_child(game)
		game.queue_free()
		await process_frame
	quit(0)
