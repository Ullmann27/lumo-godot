extends SceneTree
## Suspension look of the production karts: the sprung body (shells, coachwork, trim,
## body parts) pitches under braking/throttle, rolls outwards in corners and bounces on
## landing, while wheels, axles, steering wheel and driver contacts stay where they were.

const KART_STYLES := ["comet", "glider", "turbo", "koloss", "blitz"]
const DT := 1.0 / 60.0
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[BodyMotion] " + message)


func _drive(
	kart: LumoRaceKart,
	seconds: float,
	speed_from: float,
	speed_to: float,
	steer: float,
	brake: float
) -> void:
	var steps := int(round(seconds / DT))
	for step in range(steps):
		var speed := lerpf(speed_from, speed_to, float(step + 1) / float(steps))
		kart.set_motion(speed, steer, false, false)
		kart.set_braking(brake)
		kart._process(DT)


func _wheel_origins(kart: LumoRaceKart) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for pivot in kart.wheel_pivots:
		out.append(kart.global_transform.affine_inverse() * pivot.global_transform.origin)
	return out


func _contact(kart: LumoRaceKart) -> float:
	var worst := 0.0
	if is_instance_valid(kart.production_driver):
		var skeleton: Skeleton3D = kart.production_driver.skeleton
		for side in range(2):
			var hand := skeleton.to_global(
				(
					skeleton
					. get_bone_global_pose(skeleton.find_bone("Hand.L" if side == 0 else "Hand.R"))
					. origin
				)
			)
			worst = maxf(
				worst, hand.distance_to(kart.steering_wheel.to_global(kart.wheel_rest_grips[side]))
			)
	elif is_instance_valid(kart.lumo_animation):
		var skeleton: Skeleton3D = kart.lumo_animation.actor.skeleton
		for side in range(2):
			var hand := skeleton.to_global(
				(
					skeleton
					. get_bone_global_pose(skeleton.find_bone("Hand.L" if side == 0 else "Hand.R"))
					. origin
				)
			)
			worst = maxf(
				worst, hand.distance_to(kart.steering_wheel.to_global(kart.wheel_rest_grips[side]))
			)
	return worst


func _style(style: String, animal: String) -> void:
	var kart := LumoRaceKart.new()
	kart.configure(animal, Color("7760ef"), style)
	root.add_child(kart)
	kart.set_process(false)
	var production = kart.production_vehicle
	_check(is_instance_valid(production), "Production kart: " + style)
	if not is_instance_valid(production):
		kart.free()
		return
	var sprung: Node3D = production.sprung_node()
	_check(is_instance_valid(sprung), "Sprung body exists: " + style)
	if not is_instance_valid(sprung):
		kart.free()
		return
	for pivot in kart.wheel_pivots:
		_check(not sprung.is_ancestor_of(pivot), "Wheels stay unsprung: " + style)
	_check(
		not sprung.is_ancestor_of(kart.steering_wheel),
		"Steering wheel stays on the chassis: " + style
	)
	_check(
		sprung.is_ancestor_of(production.stock_close_mesh),
		"Body shell rides on the springs: " + style
	)
	if is_instance_valid(production.meshy_close_mesh):
		_check(
			sprung.is_ancestor_of(production.meshy_close_mesh),
			"Close-range shell rides on the springs: " + style
		)
	var wheels_rest := _wheel_origins(kart)
	var shell_rest: Transform3D = production.stock_close_mesh.global_transform
	_drive(kart, 2.0, 15.0, 15.0, 0.0, 0.0)
	var cruise: Vector3 = production.body_motion()
	_check(
		absf(cruise.x) < 0.004 and absf(cruise.y) < 0.004,
		"Steady cruise keeps the body level: %s %s" % [style, cruise]
	)
	_drive(kart, 0.35, 15.0, 6.0, 0.0, 1.0)
	var braking: Vector3 = production.body_motion()
	_check(braking.x < -0.012, "Braking dips the nose: %s pitch %.4f" % [style, braking.x])
	_drive(kart, 1.2, 6.0, 6.0, 0.0, 0.0)
	_drive(kart, 0.45, 6.0, 16.0, 0.0, 0.0)
	var throttle: Vector3 = production.body_motion()
	_check(throttle.x > 0.008, "Throttle squats the tail: %s pitch %.4f" % [style, throttle.x])
	_drive(kart, 1.0, 16.0, 16.0, 1.0, 0.0)
	var right: Vector3 = production.body_motion()
	_check(
		right.y > 0.012,
		"Right turn rolls the body outwards (left down): %s roll %.4f" % [style, right.y]
	)
	var shell_moved: float = (
		production.stock_close_mesh.global_transform.origin.distance_to(shell_rest.origin)
		+ (
			(
				production.stock_close_mesh.global_transform.basis.get_euler()
				- shell_rest.basis.get_euler()
			)
			. length()
		)
	)
	_check(shell_moved > 0.005, "Body visibly moves: %s %.4f" % [style, shell_moved])
	var wheels_now := _wheel_origins(kart)
	for index in range(wheels_now.size()):
		_check(
			wheels_now[index].distance_to(wheels_rest[index]) < 0.00001,
			"Wheel %d stays planted: %s" % [index, style]
		)
	var contact := _contact(kart)
	_check(
		contact < 0.006, "Hands keep the wheel while the body rolls: %s %.4f m" % [style, contact]
	)
	_drive(kart, 1.0, 16.0, 16.0, -1.0, 0.0)
	var left: Vector3 = production.body_motion()
	_check(left.y < -0.012, "Left turn rolls the other way: %s roll %.4f" % [style, left.y])
	kart.set_driver_runtime_state(true, false, false)
	_drive(kart, 0.6, 16.0, 16.0, 0.0, 0.0)
	var flying: Vector3 = production.body_motion()
	_check(flying.z > 0.008, "Airborne body extends: %s heave %.4f" % [style, flying.z])
	kart.set_driver_runtime_state(false, false, false)
	var lowest := 1.0
	for step in range(20):
		_drive(kart, DT, 16.0, 16.0, 0.0, 0.0)
		lowest = minf(lowest, production.body_motion().z)
	_check(lowest < -0.004, "Landing compresses the springs: %s heave %.4f" % [style, lowest])
	kart.set_driver_runtime_state(false, false, true)
	var paused: Vector3 = production.body_motion()
	_drive(kart, 0.5, 16.0, 0.0, 1.0, 1.0)
	_check(production.body_motion().is_equal_approx(paused), "Pause freezes the body: " + style)
	kart.set_driver_runtime_state(false, false, false)
	kart.reduced_motion = true
	_drive(kart, 0.5, 16.0, 0.0, 1.0, 1.0)
	_check(production.body_motion().length() < 0.000001, "Calm mode keeps the body still: " + style)
	report[style + "_" + animal] = {
		"braking_pitch": braking.x,
		"throttle_pitch": throttle.x,
		"right_roll": right.y,
		"left_roll": left.y,
		"air_heave": flying.z,
		"landing_heave": lowest,
		"hand_contact_m": contact
	}
	kart.free()


func _run() -> void:
	for style in KART_STYLES:
		_style(style, "otter")
		await process_frame
	_style("comet", "fox")
	await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file != null:
			file.store_string(
				JSON.stringify(
					{
						"passed": failures.is_empty(),
						"checks": checks,
						"errors": failures,
						"karts": report
					},
					"  "
				)
			)
			file.close()
	print(
		"[BodyMotion] checks=", checks, " failures=", failures.size(), " ", JSON.stringify(report)
	)
	quit(0 if failures.is_empty() else 1)
