extends SceneTree
## Captures are rendered by Godot, including the real UI and live geometry.

var frame_index: int = 0
var game
var samples: Array[float] = []


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	if OS.get_cmdline_user_args().has("--lightweight"):
		var config := ConfigFile.new()
		config.set_value("race", "lightweight", true)
		config.save("user://kart_preferences.cfg")
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown = 0
	game.paused = false
	game.racing = true
	game.question_index = 6
	game.modal.hide()
	game.distance = 26
	game.speed = 16
	game.message.text = "SONNENHAFEN-CUP · Neon-Stick links · Drift und Boost rechts"
	game.opponent_distances.assign([30.0, 35.0, 41.0, 50.0, 60.0])
	game._physics_process(0)
	game._update_camera(1, true)
	DirAccess.make_dir_recursive_absolute("res://exports/screenshots")


func _capture(name: String) -> void:
	var screenshot: Image = root.get_texture().get_image()
	if game.lightweight:
		name += "-lightweight"
	assert(screenshot.save_png("res://exports/screenshots/" + name + ".png") == OK)
	print("[KartRender] " + name)


func _process(delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	frame_index += 1
	if frame_index > 10:
		samples.append(delta * 1000)
	if frame_index == 20:
		_capture("sonnenhafen-race")
		game.distance = game.track_length * 0.31
		for i in range(game.opponents.size()):
			game.opponent_distances[i] = game.distance + 3 + i * 5
		game.boost_time = 3
		game._physics_process(0)
		game._update_camera(1, true)
	if frame_index == 35:
		_capture("sonnenhafen-bridge")
		game.boost_time = 0
		game._open_question()
		game._physics_process(0)
	if frame_index == 50:
		_capture("sonnenhafen-learning")
		game._skip_question()
		# A second view shows the actual modelled driver and front of the kart.
		var at: Vector3 = game.player.position
		game.camera.position = at + game.world.frame(game.distance) * Vector3(3.2, 2.0, -4.4)
		game.camera.look_at(at + Vector3.UP * 1.0)
	if frame_index == 65:
		_capture("sonnenhafen-driver")
		game._update_camera(1, true)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = game.joystick.size * 0.5 + Vector2(45, -12)
		game.joystick._gui_input(event)
		game._physics_process(0)
	if frame_index == 80:
		_capture("sonnenhafen-joystick")
		samples.sort()
		print(
			(
				"[KartRender] %s p50=%.1fms p95=%.1fms draw_calls=%d objects=%d"
				% [
					RenderingServer.get_video_adapter_name(),
					samples[samples.size() / 2],
					samples[int(samples.size() * 0.95)],
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
				]
			)
		)
		game.abandoned = true
		game.queue_free()
		quit(0)
	return false
