extends SceneTree
## Actual shipped Kart scene and player factory, not a separately attached actor.
## Inputs and race preconditions are fixtures; physics/rewards use product code.
const STEP := 1.0 / 60.0
var game
var checks := 0
var failures := 0
var output := ""
var screenshots := 0
var worst_contact := 0.0
var frame_index := 0
var video := false


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[LumoKartProduction] " + label)


func _settle() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _settle()
	_check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK,
		"Real product-scene screenshot: " + name)
	screenshots += 1


func _start(mode: String, track: String = "sonnenhafen", driver: String = "fox") -> void:
	game._start_selected_race(
		{"mode": mode, "track": track, "driver": driver, "kart": "comet", "difficulty": "flott"}
	)
	game.set_physics_process(false)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.auto_gas = true
	game.reduced_motion = false
	game.player.reduced_motion = false
	game._update_vehicles(0.0)
	game._update_hud()
	for kart in [game.player] + game.opponents:
		kart.set_process(false)
	await _settle()


func _step(frames: int, record := false) -> void:
	for frame in range(frames):
		game._physics_process(STEP)
		var before: Transform3D = game.player.transform
		var distance: float = game.distance
		var speed: float = game.speed
		var checkpoint: int = game.checkpoint_index
		var stars: int = root.get_node("ProgressStore").total_stars()
		game.player._process(STEP)
		for kart in game.opponents:
			kart._process(STEP)
		_check(game.player.transform.is_equal_approx(before), "Animation cannot move the chassis")
		_check(game.distance == distance and game.speed == speed and game.checkpoint_index == checkpoint,
			"Animation cannot write race progress or physics")
		_check(root.get_node("ProgressStore").total_stars() == stars, "Animation cannot award stars")
		var adapter = game.player.lumo_animation
		if is_instance_valid(adapter) and not adapter.victory and not game.paused:
			var error := _hand_error(game.player, 0)
			error = maxf(error, _hand_error(game.player, 1))
			worst_contact = maxf(worst_contact, error)
			_check(error < 0.006,
				"Real hand contact mm=%.3f track=%s air=%s clip=%s far=%s" % [
					error * 1000.0, game.track_id, game.airborne,
					adapter.actor.current_behavior, game.player.far_detail])
		if record and video and frame % 4 == 0 and DisplayServer.get_name() != "headless":
			await _settle()
			_check(root.get_texture().get_image().save_png(
				output.path_join("frame-%04d.png" % frame_index)) == OK, "Product animation video frame")
			frame_index += 1


func _hand_error(kart, index: int) -> float:
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var hand: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(
		skeleton.find_bone("Hand.L" if index == 0 else "Hand.R")).origin)
	return hand.distance_to(kart.steering_wheel.to_global(kart.wheel_rest_grips[index]))


func _orbit_camera() -> void:
	game.camera.look_at_from_position(
		game.player.to_global(Vector3(3.0, 2.2, -4.8)),
		game.player.global_position + Vector3.UP * 1.15
	)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "res://exports/lumo-kart-production"
	video = args.has("--video")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	DirAccess.remove_absolute("user://kart_sonnenhafen_session.cfg")
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await _settle()
	await _start("race")
	_check(is_instance_valid(game.player.lumo_animation), "Normal race factory attaches animated Lumo")
	if not is_instance_valid(game.player.lumo_animation):
		game.free()
		quit(1)
		return
	_check(game.player.lumo_animation.actor.is_usable(), "Production model and nine clips are usable")
	_check(not game.player.driver.visible, "Only one Lumo is visible")
	_check(not game.player.lumo_animation.is_processing(), "Vehicle owns the only animation clock")
	for kart in game.opponents:
		_check(not is_instance_valid(kart.lumo_animation), "Rival development remains unchanged")
	game.auto_gas = false
	game.gas_button._press()
	_check(game.gas_held, "Actual GAS control signal reaches race code")
	await _step(60, true)
	_check(game.speed > 5.0, "Existing physics really accelerates")
	_orbit_camera()
	game.player.set_animated_lumo_enabled(false)
	await _capture("before-existing-driver")
	var before: Transform3D = game.player.transform
	game.player.set_animated_lumo_enabled(true)
	game.player._process(1.0 / 30.0)
	_check(game.player.transform.is_equal_approx(before), "Enabling the visual preserves vehicle placement")
	await _capture("after-animated-lumo")
	await _capture("actual-race-player")
	for value in [-0.7, 0.7]:
		game.joystick.axis_changed.emit(Vector2(value, 0))
		await _step(12, true)
		_check(is_equal_approx(game.player.lumo_animation.steering, game.player.motion_steer),
			"Real steering reaches the rig")
		_orbit_camera()
		await _capture("steering-left" if value < 0 else "steering-right")
	game.boost_button._press()
	await _step(2)
	_check(game.player.motion_boost and game.player.lumo_animation.boosting, "Real boost reaches the rig")
	# Contact fixture: place an existing rival into collision range; detection
	# and hit_timer are the same product code as an ordinary race collision.
	game.hit_timer = 0.0
	game.shield_time = 0.0
	game.opponents[0].position = game.player.position
	game._track_events()
	_check(game.hit_timer > 0.0, "Product collision creates an actual hit event")
	game._update_vehicles(0.0)
	game.player._process(1.0 / 30.0)
	var hit_peak: float = game.player.lumo_animation.hit_amount
	_check(hit_peak > 0.0, "Hit edge reaches the animation")
	game._update_vehicles(0.0)
	game.player._process(1.0 / 30.0)
	_check(game.player.lumo_animation.hit_amount < hit_peak, "A held hit flag cannot retrigger every frame")
	game._pause()
	var elapsed: float = game.player.lumo_animation.elapsed
	var paused_pose: Transform3D = game.player.lumo_animation.actor.skeleton.get_bone_global_pose(
		game.player.lumo_animation.actor.skeleton.find_bone("Head"))
	await _step(12)
	_check(game.player.lumo_animation.elapsed == elapsed, "Actual pause freezes the animation clock")
	_check(game.player.lumo_animation.actor.skeleton.get_bone_global_pose(
		game.player.lumo_animation.actor.skeleton.find_bone("Head")).is_equal_approx(paused_pose),
		"Actual pause freezes the head pose")
	await _capture("actual-pause")
	game._resume()
	await _step(4)
	_check(game.player.lumo_animation.elapsed > elapsed, "Actual resume restarts animation")
	game.reduced_motion = true
	game.player.reduced_motion = true
	game._update_vehicles(0.0)
	elapsed = game.player.lumo_animation.elapsed
	await _step(12)
	_check(game.player.lumo_animation.elapsed == elapsed, "Existing quiet-motion preference stops the clip clock")
	_check(game.player.lumo_animation.actor.reduced_motion, "Preference reaches the shared actor")
	game.reduced_motion = false
	game.player.reduced_motion = false
	game._update_vehicles(0.0)
	# LOD must never reintroduce the old fox or bake a weighted skin rigidly.
	game.player._set_far_detail(true)
	_check(not game.player.driver.visible and game.player.lumo_animation.is_visible_in_tree(),
		"LOD keeps exactly the animated character")
	game.player._set_far_detail(false)
	var old_actor = weakref(game.player.lumo_animation)
	game.player.configure_variant("glider")
	_check(old_actor.get_ref() == null, "Variant rebuild releases the previous rig")
	_check(is_instance_valid(game.player.lumo_animation), "Variant rebuild reconnects Lumo")
	game.player.set_process(false)
	await _step(4)
	# Footage from the genuine chase camera and two logical desktop/Fold layouts.
	game._update_camera(1.0, true)
	await _capture("chase-camera-1280x720")
	root.size = Vector2i(640, 320)
	game._apply_responsive_layout()
	await _capture("chase-camera-640x320")
	root.size = Vector2i(1280, 720)
	game._apply_responsive_layout()
	# Genuine ramp crossing and flight: no test ever sets airborne=true.
	await _start("training", "bergwelt")
	var jump: Dictionary = game.world.jump
	var start: float = float(jump.ramp_start) - 25.0
	game.player.transform = game.world.reset_transform(start)
	game.previous_road_distance = start
	game.distance = start
	game.player_heading = game._heading(start)
	game.speed = 17.0
	game.physical_velocity = Vector3(-sin(game.player_heading), 0, -cos(game.player_heading)) * 17.0
	game.checkpoint_index = 3
	var air_frames := 0
	var air_capture := false
	for frame in range(180):
		var direction: Vector3 = game.world.position_at(game.previous_road_distance + 10.0) - game.player.position
		var heading := atan2(-direction.x, -direction.z)
		game.joystick.axis_changed.emit(Vector2(
			clampf(-angle_difference(game.player_heading, heading) * 2.1, -1, 1), 0))
		await _step(1)
		_check(game.player.lumo_animation.airborne == game.airborne, "Actual ramp state reaches the rig")
		if game.airborne:
			air_frames += 1
			if air_frames >= 10 and not air_capture:
				_check(game.player.lumo_animation.actor.current_behavior == "kart_jump",
					"Real flight selects the exported jump clip")
				await _capture("actual-ramp-jump")
				air_capture = true
	_check(game.jump_count == 1 and game.landing_count == 1 and game.gap_falls == 0,
		"Existing ramp physics still takes off and lands once")
	_check(air_frames > 20 and air_capture, "Real ramp flight was observed")
	await _step(4)
	_check(not game.player.lumo_animation.airborne, "Landing clears the animation's airborne state")
	await _capture("actual-ramp-landing")
	# Only finish preconditions are fixtures, not a claim of two fully played laps.
	# The real completion/reward/cinematic methods are used unchanged.
	await _start("race")
	game.distance = game.track_length * game.TOTAL_LAPS
	game.checkpoint_index = game.TOTAL_LAPS * 8
	var stars_before: int = root.get_node("ProgressStore").total_stars()
	game.speed = 12.0
	game._finish()
	_check(game.player.lumo_animation.victory, "Real race finish requests the animation")
	var stars_after: int = root.get_node("ProgressStore").total_stars()
	_check(stars_after == stars_before + int(game.result_payload.stars), "Reward still belongs to race completion")
	var result_id: String = game.result_id
	await _step(54, true)
	_check(_hand_error(game.player, 0) < 0.006, "Left hand stays on the wheel in the real finish coast")
	await _capture("actual-finish-coast")
	game._finish()
	_check(root.get_node("ProgressStore").total_stars() == stars_after and game.result_id == result_id,
		"Replaying the finish cannot duplicate rewards or identity")
	await _step(140)
	_check(not game.player.lumo_animation.victory, "The one-shot finish animation returns to seated")
	await _capture("actual-finish-result")
	await _start("training", "sonnenhafen", "rabbit")
	_check(not is_instance_valid(game.player.lumo_animation) and game.player.driver.visible,
		"Selecting a different driver never disguises it as Lumo")
	await _start("training")
	_check(is_instance_valid(game.player.lumo_animation), "Selecting Lumo again reconnects the shared model")
	var load_kind: String = game.player.lumo_animation.actor.model_load_kind
	game.abandoned = true
	game.queue_free()
	await _settle()
	await create_timer(0.5).timeout
	await _settle()
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline,
		"All scene rebuilds and navigation release their rig nodes")
	var report := {"checks": checks, "failures": failures, "screenshots": screenshots,
		"worst_hand_contact_mm": worst_contact * 1000.0, "model_load_kind": load_kind,
		"real_product_scene": true, "real_ramp_flight": air_frames,
		"finish_preconditions_are_fixture": true, "android_test": false}
	var file := FileAccess.open(output.path_join("production-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("[LumoKartProduction] ", JSON.stringify(report))
	if failures == 0:
		print("[LumoKartProduction] PASS actual Kart factory, physics events, pause, rebuild and finish")
	quit(0 if failures == 0 else 1)
