extends SceneTree
## Actual production scene, not a mock or a replacement curriculum.
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[LearningWonder] " + message)


func _frames(count := 8) -> void:
	for index in range(count):
		await process_frame


func _run() -> void:
	await _frames(2)
	var packed := load("res://scenes/learning/learning_world.tscn") as PackedScene
	var game = packed.instantiate()
	game.capture_options = {
		"learning": {"kind": "bridge_ten", "a": 8, "b": 5},
		"reduceAnimations": true
	}
	root.add_child(game)
	await _frames()
	var garden: Node = game.get_node_or_null("LearningGardenAtelier/LearningWonderGarden")
	_check(garden != null, "The existing learning route must contain the interactive wonder garden")
	if garden != null:
		_check(garden.has_method("render_state"), "Garden exposes bounded rendering evidence")
		if garden.has_method("render_state"):
			var start: Dictionary = garden.call("render_state")
			_check(start.get("progress", -1.0) == 0.0, "Unattempted explanation starts with closed buds")
			_check(start.get("reduced_motion", false), "Actual host reduced-motion option reaches garden")
			var before: int = game.activity.placed.size()
			game._show_one()
			await _frames(16)
			var moved: Dictionary = garden.call("render_state")
			_check(game.activity.placed.size() == before + 1, "Original learning manipulation remains authoritative")
			_check(is_equal_approx(float(moved.get("progress", -1.0)), 0.2), "Real action opens the corresponding amount of the garden")
			_check(game.activity.a == 8 and game.activity.b == 5, "Decoration must not rewrite the task")
			for index in range(4):
				game._show_one()
				await _frames(16)
			var complete: Dictionary = garden.call("render_state")
			_check(is_equal_approx(float(complete.get("progress", -1.0)), 1.0), "Garden celebrates only the completed real explanation")
			_check(game.activity.is_complete(), "The original completion rule still decides progress")
			game.restart()
			await _frames(16)
			_check(garden.call("render_state").get("progress", -1.0) == 0.0, "Restart resets decoration without carrying an old celebration")
	game.queue_free()
	await _frames()
	print("[LearningWonder] checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
