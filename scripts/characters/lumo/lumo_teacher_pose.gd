extends RefCounted
## Bounded additive attention after the original authored clip is sampled.
## No eye, lip or jaw animation is invented: the source has none of those rigs.
const MAX_YAW: float = 0.65
const MAX_PITCH: float = 0.32
var skeleton: Skeleton3D
var bones: Dictionary = {}
var target: Vector3 = Vector3.ZERO
var has_target: bool = false
var angles: Vector2 = Vector2.ZERO
var speaking: bool = false
var reaction: String = "idle"
var reaction_left: float = 0.0
var clock: float = 0.0


func bind(source: Skeleton3D) -> bool:
	if source == null:
		return false
	for bone in ["Head", "Neck", "SpineUpper", "TailBase", "Tail1", "Tail2", "Tail3"]:
		var index: int = source.find_bone(bone)
		if index < 0:
			return false
		bones[bone] = index
	skeleton = source
	return true


func set_target(world_position: Vector3) -> bool:
	if not world_position.is_finite():
		return false
	target = world_position
	has_target = true
	return true


func react(event: String) -> void:
	reaction = event
	reaction_left = 1.2 if event == "encourage" else 0.8


func advance(owner: Node3D, delta: float) -> void:
	if skeleton == null or not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 0.10)
	skeleton.force_update_all_bone_transforms()
	clock += delta
	reaction_left = maxf(0.0, reaction_left - delta)
	var desired := Vector2.ZERO
	if has_target:
		var origin: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(int(bones.Head)).origin)
		# Original Lumo faces +Z. Never twist his head towards a rear target.
		var direction: Vector3 = owner.global_basis.orthonormalized().inverse() * (target - origin)
		var horizontal: float = Vector2(direction.x, direction.z).length()
		if direction.z > 0.05 and horizontal > 0.05:
			desired = Vector2(clampf(atan2(direction.x, direction.z), -MAX_YAW, MAX_YAW), clampf(-atan2(direction.y, horizontal), -MAX_PITCH, MAX_PITCH))
	angles = angles.lerp(desired, 1.0 - exp(-7.0 * delta))
	var talk_nod: float = sin(clock * 3.4) * 0.018 if speaking else 0.0
	var encouragement: float = sin(reaction_left / 1.2 * PI) * 0.07 if reaction == "encourage" and reaction_left > 0.0 else 0.0
	_add_character_rotation(owner, "Neck", Quaternion(Vector3.UP, angles.x * 0.35) * Quaternion(Vector3.RIGHT, angles.y * 0.35 + talk_nod * 0.4))
	_add_character_rotation(owner, "Head", Quaternion(Vector3.UP, angles.x * 0.65) * Quaternion(Vector3.RIGHT, angles.y * 0.65 + talk_nod * 0.6) * Quaternion(Vector3.FORWARD, encouragement))
	var active: float = 1.0 if speaking or reaction_left > 0.0 else 0.3
	for index in range(4):
		var bone: String = ["TailBase", "Tail1", "Tail2", "Tail3"][index]
		_add_character_rotation(owner, bone, Quaternion(Vector3.UP, sin(clock * 2.0 - float(index) * 0.45) * 0.035 * active))
	skeleton.force_update_all_bone_transforms()


func _add_character_rotation(owner: Node3D, bone: String, rotation: Quaternion) -> void:
	var index: int = int(bones[bone])
	# Original bones have differing rest axes. Conjugate the body-space
	# rotation into this bone's current frame so "right/up" means the same
	# direction for the neck and head, including rotated teaching stages.
	var body_world: Quaternion = owner.global_basis.orthonormalized().get_rotation_quaternion()
	var bone_world: Quaternion = (skeleton.global_basis * skeleton.get_bone_global_pose(index).basis).orthonormalized().get_rotation_quaternion()
	var local_delta: Quaternion = bone_world.inverse() * body_world * rotation * body_world.inverse() * bone_world
	skeleton.set_bone_pose_rotation(index, (skeleton.get_bone_pose_rotation(index) * local_delta).normalized())
	skeleton.force_update_all_bone_transforms()
