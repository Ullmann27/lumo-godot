extends SceneTree
## Native source test of the actual production learning adapter, not Android.
const GUIDE := preload("res://scripts/learning/nextgen/lumo_learning_guide.gd")


func _initialize() -> void:
	call_deferred("_verify")


func _check(ok: bool, name: String) -> bool:
	if ok:
		return true
	push_error("[LumoLearningGuide] FAIL " + name)
	quit(1)
	return false


func _verify() -> void:
	var guide := GUIDE.new()
	guide.name = "ProductionLearningLumo"
	root.add_child(guide)
	for i in range(8):
		await process_frame
	if not _check(guide.is_usable(), "original active rig imports"):
		return
	if not _check(guide.learning_model_active, "new Blender model active without fallback"):
		return
	if not _check(guide.skeleton.get_bone_count() == 65, "original 65 bone skeleton retained"):
		return
	if not _check(guide.player.has_animation("learn_explain") and
			guide.player.has_animation("learn_point"), "authored learning clips loaded"):
		return
	if not _check(guide._mouth_mesh != null and not guide._viseme_indices.is_empty(),
			"mouth blendshapes imported"):
		return
	guide.set_teaching_target(Vector3(0.0, 1.25, -0.25))
	if not _check(guide.teacher_react("explain"), "pointing/explaining state"):
		return
	guide.apply_speech_sample(0.18, 0.65, true)
	if not _check(guide.audio_active and guide.last_audio_envelope > 0.0,
			"measured audible playback can drive mouth"):
		return
	guide.apply_speech_sample(0.0, 0.0, false)
	if not _check(not guide.audio_active and guide.last_audio_envelope == 0.0,
			"aborting speech clears amplitude"):
		return
	for i in guide._viseme_indices:
		if not _check(is_zero_approx(guide._mouth_mesh.get_blend_shape_value(i)),
				"no jaw remains moving after stop"):
			return
	guide.set_suspended(true)
	if not _check(guide.suspended and not guide.audio_active,
			"lifecycle interrupts mouth and animation"):
		return
	guide.set_suspended(false)
	guide.set_reduced_motion(true)
	if not _check(not guide.audio_active, "calm mode keeps mouth idle"):
		return
	print("[LumoLearningGuide] PASS: actual learning-world actor loads 65-bone Blender model, learning clips, owned envelope mouth, interrupt and calm mode")
	quit(0)
