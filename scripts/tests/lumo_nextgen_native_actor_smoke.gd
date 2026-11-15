extends SceneTree
## Loads the same Blender actor as the real native learning route.
## Only actual rig, morph and audio-clock properties can satisfy this smoke.
const ACTOR = preload("res://scripts/characters/lumo/lumo_nextgen_learning_actor.gd")

func _initialize() -> void:
	call_deferred("_verify")


func _fail(message: String) -> void:
	push_error("[NextGenNativeActor] " + message)
	quit(1)


func _verify() -> void:
	var actor := ACTOR.new()
	get_root().add_child(actor)
	await process_frame
	if not actor.is_usable():
		_fail("Lumo Blender actor could not load its imported rig/animations")
		return
	if actor.skeleton.get_bone_count() != 65:
		_fail("Original 65-bone skeleton was not preserved")
		return
	if not actor.player.has_animation("learn_explain") or not actor.player.has_animation("learn_celebrate"):
		_fail("Authored Blender learning animation clips are not imported")
		return
	if not is_instance_valid(actor._nextgen_mouth):
		_fail("Blender speech morph mesh is missing")
		return
	if not actor._mouth_indices.has("viseme_A"):
		_fail("Viseme A morph was not imported")
		return
	if not actor.mouth_supported or actor.phoneme_lipsync_supported:
		_fail("Audio envelope/morph capability was not classified correctly")
		return
	if not actor.set_teaching_target(Vector3(1.0, 1.5, 2.2)):
		_fail("Real gaze target was not accepted by teaching rig")
		return
	if not actor.teacher_react("explain"):
		_fail("Authored explain gesture did not play")
		return
	actor.apply_speech_sample(0.18, 0.72, true)
	if not actor.audio_active or not is_equal_approx(actor.last_audio_position, 0.18):
		_fail("Live audio clock and speech state not accepted")
		return
	var shape_id := int(actor._mouth_indices["viseme_A"])
	var weight := actor._nextgen_mouth.get_blend_shape_value(shape_id)
	if weight <= 0.1:
		_fail("Actual audio envelope does not drive 3D mouth")
		return
	actor.apply_speech_sample(0.0, 0.0, false)
	if actor.audio_active or actor._nextgen_mouth.get_blend_shape_value(shape_id) > 0.0001:
		_fail("Mouth failed to reset on Stop")
		return
	actor.set_suspended(true)
	if actor.audio_active or actor._nextgen_mouth.get_blend_shape_value(shape_id) > 0.0001:
		_fail("Mouth still animated while app suspended")
		return
	print("[NextGenNativeActor] PASS: 65 bones, animations, target, real envelope morph, Stop and suspension")
	quit(0)
