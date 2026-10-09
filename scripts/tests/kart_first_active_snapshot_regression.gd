extends SceneTree
## Controlled natural-delta scene test. No elapsed/countdown/checkpoint state is assigned.

const STEP: float = 1.0 / 60.0
const SESSION: String = "user://kart_sonnenhafen_session.cfg"
var game
var checks: Array[Dictionary] = []
var output: String
var sequence: int = 0
var startup_environment: Environment = null


func _initialize() -> void:
	startup_environment = root.world_3d.fallback_environment
	call_deferred("_run")


func _check(ok: bool, label: String, expected: Variant, actual: Variant) -> void:
	checks.append({"name": label, "passed": ok, "expected": expected, "actual": actual})
	if not ok:
		print("[FirstActiveSnapshot] FAIL: " + label)


func _saved(tag: String) -> Dictionary:
	var config := ConfigFile.new()
	assert(config.load(SESSION) == OK)
	sequence += 1
	var filename: String = "%03d-%s-session.cfg" % [sequence, tag]
	assert(config.save(output.path_join(filename)) == OK)
	return {"snapshot": filename, "id": config.get_value("race", "result_id"),
		"elapsed": config.get_value("race", "elapsed"), "countdown": config.get_value("race", "countdown"),
		"checkpoint": config.get_value("race", "checkpoint_index"),
		"finished": config.get_value("race", "finished"),
		"completed": config.get_value("race", "completed_race"),
		"payload": config.get_value("race", "result_payload"),
		"laps": config.get_value("race", "lap_times"),
		"lap_start": config.get_value("race", "lap_started_at")}


func _setup(mode: String = "race", motion: bool = true) -> void:
	DirAccess.remove_absolute(SESSION)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	root.get_node("HostBridge")._options = {"soundEnabled": false, "reduceAnimations": motion}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await process_frame
	game._start_selected_race({"mode": mode, "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "gemuetlich"})


func _close() -> void:
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	game = null
	await process_frame
	await process_frame


func _advance_until_elapsed(target: float) -> void:
	var frames: int = 0
	while game.elapsed + 0.0000001 < target:
		game._physics_process(STEP)
		frames += 1
		assert(frames < 2400, "Natural-delta test cannot remain indefinitely in preview/countdown")


func _reopen() -> void:
	await _close()
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await process_frame
	game._resume_saved_race()


func _cadence(mode: String) -> void:
	await _setup(mode)
	var initial: Dictionary = _saved(mode + "-initial")
	_check(initial.elapsed == 0.0 and initial.countdown == 3.5,
		mode + ": initial save is the real untouched countdown", [0.0, 3.5], [initial.elapsed, initial.countdown])
	_advance_until_elapsed(0.8)
	var early: Dictionary = _saved(mode + "-subsecond")
	_check(early.elapsed == 0.0 and early.countdown == 3.5,
		mode + ": no automatic save before one active second", [0.0, 3.5], [early.elapsed, early.countdown])
	_advance_until_elapsed(1.0 + STEP)
	var first: Dictionary = _saved(mode + "-first-active")
	_check(first.elapsed >= 1.0 and first.elapsed <= 1.0 + STEP + 0.000001 and first.countdown == 0.0,
		mode + ": first active snapshot records a real racing second", "elapsed in [1,1+step], countdown0", first)
	_check(first.id == game.result_id and not first.finished and not first.completed and first.payload.is_empty(),
		mode + ": early snapshot preserves unfinished identity without a result", "same unfinished ID, empty payload", first)
	var first_elapsed: float = float(first.elapsed)
	_advance_until_elapsed(5.9)
	var before_periodic: Dictionary = _saved(mode + "-before-periodic")
	_check(before_periodic.elapsed == first_elapsed,
		mode + ": no duplicate autosave within following five active seconds", first_elapsed, before_periodic.elapsed)
	_advance_until_elapsed(6.0 + STEP * 2.0)
	var periodic: Dictionary = _saved(mode + "-periodic")
	_check(periodic.elapsed >= 6.0 and periodic.elapsed <= 6.0 + STEP * 2.0 + 0.000001,
		mode + ": subsequent autosave retains five-second cadence", "elapsed in [6,6+2step]", periodic.elapsed)
	await _close()


func _pause_restore() -> void:
	await _setup()
	_advance_until_elapsed(0.8)
	game._pause()
	var paused: Dictionary = _saved("paused-subsecond")
	var id: String = game.result_id
	var elapsed: float = game.elapsed
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SESSION)
	for frame in range(120):
		game._physics_process(STEP)
	_check(game.elapsed == elapsed and FileAccess.get_file_as_bytes(SESSION) == saved_bytes,
		"pause freezes active elapsed and automatic snapshot writes", "same elapsed/file bytes", game.elapsed)
	game._rebuild_graphics()
	_check(game.paused and game.elapsed == elapsed and game.result_id == id,
		"graphics rebuild preserves the paused subsecond race", [true, elapsed, id], [game.paused, game.elapsed, game.result_id])
	await _reopen()
	_check(game.paused and absf(game.elapsed - 0.8) <= STEP and game.result_id == id,
		"reopened subsecond save retains its own active elapsed and ID", [true, 0.8, id], [game.paused, game.elapsed, game.result_id])
	game._resume()
	_advance_until_elapsed(1.0 + STEP)
	var first: Dictionary = _saved("restored-subsecond-first-active")
	_check(first.elapsed >= 1.0 and first.elapsed <= 1.0 + STEP + 0.000001,
		"reopened0.8 save gets first snapshot at real elapsed1", "elapsed in [1,1+step]", first.elapsed)
	game._pause()
	var settled: Dictionary = _saved("paused-after-first-active")
	await _reopen()
	game._resume()
	var resume_elapsed: float = game.elapsed
	_advance_until_elapsed(resume_elapsed + 4.9)
	var no_duplicate: Dictionary = _saved("restored-after-first-no-duplicate")
	_check(no_duplicate.elapsed == settled.elapsed,
		"reopened>=1 save does not duplicate the early snapshot", settled.elapsed, no_duplicate.elapsed)
	_advance_until_elapsed(resume_elapsed + 5.0 + STEP)
	var periodic: Dictionary = _saved("restored-after-first-periodic")
	_check(periodic.elapsed >= resume_elapsed + 5.0,
		"reopened>=1 save returns to five active seconds", ">=resume elapsed+5", periodic.elapsed)
	await _close()


func _preview_restart() -> void:
	await _setup("race", false)
	var initial: Dictionary = _saved("preview-initial")
	for frame in range(120):
		game._physics_process(STEP)
	var preview: Dictionary = _saved("preview-after-two-seconds")
	_check(game.preview_left > 0.0 and game.elapsed == 0.0 and preview.elapsed == initial.elapsed,
		"preview cannot advance or autosave active race time", "preview>0, active elapsed0", preview)
	game._pause()
	var countdown: float = game.countdown
	for frame in range(120):
		game._physics_process(STEP)
	_check(game.countdown == countdown and game.elapsed == 0.0,
		"paused countdown cannot trigger early active snapshot", [countdown, 0.0], [game.countdown, game.elapsed])
	game._resume()
	_advance_until_elapsed(4.8)
	var old_id: String = game.result_id
	game._restart_setup()
	var initial_restart: Dictionary = _saved("restart-initial")
	_check(game.result_id != old_id and initial_restart.elapsed == 0.0 and game.save_timer == 0.0,
		"new race resets snapshot timer and creates a new identity", "new ID, elapsed0, timer0", initial_restart)
	_advance_until_elapsed(0.8)
	var before_first: Dictionary = _saved("restart-subsecond")
	_check(before_first.elapsed == 0.0,
		"prior race timer cannot save a new race before one active second", 0.0, before_first.elapsed)
	_advance_until_elapsed(1.0 + STEP)
	var first: Dictionary = _saved("restart-first-active")
	_check(first.elapsed >= 1.0 and first.elapsed <= 1.0 + STEP + 0.000001,
		"new race receives its own first active snapshot", "elapsed in [1,1+step]", first.elapsed)
	await _close()


func _run() -> void:
	output = OS.get_environment("LUMO_QA_DIR")
	assert(not output.is_empty(), "Controlled evidence must have an explicit outside output")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	for mode in ["race", "cup", "time_trial", "training", "arena"]:
		await _cadence(mode)
	await _pause_restore()
	await _preview_restart()
	var failures: int = 0
	for row in checks:
		if not row.passed:
			failures += 1
	if checks.size() != 41:
		failures += 1
		print("[FirstActiveSnapshot] FAIL: all41 required controls must execute")
	var evidence: Dictionary = {"status": "PASS" if failures == 0 else "FAIL", "checks": checks,
		"check_count": checks.size(), "failures": failures,
		"engine": Engine.get_version_info(),
		"scope": "Controlled natural-delta scene calls; no elapsed/countdown/gate injection, no Android/FPS claim"}
	var file := FileAccess.open(output.path_join("first-active-snapshot-evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("[FirstActiveSnapshot] %s: %d checks / %d failures" % [evidence.status, checks.size(), failures])
	if startup_environment != null:
		startup_environment.sky = null
	startup_environment = null
	for frame in range(8):
		await process_frame
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
