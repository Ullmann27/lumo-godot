extends Node
## In-process Android host; desktop and separate Godot exports remain playable.

signal returned(destination: String, payload: Dictionary)
signal reward_reported(payload: Dictionary)

var _host: Object
var _options: Dictionary = {}
var _result_ids: Dictionary = {}
var _return_pending: bool = false


func _ready() -> void:
	if Engine.has_singleton("LumoHost"):
		_host = Engine.get_singleton("LumoHost")
		var parsed = JSON.parse_string(str(_host.call("getLaunchOptions")))
		if parsed is Dictionary:
			_options = validated_options(parsed)
		else:
			push_warning("[LumoHost] launch options are not valid JSON")


func is_embedded() -> bool:
	return is_instance_valid(_host)


static func validated_options(raw: Dictionary) -> Dictionary:
	var options: Dictionary = raw.duplicate(true)
	options["grade"] = clampi(int(raw.get("grade", 1)), 1, 4)
	options["stars"] = maxi(0, int(raw.get("stars", 0)))
	options["scene"] = str(raw.get("game", raw.get("scene", "kart")))
	if options["scene"] not in ["kart", "jump", "games", "home"]:
		options["scene"] = "kart"
	if (
		str(raw.get("subject", "Mathematik"))
		not in ["Mathematik", "Deutsch", "Sachunterricht", "Logik"]
	):
		options["subject"] = "Mathematik"
	return options


func launch_options() -> Dictionary:
	return _options.duplicate(true)


func new_result_id() -> String:
	# OS epoch plus monotonic microseconds also distinguishes quick restarts.
	return (
		"%s-%d-%d"
		% [
			str(_options.get("sessionId", "standalone")),
			int(Time.get_unix_time_from_system() * 1000),
			Time.get_ticks_usec()
		]
	)


func reward(payload: Dictionary) -> bool:
	var result_id: String = str(payload.get("resultId", ""))
	if result_id.is_empty():
		return false
	if _result_ids.has(result_id):
		return true
	if is_embedded():
		var accepted = _host.call("reward", JSON.stringify(payload))
		if accepted != true:
			push_warning("[LumoHost] reward not saved; retry on return: %s" % result_id)
			return false
		print("[LumoHost] reward reported: %s" % result_id)
	_result_ids[result_id] = true
	reward_reported.emit(payload.duplicate(true))
	return true


func return_to_app(destination: String, payload: Dictionary = {}) -> bool:
	if not is_embedded():
		return false
	if _return_pending:
		return true
	_return_pending = true
	var target: String = "learn" if destination == "learn" else "games"
	var result: Dictionary = payload.duplicate(true)
	result["sessionId"] = str(_options.get("sessionId", ""))
	_host.call("returnToApp", target, JSON.stringify(result))
	returned.emit(target, result)
	print("[LumoHost] return: %s" % target)
	return true
