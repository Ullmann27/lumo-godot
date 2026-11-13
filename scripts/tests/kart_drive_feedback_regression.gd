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


func _production_events() -> void:
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
	game.abandoned = true
	game.queue_free()
	await process_frame
