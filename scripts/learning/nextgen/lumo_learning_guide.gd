extends "res://scripts/characters/lumo/lumo_rigged_actor.gd"
## Learning-only adapter. Keeps Kart/other original Lumo actors completely
## unchanged. This swaps the visual source for the verified original fox rig
## plus new Blender clips and mouth shapes. All host progression and answering
## remain in the existing Flutter task authority.
const NEXTGEN_MODEL := "res://assets/characters/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
const LEARNING_CLIPS := {
	"welcome": "learn_listen",
	"explain": "learn_explain",
	"encourage": "learn_encourage",
	"correct": "learn_nod",
	"celebrate": "learn_celebrate",
}
var learning_model_active := false
var _mouth_mesh: MeshInstance3D
var _viseme_indices: Array[int] = []
var _last_speaking := false


func _ready() -> void:
	# Prefer the new original 65-bone actor, without loading the old mesh
	# first. A stale .glb.import can point at a missing generated .scn in
	# CI fixtures; in that case the raw author-supplied GLB is a safe
	# source fallback. Release exports normally use the imported PackedScene.
	var next_visual: Node3D
	if ResourceLoader.exists(NEXTGEN_MODEL, "PackedScene"):
		var imported := ResourceLoader.load(NEXTGEN_MODEL, "PackedScene") as PackedScene
		if imported != null:
			next_visual = imported.instantiate() as Node3D
	if next_visual == null and FileAccess.file_exists(NEXTGEN_MODEL):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var err := document.append_from_file(NEXTGEN_MODEL, state)
		if err == OK:
			next_visual = document.generate_scene(state) as Node3D
	if next_visual == null:
		push_warning("[LumoNextGenLearning] GLB unavailable, falling back to installed original")
		super._ready()
		return
	var next_skeleton: Skeleton3D
	var next_player: AnimationPlayer
	var next_mouth: MeshInstance3D
	for child in next_visual.find_children("*", "Skeleton3D", true, false):
		if child is Skeleton3D and (child as Skeleton3D).get_bone_count() == 65:
			next_skeleton = child
			break
	for child in next_visual.find_children("*", "AnimationPlayer", true, false):
		if child is AnimationPlayer and (child as AnimationPlayer).has_animation("learn_listen"):
			next_player = child
			break
	for child in next_visual.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.name.begins_with("MouthVisemes"):
			next_mouth = child
			break
	var rig_valid := next_skeleton != null and next_player != null and next_mouth != null
	if rig_valid:
		for clip in CLIPS:
			if not next_player.has_animation(clip):
				push_warning("[LumoNextGenLearning] Missing original clip: " + clip)
				rig_valid = false
				break
	if rig_valid:
		for clip in LEARNING_CLIPS.values():
			if not next_player.has_animation(str(clip)):
				push_warning("[LumoNextGenLearning] Missing learning clip: " + str(clip))
				rig_valid = false
				break
	if rig_valid:
		for i in range(next_mouth.mesh.get_blend_shape_count()):
			if str(next_mouth.mesh.get_blend_shape_name(i)).begins_with("viseme_"):
				_viseme_indices.append(i)
		rig_valid = not _viseme_indices.is_empty()
	if not rig_valid:
		next_visual.free()
		_viseme_indices.clear()
		push_warning("[LumoNextGenLearning] Incompatible GLB, fallback to original")
		super._ready()
		return
	visual = next_visual
	add_child(visual)
	skeleton = next_skeleton
	player = next_player
	_mouth_mesh = next_mouth
	locomotion = WALK.new()
	facial_pose = FACIAL_POSE.new()
	if not facial_pose.bind(visual, skeleton):
		facial_pose = null
	for clip in ["idle", "kart_seated", "kart_steer_left", "kart_steer_right"]:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_finished)
	model_load_kind = "nextgen_learning_visual"
	learning_model_active = true
	mouth_supported = true
	phoneme_lipsync_supported = false
	play_behavior("idle")

func teacher_react(event: String) -> bool:
	var ok := super.teacher_react(event)
	if not ok or not learning_model_active or reduced_motion or suspended:
		return ok
	var clip := str(LEARNING_CLIPS.get(event, ""))
	if not clip.is_empty() and player != null and player.has_animation(clip):
		player.play(clip, 0.18)
	return ok


func set_teacher_speaking(value: bool) -> bool:
	var ok := super.set_teacher_speaking(value)
	if not learning_model_active:
		return ok
	var live := ok and value and not suspended and not reduced_motion
	if live != _last_speaking:
		_last_speaking = live
		if live:
			if player != null and player.has_animation("learn_explain"):
				player.play("learn_explain", 0.13)
		elif player != null and player.has_animation("learn_listen"):
			player.play("learn_listen", 0.15)
	return ok


func apply_speech_sample(media_seconds: float, envelope: float, speaking: bool) -> void:
	# The only source of mouth movement is the REAL player envelope from
	# getLearningSpeechStatus. This is NOT phoneme-accurate viseme sync.
	super.apply_speech_sample(media_seconds, envelope, speaking)
	if not learning_model_active or _mouth_mesh == null:
		return
	var amount := clampf(last_audio_envelope, 0.0, 1.0) if audio_active else 0.0
	for index in _viseme_indices:
		_mouth_mesh.set_blend_shape_value(index, amount if
			str(_mouth_mesh.mesh.get_blend_shape_name(index)) == "viseme_A" else 0.0)


func set_suspended(value: bool) -> void:
	super.set_suspended(value)
	if value:
		_last_speaking = false
		_clear_learning_mouth()


func set_reduced_motion(value: bool) -> void:
	super.set_reduced_motion(value)
	if value:
		_last_speaking = false
		_clear_learning_mouth()


func _clear_learning_mouth() -> void:
	if not is_instance_valid(_mouth_mesh):
		return
	for index in _viseme_indices:
		_mouth_mesh.set_blend_shape_value(index, 0.0)
