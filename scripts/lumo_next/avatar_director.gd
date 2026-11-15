extends Node
## An instance-local animation owner for the editable LUMO learning character.
## Mouth time is supplied by actual audio playback, never elapsed text length.
## Timed shape cues are supported; their phonetic accuracy is not inferred here.

signal state_changed(state: String)
signal behavior_started(behavior: String)
signal behavior_finished(behavior: String)
signal stop_playback_requested(turn_id: String, reason: String)
signal target_unavailable(target_id: String, reason: String)
signal event_rejected(reason: String)

const PROTOCOL_VERSION: int = 1
const STALE_AUDIO_SECONDS: float = 0.35
const MAX_CUES: int = 2048
const MAX_CUE_TIME_MS: float = 900000.0
const MOUTH_SHAPES: Array[String] = ["AA", "EE", "OH", "OU", "MBP", "FV", "L", "TH"]
const LOOP_CLIPS: Array[String] = ["idle_breathe", "listening", "thinking", "focused_input"]
const STATE_CLIP: Dictionary = {
	"idle": "idle_breathe",
	"greeting": "greeting",
	"listening": "listening",
	"thinking": "thinking",
	"answer": "answer",
	"explaining": "explain",
	"pointing": "point",
	"nodding": "nod",
	"unsure": "unsure",
	"encouraging": "encourage",
	"celebrating": "celebrate_step",
	"interrupt": "interrupt",
	"farewell": "farewell",
	"focused_input": "focused_input",
	"paused": "focused_input",
}
const EVENT_STATE: Dictionary = {
	"idle": "idle", "wait": "idle", "greeting": "greeting", "greet": "greeting",
	"welcome": "greeting", "greeting_wave": "greeting", "listen": "listening",
	"listening": "listening", "think": "thinking", "thinking": "thinking",
	"answer": "answer", "explain": "explaining", "demonstrate": "explaining",
	"point": "pointing", "point_portal": "pointing", "nod": "nodding",
	"agree_nod": "nodding", "correct": "nodding", "approve": "nodding",
	"unsure": "unsure", "encourage": "encouraging", "celebrate": "celebrating",
	"celebrate_step": "celebrating", "farewell": "farewell", "goodbye": "farewell",
}
const CLIP_FALLBACKS: Dictionary = {
	"idle_breathe": "idle", "greeting": "greeting_wave", "nod": "agree_nod",
	"point": "point_portal", "explain": "point_portal", "celebrate_step": "celebrate",
}

var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var registry: Node
var state: String = "idle"
var current_clip: String = ""
var active_turn: String = ""
var active_lesson: String = ""
var active_revision: int = 0
var target_id: String = ""
var point_target_id: String = ""
var mouth_mode: String = "closed"
var cue_source: String = "none"
var last_media_ms: float = 0.0
var suspended: bool = false
var focused_input: bool = false
var reduced_motion: bool = false
var last_rejection: String = ""
var mouth_supported: bool = false
var timed_shapes_supported: bool = false
var pointing_angular_error_degrees: float = -1.0

var _shapes: Dictionary = {}
var _lid_meshes: Array[MeshInstance3D] = []
var _bones: Dictionary = {}
var _base_rotations: Dictionary = {}
var _mouth_weights: Dictionary = {}
var _turn_open: bool = false
var _seen_turns: Dictionary = {}
var _cues: Array[Dictionary] = []
var _cue_audio_id: String = ""
var _audio_id: String = ""
var _audio_state: String = "idle"
var _audio_audible: bool = false
var _audio_envelope_available: bool = false
var _audio_envelope: float = 0.0
var _audio_age: float = 1000.0
var _has_audio_position: bool = false
var _audio_player: AudioStreamPlayer
var _audio_turn: String = ""
var _audio_envelope_provider: Callable
var _camera: Camera3D
var _usable_rect: Rect2
var _gaze_angles: Vector2 = Vector2.ZERO
var _eye_angles: Vector2 = Vector2.ZERO
var _point_weight: float = 0.0
var _point_side: String = ".L"
var _clock: float = 0.0
var _next_blink: float = 2.5
var _blink_start: float = -1.0
var _blink: float = 0.0
var _idle_gaze: Vector2 = Vector2.ZERO
var _next_idle_gaze: float = 1.7
var _interrupt_left: float = 0.0
var _previous_player_mode: int = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_next_blink = _random.randf_range(2.2, 4.4)


func bind_character(source: Node3D, target_registry: Node = null) -> bool:
	unbind_character()
	if not is_instance_valid(source):
		return _reject("missing_character")
	visual = source
	registry = target_registry
	if is_instance_valid(registry):
		if registry.has_signal("lesson_changed"):
			registry.lesson_changed.connect(_lesson_changed)
		if registry.has_signal("target_removed"):
			registry.target_removed.connect(_target_removed)
	for child in source.find_children("*", "Skeleton3D", true, false):
		if skeleton == null:
			skeleton = child as Skeleton3D
	for child in source.find_children("*", "AnimationPlayer", true, false):
		if player == null:
			player = child as AnimationPlayer
	if skeleton == null or player == null:
		unbind_character()
		return _reject("missing_rig_or_animation_player")
	for name in [
		"Head", "Neck", "Ear.L", "Ear.R", "TailBase", "Tail1", "Tail2", "Tail3",
		"UpperArm.L", "Forearm.L", "Wrist.L", "Hand.L",
		"UpperArm.R", "Forearm.R", "Wrist.R", "Hand.R"
	]:
		var index := skeleton.find_bone(name)
		if index >= 0:
			_bones[name] = index
	if not _bones.has("Head") or not _bones.has("Neck"):
		unbind_character()
		return _reject("missing_head_or_neck")
	var meshes: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
	if source is MeshInstance3D:
		meshes.append(source)
	for child in meshes:
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		if str(instance.name) == "LumoEyelids":
			_lid_meshes.append(instance)
		for index in range(instance.mesh.get_blend_shape_count()):
			var name := str(instance.mesh.get_blend_shape_name(index))
			if not _shapes.has(name):
				_shapes[name] = []
			_shapes[name].append({"mesh": instance, "index": index})
	mouth_supported = _shapes.has("AA") or _shapes.has("JawArticulation")
	timed_shapes_supported = true
	for name in MOUTH_SHAPES:
		timed_shapes_supported = timed_shapes_supported and _shapes.has(name)
	# Imported Animation resources may be shared with other instantiated actors.
	# Copy libraries before changing loop flags; only this director owns them.
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, library)
	for clip in LOOP_CLIPS:
		var resolved := _resolve_clip(clip)
		if not resolved.is_empty():
			player.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
	_previous_player_mode = player.callback_mode_process
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.animation_finished.connect(_clip_finished)
	_reset_face()
	_transition("idle", true)
	return true


func unbind_character() -> void:
	_end_audio("character_unbound", true)
	_turn_open = false
	_cues.clear()
	clear_attention_target()
	if is_instance_valid(registry):
		if registry.has_signal("lesson_changed") and registry.lesson_changed.is_connected(_lesson_changed):
			registry.lesson_changed.disconnect(_lesson_changed)
		if registry.has_signal("target_removed") and registry.target_removed.is_connected(_target_removed):
			registry.target_removed.disconnect(_target_removed)
	registry = null
	_restore_bone_offsets()
	_close_mouth()
	if is_instance_valid(player):
		if player.animation_finished.is_connected(_clip_finished):
			player.animation_finished.disconnect(_clip_finished)
		player.callback_mode_process = _previous_player_mode
		player.pause()
	visual = null
	skeleton = null
	player = null
	_shapes.clear()
	_lid_meshes.clear()
	_bones.clear()
	_mouth_weights.clear()
	mouth_supported = false
	timed_shapes_supported = false
	current_clip = ""


func is_usable() -> bool:
	return is_instance_valid(visual) and is_instance_valid(skeleton) and is_instance_valid(player)


func begin_turn(id: String, lesson: String, revision: int = 0) -> bool:
	if not _valid_id(id) or not _valid_id(lesson) or revision < 0:
		return _reject("invalid_turn_scope")
	if suspended or focused_input:
		return _reject("input_or_pause_active")
	if _seen_turns.has(id):
		return _reject("turn_id_reused")
	if is_instance_valid(registry):
		if registry.get("lesson_id") != lesson or registry.get("revision") != revision:
			return _reject("lesson_revision_mismatch")
	_end_audio("superseded", true)
	active_turn = id
	active_lesson = lesson
	active_revision = revision
	_turn_open = true
	_seen_turns[id] = true
	_cues.clear()
	_cue_audio_id = ""
	cue_source = "none"
	_audio_id = ""
	_has_audio_position = false
	_audio_age = 1000.0
	last_media_ms = 0.0
	_interrupt_left = 0.0
	last_rejection = ""
	return true


func handle_event(event: Dictionary) -> bool:
	if not _scope_matches(event):
		return false
	var type := str(event.get("type", ""))
	if type == "interrupt":
		interrupt("child_interrupt")
		return true
	if type in ["focused_input", "input_started"]:
		set_focused_input(true)
		return true
	if type == "pause":
		set_suspended(true)
		return true
	if suspended or focused_input:
		return _reject("input_or_pause_active")
	if not EVENT_STATE.has(type):
		return _reject("unknown_event")
	var requested_target := str(event.get("target_id", ""))
	if not requested_target.is_empty():
		if not set_attention_target(requested_target):
			return false
	elif type in ["point", "point_portal", "demonstrate"]:
		return _reject("point_requires_target_id")
	if type in ["point", "point_portal", "demonstrate"]:
		point_target_id = requested_target
		_choose_point_side()
	elif type not in ["explain", "answer"]:
		point_target_id = ""
	_transition(str(EVENT_STATE[type]))
	return true


## Local adapter for existing app events. Scoped host events use handle_event().
func play_behavior(behavior: String) -> bool:
	if not EVENT_STATE.has(behavior) or suspended or focused_input:
		return false
	if behavior in ["point", "point_portal"] and target_id.is_empty():
		return false
	if behavior in ["point", "point_portal"]:
		point_target_id = target_id
		_choose_point_side()
	else:
		point_target_id = ""
	_transition(str(EVENT_STATE[behavior]))
	return true


func set_view(camera: Camera3D, usable_rect: Rect2) -> void:
	_camera = camera
	_usable_rect = usable_rect


func set_attention_target(id: String) -> bool:
	if not is_instance_valid(registry) or not registry.has_method("resolve_target"):
		return _reject("missing_target_registry")
	var resolved: Dictionary = registry.resolve_target(id)
	if resolved.is_empty() or not resolved.visible:
		target_unavailable.emit(id, "missing_or_hidden")
		return _reject("missing_or_hidden_target")
	if is_instance_valid(_camera):
		var visibility: Dictionary = registry.viewport_visibility(id, _camera, _usable_rect)
		if not visibility.visible:
			target_unavailable.emit(id, str(visibility.reason))
			return _reject("target_not_in_active_view")
	target_id = id
	return true


func clear_attention_target() -> void:
	target_id = ""
	point_target_id = ""


func _lesson_changed(lesson: String, revision: int) -> void:
	if not active_lesson.is_empty() and (lesson != active_lesson or revision != active_revision):
		interrupt("lesson_changed")


func _target_removed(id: String) -> void:
	if id == target_id or id == point_target_id:
		clear_attention_target()
		_point_weight = 0.0
		_restore_bone_offsets()
		_gaze_angles = Vector2.ZERO
		_eye_angles = Vector2.ZERO
		for name in ["LookLeft", "LookRight", "LookUp", "LookDown"]:
			_set_shape(name, 0.0)
		target_unavailable.emit(id, "removed")


## Cues must come from the same audio. No guessed timing from text is generated.
## Empty cues explicitly select measured-envelope animation on the next sample.
func set_mouth_cues(
	id: String, audio_id: String, cues: Array, source: String = "aligned_audio"
) -> bool:
	if id != active_turn or not _turn_open:
		return _reject("stale_turn")
	if cues.is_empty():
		_cues.clear()
		_cue_audio_id = ""
		cue_source = "none"
		return true
	if not _valid_id(audio_id) or source not in ["aligned_audio", "authored_fixture"]:
		return _reject("invalid_cue_provenance")
	if cues.size() > MAX_CUES or not timed_shapes_supported:
		return _reject("unsupported_mouth_cues")
	var parsed: Array[Dictionary] = []
	var previous_end := -1.0
	for raw: Variant in cues:
		if not raw is Dictionary:
			return _reject("invalid_mouth_cue")
		if not _finite_number(raw.get("start_ms")) or not _finite_number(raw.get("end_ms")):
			return _reject("invalid_cue_time")
		var start: float = float(raw.start_ms)
		var end: float = float(raw.end_ms)
		var shape := str(raw.get("shape", ""))
		var weight: Variant = raw.get("weight", 1.0)
		if (
			start < 0.0 or end <= start or end > MAX_CUE_TIME_MS or start < previous_end
			or (shape not in MOUTH_SHAPES and shape != "Neutral")
			or not _finite_number(weight) or float(weight) < 0.0 or float(weight) > 1.0
		):
			return _reject("invalid_or_overlapping_cue")
		parsed.append({"start_ms": start, "end_ms": end, "shape": shape, "weight": float(weight)})
		previous_end = end
	_cues = parsed
	_cue_audio_id = audio_id
	cue_source = source
	return true


## This accepts snapshots from MediaPlayer, not independent animation clocks.
## position_ms is the measured media position; repeated positions expire.
func push_playback_sample(sample: Dictionary) -> bool:
	if not _scope_matches(sample):
		return false
	if suspended or focused_input:
		return _reject("input_or_pause_active")
	var next_state := str(sample.get("state", "idle"))
	if next_state not in ["preparing", "playing", "paused", "completed", "unavailable", "idle"]:
		return _reject("invalid_playback_state")
	var position: Variant = sample.get("position_ms", sample.get("positionMs", 0.0))
	var envelope: Variant = sample.get("envelope", 0.0)
	if (
		not _finite_number(position) or float(position) < 0.0
		or not _finite_number(envelope) or float(envelope) < 0.0 or float(envelope) > 1.0
	):
		_audio_audible = false
		_audio_envelope_available = false
		_close_mouth()
		return _reject("invalid_audio_measurement")
	var previous_state := _audio_state
	_audio_state = next_state
	_audio_id = str(sample.get("audio_id", ""))
	_audio_audible = next_state == "playing" and sample.get("audible", false) == true
	_audio_envelope_available = sample.get(
		"envelope_available", sample.get("envelopeAvailable", false)
	) == true
	_audio_envelope = float(envelope) if _audio_audible else 0.0
	if not _has_audio_position or not is_equal_approx(float(position), last_media_ms):
		_audio_age = 0.0
	last_media_ms = float(position)
	_has_audio_position = true
	if not _audio_audible:
		_close_mouth()
	if next_state == "paused" and previous_state in ["preparing", "playing"]:
		clear_attention_target()
		_point_weight = 0.0
		_restore_bone_offsets()
		if is_instance_valid(player):
			player.stop()
		_transition("listening", true)
	if next_state in ["completed", "unavailable", "idle"]:
		_turn_open = false
		_cues.clear()
		_cue_audio_id = ""
		cue_source = "none"
		point_target_id = ""
		_transition("listening")
	return true


## Godot-owned audio path. The supplied callback, if any, reads measured PCM
## amplitude at this player's position; omitting it never invents amplitude.
func bind_audio_player(
	source: AudioStreamPlayer, id: String, audio_id: String = "", envelope_provider: Callable = Callable()
) -> bool:
	if not is_instance_valid(source) or id != active_turn or not _turn_open:
		return _reject("invalid_audio_binding")
	_audio_player = source
	_audio_turn = id
	_audio_id = audio_id
	_audio_envelope_provider = envelope_provider
	return true


func interrupt(reason: String = "interrupted") -> void:
	_end_audio(reason, true)
	_turn_open = false
	_cues.clear()
	_cue_audio_id = ""
	cue_source = "none"
	clear_attention_target()
	_point_weight = 0.0
	_restore_bone_offsets()
	_reset_face()
	if is_instance_valid(player):
		# Clear an in-progress gesture and its pending AnimationMixer blend.
		player.stop()
	if not suspended and not focused_input:
		_transition("interrupt", true)
		_interrupt_left = 0.16


func set_focused_input(value: bool) -> void:
	if value == focused_input:
		return
	focused_input = value
	if value:
		interrupt("focused_input")
		_transition("focused_input", true)
	else:
		_transition("paused" if suspended else "listening", true)


func set_suspended(value: bool) -> void:
	if value == suspended:
		return
	suspended = value
	if value:
		interrupt("suspended")
		_transition("paused", true)
		if is_instance_valid(player):
			player.pause()
	else:
		_transition("focused_input" if focused_input else "listening", true)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_restore_bone_offsets()
	_point_weight = 0.0
	_transition(state, true)


func diagnostics() -> Dictionary:
	return {
		"protocol": PROTOCOL_VERSION,
		"usable": is_usable(),
		"state": state,
		"clip": current_clip,
		"turn_id": active_turn,
		"turn_open": _turn_open,
		"lesson_id": active_lesson,
		"revision": active_revision,
		"target_id": target_id,
		"point_target_id": point_target_id,
		"pointing_angular_error_degrees": pointing_angular_error_degrees,
		"mouth_mode": mouth_mode,
		"cue_source": cue_source,
		"media_position_ms": last_media_ms,
		"audio_age_seconds": _audio_age,
		"audio_state": _audio_state,
		"audio_audible": _audio_audible,
		"mouth_weights": _mouth_weights.duplicate(),
		"mouth_supported": mouth_supported,
		"timed_shapes_supported": timed_shapes_supported,
		"phonetic_accuracy_verified": false,
		"paused": suspended,
		"focused_input": focused_input,
		"reduced_motion": reduced_motion,
	}


func _process(delta: float) -> void:
	advance(delta)


## Also used by deterministic tests; it never advances an audio timestamp.
func advance(delta: float) -> void:
	if not is_usable() or not is_finite(delta) or delta <= 0.0:
		return
	if is_instance_valid(_audio_player):
		_sample_audio_player()
	_audio_age += delta
	var dt := minf(delta, 0.1)
	_clock += dt
	_restore_bone_offsets()
	if not suspended and not reduced_motion:
		player.advance(dt)
	if _interrupt_left > 0.0:
		_interrupt_left = maxf(0.0, _interrupt_left - delta)
		if _interrupt_left == 0.0 and not suspended and not focused_input:
			_transition("listening")
	if not suspended:
		_update_attention(dt)
		_update_blink(dt)
	_update_mouth(dt)


func _sample_audio_player() -> void:
	if _audio_turn != active_turn or not _turn_open:
		_audio_player = null
		return
	var measured := _audio_player.get_playback_position()
	var playing := _audio_player.playing and not _audio_player.stream_paused
	if playing:
		# These values come from the audio mixer and hardware-output latency.
		measured += AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	measured = maxf(0.0, measured)
	var audible := playing and _audio_player.volume_db > -70.0 and _bus_audible(_audio_player.bus)
	var amplitude: float = 0.0
	var measured_envelope := false
	if audible and _audio_envelope_provider.is_valid():
		var result: Variant = _audio_envelope_provider.call(measured)
		if _finite_number(result) and float(result) >= 0.0 and float(result) <= 1.0:
			amplitude = float(result)
			measured_envelope = true
	var playback_state := "playing" if playing else "paused"
	if not _audio_player.playing and not _audio_player.stream_paused:
		playback_state = "completed"
	push_playback_sample({
		"turn_id": _audio_turn,
		"audio_id": _audio_id,
		"position_ms": measured * 1000.0,
		"state": playback_state,
		"audible": audible,
		"envelope_available": measured_envelope,
		"envelope": amplitude,
	})


static func _bus_audible(name: StringName) -> bool:
	var visited: Dictionary = {}
	var bus := AudioServer.get_bus_index(name)
	while bus >= 0 and not visited.has(bus):
		visited[bus] = true
		if AudioServer.is_bus_mute(bus) or AudioServer.get_bus_volume_db(bus) <= -70.0:
			return false
		if bus == 0:
			return true
		bus = AudioServer.get_bus_index(AudioServer.get_bus_send(bus))
	return false


func _update_mouth(dt: float) -> void:
	if suspended or focused_input or not _turn_open or not _audio_audible or _audio_age >= STALE_AUDIO_SECONDS:
		_close_mouth()
		return
	var desired: Dictionary = {}
	if not _cues.is_empty() and _audio_id == _cue_audio_id:
		mouth_mode = "timed_shapes"
		var cue := _cue_at(last_media_ms)
		if not cue.is_empty() and cue.shape != "Neutral":
			desired[cue.shape] = cue.weight
	elif _audio_envelope_available and mouth_supported:
		mouth_mode = "audio_envelope"
		var shape := "AA" if _shapes.has("AA") else "JawArticulation"
		desired[shape] = _audio_envelope * 0.72
	else:
		_close_mouth()
		return
	# Closed intervals are real pauses, not a free-running talking loop.
	if desired.is_empty() or float(desired.values()[0]) <= 0.0001:
		_close_mouth()
		return
	var names: Array[String] = MOUTH_SHAPES.duplicate()
	names.append("JawArticulation")
	names.append("Neutral")
	var mix := 1.0 - exp(-38.0 * dt)
	for name in names:
		var value := lerpf(float(_mouth_weights.get(name, 0.0)), float(desired.get(name, 0.0)), mix)
		if value < 0.0001:
			value = 0.0
		_mouth_weights[name] = value
		_set_shape(name, value)


func _cue_at(position_ms: float) -> Dictionary:
	var low := 0
	var high := _cues.size() - 1
	while low <= high:
		var middle := (low + high) / 2
		var cue: Dictionary = _cues[middle]
		if position_ms < float(cue.start_ms):
			high = middle - 1
		elif position_ms >= float(cue.end_ms):
			low = middle + 1
		else:
			return cue
	return {}


func _update_attention(dt: float) -> void:
	var at: Variant = _resolved_attention(target_id)
	var desired := Vector2.ZERO
	if at is Vector3 and not focused_input:
		var head_position := _bone_world_position(int(_bones.Head))
		var local: Vector3 = visual.global_basis.orthonormalized().inverse() * (at - head_position)
		var horizontal := Vector2(local.x, local.z).length()
		if local.z > 0.05 and horizontal > 0.05:
			desired = Vector2(
				clampf(atan2(local.x, local.z), -0.65, 0.65),
				clampf(-atan2(local.y, horizontal), -0.32, 0.32)
			)
	elif target_id.is_empty() and not focused_input and not reduced_motion:
		if _clock >= _next_idle_gaze:
			_idle_gaze = Vector2(_random.randf_range(-0.07, 0.07), _random.randf_range(-0.035, 0.025))
			_next_idle_gaze = _clock + _random.randf_range(2.0, 4.8)
		desired = _idle_gaze
	_gaze_angles = _gaze_angles.lerp(desired, 1.0 - exp(-8.0 * dt))
	if not reduced_motion and not focused_input:
		_add_body_rotation("Neck", Quaternion(Vector3.UP, _gaze_angles.x * 0.35) * Quaternion(Vector3.RIGHT, _gaze_angles.y * 0.35))
		_add_body_rotation("Head", Quaternion(Vector3.UP, _gaze_angles.x * 0.65) * Quaternion(Vector3.RIGHT, _gaze_angles.y * 0.65))
	# Morph gaze uses the residual direction in the animated head's rest frame.
	var eye_desired := Vector2.ZERO
	if at is Vector3 and not focused_input:
		var head_index := int(_bones.Head)
		var pose := skeleton.get_bone_global_pose(head_index)
		var frame := (skeleton.global_basis * pose.basis * skeleton.get_bone_global_rest(head_index).basis.inverse()).orthonormalized()
		var direction: Vector3 = frame.inverse() * (at - skeleton.to_global(pose.origin))
		if direction.z > 0.05:
			eye_desired = Vector2(
				clampf(atan2(direction.x, direction.z) / 0.32, -1.0, 1.0),
				clampf(atan2(direction.y, Vector2(direction.x, direction.z).length()) / 0.24, -1.0, 1.0)
			)
	_eye_angles = _eye_angles.lerp(eye_desired, 1.0 - exp(-16.0 * dt))
	var point: Variant = _resolved_attention(point_target_id)
	var should_point := point is Vector3 and not focused_input and not reduced_motion
	_point_weight = move_toward(_point_weight, 1.0 if should_point else 0.0, dt * 5.0)
	pointing_angular_error_degrees = -1.0
	if should_point and _point_weight > 0.0:
		_aim_pointing_arm(point, _point_weight)
	var smile := 0.5 if state in ["greeting", "encouraging", "celebrating", "nodding"] else 0.12
	var concern := 0.52 if state == "unsure" else 0.0
	if _turn_open and _audio_audible and _audio_age < STALE_AUDIO_SECONDS:
		# The facial source specifies a convex viseme mixture and restrained
		# additive emotion so combined extreme shapes cannot pull the lip seam.
		var emotion_scale := minf(1.0, 0.35 / maxf(smile + concern, 0.001))
		smile *= emotion_scale
		concern *= emotion_scale
	_set_shape("Smile", smile)
	_set_shape("Concern", concern)


func _resolved_attention(id: String) -> Variant:
	if id.is_empty() or not is_instance_valid(registry):
		return null
	if not active_lesson.is_empty():
		if registry.get("lesson_id") != active_lesson or registry.get("revision") != active_revision:
			return null
	var resolved: Dictionary = registry.resolve_target(id)
	if resolved.is_empty() or not resolved.visible:
		return null
	if is_instance_valid(_camera):
		var visible: Dictionary = registry.viewport_visibility(id, _camera, _usable_rect)
		if not visible.visible:
			return null
	return resolved.world_position


func _update_blink(_dt: float) -> void:
	if _clock >= _next_blink and _blink_start < 0.0:
		_blink_start = _clock
	_blink = 0.0
	if _blink_start >= 0.0:
		var elapsed := _clock - _blink_start
		if elapsed < 0.075:
			_blink = clampf(elapsed / 0.075, 0.0, 1.0)
		elif elapsed < 0.19:
			_blink = clampf((0.19 - elapsed) / 0.115, 0.0, 1.0)
		else:
			_blink_start = -1.0
			_next_blink = _clock + (_random.randf_range(0.16, 0.24) if _random.randf() < 0.10 else _random.randf_range(2.7, 5.3))
	var gaze := _eye_angles * (1.0 - smoothstep(0.0, 0.3, _blink))
	_set_shape("LookLeft", maxf(0.0, -gaze.x))
	_set_shape("LookRight", maxf(0.0, gaze.x))
	_set_shape("LookUp", maxf(0.0, gaze.y))
	_set_shape("LookDown", maxf(0.0, -gaze.y))
	for side in ["Left", "Right"]:
		if _shapes.has("Blink" + side + "Quarter"):
			_set_shape("Blink" + side, 0.0)
			var stages := ["Quarter", "Half", "ThreeQuarter", "Close"]
			for index in range(stages.size()):
				_set_shape("Blink" + side + stages[index], maxf(0.0, 1.0 - absf(_blink * 4.0 - float(index + 1))))
		else:
			_set_shape("Blink" + side, _blink)
	for lids in _lid_meshes:
		if is_instance_valid(lids):
			lids.visible = _blink > 0.002


func _choose_point_side() -> void:
	var at: Variant = _resolved_attention(point_target_id)
	if not at is Vector3:
		return
	var best := INF
	for side in [".L", ".R"]:
		if not _bones.has("UpperArm" + side):
			continue
		var distance := _bone_world_position(int(_bones["UpperArm" + side])).distance_squared_to(at)
		if distance < best:
			best = distance
			_point_side = side


func _aim_pointing_arm(at: Vector3, weight: float) -> void:
	var names := ["UpperArm" + _point_side, "Forearm" + _point_side, "Wrist" + _point_side, "Hand" + _point_side]
	for name in names:
		if not _bones.has(name):
			return
	var shoulder := _bone_world_position(int(_bones[names[0]]))
	var elbow := _bone_world_position(int(_bones[names[1]]))
	var wrist := _bone_world_position(int(_bones[names[2]]))
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var target_distance := shoulder.distance_to(at)
	if minf(upper_length, lower_length) < 0.0001 or target_distance < 0.05:
		return
	var direction := (at - shoulder) / target_distance
	# Keep a bent elbow; the arm indicates the object without chasing/touching it.
	var reach := clampf(target_distance * 0.88, absf(upper_length - lower_length) + 0.001, (upper_length + lower_length) * 0.94)
	var along := (upper_length * upper_length - lower_length * lower_length + reach * reach) / (2.0 * reach)
	var bend := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var pole := visual.global_basis.orthonormalized() * Vector3(0, -1, -0.25)
	var bend_direction := pole - direction * pole.dot(direction)
	if bend_direction.length_squared() < 0.001:
		bend_direction = direction.cross(visual.global_basis.x)
	bend_direction = bend_direction.normalized()
	var desired_elbow := shoulder + direction * along + bend_direction * bend
	var desired_wrist := shoulder + direction * reach
	_rotate_bone_toward(int(_bones[names[0]]), elbow - shoulder, desired_elbow - shoulder, weight)
	elbow = _bone_world_position(int(_bones[names[1]]))
	wrist = _bone_world_position(int(_bones[names[2]]))
	_rotate_bone_toward(int(_bones[names[1]]), wrist - elbow, desired_wrist - elbow, weight)
	wrist = _bone_world_position(int(_bones[names[2]]))
	var hand := _bone_world_position(int(_bones[names[3]]))
	_rotate_bone_toward(int(_bones[names[2]]), hand - wrist, at - wrist, weight)
	hand = _bone_world_position(int(_bones[names[3]]))
	var paw_ray := (hand - wrist).normalized()
	var object_ray := (at - wrist).normalized()
	pointing_angular_error_degrees = rad_to_deg(acos(clampf(paw_ray.dot(object_ray), -1.0, 1.0)))


func _rotate_bone_toward(index: int, current: Vector3, desired: Vector3, weight: float) -> void:
	if current.length_squared() < 0.0000001 or desired.length_squared() < 0.0000001:
		return
	var world_delta := Quaternion(current.normalized(), desired.normalized())
	world_delta = Quaternion.IDENTITY.slerp(world_delta, clampf(weight, 0.0, 1.0))
	var world_rotation := (skeleton.global_basis * skeleton.get_bone_global_pose(index).basis).orthonormalized().get_rotation_quaternion()
	_save_bone(index)
	var local_delta := world_rotation.inverse() * world_delta * world_rotation
	skeleton.set_bone_pose_rotation(index, (skeleton.get_bone_pose_rotation(index) * local_delta).normalized())
	skeleton.force_update_all_bone_transforms()


func _bone_world_position(index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)


func _add_body_rotation(name: String, rotation: Quaternion) -> void:
	if not _bones.has(name):
		return
	var index := int(_bones[name])
	_save_bone(index)
	var body := visual.global_basis.orthonormalized().get_rotation_quaternion()
	var bone := (skeleton.global_basis * skeleton.get_bone_global_pose(index).basis).orthonormalized().get_rotation_quaternion()
	var local := bone.inverse() * body * rotation * body.inverse() * bone
	skeleton.set_bone_pose_rotation(index, (skeleton.get_bone_pose_rotation(index) * local).normalized())
	skeleton.force_update_all_bone_transforms()


func _save_bone(index: int) -> void:
	if not _base_rotations.has(index):
		_base_rotations[index] = skeleton.get_bone_pose_rotation(index)


func _restore_bone_offsets() -> void:
	if is_instance_valid(skeleton):
		for index: int in _base_rotations:
			skeleton.set_bone_pose_rotation(index, _base_rotations[index])
		skeleton.force_update_all_bone_transforms()
	_base_rotations.clear()


func _transition(next: String, force: bool = false) -> void:
	if not STATE_CLIP.has(next):
		return
	var clip := _resolve_clip(str(STATE_CLIP[next]))
	if state != next:
		state = next
		state_changed.emit(state)
	if not is_instance_valid(player) or clip.is_empty():
		return
	if current_clip == clip and player.is_playing() and not force:
		return
	_restore_bone_offsets()
	current_clip = clip
	player.play(clip, 0.18)
	player.advance(0.0)
	if reduced_motion or suspended:
		player.seek(0.0 if next in ["idle", "listening", "focused_input", "paused"] else player.get_animation(clip).length * 0.5, true)
		player.pause()
	behavior_started.emit(clip)


func _resolve_clip(name: String) -> String:
	if not is_instance_valid(player):
		return ""
	if player.has_animation(name):
		return name
	var fallback := str(CLIP_FALLBACKS.get(name, "idle"))
	return fallback if player.has_animation(fallback) else ""


func _clip_finished(clip: StringName) -> void:
	behavior_finished.emit(str(clip))
	if str(clip) != current_clip or suspended or focused_input:
		return
	if state in ["explaining", "pointing"] and _audio_audible and _turn_open:
		_transition(state, true)
	elif state == "farewell":
		_transition("idle")
	else:
		point_target_id = ""
		_transition("listening")


func _end_audio(reason: String, request_stop: bool) -> void:
	var previous := active_turn
	var was_active := _turn_open or _audio_state in ["preparing", "playing", "paused"]
	if is_instance_valid(_audio_player):
		_audio_player.stop()
	_audio_player = null
	_audio_turn = ""
	_audio_envelope_provider = Callable()
	_audio_state = "idle"
	_audio_audible = false
	_audio_envelope_available = false
	_audio_envelope = 0.0
	_audio_age = 1000.0
	_close_mouth()
	if request_stop and was_active and not previous.is_empty():
		stop_playback_requested.emit(previous, reason)


func _close_mouth() -> void:
	mouth_mode = "closed"
	for name in MOUTH_SHAPES:
		_mouth_weights[name] = 0.0
		_set_shape(name, 0.0)
	for name in ["JawArticulation", "Neutral"]:
		_mouth_weights[name] = 0.0
		_set_shape(name, 0.0)


func _reset_face() -> void:
	_close_mouth()
	_gaze_angles = Vector2.ZERO
	_eye_angles = Vector2.ZERO
	for lids in _lid_meshes:
		if is_instance_valid(lids):
			lids.visible = false
	for name: String in _shapes:
		if name.begins_with("Look") or name.begins_with("Blink") or name in ["Smile", "Concern"]:
			_set_shape(name, 0.0)


func _set_shape(name: String, value: float) -> void:
	if not _shapes.has(name):
		return
	for target: Dictionary in _shapes[name]:
		var instance := target.mesh as MeshInstance3D
		if is_instance_valid(instance):
			instance.set_blend_shape_value(int(target.index), value)


func _scope_matches(packet: Dictionary) -> bool:
	if not _turn_open or str(packet.get("turn_id", "")) != active_turn:
		return _reject("stale_turn")
	if packet.get("protocol", PROTOCOL_VERSION) != PROTOCOL_VERSION:
		return _reject("unsupported_protocol")
	if str(packet.get("lesson_id", active_lesson)) != active_lesson:
		return _reject("lesson_revision_mismatch")
	var revision: Variant = packet.get("revision", active_revision)
	if not _finite_number(revision) or float(revision) != float(active_revision):
		return _reject("lesson_revision_mismatch")
	if is_instance_valid(registry):
		if registry.get("lesson_id") != active_lesson or registry.get("revision") != active_revision:
			return _reject("lesson_revision_mismatch")
	return true


func _reject(reason: String) -> bool:
	last_rejection = reason
	event_rejected.emit(reason)
	return false


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))


static func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 160 or id != id.strip_edges():
		return false
	for index in range(id.length()):
		if id.unicode_at(index) < 32 or id.unicode_at(index) == 127:
			return false
	return true


func _exit_tree() -> void:
	_end_audio("scene_exit", true)
	_turn_open = false
	unbind_character()
