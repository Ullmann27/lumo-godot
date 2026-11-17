extends SceneTree
## Real world placement and actual animated instance transforms, not a mock.
const WORLD = preload("res://scripts/games/kart_world.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr(
			"Harbor instance-transform proof requires a real renderer; use Xorg/Xvfb with GL compatibility"
		)
		quit(2)
		return
	for low in [true, false]:
		var world = WORLD.new()
		root.add_child(world)
		world.build(low, "sonnenhafen", true)
		var attraction = world.get_node_or_null("SonnenhafenHarborAttraction")
		_check(attraction != null, "Harbor attraction must be connected to the real world")
		if attraction == null:
			continue
		var props: MultiMesh = attraction.get_node("UprightCabinsAndSpokes").multimesh
		var initial: Transform3D = props.get_instance_transform(2)
		var racer: Vector3 = world.position_at(95.0)
		for i in range(120):
			attraction.advance(1.0 / 60.0, racer, true, false)
		var moved: Transform3D = props.get_instance_transform(2)
		print(
			"[HarborAttraction] movement=",
			initial.origin.distance_to(moved.origin),
			" initial=",
			initial.origin,
			" moved=",
			moved.origin,
			" phase=",
			attraction.phase
		)
		_check(
			initial.origin.distance_to(moved.origin) > 1.0,
			"Cabins must genuinely travel around the wheel"
		)
		_check(attraction.trigger_count == 1, "One approach must cause exactly one welcome wave")
		_check(moved.basis.y.normalized().dot(Vector3.UP) > 0.99, "Cabin floors must stay upright")
		var phase: float = attraction.phase
		attraction.advance(1.0, racer, false, false)
		attraction.advance(1.0, racer, true, true)
		_check(
			is_equal_approx(phase, attraction.phase),
			"Pause and reduced motion must freeze the wheel"
		)
		attraction.advance(0.1, attraction.position + Vector3.RIGHT * 90.0, true, false)
		attraction.advance(0.1, racer, true, false)
		_check(attraction.trigger_count == 2, "Leaving and re-entering must rearm the attraction")
		phase = attraction.phase
		attraction.advance(0.1, attraction.position + Vector3.RIGHT * 500.0, true, false)
		_check(
			is_equal_approx(phase, attraction.phase), "Distant attractions must stop animation work"
		)
		_check(
			attraction.get_child_count() == 2, "Wheel must stay within two instanced draw groups"
		)
		for child in attraction.get_children():
			_check(not child is CollisionObject3D, "Decoration must not obstruct the race road")
		print(
			"[HarborAttraction] low=",
			low,
			" static_parts=",
			world.get_meta("sonnenhafen_generation_parts"),
			" moving_parts=",
			props.instance_count,
			" welcome_triggers=",
			attraction.trigger_count
		)
		world.queue_free()
		await process_frame
	for failure in failures:
		printerr("[HarborAttraction] FAIL ", failure)
	if failures.is_empty():
		print(
			(
				"[HarborAttraction] PASS: LOW/HIGH placement, upright travel, "
				+ "pass-by, rearm, pause, reduced motion, distance culling"
			)
		)
	quit(0 if failures.is_empty() else 1)
