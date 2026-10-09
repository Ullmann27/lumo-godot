extends SceneTree
## Boundary expectations are independent of the formatter implementation.
## The observed lap comes from the untouched 1905 complete-flow gate trace.

const CASES: Array[Dictionary] = [
	{"seconds": 0.0, "expected": "00:00.000"},
	{"seconds": 0.0004, "expected": "00:00.000"},
	{"seconds": 0.0005, "expected": "00:00.001"},
	{"seconds": 0.0006, "expected": "00:00.001"},
	{"seconds": 0.001, "expected": "00:00.001"},
	{"seconds": 0.125, "expected": "00:00.125"},
	{"seconds": 0.9994, "expected": "00:00.999"},
	{"seconds": 0.9995, "expected": "00:01.000"},
	{"seconds": 0.9996, "expected": "00:01.000"},
	{"seconds": 1.0, "expected": "00:01.000"},
	{"seconds": 1.0004, "expected": "00:01.000"},
	{"seconds": 1.001, "expected": "00:01.001"},
	{"seconds": 12.345, "expected": "00:12.345"},
	{"seconds": 12.3454, "expected": "00:12.345"},
	{"seconds": 12.3456, "expected": "00:12.346"},
	{"seconds": 40.9999999999977, "expected": "00:41.000", "source": "actual1905 lap"},
	{"seconds": 41.0, "expected": "00:41.000", "source": "actual1905 payload"},
	{"seconds": 59.9994, "expected": "00:59.999"},
	{"seconds": 59.9995, "expected": "01:00.000"},
	{"seconds": 59.9996, "expected": "01:00.000"},
	{"seconds": 60.0, "expected": "01:00.000"},
	{"seconds": 60.9999999999977, "expected": "01:01.000"},
	{"seconds": 61.125, "expected": "01:01.125"},
	{"seconds": 119.9996, "expected": "02:00.000"},
	{"seconds": 120.0, "expected": "02:00.000"},
	{"seconds": 3599.9996, "expected": "60:00.000"},
	{"seconds": 3600.125, "expected": "60:00.125"},
	{"seconds": 90.0, "expected": "01:30.000"},
	{"seconds": 489.123, "expected": "08:09.123"}
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var formatter = load("res://scripts/games/kart_island.gd").new()
	var cases: Array[Dictionary] = []
	var failures := 0
	for entry in CASES:
		var observed: String = formatter._format_time(float(entry.seconds))
		var correct: bool = observed == entry.expected
		cases.append(
			{
				"seconds": entry.seconds,
				"expected": entry.expected,
				"observed": observed,
				"pass": correct,
				"source": entry.get("source", "boundary or normal time")
			}
		)
		if not correct:
			failures += 1
			print(
				(
					"[KartTimeFormat] FAIL: %.15f expected %s, got %s"
					% [entry.seconds, entry.expected, observed]
				)
			)
	formatter.free()
	var output := OS.get_environment("LUMO_QA_DIR")
	if output.is_empty():
		output = "res://exports/time-format"
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("evidence.json"), FileAccess.WRITE).store_string(
		JSON.stringify(
			{
				"status": "PASS" if failures == 0 else "FAIL",
				"checks": cases,
				"passed": CASES.size() - failures,
				"failed": failures,
				"engine": Engine.get_version_info(),
				"display": DisplayServer.get_name(),
				"scope": "formatter only; no race/physics/result/reward state is assigned"
			},
			"  "
		)
	)
	if failures == 0:
		print("[KartTimeFormat] PASS: %d independent boundary and normal-time cases" % CASES.size())
	quit(0 if failures == 0 else 1)
