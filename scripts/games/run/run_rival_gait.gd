extends RefCounted
## Fips' own movements for Lumo Lauf, keyed on the 26 bones of his rig.
##
## The squirrel model of the roster brings a standing "idle" and clips for
## sitting in a kart; a runner needs more. This builds three skeletal clips from
## his own standing pose (the first frame of "idle"):
##   rival_run    a sprint cycle: thighs swing 42° each way, knees fold up to
##                85° in the swing, arms counter-swing with bent elbows, the
##                spine leans into the run, hips and chest twist against each
##                other, the pelvis bobs twice per cycle, tail and ears follow
##   rival_leap   the tucked pose of a hop (knees up, arms forward)
##   rival_cheer  both arms up, a little bounce (he arrived first)
## Every bone turns about an axis given in the world (across the body for
## swinging, up for twisting) and converted into that bone's own frame, so the
## clips fit the rig whatever its bone roll is.

const RUN: String = "rival_run"
const LEAP: String = "rival_leap"
const CHEER: String = "rival_cheer"
const LIBRARY: String = "rival"
const RUN_SECONDS: float = 0.5
const KEYS: int = 16
const BONES: Array[String] = [
	"Pelvis",
	"Spine",
	"Chest",
	"Neck",
	"Head",
	"Tail",
	"Ear.L",
	"Ear.R",
	"Thigh.L",
	"Shin.L",
	"Foot.L",
	"Thigh.R",
	"Shin.R",
	"Foot.R",
	"UpperArm.L",
	"Forearm.L",
	"UpperArm.R",
	"Forearm.R",
]

var _skeleton: Skeleton3D
var _base_rot: Dictionary = {}
var _base_pos: Dictionary = {}
var _frames: Dictionary = {}
var _paths: Dictionary = {}


## Adds the clips to `player` (library "rival"). False when the rig is not the
## expected one (then the view keeps the plain idle).
func build(player: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	_skeleton = skeleton
	if not player.has_animation("idle"):
		return false
	for bone in ["Pelvis", "Spine", "Chest", "Neck", "Head", "Tail", "Ear.L", "Ear.R"]:
		if skeleton.find_bone(bone) < 0:
			return false
	for side in ["L", "R"]:
		for part in ["Thigh.", "Shin.", "Foot.", "UpperArm.", "Forearm."]:
			if skeleton.find_bone(part + side) < 0:
				return false
	player.play("idle")
	player.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	var root: Node = player.get_node(player.root_node)
	var to_skeleton: String = str(root.get_path_to(skeleton))
	for bone in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(bone)
		_base_rot[bone_name] = skeleton.get_bone_pose_rotation(bone)
		_base_pos[bone_name] = skeleton.get_bone_pose_position(bone)
		_frames[bone_name] = skeleton.get_bone_global_pose(bone).basis.orthonormalized()
		_paths[bone_name] = NodePath(to_skeleton + ":" + bone_name)
	var library := AnimationLibrary.new()
	library.add_animation(RUN, _run_clip())
	library.add_animation(LEAP, _leap_clip())
	library.add_animation(CHEER, _cheer_clip())
	if player.has_animation_library(LIBRARY):
		player.remove_animation_library(LIBRARY)
	player.add_animation_library(LIBRARY, library)
	player.play("idle")
	return true


static func clip(name: String) -> String:
	return LIBRARY + "/" + name


## Rotation of a bone in its parent's frame: its standing pose turned by
## `swing` (radians, about the world axis across the body: positive brings a
## hanging limb forward) and `twist` (about the world up axis).
func _turned(bone: String, swing: float, twist: float = 0.0, roll: float = 0.0) -> Quaternion:
	var frame: Basis = _frames[bone]
	var across: Vector3 = (frame.inverse() * Vector3.RIGHT).normalized()
	var up: Vector3 = (frame.inverse() * Vector3.UP).normalized()
	var ahead: Vector3 = (frame.inverse() * Vector3.FORWARD).normalized()
	var turn := Quaternion(across, swing) * Quaternion(up, twist) * Quaternion(ahead, roll)
	return (_base_rot[bone] as Quaternion) * turn


func _track(animation: Animation, bone: String) -> int:
	var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, _paths[bone])
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track


func _position_track(animation: Animation, bone: String) -> int:
	var track: int = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track, _paths[bone])
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track


## One key per bone at time `at` from a dictionary bone -> [swing, twist, roll].
func _key(
	animation: Animation, tracks: Dictionary, at: float, pose: Dictionary, lift: float
) -> void:
	for bone in pose:
		var angles: Array = pose[bone]
		var rot: Quaternion = _turned(
			bone,
			float(angles[0]),
			float(angles[1]) if angles.size() > 1 else 0.0,
			float(angles[2]) if angles.size() > 2 else 0.0
		)
		animation.rotation_track_insert_key(tracks[bone], at, rot)
	animation.position_track_insert_key(
		tracks["@pelvis"], at, (_base_pos["Pelvis"] as Vector3) + Vector3(0.0, lift, 0.0)
	)


func _tracks(animation: Animation, bones: Array) -> Dictionary:
	var tracks: Dictionary = {}
	for bone in bones:
		tracks[bone] = _track(animation, bone)
	tracks["@pelvis"] = _position_track(animation, "Pelvis")
	return tracks


func _run_pose(phase: float) -> Dictionary:
	var pose: Dictionary = {}
	for side in ["L", "R"]:
		var t: float = phase * TAU + (0.0 if side == "L" else PI)
		# The knee folds most while the leg swings forward (cos > 0).
		var fold: float = pow(clampf(0.5 + 0.5 * cos(t + 0.35), 0.0, 1.0), 1.4)
		pose["Thigh." + side] = [deg_to_rad(42.0) * sin(t)]
		pose["Shin." + side] = [-deg_to_rad(10.0 + 75.0 * fold)]
		pose["Foot." + side] = [deg_to_rad(18.0) * sin(t - 0.9)]
		# The arm swings against the leg of its own side, elbow bent.
		pose["UpperArm." + side] = [
			-deg_to_rad(38.0) * sin(t), 0.0, deg_to_rad(8.0) * (1.0 if side == "L" else -1.0)
		]
		pose["Forearm." + side] = [deg_to_rad(62.0 + 12.0 * sin(t))]
	var u: float = phase * TAU
	pose["Pelvis"] = [deg_to_rad(4.0), deg_to_rad(7.0) * sin(u)]
	pose["Spine"] = [-deg_to_rad(9.0 + 2.5 * cos(2.0 * u))]
	pose["Chest"] = [-deg_to_rad(5.0), -deg_to_rad(11.0) * sin(u)]
	pose["Neck"] = [deg_to_rad(7.0)]
	pose["Head"] = [deg_to_rad(6.0 + 2.5 * cos(2.0 * u))]
	pose["Tail"] = [deg_to_rad(14.0) * sin(2.0 * u - 0.6), deg_to_rad(10.0) * sin(u)]
	pose["Ear.L"] = [-deg_to_rad(10.0) * (0.5 + 0.5 * sin(2.0 * u + 0.8))]
	pose["Ear.R"] = [-deg_to_rad(10.0) * (0.5 + 0.5 * sin(2.0 * u + 1.1))]
	return pose


func _run_clip() -> Animation:
	var animation := Animation.new()
	animation.length = RUN_SECONDS
	animation.loop_mode = Animation.LOOP_LINEAR
	var tracks: Dictionary = _tracks(animation, BONES)
	for index in range(KEYS + 1):
		var phase: float = float(index) / float(KEYS)
		# Highest in the middle of each flight phase, lowest at each foot strike.
		var lift: float = -0.025 + 0.05 * absf(sin(phase * TAU))
		_key(animation, tracks, phase * RUN_SECONDS, _run_pose(fposmod(phase, 1.0)), lift)
	return animation


func _leap_pose() -> Dictionary:
	return {
		"Pelvis": [deg_to_rad(6.0)],
		"Spine": [-deg_to_rad(14.0)],
		"Chest": [-deg_to_rad(6.0)],
		"Neck": [deg_to_rad(10.0)],
		"Head": [deg_to_rad(8.0)],
		"Tail": [deg_to_rad(24.0)],
		"Ear.L": [-deg_to_rad(16.0)],
		"Ear.R": [-deg_to_rad(16.0)],
		"Thigh.L": [deg_to_rad(62.0)],
		"Shin.L": [-deg_to_rad(95.0)],
		"Foot.L": [deg_to_rad(20.0)],
		"Thigh.R": [deg_to_rad(30.0)],
		"Shin.R": [-deg_to_rad(70.0)],
		"Foot.R": [deg_to_rad(10.0)],
		"UpperArm.L": [deg_to_rad(65.0), 0.0, deg_to_rad(18.0)],
		"Forearm.L": [deg_to_rad(35.0)],
		"UpperArm.R": [deg_to_rad(65.0), 0.0, -deg_to_rad(18.0)],
		"Forearm.R": [deg_to_rad(35.0)],
	}


func _leap_clip() -> Animation:
	var animation := Animation.new()
	animation.length = 0.3
	animation.loop_mode = Animation.LOOP_LINEAR
	var tracks: Dictionary = _tracks(animation, BONES)
	_key(animation, tracks, 0.0, _leap_pose(), 0.03)
	_key(animation, tracks, 0.3, _leap_pose(), 0.03)
	return animation


func _cheer_clip() -> Animation:
	var animation := Animation.new()
	animation.length = 0.8
	animation.loop_mode = Animation.LOOP_LINEAR
	var tracks: Dictionary = _tracks(animation, BONES)
	for index in range(9):
		var u: float = float(index) / 8.0
		var hop: float = absf(sin(u * TAU))
		var wave: float = sin(u * TAU * 2.0)
		var pose: Dictionary = {
			"Pelvis": [0.0],
			"Spine": [deg_to_rad(4.0)],
			"Chest": [deg_to_rad(3.0)],
			"Neck": [-deg_to_rad(4.0)],
			"Head": [-deg_to_rad(6.0), deg_to_rad(8.0) * wave],
			"Tail": [deg_to_rad(20.0) * wave],
			"Ear.L": [deg_to_rad(6.0) * wave],
			"Ear.R": [-deg_to_rad(6.0) * wave],
			"Thigh.L": [deg_to_rad(28.0) * hop],
			"Shin.L": [-deg_to_rad(45.0) * hop],
			"Foot.L": [0.0],
			"Thigh.R": [deg_to_rad(28.0) * hop],
			"Shin.R": [-deg_to_rad(45.0) * hop],
			"Foot.R": [0.0],
			"UpperArm.L": [deg_to_rad(150.0), 0.0, deg_to_rad(18.0 + 10.0 * wave)],
			"Forearm.L": [deg_to_rad(20.0)],
			"UpperArm.R": [deg_to_rad(150.0), 0.0, -deg_to_rad(18.0 + 10.0 * wave)],
			"Forearm.R": [deg_to_rad(20.0)],
		}
		_key(animation, tracks, u * 0.8, pose, 0.16 * hop)
	return animation
