extends SceneTree
## Real OpenGL frames of the Sonnenhafen precision stunt sequence: loop run-up,
## loop exit towards the ramp, the speed hint in red/green/orange in the actual
## race HUD, take-off, mid-air over the open gap, landing zone, and a short jump.
## Everything is driven through kart_island._physics_process; no mockups.
const STUNT = preload("res://scripts/games/kart_sonnenhafen_stunt_sequence.gd")
const PRECISION = preload("res://scripts/games/kart_precision_jump.gd")
const STEP: float = 1.0 / 60.0
var game
var output: String
var shots: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path: String = output.path_join(name + ".png")
	assert(frame.save_png(path) == OK)
	shots.append(name)
	print("[PrecisionCapture] saved ", path)


func _place(at: float, lateral: float, speed: float) -> void:
	game.distance = at
	game.previous_road_distance = at
	game.player.transform = game.world.reset_transform(at, lateral)
	game.player_heading = game._heading(at)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = speed
	game.physical_velocity = Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * speed
	game.airborne = false
	game.boost_time = 0.0
	game.steering = 0.0


func _look(from: Vector3, at: Vector3, fov: float = 62.0) -> void:
	var cam: Camera3D = game.camera
	cam.far = 1500.0
	cam.fov = fov
	cam.position = from
	cam.look_at(at, Vector3.UP)


func _chase_frames(count: int) -> void:
	for i in range(count):
		game._physics_process(STEP)


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Real OpenGL render required")
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	await process_frame
	game._start_selected_race({
		"mode": "training", "driver": "fox", "kart": "comet",
		"track": "sonnenhafen", "difficulty": "flott"
	})
	game._end_preview()
	await process_frame
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = false
	var world = game.world
	var layout: Dictionary = world.loop_layout
	var kicker: Dictionary = {}
	for candidate in world.action.kickers:
		if bool(candidate.get("precision_jump", false)):
			kicker = candidate
	assert(not kicker.is_empty())
	var loop_start: float = float(layout.start)
	var take_off: float = float(kicker.take_off)
	# 1) Loop with its run-up, seen from behind the approach, high and to the left.
	_place(loop_start - 60.0, 2.9, 20.0)
	game.safe_ui.visible = false
	var p: Vector3 = world.position_at(loop_start - 46.0, -9.0)
	_look(p + Vector3.UP * 14.0, world.position_at(loop_start + 4.0, 2.9) + Vector3.UP * 7.0)
	await _capture("01_loop_runup_overview")
	# 2) Loop exit to ramp: the 80 m straight with sign, arrows and ramp.
	p = world.position_at(loop_start + 14.0, 7.5)
	_look(p + Vector3.UP * 6.0, world.position_at(float(kicker.start) + 4.0) + Vector3.UP * 1.5, 55.0)
	await _capture("02_loop_exit_to_ramp")
	# 3) Side view of the ramp, gap and landing zone.
	var mid: float = take_off + float(kicker.landing_min) * 0.5
	var side: Vector3 = world.position_at(mid - 16.0, -17.0)
	_look(side + Vector3.UP * 16.0, world.position_at(mid + 2.0) + Vector3.UP * 0.5, 64.0)
	await _capture("03_ramp_gap_landing_side")
	# 4-6) Real race HUD with the speed hint at three speeds (actual chase camera).
	game.safe_ui.visible = true
	var hint_speeds: Array = [["04_hint_red_gib_gas", 12.0], ["05_hint_green_tempo_passt", float(kicker.rival_speed)],
		["06_hint_orange_etwas_bremsen", 30.0]]
	for entry in hint_speeds:
		_place(float(kicker.start) - 55.0, 0.0, float(entry[1]))
		game.auto_gas = false
		game.gas_held = false
		for i in range(45):
			game.speed = float(entry[1])
			game._physics_process(STEP)
		game.speed = float(entry[1])
		game._update_hud()
		assert(game.jump_hint.visible)
		print("[PrecisionCapture] %s: %.1f m/s -> %s (predicted %.1f m)" % [entry[0], float(entry[1]), game.jump_hint.text, game.jump_hint.predicted])
		await _capture(str(entry[0]))
	# 7-8) Real reference-speed flight: mid-air over the gap, then the landing.
	_place(take_off - 1.0, 0.0, float(kicker.rival_speed))
	var mid_air_done: bool = false
	for frame in range(200):
		game._physics_process(STEP)
		if game.airborne and game.air_time > 0.45 and not mid_air_done:
			mid_air_done = true
			await _capture("07_midair_over_gap_chase")
			var kart: Vector3 = game.player.position
			var saved: Transform3D = game.camera.transform
			_look(kart + world.frame(game.previous_road_distance).x * 16.0 + Vector3.UP * 2.0, kart, 58.0)
			game.safe_ui.visible = false
			await _capture("08_midair_over_gap_side")
			game.safe_ui.visible = true
			game.camera.transform = saved
		if mid_air_done and not game.airborne:
			_chase_frames(4)
			print("[PrecisionCapture] landing: %s after %.2f m" % [game.last_precision_landing, game.last_precision_flown])
			await _capture("09_landing_in_zone")
			break
	# 10) Too slow: the kart drops into the open gap (before the cloud rescue).
	_place(take_off - 1.0, 0.0, 11.0)
	for frame in range(200):
		game._physics_process(STEP)
		var road: Dictionary = world.sample_road(game.player.position, game.previous_road_distance)
		if game.airborne and game.player.position.y < float(road.height) - 1.2:
			var kart: Vector3 = game.player.position
			game.safe_ui.visible = false
			_look(kart + world.frame(game.previous_road_distance).x * 15.0 + Vector3.UP * 4.0, kart, 58.0)
			await _capture("10_too_slow_falls_into_gap")
			break
	assert(shots.size() == 10, "Every precision-jump state must be captured")
	# AudioStreamPlayer.stop() hands playback release to the audio thread.
	# Quitting after one scene-tree frame can strand the Ogg stream and packet
	# sequence even though the game is freed. Keep only weak references and
	# require the actual streams to disappear before the strict exit check.
	var audio_streams: Array[WeakRef] = []
	for audio_player in game.find_children("*", "AudioStreamPlayer", true, false):
		if audio_player.stream != null:
			audio_streams.append(weakref(audio_player.stream))
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = null
	var release_deadline: int = Time.get_ticks_msec() + 2000
	for stream in audio_streams:
		while stream.get_ref() != null and Time.get_ticks_msec() < release_deadline:
			await process_frame
		assert(stream.get_ref() == null, "AudioServer must release the captured game's audio streams")
	await process_frame
	print("[PrecisionCapture] released %d audio streams" % audio_streams.size())
	print("[PrecisionCapture] PASS: %d frames" % shots.size())
	quit(0)
