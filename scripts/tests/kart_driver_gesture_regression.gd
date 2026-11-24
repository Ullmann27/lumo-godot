extends SceneTree
## Exercise visible hand positions through the production adapter, including
## its intervening 60 Hz grip correction and the actual imported LODs.

const DRIVER = preload("res://scripts/games/kart_production_driver.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const SPECIES := ["rabbit", "frog", "lion", "owl", "squirrel", "turtle", "otter", "badger", "cat"]
var checks := 0
var failures: Array[String] = []


class DriverHost extends Node3D:

	var steering_wheel: Node3D
	var wheel_rest_grips: Array[Vector3] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)
		push_error("[DriverGesture] " + detail)


func _typed(node: Node, kind: String) -> Node:
	if node.is_class(kind):
		return node
	for child in node.get_children():
		var result := _typed(child, kind)
		if result != null:
			return result
	return null


func _host() -> DriverHost:
	var host := DriverHost.new()
	host.steering_wheel = Node3D.new()
	host.steering_wheel.position = Vector3(0, 1.035, -0.33)
	host.steering_wheel.rotation.x = -0.45
	host.add_child(host.steering_wheel)
	for side in [-1.0, 1.0]:
		host.wheel_rest_grips.append(
			host.steering_wheel.transform.affine_inverse() * Vector3(side * 0.16, 1.055, -0.34)
		)
	host.position = Vector3(8.0, 2.0, -3.0)
	host.rotation = Vector3(0.05, 0.6, -0.03)
	return host


func _hand(actor: Node3D, side: String) -> Vector3:
	var skeleton: Skeleton3D = actor.skeleton
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Hand." + side)).origin)


func _on_wheel(host: DriverHost, actor: Node3D, side: int) -> bool:
	return _hand(actor, "L" if side == 0 else "R").distance_to(
		host.steering_wheel.to_global(host.wheel_rest_grips[side])
	) < 0.001


func _check_actor(identity: String) -> void:
	var host := _host()
	var actor := DRIVER.new()
	host.add_child(actor)
	_check(actor.bind_visual(host, identity), identity + ": real production driver loads")
	root.add_child(host)
	if not actor.is_usable():
		host.free()
		return
	actor.apply_vehicle_sample(0.0, 0.0, false)
	for lod in [0, 2]:
		actor.set_visual_lod(lod)
		var reference := (load(ROSTER.racing_model_path(identity, lod)) as PackedScene).instantiate() as Node3D
		host.add_child(reference)
		reference.visible = false
		var skeleton := _typed(reference, "Skeleton3D") as Skeleton3D
		var animator := _typed(reference, "AnimationPlayer") as AnimationPlayer
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in ["greeting_wave", "point_portal", "celebrate"]:
			_check(actor.play_menu_behavior(clip), identity + ": accepts " + clip)
			for tick in range(25):
				actor.advance_tick(1.0 / 30.0)
			animator.play(clip, 0.0)
			animator.seek(actor.current_sample_time, true)
			skeleton.force_update_all_bone_transforms()
			var expected := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Hand.R")).origin)
			var label := "%s/%s/LOD%d" % [identity, clip, lod]
			_check(expected.distance_to(host.steering_wheel.to_global(host.wheel_rest_grips[1])) > 0.08,
				label + ": imported animation contains a visible hand gesture")
			_check(_hand(actor, "R").distance_to(expected) < 0.002,
				label + ": production adapter preserves the authored hand gesture")
			if clip != "celebrate":
				_check(_on_wheel(host, actor, 0), label + ": supporting hand keeps the wheel")
			else:
				var expected_left := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Hand.L")).origin)
				_check(_hand(actor, "L").distance_to(expected_left) < 0.002,
					label + ": stopped celebration preserves both raised hands")
			# This subframe takes the adapter's grip-only branch. It must not
			# snap the waving hand back between its 30 Hz animation samples.
			actor.advance_tick(1.0 / 120.0)
			# A preceding clip may leave part of an interval accumulated. Sample
			# the independent imported clip at the resulting time in either case.
			animator.seek(actor.current_sample_time, true)
			skeleton.force_update_all_bone_transforms()
			expected = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Hand.R")).origin)
			_check(_hand(actor, "R").distance_to(expected) < 0.002,
				label + ": subframe does not cancel the gesture")
			actor.apply_vehicle_sample(8.0, 0.0, false)
			actor.advance_tick(1.0 / 30.0)
			_check(_on_wheel(host, actor, 0) and _on_wheel(host, actor, 1),
				label + ": moving vehicle keeps both hands on the wheel")
			actor.apply_vehicle_sample(0.0, 0.0, false)
			actor.clear_menu_behavior()
			_check(_on_wheel(host, actor, 0) and _on_wheel(host, actor, 1),
				label + ": clearing the gesture restores both contacts")
		_check(actor.play_menu_behavior("agree_nod"), identity + ": selection nod starts")
		for tick in range(12):
			actor.advance_tick(1.0 / 30.0)
		_check(_on_wheel(host, actor, 0) and _on_wheel(host, actor, 1),
			identity + ": selection nod keeps both hands on the wheel")
		actor.clear_menu_behavior()
		reference.free()
	host.free()


func _run() -> void:
	for identity in SPECIES:
		_check_actor(identity)
	print("DRIVER_GESTURE_%s checks=%d failures=%d" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()
	])
	quit(0 if failures.is_empty() else 1)
