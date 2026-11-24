extends SceneTree
const BOT = preload("res://scripts/tests/helpers/sky_post_bot.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var router = root.get_node("SceneRouter")
	router.launch_options = {"grade": 2, "childKey": "dbg", "skypostProfile": "low"}
	var game = load("res://scenes/games/sky_post.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.build_now()
	game.mode = "race"
	game.stage = "extrem"
	game.start_flight(false)
	var bot = BOT.new(game)
	game.autopilot = bot.stick
	var last_passed: int = 0
	var t: float = 0.0
	var last_t: float = 0.0
	var bumps: int = 0
	game.moment.connect(func(kind, d): if kind in ["bump", "cushion", "wall"]: print("  event ", kind, " at ", game.flight.pos))
	for i in range(int(300 * 60)):
		game.advance(1.0 / 60.0)
		t += 1.0 / 60.0
		if game.race.passed != last_passed:
			print("gate %d (#%d) after %.1f s, speed %.1f" % [game.race.next_gate() - 1, game.race.passed, t - last_t, game.flight.speed])
			last_passed = game.race.passed
			last_t = t
		if game.phase == game.Phase.FINISHED:
			break
	quit()
