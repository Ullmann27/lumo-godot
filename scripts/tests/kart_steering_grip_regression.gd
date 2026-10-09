extends SceneTree
## Measures the authored glove meshes against the rotating physical wheel.
## Targets are sampled from their neutral world contact, not solver constants.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const CONTACT_TOLERANCE := 0.0005
var failures: int = 0
var measurements: int = 0
var worst_error: float = 0.0


class AuthoredKart:
	extends LumoRaceKart

	func _make_far_mesh() -> void:
		pass

	func _merge_static(_parent: Node3D) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _check_contact(
	kart: LumoRaceKart, glove: MeshInstance3D, target: Vector3, label: String
) -> void:
	var expected: Vector3 = kart.steering_wheel.global_transform * target
	var error: float = glove.global_position.distance_to(expected)
	measurements += 1
	worst_error = maxf(worst_error, error)
	if error > CONTACT_TOLERANCE:
		failures += 1
		if failures <= 8:
			push_error(
				"[KartSteeringGrip] %s: hand leaves moving rim by %.2f mm" % [label, error * 1000.0]
			)


func _exercise(kind: String, style: String, reduced: bool) -> void:
	var kart := AuthoredKart.new()
	kart.configure(kind, Color("76d9ff"), style)
	kart.reduced_motion = reduced
	root.add_child(kart)
	kart.set_process(false)
	var gloves: Array[Node] = kart.driver.find_children("GripGlove", "MeshInstance3D", true, false)
	if gloves.size() != 2:
		failures += 1
		push_error(
			"[KartSteeringGrip] %s: two separately addressable authored gloves required" % kind
		)
		kart.free()
		return
	var targets: Array[Vector3] = []
	for glove: MeshInstance3D in gloves:
		targets.append(
			kart.steering_wheel.global_transform.affine_inverse() * glove.global_position
		)
	for profile in ["high", "light"]:
		kart.set_graphics_quality(profile)
		for steer in [0.0, -1.0, 1.0, -0.55, 0.35, 0.0]:
			kart.set_motion(18.0, steer, steer == 0.35, absf(steer) > 0.5)
			for frame in range(18):
				kart._process(1.0 / 60.0)
				for i in range(gloves.size()):
					_check_contact(
						kart,
						gloves[i],
						targets[i],
						(
							"%s/%s/%s reduced=%s steer=%s frame=%d hand=%d"
							% [kind, style, profile, reduced, steer, frame, i]
						)
					)
	if kind == "fox":
		kart.celebrate(1)
		for frame in range(24):
			kart._process(1.0 / 60.0)
			_check_contact(kart, gloves[0], targets[0], "Victory retains left grip")
		var released: float = gloves[1].global_position.distance_to(
			kart.steering_wheel.global_transform * targets[1]
		)
		assert(released > 0.3, "Right hand visibly releases its grip for the existing victory wave")
		kart.celebrate(0)
		for frame in range(24):
			kart._process(1.0 / 60.0)
		for i in range(gloves.size()):
			_check_contact(kart, gloves[i], targets[i], "Victory returns both hands to the rim")
	kart.free()


func _run() -> void:
	for reduced in [false, true]:
		for entry in CATALOG.KARTS:
			_exercise("fox", str(entry.id), reduced)
		for kind in ["rabbit", "otter", "badger", "cat"]:
			_exercise(kind, "comet", reduced)
	# Reconfiguration retains no stale arm references and the batched live rig
	# solves its contact again on the first frame after a LOD return/rebuild.
	var kart: LumoRaceKart = VEHICLE.new()
	root.add_child(kart)
	kart.set_process(false)
	for kind in ["fox", "rabbit", "fox"]:
		kart.configure(kind, Color("76d9ff"), "comet")
		kart._set_far_detail(true)
		kart.set_motion(18.0, 1.0, true, true)
		kart._process(1.0 / 60.0)
		kart._set_far_detail(false)
		kart._process(1.0 / 60.0)
		var anchors := kart.driver.find_children("SteeringGripAnchor", "Node3D", true, false)
		if anchors.size() != 2:
			failures += 1
			push_error(
				"[KartSteeringGrip] Batched mobile rig lacks two contact anchors after rebuild"
			)
			break
		for anchor: Node3D in anchors:
			var wheel_space: Vector3 = (
				kart.steering_wheel.global_transform.affine_inverse() * anchor.global_position
			)
			assert(
				(
					absf(wheel_space.z) < 0.005
					and Vector2(wheel_space.x, wheel_space.y).length() >= 0.135
					and Vector2(wheel_space.x, wheel_space.y).length() <= 0.175
				)
			)
	kart.free()
	print(
		(
			"[KartSteeringGrip] measurements=%d max_error_mm=%.4f failures=%d"
			% [measurements, worst_error * 1000.0, failures]
		)
	)
	if failures == 0:
		print(
			(
				"[KartSteeringGrip] PASS: both authored gloves follow idle/steer/drift/boost, "
				+ "%d Lumo karts, 5 drivers, 2 detail levels, reduced motion, " % CATALOG.KARTS.size()
				+ "victory release/return and rebuilt mobile LOD"
			)
		)
	quit(0 if failures == 0 else 1)
