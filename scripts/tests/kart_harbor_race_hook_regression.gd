extends SceneTree
## Controller integration proof. The attraction's actual GPU transforms are
## checked separately by kart_harbor_attraction_regression.gd with GL rendering.
var failures: Array[String] = []
var game


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.lightweight = true
	(
		game
		. _start_selected_race(
			{
				"mode": "race",
				"driver": "fox",
				"kart": "comet",
				"track": "sonnenhafen",
				"difficulty": "flott",
			}
		)
	)
	game.set_physics_process(false)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	game.speed = 0.0
	game.player.position = game.world.position_at(95.0) + Vector3.UP * 0.035
	game.player_heading = game._heading(95.0)
	game.previous_road_distance = 95.0
	game.physical_velocity = Vector3.ZERO
	var attraction = game.world.get_node_or_null("SonnenhafenHarborAttraction")
	if attraction == null:
		_check(false, "Real race world has no harbor attraction")
		await _finish()
		return
	var phase: float = attraction.phase
	var streetfronts = game.world.get_node_or_null("SonnenhafenStreetfronts")
	if streetfronts == null:
		_check(false, "Real race world has no streetfront kit")
		await _finish()
		return
	var street_phase: float = streetfronts.phase
	# Only the actual game physics loop is called; no direct attraction.advance.
	for i in range(60):
		game._physics_process(1.0 / 60.0)
	_check(
		attraction.phase > phase + 0.04, "Normal racing physics must advance the visible attraction"
	)
	_check(attraction.trigger_count == 1, "The real racer position must reach the attraction")
	_check(streetfronts.phase > street_phase + 0.04, "Normal race physics must advance streetfront pennants")
	_check(streetfronts.trigger_count > 0, "Actual racer position must trigger nearby welcome pennants")
	game._pause()
	phase = attraction.phase
	street_phase = streetfronts.phase
	for i in range(12):
		game._physics_process(1.0 / 60.0)
	_check(is_equal_approx(phase, attraction.phase), "Race pause must freeze the attraction")
	_check(is_equal_approx(street_phase, streetfronts.phase), "Race pause must freeze streetfront pennants")
	game._resume()
	game._physics_process(1.0 / 60.0)
	_check(attraction.phase > phase, "Race resume must continue the attraction")
	_check(streetfronts.phase > street_phase, "Race resume must continue streetfront pennants")
	game.reduced_motion = true
	phase = attraction.phase
	street_phase = streetfronts.phase
	game._physics_process(1.0 / 60.0)
	_check(
		is_equal_approx(phase, attraction.phase),
		"Reduced-motion preference must reach the attraction"
	)
	game.reduced_motion = false
	_check(is_equal_approx(street_phase, streetfronts.phase), "Reduced motion must reach streetfront pennants")
	game.finished = true
	game.finish_cine_left = 0.0
	game._physics_process(1.0 / 60.0)
	_check(is_equal_approx(phase, attraction.phase), "Finished race must freeze the attraction")
	_check(is_equal_approx(street_phase, streetfronts.phase), "Finished race must freeze streetfront pennants")
	await _finish()


func _finish() -> void:
	if is_instance_valid(game):
		var playbacks: Array[WeakRef] = []
		for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
			if player.has_stream_playback():
				playbacks.append(weakref(player.get_stream_playback()))
		game.abandoned = true
		game.queue_free()
		await process_frame
		game = null
		_check(await _release_audio(playbacks), "Audio playback retained after scene teardown")
	for failure in failures:
		printerr("[HarborRaceHook] FAIL ", failure)
	if failures.is_empty():
		print(
			"[HarborRaceHook] PASS: actual race physics, position, pause, resume, reduced motion, finish"
		)
	quit(0 if failures.is_empty() else 1)


func _release_audio(playbacks: Array[WeakRef]) -> bool:
	# Scene destruction stops audio, but mixer-side fadeout retires later.
	# Observe actual playbacks without retaining them or ignoring exit errors.
	var started := Time.get_ticks_msec()
	while true:
		var pending := 0
		for playback: WeakRef in playbacks:
			if playback.get_ref() != null:
				pending += 1
		if pending == 0:
			print(
				"[HarborRaceHook] audio_release tracked=%d elapsed_ms=%d"
				% [playbacks.size(), Time.get_ticks_msec() - started]
			)
			return true
		if Time.get_ticks_msec() - started >= 2000:
			printerr("[HarborRaceHook] retained_audio_playbacks=", pending)
			return false
		OS.delay_msec(2)
		await process_frame
	return false
