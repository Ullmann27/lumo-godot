extends RefCounted
## Convert character-space pose offsets to the original rig's bone frames.
## The imported feet and pelvis have different rest axes from thighs/arms.
## Applying an unconverted local X rotation twists feet and tilts the pelvis.
## All bases are sampled once at bind time, not allocated in the animation loop.

const STUDIO = preload("res://assets/characters/lumo_animated/lumo_studio_clips.gd")

var skeleton: Skeleton3D
var rotations: Dictionary = {}
var positions: Dictionary = {}
var rotation_frames: Dictionary = {}
var parent_frames: Dictionary = {}


func bind(source: Skeleton3D, bone_indices: Dictionary) -> bool:
	if not is_instance_valid(source):
		return false
	source.force_update_all_bone_transforms()
	rotations.clear()
	positions.clear()
	rotation_frames.clear()
	parent_frames.clear()
	for bone in bone_indices:
		var index: int = int(bone_indices[bone])
		if index < 0 or index >= source.get_bone_count():
			return false
		rotations[bone] = source.get_bone_pose_rotation(index)
		positions[bone] = source.get_bone_pose_position(index)
		rotation_frames[bone] = source.get_bone_global_pose(index).basis.orthonormalized().get_rotation_quaternion()
		var parent: int = source.get_bone_parent(index)
		parent_frames[bone] = (
			source.get_bone_global_pose(parent).basis.orthonormalized().inverse()
			if parent >= 0 else Basis.IDENTITY
		)
	skeleton = source
	return true


func rotation_target(bone: String, body_delta: Quaternion) -> Quaternion:
	var frame: Quaternion = rotation_frames[bone]
	var neutral: Quaternion = rotations[bone]
	return (neutral * frame.inverse() * body_delta * frame).normalized()


func position_target(bone: String, body_offset: Vector3) -> Vector3:
	var parent_inverse: Basis = parent_frames[bone]
	var neutral: Vector3 = positions[bone]
	return neutral + parent_inverse * body_offset


func clip_rotation(clip: String, bone: String, phase: float) -> Quaternion:
	var track: Array = STUDIO.CLIPS[clip].rotations[bone]
	var sample: float = clampf(phase, 0.0, 1.0) * float(track.size() - 1)
	var first: int = mini(int(sample), track.size() - 2)
	var a: Quaternion = track[first]
	var b: Quaternion = track[first + 1]
	return a.slerp(b, sample - float(first))


func clip_pelvis(clip: String, phase: float) -> Vector3:
	var track: Array = STUDIO.CLIPS[clip].pelvis
	var sample: float = clampf(phase, 0.0, 1.0) * float(track.size() - 1)
	var first: int = mini(int(sample), track.size() - 2)
	var a: Vector3 = track[first]
	var b: Vector3 = track[first + 1]
	return a.lerp(b, sample - float(first))


func stride_metres(running: float = 0.0) -> float:
	# Asset trajectories use model metres. The owner may scale Lumo differently
	# in a learning world and Jump; phase must still follow travelled distance.
	return lerpf(float(STUDIO.STRIDE_METRES.walk), float(STUDIO.STRIDE_METRES.sprint), running) * absf(skeleton.global_basis.get_scale().y)
