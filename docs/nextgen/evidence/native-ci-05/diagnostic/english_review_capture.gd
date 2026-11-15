extends "res://scripts/tests/learning_english_regression.gd"
## Focused renderer replay of four existing CI profiles. The full original
## fourteen-profile regression is executed independently without any filter.

func _tap(button: Button, context: String) -> void:
	await super._tap(button, context)
	if context.ends_with(": first targeted hint"):
		var game: Node = button
		while is_instance_valid(game) and not game.has_method("_english_hint"):
			game = game.get_parent()
		_check(is_instance_valid(game), "actual hint scene is available for readback")
		if is_instance_valid(game):
			await _capture(game, "english-%s-%dx%d-first-hint" % [game.activity.word, root.size.x, root.size.y])

func _run() -> void:
	if output.is_empty() or not capture or DisplayServer.get_name() == "headless":
		push_error("A real renderer, --capture and --output are required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources: Dictionary = {}
	for path: String in OWNED:
		sources[path] = FileAccess.get_sha256("res://" + path)
	if not _load_actual_tasks():
		quit(1)
		return
	for word in ["ruler", "rubber", "chair"]:
		await _exercise(word, Vector2i(640, 360), 1.0, Rect2())
	await _exercise("paper", Vector2i(2400, 1080), 2.625, Rect2(136, 0, 0, 63))
	for path: String in OWNED:
		_check(FileAccess.get_sha256("res://" + path) == sources[path], "source stayed identical: " + path)
	var file := FileAccess.open(output.path_join("english-review-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Four existing English CI profiles with real llvmpipe screenshots; full CI gate runs separately", "engine": Engine.get_version_info(), "renderer": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "source_sha256": sources, "checks": checks, "failures": failures, "captures": captures, "hint_layouts": hint_layouts, "input_events": input_events}, "  ") + "\n")
	file.close()
	print("ENGLISH_REVIEW_", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
