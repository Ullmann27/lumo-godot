extends Node3D
## The authored rival animal rigs, driven only by the existing vehicle state.
## Each rig has the 21 body bones plus jaw, eye and lid bones for the face.
## This adapter never changes vehicle transforms, physics or race progress.

const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const AUTHORED_SEAT := Vector3(0.0, 0.69, 0.07)
const FIRST_KEY_SECONDS := 1.0 / 24.0
const VISUAL_TICK_SECONDS := 1.0 / 30.0
const MAX_VISUAL_STEP_SECONDS := 0.1
const CLIPS := [&"idle", &"kart_seated", &"kart_steer_left", &"kart_steer_right", &"kart_jump", &"celebrate"]
const MENU_CLIPS := [&"greeting_wave", &"agree_nod", &"point_portal", &"celebrate"]
const HIT_CLIP := &"kart_hit"
const FINISH_CLIP := &"kart_celebrate"
const BONES := [
	"Root", "Pelvis", "Spine", "Chest", "Neck", "Head", "Tail",
	"UpperArm.L", "Forearm.L", "Hand.L", "Thigh.L", "Shin.L", "Foot.L", "Ear.L",
	"UpperArm.R", "Forearm.R", "Hand.R", "Thigh.R", "Shin.R", "Foot.R", "Ear.R",
	"Jaw", "Eye.L", "Eye.R", "Lid.L", "Lid.R"
]
static var _scene_cache: Dictionary = {}

var kart: Node3D
var species := ""
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var model_load_kind := ""
var model_path := ""
var current_behavior: StringName = &""
var current_sample_time := 0.0
var visual_lod := -1
var graphics_profile := "high"
var steering := 0.0
var speed := 0.0
var airborne := false
var boosting := false
var drifting := false
var suspended := false
var reduced_motion := false
var victory := false
var elapsed := 0.0
var maximum_contact_error := 0.0
var _requested_lod := 0
var _tick := 0.0
var _jump_elapsed := 0.0
var _celebration_elapsed := 0.0
var _hit_elapsed := 0.0
var _hit_reaction := false
var _menu_behavior: StringName = &""
var _menu_elapsed := 0.0
var _arms: Array[PackedInt32Array] = []
var _ready_for_pose := false


func _init() -> void:
	# LumoRaceKart owns the visual clock, including its pause and far-detail path.
	set_process(false)


func _ready() -> void:
	_ready_for_pose = true
	if is_usable():
		_sample_pose()


func bind_visual(vehicle: Node3D, identity: String) -> bool:
	if is_usable():
		return kart == vehicle and species == identity
	if not is_instance_valid(vehicle):
		return false
	var anchors: Variant = vehicle.get("wheel_rest_grips")
	if not vehicle.get("steering_wheel") is Node3D or not anchors is Array or anchors.size() != 2:
		return false
	if not ROSTER.can_use_racing_model(identity):
		return false
	kart = vehicle
	species = identity
	name = "ProductionDriver_" + species
	transform = Transform3D.IDENTITY
	# The rival rigs were authored for the former seat at (0, 0.69, 0.07).
	# Follow the kart's actual DriverSeat marker so they sit in the cockpit.
	var production: Variant = vehicle.get("production_vehicle")
	if is_instance_valid(production):
		var seat: Node3D = production.asset_root.find_child("DriverSeat", true, false)
		if seat != null:
			position = _position_in(vehicle, seat) - AUTHORED_SEAT
	return _load_lod(_effective_lod())


func is_usable() -> bool:
	return is_instance_valid(visual) and is_instance_valid(skeleton) and is_instance_valid(player)


## Position of [param node] in the space of its [param ancestor], from local
## transforms only: the factory binds before the kart enters the scene tree.
static func _position_in(ancestor: Node3D, node: Node3D) -> Vector3:
	var chain := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			chain = (current as Node3D).transform * chain
		current = current.get_parent()
	return chain.origin


func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null


func _load_lod(level: int) -> bool:
	if visual_lod == level and is_usable():
		return true
	var path := ROSTER.racing_model_path(species, level)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return false
	var packed: PackedScene = _scene_cache.get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
		if packed == null:
			return false
		_scene_cache[path] = packed
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		return false
	var next_skeleton := _find_type(candidate, "Skeleton3D") as Skeleton3D
	var next_player := _find_type(candidate, "AnimationPlayer") as AnimationPlayer
	if not _valid_rig(next_skeleton, next_player):
		candidate.free()
		push_error("Unusable production driver: " + path)
		return false
	var retained_pose: Array[Transform3D] = []
	if is_usable() and _ready_for_pose:
		for bone in BONES:
			retained_pose.append(skeleton.get_bone_pose(skeleton.find_bone(bone)))
	# Validate before retiring the visible LOD. Each driver has one live skin.
	if is_instance_valid(visual):
		remove_child(visual)
		visual.free()
	visual = candidate
	skeleton = next_skeleton
	player = next_player
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.set_process(false)
	visual.transform = Transform3D.IDENTITY
	add_child(visual)
	model_load_kind = "imported_packed_scene"
	model_path = path
	visual_lod = level
	_arms.clear()
	for side in ["L", "R"]:
		_arms.append(PackedInt32Array([
			skeleton.find_bone("UpperArm." + side),
			skeleton.find_bone("Forearm." + side),
			skeleton.find_bone("Hand." + side)
		]))
	if _ready_for_pose:
		if retained_pose.is_empty():
			_sample_pose()
		else:
			player.play(current_behavior, 0.0)
			player.seek(current_sample_time, true)
			for index in range(BONES.size()):
				var bone := skeleton.find_bone(BONES[index])
				var pose := retained_pose[index]
				skeleton.set_bone_pose_position(bone, pose.origin)
				skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
				skeleton.set_bone_pose_scale(bone, pose.basis.get_scale())
			skeleton.force_update_all_bone_transforms()
	return true


func _valid_rig(candidate: Skeleton3D, animator: AnimationPlayer) -> bool:
	if candidate == null or animator == null or candidate.get_bone_count() != BONES.size():
		return false
	for bone in BONES:
		if candidate.find_bone(bone) < 0:
			return false
	for clip in CLIPS:
		if not animator.has_animation(clip):
			return false
		# All bones carry T/R/S, including the constant seated resets.
		# A default import that prunes them is unsuitable after idle/celebrate.
		if animator.get_animation(clip).get_track_count() != BONES.size() * 3:
			return false
	return true


func apply_vehicle_sample(
	velocity: float, steer: float, in_air: bool, hit: bool = false,
	boost: bool = false, drift: bool = false
) -> void:
	speed = absf(velocity) if is_finite(velocity) else 0.0
	steering = clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	if in_air and not airborne:
		_jump_elapsed = 0.0
	airborne = in_air
	boosting = boost
	drifting = drift
	if hit and not reduced_motion and _has_clip(HIT_CLIP):
		_hit_reaction = true
		_hit_elapsed = 0.0
		_menu_behavior = &""
		_menu_elapsed = 0.0
	# Boost and drift remain vehicle effects. A real impact now consumes the
	# authored kart_hit clip instead of silently dropping the event.


func set_suspended(value: bool) -> void:
	if suspended == value:
		return
	suspended = value
	_tick = 0.0


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	if value:
		victory = false
		_celebration_elapsed = 0.0
		_hit_reaction = false
		_hit_elapsed = 0.0
		_menu_behavior = &""
		_menu_elapsed = 0.0
	if _ready_for_pose and not suspended and is_usable():
		_sample_pose()


func celebrate_finished_race(_place: int = 1) -> void:
	if not is_usable() or victory or suspended or reduced_motion:
		return
	victory = true
	_celebration_elapsed = 0.0
	_hit_reaction = false
	_hit_elapsed = 0.0
	_menu_behavior = &""
	_menu_elapsed = 0.0
	if _ready_for_pose:
		_sample_pose()


func clear_celebration() -> void:
	victory = false
	_celebration_elapsed = 0.0
	if _ready_for_pose and not suspended and is_usable():
		_sample_pose()


func play_menu_behavior(behavior: String) -> bool:
	if not is_usable() or suspended or reduced_motion:
		return false
	var clip := StringName(behavior)
	if clip not in MENU_CLIPS or not _has_clip(clip):
		return false
	victory = false
	_celebration_elapsed = 0.0
	_hit_reaction = false
	_hit_elapsed = 0.0
	_menu_behavior = clip
	_menu_elapsed = 0.0
	if _ready_for_pose:
		_sample_pose()
	return true


func clear_menu_behavior() -> void:
	if _menu_behavior.is_empty():
		return
	_menu_behavior = &""
	_menu_elapsed = 0.0
	if _ready_for_pose and not suspended and is_usable():
		_sample_pose()


func set_visual_lod(level: int) -> void:
	_requested_lod = clampi(level, 0, 2)
	if not species.is_empty():
		_load_lod(_effective_lod())


func set_graphics_quality(profile: String) -> void:
	graphics_profile = profile if profile in ["low", "medium", "high"] else "high"
	if not species.is_empty():
		_load_lod(_effective_lod())


func _effective_lod() -> int:
	var minimum := 2 if graphics_profile == "low" else 1 if graphics_profile == "medium" else 0
	return maxi(_requested_lod, minimum)


func advance_tick(delta: float) -> void:
	if suspended or not _ready_for_pose or not is_usable() or not is_finite(delta) or delta < 0.0:
		return
	_tick += delta
	if _tick + 0.000000001 >= VISUAL_TICK_SECONDS:
		var intervals := floori((_tick + 0.000000001) / VISUAL_TICK_SECONDS)
		var consumed := float(intervals) * VISUAL_TICK_SECONDS
		_tick = maxf(0.0, _tick - consumed)
		var step := minf(consumed, MAX_VISUAL_STEP_SECONDS)
		if not reduced_motion:
			elapsed += step
			if airborne:
				_jump_elapsed += step
			if _hit_reaction:
				_hit_elapsed += step
				if _hit_elapsed >= _active_span(HIT_CLIP):
					_hit_reaction = false
					_hit_elapsed = 0.0
			if not _menu_behavior.is_empty():
				_menu_elapsed += step
				if _menu_elapsed >= _active_span(_menu_behavior):
					_menu_behavior = &""
					_menu_elapsed = 0.0
			if victory:
				_celebration_elapsed += step
				if _celebration_elapsed >= _active_span(_finish_clip()):
					victory = false
		_sample_pose()
	else:
		# A 60 Hz steering change still needs a 60 Hz grip correction.
		_follow_wheel()


func _has_clip(clip: StringName) -> bool:
	return is_instance_valid(player) and player.has_animation(clip)


func _finish_clip() -> StringName:
	return FINISH_CLIP if _has_clip(FINISH_CLIP) else &"celebrate"


func _active_span(clip: StringName) -> float:
	if not _has_clip(clip):
		return FIRST_KEY_SECONDS
	return maxf(FIRST_KEY_SECONDS, player.get_animation(clip).length - FIRST_KEY_SECONDS)


func _sample_pose() -> void:
	var clip: StringName = &"kart_seated"
	var sample_time := FIRST_KEY_SECONDS
	if not _menu_behavior.is_empty() and _has_clip(_menu_behavior) and not reduced_motion:
		clip = _menu_behavior
		sample_time += minf(_menu_elapsed, _active_span(clip))
	elif victory and not reduced_motion:
		clip = _finish_clip()
		sample_time += minf(_celebration_elapsed, _active_span(clip))
	elif _hit_reaction and _has_clip(HIT_CLIP) and not reduced_motion:
		clip = HIT_CLIP
		sample_time += minf(_hit_elapsed, _active_span(clip))
	elif airborne and not reduced_motion:
		clip = &"kart_jump"
		sample_time += minf(_jump_elapsed, _active_span(clip))
	elif absf(steering) > 0.005:
		clip = &"kart_steer_left" if steering > 0.0 else &"kart_steer_right"
		# Authored steering reaches full lock in the first quarter using sin.
		# Invert that curve, respecting the GLB's first key at 1/24 second.
		var phase := asin(absf(steering)) / (2.0 * PI)
		sample_time += phase * _active_span(clip)
	elif not reduced_motion:
		sample_time += fmod(elapsed, _active_span(clip))
	if player.current_animation != clip:
		player.play(clip, 0.0)
	player.seek(sample_time, true)
	skeleton.force_update_all_bone_transforms()
	current_behavior = clip
	current_sample_time = sample_time
	_follow_wheel()


func _follow_wheel() -> void:
	maximum_contact_error = 0.0
	if not is_instance_valid(kart) or not is_instance_valid(kart.get("steering_wheel")):
		return
	# A stopped kart may celebrate with both hands. During finish coasting
	# the left hand retains contact; every other driving pose uses both.
	if victory and speed <= 0.5:
		return
	_solve_arm(0)
	if not victory:
		_solve_arm(1)


func _set_global_rotation(index: int, rotation: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(index)
	var parent_rotation := Quaternion.IDENTITY
	if parent >= 0:
		parent_rotation = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, (parent_rotation.inverse() * rotation).normalized())
	skeleton.force_update_all_bone_transforms()


func _solve_arm(side: int) -> void:
	var wheel: Node3D = kart.get("steering_wheel")
	var grips: Array = kart.get("wheel_rest_grips")
	var target := skeleton.to_local(wheel.to_global(grips[side]))
	var chain := _arms[side]
	var upper := skeleton.get_bone_global_pose(chain[0])
	var forearm := skeleton.get_bone_global_pose(chain[1])
	var hand := skeleton.get_bone_global_pose(chain[2])
	var palm_rotation := hand.basis.get_rotation_quaternion()
	var first := forearm.origin - upper.origin
	var second := hand.origin - forearm.origin
	var toward := target - upper.origin
	var distance := toward.length()
	if distance < 0.00001 or first.length_squared() < 0.00000001 or second.length_squared() < 0.00000001:
		return
	var axis := toward / distance
	var length_a := first.length()
	var length_b := second.length()
	var reach := clampf(distance, absf(length_a - length_b) + 0.00001, length_a + length_b - 0.00001)
	var along := (length_a * length_a - length_b * length_b + reach * reach) / (2.0 * reach)
	var height := sqrt(maxf(0.0, length_a * length_a - along * along))
	var pole := first - axis * first.dot(axis)
	if pole.length_squared() < 0.00000001:
		pole = Vector3(-1.0 if side == 0 else 1.0, -0.5, 0.0)
		pole -= axis * pole.dot(axis)
	var elbow := upper.origin + axis * along + pole.normalized() * height
	var upper_delta := Quaternion(first.normalized(), (elbow - upper.origin).normalized())
	_set_global_rotation(chain[0], upper_delta * upper.basis.get_rotation_quaternion())
	forearm = skeleton.get_bone_global_pose(chain[1])
	hand = skeleton.get_bone_global_pose(chain[2])
	var forearm_delta := Quaternion(
		(hand.origin - forearm.origin).normalized(), (target - forearm.origin).normalized())
	_set_global_rotation(chain[1], forearm_delta * forearm.basis.get_rotation_quaternion())
	# Keep the authored palm orientation while correcting the arm chain.
	_set_global_rotation(chain[2], palm_rotation)
	var actual := skeleton.to_global(skeleton.get_bone_global_pose(chain[2]).origin)
	maximum_contact_error = maxf(maximum_contact_error, actual.distance_to(wheel.to_global(grips[side])))
