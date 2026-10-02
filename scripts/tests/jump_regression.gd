extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Deutsch"}
	var game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	for frame in range(30):
		await physics_frame
	assert(game.actor.is_on_floor(), "Lumo must stand on a real collision platform")
	assert(game.grade == 2 and game.subject == "Deutsch")
	game.jump_buffer = 0.15
	await physics_frame
	await physics_frame
	assert(game.actor.velocity.y > 0, "Jump must apply upward velocity")
	game.actor.position = game.islands[3] + Vector3(0, 0.4, 0)
	game.actor.velocity = Vector3.ZERO
	for frame in range(25):
		await physics_frame
	assert(game.checkpoint == 3 and game.question_open)
	var answer: String = game.active_question.answer
	var wrong: String = game.active_question.options.filter(func(a): return a != answer)[0]
	game._answer(wrong)
	assert(game.question_open and game.wrong_count == 1)
	game._answer(answer)
	assert(not game.question_open and game.completed_questions.has(3))
	game.actor.position.y = -10
	await physics_frame
	await physics_frame
	assert(game.falls == 1 and game.actor.position.y > -1)
	game._pause()
	assert(game.paused)
	game._set_direction(Vector2.UP, true)
	game._stop_input()
	game._set_direction(Vector2.UP, false)
	assert(game.touch_direction == Vector2.ZERO, "Releasing a key after pause must not reverse Lumo")
	game._finish()
	assert(game.finished)
	game.queue_free()
	await process_frame
	print("[JumpTests] PASS: collision platforms, jump, class/subject, checkpoint, retries, respawn, pause, finish")
	quit(0)
