extends SceneTree
## The three selectable routes must all be genuinely traversable. No player
## position injection after course start; regular movement/jump/question input.
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[JumpExpeditions] " + label)


func _run() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	var previous_points: Array[Vector3] = []
	var child: String = "jump_course_test_%d" % Time.get_ticks_usec()
	for course in range(3):
		root.get_node("SceneRouter").launch_options = {"childKey": child, "grade": 2, "subject": "Mathematik", "jumpCourse": course}
		var game = load("res://scenes/games/jump_islands.tscn").instantiate()
		root.add_child(game)
		await physics_frame
		_check(game.course_index == course, "launch selects actual course %d" % course)
		_check(game.islands.size() == 12, "course %d keeps twelve physical islands" % course)
		if not previous_points.is_empty():
			_check(not game.islands[5].is_equal_approx(previous_points[5]), "course %d changes the playable route" % course)
		previous_points.assign(game.islands)
		var frames: int = 0
		while not game.finished and frames < 5000:
			if game.question_open:
				game._answer(game.active_question.answer)
			else:
				var destination: Vector3 = game.islands[mini(game.checkpoint + 1, game.ISLAND_COUNT - 1)]
				game.touch_direction = Vector2(destination.x - game.actor.position.x, destination.z - game.actor.position.z).normalized()
				if game.actor.is_on_floor() and game.actor.position.z < game.islands[game.checkpoint].z - 1.9:
					game.jump_buffer = 0.15
			await physics_frame
			frames += 1
		_check(game.finished and game.checkpoint == 11, "course %d reaches goal with real physics" % course)
		_check(game.falls == 0, "course %d main route has no forced fall" % course)
		_check(game.completed_questions.size() == 3, "course %d has three genuine learning stops" % course)
		_check(game.objective.text.contains("Etappe 4/4"), "course %d exposes stage goal in HUD" % course)
		if game.finished:
			var base: int = 3 + game.completed_questions.size() * 2 + game.collected.size()
			_check(int(game.result_payload.stars) == base + game.stars_gathered.size() + game._completed_goal_count() * 2, "course %d award contains earned optional goals exactly once" % course)
			var before: int = root.get_node("ProgressStore").total_stars()
			game._finish()
			_check(root.get_node("ProgressStore").total_stars() == before, "course %d repeated finish cannot pay twice" % course)
		print("[JumpExpeditions] route %d: frames=%d falls=%d crystals=%d goals=%d" % [course, frames, game.falls, game.collected.size(), game._completed_goal_count()])
		var path: String = game.session_path
		game.abandoned = true
		game.queue_free()
		await process_frame
		await process_frame
		DirAccess.remove_absolute(path)
	# Actual course navigation must save the outgoing course and resume it later.
	root.get_node("SceneRouter").launch_options = {"childKey": child, "grade": 2, "jumpCourse": 0}
	var game = load("res://scenes/games/jump_islands.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.checkpoint = 2
	game._save_session()
	var first_path: String = game.session_path
	game._pause()
	game._show_courses()
	_check(game.modal_column.has_node("CourseChoice1") and game.modal_column.has_node("CourseChoice2"), "course choices connected to production pause menu")
	game.modal_column.get_node("CourseChoice1").pressed.emit()
	for _i in range(8):
		await physics_frame
	game = current_scene
	_check(game.course_index == 1 and game.checkpoint == 0 and game.session_path != first_path, "real course switch opens separate route/save")
	var second_path: String = game.session_path
	game._pause()
	game._choose_course(0)
	for _i in range(8):
		await physics_frame
	game = current_scene
	_check(game.course_index == 0 and game.checkpoint == 2 and game.paused, "return to prior course restores outgoing checkpoint")
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(first_path)
	DirAccess.remove_absolute(second_path)
	if failures.is_empty():
		print("[JumpExpeditions] PASS %d checks: three physical courses, four stages, real menu selection and preserved progress" % checks)
		quit(0)
	else:
		print("[JumpExpeditions] FAIL ", failures)
		quit(1)
