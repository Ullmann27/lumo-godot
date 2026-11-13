extends SceneTree
## Rendering stays bounded and cannot change the existing race outcomes.

const FX = preload("res://scripts/games/kart_drive_feedback.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var checks: int = 0
var failures: Array[String] = []
var logic_only: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("[KartDriveFeedback] FAIL " + label)


func _run() -> void:
	logic_only = "--logic-only" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not logic_only:
		push_error(
			"[KartDriveFeedback] Renderer required; use --logic-only for bounded state checks"
		)
		quit(1)
		return
	await _geometry_and_lifetime()
	await _variant_rebuild()
	await _production_events()
	await create_timer(0.1).timeout
	if failures.is_empty():
		var status := "LOGIC_PASS" if logic_only else "PASS"
		print(
			(
				"[KartDriveFeedback] %s %d checks: pause, reset, bounded pools and real events"
				% [status, checks]
			)
		)
		if logic_only:
			print("[KartDriveFeedback] Renderer geometry/color assertions remain pending")
		quit(0)
	else:
		print("[KartDriveFeedback] FAIL ", failures)
		quit(1)


func _geometry_and_lifetime() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.position = Vector3(19, 3, -8)
	var kart := VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	world.add_child(kart)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(6, 4, 9)
	camera.look_at(world.global_position + Vector3.UP)
	camera.current = true
	var fx := FX.new()
	world.add_child(fx)
	fx.bind_vehicle(kart)
	_check(fx.get_child_count() == 3, "three fixed batches are allocated once")
	_check(not fx.is_processing(), "race owns effect time; no independent process")
	_check(fx.visual_state().trail_segments == 0, "idle kart has no ribbons")
	kart.set_motion(18.0, 0.7, false, true)
	kart.set_drift_spark_tier(1)
	for _i in range(12):
		kart.position += Vector3(-0.3, 0, -0.05)
		fx.advance(1.0 / 60.0, true, false, false, false)
	_check(
		fx.visual_state().trail_segments > 0, "actual wheel movement draws a continuous drift path"
	)
	_check(fx.visual_state().contacts == 2, "both rear contact points show drift readiness")
	var batch: MultiMeshInstance3D = fx.get_node("TyreAndExhaustRibbons")
	var fixed_mark: Transform3D = batch.multimesh.get_instance_transform(0)
	var center: Vector3 = world.to_global(fixed_mark.origin)
	if not logic_only:
		_check(fixed_mark.basis.determinant() > 0.0, "renderer retains nonzero ribbon geometry")
		_check(
			absf(fixed_mark.basis.z.length() - (Vector3(0.3, 0, 0.05).length() + 0.025)) < 0.001,
			"ribbon length follows real travel across a bend without global-axis scaling"
		)
		_check(
			center.distance_to(kart.global_position) < 6.0,
			"translated race root retains world contact placement"
		)
	kart.position.z -= 0.3
	fx.advance(1.0 / 60.0, true, false, false, false)
	if not logic_only:
		_check(
			batch.multimesh.get_instance_transform(0) == fixed_mark,
			"old tyre marks stay fixed in the world"
		)
	var contact: MultiMeshInstance3D = fx.get_node("LumoEnergyStars")
	var blue: Color = contact.multimesh.get_instance_color(FX.CONTACT_START)
	kart.set_drift_spark_tier(2)
	fx.advance(1.0 / 60.0, true, false, false, false)
	var orange: Color = contact.multimesh.get_instance_color(FX.CONTACT_START)
	if not logic_only:
		_check(
			blue.b > blue.r and orange.r > orange.b,
			"blue and orange match the real existing drift tiers"
		)
	var before_pause: Dictionary = fx.visual_state()
	fx.advance(3.0, true, true, false, false)
	_check(fx.visual_state() == before_pause, "pause freezes age, contacts and trail lifetime")
	kart.set_motion(18, 0.7, false, true)
	for _i in range(30):
		fx.advance(1.0 / 60.0, true, false, true, false)
	_check(fx.visual_state().trail_segments == 0, "airborne kart leaves no ground drift path")
	_check(fx.visual_state().contacts == 0, "airborne kart has no ground contact flash")
	fx.advance(1.0 / 60.0, true, false, false, true)
	_check(fx.visual_state().contacts == 2, "reduced motion retains readable readiness color")
	_check(fx.visual_state().trail_segments == 0, "reduced motion avoids moving ribbon buildup")
	fx.reset()
	kart.set_motion(0, 0, false, false)
	fx.advance(0.0, true, false, false, true)
	fx.collect_item(kart.global_position + Vector3(1, 0.8, 0), "shield")
	var quiet_transform: Transform3D = contact.multimesh.get_instance_transform(0)
	var quiet_color: Color = contact.multimesh.get_instance_color(0)
	fx.advance(0.1, true, false, false, true)
	fx.advance(0.1, true, false, false, true)
	_check(fx.visual_state().pickup_events == 1, "quiet pickup retains a visible acknowledgement")
	if not logic_only:
		_check(quiet_transform.basis.determinant() > 0.0, "quiet pickup retains real star geometry")
		_check(
			contact.multimesh.get_instance_transform(0).is_equal_approx(quiet_transform),
			"quiet pickup never translates, rotates or pulses in size"
		)
		_check(
			contact.multimesh.get_instance_color(0).a < quiet_color.a,
			"quiet pickup only fades its opacity"
		)
		var quiet_stars := 0
		for index in range(FX.STARS_PER_EVENT):
			if contact.multimesh.get_instance_transform(index).basis.determinant() > 0.0:
				quiet_stars += 1
		_check(quiet_stars == 3, "quiet pickup uses three fixed stars")
	fx.advance(0.6, true, false, false, true)
	_check(fx.visual_state().events == 0, "quiet pickup expires without a retained star")
	if not logic_only:
		_exhaust_impulse_geometry(kart, fx)
	kart.set_motion(18, 0.7, false, true)
	for _i in range(12):
		kart.position.z -= 0.3
		fx.advance(1.0 / 60.0, true, false, false, false)
	kart.position.x += 100.0
	fx.advance(1.0 / 60.0, true, false, false, false)
	_check(fx.visual_state().trail_segments == 0, "respawn or teleport cannot connect a long strip")
	for _i in range(120):
		fx.collect_item(kart.global_position + Vector3(1, 0.8, 0), "pulse")
		fx.landed(10.0, true, world.global_basis)
		fx.boost_release(2)
	_check(fx.visual_state().events <= FX.EVENT_CAPACITY, "repeated events use a fixed pool")
	_check(fx.get_child_count() == 3, "repeated events allocate no additional scene nodes")
	kart.set_motion(0, 0, false, false)
	for _i in range(60):
		fx.advance(1.0 / 60.0, true, false, false, false)
	_check(fx.visual_state().events == 0, "all one-shot event geometry expires")
	_check(fx.visual_state().trail_segments == 0, "all stopped-kart trails expire")
	fx.collect_item(kart.global_position, "boost")
	fx.advance(0.0, false, false, false, false)
	_check(fx.visual_state().events == 0, "race finish or menu entry clears residual events")
	world.queue_free()
	await process_frame
	_check(not is_instance_valid(fx), "scene replacement frees the entire effect pool")


func _exhaust_impulse_geometry(kart: Node3D, fx: Node3D) -> void:
	var original_transform := kart.transform
	kart.rotation = Vector3(0.14, 0.55, -0.09)
	fx.reset()
	fx.advance(0.0, true, false, false, false)
	var origins: Array[Vector3] = []
	for source in kart.flames:
		origins.append(source.global_position)
	var rearward := kart.global_basis.z.normalized()
	fx.boost_release(2)
	var rings: MultiMeshInstance3D = fx.get_node("EventContactRings")
	var directions_match := true
	for index in range(2):
		var pulse: Transform3D = rings.multimesh.get_instance_transform(index)
		_check(
			fx.to_global(pulse.origin).distance_to(origins[index]) < 0.001,
			"boost pulse %d starts at its real exhaust nozzle" % index
		)
		var normal := (fx.global_basis * pulse.basis.y).normalized()
		directions_match = directions_match and normal.dot(rearward) > 0.999
	_check(directions_match, "both exhaust pulses face the real rearward thrust direction")
	kart.position += Vector3(0.8, 0.0, -0.6)
	for _i in range(3):
		fx.advance(0.1, true, false, false, false)
	var directed := true
	var compact := true
	for index in range(2):
		var pulse: Transform3D = rings.multimesh.get_instance_transform(index)
		var travel := fx.to_global(pulse.origin) - origins[index]
		var along := travel.dot(rearward)
		directed = directed and along > 0.1 and (travel - rearward * along).length() < 0.001
		compact = compact and pulse.basis.x.length() > 0.12 and pulse.basis.x.length() < 0.29
		compact = compact and is_equal_approx(pulse.basis.x.length(), pulse.basis.z.length())
	_check(directed, "released pulses move aft from their world origins without following the kart")
	_check(compact, "boost pulses remain nozzle-sized instead of surrounding the kart")
	fx.reset()
	fx.advance(0.0, true, false, false, true)
	fx.boost_release(2)
	var quiet_a := rings.multimesh.get_instance_transform(0)
	var quiet_b := rings.multimesh.get_instance_transform(1)
	var quiet_alpha := rings.multimesh.get_instance_color(0).a
	fx.advance(0.1, true, false, false, true)
	_check(
		(
			rings.multimesh.get_instance_transform(0).is_equal_approx(quiet_a)
			and rings.multimesh.get_instance_transform(1).is_equal_approx(quiet_b)
		),
		"reduced-motion exhaust pulses retain fixed positions and sizes"
	)
	_check(
		rings.multimesh.get_instance_color(0).a < quiet_alpha,
		"reduced-motion exhaust pulses fade without motion"
	)
	fx.reset()
	kart.transform = original_transform
	fx.advance(0.0, true, false, false, false)


func _variant_rebuild() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var kart := VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	world.add_child(kart)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var fx := FX.new()
	world.add_child(fx)
	fx.bind_vehicle(kart)
	kart.set_motion(18.0, 0.7, true, true)
	for _i in range(3):
		kart.position.z -= 0.3
		fx.advance(1.0 / 60.0, true, false, false, false)
	_check(fx.visual_state().trail_segments > 0, "old variant really emitted tyre/exhaust paths")
	var old_tyre: WeakRef = weakref(fx._tyres[0])
	var old_exhaust: WeakRef = weakref(fx._exhausts[0])
	var batch := fx.get_node("TyreAndExhaustRibbons")
	kart.configure_variant("glider")
	_check(
		old_tyre.get_ref() == null and old_exhaust.get_ref() == null,
		"actual configure_variant releases both kinds of cached attachment nodes"
	)
	# A rebuild is a lifecycle boundary even while ordinary effect time is paused.
	fx.advance(0.0, true, true, false, false)
	var rebound: bool = fx._tyres.size() == 2 and fx._exhausts.size() == 2
	for anchor in fx._tyres:
		rebound = rebound and is_instance_valid(anchor) and kart.sparks.has(anchor)
	for anchor in fx._exhausts:
		rebound = rebound and is_instance_valid(anchor) and kart.flames.has(anchor)
	_check(rebound, "feedback rebinds the real new glider contact and exhaust nodes")
	if rebound:
		var reset_state: Dictionary = fx.visual_state()
		_check(
			reset_state.trail_segments == 0 and reset_state.events == 0 and reset_state.contacts == 0,
			"variant replacement clears trails and frozen events from the released geometry"
		)
		_check(
			fx.get_child_count() == 3 and fx.get_node("TyreAndExhaustRibbons") == batch,
			"rebind preserves the three existing bounded rendering batches"
		)
		kart.set_motion(18.0, 0.7, true, true)
		for _i in range(3):
			kart.position.z -= 0.3
			fx.advance(1.0 / 60.0, true, false, false, false)
		var resumed: Dictionary = fx.visual_state()
		_check(
			resumed.trail_segments > 0 and resumed.contacts == 2 and resumed.boost_events == 1,
			"rebuilt glider produces real new drift and boost feedback without another bind call"
		)
		var glider_exhaust: WeakRef = weakref(fx._exhausts[0])
		kart.configure_variant("comet")
		_check(glider_exhaust.get_ref() == null, "second real variant rebuild frees the glider nozzle")
		# A production event can arrive before the next physics sampling call.
		fx.boost_release(2)
		var direct_rebind: bool = fx._exhausts.size() == 2
		for anchor in fx._exhausts:
			direct_rebind = direct_rebind and is_instance_valid(anchor) and kart.flames.has(anchor)
		_check(
			direct_rebind and fx.visual_state().boost_events == 1,
			"direct boost release rebinds new nozzles before any subsequent advance"
		)
		if direct_rebind:
			var fresh_origins := true
			for index in range(2):
				var emitted: Vector3 = fx.to_global(fx._boost_origins[index])
				fresh_origins = (
					fresh_origins and emitted.distance_to(kart.flames[index].global_position) < 0.001
				)
			_check(
				fresh_origins and fx.get_child_count() == 3,
				"direct boost stores both real new exhaust origins in the existing bounded pool"
			)
	world.queue_free()
	await process_frame


func _production_events() -> void:
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	root.get_node("SceneRouter").launch_options = {"childKey": "drive-feedback-regression"}
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await process_frame
	game._start_selected_race(
		{
			"mode": "training",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich"
		}
	)
	game.countdown = 0.0
	game.preview_left = 0.0
	game.racing = true
	game.paused = false
	await process_frame
	var feedback: Node3D = game.drive_feedback
	_check(is_instance_valid(feedback), "real race builds and binds the feedback component")
	game.speed = 18.0
	game.steering = 0.7
	game.drifting = true
	game.drift_charge = game.DRIFT_TIERS[1] + 0.1
	game.boost_time = 0.0
	game._update_vehicles(1.0 / 60.0)
	var speed_before: float = game.speed
	var charge_before: float = game.drift_charge
	game._update_vehicles(1.0 / 60.0)
	_check(
		game.speed == speed_before and game.drift_charge == charge_before,
		"visual sampling cannot alter speed or charge"
	)
	game._release_drift()
	_check(
		feedback.visual_state().boost_events == 1, "real drift release triggers one thrust event"
	)
	_check(
		is_equal_approx(game.boost_time, game._boost_for(game.DRIFT_BOOST_SECONDS[1])),
		"existing drift boost duration is unchanged"
	)
	game._update_vehicles(1.0 / 60.0)
	_check(
		feedback.visual_state().boost_events == 1,
		"motion sampling does not duplicate the release event"
	)
	_production_rebuild_lifetime(game, feedback)
	feedback.reset()
	game.item = ""
	game.boost_time = 0.0
	game.airborne = false
	game.speed = 18.0
	game.distance = game.item_box_distances[0]
	game.lane = game.item_box_laterals[0]
	game.player.position = game.item_boxes[0].position
	game._track_events()
	_check(not game.item.is_empty(), "production resonance crossing awards its original item")
	_check(
		feedback.visual_state().pickup_events == 1,
		"actual item award starts its directed energy pickup"
	)
	game._track_events()
	_check(
		feedback.visual_state().pickup_events == 1,
		"the same collected ring cannot retrigger pickup"
	)
	feedback.reset()
	game.distance = 10.0
	game.previous_road_distance = 10.0
	game.lane = 0.0
	game.player.transform = game.world.reset_transform(10.0, 0.0)
	var road: Dictionary = game.world.sample_road(game.player.position, 10.0)
	game.player.position.y = float(road.height) + 0.035
	game.player.rotate_object_local(Vector3.RIGHT, -0.32)
	game.airborne = true
	game.vertical_speed = -8.0
	game.air_time = 0.5
	game.precision_kicker = {}
	var landings_before: int = game.landing_count
	game._move_vertically(road, float(road.distance), 1.0 / 60.0)
	_check(
		game.landing_count == landings_before + 1 and not game.airborne,
		"production vertical motion really lands the kart"
	)
	_check(
		feedback.visual_state().landing_events == 1,
		"real ground contact produces exactly one landing event"
	)
	if not logic_only:
		var rings: MultiMeshInstance3D = feedback.get_node("EventContactRings")
		var contact_up: Vector3 = (
			(feedback.global_basis * rings.multimesh.get_instance_transform(0).basis.y).normalized()
		)
		var road_up: Vector3 = (game.race_root.global_basis * (road.basis as Basis).y).normalized()
		_check(
			contact_up.dot(road_up) > 0.999,
			"landing ring follows the road, not the airborne chassis pitch"
		)
	game._move_vertically(road, float(road.distance), 1.0 / 60.0)
	_check(
		feedback.visual_state().landing_events == 1,
		"continuing on the road cannot repeat the landing burst"
	)
	game._pause()
	_check(
		game.paused and feedback.visual_state().events > 0,
		"pause preserves the pending contact effect"
	)
	var finish_training: Button
	for child in game.modal_column.get_children():
		if child is Button and child.text == "Training abschließen":
			finish_training = child
	_check(is_instance_valid(finish_training), "training pause menu exposes its real finish action")
	if is_instance_valid(finish_training):
		finish_training.pressed.emit()
		_check(
			game.finished and game.finish_cine_left > 0.0,
			"pause-menu action enters the actual finish cinematic"
		)
		var finished_state: Dictionary = feedback.visual_state()
		_check(
			(
				finished_state.events == 0
				and finished_state.trail_segments == 0
				and finished_state.contacts == 0
			),
			"finish entry immediately clears frozen events, trails and contacts"
		)
		game._physics_process(0.1)
		_check(
			feedback.visual_state().events == 0,
			"finish cinematic cannot retain a frozen race effect"
		)
	var playbacks: Array[WeakRef] = []
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = null
	_check(await _release_audio(playbacks), "audio playback releases after race teardown")
	await process_frame
	_check(
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_baseline,
		"race replacement and repeated kart rebuilds release every attached node"
	)


func _release_audio(playbacks: Array[WeakRef]) -> bool:
	# Fixed simulation time can outrun the mixer's real fadeout. Observe the
	# actual playbacks without retaining them, and fail if teardown stalls.
	var started := Time.get_ticks_msec()
	while true:
		var pending := 0
		for playback: WeakRef in playbacks:
			if playback.get_ref() != null:
				pending += 1
		if pending == 0:
			print(
				"[KartDriveFeedback] audio_release tracked=%d elapsed_ms=%d"
				% [playbacks.size(), Time.get_ticks_msec() - started]
			)
			return true
		if Time.get_ticks_msec() - started >= 2000:
			printerr("[KartDriveFeedback] retained_audio_playbacks=", pending)
			return false
		OS.delay_msec(2)
		await process_frame
	return false


func _production_rebuild_lifetime(race, feedback: Node3D) -> void:
	var original_feedback_id := feedback.get_instance_id()
	var old_flame: WeakRef = weakref(race.player.flames[0])
	var old_spark: WeakRef = weakref(race.player.sparks[0])
	race.player.configure_variant("glider")
	_check(
		old_flame.get_ref() == null and old_spark.get_ref() == null,
		"real variant rebuild frees the previously bound nozzle and tyre nodes"
	)
	race.speed = 18.0
	race.steering = 0.7
	race.drifting = true
	race.drift_charge = race.DRIFT_TIERS[1] + 0.1
	race.boost_time = 0.0
	race._update_vehicles(1.0 / 60.0)
	var state: Dictionary = feedback.visual_state()
	_check(
		state.contacts == 2 and state.trail_segments == 0 and state.events == 0,
		"variant rebuild resumes current tyre contacts without bridging old trails or events"
	)
	race.player.position -= race.player.basis.z * 0.3
	race._update_vehicles(1.0 / 60.0)
	_check(
		(
			feedback.visual_state().trail_segments > 0
			and feedback.get_instance_id() == original_feedback_id
			and feedback.get_child_count() == 3
		),
		"rebuilt kart resumes real trails using the same fixed effect pool"
	)
	old_flame = weakref(race.player.flames[0])
	race.player.configure_variant("comet")
	# The actual release event may arrive before the next advance() call.
	race._release_drift()
	_check(
		(
			old_flame.get_ref() == null
			and feedback.visual_state().boost_events == 1
			and feedback.visual_state().trail_segments == 0
		),
		"direct release after a second rebuild automatically binds the new exhausts"
	)
	if not logic_only:
		var rings: MultiMeshInstance3D = feedback.get_node("EventContactRings")
		for index in range(2):
			var pulse := rings.multimesh.get_instance_transform(index)
			_check(
				(
					feedback.to_global(pulse.origin).distance_to(
						race.player.flames[index].global_position
					)
					< 0.001
				),
				"rebuilt production nozzle %d owns its real rendered impulse" % index
			)
	race._pause()
	var paused_clock: float = feedback.visual_state().clock
	race.player.set_driver_character("fox")
	race._update_vehicles(0.5)
	state = feedback.visual_state()
	_check(
		(
			state.clock == paused_clock
			and state.events == 0
			and state.trail_segments == 0
			and state.contacts == 0
		),
		"driver rebuild during real pause clears stale attachments without advancing time"
	)
	race._resume()
	race.drifting = true
	race.steering = 0.7
	race.boost_time = 0.0
	race._update_vehicles(1.0 / 60.0)
	_check(
		feedback.visual_state().contacts == 2,
		"resuming after the driver rebuild restores the actual rear tyre contacts"
	)
