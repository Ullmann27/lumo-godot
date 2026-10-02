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
		for subject in ["Mathematik", "Deutsch"]:
			for i in range(500):
				var q: Dictionary = questions.make(grade, subject, rng)
				assert(q.options.size() == 3)
				assert(q.options.count(q.answer) == 1)
				assert(q.options[0] != q.options[1] and q.options[1] != q.options[2] and q.options[0] != q.options[2])
				if subject == "Mathematik":
					var match_result: RegExMatch = calculation.search(q.prompt)
					var expected: int = 0
					if match_result:
						var a: int = int(match_result.get_string(1))
						var b: int = int(match_result.get_string(3))
						match match_result.get_string(2):
							"+": expected = a + b
							"−": expected = a - b
							"·": expected = a * b
					else:
						var values: Array[RegExMatch] = numbers.search_all(q.prompt)
						assert(values.size() == 2)
						expected = int(values[0].get_string()) + int(values[1].get_string())
					assert(str(expected) == q.answer)
					assert(expected >= 0 and expected <= [0, 10, 100, 1000, 10000][grade])
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.track_length > 150)
	var checked_road: bool = false
	for child in game.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			var normals = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			assert(normals[0].y > 0.9, "Road must face upward, not disappear below the camera")
			checked_road = true
	assert(checked_road)
	game.countdown = 0
	game.racing = true
	game._physics_process(1.0)
	assert(game.distance > 0)
	game._open_question()
	assert(game.question_open)
	var correct: String = game.active_question.answer
	var wrong: String = game.active_question.options.filter(func(a): return a != correct)[0]
	game._answer(wrong)
	assert(game.question_open and game.wrong_count == 1)
	game._answer(correct)
	assert(not game.question_open and game.correct_count == 1)
	game.boosts = 1
	game._boost()
	assert(game.boost_time > 0 and game.boosts == 0)
	game._finish()
	assert(game.finished)
	game.queue_free()
	await process_frame
	print("[KartTests] PASS: 4000 question variants, movement, retries, boosts, finish, persistence")
	quit(0)
