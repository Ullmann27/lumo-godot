extends SceneTree
## Normal engine physics and actual public GUI touches. No manual step or gameplay assignment.

const SESSION: String = "user://kart_sonnenhafen_session.cfg"
var game
var observations: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var output: String
var started: int
var startup_environment: Environment = null


func _initialize() -> void:
	startup_environment = root.world_3d.fallback_environment
	call_deferred("_run")


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _check(ok: bool, label: String, expected: Variant, actual: Variant) -> void:
	checks.append({"name": label, "passed": ok, "expected": expected, "actual": actual})


func _touch(control: Control) -> void:
	assert(control.is_visible_in_tree())
	assert(root.get_visible_rect().encloses(control.get_global_rect()), "Public touch target must fit the current surface")
	var position: Vector2 = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _read() -> Dictionary:
	var config := ConfigFile.new()
	assert(config.load(SESSION) == OK)
	return {"result_id": config.get_value("race", "result_id"),
		"elapsed": config.get_value("race", "elapsed"), "countdown": config.get_value("race", "countdown"),
		"checkpoint_index": config.get_value("race", "checkpoint_index"),
		"finished": config.get_value("race", "finished"),
		"completed_race": config.get_value("race", "completed_race"),
		"result_payload": config.get_value("race", "result_payload"),
		"actual_active_elapsed": game.elapsed, "actual_countdown": game.countdown,
		"wall_seconds": float(Time.get_ticks_usec() - started) / 1000000.0,
		"source_sha256": FileAccess.get_sha256("res://scripts/games/kart_island.gd")}


func _preserve(name: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SESSION)
	var file := FileAccess.open(output.path_join(name + "-session.cfg"), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _run() -> void:
	started = Time.get_ticks_usec()
	output = OS.get_environment("LUMO_QA_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(SESSION)
	DirAccess.remove_absolute("user://kart_preferences.cfg")
	root.get_node("HostBridge")._options = {"soundEnabled": false, "reduceAnimations": true}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	await _settle()
	_check(game.menu_active and not game.racing, "normal engine starts in the actual garage", [true, false], [game.menu_active, game.racing])
	for step in range(5):
		_check(game.garage.step == step, "public garage step%d" % step, step, game.garage.step)
		await _touch(game.garage.next_button)
	_check(not game.menu_active and not game.paused, "public start enters the actual unpaused race", [false, false], [game.menu_active, game.paused])
	var initial: Dictionary = _read()
	observations.append(initial)
	_preserve("01-public-start")
	var id: String = initial.result_id
	var first: Dictionary = {}
	var second: Dictionary = {}
	while float(Time.get_ticks_usec() - started) / 1000000.0 < 30.0:
		await physics_frame
		var row: Dictionary = _read()
		if row.elapsed != observations.back().elapsed or row.countdown != observations.back().countdown:
			observations.append(row)
		if first.is_empty() and row.countdown == 0.0 and row.elapsed >= 1.0:
			first = row
			_preserve("02-first-active")
		elif not first.is_empty() and row.elapsed > first.elapsed:
			second = row
			_preserve("03-next-periodic")
			break
	_check(not first.is_empty(), "normal engine produced an actual active snapshot", true, not first.is_empty())
	if not first.is_empty():
		_check(first.elapsed >= 1.0 and first.elapsed <= 1.0 + 1.0 / 60.0 + 0.000001,
			"first normal snapshot records one real active second", "elapsed in [1,1+step]", first.elapsed)
		_check(first.result_id == id and first.countdown == 0.0 and not first.finished
			and not first.completed_race and first.result_payload.is_empty(),
			"first normal snapshot preserves unfinished race identity", "same ID,countdown0,unfinished,empty payload", first)
	_check(not second.is_empty() and not first.is_empty() and second.elapsed - first.elapsed >= 5.0
		and second.elapsed - first.elapsed <= 5.0 + 1.0 / 60.0 + 0.000001,
		"next normal snapshot retains five active seconds", "five active seconds plus at most one step", second)
	var failed: int = 0
	for row in checks:
		if not row.passed:
			failed += 1
	if checks.size() != 11:
		failed += 1
	var report: Dictionary = {"status": "PASS" if failed == 0 else "FAIL", "checks": checks,
		"check_count": checks.size(), "failures": failed, "observations": observations,
		"first_active": first, "next_periodic": second, "engine": Engine.get_version_info(),
		"scope": "Normal headless engine physics and five current public GUI touch pairs; host motion preference skips preview; desktop auto-gas defaults; no manual step/gameplay assignment, no Android/visual/FPS claim"}
	var file := FileAccess.open(output.path_join("natural-engine-public-touch-evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	game.abandoned = true
	root.world_3d.fallback_environment = null
	game.queue_free()
	game = null
	for frame in range(8):
		await process_frame
	if startup_environment != null:
		startup_environment.sky = null
	startup_environment = null
	await create_timer(0.1).timeout
	print("[FirstActiveEngine] %s: %d checks / %d failures" % [report.status, checks.size(), failed])
	quit(0 if failed == 0 else 1)
