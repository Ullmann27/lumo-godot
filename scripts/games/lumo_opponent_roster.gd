extends RefCounted
## Shared reference identities, not an alternative race or reward system.
## Missing/unvalidated rigs never silently replace an existing animated driver.

const PATH := "res://assets/characters/rivals/roster.json"
static var _cache: Array[Dictionary] = []


static func all() -> Array[Dictionary]:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not parsed is Dictionary or parsed.get("schemaVersion") != 1:
			push_error("Invalid Lumo opponent roster schema.")
			return []
		var rows: Variant = parsed.get("opponents", [])
		if not rows is Array or rows.is_empty():
			push_error("Missing Lumo opponent identities.")
			return []
		var ids: Dictionary = {}
		var entries: Array[Dictionary] = []
		for row in rows:
			if not row is Dictionary or str(row.get("id", "")).is_empty() or not row.get("games") is Array:
				push_error("Invalid Lumo opponent identity.")
				return []
			var id: String = str(row.id)
			if ids.has(id):
				push_error("Duplicate Lumo opponent identity: " + id)
				return []
			ids[id] = true
			var entry: Dictionary = row.duplicate(true)
			entry["games"].make_read_only()
			entry.make_read_only()
			entries.append(entry)
		entries.make_read_only()
		_cache = entries
	return _cache


static func for_game(game: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in all():
		if game in entry.get("games", []):
			result.append(entry)
	return result


static func rotation(game: String, round_index: int = 0) -> Array[Dictionary]:
	var entries := for_game(game)
	if entries.is_empty():
		return []
	var result: Array[Dictionary] = []
	var offset: int = posmod(round_index, entries.size())
	for index in range(entries.size()):
		result.append(entries[(index + offset) % entries.size()])
	return result


static func can_use_racing_model(id: String) -> bool:
	for entry in all():
		if str(entry.id) == id:
			return bool(entry.get("runtimeReady", false)) and ResourceLoader.exists(str(entry.get("godotModel", "")))
	return false


static func ready_for_race() -> bool:
	var entries := for_game("kart")
	if entries.size() != 5:
		return false
	for entry in entries:
		if not can_use_racing_model(str(entry.id)):
			return false
	return true
