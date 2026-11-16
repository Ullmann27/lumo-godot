extends Node3D
# gdlint: disable=max-returns
# Fail-closed wire validation intentionally uses one guard per independent field.
## Learning-only adapter. The original shared Kart/Jump actor remains intact.
const DIRECTOR = preload("res://scripts/lumo_next/avatar_director.gd")
const REGISTRY = preload("res://scripts/lumo_next/learning_target_registry.gd")
const MODEL := "res://assets/lumo_next/character/Lumo-Learning.glb"
const MAX_SEQUENCE := 2147483646
const ACTIONS: Array[String] = [
	"explain", "repeat", "slower", "hint", "highlight", "point", "look", "stop", "proposeAnswer"
]
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
var _audio_owner: Dictionary = {}
var _allowed_actions: Array[String] = ["stop"]
var _owner_serial := 0
var _highest_interaction_turn := 0
var _active_interaction_turn := 0


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
	director.stop_playback_requested.connect(_playback_stopped)
	begin_lesson(_lesson, _revision)
	play_behavior("idle")


func is_usable() -> bool:
	return is_instance_valid(director) and not model_load_kind.is_empty()


func begin_lesson(lesson_id: String, revision: int) -> bool:
	if not is_usable() or not registry.begin_lesson(lesson_id, revision):
		return false
	_lesson = lesson_id
	_revision = revision
	_target_id = ""
	_clear_audio_binding()
	if is_instance_valid(director) and _new_idle_turn():
		_emit("listening")
	return true


func can_begin_audio_turn(scope: Dictionary = {}) -> bool:
	if not is_usable() or suspended or focused_input:
		return false
	if not scope.is_empty() and not interaction_context_matches(scope):
		return false
	if scope.has("turnId"):
		if not _integer(scope.turnId, 1, MAX_SEQUENCE):
			return false
		var number := int(scope.turnId)
		if number < _highest_interaction_turn:
			return false
		if number == _highest_interaction_turn and number != _active_interaction_turn:
			return false
	return true


func begin_audio_turn(
	turn: String,
	audio_id: String = "",
	cues: Array = [],
	cue_source: String = "aligned_audio",
	scope: Dictionary = {}
) -> bool:
	var identifier := _native_id(turn)
	if identifier.is_empty() or not can_begin_audio_turn(scope):
		return false
	var next_turn := "owner:%d/audio:%s" % [_owner_serial, identifier]
	if not director.begin_turn(next_turn, _lesson, _revision):
		return false
	_turn = next_turn
	_audio_id = audio_id if not audio_id.is_empty() else next_turn
	_native_utterance_id = identifier
	_audio_owner = _interaction.duplicate(true)
	_speaking = false
	audio_active = false
	_active_interaction_turn = int(scope.get("turnId", 0))
	_highest_interaction_turn = maxi(_highest_interaction_turn, _active_interaction_turn)
	if not cues.is_empty() and director.has_method("set_mouth_cues"):
		if not director.set_mouth_cues(_turn, _audio_id, cues, cue_source):
			interrupt("invalid_mouth_cues")
			return false
	director.push_playback_sample(
		{
			"turn_id": _turn,
			"audio_id": _audio_id,
			"position_ms": 0.0,
			"state": "preparing",
			"audible": false,
			"envelope_available": false,
			"envelope": 0.0
		}
	)
	_emit("thinking")
	return true


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
	_turn = "owner:%d/idle:%d" % [_owner_serial, _turn_serial]
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
	var events := {
		"welcome": "greeting",
		"correct": "nod",
		"celebrate": "celebrate",
		"encourage": "encourage",
		"explain": "explain",
		"idle": "listening"
	}
	current_behavior = reaction
	return _emit(str(events.get(reaction, reaction)))


func play_behavior(behavior: String) -> bool:
	var events := {
		"idle": "listening",
		"greeting_wave": "greeting",
		"agree_nod": "nod",
		"point_portal": "point",
		"celebrate_step": "celebrate"
	}
	current_behavior = behavior
	return _emit(str(events.get(behavior, behavior)))


func set_teacher_speaking(active: bool) -> void:
	var now_speaking := active and _owns_audio() and not suspended and not focused_input
	if now_speaking and not _speaking:
		_emit("explain")
	_speaking = now_speaking
	audio_active = _speaking


func apply_speech_sample(position_seconds: float, envelope: float, active: bool) -> bool:
	if not is_usable() or not _owns_audio():
		return false
	last_audio_position = maxf(0.0, position_seconds)
	last_audio_envelope = clampf(envelope, 0.0, 1.0) if active else 0.0
	audio_active = _speaking and not suspended and not focused_input
	return bool(
		director.push_playback_sample(
			{
				"turn_id": _turn,
				"audio_id": _audio_id,
				"position_ms": last_audio_position * 1000.0,
				"state": "playing" if audio_active else "paused",
				"audible": audio_active,
				"envelope": last_audio_envelope,
				"envelope_available": active and audio_active
			}
		)
	)


func apply_playback_status(status: Dictionary) -> bool:
	if not is_usable() or not _owns_audio():
		return false
	# Never relabel an unscoped or older host callback as the current turn.
	if _native_id(status.get("id")) != _native_utterance_id:
		return false
	if status.has("protocolVersion") and not interaction_context_matches(status):
		return false
	if (
		status.has("turnId")
		and (
			not _integer(status.turnId, 1, MAX_SEQUENCE)
			or int(status.turnId) != _active_interaction_turn
		)
	):
		return false
	if status.has("turn_id") and status.turn_id != _turn:
		return false
	if (
		not status.get("audible", false) is bool
		or not status.get("envelopeAvailable", false) is bool
	):
		return false
	var sample := status.duplicate(true)
	sample["turn_id"] = _turn
	sample["audio_id"] = _audio_id
	if not director.push_playback_sample(sample):
		return false
	last_audio_position = float(status.get("positionMs", status.get("position_ms", 0.0))) / 1000.0
	last_audio_envelope = float(status.get("envelope", 0.0))
	var state_value := str(status.get("state", "idle"))
	if state_value in ["completed", "unavailable", "idle"]:
		_clear_audio_binding()
	else:
		set_teacher_speaking(state_value == "playing" and status.get("audible", false) == true)
	return true


func stop_audio_turn(reason: String = "speech_stopped") -> void:
	if not _native_utterance_id.is_empty():
		interrupt(reason)


func _owns_audio() -> bool:
	if _native_utterance_id.is_empty() or not is_usable() or not director.diagnostics().turn_open:
		return false
	return _audio_owner == _interaction


func _clear_audio_binding() -> void:
	_native_utterance_id = ""
	_audio_owner.clear()
	_audio_id = ""
	_speaking = false
	audio_active = false
	last_audio_envelope = 0.0


func _playback_stopped(turn: String, _reason: String) -> void:
	if turn == _turn:
		_clear_audio_binding()
		_target_id = ""


func interrupt(reason: String = "interrupted", _epoch: int = -1) -> void:
	_clear_audio_binding()
	_target_id = ""
	if is_usable():
		director.interrupt(reason)
		if _new_idle_turn():
			_emit("listening")


func set_focused_input(value: bool) -> void:
	if focused_input == value:
		return
	focused_input = value
	if value:
		_clear_audio_binding()
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
		_clear_audio_binding()
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
	if not is_usable():
		return false
	var identity := _canonical_identity(context)
	var actions: Variant = context.get("allowedActions", ["stop"])
	if identity.is_empty() or not actions is Array:
		return false
	var checked_actions: Array[String] = ["stop"]
	for action: Variant in actions:
		if not action is String or action not in ACTIONS:
			return false
		if action not in checked_actions:
			checked_actions.append(action)
	if identity == _interaction:
		_allowed_actions = checked_actions
		return true
	if (
		not _interaction.is_empty()
		and identity.sessionId == _interaction.sessionId
		and identity.taskId == _interaction.taskId
	):
		if (
			identity.revision < _interaction.revision
			or (
				identity.revision == _interaction.revision
				and identity.cancelEpoch < _interaction.cancelEpoch
			)
		):
			return false
	interrupt("context_changed")
	_interaction = identity
	_allowed_actions = checked_actions
	_owner_serial += 1
	_highest_interaction_turn = 0
	_active_interaction_turn = 0
	return begin_lesson(
		str(identity.sessionId) + "/" + str(identity.taskId), int(identity.revision)
	)


func interaction_context_matches(context: Dictionary) -> bool:
	var identity := _canonical_identity(context)
	return not identity.is_empty() and identity == _interaction


func apply_interaction_event(event: Dictionary) -> bool:
	if not interaction_context_matches(event):
		return false
	var action: Variant = event.get("action")
	if not action is String or action not in _allowed_actions:
		return false
	var number := 0
	if event.has("turnId"):
		if not _integer(event.turnId, 1, MAX_SEQUENCE):
			return false
		number = int(event.turnId)
		if number < _highest_interaction_turn:
			return false
	if action == "stop":
		interrupt("host_stop")
		_interaction["cancelEpoch"] = int(_interaction.cancelEpoch) + 1
		_owner_serial += 1
		_highest_interaction_turn = 0
		_active_interaction_turn = 0
		return true
	var presentation := {
		"explain": "explain",
		"repeat": "explain",
		"slower": "explain",
		"hint": "explain",
		"point": "point",
		"highlight": "point",
		"look": "listening"
	}
	if number <= 0 or not presentation.has(action) or suspended or focused_input:
		return false
	var target: Variant = event.get("objectId", "")
	if not target is String or (action in ["point", "highlight", "look"] and target.is_empty()):
		return false
	if not target.is_empty() and not director.can_target(target):
		return false
	if number == _highest_interaction_turn:
		if number != _active_interaction_turn or not director.diagnostics().turn_open:
			return false
	else:
		var id := "owner:%d/interaction:%d" % [_owner_serial, number]
		if not director.begin_turn(id, _lesson, _revision):
			return false
		_clear_audio_binding()
		_turn = id
		_highest_interaction_turn = number
		_active_interaction_turn = number
	var translated := {
		"type": presentation[action], "turn_id": _turn, "lesson_id": _lesson, "revision": _revision
	}
	if not target.is_empty():
		translated["target_id"] = target
	return bool(director.handle_event(translated))


static func _canonical_identity(value: Dictionary) -> Dictionary:
	if not _integer(value.get("protocolVersion"), 1, 1):
		return {}
	for key in ["sessionId", "taskId"]:
		if not _identifier(value.get(key)):
			return {}
	for key in ["revision", "cancelEpoch"]:
		if not _integer(value.get(key), 0, MAX_SEQUENCE):
			return {}
	var step: Variant = value.get("stepId")
	if step != null and not _identifier(step):
		return {}
	return {
		"protocolVersion": 1,
		"sessionId": value.sessionId,
		"taskId": value.taskId,
		"revision": int(value.revision),
		"cancelEpoch": int(value.cancelEpoch),
		"stepId": step
	}


static func _identifier(value: Variant) -> bool:
	if (
		not value is String
		or value.is_empty()
		or value.length() > 192
		or value.strip_edges() != value
	):
		return false
	for index in range(value.length()):
		var point: int = value.unicode_at(index)
		if point < 32 or (point >= 127 and point <= 159):
			return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value))
		and float(value) == floorf(float(value))
		and float(value) >= minimum
		and float(value) <= maximum
	)


static func _native_id(value: Variant) -> String:
	if _integer(value, 1, MAX_SEQUENCE):
		return str(int(value))
	if (
		value is String
		and value.is_valid_int()
		and _integer(value.to_int(), 1, MAX_SEQUENCE)
		and str(value.to_int()) == value
	):
		return value
	return ""
