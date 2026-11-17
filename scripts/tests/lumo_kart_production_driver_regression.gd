extends SceneTree
## Exercise the shipped PackedScene import and the same rival adapter as the kart.
## The host supplies only the existing wheel contract, not a replacement race.

const DRIVER = preload("res://scripts/games/kart_production_driver.gd")
const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const SPECIES := ["lion", "owl", "rabbit", "squirrel", "turtle"]
const CLIPS := ["idle", "kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump", "celebrate"]
var checks := 0
var failures: Array[String] = []
var imported: Array[Dictionary] = []
var worst_contact := 0.0

class DriverHost extends Node3D:
	var steering_wheel: Node3D
	var wheel_rest_grips: Array[Vector3] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[ProductionDriver] " + message)


func _typed(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _typed(child, type_name)
		if found != null:
			return found
	return null


func _imported_scene(identity: String, level: int) -> void:
	var path := ROSTER.racing_model_path(identity, level)
	var packed := load(path) as PackedScene
	_check(packed != null, "Normal resource import yields PackedScene: " + path)
	if packed == null:
		return
	var visual := packed.instantiate() as Node3D
	root.add_child(visual)
	var skeleton := _typed(visual, "Skeleton3D") as Skeleton3D
	var animator := _typed(visual, "AnimationPlayer") as AnimationPlayer
	_check(skeleton != null and animator != null, "Imported skin and AnimationPlayer: " + path)
	if skeleton == null or animator == null:
		visual.free()
		return
	_check(skeleton.get_bone_count() == 21, "Authored 21-bone rival rig: " + path)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var tracks: Dictionary = {}
	for clip in CLIPS:
		_check(animator.has_animation(clip), "Imported clip " + identity + "/" + clip)
		if animator.has_animation(clip):
			tracks[clip] = animator.get_animation(clip).get_track_count()
			_check(tracks[clip] == 63, "All constant T/R/S reset tracks remain: " + path + "/" + clip)
	for clip in ["idle", "kart_seated", "celebrate", "kart_seated", "kart_steer_left", "idle", "kart_jump", "kart_steer_right", "kart_seated"]:
		animator.play(clip, 0.0)
		animator.seek(0.7, true)
		skeleton.force_update_all_bone_transforms()
		if clip == "kart_seated":
			for side in ["L", "R"]:
				var sign_value := -1.0 if side == "L" else 1.0
				var hand := skeleton.get_bone_global_pose(skeleton.find_bone("Hand." + side)).origin
				var foot := skeleton.get_bone_global_pose(skeleton.find_bone("Foot." + side)).origin
				_check(hand.distance_to(Vector3(sign_value * 0.16, 1.055, -0.34)) < 0.002,
					"Clip changes restore the seated hand: " + path + "/" + side)
				_check(foot.distance_to(Vector3(sign_value * 0.18, 0.80, -0.24)) < 0.001,
					"Clip changes restore the seated foot: " + path + "/" + side)
	var settings := ConfigFile.new()
	_check(settings.load(path + ".import") == OK, "Per-asset import settings exist: " + path)
	_check(settings.get_value("params", "animation/remove_immutable_tracks", true) == false,
		"Export-safe immutable tracks retained: " + path)
	imported.append({"path": path, "source_sha256": FileAccess.get_sha256(path),
		"import_sha256": FileAccess.get_sha256(path + ".import"), "tracks": tracks,
		"load_kind": "ResourceLoader PackedScene.instantiate"})
	visual.free()


func _host() -> DriverHost:
	var host := DriverHost.new()
	host.steering_wheel = Node3D.new()
	host.steering_wheel.position = Vector3(0, 1.035, -0.33)
	host.steering_wheel.rotation.x = -0.45
	host.add_child(host.steering_wheel)
	for side in [-1.0, 1.0]:
		host.wheel_rest_grips.append(host.steering_wheel.transform.affine_inverse() * Vector3(side * 0.16, 1.055, -0.34))
	# Contacts must remain correct after the existing vehicle world transform.
	host.position = Vector3(12.0, 3.0, -7.0)
	host.rotation = Vector3(0.12, 0.51, -0.06)
	return host


func _sample(host: DriverHost, adapter: Node3D, steer: float, in_air: bool, delta: float = 1.0 / 60.0, velocity: float = 18.0) -> void:
	host.steering_wheel.rotation.z = -steer * 0.4
	adapter.apply_vehicle_sample(velocity, steer, in_air, false, false, false)
	adapter.advance_tick(delta)


func _contacts(host: DriverHost, adapter: Node3D, both_hands: bool = true) -> void:
	var skeleton: Skeleton3D = adapter.skeleton
	for side in range(2):
		var suffix := ".L" if side == 0 else ".R"
		if both_hands or side == 0:
			var hand := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Hand" + suffix)).origin)
			var error := hand.distance_to(host.steering_wheel.to_global(host.wheel_rest_grips[side]))
			worst_contact = maxf(worst_contact, error)
			_check(error < 0.001, "Actual moving grip error below 1 mm: %s/%s/%s %.6f" % [adapter.species, adapter.current_behavior, suffix, error])
		var foot := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Foot" + suffix)).origin)
		var expected := host.to_global(Vector3(-0.18 if side == 0 else 0.18, 0.80, -0.24))
		_check(foot.distance_to(expected) < 0.001, "Authored seated foot stays on its pedal: " + suffix)


func _pose(adapter: Node3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for name_value in DRIVER.BONES:
		result.append(adapter.skeleton.get_bone_pose(adapter.skeleton.find_bone(name_value)))
	return result


func _same_pose(adapter: Node3D, expected: Array[Transform3D], label: String) -> void:
	var actual := _pose(adapter)
	for index in range(actual.size()):
		_check(actual[index].is_equal_approx(expected[index]), label + "/" + str(DRIVER.BONES[index]))


func _adapter(identity: String) -> void:
	var host := _host()
	var adapter := DRIVER.new()
	host.add_child(adapter)
	_check(adapter.bind_visual(host, identity), "Factory binds before SceneTree insertion: " + identity)
	root.add_child(host)
	_check(adapter.is_usable() and adapter.model_load_kind == "imported_packed_scene", "Runtime uses imported rig: " + identity)
	_check(not adapter.is_processing(), "Vehicle owns the only animation clock.")
	if not adapter.is_usable():
		host.free()
		return
	_contacts(host, adapter)
	for steer in [-1.0, -0.87, -0.3, -0.01, 0.0, 0.01, 0.3, 0.87, 1.0]:
		for step in range(5):
			_sample(host, adapter, steer, false, 1.0 / 120.0)
			_contacts(host, adapter)
		var expected: StringName = &"kart_seated" if steer == 0.0 else &"kart_steer_left" if steer > 0.0 else &"kart_steer_right"
		_check(adapter.current_behavior == expected, "Actual steering selects authored clip: " + identity)
	for index in range(90):
		_sample(host, adapter, sin(float(index) * 0.11), true)
		_contacts(host, adapter)
	_check(adapter.current_behavior == &"kart_jump", "Real airborne state uses jump clip.")
	_sample(host, adapter, 0.0, false, 1.0 / 30.0)
	_check(adapter.current_behavior == &"kart_seated", "Real landing restores seated clip.")
	_contacts(host, adapter)
	adapter.apply_vehicle_sample(18.0, 0.0, false, true, true, true)
	adapter.advance_tick(1.0 / 30.0)
	_check(adapter.current_behavior == &"kart_seated", "Hit/boost/drift cannot invent a physical jump.")
	adapter.set_suspended(true)
	var before := _pose(adapter)
	var elapsed_before: float = adapter.elapsed
	for index in range(10):
		adapter.advance_tick(0.1)
	_same_pose(adapter, before, "Pause freezes all 21 bones")
	_check(adapter.elapsed == elapsed_before, "Pause freezes the animation clock.")
	for level in [2, 1, 0]:
		adapter.set_visual_lod(level)
		_check(adapter.visual_lod == level, "LOD switch uses requested authored mesh.")
		_same_pose(adapter, before, "LOD preserves the entire current pose")
		_check(adapter.find_children("*", "Skeleton3D", true, false).size() == 1, "One live skin after LOD switch.")
	adapter.set_suspended(false)
	adapter.set_reduced_motion(true)
	_sample(host, adapter, 0.0, true, 1.0 / 30.0)
	before = _pose(adapter)
	for index in range(20):
		_sample(host, adapter, 0.0, true, 0.1)
	_same_pose(adapter, before, "Reduced motion keeps a stable seated pose")
	_check(adapter.current_behavior == &"kart_seated", "Reduced motion suppresses optional jump body motion.")
	adapter.celebrate_finished_race(1)
	_check(not adapter.victory, "Reduced motion suppresses the optional celebration.")
	adapter.set_reduced_motion(false)
	_sample(host, adapter, 0.0, false, 1.0 / 30.0, 0.0)
	adapter.celebrate_finished_race(1)
	for index in range(45):
		adapter.advance_tick(1.0 / 30.0)
	_check(adapter.current_behavior == &"celebrate" and adapter.victory, "Finish event plays authored celebration.")
	var hand_height: float = adapter.skeleton.get_bone_global_pose(adapter.skeleton.find_bone("Hand.R")).origin.y
	_check(hand_height > 1.4, "Stopped finish celebration actually raises a hand.")
	for index in range(50):
		adapter.advance_tick(1.0 / 30.0)
	_check(not adapter.victory and adapter.current_behavior == &"kart_seated", "Celebration ends once and restores sitting.")
	_contacts(host, adapter)
	_sample(host, adapter, -0.7, false, 1.0 / 30.0, 8.0)
	adapter.celebrate_finished_race(4)
	for index in range(45):
		adapter.advance_tick(1.0 / 30.0)
	_contacts(host, adapter, false)
	adapter.clear_celebration()
	_contacts(host, adapter)
	adapter.set_graphics_quality("low")
	_check(adapter.visual_lod == 2, "Low profile selects authored mobile LOD2.")
	adapter.set_graphics_quality("medium")
	_check(adapter.visual_lod == 1, "Medium profile selects authored LOD1.")
	adapter.set_graphics_quality("high")
	_check(adapter.visual_lod == 0, "High profile restores authored LOD0.")
	before = _pose(adapter)
	adapter.advance_tick(NAN)
	adapter.advance_tick(-1.0)
	_same_pose(adapter, before, "Invalid visual delta cannot corrupt pose")
	_check(host.position == Vector3(12.0, 3.0, -7.0), "Driver cannot move the vehicle.")
	host.free()


func _run() -> void:
	_check(ROSTER.ready_for_race(), "Five production identities have all imported LODs.")
	for identity in SPECIES:
		for level in range(3):
			_imported_scene(identity, level)
		_adapter(identity)
		await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"passed": failures.is_empty(), "godot": Engine.get_version_info().string,
				"checks": checks, "maximum_hand_error_m": worst_contact, "imported_scenes": imported,
				"errors": failures, "physical_android": false,
				"method": "Regular Godot editor imports loaded as PackedScenes; full clip transitions, driven steering/flight/finish, manual clock, pause, reduced motion and LOD pose retention"}, "  "))
			file.close()
		else:
			_check(false, "Cannot write runtime integration report.")
	print("[ProductionDriver] checks=", checks, " failures=", failures.size(), " imported=", imported.size(), " maximum_hand_error_m=", worst_contact)
	quit(0 if failures.is_empty() else 1)
