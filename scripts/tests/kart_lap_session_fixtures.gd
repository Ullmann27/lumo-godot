extends RefCounted
## Assigned legacy ConfigFile fixtures; these do not claim physically driven laps.


static func legacy_pairs(probe) -> void:
	await probe._fresh()
	probe.game._pause()
	var cases: Array[Dictionary] = [
		{"name": "valid measured pair", "laps": [30.0], "start": 30.0, "expected": [[30.0], 30.0]},
		{"name": "both timing keys absent", "missing": ["lap_times", "lap_started_at"]},
		{"name": "history key absent", "missing": ["lap_times"]},
		{"name": "start key absent", "missing": ["lap_started_at"]},
		{"name": "history is a string", "laps": "30"},
		{"name": "start is a string", "start": "30"},
		{"name": "start is a boolean", "start": true},
		{"name": "interval is a boolean", "laps": [true]},
		{"name": "interval is a string", "laps": ["30"]},
		{"name": "zero interval", "laps": [0.0]},
		{"name": "negative interval", "laps": [-1.0]},
		{"name": "NaN interval", "laps": [NAN]},
		{"name": "infinite interval", "laps": [INF]},
		{"name": "NaN start", "start": NAN},
		{"name": "infinite start", "start": INF},
		{"name": "invalid negative start", "start": -2.0},
		{"name": "future start", "start": 56.0},
		{"name": "history exceeds start", "laps": [40.0]},
		{"name": "more history than completed gates", "laps": [15.0, 15.0]},
		{"name": "later lap cannot begin at race start zero", "laps": [], "start": 0.0},
	]
	for fixture in cases:
		var config: ConfigFile = probe._lap_seed_config()
		config.set_value("race", "lap_times", fixture.get("laps", [30.0]))
		config.set_value("race", "lap_started_at", fixture.get("start", 30.0))
		for key in fixture.get("missing", []):
			probe._lap_erase(config, str(key))
		assert(config.save(probe.game.SESSION) == OK)
		# Deliberate stale same-instance state must never leak into a restored save.
		probe.game.lap_times.assign([7.0])
		probe.game.lap_started_at = 7.0
		var restored: bool = probe.game._restore_session()
		probe._lap_check(
			restored, "optional timing data still restores: " + str(fixture.name), true, restored
		)
		var expected: Array = fixture.get("expected", [[], -1.0])
		var actual: Array = [probe.game.lap_times.duplicate(), probe.game.lap_started_at]
		probe._lap_check(
			actual == expected, "validated timing pair: " + str(fixture.name), expected, actual
		)


static func unknown_durability(probe) -> void:
	await probe._fresh("training")
	probe.game._pause()
	var config: ConfigFile = probe._lap_seed_config(10, 55.0, "training")
	probe._lap_erase(config, "lap_times")
	probe._lap_erase(config, "lap_started_at")
	assert(config.save(probe.game.SESSION) == OK)
	probe.game._restore_session()
	probe._lap_check(
		probe.game.lap_times.is_empty() and probe.game.lap_started_at == -1.0,
		"legacy lap-two duration stays explicitly unknown",
		[[], -1.0],
		[probe.game.lap_times, probe.game.lap_started_at]
	)
	probe.game._save_session()
	config.load(probe.game.SESSION)
	probe._lap_check(
		config.get_value("race", "lap_started_at", 0.0) == -1.0,
		"resave stores the unknown sentinel",
		-1.0,
		config.get_value("race", "lap_started_at", 0.0)
	)
	await probe._lap_reopen()
	probe.game._resume_saved_race()
	probe._lap_check(
		probe.game.lap_times.is_empty() and probe.game.lap_started_at == -1.0,
		"new-instance resave round-trip keeps the unknown sentinel",
		[[], -1.0],
		[probe.game.lap_times, probe.game.lap_started_at]
	)
	probe.game.lane = 0.0
	probe.game.speed = 0.0
	probe.game.checkpoint_index = 15
	probe.game.distance = probe.game.track_length * 2.0
	probe.game.elapsed = 60.0
	probe.game._update_checkpoints()
	probe._lap_check(
		probe.game.lap_times.is_empty() and probe.game.lap_started_at == 60.0,
		"the unknown partial lap is skipped at its legitimate boundary",
		[[], 60.0],
		[probe.game.lap_times, probe.game.lap_started_at]
	)
	probe.game._save_session()
	config.load(probe.game.SESSION)
	probe._lap_check(
		(
			config.get_value("race", "lap_times", []) == []
			and config.get_value("race", "lap_started_at", -1.0) == 60.0
		),
		"a new known boundary can be saved without invented history",
		[[], 60.0],
		[
			config.get_value("race", "lap_times", []),
			config.get_value("race", "lap_started_at", -1.0)
		]
	)
	await probe._lap_reopen()
	probe.game._resume_saved_race()
	probe._lap_check(
		probe.game.lap_times.is_empty() and probe.game.lap_started_at == 60.0,
		"known start with shorter legacy history restores",
		[[], 60.0],
		[probe.game.lap_times, probe.game.lap_started_at]
	)
	probe.game.checkpoint_index = 23
	probe.game.distance = probe.game.track_length * 3.0
	probe.game.elapsed = 90.0
	probe.game.lane = 0.0
	probe.game.speed = 0.0
	probe.game._update_checkpoints()
	probe._lap_check(
		probe.game.lap_times == [30.0] and probe.game.lap_started_at == 90.0,
		"only the subsequent full legacy lap is recorded",
		[[30.0], 90.0],
		[probe.game.lap_times, probe.game.lap_started_at]
	)
	probe.game._save_session()
	probe.game.lap_times.clear()
	probe.game.lap_started_at = -1.0
	probe.game._restore_session()
	probe._lap_check(
		probe.game.lap_times == [30.0] and probe.game.lap_started_at == 90.0,
		"the subsequently measured legacy lap survives another restore",
		[[30.0], 90.0],
		[probe.game.lap_times, probe.game.lap_started_at]
	)


static func versions(probe) -> void:
	await probe._fresh()
	probe.game._pause()
	for version in [1, 2, 3, 4]:
		var config: ConfigFile = probe._lap_seed_config()
		config.set_value("race", "version", version)
		config.set_value("race", "checkpoint_index", 3 if version < 3 else 10)
		probe._lap_erase(config, "lap_times")
		probe._lap_erase(config, "lap_started_at")
		assert(config.save(probe.game.SESSION) == OK)
		var restored: bool = probe.game._restore_session()
		probe._lap_check(
			restored and probe.game.checkpoint_index == 10,
			"legacy gate correction precedes timing: v%d" % version,
			{"restored": true, "gate": 10},
			{"restored": restored, "gate": probe.game.checkpoint_index}
		)
		probe._lap_check(
			probe.game.lap_times.is_empty() and probe.game.lap_started_at == -1.0,
			"legacy later lap remains unmeasured: v%d" % version,
			[[], -1.0],
			[probe.game.lap_times, probe.game.lap_started_at]
		)


static func unknown_finish(probe) -> void:
	await probe._fresh()
	probe.game._pause()
	var config: ConfigFile = probe._lap_seed_config(10, 55.0)
	probe._lap_erase(config, "lap_times")
	probe._lap_erase(config, "lap_started_at")
	assert(config.save(probe.game.SESSION) == OK)
	probe.game._restore_session()
	probe.game.elapsed = 58.0
	probe.game._finish(false)
	probe._lap_check(
		(
			probe.game.lap_times.is_empty()
			and probe.game._best_lap() == 0.0
			and float(probe.game.result_payload.bestLapSeconds) == 0.0
		),
		"finishing an unknown partial legacy lap never invents a best time",
		{"lap_times": [], "bestLapSeconds": 0.0},
		{
			"lap_times": probe.game.lap_times.duplicate(),
			"bestLapSeconds": probe.game.result_payload.bestLapSeconds
		}
	)
