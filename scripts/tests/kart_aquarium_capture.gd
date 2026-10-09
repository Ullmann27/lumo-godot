extends SceneTree
## Six actual chase-camera views after short physics-driven approaches, LOW and HIGH.
## This is visual evidence for the aquarium, not a complete-lap or physical-device probe.

const GAME = "res://scenes/games/kart_island.tscn"
const AQUARIUM = preload("res://scripts/games/kart_harbor_aquarium.gd")
const STEP: float = 1.0 / 60.0

var game
var output: String = "res://exports/aquarium-proof"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	call_deferred("_run")


func _settle() -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw


func _start(lightweight: bool) -> void:
	game.lightweight = lightweight
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "flott"
		}
	)
	game._end_preview()
	await _settle()
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	assert(game.world.low_detail == lightweight, "Capture must use its declared detail level")
	game.world.get_node("HarborAquarium").set_process(false)


func _shot(name: String, passage_distance: float) -> void:
	var target_distance: float = game.track_length * AQUARIUM.START + passage_distance
	var start_distance: float = target_distance - 6.0
	game.distance = start_distance
	game.previous_road_distance = start_distance
	game.player.transform = game.world.reset_transform(start_distance)
	game.player_heading = game._heading(start_distance)
	game.player.rotation = Vector3(0, game.player_heading, 0)
	game.speed = 15.0
	game.physical_velocity = (
		Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * game.speed
	)
	game.airborne = false
	for frame in range(100):
		game._update_camera(STEP)
	var aquarium = game.world.get_node("HarborAquarium")
	var driven_metres: float = 0.0
	for frame in range(120):
		var target: Vector3 = game.world.position_at(game.previous_road_distance + 8.0)
		var direction: Vector3 = target - game.player.position
		game.steering = clampf(
			-angle_difference(game.player_heading, atan2(-direction.x, -direction.z)) * 2.3,
			-1.0,
			1.0
		)
		game._physics_process(STEP)
		aquarium._process(STEP)
		driven_metres = game.previous_road_distance - start_distance
		if driven_metres >= 6.0:
			break
		if frame % 10 == 0:
			await process_frame
	assert(driven_metres >= 6.0, "Capture must follow real forward driving through the passage")
	game._update_hud()
	await _settle()
	var captured: Image = root.get_texture().get_image()
	assert(captured.get_size() == Vector2i(1280, 720))
	assert(captured.save_png(output.path_join(name + ".png")) == OK)
	print("[KartAquariumCapture] %s: 1280x720, %.2f metres driven" % [name, driven_metres])


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[KartAquariumCapture] A real rendering display is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load(GAME).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await _settle()
	for lightweight in [true, false]:
		await _start(lightweight)
		var prefix: String = "low" if lightweight else "high"
		var first: int = 1 if lightweight else 4
		await _shot("%02d-%s-entry" % [first, prefix], 2.0)
		await _shot("%02d-%s-middle" % [first + 1, prefix], 15.0)
		await _shot("%02d-%s-exit" % [first + 2, prefix], 28.0)
	game.abandoned = true
	game.queue_free()
	await _settle()
	await create_timer(1.3).timeout
	print("[KartAquariumCapture] PASS: six actual chase-camera views, LOW/HIGH")
	quit(0)
