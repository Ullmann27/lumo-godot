extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The question generator is shared with the Jump learning game; Kart itself never asks.
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
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.menu_active and game.garage.visible, "The garage must precede any race")
	assert(game.garage._entries().size() == 5, "Five usable mode choices")
	for entry in game.garage._entries():
		assert(str(entry.id) != "learn_cup", "No learning cup in Kart")
	for removed in [
		"question_open", "active_question", "learning_events", "lesson", "correct_count", "grade"
	]:
		assert(removed not in game, "Kart has no learning-question state: " + removed)
	game.lightweight = true
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet", "track": "sonnenhafen", "difficulty": "flott"})
	await process_frame
	assert(game.track_length > 250 and game.opponents.size() == 5)
	assert(game._track_position(0, 0).distance_to(game._track_position(game.track_length, 0)) < .01)
	game.countdown = 0
	game.racing = true
	var start_position: Vector3 = game.player.position
	for i in range(35):
		game.steering = 0.85
		game._physics_process(1.0 / 60)
	assert(game.player.position.distance_to(start_position) > 0.5)
	assert(absf(angle_difference(game._heading(0), game.player_heading)) > 0.15, "Steering turns the actual kart heading")
	var position_before: Vector3 = game.player.position
	game.distance += 30
	game._update_vehicles(0)
	assert(game.player.position == position_before, "Race progress cannot move the physical kart along rails")
	game.distance -= 30
	game.steering = 0
	game._pause()
	var before: float = game.distance
	var before_elapsed: float = game.elapsed
	var before_rivals: Array = game.opponent_distances.duplicate()
	game._physics_process(.2)
	assert(game.distance == before and game.elapsed == before_elapsed)
	assert(game.opponent_distances == before_rivals, "All rivals wait during the pause")
	game._resume()
	assert(not game.paused and game.racing, "Resume continues the race without any task")
	game.boosts = 1
	game._boost()
	assert(game.boost_time > 0 and game.boosts == 0)
	game.boost_time = 0
	game.speed = 16
	game.brake = 1
	for i in range(30):
		game._physics_process(1.0 / 60)
	assert(game.speed < 12, "Brake input decelerates the physical kart")
	game.brake = 0
	game._reset_kart()
	game.drifting = true
	game.drift_charge = 2.0
	game._release_drift()
	assert(game.boost_time >= 1.8, "A long drift releases the orange turbo")
	game._save_session()
	var saved_position: Vector3 = game.player.position
	var saved_result_id: String = game.result_id
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.menu_active and game.saved_session_available)
	game.lightweight = true
	game._resume_saved_race()
	assert(game.paused and game.player.position.is_equal_approx(saved_position))
	assert(game.result_id == saved_result_id)
	game._resume()
	# The test driver only supplies steering, exactly like a thumb. It never moves the kart.
	var frames: int = 0
	while not game.finished and frames < 15000:
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
		var direction: Vector3 = target - game.player.position
		var heading: float = atan2(-direction.x, -direction.z)
		game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
		game._physics_process(1.0 / 60)
		frames += 1
		if frames % 60 == 0:
			await process_frame
	assert(game.finished, "A freely steered kart must complete two actual laps")
	assert(game.checkpoint_index == 16 and game.distance >= game.track_length * 2)
	# Zieleinlauf: erst Kamerafahrt mit ausrollendem Kart, dann das Ergebnis.
	assert(game.result_payload.status == "completed", "Reward is decided at the line")
	assert(not game.modal.visible and game.finish_cine_left > 0, "Finish camera runs before the result")
	assert(not game.controls_row.visible, "Driving controls are hidden during the finish camera")
	var line_position: Vector3 = game.player.position
	var behind := Vector3(sin(game.player_heading), 0, cos(game.player_heading))
	var cine_frames: int = 0
	while not game.modal.visible and cine_frames < 600:
		game._physics_process(1.0 / 60)
		cine_frames += 1
	assert(game.modal.visible, "The result appears after the finish camera")
	assert(cine_frames >= 150 and cine_frames <= 220, "Finish camera lasts about three seconds")
	assert(game.player.position.distance_to(line_position) > 3.0, "The kart rolls on after the line")
	var view: Vector3 = (game.camera.position - game.player.position).normalized()
	assert(view.dot(behind) < 0.2, "The camera ends beside/in front of Lumo, not behind")
	assert(game.player.celebration_place == int(game.result_payload.place), "Lumo reacts to the place")
	assert(game.modal_column.has_node("ResultStats"), "Result shows time, best lap and stars")
	assert(game.result_payload.has("bestLapSeconds") and float(game.result_payload.bestLapSeconds) > 0)
	assert(game.result_payload.stars == 3, "Plain race reward")
	assert(game.result_payload.solved == 0, "The Flutter host needs an integer solved")
	for removed in ["grade", "subject", "learning_events"]:
		assert(not game.result_payload.has(removed), "No learning data in the race result: " + removed)
	var stars: int = root.get_node("ProgressStore").total_stars()
	game._finish()
	assert(root.get_node("ProgressStore").total_stars() == stars, "A result must award once")
	print("[KartTests] Full free-steering race: %.1fs, %d frames, %d resets" % [game.elapsed, frames, game.reset_count])
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	print(
		(
			"[KartTests] PASS: 8000 shared Jump questions; no Kart learning state; free steering; "
			+ "real full race; brake/drift; pause; save/resume; one award"
		)
	)
	# AudioServer releases stopped stream playbacks on its asynchronous mix thread.
	await create_timer(0.12).timeout
	quit(0)
