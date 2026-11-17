extends SceneTree
## Evaluate exported driver bones against moving kart grip and foot markers.

const DRIVERS := ["rabbit", "lion", "owl", "squirrel", "turtle"]
const KARTS := ["comet", "glider", "turbo"]
const CLIPS := ["kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump"]
var repo := ""
var errors: Array[String] = []
var cases: Array = []


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://../../../").simplify_path().trim_suffix("/")
	_run.call_deferred()


func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null


func _run() -> void:
	var loader = load(repo.path_join("tools/lumo_kart_art/asset_contract_loader.gd"))
	var sources := {}
	var maximum_error := 0.0
	for driver_id in DRIVERS:
		var driver_path: String = "assets/kart/production/drivers/" + str(driver_id) + "/driver.glb"
		var driver: Node3D = loader.load_model(repo.path_join(driver_path))
		if driver == null:
			errors.append("Missing driver " + str(driver_id))
			continue
		root.add_child(driver)
		sources[driver_path] = FileAccess.get_sha256(repo.path_join(driver_path))
		var skeleton := _find_type(driver, "Skeleton3D") as Skeleton3D
		var player := _find_type(driver, "AnimationPlayer") as AnimationPlayer
		if skeleton == null or player == null:
			errors.append("Unusable driver rig " + str(driver_id))
			driver.free()
			continue
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for kart_id in KARTS:
			var kart_path: String = "assets/kart/production/karts/aurora_" + str(kart_id) + ".glb"
			var kart: Node3D = loader.load_model(repo.path_join(kart_path))
			if kart == null:
				errors.append("Missing kart " + str(kart_id))
				continue
			root.add_child(kart)
			sources[kart_path] = FileAccess.get_sha256(repo.path_join(kart_path))
			var steering := kart.find_child("SteeringWheel", true, false) as Node3D
			var rest_basis := steering.basis
			for clip in CLIPS:
				var duration := player.get_animation(clip).length
				for fraction in [0.13, 0.5, 0.89]:
					player.play(clip, 0.0)
					player.seek(duration * float(fraction), true)
					player.advance(0.0)
					skeleton.force_update_all_bone_transforms()
					var turn := 0.0
					if clip == "kart_steer_left" or clip == "kart_steer_right":
						var t := clampf((duration * float(fraction) - 1.0 / 24.0) / (duration - 1.0 / 24.0), 0.0, 1.0)
						turn = sin(PI * minf(1.0, t / 0.25) / 2.0) if t < 0.25 else 1.0 if t < 0.75 else cos(PI * (t - 0.75) / 0.25 / 2.0)
						if clip == "kart_steer_right":
							turn = -turn
					steering.basis = rest_basis * Basis(Vector3.BACK, -turn * 0.4)
					for side in ["L", "R"]:
						for part in ["Hand", "Foot"]:
							var bone_name: String = str(part) + "." + str(side)
							var index := skeleton.find_bone(bone_name)
							var marker_name: String = ("Grip_" if part == "Hand" else "Foot_") + str(side)
							var marker := kart.find_child(marker_name, true, false) as Node3D
							if index < 0 or marker == null:
								errors.append("Missing contact " + bone_name + "/" + marker_name)
								continue
							var bone_point := skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
							var distance := bone_point.distance_to(marker.global_position)
							maximum_error = maxf(maximum_error, distance)
							cases.append({"driver": driver_id, "kart": kart_id, "clip": clip,
								"phase": fraction, "contact": bone_name, "error_m": distance})
							if distance > 0.01:
								errors.append("Contact exceeds 10 mm: %s/%s/%s/%s = %.6f m" % [driver_id, kart_id, clip, bone_name, distance])
			kart.free()
		driver.free()
		await process_frame
	var output := repo.path_join("evidence/lumo_kart_art/review/godot_driver_kart_fit.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write contact report")
		quit(2)
		return
	file.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "passed": errors.is_empty(),
		"sources": sources, "maximum_error_m": maximum_error, "threshold_m": 0.01,
		"method": "Exported Skeleton3D global poses against moving SteeringWheel grip and fixed foot markers",
		"physical_android": false, "measurements": cases, "errors": errors}, "  "))
	file.close()
	for error in errors:
		printerr(error)
	print("[LumoKartDriverFit] ", "PASS" if errors.is_empty() else "FAIL", " measurements=", cases.size(), " maximum_error_m=", maximum_error)
	quit(0 if errors.is_empty() else 1)
