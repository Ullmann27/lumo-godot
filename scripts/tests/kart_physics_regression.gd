extends SceneTree
## Rails are real walls on every course, drift has two turbo tiers, driving against the course
## is announced, and neither reversing over the line nor jumping ahead creates lap progress.
const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _start(mode: String, track: String) -> void:
	game._start_selected_race(
		{"mode": mode, "driver": "fox", "kart": "comet", "track": track, "difficulty": "flott"}
	)
	game.countdown = 0
	game.racing = true
	await process_frame


func _steer_towards(target: Vector3) -> void:
	var direction: Vector3 = target - game.player.position
	var heading: float = atan2(-direction.x, -direction.z)
	game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)


func _face(heading: float, speed: float) -> void:
	game.player_heading = heading
	game.speed = speed
	game.physical_velocity = Vector3(-sin(heading), 0, -cos(heading)) * speed


func _test_walls(track: String) -> void:
	for side in [1.0, -1.0]:
		await _start("training", track)
		var start_distance: float = game.distance
		var widest: float = 0.0
		for frame in range(300):
			# Aim far beyond the rail at full turbo speed: the worst case for tunnelling.
			_steer_towards(game.world.position_at(game.previous_road_distance + 14.0, side * 14.0))
			game.boost_time = 3.0
			game._physics_process(STEP)
			widest = maxf(widest, absf(game.lane))
		var wall: float = game.WORLD.WALL_LATERAL
		assert(
			widest <= wall + 0.02, "%s: the kart stays inside the rail (%.2f m)" % [track, widest]
		)
		assert(game.wall_contacts > 10, "%s: the rail was actually hit" % track)
		assert(game.reset_count == 0, "%s: a rail hit never drops the kart" % track)
		assert(game.distance - start_distance > 25.0, "%s: the kart slides along the rail" % track)
		print(
			(
				"[KartPhysics] %s side %+d: widest %.2f m, %d wall contacts, %.0f m along the rail"
				% [track, int(side), widest, game.wall_contacts, game.distance - start_distance]
			)
		)


func _test_drift_tiers() -> void:
	await _start("training", "sonnenhafen")
	_face(game._heading(0), 15.0)
	game.drifting = true
	for frame in range(60):
		game.steering = 1.0
		game._physics_process(STEP)
	assert(game.drift_charge >= 0.8 and game.drift_charge < 1.8, "One second of drift charges blue")
	game.boost_time = 0
	game._release_drift()
	assert(is_equal_approx(game.boost_time, 1.0) and game.drift_tier_count == [1, 0])
	assert("Blauer" in game.message.text)
	game.drifting = true
	game.drift_charge = 1.9
	game.boost_time = 0
	game._release_drift()
	assert(game.boost_time >= 1.8 and game.drift_tier_count == [1, 1], "A long drift is orange")
	game.drifting = true
	game.drift_charge = 0.5
	game.boost_time = 0
	game._release_drift()
	assert(game.boost_time == 0 and game.drift_tier_count == [1, 1], "A short drift gives nothing")


func _test_wrong_way() -> void:
	await _start("training", "sonnenhafen")
	var d: float = game.track_length * 0.25
	game.player.transform = game.world.reset_transform(d)
	game.previous_road_distance = d
	game.distance = d
	_face(game._heading(d) + PI, 12.0)
	for frame in range(150):
		_steer_towards(game.world.position_at(game.previous_road_distance - 12.0))
		game._physics_process(STEP)
	assert(game.wrong_way, "Driving backwards is detected")
	assert("Falsche Richtung" in game.message.text, "Driving backwards is announced")
	_face(game._heading(game.previous_road_distance), 12.0)
	for frame in range(30):
		_steer_towards(game.world.position_at(game.previous_road_distance + 12.0))
		game._physics_process(STEP)
	assert(not game.wrong_way, "The warning clears once the kart turns around")


func _test_lap_validity() -> void:
	await _start("time_trial", "sonnenhafen")
	_face(game._heading(0) + PI, 10.0)
	for frame in range(240):
		_steer_towards(game.world.position_at(game.previous_road_distance - 12.0))
		game._physics_process(STEP)
	assert(game.distance < 1.0 and game.checkpoint_index == 0, "Reversing over the line is no lap")
	assert(not game.finished)
	var before: float = game.distance
	game.player.position = game.world.position_at(game.track_length * 0.9)
	game._physics_process(STEP)
	assert(game.distance - before < 5.0, "Jumping ahead gives no progress")
	assert(game.checkpoint_index == 0)
	assert(not game.finished)


func _test_pedals() -> void:
	await _start("training", "sonnenhafen")
	game.auto_gas = false
	_face(game._heading(0), 0.0)
	for frame in range(60):
		game._physics_process(STEP)
	assert(game.speed < 0.5, "Without GAS the kart does not drive off")
	game.gas_held = true
	for frame in range(90):
		game._physics_process(STEP)
	assert(game.speed > 10.0, "Holding GAS accelerates (%.1f m/s)" % game.speed)
	game.gas_held = false
	game.control_brake = 1.0
	for frame in range(90):
		game._physics_process(STEP)
	assert(game.speed < 1.0, "BREMSE stops the kart")
	for frame in range(90):
		game._physics_process(STEP)
	assert(game.speed < -1.0, "Holding BREMSE while stopped reverses slowly")
	game.control_brake = 0.0
	# The pedal pad sits fully on screen without overlapping buttons.
	game._update_hud()
	await process_frame
	var screen: Rect2 = root.get_visible_rect()
	var rects: Array[Rect2] = []
	for button in [
		game.gas_button, game.brake_button, game.drift_button, game.boost_button, game.item_button
	]:
		var rect: Rect2 = button.get_global_rect()
		assert(screen.encloses(rect), "Pedal pad button on screen")
		for other in rects:
			assert(not rect.grow(-4).intersects(other), "Pad buttons do not overlap")
		rects.append(rect)
	assert(not game.joystick.get_global_rect().intersects(rects[0]), "Stick and GAS are apart")
	game.auto_gas = true


func _test_boost_response() -> void:
	await _start("training", "sonnenhafen")
	_face(game._heading(0), 5.0)
	game.steering = 0.6
	game._physics_process(STEP)
	var unboosted_delta: float = game.speed - 5.0

	await _start("training", "sonnenhafen")
	game._update_hud()
	game.muted = false
	game.host_sound_enabled = true
	game.kart_audio.set_muted(false)
	_face(game._heading(0), 5.0)
	game.steering = 0.6
	var speed_before: float = game.speed
	var effect_cursor_before: int = int(game.kart_audio.get("_effect_cursor"))
	var effect_players: Array = game.kart_audio.get("_effects")
	var boost_audio_player: AudioStreamPlayer = (
		effect_players[effect_cursor_before] as AudioStreamPlayer
	)
	var input_usec: int = Time.get_ticks_usec()
	game.boost_button._press()
	var accepted_usec: int = Time.get_ticks_usec()
	assert(game.boosts == 0 and game.boost_time == 3.2, "Touch accepts and consumes one boost")
	game._physics_process(STEP)
	var physics_usec: int = Time.get_ticks_usec()
	var speed_delta: float = game.speed - speed_before
	var feedback_visible: bool = game.player.motion_boost
	var effect_cursor_after: int = int(game.kart_audio.get("_effect_cursor"))
	assert(
		speed_delta > unboosted_delta * 1.5,
		"Boost increases speed on its first physics step (%.3f vs %.3f)" % [speed_delta, unboosted_delta]
	)
	assert(feedback_visible, "Boost flame is active on the first physics step")
	assert(
		effect_cursor_after == (effect_cursor_before + 1) % effect_players.size(),
		"Boost sound starts on accepted input"
	)
	assert(boost_audio_player.playing, "Boost sound begins on accepted input")
	assert(absf(game.player_heading - game._heading(0)) > 0.0001, "Steering remains active with boost")
	print(
		(
			"[KartBoost] input→accepted %d µs, accepted→physics %d µs, "
			+ "speed +%.3f m/s (normal +%.3f), VFX/audio active"
		)
		% [accepted_usec - input_usec, physics_usec - accepted_usec, speed_delta, unboosted_delta]
	)
	game.boost_button._release()
	var boost_time_after_first_tap: float = game.boost_time
	game.boost_button._press()
	assert(
		game.boosts == 0 and game.boost_time == boost_time_after_first_tap,
		"A second tap cannot queue an empty boost"
	)
	game.boost_button._release()


func _test_boost_gates_and_restart() -> void:
	await _start("training", "sonnenhafen")
	game.boosts = 1
	game.racing = false
	game.countdown = 1.0
	game._update_hud()
	assert(game.boost_button.disabled, "Boost is visibly locked during the countdown")
	game._boost()
	assert(game.boosts == 1 and game.boost_time == 0, "Countdown cannot queue a boost")
	game.racing = true
	game.paused = true
	game._update_hud()
	assert(game.boost_button.disabled, "Boost is visibly locked while paused")
	game._boost()
	assert(game.boosts == 1 and game.boost_time == 0, "Pause cannot queue a boost")
	game.paused = false
	game._physics_process(STEP)
	assert(game.boosts == 1 and game.boost_time == 0, "Paused input stays rejected after resume")
	game.finished = true
	game._update_hud()
	assert(game.boost_button.disabled, "Boost is visibly locked after finishing")
	game._boost()
	assert(game.boosts == 1 and game.boost_time == 0, "Finished race cannot queue a boost")
	game.finished = false
	game.boosts = 0
	game._boost()
	assert(game.boost_time == 0, "An empty boost slot cannot activate later")
	await _start("training", "sonnenhafen")
	assert(game.boosts == 1 and game.boost_time == 0, "Restart resets charges and active boost")


func _test_boost_pad_and_airborne() -> void:
	await _start("training", "sonnenhafen")
	_face(game._heading(0), 5.0)
	game.distance = game.track_length * 0.12 + 1.1
	game._track_events()
	assert(game.boost_time >= 1.0, "Crossing a boost pad activates turbo")
	var pad_speed: float = game.speed
	game._physics_process(STEP)
	assert(game.speed > pad_speed, "Boost pad accelerates on its first physics step")

	await _start("training", "sonnenhafen")
	_face(game._heading(0), 5.0)
	game.airborne = true
	game.player.position.y += 2.0
	game._boost()
	var airborne_speed: float = game.speed
	game._physics_process(STEP)
	assert(game.speed > airborne_speed, "Boost also accelerates during a ramp jump")
	assert(game.airborne, "Boost does not cancel the jump")


func _run() -> void:
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	for track in game.CATALOG.TRACKS:
		await _test_walls(str(track.id))
	await _test_drift_tiers()
	await _test_wrong_way()
	await _test_lap_validity()
	await _test_boost_response()
	await _test_boost_gates_and_restart()
	await _test_boost_pad_and_airborne()
	await _test_pedals()
	game.abandoned = true
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	print(
		(
			"[KartPhysics] PASS: rail walls on four courses at full turbo, sliding contact, "
			+ "blue/orange drift tiers, wrong-way warning, reverse line and jump-ahead give no lap, "
			+ "GAS/BREMSE pedals with reverse and an on-screen pad"
		)
	)
	# The audio mix thread releases the course music late.
	await create_timer(0.5).timeout
	quit(0)
