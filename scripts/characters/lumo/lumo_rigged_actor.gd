extends Node3D
## Shared visual character adapter. No race physics, audio engine or rewards.
## Uses the existing companion behavior names rather than a second event bus.
signal behavior_started(behavior: String)
signal behavior_finished(behavior: String)
const MODEL := "res://assets/characters/lumo_facial/Lumo-Facial-Mobile.glb"
const ORIGINAL_MODEL := "res://assets/characters/lumo_animated/Lumo-Animated-Mobile.glb"
const WALK = preload("res://scripts/characters/lumo/lumo_walk_locomotion.gd")
const PLATFORM_POSE = preload("res://scripts/characters/lumo/lumo_platform_pose.gd")
const TEACHER_POSE = preload("res://scripts/characters/lumo/lumo_teacher_pose.gd")
const FACIAL_POSE = preload("res://scripts/characters/lumo/lumo_facial_pose.gd")
const LEARNING_MODEL := "res://assets/characters/lumo_nextgen_chat3/Lumo-Learning-Animated.glb"
static var _models: Dictionary = {}
static var _load_kinds: Dictionary = {}
@export var prefer_learning_model := false
var using_learning_model := false
var _mouth_mesh: MeshInstance3D
var _lid_mesh: MeshInstance3D
var _mouth_index := -1
var _blink_index := -1
var _blink_clock := 0.0
var _mouth_media := -1.0
var _mouth_age := 1.0
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
var phoneme_lipsync_supported := false
var facial_pose
var last_audio_position := 0.0
var last_audio_envelope := 0.0
var audio_active := false
var locomotion
var walking := false
var walk_speed_mps: float = 0.0
var platform_pose
var platform_active: bool = false
var teacher_pose
var teacher_enabled: bool = false
var _teacher_previous_process_mode: int = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func _load_model(path: String) -> PackedScene:
	if _models.has(path):
		return _models[path] as PackedScene
	var packed: PackedScene
	if ResourceLoader.exists(path, "PackedScene"):
		packed = ResourceLoader.load(path, "PackedScene") as PackedScene
		if packed != null:
			_load_kinds[path] = "imported_packed_scene"
	elif FileAccess.file_exists(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) != OK:
			return null
		var source := document.generate_scene(state)
		if source == null:
			return null
		packed = PackedScene.new()
		var error := packed.pack(source)
		source.free()
		if error != OK:
			return null
		_load_kinds[path] = "source_fixture"
	if packed != null:
		_models[path] = packed
	return packed


func _ready() -> void:
	var paths: Array[String] = [MODEL, ORIGINAL_MODEL]
	if prefer_learning_model:
		paths.push_front(LEARNING_MODEL)
	for path in paths:
		var packed := _load_model(path)
		if packed == null:
			continue
		var candidate := packed.instantiate() as Node3D
		if candidate == null:
			continue
		var candidate_skeleton: Skeleton3D
		var candidate_player: AnimationPlayer
		for node in candidate.find_children("*", "Skeleton3D", true, false):
			if (node as Skeleton3D).get_bone_count() == 65:
				candidate_skeleton = node as Skeleton3D
				break
		for node in candidate.find_children("*", "AnimationPlayer", true, false):
			var animations := node as AnimationPlayer
			var complete := true
			for clip in CLIPS:
				if not animations.has_animation(clip):
					complete = false
					break
			if complete and (path != LEARNING_MODEL or animations.has_animation("learn_listen")):
				candidate_player = animations
				break
		if candidate_skeleton == null or candidate_player == null:
			candidate.free()
			continue
		visual = candidate
		skeleton = candidate_skeleton
		player = candidate_player
		using_learning_model = path == LEARNING_MODEL
		model_load_kind = str(_load_kinds.get(path, ""))
		break
	if visual == null:
		push_warning("[LumoRig] No compatible 65-bone model with the required clips")
		return
	add_child(visual)
	for clip in ["idle", "kart_seated", "kart_steer_left", "kart_steer_right"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_finished)
	locomotion = WALK.new()
	facial_pose = FACIAL_POSE.new()
	if not facial_pose.bind(visual, skeleton):
		facial_pose = null
	if using_learning_model:
		_bind_learning_morphs()
	mouth_supported = facial_pose != null or _mouth_index >= 0
	play_behavior("idle")


func _bind_learning_morphs() -> void:
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		for index in range(part.mesh.get_blend_shape_count()):
			var shape := str(part.mesh.get_blend_shape_name(index))
			if part.name.begins_with("MouthVisemes") and shape == "viseme_A":
				_mouth_mesh = part
				_mouth_index = index
			elif part.name.begins_with("Eyelid") and shape == "blink":
				_lid_mesh = part
				_blink_index = index
	# Amplitude is not phoneme recognition. Never claim phoneme lip sync.
	phoneme_lipsync_supported = false


func _reset_learning_face() -> void:
	_mouth_media = -1.0
	_mouth_age = 1.0
	_blink_clock = 0.0
	if is_instance_valid(_mouth_mesh) and _mouth_index >= 0:
		_mouth_mesh.set_blend_shape_value(_mouth_index, 0.0)
	if is_instance_valid(_lid_mesh) and _blink_index >= 0:
		_lid_mesh.set_blend_shape_value(_blink_index, 0.0)

func is_usable() -> bool:
	return is_instance_valid(skeleton) and is_instance_valid(player) and not model_load_kind.is_empty()


func _process(delta: float) -> void:
	if teacher_enabled:
		if not suspended and not reduced_motion:
			# The same owner restores and samples the authored pose before
			# adding gaze; constant animation tracks cannot accumulate offsets.
			teacher_pose.restore_sampled_pose()
			player.advance(minf(delta, 0.10))
			teacher_pose.advance(self, delta)
		_advance_face(delta)
		return
	# Reduced-motion suppresses decorative idle/facial motion, but locomotion is
	# essential feedback: a moving character must still articulate its gait.
	if walking and not platform_active and not suspended and locomotion != null:
		locomotion.advance(delta, walk_speed_mps)
	_advance_face(delta)


func _advance_face(delta: float) -> void:
	if facial_pose != null and not suspended and not reduced_motion:
		facial_pose.advance(delta)
	if not using_learning_model or suspended or reduced_motion or not is_finite(delta) or delta <= 0.0:
		return
	_mouth_age += minf(delta, 1.0)
	if _mouth_age > 0.35 and is_instance_valid(_mouth_mesh) and _mouth_index >= 0:
		_mouth_mesh.set_blend_shape_value(_mouth_index, 0.0)
	if facial_pose == null and is_instance_valid(_lid_mesh) and _blink_index >= 0:
		_blink_clock = fmod(_blink_clock + delta, 4.1)
		var weight := sin(_blink_clock * PI / 0.17) if _blink_clock <= 0.17 else 0.0
		_lid_mesh.set_blend_shape_value(_blink_index, maxf(0.0, weight))


## The owner supplies actual horizontal velocity from navigation/physics.
## This API affects bones only; it cannot teleport or slide the root node.
func set_locomotion_speed(speed_mps: float) -> bool:
	if not is_usable():
		return false
	_stop_teacher_mode()
	_stop_platform_pose()
	if not is_finite(speed_mps) or speed_mps <= 0.045:
		if walking:
			play_behavior("idle")
		return true
	walk_speed_mps = clampf(speed_mps, 0.05, 3.2)
	if not walking:
		return play_behavior("walk_loop")
	return true


## Feed after move_and_slide(), once per physics tick. This optional mode is
## shared by Jump and walking worlds. It has sole ownership of animated bones;
## the original AnimationPlayer is paused until a gesture/legacy mode resumes.
## Gait look for action games (bigger stride, knee lift and arm swing). Empty =
## the authored calm gait. Applies to the running pose owner at once and later.
var platform_style: Dictionary = {}


func _effective_platform_style() -> Dictionary:
	if not reduced_motion:
		return platform_style
	# Walking/running is functional motion, not decorative motion. Keep the gait
	# readable in calm/reduced mode while lowering the amount of body movement.
	return {
		"limb_gain": minf(float(platform_style.get("limb_gain", 1.0)), 0.72),
		"bounce_gain": minf(float(platform_style.get("bounce_gain", 1.0)), 0.55),
		"run_floor": 0.0,
		"response": clampf(float(platform_style.get("response", 22.0)), 14.0, 22.0),
	}


func set_platform_style(style: Dictionary) -> void:
	platform_style = style.duplicate()
	if platform_active and platform_pose != null:
		platform_pose.set_style(_effective_platform_style())


func set_platform_motion(velocity: Vector3, grounded: bool, delta: float) -> bool:
	if not is_usable() or suspended or not velocity.is_finite() or delta <= 0.0:
		return false
	_stop_teacher_mode()
	var speed: float = Vector2(velocity.x, velocity.z).length()
	# Let the original authored idle breathe again after the landing settles.
	# Do not repeatedly restart it on every physics tick.
	if grounded and speed <= 0.06:
		if platform_active and platform_pose.was_grounded and platform_pose.landing_left <= 0.0:
			_stop_platform_pose()
		if not platform_active:
			if walking:
				play_behavior("idle")
			return true
	if not platform_active:
		if walking and locomotion != null:
			locomotion.stop()
		player.play("idle", 0.0)
		# play() resumes an already-selected idle at its current position.
		# The studio curves are relative to frame zero, including Root height.
		player.seek(0.0, true)
		player.advance(0.0)
		player.pause()
		platform_pose = PLATFORM_POSE.new()
		if not platform_pose.bind(skeleton):
			player.play("idle")
			return false
		platform_pose.set_style(_effective_platform_style())
		platform_active = true
	walking = grounded and speed > 0.06
	walk_speed_mps = speed
	# Never freeze the skeleton while the body is translating. That produced
	# the visible "gliding Lumo" regression in Lumo World.
	platform_pose.advance(velocity, grounded, delta)
	current_behavior = platform_pose.state
	return true


func _stop_platform_pose() -> void:
	if not platform_active:
		return
	platform_pose.stop()
	platform_active = false
	walking = false
	current_behavior = "idle"
	player.play("idle", 0.12)


func _enable_teacher_mode() -> bool:
	if not is_usable():
		return false
	if teacher_enabled:
		return true
	# The kart adapter already owns its AnimationPlayer manually. Do not
	# compete with that owner if a caller accidentally sends teacher events.
	if player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		return false
	_stop_platform_pose()
	if walking:
		play_behavior("idle")
	teacher_pose = TEACHER_POSE.new()
	if not teacher_pose.bind(skeleton):
		return false
	_teacher_previous_process_mode = player.callback_mode_process
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	teacher_enabled = true
	return true


func _stop_teacher_mode() -> void:
	if not teacher_enabled:
		return
	teacher_pose.restore_sampled_pose()
	teacher_enabled = false
	player.callback_mode_process = _teacher_previous_process_mode
	player.advance(0.0)


func set_teaching_target(world_position: Vector3) -> bool:
	if not world_position.is_finite() or not _enable_teacher_mode():
		return false
	if facial_pose != null:
		facial_pose.set_target(world_position)
	return teacher_pose.set_target(world_position)


func clear_teaching_target() -> void:
	if teacher_enabled:
		teacher_pose.has_target = false
	if facial_pose != null:
		facial_pose.has_target = false


func cancel_teaching_performance() -> void:
	# One explicit cancellation for a lesson/utterance: the old point/celebrate
	# clip must not continue after the mouth has already closed. Callers that
	# merely replace audio use apply_speech_sample(false) instead.
	clear_teaching_target()
	apply_speech_sample(0.0, 0.0, false)
	if facial_pose != null:
		facial_pose.reset()
	if not teacher_enabled or not is_usable():
		return
	teacher_pose.restore_sampled_pose()
	teacher_pose.speaking = false
	teacher_pose.reaction = "idle"
	teacher_pose.reaction_left = 0.0
	teacher_pose.angles = Vector2.ZERO
	current_behavior = "idle"
	# No crossfade from a cancelled pointing pose, even for a reduced-motion
	# frame. Sample the authored neutral pose now, then keep normal idle alive.
	player.play("idle", 0.0)
	player.seek(0.0, true)
	player.advance(0.0)
	if suspended or reduced_motion:
		player.pause()


func teacher_react(event: String) -> bool:
	var clips: Dictionary = {"explain": "point_portal", "encourage": "agree_nod", "correct": "agree_nod", "celebrate": "celebrate", "welcome": "greeting_wave"}
	if not clips.has(event) or suspended or not _enable_teacher_mode():
		return false
	teacher_pose.react(event)
	var selected := str(clips[event])
	if using_learning_model:
		var learning_clips := {"explain": "learn_explain", "encourage": "learn_encourage", "correct": "learn_nod", "celebrate": "learn_celebrate", "welcome": "greeting_wave"}
		var authored := str(learning_clips.get(event, selected))
		if player.has_animation(authored):
			selected = authored
	return play_behavior(selected)


func set_teacher_speaking(value: bool) -> bool:
	if not _enable_teacher_mode():
		return false
	# This drives gentle explaining motion only. It is not a viseme/jaw API.
	teacher_pose.speaking = value
	return true


func play_behavior(behavior: String) -> bool:
	if suspended or player == null:
		return false
	if teacher_enabled:
		teacher_pose.restore_sampled_pose()
	_stop_platform_pose()
	if behavior == "walk_loop":
		if not is_usable():
			return false
		_stop_teacher_mode()
		if not walking:
			player.play("idle", 0.0)
			player.seek(0.0, true)
			player.advance(0.0)
			player.pause()
			if locomotion == null or not locomotion.bind(skeleton):
				return false
		walking = true
		walk_speed_mps = maxf(walk_speed_mps, 0.9)
		current_behavior = behavior
		behavior_started.emit(behavior)
		return true
	if not CLIPS.has(behavior) and not (using_learning_model and behavior.begins_with("learn_") and player.has_animation(behavior)):
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
	if value:
		if facial_pose != null:
			facial_pose.reset()
		_reset_learning_face()
		apply_speech_sample(0.0, 0.0, false)
	if player == null:
		return
	if value:
		player.pause()
	else:
		if walking or platform_active:
			player.pause()
		else:
			player.play()
			if reduced_motion:
				player.pause()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		if facial_pose != null:
			facial_pose.reset()
		_reset_learning_face()
		apply_speech_sample(0.0, 0.0, false)
	if platform_active and platform_pose != null:
		platform_pose.set_style(_effective_platform_style())
		return
	if not suspended:
		play_behavior(current_behavior)


func apply_speech_sample(media_seconds: float, envelope: float, speaking: bool) -> void:
	# Actual PCM amplitude drives the derived closed-muzzle shape. The source
	# still has no mouth cavity or phoneme/viseme model; do not claim lip sync.
	speaking = speaking and not suspended and not reduced_motion
	last_audio_position = maxf(0.0, media_seconds) if is_finite(media_seconds) else 0.0
	last_audio_envelope = clampf(envelope, 0.0, 1.0) if speaking and is_finite(envelope) else 0.0
	audio_active = speaking
	if facial_pose != null:
		facial_pose.speech_sample(media_seconds, envelope, speaking)
	if using_learning_model and is_instance_valid(_mouth_mesh) and _mouth_index >= 0:
		if not speaking or not is_finite(media_seconds) or media_seconds < 0.0 or not is_finite(envelope):
			_mouth_media = -1.0
			_mouth_age = 1.0
			_mouth_mesh.set_blend_shape_value(_mouth_index, 0.0)
		elif not is_equal_approx(media_seconds, _mouth_media):
			_mouth_media = media_seconds
			_mouth_age = 0.0
			_mouth_mesh.set_blend_shape_value(_mouth_index, last_audio_envelope * 0.85)


func get_current_behavior() -> String:
	return current_behavior
