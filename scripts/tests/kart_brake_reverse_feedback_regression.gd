extends SceneTree
## Standard Auto-Gas must still allow intentional reverse after a held brake,
## and braking must have visible feedback on the player's kart.

const STEP: float = 1.0 / 60.0
var game


func _initialize() -> void:
	call_deferred("_run")


func _has_property(object: Object, property_name: String) -> bool:
	for info in object.get_property_list():
		if str(info.name) == property_name:
			return true
	return false


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich",
		}
	)
	game.countdown = 0.0
	game.racing = true
	await process_frame
	assert(game.auto_gas, "Default child-friendly profile must exercise Auto-Gas.")

	var heading: float = game._heading(0.0)
	game.player_heading = heading
	game.speed = 8.0
	game.physical_velocity = Vector3(-sin(heading), 0, -cos(heading)) * game.speed
	game.control_brake = 1.0
	for frame in range(240):
		game._physics_process(STEP)
	assert(
		game.speed < -1.0,
		"Holding BREMSE after stopping must intentionally engage slow reverse even with Auto-Gas."
	)

	assert(
		_has_property(game.player, "brake_lights"),
		"Player kart needs visible brake-light feedback, not only a speed change."
	)
	assert(game.player.brake_lights.size() == 2)
	game._update_vehicles(STEP)
	game.player._process(STEP)
	for light in game.player.brake_lights:
		assert(light.visible, "Brake lights stay visible while the brake is held.")

	# Explicit GAS wins over reverse engagement so simultaneous right-thumb
	# input cannot accidentally select reverse.
	game.speed = 0.0
	game.physical_velocity = Vector3.ZERO
	game.gas_held = true
	game.control_brake = 1.0
	for frame in range(90):
		game._physics_process(STEP)
	assert(game.speed >= -0.05, "Manual GAS prevents accidental reverse while braking.")
	game.gas_held = false
	game.control_brake = 0.0
	game._physics_process(STEP)
	game._update_vehicles(STEP)
	game.player._process(STEP)
	for light in game.player.brake_lights:
		assert(not light.visible, "Brake lights turn off after release.")

	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[KartBrakeReverse] PASS: Auto-Gas reverse, manual-GAS interlock, two visible brake lights")
	await create_timer(0.1).timeout
	quit(0)
