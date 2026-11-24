extends "res://tools/lumo_kart_art/review/original_lumo_anchor_probe.gd"
## Real Original-Lumo skin and hand/pedal contacts across the imported chassis.
## Surface dumps are checked independently against the frozen Blender meshes.

const VARIANTS := ["comet", "glider", "turbo"]
const SAMPLE_TIMES := [0.2, 0.7, 1.5]
const PHASES := ["driving", "left", "right", "jump", "landing", "finish"]
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var sample_directory := "/tmp/lumo-original-seat-validation"

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[OriginalLumoSeat] " + label)

func _sample(kart, variant: String, phase: String, at: float) -> void:
	var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	var greatest_hand := 0.0
	var hand_count := 1 if phase == "finish" else 2
	for side in range(hand_count):
		var index := skeleton.find_bone("Hand.L" if side == 0 else "Hand.R")
		var actual := skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
		var expected: Vector3 = kart.steering_wheel.to_global(kart.wheel_rest_grips[side])
		greatest_hand = maxf(greatest_hand, actual.distance_to(expected))
	_check(greatest_hand < 0.006, "%s %s %.1f hand contact" % [variant, phase, at])
	var fit = kart.production_lumo_seat
	_check(fit.maximum_foot_error < 0.001, "%s %s %.1f leg reach" % [variant, phase, at])
	var support_error := 0.0
	for side in range(2):
		var vertices: Array[Vector3] = fit._foot_vertices("L" if side == 0 else "R", Transform3D.IDENTITY)
		var lowest := INF
		for vertex in vertices:
			lowest = minf(lowest, vertex.y)
		support_error = maxf(support_error, absf(lowest - fit.support_points[side].y - fit.SOLE_CLEARANCE))
	_check(support_error < 0.002, "%s %s %.1f skinned sole contact" % [variant, phase, at])
	_skin_bounds(kart, true)
	var geometry := sample_directory + "/%s_%s_%03d.json" % [variant, phase, int(at * 10.0)]
	_check(DirAccess.rename_absolute("/tmp/lumo-original-fit-comet.json", geometry) == OK, "Save evaluated skin " + geometry)
	samples.append({"variant": variant, "phase": phase, "seconds": at,
		"geometry": geometry, "hand_error_m": greatest_hand,
		"foot_error_m": fit.maximum_foot_error, "sole_support_error_m": support_error})

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="):
			sample_directory = argument.trim_prefix("--samples=")
	DirAccess.make_dir_recursive_absolute(sample_directory)
	for variant in VARIANTS:
		var kart = VEHICLE.new()
		kart.configure("fox", Color.WHITE, variant)
		kart.set_animated_lumo_enabled(true)
		root.add_child(kart)
		kart.set_process(false)
		kart.position = Vector3(3.0, 1.0, -5.0)
		kart.quaternion = Quaternion(Vector3.UP, 0.37)
		_check(is_instance_valid(kart.production_lumo_seat), variant + " binds actual original-rig seat fit")
		_check(kart.lumo_animation.actor.skeleton.get_bone_count() == 65, variant + " preserves original rig")
		_check(kart.lumo_animation.actor.scale.is_equal_approx(Vector3.ONE * 1.15), variant + " preserves uniform actor scale")
		for phase in PHASES:
			var steering := -1.0 if phase == "left" else (1.0 if phase == "right" else 0.0)
			kart.set_motion(18.0, steering, phase == "driving", phase in ["left", "right"])
			kart.set_driver_runtime_state(phase == "jump", false, false)
			if phase == "finish":
				kart.celebrate(1)
			var elapsed := 0.0
			for at in SAMPLE_TIMES:
				while elapsed + 0.00001 < at:
					kart._process(1.0 / 60.0)
					elapsed += 1.0 / 60.0
				_sample(kart, variant, phase, at)
		kart.free()
	var evidence := "res://evidence/lumo_kart_runtime/karts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var report := {"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks,
		"failures": failures, "engine": Engine.get_version_info().string, "samples": samples,
		"model_sha256": FileAccess.get_sha256("res://assets/characters/lumo_facial/Lumo-Facial-Mobile.glb"),
		"original_model_sha256": FileAccess.get_sha256("res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb"),
		"scope": "Original character, actual skin vertices and wheel contact. Surface clearance needs the separate Blender BVH gate."}
	var output := FileAccess.open(evidence + "/original_lumo_seat_contacts.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("[OriginalLumoSeat] ", report.status, ": ", checks, " checks, ", samples.size(), " actual skinned poses")
	quit(0 if failures.is_empty() else 1)
