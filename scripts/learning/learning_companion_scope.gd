extends RefCounted
## Additive v1 identity for the existing learning scene. This object grants no
## reward, answer evaluation or arbitrary scene mutation to a conversation.
const VERSION: int = 1
const REQUESTS: Array[String] = [
	"explain", "repeat", "slower", "hint", "highlight", "point", "look", "stop", "proposeAnswer"
]
const ID_LIMIT: int = 192
var session_id: String = ""
var task_id: String = ""
var revision: int = 0
var cancel_epoch: int = 0
var step_id: String = "start"
var object_ids: Array[String] = []
var valid: bool = false
var allowed_actions: Array[String] = ["stop"]


func configure(raw: Dictionary, fallback_session: String, fallback_task: String) -> bool:
	valid = false
	allowed_actions.assign(["stop"])
	var supplied: Variant = raw.get("scope", raw)
	if not supplied is Dictionary:
		return false
	var wire: Dictionary = supplied
	# Legacy, checked illustration payloads remain supported. Unknown explicit
	# protocol versions fail closed instead of being relabelled as version 1.
	if wire.has("protocolVersion") and not _integer(wire.protocolVersion, VERSION, VERSION):
		return false
	var session: Variant = wire.get("sessionId", fallback_session)
	var task: Variant = wire.get("taskId", fallback_task)
	var rev: Variant = wire.get("revision", 0)
	var epoch: Variant = wire.get("cancelEpoch", 0)
	var step: Variant = wire.get("stepId", "start")
	if not _identifier(session) or not _identifier(task) or not _identifier(step):
		return false
	if not _integer(rev, 0, 2147483646) or not _integer(epoch, 0, 2147483646):
		return false
	var supplied_actions: Variant = wire.get("allowedActions", ["stop"])
	if not supplied_actions is Array:
		return false
	for action in supplied_actions:
		if not action is String or action not in REQUESTS:
			return false
		if action not in allowed_actions:
			allowed_actions.append(action)
	session_id = session
	task_id = task
	revision = int(rev)
	cancel_epoch = int(epoch)
	step_id = step
	valid = true
	return true


func envelope(turn: int = 0, utterance: String = "") -> Dictionary:
	var result := {
		"protocolVersion": VERSION,
		"sessionId": session_id,
		"taskId": task_id,
		"revision": revision,
		"cancelEpoch": cancel_epoch,
		"stepId": step_id,
	}
	if turn > 0:
		result["turnId"] = turn
	if not utterance.is_empty():
		result["utteranceId"] = utterance
	return result


func matches(wire: Dictionary) -> bool:
	return (
		valid
		and (
			_integer(wire.get("protocolVersion"), VERSION, VERSION)
			and wire.get("sessionId") == session_id
			and wire.get("taskId") == task_id
			and _integer(wire.get("revision"), revision, revision)
			and _integer(wire.get("cancelEpoch"), cancel_epoch, cancel_epoch)
			and (not wire.has("stepId") or wire.stepId == step_id)
		)
	)


func advance(next_step: String) -> void:
	if not valid or not _identifier(next_step):
		return
	revision += 1
	step_id = next_step


func cancel() -> void:
	cancel_epoch += 1


func permits_reply(wire: Dictionary, turn: int) -> bool:
	if not matches(wire) or wire.get("turnId") != turn or turn <= 0:
		return false
	var action: Variant = wire.get("action", "explain")
	if not action is String or action not in allowed_actions:
		return false
	var object_id: Variant = wire.get("objectId", "")
	if not object_id is String:
		return false
	if action in ["point", "look", "highlight"] and object_id.is_empty():
		return false
	return object_id.is_empty() or object_id in object_ids


static func _identifier(value: Variant) -> bool:
	return (
		value is String
		and not value.is_empty()
		and value.length() <= ID_LIMIT
		and value.strip_edges() == value
	)


static func _integer(value: Variant, low: int, high: int) -> bool:
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value))
		and float(value) == floorf(float(value))
		and float(value) >= low
		and float(value) <= high
	)
