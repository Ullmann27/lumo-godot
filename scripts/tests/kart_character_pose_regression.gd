extends SceneTree
## Replays real animation updates; construction-only checks missed rest-pose snaps.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[CharacterPose] FAIL: ", label)


func _ear_angles(kart) -> Array[float]:
	var angles: Array[float] = []
	for ear in kart.ear_joints:
		angles.append(ear.rotation.z)
	return angles


func _check_ears(kart, expected: Array[float], label: String, animated: bool = false) -> void:
	_check(kart.ear_joints.size() == expected.size(), label + " ear count")
	for index in range(mini(kart.ear_joints.size(), expected.size())):
		var difference: float = absf(kart.ear_joints[index].rotation.z - expected[index])
		_check(difference <= (0.0181 if animated else 0.00001), label + " ear " + str(index))


func _exercise_animal(animal: String, reduced: bool) -> Dictionary:
	var label: String = animal + " reduced_motion=" + str(reduced)
	var kart = VEHICLE.new()
	kart.configure(animal, Color("1d4fa0"), "comet")
	root.add_child(kart)
	kart.set_process(false)
	kart.reduced_motion = reduced
	var authored_jaw: Vector3 = kart.jaw.position
	var race_ears: Array[float] = _ear_angles(kart)
	kart._process(1.0 / 60.0)
	_check(kart.jaw.position.is_equal_approx(authored_jaw), label + " idle preserves authored jaw")
	kart.set_motion(20.0, 0.6, true, true)
	for amount in [0.25, 1.0, 0.0]:
		kart.set_speaking(amount)
		kart._process(1.0 / 60.0)
		_check(
			kart.jaw.position.is_equal_approx(authored_jaw + Vector3(0, -amount * 0.035, 0)),
			label + " racing speech offsets its own rest pose"
		)
	if reduced:
		_check(is_zero_approx(kart.driver.position.y), label + " race body bob is disabled")
		_check(is_zero_approx(kart.head.rotation.z), label + " race head roll is disabled")
	kart.celebrate(1)
	kart._process(1.0 / 60.0)
	_check(
		kart.jaw.position.is_equal_approx(authored_jaw),
		label + " celebration preserves lip placement"
	)
	if reduced:
		_check(is_zero_approx(kart.driver.position.y), label + " celebration hop is disabled")
	kart.configure_companion(animal)
	var companion_jaw: Vector3 = kart.jaw.position
	var authored_ears: Array[float] = _ear_angles(kart)
	_check(authored_ears.size() == 2, label + " rebuilt companion has both ears")
	# Companion movement predates this patch; here both settings must retain
	# the sculpted anatomy, regardless of the existing decorative motion policy.
	for frame in range(120):
		var t: float = float(frame) / 60.0
		var voice: float = 0.0 if frame < 60 else 0.75
		kart.set_companion_pose(t, "idle" if frame < 60 else "speaking", voice)
		_check(
			kart.jaw.position.is_equal_approx(companion_jaw + Vector3(0, -voice * 0.044, 0)),
			label + " companion speech frame " + str(frame)
		)
		for index in range(kart.ear_joints.size()):
			_check(
				absf(kart.ear_joints[index].rotation.z - authored_ears[index]) <= 0.0181,
				label + " authored ear silhouette frame " + str(frame)
			)
	# Return from an animated companion to the same racing character. Compare
	# with the first construction, not with a potentially stale rebuilt cache.
	kart.configure(animal, Color("1d4fa0"), "comet")
	kart.celebrate(0)
	kart.set_speaking(0.0)
	_check(not kart.companion_mode, label + " companion returns to racing mode")
	_check(
		kart.jaw.position.is_equal_approx(authored_jaw),
		label + " rebuild restores original racing jaw"
	)
	_check_ears(kart, race_ears, label + " companion-to-race rebuild")
	kart._process(1.0 / 60.0)
	_check(
		kart.jaw.position.is_equal_approx(authored_jaw), label + " rebuilt race idle keeps its jaw"
	)
	kart.set_speaking(1.0)
	kart._process(1.0 / 60.0)
	_check(
		kart.jaw.position.is_equal_approx(authored_jaw + Vector3(0, -0.035, 0)),
		label + " rebuilt race speech keeps its own rest pose"
	)
	kart.free()
	return {"jaw": companion_jaw, "ears": authored_ears}


func _exercise_animal_switches(reduced: bool, independent_poses: Dictionary) -> void:
	var kart = VEHICLE.new()
	kart.configure_companion("fox")
	root.add_child(kart)
	kart.set_process(false)
	kart.reduced_motion = reduced
	var sequence: Array[String] = ["fox", "rabbit", "fox"]
	for step in range(sequence.size()):
		var animal: String = sequence[step]
		if step > 0:
			kart.set_driver_character(animal)
		var label: String = (
			"same-instance step " + str(step) + " " + animal + " reduced_motion=" + str(reduced)
		)
		var expected_jaw: Vector3 = independent_poses[animal]["jaw"]
		var expected_ears: Array[float] = independent_poses[animal]["ears"]
		_check(kart.companion_mode, label + " keeps companion mode")
		_check(
			kart.jaw.position.is_equal_approx(expected_jaw),
			label + " restores independently authored jaw"
		)
		_check_ears(kart, expected_ears, label + " rebuilt authored ears")
		kart.set_companion_pose(0.37, "speaking", 0.75)
		_check(
			kart.jaw.position.is_equal_approx(expected_jaw + Vector3(0, -0.75 * 0.044, 0)),
			label + " speech uses new animal rest pose"
		)
		_check_ears(kart, expected_ears, label + " animated rebuilt ears", true)
		# Exercise the production automatic companion update as well as the
		# direct pose API used by the atlas and treasure-game controllers.
		kart.set_speaking(0.5)
		kart._process(1.0 / 60.0)
		_check(
			kart.jaw.position.is_equal_approx(expected_jaw + Vector3(0, -0.5 * 0.044, 0)),
			label + " automatic companion speech uses new rest pose"
		)
		_check_ears(kart, expected_ears, label + " automatic rebuilt ears", true)
	kart.free()


func _run() -> void:
	for reduced in [false, true]:
		var independent_poses: Dictionary = {}
		for animal in ["fox", "rabbit", "otter"]:
			independent_poses[animal] = _exercise_animal(animal, reduced)
		_exercise_animal_switches(reduced, independent_poses)
	print("[CharacterPose] checks=", checks, " failures=", failures.size())
	if failures.is_empty():
		print(
			"[CharacterPose] PASS: racing, companion, speech, reduced motion and rebuilds "
			+ "preserve authored anatomy"
		)
	quit(0 if failures.is_empty() else 1)
