extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Exercise the production HUD without loading a race or changing save data.
	var race = load("res://scripts/games/kart_island.gd").new()
	race.safe_ui = Control.new()
	root.add_child(race.safe_ui)
	race.safe_ui.size = Vector2(900, 600)
	race._build_start_lights()
	race.preview_left = 0.0
	race.menu_active = false
	race.countdown = 2.8
	race._update_start_lights(0.0)
	assert(race.start_lights.visible)
	var first: StyleBox = race.start_lamps[0].get_theme_stylebox("panel")
	race._update_start_lights(0.016)
	assert(race.start_lamps[0].get_theme_stylebox("panel") == first,
		"Unchanged countdown frames must reuse lamp materials")
	race.countdown = 1.8
	race._update_start_lights(0.016)
	assert(race.countdown_label.text == "2")
	assert(race.start_lamps[1].get_theme_stylebox("panel").bg_color.r > 0.9)
	race.countdown = 0.0
	race.start_green_left = 1.0
	race._update_start_lights(0.0)
	assert(race.countdown_label.text == "LOS!")
	assert(race.start_lamps[2].get_theme_stylebox("panel").bg_color.g > 0.9)
	race.reduced_motion = true
	race._update_start_lights(0.016)
	assert(race.start_lights.scale == Vector2.ONE)
	race.paused = true
	race._update_start_lights(0.1)
	assert(not race.start_lights.visible)
	race.paused = false
	race.safe_ui.size = Vector2(400, 800)
	race._update_start_lights(0.0)
	assert(race.start_lights.position.x >= 0.0)
	race.start_green_left = 0.0
	race._update_start_lights(0.0)
	assert(not race.start_lights.visible)
	race.safe_ui.free()
	race.free()
	print("[StartLights] PASS: cached materials, red/green states, reduced motion, pause, resize")
	quit()
