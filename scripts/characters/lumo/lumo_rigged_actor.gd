extends Node3D
## Isolated phase-one character adapter. No race physics, audio engine or rewards.
## Uses the existing companion behavior names rather than a second event bus.
signal behavior_started(behavior: String)
signal behavior_finished(behavior: String)
const MODEL := "res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb"
static var _cached_model: PackedScene
const CLIPS: Array[String] = [
	"idle", "greeting_wave", "celebrate", "point_portal", "agree_nod",
	"kart_seated", "kart_steer_left", "kart_steer_right", "kart_jump",
]
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var current_behavior := "idle"
var reduced_motion := false
var suspended := false
var mouth_supported := false
var last_audio_position := 0.0
var last_audio_envelope := 0.0
var audio_active := false


func _ready() -> void:
	if _cached_model == null:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(MODEL, state) == OK)
		var source := document.generate_scene(state)
		assert(source != null)
		_cached_model = PackedScene.new()
		assert(_cached_model.pack(source) == OK)
		source.free()
	visual = _cached_model.instantiate() as Node3D
	assert(visual != null)
	add_child(visual)
	skeleton = visual.find_child("*", true, false) as Skeleton3D
	for node in visual.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		player = node
	assert(skeleton != null and player != null)
	assert(skeleton.get_bone_count() == 65)
	for clip in CLIPS:
		assert(player.has_animation(clip), "Missing exported clip: " + clip)
	for clip in ["idle", "kart_seated", "kart_steer_left", "kart_steer_right"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_finished)
	play_behavior("idle")


func play_behavior(behavior: String) -> bool:
	if not CLIPS.has(behavior) or suspended or player == null:
		return false
	current_behavior = behavior
	player.play(behavior, 0.12)
	player.advance(0.0)
	if reduced_motion:
		player.seek(0.0 if behavior == "idle" else player.get_animation(behavior).length * 0.5, true)
		player.pause()
	behavior_started.emit(behavior)
	return true


func _finished(behavior: StringName) -> void:
	behavior_finished.emit(str(behavior))
	if not suspended and str(behavior) == current_behavior:
		play_behavior("idle")


func set_suspended(value: bool) -> void:
	suspended = value
	if player == null:
		return
	if value:
		player.pause()
	else:
		player.play()
		if reduced_motion:
			player.pause()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if not suspended:
		play_behavior(current_behavior)


func apply_speech_sample(media_seconds: float, envelope: float, speaking: bool) -> void:
	# Transport-neutral synchronization seam. The current model has no mouth
	# morphs, so accepting a real playback envelope does NOT claim lip sync.
	last_audio_position = maxf(0.0, media_seconds) if is_finite(media_seconds) else 0.0
	last_audio_envelope = clampf(envelope, 0.0, 1.0) if speaking and is_finite(envelope) else 0.0
	audio_active = speaking


func get_current_behavior() -> String:
	return current_behavior
