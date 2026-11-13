extends SceneTree
## Persistence/policy tests. The companion player-full-route regression proves
## the actual two-lap touch finish reaches this policy without injected progress.
const TRACK_PASS = preload("res://scripts/games/kart_track_pass.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
var checks := 0
var failures: Array[String] = []
var children: Array[String] = []
var serial := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[KartTrackPass] " + label)


func _child(suffix: String) -> String:
	var key := "kart_track_pass_test_%d_%s" % [Time.get_ticks_usec(), suffix]
	children.append(key)
	return key


func _result(place: int = 6, resets: int = 0) -> Dictionary:
	serial += 1
	return {"resultId": "pass-test-%d" % serial, "status": "completed", "mode": "race",
		"track": "sonnenhafen", "difficulty": "gemuetlich", "checkpoints": 16,
		"place": place, "resets": resets, "elapsedSeconds": 120.0}


func _file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"


func _run() -> void:
	var legacy := {}
	for path in ["user://progress.cfg", "user://kart_holographic_records.cfg", "user://kart_race_session.cfg"]:
		legacy[path] = _file_hash(path)
	var child_a := _child("A")
	var child_b := _child("B")
	var progress = TRACK_PASS.new(child_a)
	_check(progress.total("gemuetlich") == 0 and not FileAccess.file_exists(progress.path()), "new child starts empty without writing a save")
	_check(progress.path() != TRACK_PASS.path_for(child_b) and not progress.path().contains(child_a), "separate child identity is hashed in the file path")
	var first := _result()
	var result: Dictionary = progress.complete(first, 200.0, 100.0)
	_check(result.eligible and result.saved and result.advanced and result.stage == 1, "every genuine finish earns the first objective even in sixth place")
	_check(not result.has("stars") and not result.has("unlocks"), "objectives never mint currency or equipment")
	var bytes_before := FileAccess.get_file_as_bytes(progress.path())
	var replay := first.duplicate(true)
	replay.place = 1
	result = progress.complete(replay, 200.0, 100.0)
	_check(not result.advanced and result.stage == 1 and FileAccess.get_file_as_bytes(progress.path()) == bytes_before,
		"same completed result cannot be reused with a better place")
	result = progress.complete(_result(3, 2), 200.0, 100.0)
	_check(result.stage == 2, "podium goal allows ordinary rescue assistance")
	result = progress.complete(_result(1, 1), 200.0, 100.0)
	_check(result.stage == 2 and not result.advanced, "clean victory goal requires zero actual resets")
	result = progress.complete(_result(1, 0), 200.0, 100.0)
	_check(result.stage == 3 and result.advanced, "win without rescue completes the third objective")
	result = progress.complete(_result(6, 3), 200.0, 100.0)
	_check(result.stage == 3 and not result.advanced, "later difficult race never removes earned goals")
	var reloaded = TRACK_PASS.new(child_a)
	_check(reloaded.stage("sonnenhafen", "gemuetlich") == 3, "goals survive a new instance from the real save")
	_check(reloaded.stage("sonnenhafen", "flott") == 0 and reloaded.stage("zauberwald", "gemuetlich") == 0,
		"track and requested difficulty keep independent goals")
	_check(TRACK_PASS.new(child_b).total("gemuetlich") == 0, "another child's goals remain empty")
	_check(not FileAccess.file_exists(progress.path() + ".tmp"), "successful atomic save leaves no temporary file")

	var invalid = TRACK_PASS.new(_child("invalid"))
	var bad_cases: Array[Dictionary] = []
	for entry in [
		["checkpoints", 15], ["checkpoints", 16.0], ["checkpoints", "16"],
		["place", 0], ["place", 7], ["place", 1.0], ["resets", -1],
		["elapsedSeconds", 0], ["elapsedSeconds", -1], ["elapsedSeconds", INF],
		["elapsedSeconds", NAN], ["elapsedSeconds", "120"], ["status", "abandoned"],
		["status", "paused"], ["mode", "training"], ["mode", "arena"], ["mode", "time_trial"],
		["track", "missing"], ["difficulty", "missing"], ["resultId", ""], ["resultId", "x".repeat(257)],
	]:
		var bad := _result(1)
		bad[entry[0]] = entry[1]
		bad_cases.append(bad)
	for index in range(bad_cases.size()):
		result = invalid.complete(bad_cases[index], 200.0, 100.0)
		_check(not result.eligible and not result.advanced, "reject malformed or ineligible result %d" % index)
	for pair in [Vector2(199.999, 100), Vector2(INF, 100), Vector2(200, NAN), Vector2(200, 0), Vector2(200, 10)]:
		result = invalid.complete(_result(1), pair.x, pair.y)
		_check(not result.eligible, "reject incomplete or nonfinite physical race distance %s" % pair)
	_check(not FileAccess.file_exists(invalid.path()) and invalid.accepted_results.is_empty(), "rejected host-shaped results leave no save or consumed result ID")

	var retry = TRACK_PASS.new(_child("retry"))
	retry.save_enabled = false
	var retry_result := _result(1)
	result = retry.complete(retry_result, 200.0, 100.0)
	_check(result.eligible and not result.saved and result.stage == 0 and not result.advanced,
		"storage failure is visible and does not claim achievement")
	_check(retry.accepted_results.is_empty() and retry.total("gemuetlich") == 0, "failed save does not mutate durable state in memory")
	retry.save_enabled = true
	result = retry.complete(retry_result, 200.0, 100.0)
	_check(result.saved and result.stage == 3, "same result can be retried successfully after storage recovers")

	var all_tracks = TRACK_PASS.new(_child("catalog"))
	for difficulty in CATALOG.DIFFICULTIES:
		for track in CATALOG.TRACKS:
			var completion := _result(1)
			completion.track = str(track.id)
			completion.difficulty = str(difficulty.id)
			completion.mode = "cup"
			result = all_tracks.complete(completion, 200.0, 100.0)
			_check(result.saved and result.stage == 3, "%s / %s has identical achievable goals" % [track.id, difficulty.id])
		_check(all_tracks.total(str(difficulty.id)) == 36, "all twelve tracks expose exactly 36 goals for " + str(difficulty.id))
	var full_reload = TRACK_PASS.new(all_tracks.child_key)
	_check(full_reload.total("gemuetlich") == 36 and full_reload.total("flott") == 36 and full_reload.total("pro") == 36,
		"all 108 goals persist independently with no required difficulty escalation")

	# A copied or malformed save cannot import another child's achievement.
	var malformed_child := _child("malformed")
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("meta", "owner", child_a.sha256_text())
	config.set_value("stages", "sonnenhafen/gemuetlich", 3)
	config.save(TRACK_PASS.path_for(malformed_child))
	_check(TRACK_PASS.new(malformed_child).total("gemuetlich") == 0, "copied save with mismatched owner is ignored")
	config.set_value("meta", "owner", malformed_child.sha256_text())
	config.set_value("stages", "sonnenhafen/gemuetlich", 4)
	config.set_value("stages", "zauberwald/gemuetlich", "3")
	config.set_value("stages", "invented/gemuetlich", 3)
	config.save(TRACK_PASS.path_for(malformed_child))
	_check(TRACK_PASS.new(malformed_child).total("gemuetlich") == 0, "invalid stage types, ranges and unknown tracks are ignored")
	config.set_value("meta", "version", 2)
	config.set_value("stages", "sonnenhafen/gemuetlich", 3)
	config.save(TRACK_PASS.path_for(malformed_child))
	var future_file := FileAccess.get_file_as_bytes(TRACK_PASS.path_for(malformed_child))
	var future_pass = TRACK_PASS.new(malformed_child)
	_check(future_pass.total("gemuetlich") == 0, "future save version is not interpreted")
	result = future_pass.complete(_result(1), 200.0, 100.0)
	_check(not result.saved and FileAccess.get_file_as_bytes(TRACK_PASS.path_for(malformed_child)) == future_file,
		"new completion cannot overwrite a future save version")
	for path in legacy:
		_check(_file_hash(path) == legacy[path], "legacy bytes preserved: " + path)

	# Verify production wiring separately from the policy fixtures above.
	var host = root.get_node("HostBridge")
	var old_options: Dictionary = host._options.duplicate(true)
	var production_child := _child("production")
	host._options["childKey"] = production_child
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	_check(game.track_pass.child_key == production_child and game.garage.track_pass == game.track_pass,
		"actual scene and world menu share the captured child's persistent pass")
	host._options["childKey"] = child_b
	_check(game.track_pass.child_key == production_child, "late host identity change cannot reattribute an already-running race")
	game.garage.step = 3
	game.garage.setup.mode = "race"
	game.garage._refresh()
	for _frame in range(4):
		await process_frame
	_check(game.garage.choices.get_child_count() == 12 and game.garage.choices.get_child(0).caption_label.visible,
		"all existing track choices show goals through the production menu")
	game.garage.setup.mode = "time_trial"
	game.garage._refresh()
	_check(not game.garage.title_label.text.contains("/36"), "time trial retains its own ghost goal instead of promising race medals")
	game.abandoned = true
	game.queue_free()
	await process_frame
	host._options = old_options
	for child in children:
		DirAccess.remove_absolute(TRACK_PASS.path_for(child))
		DirAccess.remove_absolute(TRACK_PASS.path_for(child) + ".tmp")
	print("[KartTrackPass] ", "PASS" if failures.is_empty() else "FAIL", " ", checks, " checks")
	quit(0 if failures.is_empty() else 1)
