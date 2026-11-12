extends "res://scripts/tests/kart_action_course_regression.gd"
## Headless physics companion to the native ActionCourse gate. It reuses every
## production-driving check; the original renderer requirement stays unchanged.


func _run() -> void:
	_check_plans()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _check_pad_and_slalom()
	await _check_kicker_and_dive()
	await _check_sonnenhafen_long_flight()
	await _check_open_edge()
	game.abandoned = true
	game.queue_free()
	for frame in range(6):
		await process_frame
	await create_timer(1.3).timeout
	if completed_checks != 5:
		print("[KartActionLogic] FAIL: %d of 5 checks completed" % completed_checks)
		quit(1)
		return
	print("[KartActionLogic] PASS: five production-physics checks; native renderer gate remains separate")
	quit(0)
