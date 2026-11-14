extends SceneTree
## Controlled presentation states inside the production race scene.
## Drift release, ground contact and item award use production event methods.
## LUMO_CAPTURE_DIR=... godot --path . --script scripts/tests/kart_drive_feedback_capture.gd

var game
var output: String
var along: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error(
			"[KartDriveFeedbackCapture] Real renderer required; headless images are not evidence"
		)
		quit(1)
		return
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	if output.is_empty():
		push_error("[KartDriveFeedbackCapture] Set LUMO_CAPTURE_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.get_node("SceneRouter").launch_options = {"childKey": "drive-feedback-capture"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	game.graphics_profile = "high"
	await process_frame
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game._end_preview(false)
	game.reduced_motion = false
	game.speed = 24.0
	along = game.track_length * 0.08
	_place(along)
	game._update_vehicles(0.0)
	game._update_hud()
	await _shot("00_baseline")
	game.drifting = true
	game.steering = 0.7
	game.drift_charge = game.DRIFT_TIERS[0] + 0.1
	_drive_path(18)
	game.message.text = "Blauer Drift · bereit"
	await _shot("01_blue_drift")
	game.drift_charge = game.DRIFT_TIERS[1] + 0.1
	_drive_path(18)
	game.message.text = "Oranger Drift · voller Schub"
	await _shot("02_orange_drift")
	game._release_drift()
	_drive_path(8)
	await _shot("03_drift_release")
	game.drive_feedback.reset()
	game.boost_time = 0.0
	game.steering = 0.0
	along = 10.0
	_place(along)
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	game.player.position.y = float(road.height) + 0.035
	game.airborne = true
	game.vertical_speed = -9.0
	game.air_time = 0.5
	game.precision_kicker = {}
	game._move_vertically(road, float(road.distance), 1.0 / 60.0)
	for _i in range(10):
		game._update_vehicles(1.0 / 60.0)
	await _shot("04_landing")
	game.drive_feedback.reset()
	game.boost_time = 0.0
	game.item = ""
	game.airborne = false
	game.speed = 24.0
	along = game.item_box_distances[0]
	game.lane = game.item_box_laterals[0]
	_place(along, game.lane)
	game._track_events()
	for _i in range(13):
		game._update_vehicles(1.0 / 60.0)
	await _shot("05_item_pickup")
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("[KartDriveFeedbackCapture] PASS six production-scene frames at 1280x720")
	quit(0)


func _place(distance: float, lane: float = 0.0) -> void:
	game.distance = distance
	game.previous_road_distance = distance
	game.lane = lane
	game.player.transform = game.world.reset_transform(distance, lane)
	game.player.position.y += 0.035
	game.player_heading = game._heading(distance)


func _drive_path(steps: int) -> void:
	for _i in range(steps):
		along += 0.4
		_place(along)
		if game.drifting:
			game.player.rotate_object_local(Vector3.UP, 0.24)
		game._update_vehicles(1.0 / 60.0)


func _shot(label: String) -> void:
	game._update_camera(1.0, true)
	game._update_hud()
	for _i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.get_size() != Vector2i(1280, 720):
		push_error("[KartDriveFeedbackCapture] Missing or wrong-sized rendered frame")
		quit(1)
		return
	if picture.save_png(output.path_join(label + ".png")) != OK:
		push_error("[KartDriveFeedbackCapture] Cannot write " + label)
		quit(1)
		return
	print(
		"[KartDriveFeedbackCapture] ",
		label,
		" ",
		JSON.stringify(game.drive_feedback.visual_state())
	)
