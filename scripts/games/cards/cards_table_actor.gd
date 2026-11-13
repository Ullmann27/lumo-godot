extends RefCounted
## Cards owns the original seated sample and upper-body reactions. The shared
## rig stays unchanged; a single manual AnimationPlayer avoids competing poses.
var actor: Node3D
var seat := Vector3.ZERO
var legs: Dictionary = {}
var pelvis := -1

func bind(value: Node3D, anchor: Vector3) -> bool:
	actor = value
	seat = anchor
	if not actor.is_usable():
		return false
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.play_behavior("kart_seated")
	actor.player.stop()
	actor.player.play("kart_seated", 0.0)
	actor.player.advance(0.0)
	actor.player.seek(0.3, true)
	actor.skeleton.force_update_all_bone_transforms()
	pelvis = actor.skeleton.find_bone("Pelvis")
	for side in ["L", "R"]:
		for part in ["Thigh.", "Shin.", "Foot.", "Toe.", "ToeTip."]:
			var index: int = actor.skeleton.find_bone(part + side)
			if index >= 0:
				legs[index] = actor.skeleton.get_bone_pose_rotation(index)
	actor.behavior_finished.connect(_finished)
	advance(0.0)
	return pelvis >= 0 and legs.size() == 10

func _finished(_behavior: String) -> void:
	if is_instance_valid(actor) and not actor.suspended:
		actor.play_behavior("kart_seated")

func advance(delta: float) -> void:
	if not is_instance_valid(actor) or pelvis < 0:
		return
	if not actor.suspended and not actor.reduced_motion:
		actor.player.advance(minf(delta, 0.1))
	for index in legs:
		actor.skeleton.set_bone_pose_rotation(index, legs[index])
	actor.skeleton.force_update_all_bone_transforms()
	var hips: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(pelvis).origin)
	actor.global_position += seat - hips
