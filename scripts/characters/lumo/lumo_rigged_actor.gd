extends Node3D
## Shared visual character adapter. No race physics, audio engine or rewards.
## Uses the existing companion behavior names rather than a second event bus.
signal behavior_started(behavior: String)
signal behavior_finished(behavior: String)
const MODEL := "res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb"
const WALK = preload("res://scripts/characters/lumo/lumo_walk_locomotion.gd")
static var _cached_model: PackedScene
static var _cached_load_kind := ""
var model_load_kind := ""
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
var locomotion
var walking := false
var walk_speed_mps: float = 0.0


func _ready() -> void:
	if _cached_model == null:
		# Exported games resolve the GLB through Godot's imported PackedScene.
		# Do not require raw source bytes, and never put loading side effects
		# inside assert(): release builds remove those expressions.
		if ResourceLoader.exists(MODEL, "PackedScene"):
			_cached_model = ResourceLoader.load(MODEL, "PackedScene") as PackedScene
			_cached_load_kind = "imported_packed_scene"
		elif FileAccess.file_exists(MODEL):
			# Bare headless review fixtures can run before editor import.
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var error := document.append_from_file(MODEL, state)
			if error != OK:
				push_warning("[LumoRig] Source model cannot be loaded; retain existing visual")
				return
			var source := document.generate_scene(state)
			if source == null:
				return
			var packed := PackedScene.new()
			error = packed.pack(source)
			source.free()
			if error != OK:
				return
			_cached_model = packed
			_cached_load_kind = "source_fixture"
	if _cached_model == null:
		push_warning("[LumoRig] Model is unavailable; retain existing visual")
		return
	visual = _cached_model.instantiate() as Node3D
	if visual == null:
		return
	add_child(visual)
	for node in visual.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		player = node
	if skeleton == null or player == null or skeleton.get_bone_count() != 65:
		push_warning("[LumoRig] Incompatible skeleton; retain existing visual")
		return
	for clip in CLIPS:
		if not player.has_animation(clip):
			push_warning("[LumoRig] Missing animation: " + clip)
			player = null
			return
	model_load_kind = _cached_load_kind
	for clip in ["idle", "kart_seated", "kart_steer_left", "kart_steer_right"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_finished)
	locomotion = WALK.new()
	play_behavior("idle")


func is_usable() -> bool:
	return is_instance_valid(skeleton) and is_instance_valid(player) and not model_load_kind.is_empty()


func _process(delta: float) -> void:
	if walking and not suspended and not reduced_motion and locomotion != null:
		locomotion.advance(delta, walk_speed_mps)


## The owner supplies actual horizontal velocity from navigation/physics.
## This API affects bones only; it cannot teleport or slide the root node.
func set_locomotion_speed(speed_mps: float) -> bool:
	if not is_usable():
		return false
	if not is_finite(speed_mps) or speed_mps <= 0.045:
		if walking:
			play_behavior("idle")
		return true
	walk_speed_mps = clampf(speed_mps, 0.05, 3.2)
	if not walking:
		return play_behavior("walk_loop")
	return true


func play_behavior(behavior: String) -> bool:
	if suspended or player == null:
		return false
	if behavior == "walk_loop":
		if not is_usable():
			return false
		if not walking:
			player.play("idle", 0.0)
			player.advance(0.0)
			player.pause()
			if locomotion == null or not locomotion.bind(skeleton):
				return false
		walking = true
		walk_speed_mps = maxf(walk_speed_mps, 0.9)
		current_behavior = behavior
		behavior_started.emit(behavior)
		return true
	if not CLIPS.has(behavior):
		return false
	if walking:
		walking = false
		locomotion.stop()
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
	if suspended == value:
		return
	suspended = value
	if player == null:
		return
	if value:
		player.pause()
	else:
		if walking:
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
