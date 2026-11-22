extends RefCounted
## Fortschritt im Abenteuer-Parcours je Kind (eigene Datei je childKey, wie der Streckenpass):
## geschaffte Welten, Bestzeit, meiste Sterne, gefundene Geheimwege, gebuchte Ergebnis-IDs.
## Der Spielstand zum Fortsetzen liegt ebenfalls je Kind in einer eigenen Datei.

const VERSION: int = 1
var child_key: String = "standalone"
var worlds: Dictionary = {}
var accepted: Array[String] = []


func _init(child: String = "standalone") -> void:
	child_key = child if not child.is_empty() else "standalone"
	_load()


static func path_for(child: String) -> String:
	return (
		"user://kart_parcours_%s.cfg"
		% (child if not child.is_empty() else "standalone").sha256_text()
	)


static func session_path_for(child: String) -> String:
	var identity: String = child if not child.is_empty() else "standalone"
	return "user://kart_parcours_session_%s.cfg" % identity.sha256_text()


func session_path() -> String:
	return session_path_for(child_key)


func world(world_id: String) -> Dictionary:
	return worlds.get(
		world_id, {"completed": 0, "best_time": 0.0, "best_stars": 0, "secrets": [], "explored": 0}
	)


## Ergebnis eines Laufs übernehmen. Jede Ergebnis-ID zählt genau einmal.
func record(result: Dictionary) -> Dictionary:
	var id: String = str(result.get("resultId", ""))
	var world_id: String = str(result.get("world", ""))
	var entry: Dictionary = world(world_id).duplicate(true)
	var answer := {"new_best": false, "first": int(entry.completed) == 0, "counted": false}
	if id.is_empty() or accepted.has(id) or str(result.get("status", "")) != "completed":
		return answer
	accepted.append(id)
	if accepted.size() > 64:
		accepted = accepted.slice(accepted.size() - 64)
	answer.counted = true
	entry.completed = int(entry.completed) + 1
	var seconds: float = float(result.get("elapsedSeconds", 0.0))
	if str(result.get("style", "")) == "zeitlauf":
		if float(entry.best_time) <= 0.0 or seconds < float(entry.best_time):
			answer.new_best = float(entry.best_time) > 0.0
			entry.best_time = seconds
	elif str(result.get("style", "")) == "rennen":
		entry.races = int(entry.get("races", 0)) + 1
		entry.best_place = mini(int(entry.get("best_place", 3)), int(result.get("place", 3)))
	else:
		entry.explored = int(entry.explored) + 1
	entry.best_stars = maxi(int(entry.best_stars), int(result.get("starTokens", 0)))
	var secrets: Array = entry.secrets
	for secret in result.get("secrets", []):
		if not secrets.has(str(secret)):
			secrets.append(str(secret))
	entry.secrets = secrets
	worlds[world_id] = entry
	save()
	return answer


func save() -> bool:
	var config := ConfigFile.new()
	config.set_value("parcours", "version", VERSION)
	config.set_value("parcours", "worlds", worlds)
	config.set_value("parcours", "accepted", accepted)
	var path: String = path_for(child_key)
	if config.save(path + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(path_for(child_key)) != OK:
		return
	if int(config.get_value("parcours", "version", 0)) != VERSION:
		return
	var stored: Variant = config.get_value("parcours", "worlds", {})
	if stored is Dictionary:
		worlds = (stored as Dictionary).duplicate(true)
	for id in config.get_value("parcours", "accepted", []):
		accepted.append(str(id))


func save_session(data: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value("session", "version", VERSION)
	config.set_value("session", "data", data)
	var path: String = session_path()
	if config.save(path + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


func load_session() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(session_path()) != OK:
		return {}
	if int(config.get_value("session", "version", 0)) != VERSION:
		return {}
	var data: Variant = config.get_value("session", "data", {})
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func clear_session() -> void:
	DirAccess.remove_absolute(session_path())
