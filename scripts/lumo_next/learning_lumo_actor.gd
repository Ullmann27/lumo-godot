extends Node3D
## Learning-only adapter. The original shared Kart/Jump actor remains intact.
const DIRECTOR = preload("res://scripts/lumo_next/avatar_director.gd")
const REGISTRY = preload("res://scripts/lumo_next/learning_target_registry.gd")
const MODEL := "res://assets/lumo_next/character/Lumo-Learning.glb"
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var director: Node
var registry: Node
var model_load_kind := ""
var current_behavior := "idle"
var mouth_supported := false
var phoneme_lipsync_supported := false
var reduced_motion := false
var suspended := false
var focused_input := false
var audio_active := false
var last_audio_position := 0.0
var last_audio_envelope := 0.0
var _turn := "learning-idle"
var _lesson := "learning"
var _revision := 0
var _target_id := ""
var _turn_serial := 0
var _audio_id := ""
var _native_utterance_id := ""
var _interaction: Dictionary = {}
var _speaking := false


func _ready() -> void:
	registry = REGISTRY.new()
	add_child(registry)
	if not ResourceLoader.exists(MODEL, "PackedScene"):
		push_error("[LumoLearning] Import the production GLB before starting the lesson")
		return
	var packed := load(MODEL) as PackedScene
	if packed == null:
		return
	visual = packed.instantiate() as Node3D
	add_child(visual)
	for node in visual.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		player = node
	if skeleton == null or player == null:
		push_error("[LumoLearning] Export is missing the skeleton or animation library")
		return
	director = DIRECTOR.new()
	add_child(director)
	if not director.bind_character(visual, registry):
		push_error("[LumoLearning] Avatar director could not bind the exported rig")
		return
	model_load_kind = "imported_packed_scene"
	mouth_supported = true
	begin_lesson(_lesson, _revision)
	play_behavior("idle")


func is_usable() -> bool:
	return is_instance_valid(director) and not model_load_kind.is_empty()


func begin_lesson(lesson_id: String, revision: int) -> void:
	_lesson = lesson_id
	_revision = revision
	_target_id = ""
	_native_utterance_id = ""
	registry.begin_lesson(lesson_id, revision)
	if is_instance_valid(director):
		_new_idle_turn()


func begin_audio_turn(turn: String, audio_id: String = "", cues: Array = [], cue_source: String = "aligned_audio") -> void:
	if not is_usable():
		return
	_turn = _lesson + ":" + str(_revision) + ":audio:" + turn
	_audio_id = audio_id if not audio_id.is_empty() else _turn
	_native_utterance_id = turn
	if not director.begin_turn(_turn, _lesson, _revision):
		return
	if not cues.is_empty() and director.has_method("set_mouth_cues"):
		director.set_mouth_cues(_turn, _audio_id, cues, cue_source)
	_emit("thinking")


func _emit(kind: String, extra: Dictionary = {}) -> bool:
	if not is_usable():
		return false
	if not bool(director.diagnostics().get("turn_open", false)):
		if not _new_idle_turn():
			return false
	var event := {"type": kind, "turn_id": _turn, "lesson_id": _lesson, "revision": _revision}
	if not _target_id.is_empty():
		event["target_id"] = _target_id
	event.merge(extra, true)
	return bool(director.handle_event(event))


func _new_idle_turn() -> bool:
	if not is_usable() or suspended or focused_input:
		return false
	_turn_serial += 1
	_turn = _lesson + ":" + str(_revision) + ":idle:" + str(_turn_serial)
	_audio_id = ""
	return bool(director.begin_turn(_turn, _lesson, _revision))


func set_teaching_target_id(identifier: String) -> void:
	_target_id = identifier
	if not focused_input and not suspended:
		_emit("point", {"target_id": identifier})


func set_teaching_target(world_position: Vector3) -> void:
	# Legacy callers pass a world position. Resolve it to a registered object;
	# no viewport coordinates or unowned moving pointer are stored in the rig.
	if not is_instance_valid(registry):
		return
	var closest := ""
	var distance := INF
	for identifier in registry.target_ids():
		var point: Variant = registry.world_target(identifier)
		if point is Vector3 and point.distance_squared_to(world_position) < distance:
			distance = point.distance_squared_to(world_position)
			closest = identifier
	if not closest.is_empty():
		set_teaching_target_id(closest)


func teacher_react(reaction: String) -> bool:
	var events := {"welcome": "greeting", "correct": "nod", "celebrate": "celebrate", "encourage": "encourage", "explain": "explain", "idle": "listening"}
	current_behavior = reaction
	return _emit(str(events.get(reaction, reaction)))


func play_behavior(behavior: String) -> bool:
	var events := {"idle": "listening", "greeting_wave": "greeting", "agree_nod": "nod", "point_portal": "point", "celebrate_step": "celebrate"}
	current_behavior = behavior
	return _emit(str(events.get(behavior, behavior)))


func set_teacher_speaking(active: bool) -> void:
	var now_speaking := active and not suspended and not focused_input
	if now_speaking and not _speaking:
		_emit("explain")
	_speaking = now_speaking
	audio_active = _speaking


func apply_speech_sample(position_seconds: float, envelope: float, active: bool) -> bool:
	if not is_usable():
		return false
	last_audio_position = maxf(0.0, position_seconds)
	last_audio_envelope = clampf(envelope, 0.0, 1.0) if active else 0.0
	audio_active = _speaking and not suspended and not focused_input
	return bool(director.push_playback_sample({"turn_id": _turn, "audio_id": _audio_id, "position_ms": last_audio_position * 1000.0, "state": "playing" if audio_active else "paused", "audible": audio_active, "envelope": last_audio_envelope, "envelope_available": active and audio_active}))


func apply_playback_status(status: Dictionary) -> bool:
	if not is_usable():
		return false
	# Never relabel an unscoped or older host callback as the current turn.
	if _native_utterance_id.is_empty() or str(status.get("id", "")) != _native_utterance_id:
		return false
	if status.has("turn_id") and status.turn_id != _turn:
		return false
	var sample := status.duplicate(true)
	sample["turn_id"] = _turn
	sample["audio_id"] = _audio_id
	return bool(director.push_playback_sample(sample))


func interrupt(reason: String = "interrupted", _epoch: int = -1) -> void:
	audio_active = false
	_speaking = false
	last_audio_envelope = 0.0
	_target_id = ""
	_native_utterance_id = ""
	if is_usable():
		director.interrupt(reason)
		if _new_idle_turn():
			_emit("listening")


func set_focused_input(value: bool) -> void:
	if focused_input == value:
		return
	focused_input = value
	if value:
		audio_active = false
		_speaking = false
		last_audio_envelope = 0.0
		_target_id = ""
	if is_usable():
		director.set_focused_input(value)
		if not value and _new_idle_turn():
			_emit("listening")


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if is_usable() and director.has_method("set_reduced_motion"):
		director.set_reduced_motion(value)


func set_suspended(value: bool) -> void:
	if suspended == value:
		return
	suspended = value
	if value:
		audio_active = false
		_speaking = false
		last_audio_envelope = 0.0
		_target_id = ""
	if is_usable():
		director.set_suspended(value)
		if not value and _new_idle_turn():
			_emit("listening")


func apply_avatar_event(event: Dictionary) -> bool:
	if not is_usable():
		return false
	return bool(director.handle_event(event))


## Bind the task-owner envelope before accepting external speech proposals.
## This adapter changes presentation only: it never scores or awards anything.
func bind_interaction_context(context: Dictionary) -> bool:
	if not _valid_context(context):
		return false
	interrupt("context_changed")
	_interaction = context.duplicate(true)
	begin_lesson(str(context.sessionId) + "/" + str(context.taskId), int(context.revision))
	return true


func apply_interaction_event(event: Dictionary) -> bool:
	if _interaction.is_empty() or not _valid_context(event):
		return false
	for key in ["sessionId", "taskId", "revision", "contextRevision", "cancelEpoch"]:
		if event.get(key) != _interaction.get(key):
			return false
	var event_type := str(event.get("type", ""))
	if event_type in ["stop", "interrupt"]:
		interrupt("host_stop", int(event.cancelEpoch))
		_interaction["cancelEpoch"] = int(event.cancelEpoch) + 1
		return true
	var allowed := {"listening": "listening", "thinking": "thinking", "explain": "explain", "focusObject": "point", "point": "point", "focused_input": "focused_input", "encourage": "encourage", "celebrate": "celebrate", "greeting": "greeting", "farewell": "farewell"}
	if not allowed.has(event_type) or suspended or focused_input:
		return false
	var id := str(event.get("turnId", "")) + "/" + str(event.cancelEpoch)
	if str(event.get("turnId", "")).is_empty():
		return false
	if director.active_turn != id:
		if not director.begin_turn(id, _lesson, _revision):
			return false
		_turn = id
	var translated := {"type": allowed[event_type], "turn_id": id, "lesson_id": _lesson, "revision": _revision}
	var target := str(event.get("target_id", event.get("targetId", "")))
	if not target.is_empty():
		translated["target_id"] = target
	return bool(director.handle_event(translated))


static func _valid_context(value: Dictionary) -> bool:
	if value.get("schema") != "lumo.learning.interaction" or value.get("version") != 1:
		return false
	for key in ["sessionId", "taskId"]:
		if not value.get(key) is String or str(value[key]).is_empty():
			return false
	for key in ["revision", "contextRevision", "cancelEpoch"]:
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or float(number) < 0.0 or float(number) != floorf(float(number)):
			return false
	return true
