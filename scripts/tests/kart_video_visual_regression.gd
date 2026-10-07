extends SceneTree
## Runtime acceptance for the chase-camera / lighting direction from Heinz' video references.
## Captures are real Godot frames, not the reference videos and not pre-rendered mockups.

const VISUAL_GRADE = preload("res://scripts/games/kart_visual_grade.gd")

var scene: PackedScene
var game
var out_dir := "res://exports/video-reference-grade"


func _initialize() -> void:
	call_deferred("_run")


func _environment(world) -> Environment:
	for child in world.get_children():
		if child is WorldEnvironment:
			return (child as WorldEnvironment).environment
	return null


func _place(track: String, fraction: float, lane: float, speed_value: float, boosting: bool) -> void:
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": track,
			"difficulty": "flott",
		}
	)
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game.distance = game.track_length * fraction
	game.lane = lane
	game.speed = speed_value
	game.boost_time = 2.0 if boosting else 0.0
	game.player.transform = game.world.reset_transform(game.distance, lane)
	game.player_heading = game._heading(game.distance)
	game.message.text = ""
	game._update_camera(1.0, true)
	game._update_vehicles(0.0)
	game._update_hud()


func _capture(name: String) -> void:
	for _frame in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	assert(image.get_width() == 1280 and image.get_height() == 720)
	assert(image.save_png(out_dir + "/" + name + ".png") == OK)
	print("[KartVideoGrade] captured ", name)


func _validate_grade(track: String) -> void:
	var visual: Dictionary = VISUAL_GRADE.environment_profile(track, false)
	var env: Environment = _environment(game.world)
	assert(env != null, "Track needs a WorldEnvironment")
	assert(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC)
	assert(env.glow_enabled == bool(visual.glow))
	assert(env.adjustment_enabled)
	assert(env.adjustment_contrast >= 1.07)
	assert(env.adjustment_saturation >= 1.07)
	var road_material := game.world.road.material_override as ShaderMaterial
	assert(road_material != null)
	assert(float(road_material.get_shader_parameter("cinematic_grade")) >= 0.9)
	assert(float(road_material.get_shader_parameter("road_gloss")) >= 0.8)
	assert(float(road_material.get_shader_parameter("edge_energy")) > 0.35)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	await process_frame

	# High-speed Holo City chase: large kart, luminous course, bounded boost FOV.
	_place("holo_city", 0.61, 0.35, 22.0, false)
	_validate_grade("holo_city")
	var horizontal: Vector2 = Vector2(
		game.camera.position.x - game.player.position.x,
		game.camera.position.z - game.player.position.z
	)
	assert(horizontal.length() >= VISUAL_GRADE.CAMERA_DISTANCE_NEAR - 0.2)
	assert(horizontal.length() <= VISUAL_GRADE.CAMERA_DISTANCE_FAST + 0.35)
	assert(game.camera.position.y - game.player.position.y < 3.4)
	var base_fov: float = game.camera.fov
	assert(base_fov >= VISUAL_GRADE.BASE_FOV and base_fov <= VISUAL_GRADE.SPEED_FOV + 0.5)
	await _capture("01_holo_city_chase")

	game.boost_time = 2.0
	game.speed = 25.0
	game._update_camera(1.0, true)
	assert(game.camera.fov >= VISUAL_GRADE.BOOST_FOV - 0.5)
	assert(game.camera.fov > base_fov + 6.0)
	var boost_fx: Dictionary = game.speed_fx.visual_state()
	assert(bool(boost_fx.boosting))
	assert(int(boost_fx.visible_count) >= 10, "Boost must add readable camera-local speed streaks.")
	await _capture("02_holo_city_boost")

	# Himmelsinseln uses its own Environment path; it must receive the same grade.
	_place("bergwelt", 0.83, -0.7, 21.0, false)
	_validate_grade("bergwelt")
	await _capture("03_himmelsinseln_chase")

	# The same material/light system must cover the bright and forest worlds too.
	_place("sonnenhafen", 0.38, 0.2, 20.0, false)
	_validate_grade("sonnenhafen")
	await _capture("04_sonnenhafen_chase")

	_place("zauberwald", 0.34, -0.35, 19.0, false)
	_validate_grade("zauberwald")
	await _capture("05_zauberwald_chase")

	# Reduced motion must keep a steady baseline view rather than speed-punching the camera.
	game.reduced_motion = true
	game.speed = 25.0
	game.boost_time = 2.0
	game._update_camera(1.0, true)
	assert(absf(game.camera.fov - VISUAL_GRADE.BASE_FOV) < 0.5)
	assert(int(game.speed_fx.visual_state().visible_count) == 0)
	await _capture("06_reduced_motion")

	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[KartVideoGrade] PASS: close chase framing, glossy emissive road, filmic glow/contrast, bounded boost FOV")
	await create_timer(0.12).timeout
	quit(0)
