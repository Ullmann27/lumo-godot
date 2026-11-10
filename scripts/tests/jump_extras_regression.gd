extends SceneTree
## Live physics checks for the 2013 moving-platform, bounce and bonus-star delta.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[JumpExtras] FAIL " + label)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _run() -> void:
	DirAccess.remove_absolute("user://jump_session.cfg")
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Mathematik"}
	var scene: PackedScene = load("res://scenes/games/jump_islands.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await _frames(30)
	_check(game.movers.size() == 3, "three real moving platforms")
	_check(game.bounce_pads.size() == 3, "three optional bounce pads")
	_check(game.bonus_stars.size() == 8, "eight optional bonus stars")
	var mover: AnimatableBody3D = game.movers[0].body
	var moving_at := mover.position
	await _frames(8)
	_check(not mover.position.is_equal_approx(moving_at), "platform moves during play")
	game._pause()
	var paused_at := mover.position
	var paused_clock: float = game.movers[0].clock
	await _frames(12)
	_check(mover.position.is_equal_approx(paused_at), "pause freezes platform transform")
	_check(is_equal_approx(game.movers[0].clock, paused_clock), "pause freezes platform clock")
	game._resume()
	game.question_open = true
	var question_at := mover.position
	await _frames(12)
	_check(mover.position.is_equal_approx(question_at), "learning question freezes platform")
	game.question_open = false
	game.finished = true
	var finished_at := mover.position
	await _frames(8)
	_check(mover.position.is_equal_approx(finished_at), "completed round freezes platform")
	game.finished = false
	game.actor.position = game.bounce_pads[0] + Vector3(0, 0.45, 0)
	game.actor.velocity = Vector3.ZERO
	var bounced := false
	for _frame in range(70):
		await physics_frame
		if game.actor.velocity.y > 10.0:
			bounced = true
	_check(bounced, "physical landing on bounce pad launches Lumo")
	_check(game.stars_gathered.size() > 0, "bounce collects reachable optional star")
	var collected_stars: Dictionary = game.stars_gathered.duplicate()
	game._save_session()
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	await _frames(2)
	_check(game.stars_gathered == collected_stars, "bonus progress survives resume")
	for id in collected_stars:
		_check(not game.bonus_stars[int(id)].visible, "collected star stays hidden")
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://jump_session.cfg")
	if failures.is_empty():
		print("[JumpExtras] PASS %d checks: live platforms, pause, bounce and star resume" % checks)
		quit(0)
	else:
		print("[JumpExtras] FAIL ", failures)
		quit(1)
