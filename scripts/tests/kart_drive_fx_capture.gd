extends SceneTree
## Real engine pictures of every driving effect inside the production race scene.
## Each state is driven through the race's own rules/hooks, then frozen with the
## race pause (the effect clock stops) and photographed landscape + portrait.
## LUMO_CAPTURE_DIR=... xvfb-run godot --path . --rendering-method gl_compatibility \
##   --script res://scripts/tests/kart_drive_fx_capture.gd

const STEP := 1.0 / 60.0
const SIZES: Array[Vector2i] = [Vector2i(1600, 720), Vector2i(720, 1600)]

var game
var fx
var output: String
var along: float = 0.0
var report: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[KartDriveFxCapture] Real renderer required")
		quit(1)
		return
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	if output.is_empty():
		push_error("[KartDriveFxCapture] Set LUMO_CAPTURE_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var only := OS.get_environment("LUMO_CAPTURE_ONLY")
	root.size = SIZES[0]
	root.get_node("SceneRouter").launch_options = {"childKey": "drive-fx-capture"}
	if only.is_empty() or only == "sonnenhafen":
		await _start("sonnenhafen")
		await _measure()
		await _rail()
		await _brake()
		await _launch()
		await _turbo()
		for tier in [1, 2, 3]:
			await _drift(tier)
		await _landing()
		await _rivals()
		await _end()
		await _start("sonnenhafen")
		await _photo_finish()
		await _end()
	for entry in [["desert_drift", "sand"], ["winter_sprint", "snow"], ["zauberwald", "forest"], ["volcano_night", "lava"]]:
		if not only.is_empty() and only != entry[0]:
			continue
		await _start(entry[0])
		await _surface(entry[1])
		await _end()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[KartDriveFxCapture] PASS ", JSON.stringify(report.get("draw_calls", {})))
	quit(0)


func _start(track: String) -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = false
	game.graphics_profile = "high"
	await process_frame
	game._start_selected_race({
		"mode": "race", "driver": "fox", "kart": "comet", "track": track, "difficulty": "gemuetlich"
	})
	game.countdown = 0.0
	game.racing = true
	game.paused = false
	game._end_preview(false)
	game.reduced_motion = false
	game.auto_gas = false
	fx = game.drive_fx
	# Rivals stay out of the way of the hero shots.
	for rival in game.opponents:
		rival.visible = false
	along = game.track_length * 0.1
	await process_frame


func _end() -> void:
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout


func _place(distance: float, lane: float = 0.0) -> void:
	game.distance = distance
	game.previous_road_distance = distance
	game.lane = lane
	# reset_transform clamps the lateral to +-3.5 m; rail tests need the real wall position.
	var placed: Transform3D = game.world.reset_transform(distance, 0.0)
	placed.origin += placed.basis.x.normalized() * lane
	game.player.transform = placed
	game.player.position.y += 0.035
	game.player_heading = game._heading(distance)


func _drive(steps: int, speed_change: float = 0.0, lane_fn: Callable = Callable()) -> void:
	for _i in range(steps):
		game.speed = maxf(0.0, game.speed + speed_change)
		along += maxf(0.05, game.speed * STEP)
		_place(along, lane_fn.call() if lane_fn.is_valid() else game.lane)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		await _frame()


func _clean(speed: float) -> void:
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
	game.auto_gas = false
	fx._previous_speed = speed
	fx._accel = 0.0
	fx._previous_gas = false


func _rail() -> void:
	_clean(23.0)
	along = game.track_length * 0.12
	var wall: float = game._wall_lateral_at(along)
	game.lane = wall - 1.5
	await _drive(10)
	for i in range(34):
		game.lane = wall + (0.5 if i == 26 else 0.12)
		along += game.speed * STEP
		_place(along, game.lane)
		var road: Dictionary = game.world.sample_road(game.player.position, along)
		var basis: Basis = road.basis
		game.physical_velocity = -basis.z * game.speed + basis.x * (11.0 if i == 26 else 2.6)
		game._collide_with_rail(road)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		await _frame()
	await _shot("01_rail_sparks")


func _brake() -> void:
	_clean(25.0)
	along = game.track_length * 0.16
	await _drive(6)
	game.brake_visual_amount = 1.0
	await _drive(42, -0.38)
	await _shot("02_full_brake")


func _launch() -> void:
	_clean(0.0)
	along = game.track_length * 0.2
	await _drive(4)
	game.auto_gas = true
	await _drive(30, 0.32)
	await _shot("03_launch_dust")


func _turbo() -> void:
	_clean(24.0)
	along = game.track_length * 0.24
	await _drive(4)
	game.boost_time = 3.0
	await _drive(26, 0.05)
	await _shot("04_turbo")


func _drift(tier: int) -> void:
	_clean(19.0)
	along = game.track_length * (0.28 + 0.03 * tier)
	await _drive(4)
	game.drifting = true
	game.steering = 0.8
	game.drift_charge = game.DRIFT_TIERS[tier - 1] + 0.05
	for _i in range(36):
		along += game.speed * STEP
		_place(along, game.lane)
		game.player.rotate_object_local(Vector3.UP, 0.32)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		await _frame()
	await _shot("05_drift_tier%d" % tier)


func _landing() -> void:
	_clean(18.0)
	along = game.track_length * 0.42
	await _drive(6)
	var road: Dictionary = game.world.sample_road(game.player.position, along)
	game.player.position.y = float(road.height) + 0.035
	game.airborne = true
	game.vertical_speed = -10.5
	game.air_time = 0.6
	game.precision_kicker = {}
	game._move_vertically(road, float(road.distance), STEP)
	await _drive(9)
	await _shot("06_landing")


func _rivals() -> void:
	_clean(21.0)
	along = game.track_length * 0.5
	await _drive(6)
	var shown: Array = [game.opponents[0], game.opponents[1]]
	for rival in shown:
		rival.visible = true
	for i in range(40):
		along += game.speed * STEP
		_place(along, -1.5)
		var ahead: Transform3D = game.world.reset_transform(along + 7.0, 1.8)
		shown[0].global_transform = game.race_root.global_transform * ahead.rotated_local(Vector3.UP, 0.3)
		shown[0].set_motion(21.0, 0.8, false, true)
		shown[0].set_drift_spark_tier(1)
		var beside: Transform3D = game.world.reset_transform(along + 12.0, -2.5)
		shown[1].global_transform = game.race_root.global_transform * beside
		shown[1].set_motion(24.0, 0.0, true, false)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		await _frame()
	await _shot("08_rivals")
	for rival in shown:
		rival.set_motion(0.0, 0.0, false, false)
		rival.visible = false


func _photo_finish() -> void:
	_clean(20.0)
	for rival in game.opponents:
		rival.visible = false
	along = game.track_length - 30.0
	await _drive(20)
	var rival = game.opponents[0]
	rival.visible = true
	game.elapsed = 61.5
	game.checkpoint_index = game.TOTAL_LAPS * 8
	game.distance = game.track_length * game.TOTAL_LAPS + 0.3
	for i in range(game.opponent_distances.size()):
		game.opponent_distances[i] = game.distance - 80.0
	game.opponent_distances[0] = game.distance - 2.5
	rival.global_transform = game.race_root.global_transform * game.world.reset_transform(along - 2.5, 2.2)
	rival.set_motion(20.0, 0.0, true, false)
	game._update_vehicles(STEP)
	game._finish()
	for _i in range(8):
		game._update_finish_cine(STEP * Engine.time_scale)
		await process_frame
	report["photo_finish"] = {"active": fx.photo_finish.active, "gap": fx.photo_finish.last_gap,
		"time_scale": Engine.time_scale}
	await _shot("09_photo_finish", false)


func _surface(label: String) -> void:
	_clean(22.0)
	along = game.track_length * 0.14
	await _drive(20)
	game.brake_visual_amount = 1.0
	await _drive(16, -0.3)
	game.brake_visual_amount = 0.0
	game.speed = 22.0
	fx._previous_speed = 22.0
	await _drive(14)
	game.drifting = true
	game.steering = 0.7
	game.drift_charge = game.DRIFT_TIERS[0] + 0.05
	for _i in range(30):
		along += game.speed * STEP
		_place(along, game.lane)
		game.player.rotate_object_local(Vector3.UP, 0.28)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		await _frame()
	await _shot("07_surface_" + label)


func _measure() -> void:
	# Same view with and without the effects: drift + turbo + braking + rail.
	_clean(22.0)
	along = game.track_length * 0.12
	var wall: float = game._wall_lateral_at(along)
	game.boost_time = 4.0
	game.drifting = true
	game.steering = 0.8
	game.drift_charge = 3.0
	for _i in range(40):
		game.lane = wall + 0.12
		along += game.speed * STEP
		_place(along, game.lane)
		var road: Dictionary = game.world.sample_road(game.player.position, along)
		game.physical_velocity = -(road.basis as Basis).z * game.speed + (road.basis as Basis).x * 3.0
		game._collide_with_rail(road)
		game._update_vehicles(STEP)
		game._update_camera(STEP)
		await _frame()
	game.paused = true
	game._update_vehicles(STEP)
	var with_fx := await _render_info()
	fx.visible = false
	var without_fx := await _render_info()
	fx.visible = true
	report["draw_calls"] = {
		"with_effects": with_fx, "without_effects": without_fx, "state": fx.visual_state()
	}
	game.paused = false


func _render_info() -> Dictionary:
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var viewport := root.get_viewport_rid()
	return {
		"draw_calls": RenderingServer.viewport_get_render_info(
			viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.viewport_get_render_info(
			viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.viewport_get_render_info(
			viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
	}


func _shot(label: String, freeze: bool = true) -> void:
	# Freeze: the race pause stops the effect clock, so both formats show one moment.
	game.paused = freeze
	if freeze:
		game._update_vehicles(STEP)
	report[label] = fx.visual_state()
	for size in SIZES:
		root.size = size
		if freeze:
			game._update_camera(1.0, true)
		game._update_hud()
		for _i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		var name := "%s_%dx%d.png" % [label, size.x, size.y]
		if picture == null or picture.save_png(output.path_join(name)) != OK:
			push_error("[KartDriveFxCapture] Cannot write " + name)
		print("[KartDriveFxCapture] ", name, " ", JSON.stringify(fx.visual_state().counts))
	root.size = SIZES[0]
	game.paused = false


var _frames: int = 0


## Software rendering is slow: only every sixth driven tick is drawn (the
## simulation itself still runs every tick).
func _frame() -> void:
	_frames += 1
	if _frames % 6 == 0:
		await process_frame
