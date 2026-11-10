extends SceneTree
## Runtime before/after shots of player and rival item / speed effects.
## Usage: godot --script scripts/tests/kart_item_effects_capture.gd -- <out_dir>

var game
var out_dir: String = "res://exports/item-effects"


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _settle(10)
	var image: Image = root.get_texture().get_image()
	assert(image.get_width() == 1280 and image.get_height() == 720)
	assert(image.save_png(out_dir + "/" + name + ".png") == OK)
	print("[KartItemShots] captured ", name)


func _place_on_track() -> void:
	var d: float = game.track_length * 0.12
	game.distance = d
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(d, 0.0)
	game.player.position.y += 0.035
	game.player_heading = game._heading(d)
	game.previous_road_distance = fposmod(d, game.track_length)
	var rival_d: float = d + 7.0
	game.opponent_distances[0] = rival_d
	game.opponent_lanes[0] = 0.7
	game.opponents[0].transform = game.world.reset_transform(rival_d, 0.7)
	game.opponent_headings[0] = game._heading(rival_d)
	var midpoint: Vector3 = (game.player.position + game.opponents[0].position) * 0.5
	game.camera.position = midpoint + game.world.frame(d) * Vector3(7.6, 4.6, 11.8)
	game.camera.look_at(midpoint + Vector3.UP * 1.1)
	game.camera.fov = 56
	game.safe_ui.visible = true
	game.message.text = ""


func _clear_rival() -> void:
	game.opponent_items[0] = ""
	game.opponent_shield_times[0] = 0.0
	game.opponent_pulse_warning_times[0] = 0.0
	game.opponent_stuns[0] = 0.0
	game.opponent_item_fx[0].set_item("")
	game.opponent_item_fx[0].set_shield(0.0)
	game.opponent_item_fx[0].set_pulse_warning(0.0, game.RIVAL_PULSE_WARNING_SECONDS)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.lightweight = false
	await process_frame
	game._start_selected_race({
		"mode": "race",
		"driver": "fox",
		"kart": "comet",
		"track": "sonnenhafen",
		"difficulty": "gemuetlich",
	})
	game.set_physics_process(false)
	game.countdown = 0.0
	game.racing = true
	await process_frame
	_place_on_track()

	game.item = "boost"
	game._use_item()
	game.speed = 22.0
	if is_instance_valid(game.speed_fx):
		game.speed_fx.set_motion(0.95, true, false)
	game.message.text = "Rückenwind!"
	await _shot("01_player_boost")

	game.boost_time = 0.0
	if is_instance_valid(game.speed_fx):
		game.speed_fx.set_motion(0.2, false, false)
	game.item = "shield"
	game._use_item()
	game.message.text = "Sternenschild."
	await _shot("02_player_shield")

	game.shield_time = 0.0
	if is_instance_valid(game.shield_visual):
		game.shield_visual.visible = false
	game.item = "pulse"
	game._use_item()
	game.pulse_age = 0.18
	if is_instance_valid(game.pulse_visual):
		game.pulse_visual.visible = true
		game.pulse_visual.scale = Vector3.ONE * (1.0 + game.pulse_age * 22.0)
	game.message.text = "Lichtimpuls!"
	await _shot("03_player_pulse")

	game.pulse_age = 2.0
	if is_instance_valid(game.pulse_visual):
		game.pulse_visual.visible = false
	_clear_rival()
	game.opponent_items[0] = "pulse"
	game._sync_rival_item_fx(0)
	game.message.text = "Rivale hat einen Lichtimpuls."
	await _shot("04_rival_held_pulse")

	_clear_rival()
	game.opponent_items[0] = "pulse"
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, 0.01)
	await _shot("05_rival_pulse_warning")

	_clear_rival()
	game.opponent_items[0] = "shield"
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, 0.01)
	game.message.text = "Rivale aktiviert Sternenschild."
	await _shot("06_rival_shield")

	_clear_rival()
	game.opponent_items[0] = "pulse"
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, 0.01)
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, 1.0)
	await _shot("07_rival_pulse_wave")

	print("[KartItemShots] PASS: 7 real runtime frames at 1280x720 in ", out_dir)
	game.abandoned = true
	game.queue_free()
	quit(0)
