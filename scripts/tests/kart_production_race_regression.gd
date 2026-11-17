extends SceneTree
## Exercises the production race controller, including its manual movement path.
const FLIGHT = preload("res://scripts/games/kart_rival_flight.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0
var game
var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(passed: bool, label: String, detail: Variant = "") -> bool:
	checks.append({"passed": passed, "check": label, "detail": detail})
	if not passed:
		printerr("[ProductionRace] FAIL: %s %s" % [label, detail])
	return passed


func _place(at: float) -> void:
	game.previous_road_distance = at
	game.distance = at
	game.player.transform = game.world.reset_transform(at)
	game.player_heading = game._heading(at)
	game.speed = 0.0
	game.physical_velocity = Vector3.ZERO
	game.airborne = false
	game.vertical_speed = 0.0
	game.open_edge_fall = false
	game.offroad_seconds = 0.0
	game.precision_kicker = {}
	game.boost_time = 0.0
	game.hit_timer = 0.0


func _drive_through_tunnel() -> void:
	var layout: Dictionary = game.world.production_tunnel_layout
	var begin: float = float(layout.start) - 2.0
	var end: float = float(layout.end) + 2.0
	_place(begin)
	game.auto_gas = true
	game.speed = 18.0
	game.physical_velocity = game.world.forward(begin) * game.speed
	var largest_step := 0.0
	var largest_lateral := 0.0
	var frames := 0
	for frame in range(900):
		var before: Vector3 = game.player.position
		var desired_heading: float = game._heading(game.previous_road_distance + 5.0)
		var turn: float = clampf(-angle_difference(game.player_heading, desired_heading) * 2.4, -1.0, 1.0)
		game._drive_player(STEP, turn, 0.0)
		largest_step = maxf(largest_step, before.distance_to(game.player.position))
		largest_lateral = maxf(largest_lateral, absf(game.lane))
		frames = frame + 1
		if game.previous_road_distance >= end:
			break
		if frame % 60 == 0:
			await process_frame
	_check(game.previous_road_distance >= end, "Actual player controller traverses entry, tunnel and exit", {
		"frames": frames, "start": begin, "required_exit": end,
		"reached": game.previous_road_distance, "largest_lateral_m": largest_lateral
	})
	_check(largest_step < 1.0 and game.reset_count == 0,
		"Tunnel traversal has no position jump or rescue", {"largest_step_m": largest_step, "rescues": game.reset_count})
	_check(game.player.position.is_finite() and game.physical_velocity.is_finite(), "Race movement stays finite")


func _probe_motion_and_camera() -> void:
	var layout: Dictionary = game.world.production_tunnel_layout
	var at: float = (float(layout.start) + float(layout.end)) * 0.5
	_place(at)
	game.auto_gas = false
	var origin: Vector3 = game.player.position
	var right: Vector3 = game.world.frame(at).x
	var flat_right := Vector3(right.x, 0.0, right.z).normalized()
	game.player_heading = atan2(-flat_right.x, -flat_right.z)
	game.speed = 80.0
	game.physical_velocity = flat_right * game.speed
	game._drive_player(0.1, 0.0, 0.0)
	_check(game.player.position.distance_to(origin) < 6.0,
		"Actual horizontal integration cannot cross the tunnel wall", game.player.position.distance_to(origin))
	_place(at)
	origin = game.player.position
	var roof_query := PhysicsRayQueryParameters3D.create(
		game.world.to_global(origin + Vector3.UP),
		game.world.to_global(origin + Vector3.UP * 20.0), 1 << 20
	)
	var roof: Dictionary = game.world.get_world_3d().direct_space_state.intersect_ray(roof_query)
	var roof_height: float = -INF if roof.is_empty() else game.world.to_local(roof.position).y
	game.airborne = true
	game.vertical_speed = 45.0
	game._drive_player(0.25, 0.0, 0.0)
	var rise: float = game.player.position.y - origin.y
	var clearance: float = roof_height - game.player.position.y - game.world.production_tunnels.BODY_HEIGHT
	_check(not roof.is_empty() and rise > 0.5 and clearance >= -0.02 and clearance < 0.3 and game.vertical_speed <= 0.0,
		"Actual vertical integration stops at independently ray-measured roof", {
			"rise_m": rise, "vertical_speed": game.vertical_speed, "capsule_to_roof_m": clearance,
			"measured_roof_y": roof_height
		})
	_place(at)
	var anchor: Vector3 = game.player.position + Vector3.UP
	game.camera.position = anchor + right * 18.0
	game._update_camera(0.001, false)
	var camera_delta: float = game.camera.position.distance_to(anchor)
	_check(camera_delta < 8.0 and camera_delta > 0.1,
		"Camera collision runs after chase interpolation", camera_delta)
	game.finished = true
	game.finish_cine_left = 1.0
	game.camera.position = anchor + right * 18.0
	game._update_camera(0.001, false)
	_check(game.camera.position.distance_to(anchor) < 8.0,
		"Result camera remains inside the tunnel", game.camera.position.distance_to(anchor))
	game.finished = false


func _probe_driver_states() -> void:
	var rival = game.opponents[0]
	var flight = FLIGHT.new()
	rival.set_meta(FLIGHT.STATE_KEY, flight)
	game.opponent_stuns[0] = 0.6
	game._update_vehicles(STEP)
	rival._process(STEP * 2.0)
	_check(rival.driver_airborne and rival.driver_hit_active,
		"Island forwards actual rival flight and stun state")
	_check(rival.production_driver.current_behavior == &"kart_jump",
		"Rival flight selects the imported jump clip", str(rival.production_driver.current_behavior))
	game.paused = true
	game._update_vehicles(STEP)
	var sample: float = rival.production_driver.current_sample_time
	rival._process(0.2)
	_check(is_equal_approx(sample, rival.production_driver.current_sample_time), "Pause freezes imported rival animation")
	game.paused = false
	flight.active = false
	game.opponent_stuns[0] = 0.0
	game._update_vehicles(STEP)
	rival._process(STEP * 2.0)
	_check(not rival.driver_airborne and rival.production_driver.current_behavior != &"kart_jump",
		"Rival landing leaves the jump clip")
	game.elapsed = 80.0
	game.distance = game.track_length * 2.0
	game.checkpoint_index = 16
	game.finish_cine_left = 0.0
	game._finish(false)
	for index in game.opponents.size():
		var opponent = game.opponents[index]
		opponent._process(STEP * 2.0)
		_check(opponent.production_driver.current_behavior == &"celebrate",
			"Real finish selects rival celebration %d" % index, str(opponent.production_driver.current_behavior))


func _run() -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.reduced_motion = false
	await process_frame
	await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
		"track": "zauberwald", "difficulty": "flott"})
	game._end_preview()
	await physics_frame
	await physics_frame
	game.countdown = 0.0
	game.racing = true
	_check(is_instance_valid(game.player.production_vehicle), "Real player uses the production Comet")
	_check(is_instance_valid(game.player.lumo_animation), "Original animated LUMO remains the player")
	var ready: bool = is_instance_valid(game.world.production_tunnels) and game.opponents.size() == 5
	_check(ready, "Real race builds its tunnel and five rivals")
	for index in game.opponents.size():
		ready = _check(is_instance_valid(game.opponents[index].production_driver),
			"Real race builds production rival %d" % index) and ready
	if ready:
		await _drive_through_tunnel()
		_probe_motion_and_camera()
		_probe_driver_states()
	_check(await TEARDOWN.release_scene(self, game, "[ProductionRace]"), "Race and audio teardown complete")
	var failures := 0
	for row in checks:
		if not row.passed:
			failures += 1
	var report := {"status": "PASS" if failures == 0 else "FAIL", "engine": Engine.get_version_info().string,
		"scope": "Production kart_island scene, manual player integration, rival state wiring and result flow",
		"display_server": DisplayServer.get_name(), "checks": checks, "failure_count": failures,
		"physical_android_test": false}
	var destination := "res://evidence/lumo_kart_art/review/runtime_race_integration.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var out := FileAccess.open(destination, FileAccess.WRITE)
	if out == null:
		printerr("Cannot write race integration evidence")
		quit(1)
		return
	out.store_string(JSON.stringify(report, "\t") + "\n")
	out.close()
	print("[ProductionRace] %s: %d checks, %d failures" % [report.status, checks.size(), failures])
	quit(0 if failures == 0 else 1)
