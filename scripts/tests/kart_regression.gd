extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var questions = load("res://scripts/games/kart_questions.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 82741
	var calculation := RegEx.new()
	calculation.compile("^(\\d+) ([+−·]) (\\d+) = \\?$")
	var numbers := RegEx.new()
	numbers.compile("\\d+")
	for grade in range(1, 5):
		for subject in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]:
			for i in range(500):
				var q: Dictionary = questions.make(grade, subject, rng)
				assert(q.options.size() == 3)
				assert(q.options.count(q.answer) == 1)
				assert(
					(
						q.options[0] != q.options[1]
						and q.options[1] != q.options[2]
						and q.options[0] != q.options[2]
					)
				)
				if subject == "Mathematik":
					var match_result: RegExMatch = calculation.search(q.prompt)
					var expected: int = 0
					if match_result:
						var a: int = int(match_result.get_string(1))
						var b: int = int(match_result.get_string(3))
						match match_result.get_string(2):
							"+":
								expected = a + b
							"−":
								expected = a - b
							"·":
								expected = a * b
					else:
						var values: Array[RegExMatch] = numbers.search_all(q.prompt)
						assert(values.size() == 2)
						expected = int(values[0].get_string()) + int(values[1].get_string())
					assert(str(expected) == q.answer)
					assert(expected >= 0 and expected <= [0, 10, 100, 1000, 10000][grade])
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	for mode in ["gemuetlich", "flott"]:
		var game = scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		assert(game.track_length > 350)
		assert(game.opponents.size() == 5)
		assert(game.world.decoration_count > 2000)
		var normals = game.world.road.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		assert(normals[0].y > 0.9, "Road faces upward")
		assert(game._forward(0).dot(game._forward(game.track_length - .05)) > .99)
		assert(
			game._track_position(0, 0).distance_to(game._track_position(game.track_length, 0)) < .01
		)
		game.countdown = 0
		game.paused = false
		game.racing = true
		game.difficulty = mode
		game.distance = 0
		game.elapsed = 0
		game.question_index = 0
		game.correct_count = 0
		game.checkpoint_index = 0
		game._physics_process(.2)
		assert(game.distance > 0)
		game._open_question()
		var correct: String = game.active_question.answer
		var wrong: String = game.active_question.options.filter(func(a): return a != correct)[0]
		game._answer(wrong)
		assert(game.question_open and game.wrong_count == 1)
		var before: float = game.distance
		var before_elapsed: float = game.elapsed
		var before_rivals: Array = game.opponent_distances.duplicate()
		game._physics_process(.2)
		assert(game.distance == before, "Learning must pause Lumo's kart")
		assert(game.elapsed == before_elapsed, "Thinking time is excluded from race time")
		assert(game.opponent_distances == before_rivals, "All rivals wait during learning")
		game._pause()
		before = game.distance
		game._physics_process(1)
		assert(game.distance == before and game.paused)
		game._answer(correct)
		assert(game.correct_count == 0, "No answers during pause")
		game._resume()
		assert(game.question_open and game.active_question.answer == correct)
		game._answer(correct)
		game._answer(correct)
		assert(not game.question_open and game.correct_count == 1, "No double answer reward")
		game.boosts = 1
		game._boost()
		assert(game.boost_time > 0 and game.boosts == 0)
		game.boost_time = 0
		game.speed = 16
		game.brake = 1
		game._physics_process(1)
		assert(game.speed < 12, "Pulling the stick down slows the kart")
		game.brake = 0
		# Own-finger capture, a second finger and release outside the rectangle.
		game.joystick.set_enabled(true)
		var touch := InputEventScreenTouch.new()
		touch.index = 3
		touch.pressed = true
		touch.position = game.joystick.size / 2 + Vector2(45, 0)
		game.joystick._gui_input(touch)
		assert(game.steering > .5 and game.joystick.touch_id == 3)
		game.boosts = 1
		game.boost_button.disabled = false
		touch.index = 5
		touch.position = game.boost_button.size / 2
		game.boost_button._gui_input(touch)
		assert(game.boosts == 0 and game.boost_time > 0)
		assert(game.joystick.touch_id == 3 and game.steering > .5)
		touch.pressed = false
		game.boost_button._input(touch)
		game.joystick._input(touch)
		assert(game.steering > .5, "Second finger release must leave stick active")
		touch.index = 3
		game.joystick._input(touch)
		assert(game.steering == 0 and game.joystick.touch_id == -1)
		game.boost_time = 0
		game.drifting = true
		game.steering = .8
		game._physics_process(1.2)
		game._release_drift()
		assert(game.boost_time >= 1.6)
		game.steering = 0
		game._save_session()
		before = game.distance
		var saved_boosts: int = game.boosts
		game.abandoned = true
		game.queue_free()
		await process_frame
		game = scene.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		assert(game.paused and is_equal_approx(game.distance, before))
		assert(game.boosts == saved_boosts and game.difficulty == mode)
		game._resume()
		# Complete both laps by advancing the real race logic, never calling finish.
		var frames: int = 0
		while not game.finished and frames < 9000:
			game._physics_process(1.0 / 60)
			if game.question_open:
				game._answer(game.active_question.answer)
			frames += 1
		assert(game.finished and game.distance >= game.track_length * 2)
		assert(game.checkpoint_index == 16 and not game.result_id.is_empty())
		assert(game.correct_count == 6 and game.modal.visible)
		var stars: int = root.get_node("ProgressStore").total_stars()
		game._finish()
		assert(root.get_node("ProgressStore").total_stars() == stars)
		assert(not FileAccess.file_exists(game.SESSION))
		print(
			(
				"[KartTests] completed %s: %.1fs, %d frames, six learning boosts"
				% [mode, game.elapsed, frames]
			)
		)
		game.queue_free()
		await process_frame
	print(
		(
			"[KartTests] PASS: 8000 questions, two full races, analogue multi-touch, drift, "
			+ "braking, pause, save/resume, no duplicate rewards"
		)
	)
	quit(0)
