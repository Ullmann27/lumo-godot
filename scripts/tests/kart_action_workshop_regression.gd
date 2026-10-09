extends SceneTree
const GAME = "res://scenes/games/kart_island.tscn"
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
var game


func _initialize() -> void:
	call_deferred("_run")


func _settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture(file: String) -> void:
	await _settle()
	if DisplayServer.get_name() != "headless":
		assert(
			(
				root.get_texture().get_image().save_png(
					"res://exports/action-workshop/" + file + ".png"
				)
				== OK
			)
		)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://exports/action-workshop")
	game = load(GAME).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	root.size = Vector2i(1280, 720)
	var garage = game.garage
	garage.workshop = TUNING.new("action_workshop_qa", 500)
	garage.workshop.save_enabled = false
	garage.step = 2
	garage._refresh()
	await _settle()
	garage.workshop_button.pressed.emit()
	await _settle()
	var view = garage.workshop_view
	var before: Dictionary = POWERTRAIN.report(view.tuning.multipliers("comet"))
	for part in ["motor", "bremsen", "turbo"]:
		view._on_upgrade(part)
	var after: Dictionary = POWERTRAIN.report(view.tuning.multipliers("comet"))
	assert(after.top_kmh > before.top_kmh and after.zero_fifty < before.zero_fifty)
	assert(after.brake_metres < before.brake_metres and after.boost_seconds > before.boost_seconds)
	view.set_process(false)
	view.dyno_button.pressed.emit()
	for frame in range(120):
		view._process(1.0 / 60.0)
	assert(view.dyno_speed > 15.0 and "km/h" in view.dyno_button.text)
	await _capture("01-workshop-pruefstand")
	for frame in range(240):
		view._process(1.0 / 60.0)
	assert(view.dyno_time == 0.0 and view.dyno_speed == 0.0)
	assert(view.tuning.spent_on_parts() == 12, "A dyno run never charges stars")
	garage.handle_back()
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "flott"
		}
	)
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	await _settle()
	assert(game.world.action_obstacles.size() == 6)
	var aquarium = game.world.get_node("HarborAquarium")
	assert(aquarium.fish.size() == 4 and aquarium.has_node("AquariumGlass"))
	var fish_before: Vector3 = aquarium.fish[0].position
	aquarium._process(0.5)
	assert(not fish_before.is_equal_approx(aquarium.fish[0].position))
	# Actual gameplay collision, immunity and a clear central driving line.
	game.player.position = game.world.action_obstacles[0]
	game.speed = 20.0
	game.hit_timer = 0.0
	game._track_events()
	assert(game.speed < 20.0 and game.hit_timer > 0.0)
	game.speed = 20.0
	game.hit_timer = 0.0
	game.shield_time = 2.0
	game._track_events()
	assert(game.speed == 20.0)
	game.shield_time = 0.0
	game.message.text = ""
	for obstacle in game.world.action_obstacles:
		var road: Dictionary = game.world.sample_road(obstacle)
		assert(absf(float(road.lateral)) >= 3.5)
	# Capture real game geometry and HUD from the actual chase camera.
	for section in [{"d": 0.30, "name": "02-hafen-slalom"}, {"d": 0.53, "name": "03-aquarium"}]:
		var distance: float = game.track_length * float(section.d)
		game.player.transform = game.world.reset_transform(distance)
		game.player_heading = game._heading(distance)
		game.previous_road_distance = distance
		game.distance = distance
		game.speed = 0.0
		game.physical_velocity = Vector3.ZERO
		for frame in range(100):
			game._update_camera(1.0 / 60.0)
		game._update_hud()
		await _capture(str(section.name))
	game.abandoned = true
	game.queue_free()
	await _settle()
	await create_timer(1.2).timeout
	print(
		"[ActionWorkshop] PASS: drivetrain, upgrades, free dyno, braking, cones, shield, aquarium"
	)
	quit(0)
