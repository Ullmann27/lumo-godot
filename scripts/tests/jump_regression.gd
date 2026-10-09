extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute("user://jump_session.cfg")
	var scene: PackedScene = load("res://scenes/games/jump_islands.tscn")
	root.get_node("SceneRouter").launch_options = {"grade": 2, "subject": "Deutsch"}
	var game = scene.instantiate()
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
	assert(
		game.touch_direction == Vector2.ZERO, "Releasing a key after pause must not reverse Lumo"
	)
	var result_id: String = game.result_id
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.paused and game.checkpoint == 3 and game.result_id == result_id)
	assert(game.completed_questions.has(3) and game.falls == 1)
	game._resume()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(game.paused and FileAccess.file_exists(game.SESSION))
	game._finish()
	assert(game.finished)
	assert(game.result_payload.game == "jump" and game.result_payload.status == "completed")
	assert(game.result_payload.solved == 1 and not FileAccess.file_exists(game.SESSION))
	game.queue_free()
	await process_frame
	print("[JumpTests] intermediate: collision, jump, checkpoint, retry, respawn, save/resume")
	# Traverse every gap with actual CharacterBody physics input, no teleport.
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	game = scene.instantiate()
	root.add_child(game)
	var frames: int = 0
	while not game.finished and frames < 5000:
		if game.question_open:
			game._answer(game.active_question.answer)
		else:
			var destination: Vector3 = game.islands[mini(
				game.checkpoint + 1, game.ISLAND_COUNT - 1
			)]
			game.touch_direction = (
				Vector2(
					destination.x - game.actor.position.x, destination.z - game.actor.position.z
				)
				. normalized()
			)
			if (
				game.actor.is_on_floor()
				and game.actor.position.z < game.islands[game.checkpoint].z - 1.9
			):
				game.jump_buffer = 0.15
		await physics_frame
		frames += 1
	assert(game.finished and game.checkpoint == 11, "All twelve physical islands must be reachable")
	assert(game.completed_questions.size() == 3, "All three learning islands must be answered")
	assert(game.falls == 0, "The real controller can cross every intended gap without falling")
	print(
		(
			"[JumpTests] full physical adventure: %d frames, %d crystals"
			% [frames, game.collected.size()]
		)
	)
	game.queue_free()
	await process_frame
	print(
		(
			"[JumpTests] PASS: full twelve-island adventure, collisions, jump, "
			+ "three learning stops, save/resume"
		)
	)
	quit(0)
