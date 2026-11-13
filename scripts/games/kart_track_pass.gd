extends RefCounted
## Optional, additive race mastery. Existing stars, unlocks, ghosts and saves
## are never migrated or rewritten. A child owns one separate atomic file.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const VERSION := 1
var child_key: String
var stages: Dictionary = {}
var accepted_results: Array[String] = []
var save_enabled := true
var _compatible_save := true


func _init(child: String = "standalone") -> void:
	child_key = child if not child.is_empty() else "standalone"
	_load()


static func path_for(child: String) -> String:
	var identity := child if not child.is_empty() else "standalone"
	return "user://kart_track_pass_%s.cfg" % identity.sha256_text()


func path() -> String:
	return path_for(child_key)


func stage(track: String, difficulty: String) -> int:
	return int(stages.get(_key(track, difficulty), 0))


func total(difficulty: String) -> int:
	var count := 0
	for track in CATALOG.TRACKS:
		count += stage(str(track.id), difficulty)
	return count


static func goal_text(level: int) -> String:
	match clampi(level, 0, 3):
		0: return "Fahre zwei Runden ins Ziel"
		1: return "Erreiche einen Podiumsplatz"
		2: return "Siege ohne Zurücksetzen"
		_: return "Alle drei Ziele geschafft"


func complete(result: Dictionary, race_distance: float, track_length: float) -> Dictionary:
	var track := str(result.get("track", ""))
	var difficulty := str(result.get("difficulty", ""))
	var before := stage(track, difficulty)
	var answer := {"stage": before, "previous": before, "advanced": false, "saved": true, "eligible": false}
	var id := str(result.get("resultId", ""))
	if not _known(track, difficulty) or str(result.get("mode", "")) not in ["race", "cup"]:
		return answer
	if str(result.get("status", "")) != "completed" or id.is_empty() or id.length() > 256:
		return answer
	for field in ["checkpoints", "place", "resets"]:
		if typeof(result.get(field)) != TYPE_INT:
			return answer
	var place := int(result.place)
	var resets := int(result.resets)
	var elapsed: Variant = result.get("elapsedSeconds")
	if typeof(elapsed) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(elapsed)) or float(elapsed) <= 0.0:
		return answer
	if int(result.checkpoints) < 16 or place < 1 or place > 6 or resets < 0:
		return answer
	if not is_finite(race_distance) or not is_finite(track_length) or track_length <= 10.0 or race_distance < track_length * 2.0:
		return answer
	answer.eligible = true
	if accepted_results.has(id):
		return answer
	# A strong first race can satisfy every nested objective. No artificial
	# repeat requirement, paid unlock, bonus stars or difficulty penalty.
	var achieved := 1
	if place <= 3:
		achieved = 2
	if place == 1 and resets == 0:
		achieved = 3
	var next_stages := stages.duplicate(true)
	next_stages[_key(track, difficulty)] = maxi(before, achieved)
	var next_ids: Array[String] = accepted_results.duplicate()
	next_ids.append(id)
	if next_ids.size() > 256:
		next_ids.pop_front()
	if not _save(next_stages, next_ids):
		answer.saved = false
		return answer
	stages = next_stages
	accepted_results = next_ids
	answer.stage = stage(track, difficulty)
	answer.advanced = int(answer.stage) > before
	return answer


static func _key(track: String, difficulty: String) -> String:
	return track + "/" + difficulty


static func _known(track: String, difficulty: String) -> bool:
	var track_known := false
	var difficulty_known := false
	for entry in CATALOG.TRACKS:
		track_known = track_known or str(entry.id) == track
	for entry in CATALOG.DIFFICULTIES:
		difficulty_known = difficulty_known or str(entry.id) == difficulty
	return track_known and difficulty_known


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(path()) != OK:
		_compatible_save = not FileAccess.file_exists(path())
		return
	var version: Variant = config.get_value("meta", "version", 0)
	if typeof(version) != TYPE_INT or version != VERSION:
		_compatible_save = false
		return
	if str(config.get_value("meta", "owner", "")) != child_key.sha256_text():
		_compatible_save = false
		return
	for track in CATALOG.TRACKS:
		for difficulty in CATALOG.DIFFICULTIES:
			var key := _key(str(track.id), str(difficulty.id))
			var level: Variant = config.get_value("stages", key, 0)
			if typeof(level) == TYPE_INT and level >= 0 and level <= 3:
				stages[key] = level
	var ids: Variant = config.get_value("meta", "accepted_results", [])
	if ids is Array and ids.size() <= 256:
		for id in ids:
			if typeof(id) == TYPE_STRING and not id.is_empty() and id.length() <= 256:
				accepted_results.append(id)


func _save(next_stages: Dictionary, next_ids: Array[String]) -> bool:
	if not save_enabled or not _compatible_save:
		return false
	var config := ConfigFile.new()
	config.set_value("meta", "version", VERSION)
	config.set_value("meta", "owner", child_key.sha256_text())
	config.set_value("meta", "accepted_results", next_ids)
	for key in next_stages:
		config.set_value("stages", key, next_stages[key])
	if config.save(path() + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(path() + ".tmp", path()) == OK
