extends "res://scripts/tests/kart_sonnenhafen_stunt_regression.gd"
## Headless physics companion; no claim of native visual acceptance.


func _run() -> void:
	await _check_layout()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	await _check_full_loop()
	await _check_too_slow()
	await _check_stunt_jump()
	await _check_precision_speeds()
	game.abandoned = true
	game.queue_free()
	for frame in range(6):
		await process_frame
	await create_timer(1.3).timeout
	if completed_checks != 5:
		print("[KartStuntLogic] FAIL: %d of 5 checks completed" % completed_checks)
		quit(1)
		return
	print("[KartStuntLogic] PASS: five production-physics checks; native renderer gate remains separate")
	quit(0)
