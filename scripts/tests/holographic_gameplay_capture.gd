extends SceneTree
## Actual game/menu rendering. The demonstration driver supplies steering only;
## unmodified game physics run at 60 Hz. This is not an Android FPS benchmark.

var game
var frame_index: int = 0
var short_capture: bool = false
var tap_release: Vector2 = Vector2(-1, -1)


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	short_capture = OS.get_cmdline_user_args().has("--stills")
	DirAccess.make_dir_recursive_absolute("res://exports/holographic-proof")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.reduced_motion = true


func _tap(control: Control) -> void:
	if not control.is_visible_in_tree() or not root.get_visible_rect().encloses(control.get_global_rect()):
		push_error("Requested menu action is outside the actual visible viewport")
		quit(1)
		return
	tap_release = control.get_global_rect().get_center()
	var event := InputEventScreenTouch.new()
	event.index = 8
	event.position = tap_release
	event.pressed = true
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	var capture: Image = root.get_texture().get_image()
	assert(capture.save_png("res://exports/holographic-proof/" + label + ".png") == OK)
	print("[HolographicCapture] ", label)


func _process(_delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	frame_index += 1
	if tap_release.x >= 0:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.position = tap_release
		event.pressed = false
		Input.parse_input_event(event)
		tap_release = Vector2(-1, -1)
	if frame_index in [25, 85, 145, 205, 265]:
		var expected_step: int = (frame_index - 25) / 60
		if not game.menu_active or game.garage.step != expected_step:
			push_error("Actual setup touch did not advance to step %d" % expected_step)
			quit(1)
			return true
		_capture(["menu", "driver", "kart", "tracks", "difficulty"][(frame_index - 25) / 60])
	if frame_index in [60, 120, 180, 240, 300]:
		assert(game.menu_active, "The real setup flow must stay active until Start")
		_tap(game.garage.next_button)
	if not game.menu_active and not game.finished:
		for substep in range(2):
			var target: Vector3 = game.world.position_at(game.previous_road_distance + 10, 0)
			var direction: Vector3 = target - game.player.position
			var heading: float = atan2(-direction.x, -direction.z)
			game.steering = clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1)
			game._physics_process(1.0 / 60.0)
	if frame_index in [430, 650, 900]:
		if game.menu_active:
			push_error("The real menu flow did not start a race")
			quit(1)
			return true
		_capture("race-%04d" % frame_index)
	if frame_index == 600:
		_tap(game.boost_button)
	if (short_capture and frame_index == 660) or frame_index >= 1020:
		var proof := {
			"capture": "actual Godot desktop game and GUI",
			"renderer": RenderingServer.get_video_adapter_name(),
			"size": [1280, 720],
			"movie_fps": 30,
			"physics_hz": 60,
			"driver": "automated steering input; no position/physics modifications",
			"race_seconds": game.elapsed,
			"distance_m": game.distance,
			"resets": game.reset_count,
			"graphics_profile": game.graphics_profile,
			"android_performance_measurement": false,
		}
		var file := FileAccess.open("res://exports/holographic-proof/capture.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(proof, "  "))
		file.close()
		game.abandoned = true
		call_deferred("_finish_capture")
	return false


func _finish_capture() -> void:
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	quit(0)
