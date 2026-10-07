extends SceneTree
## Actual runtime captures of the rival item feedback added in this branch.

var scene: PackedScene
var game
var shots: Array[String] = ["01_held_pulse", "02_pulse_warning", "03_rival_shield", "04_pulse_wave"]
var shot_index: int = 0
var frame_index: int = 0
var out_dir: String = "res://exports/rival-feedback"


func _initialize() -> void:
	call_deferred("_setup")


func _setup() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.lightweight = false
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich",
		}
	)
	game.set_physics_process(false)
	game.countdown = 0.0
	game.racing = true
	await process_frame
	_prepare_common()
	_apply_shot()


func _prepare_common() -> void:
	var d: float = game.track_length * 0.12
	game.distance = d
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(d, 0.0)
	game.player.position.y += 0.035
	game.player_heading = game._heading(d)
	var rival_d: float = d + 7.0
	game.opponent_distances[0] = rival_d
	game.opponent_lanes[0] = 0.7
	game.opponents[0].transform = game.world.reset_transform(rival_d, 0.7)
	game.opponent_headings[0] = game._heading(rival_d)
	game.camera.fov = 56
	var midpoint: Vector3 = (game.player.position + game.opponents[0].position) * 0.5
	game.camera.position = midpoint + game.world.frame(d) * Vector3(7.6, 4.6, 11.8)
	game.camera.look_at(midpoint + Vector3.UP * 1.1)
	game.safe_ui.visible = true
	game.message.text = ""


func _apply_shot() -> void:
	game.opponent_items[0] = ""
	game.opponent_shield_times[0] = 0.0
	game.opponent_pulse_warning_times[0] = 0.0
	game.opponent_stuns[0] = 0.0
	game.opponent_item_fx[0].set_item("")
	game.opponent_item_fx[0].set_shield(0.0)
	game.opponent_item_fx[0].set_pulse_warning(0.0, game.RIVAL_PULSE_WARNING_SECONDS)

	match shots[shot_index]:
		"01_held_pulse":
			game.opponent_items[0] = "pulse"
			game._sync_rival_item_fx(0)
			game.message.text = "Rivale hat einen Lichtimpuls."
		"02_pulse_warning":
			game.opponent_items[0] = "pulse"
			game._update_rival_item_tactics(
				0,
				game.player.position - game.opponents[0].position,
				0.01
			)
		"03_rival_shield":
			game.opponent_items[0] = "shield"
			game._update_rival_item_tactics(
				0,
				game.player.position - game.opponents[0].position,
				0.01
			)
			game.message.text = "Rivale aktiviert Sternenschild."
		"04_pulse_wave":
			game.opponent_items[0] = "pulse"
			game._update_rival_item_tactics(
				0,
				game.player.position - game.opponents[0].position,
				0.01
			)
			game._update_rival_item_tactics(
				0,
				game.player.position - game.opponents[0].position,
				1.0
			)
	frame_index = 0


func _process(_delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	frame_index += 1
	if frame_index == 10:
		var name: String = shots[shot_index]
		var image := root.get_texture().get_image()
		assert(image.get_width() == 1280 and image.get_height() == 720)
		assert(image.save_png(out_dir + "/" + name + ".png") == OK)
		print("[KartRivalShots] captured ", name)
		shot_index += 1
		if shot_index >= shots.size():
			print("[KartRivalShots] PASS: 4 real runtime frames at 1280x720")
			game.abandoned = true
			game.queue_free()
			quit(0)
		else:
			_apply_shot()
	return false
