extends "res://scripts/tests/kart_first_active_snapshot_regression.gd"
## Scoped filesystem fault and callback recorder; the actual Core atomic save runs unchanged.

func _setup_recording() -> void:
	DirAccess.remove_absolute(SESSION)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	root.get_node("HostBridge")._options = {"soundEnabled": false, "reduceAnimations": true}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	game.set_script(load("res://scripts/tests/kart_first_active_snapshot_recording_fixture.gd"))
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "gemuetlich"})


func _run() -> void:
	output = OS.get_environment("LUMO_QA_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	await _setup_recording()
	var initial: Dictionary = _saved("fault-initial")
	_check(game.save_attempts.size() == 1 and game.save_attempts[0].elapsed == 0.0,
		"instrumented fixture delegates the actual initial save", "one initial actual write", game.save_attempts.duplicate(true))
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SESSION)
	assert(DirAccess.make_dir_absolute(SESSION + ".tmp") == OK)
	_advance_until_elapsed(1.0 + STEP)
	var attempts: Array = game.save_attempts.duplicate(true)
	_check(attempts.size() == 2 and attempts[1].elapsed >= 1.0 and attempts[1].elapsed <= 1.0 + STEP,
		"first actual active write is attempted at elapsed1 despite I/O fault", "initial+first active attempt", attempts)
	_check(FileAccess.get_file_as_bytes(SESSION) == old_bytes,
		"failed temp write preserves the original durable countdown snapshot", "unchanged complete original bytes", _saved("fault-old-save"))
	_advance_until_elapsed(5.9)
	var failed_save: Dictionary = _saved("fault-before-retry")
	_check(failed_save.elapsed == 0.0 and failed_save.countdown == 3.5,
		"failed active write cannot publish false readiness", [0.0, 3.5], [failed_save.elapsed, failed_save.countdown])
	_check(game.save_attempts.size() == 2,
		"failed first attempt retains the following five-second retry interval", "two total attempts beforeelapsed6", game.save_attempts.duplicate(true))
	assert(DirAccess.remove_absolute(SESSION + ".tmp") == OK)
	_advance_until_elapsed(6.0 + STEP * 2.0)
	var recovered: Dictionary = _saved("fault-recovered")
	_check(recovered.elapsed >= 6.0 and recovered.elapsed <= 6.0 + STEP * 2.0 + 0.000001
		and recovered.countdown == 0.0,
		"following periodic write recovers actual active time after storage returns", "elapsed6,countdown0", recovered)
	_check(recovered.id == initial.id and not recovered.finished and not recovered.completed
		and recovered.payload.is_empty(),
		"write recovery preserves identity and cannot create a result", "same unfinished ID,empty payload", recovered)
	var final_attempts: Array = game.save_attempts.duplicate(true)
	_check(final_attempts.size() == 3 and final_attempts[2].elapsed - final_attempts[1].elapsed >= 5.0,
		"recovered write occurs five real active seconds after the failed attempt", "three attempts,active interval>=5", final_attempts)
	await _close()
	var failed: int = 0
	for row in checks:
		if not row.passed:
			failed += 1
	if checks.size() != 8:
		failed += 1
	var evidence: Dictionary = {"status": "PASS" if failed == 0 else "FAIL", "checks": checks,
		"check_count": checks.size(), "failures": failed, "save_attempts": final_attempts,
		"scope": "Controlled outside userdata .tmp directory fault; recording subclass delegates actual atomic save; no game elapsed/countdown/gate injection, no Android claim"}
	var file := FileAccess.open(output.path_join("actual-write-failure-evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	if startup_environment != null:
		startup_environment.sky = null
	startup_environment = null
	for frame in range(8):
		await process_frame
	await create_timer(0.1).timeout
	print("[FirstActiveWriteFailure] %s: %d checks / %d failures" % [evidence.status, checks.size(), failed])
	quit(0 if failed == 0 else 1)
