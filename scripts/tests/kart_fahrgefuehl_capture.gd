extends SceneTree
## Bildfolgen mit echtem Renderer für das Fahrgefühl: Drift, Landung, Turbo,
## Pfütze, Bordstein und Rempler, jeweils über die echten Hooks des Rennens
## gefahren und als JPG-Folge (Querformat) gespeichert. Die Kamera-Körpersprache
## (kart_fx_camera_rig) liegt wie im Spiel zur Bildzeit auf der Rennkamera.
## LUMO_CAPTURE_DIR=/abs/ordner xvfb-run -a -s '-screen 0 1600x1600x24' godot --path . \
##   --rendering-method gl_compatibility --audio-driver Dummy \
##   --script res://scripts/tests/kart_fahrgefuehl_capture.gd

const STEP := 1.0 / 60.0
const SIZE := Vector2i(1280, 720)
const GROUND = preload("res://scripts/games/kart_fx/kart_fx_ground.gd")

var game
var fx
var output: String
var along: float = 0.0
var report: Dictionary = {}
var shots: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[KartFahrgefuehlCapture] Real renderer required")
		quit(1)
		return
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	if output.is_empty():
		push_error("[KartFahrgefuehlCapture] Set LUMO_CAPTURE_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = SIZE
	root.get_node("SceneRouter").launch_options = {"childKey": "fahrgefuehl-capture"}
	await _start("sonnenhafen")
	await _drift()
	await _landing()
	await _boost()
	await _puddle()
	await _kerb()
	await _contact()
	await _end()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[KartFahrgefuehlCapture] PASS %d Bilder in %s" % [shots, output])
	quit(0)


func _start(track: String) -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	game.graphics_profile = "high"
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": track,
			"difficulty": "gemuetlich"
		}
	)
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game._end_preview(false)
	game.reduced_motion = false
	game.auto_gas = false
	fx = game.drive_fx
	for rival in game.opponents:
		rival.visible = false
	await process_frame
	await process_frame


func _end() -> void:
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout


func _place(distance: float, lane: float) -> void:
	game.distance = distance
	game.previous_road_distance = distance
	game.lane = lane
	var placed: Transform3D = game.world.reset_transform(distance, 0.0)
	placed.origin += placed.basis.x.normalized() * lane
	game.player.transform = placed
	game.player.position.y += 0.035
	game.player_heading = game._heading(distance)


func _clean(speed: float, start: float) -> void:
	game.paused = false
	fx.reset()
	fx.counts.clear()
	game.speed = speed
	game.boost_time = 0.0
	game.drifting = false
	game.drift_charge = 0.0
	game.brake_visual_amount = 0.0
	game.airborne = false
	game.steering = 0.0
	game.lane = 0.0
	fx._previous_speed = speed
	fx._accel = 0.0
	fx._previous_gas = false
	along = start
	_place(along, 0.0)
	game._update_camera(0.0, true)


## One driven tick through the race's own vehicle/effects/camera update.
func _tick(speed_change: float = 0.0, spin: float = 0.0) -> void:
	game.speed = maxf(0.0, game.speed + speed_change)
	along += maxf(0.05, game.speed * STEP)
	_place(along, game.lane)
	if spin != 0.0:
		game.player.rotate_object_local(Vector3.UP, spin)
	game._update_vehicles(STEP)
	game._update_camera(STEP)


func _shot(label: String) -> void:
	# Not paused: the camera body language is laid on at render time.
	report[label] = {
		"camera_offset": str(fx.camera_body_offset()),
		"fov_kick": fx.camera_fov_kick(),
		"ground": str(fx.ground.kind),
		"counts": fx.counts.duplicate(),
	}
	for _i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var name := "%s.jpg" % label
	if picture == null or picture.save_jpg(output.path_join(name), 0.82) != OK:
		push_error("[KartFahrgefuehlCapture] Cannot write " + name)
	shots += 1
	print("[KartFahrgefuehlCapture] ", name, " ", report[label].camera_offset)


func _drift() -> void:
	_clean(22.0, game.track_length * 0.31)
	for _i in range(4):
		_tick()
	game.drifting = true
	game.steering = 0.85
	game.drift_charge = 0.5
	for frame in range(60):
		game.drift_charge += STEP * 1.6
		_tick(0.0, 0.32)
		if frame in [8, 24, 40, 59]:
			await _shot("drift_%02d" % frame)
	game.drifting = false


func _landing() -> void:
	_clean(20.0, game.track_length * 0.42)
	for _i in range(6):
		_tick()
	game.airborne = true
	for frame in range(18):
		_tick()
		if frame == 16:
			await _shot("landing_0_air")
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	game.player.position.y = float(road.height) + 0.035
	game.vertical_speed = -10.5
	game.air_time = 0.6
	game.precision_kicker = {}
	game._move_vertically(road, float(road.distance), STEP)
	for frame in range(48):
		_tick()
		if frame in [2, 8, 16, 30, 47]:
			await _shot("landing_%d_%02d" % [1 + [2, 8, 16, 30, 47].find(frame), frame])


func _boost() -> void:
	_clean(14.0, game.track_length * 0.55)
	for _i in range(4):
		_tick()
	game.boost_time = 3.0
	for frame in range(50):
		_tick(40.0 * STEP)
		if frame in [2, 12, 30, 49]:
			await _shot("boost_%02d" % frame)
	game.boost_time = 0.0


func _puddle() -> void:
	_clean(16.0, game.track_length * 0.18)
	GROUND.clear_wet_spots(game.world)
	GROUND.add_wet_spot(game.world, along + 9.0, 0.0, 3.5, 3.0)
	for frame in range(60):
		_tick()
		if frame in [30, 34, 40, 52]:
			await _shot("puddle_%02d" % frame)


func _kerb() -> void:
	_clean(18.0, game.track_length * 0.24)
	game.lane = 4.75
	for frame in range(40):
		_tick()
		if frame in [30, 39]:
			await _shot("kerb_%02d" % frame)
	game.lane = 0.0


func _contact() -> void:
	_clean(20.0, game.track_length * 0.65)
	var rival = game.opponents[0]
	rival.visible = true
	for frame in range(20):
		_tick()
		rival.global_position = game.player.global_position + game.player.global_basis.x * 1.3
		rival.global_basis = game.player.global_basis
		if frame == 6:
			fx.kart_contact(game.player, rival, -game.player.global_basis.x, 12.0)
		if frame in [7, 10]:
			await _shot("contact_%02d" % frame)
	rival.visible = false
