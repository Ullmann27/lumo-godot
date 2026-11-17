extends SceneTree
## Tests the actual vehicle class used by the race, garage and workshop.

const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const GARAGE := "res://scripts/games/kart_garage_menu.gd"
const DRIVER_SPECIES: Array[String] = ["rabbit", "lion", "squirrel", "owl", "turtle"]
var results: Array[Dictionary] = []
var failures: Array[String] = []
var assertion_count := 0
var camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _require(value: bool, message: String) -> void:
	assertion_count += 1
	if not value:
		failures.append(message)
		push_error("[ProductionKart] " + message)
		quit(1)
		assert(value, message)


func _kart(variant: String, species: String = "fox"):
	var kart = VEHICLE.new()
	kart.configure(species, Color("76d9ff"), variant)
	kart.set_animated_lumo_enabled(true)
	kart.set_graphics_quality("high")
	root.add_child(kart)
	kart.set_process(false)
	return kart


func _distance(kart, metres: float) -> void:
	camera.position = kart.position + Vector3(0, 0, metres)
	camera.look_at(kart.position + Vector3(0, 0.8, 0))
	kart._update_detail(camera)


func _material(kart, fragment: String, wheel: bool = false) -> StandardMaterial3D:
	for item in kart.production_vehicle.asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if not mesh.visible or (wheel and not str(mesh.name).begins_with("Wheel_")):
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source != null and fragment in source.resource_name:
				return mesh.get_active_material(surface) as StandardMaterial3D
	return null


func _check_variant(variant: String) -> void:
	var kart = _kart(variant)
	_require(is_instance_valid(kart.production_vehicle), variant + " must use its imported asset")
	_require(is_instance_valid(kart.lumo_animation), "Original Lumo retains his existing player adapter")
	_require(not is_instance_valid(kart.production_driver), "Original Lumo cannot be replaced by a rival")
	var production = kart.production_vehicle
	_require(production.source_paths.size() == 3, "All authored LOD resources must be bound")
	_require(production.find_children("*", "AnimationPlayer", true, false).is_empty(), "Demonstration animation cannot run over physics")
	_require(kart.wheel_pivots.size() == 4 and kart.wheel_rotors.size() == 4, "Four real mechanical assemblies")
	var anchors: Array[int] = []
	var rest_bases: Array[Basis] = []
	var stance := 0.91 if variant == "glider" else (1.10 if variant == "turbo" else 1.0)
	for index in range(4):
		var pivot: Node3D = kart.wheel_pivots[index]
		anchors.append(pivot.get_instance_id())
		rest_bases.append(kart.wheel_rotors[index].basis)
		_require(absf(absf(pivot.position.x) - 0.77 * stance) < 0.00001, "Authored wheel stance")
		_require(absf(pivot.position.y - 0.35) < 0.00001, "Authored ground contact height")
		_require(absf(absf(pivot.position.z) - 0.66) < 0.00001, "Authored wheelbase")
	var wheel_id: int = kart.steering_wheel.get_instance_id()
	var wheel_normal: Vector3 = kart.steering_wheel.basis.z
	_distance(kart, 5.0)
	kart.set_motion(3.5, 0.75, false, false)
	kart._process(0.1)
	_require(absf(kart.wheel_spin_phase - 1.0) < 0.00001, "Wheel rotation derives from distance divided by radius")
	for index in range(4):
		var rotor: Node3D = kart.wheel_rotors[index]
		_require((rotor.basis * Vector3.UP).z < -0.8, "Forward roll moves the top of the tyre toward -Z")
		var front: bool = kart.wheel_pivots[index].get_meta("front")
		_require(absf(kart.wheel_pivots[index].rotation.y - (-0.255 if front else 0.0)) < 0.00001, "Front steering and fixed rear axle")
	_require(kart.steering_wheel.basis.z.distance_to(wheel_normal) < 0.00001, "Local steering preserves the inclined wheel plane")
	var original_lumo_contact := 0.0
	var original_skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
	for side in range(2):
		var hand := original_skeleton.find_bone("Hand.L" if side == 0 else "Hand.R")
		var tip := original_skeleton.to_global(original_skeleton.get_bone_global_pose(hand).origin)
		var target: Vector3 = kart.steering_wheel.to_global(kart.wheel_rest_grips[side])
		original_lumo_contact = maxf(original_lumo_contact, tip.distance_to(target))
		_require(tip.distance_to(target) < 0.006, "Original Lumo's actual hand bones retain the established contact tolerance")
	kart.set_motion(-3.5, 0.0, false, false)
	kart._process(0.1)
	for index in range(4):
		_require(kart.wheel_rotors[index].basis.is_equal_approx(rest_bases[index]), "Reverse cancels the same travelled distance")
	var profiles := {"high": [16.0, 36.0], "medium": [11.0, 27.0], "low": [7.0, 18.0]}
	for profile in profiles:
		kart.set_graphics_quality(profile)
		var limits: Array = profiles[profile]
		for sample in [[3.0, 0], [limits[0] + 1.0, 1], [limits[1] + 1.0, 2], [limits[1] - 1.0, 2], [limits[0] - 3.0, 0]]:
			_distance(kart, float(sample[0]))
			_require(production.lod_level == int(sample[1]), "Distance/profile LOD and hysteresis")
			_require(production.visible_surface_count() <= 39, "Only one complete authored LOD is drawn")
			for index in range(4):
				_require(kart.wheel_pivots[index].get_instance_id() == anchors[index], "LOD retains physical wheel anchors")
			_require(kart.steering_wheel.get_instance_id() == wheel_id, "LOD retains the driver steering reference")
	_distance(kart, 60.0)
	var distant_basis: Basis = kart.wheel_rotors[0].basis
	kart.set_motion(12.0, 0.5, true, true)
	kart.set_braking(1.0)
	kart._process(0.1)
	_require(not kart.wheel_rotors[0].basis.is_equal_approx(distant_basis), "Far LOD wheels remain driven by speed")
	_require(kart.flames.size() == 2 and kart.sparks.size() == 2 and kart.brake_lights.size() == 2, "Feedback anchors remain connected")
	_require(kart.flames[0].visible and kart.sparks[0].visible, "Real boost/drift inputs drive feedback")
	var brake := _material(kart, "RearBrakeLens")
	_require(brake != null and brake.emission_energy_multiplier > 2.0, "Brake state reaches the actual imported rear lenses")
	kart.set_preview_detail(true)
	_distance(kart, 60.0)
	_require(production.lod_level == 0 and not kart.far_detail, "Garage presentation keeps the full-detail model")
	var paused_basis: Basis = kart.wheel_rotors[0].basis
	var paused_time: float = kart.animation_time
	kart.set_driver_runtime_state(false, false, true)
	kart._process(0.2)
	_require(kart.wheel_rotors[0].basis.is_equal_approx(paused_basis) and kart.animation_time == paused_time, "Pause freezes both mechanics and character clock")
	kart.set_driver_runtime_state(false, false, false)
	kart.reduced_motion = true
	kart._process(0.05)
	_require(not kart.wheel_rotors[0].basis.is_equal_approx(paused_basis), "Reduced motion retains physical wheel travel")
	results.append({"variant": variant, "lod_paths": production.source_paths.duplicate(), "visible_surfaces": production.visible_surface_count(), "mechanics_pause_lod_passed": true,
		"original_lumo_steering_sample_hand_error_m": original_lumo_contact})
	kart.free()


func _check_tuning() -> void:
	var reference = _kart("comet")
	var stock := _material(reference, "_paint")
	var stock_color := stock.albedo_color
	var edited = _kart("comet")
	edited.set_look({"paint": Color("b3202a"), "trim": Color.WHITE, "accent": Color("ffc23a"),
		"rim": Color("e8b34c"), "rim_neon": true, "neon": Color("ff44bb"), "neon_custom": true})
	_require(_material(edited, "_paint").albedo_color.is_equal_approx(Color("b3202a")), "Workshop paint reaches the imported finish")
	_require(_material(edited, "BrushedAluminium", true).albedo_color.is_equal_approx(Color("e8b34c")), "Workshop rim selection reaches the wheel surfaces")
	_require(_material(edited, "InsetCyanLens").emission.is_equal_approx(Color("ff44bb")), "Workshop neon reaches the actual light surfaces")
	_require(stock.albedo_color.is_equal_approx(stock_color), "A tuned vehicle cannot mutate shared stock materials")
	for level in range(3):
		edited.production_vehicle.set_lod(level)
		_require(_material(edited, "_paint").albedo_color.is_equal_approx(Color("b3202a")), "Tuning survives every LOD")
	results.append({"tuning_and_shared_material_isolation": true})
	edited.free()
	reference.free()


func _check_rivals() -> void:
	for species in DRIVER_SPECIES:
		var kart = _kart("glider", species)
		_require(is_instance_valid(kart.production_driver) and kart.production_driver.is_usable(), "Actual production rival must bind")
		_require(not is_instance_valid(kart.lumo_animation), "Rivals cannot instantiate Original Lumo")
		_distance(kart, 5.0)
		kart.set_motion(8.0, -0.8, false, false)
		kart._process(0.04)
		_require(kart.production_driver.maximum_contact_error < 0.001, "Bound rival hands follow the real wheel")
		var peak_contact: float = kart.production_driver.maximum_contact_error
		_distance(kart, 55.0)
		kart._process(0.04)
		peak_contact = maxf(peak_contact, kart.production_driver.maximum_contact_error)
		_require(kart.production_driver.visual_lod == 2, "Kart distance reaches the driver LOD hook")
		kart.set_driver_runtime_state(true, true, false)
		kart._process(0.04)
		peak_contact = maxf(peak_contact, kart.production_driver.maximum_contact_error)
		_require(kart.production_driver.airborne, "Real airborne state reaches the rig")
		kart.celebrate(1)
		peak_contact = maxf(peak_contact, kart.production_driver.maximum_contact_error)
		_require(kart.production_driver.victory, "Finish event reaches the actual driver helper")
		_require(peak_contact < 0.001, "Checked steer/LOD/airborne/finish poses retain the real steering contact")
		results.append({"species": species, "shared_vehicle_driver_hook": true, "maximum_sampled_grip_error_m": peak_contact})
		kart.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for variant in ["comet", "glider", "turbo"]:
		_check_variant(variant)
	_check_tuning()
	_check_rivals()
	var previous = _kart("blitz")
	_require(not is_instance_valid(previous.production_vehicle), "Unconverted fleet designs retain their authored procedural model")
	_require(previous.wheel_rotors.size() == 4, "Legacy vehicle API remains intact")
	previous.free()
	# Garage resolves project autoloads after the SceneTree has initialized.
	var garage = load(GARAGE).new()
	garage.stars = 100
	garage.reduced_motion = true
	garage.workshop = TUNING.new("production_vehicle_regression", 100)
	garage.workshop.save_enabled = false
	root.add_child(garage)
	await process_frame
	garage.step = 2
	garage.setup.kart = "glider"
	garage._refresh()
	await process_frame
	_require(is_instance_valid(garage.preview_kart.production_vehicle), "Real garage selection displays the GLB kart")
	_require(garage.preview_kart.production_vehicle.lod_level == 0, "Real garage preview keeps full detail")
	garage.workshop_button.pressed.emit()
	await process_frame
	var workshop = garage.workshop_view
	_require(is_instance_valid(workshop), "Actual workshop button opens the preview")
	_require(is_instance_valid(workshop.preview_kart.production_vehicle), "Workshop displays the imported selection")
	_require(is_instance_valid(workshop.preview_kart.lumo_animation), "Workshop preserves Original Lumo's actual adapter")
	_require(workshop.preview_kart.production_vehicle.lod_level == 0, "Workshop keeps the authored full-detail model")
	var swatch: Button = workshop.find_child("Swatch_feuer", true, false)
	_require(swatch != null, "Workshop exposes its real paint swatch")
	swatch.pressed.emit()
	_require(_material(workshop.preview_kart, "_paint").albedo_color.is_equal_approx(Color("b3202a")), "Actual swatch changes the imported paint immediately")
	_require(workshop.tuning.chosen("glider", "paint") == "werk", "Trying paint preserves the purchase state")
	workshop.back_button.pressed.emit()
	await process_frame
	_require(not is_instance_valid(garage.workshop_view), "Actual back button closes the workshop")
	results.append({"garage_selection_and_workshop_buttons": true, "paint_preview_without_purchase": true})
	garage.queue_free()
	await process_frame
	var evidence := "res://evidence/lumo_kart_runtime/karts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var output := FileAccess.open(evidence + "/runtime_contract.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed": failures.is_empty(), "engine": Engine.get_version_info(),
		"assertion_count": assertion_count, "failures": failures,
		"scope": "Actual LumoRaceKart, garage and workshop, imported PackedScenes; no APK or physical-device FPS claim", "checks": results}, "  "))
	output.close()
	if failures.is_empty():
		print("[ProductionKart] PASS: imported variants, real mechanics, pause/reverse, LOD, tuning, garage/workshop and rival hooks (%d assertions)" % assertion_count)
	quit(0 if failures.is_empty() else 1)
