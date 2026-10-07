extends SceneTree
## Construction/animation smoke check for the real meshes, all offered variants and the shared avatar.
const Kart = preload("res://scripts/games/kart_vehicle.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	for racer in ["fox", "rabbit", "otter", "badger", "cat"]:
		var kart = Kart.new()
		root.add_child(kart)
		kart.configure(racer, Color("357cba"), "comet")
		_check(kart.head != null and kart.eyes.size() == 2, racer + " face joints")
		_check(kart.wheel_pivots.size() == 4 and kart.wheel_rotors.size() == 4, racer + " wheels")
		_check(kart.far_mesh != null and kart.far_mesh.mesh.get_surface_count() == 1, racer + " batched distance mesh")
		kart.set_motion(12.0, 0.6, true, true)
		kart._process(0.016)
		_check(kart.flames[0].visible and kart.sparks[0].visible, racer + " boost and drift effects")
		_check(absf(kart.wheel_pivots[0].rotation.y) > 0.05, racer + " steering joint")
		kart._set_far_detail(true)
		_check(kart.far_mesh.visible, racer + " far mesh visibility")
		for mesh in kart.near_meshes:
			_check(not mesh.visible, racer + " close mesh hidden at distance")
		kart._set_far_detail(false)
		var close_triangles: int = 0
		var close_surfaces: int = 0
		for mesh in kart.near_meshes:
			close_surfaces += mesh.mesh.get_surface_count()
			for index in range(mesh.mesh.get_surface_count()):
				close_triangles += mesh.mesh.surface_get_array_index_len(index) / 3
		var far_triangles: int = kart.far_mesh.mesh.surface_get_array_index_len(0) / 3
		print("GEOMETRY %s close_triangles=%d far_triangles=%d near_surfaces=%d" % [racer, close_triangles, far_triangles, close_surfaces])
		_check(far_triangles < close_triangles, racer + " distance triangle reduction")
		if racer == "fox":
			kart.set_graphics_quality("light")
			_check(is_equal_approx(kart.detail_distance, 14.0), "light distance profile")
			kart.set_graphics_quality("medium")
			_check(is_equal_approx(kart.detail_distance, 22.0), "medium distance profile")
			kart.set_graphics_quality("high")
			_check(is_equal_approx(kart.detail_distance, 32.0), "high distance profile")
			for style in ["glider", "turbo", "comet"]:
				kart.set_kart_style(style)
				_check(kart.kart_style == style and kart.wheel_rotors.size() == 4, "rebuild " + style)
		kart.free()
	var companion = Kart.new()
	companion.configure_companion("fox")
	root.add_child(companion)
	companion.set_process(false)
	_check(companion.arm_joints.size() == 2 and companion.leg_joints.size() == 2, "companion limbs")
	for mood in ["idle", "speaking", "cheer", "think", "help", "walk"]:
		companion.set_companion_pose(0.4, mood, 0.7 if mood == "speaking" else 0.0)
		for joint in companion.arm_joints + companion.elbow_joints + companion.leg_joints + companion.ear_joints:
			_check(joint.transform.is_finite(), mood + " finite joint pose")
		companion.set_companion_pose(0.0, mood, 0.0)
		var start: Transform3D = companion.arm_joints[0].transform
		companion.set_companion_pose(4.0 if mood == "idle" else 1.0, mood, 0.0)
		_check(start.is_equal_approx(companion.arm_joints[0].transform), mood + " seamless atlas loop")
	companion.set_companion_pose(2.25, "idle", 0.0)
	_check(companion.eyes[0].scale.y < 0.1, "deterministic blink")
	companion.set_companion_pose(0.0, "speaking", 1.0)
	_check(companion.jaw.position.y < -0.29, "voice jaw opens")
	companion.free()
	for failure in failures:
		push_error(failure)
	print("KART_GEOMETRY_CHECK " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
