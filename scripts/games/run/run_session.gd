extends RefCounted
## Save file of an unfinished run (state at the last checkpoint) and the best
## results per course. Everything read from disk is checked against the current
## course plan before it is used; anything doubtful is ignored, never repaired.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const VERSION: int = 1
const SECTION: String = "run"
const RECORDS: String = "user://run_records.cfg"
const MAX_ELAPSED_MS: int = 6 * 60 * 60 * 1000
## First line of every file: a checksum over the rest. A damaged, truncated or
## foreign file is recognised before the engine parser ever reads it.
const SEAL: String = "; lumo-run sha256="


static func _sha256_hex(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		hashing.update(bytes)
	return hashing.finish().hex_encode()


## Writes [param config] behind its checksum line. False when the disk refuses.
static func write_sealed(path: String, config: ConfigFile) -> bool:
	var body: PackedByteArray = config.encode_to_text().to_utf8_buffer()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer((SEAL + _sha256_hex(body) + "\n").to_utf8_buffer())
	file.store_buffer(body)
	var failed: bool = file.get_error() != OK
	file.close()
	return not failed


## Reads a file written by [method write_sealed]; null for anything else.
static func read_sealed(path: String) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var seal: PackedByteArray = SEAL.to_utf8_buffer()
	var line_end: int = bytes.find(10)
	if line_end != seal.size() + 64 or bytes.slice(0, seal.size()) != seal:
		return null
	var body: PackedByteArray = bytes.slice(line_end + 1)
	if bytes.slice(seal.size(), line_end).get_string_from_ascii() != _sha256_hex(body):
		return null
	var config := ConfigFile.new()
	if config.parse(body.get_string_from_utf8()) != OK:
		return null
	return config


static func path_for(child_scope: String, grade: int, subject: String, course_id: String) -> String:
	if child_scope.is_empty():
		return "user://run_session_%s.cfg" % course_id
	return (
		"user://run_%s_%d_%s_%s.cfg"
		% [child_scope.substr(0, 24), grade, subject.sha256_text().substr(0, 12), course_id]
	)


static func save(path: String, identity: Dictionary, state: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", VERSION)
	for key in identity:
		config.set_value(SECTION, str(key), identity[key])
	for key in state:
		config.set_value(SECTION, str(key), state[key])
	if not write_sealed(path + ".tmp", config):
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


static func erase(path: String) -> void:
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")


## Checkpoint of a save that looks usable for this child and course, or -1.
## Used by the course selection; the full check happens when the course is built.
static func peek(path: String, identity: Dictionary) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var config: ConfigFile = read_sealed(path)
	if config == null or config.get_value(SECTION, "version", 0) != VERSION:
		return -1
	for key in identity:
		var stored: Variant = config.get_value(SECTION, str(key), null)
		if typeof(stored) != typeof(identity[key]) or stored != identity[key]:
			return -1
	var checkpoint: Variant = config.get_value(SECTION, "checkpoint", null)
	if typeof(checkpoint) != TYPE_INT or checkpoint < 0 or checkpoint > 40:
		return -1
	return checkpoint


## Returns the saved state when it belongs to exactly this child, course and plan
## and every field is plausible; otherwise an empty dictionary.
static func load_valid(path: String, identity: Dictionary, plan) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var config: ConfigFile = read_sealed(path)
	if config == null or not config.has_section(SECTION):
		return {}
	if typeof(config.get_value(SECTION, "version", 0)) != TYPE_INT:
		return {}
	if int(config.get_value(SECTION, "version", 0)) != VERSION:
		return {}
	for key in identity:
		var stored: Variant = config.get_value(SECTION, str(key), null)
		if typeof(stored) != typeof(identity[key]) or stored != identity[key]:
			return {}
	var checkpoint: Variant = config.get_value(SECTION, "checkpoint", null)
	if typeof(checkpoint) != TYPE_INT or checkpoint < 0 or checkpoint >= plan.checkpoints.size():
		return {}
	var result_id: Variant = config.get_value(SECTION, "result_id", null)
	if typeof(result_id) != TYPE_STRING or result_id.is_empty() or result_id.length() > 200:
		return {}
	var elapsed: Variant = config.get_value(SECTION, "elapsed_ms", null)
	if typeof(elapsed) != TYPE_INT or elapsed < 0 or elapsed > MAX_ELAPSED_MS:
		return {}
	var taken: Variant = config.get_value(SECTION, "taken", null)
	if typeof(taken) != TYPE_PACKED_INT32_ARRAY:
		return {}
	var seen: Dictionary = {}
	var limit: float = float(plan.checkpoints[checkpoint].s) + 6.0
	var worth: int = 0
	for index in taken:
		if index < 0 or index >= plan.star_s.size() or seen.has(index):
			return {}
		# Nothing beyond the saved checkpoint can have been collected yet.
		if plan.star_s[index] > limit:
			return {}
		seen[index] = true
		worth += plan.star_value[index]
	var broken: Variant = config.get_value(SECTION, "broken", null)
	if typeof(broken) != TYPE_ARRAY:
		return {}
	var crates: Array[int] = []
	for index in broken:
		if typeof(index) != TYPE_INT or index < 0 or index >= plan.blockers.size():
			return {}
		if str(plan.blockers[index].kind) not in ["crate", "roller"] or crates.has(index):
			return {}
		crates.append(index)
	var solved: Dictionary = {}
	var questions: Variant = config.get_value(SECTION, "questions", null)
	if typeof(questions) != TYPE_DICTIONARY:
		return {}
	var stops: Array[int] = plan.question_checkpoints()
	for key in questions:
		if typeof(key) != TYPE_INT or not stops.has(key) or key > checkpoint:
			return {}
		var entry: Variant = questions[key]
		if typeof(entry) != TYPE_DICTIONARY:
			return {}
		if typeof(entry.get("correct")) != TYPE_BOOL or typeof(entry.get("first")) != TYPE_BOOL:
			return {}
		solved[key] = {"correct": entry.correct, "first": entry.first and entry.correct}
	var kept: Variant = config.get_value(SECTION, "kept", null)
	var gathered: Variant = config.get_value(SECTION, "gathered", null)
	var stumbles: Variant = config.get_value(SECTION, "stumbles", null)
	if typeof(kept) != TYPE_INT or typeof(gathered) != TYPE_INT or typeof(stumbles) != TYPE_INT:
		return {}
	# Stars held can never exceed what the collected stars, crates and answers gave.
	var ceiling: int = worth + crates.size() * TUNING.CRATE_STARS + solved.size() * TUNING.QUESTION_BONUS_STARS
	if kept < 0 or kept > ceiling or gathered < kept or gathered > ceiling or stumbles < 0:
		return {}
	var misses: Dictionary = {}
	var stored_misses: Variant = config.get_value(SECTION, "misses", {})
	if typeof(stored_misses) != TYPE_DICTIONARY:
		return {}
	for key in stored_misses:
		if typeof(key) != TYPE_INT or key < 0 or key >= plan.channels.size():
			return {}
		if typeof(stored_misses[key]) != TYPE_INT or stored_misses[key] < 0:
			return {}
		misses[key] = stored_misses[key]
	var pending: Variant = config.get_value(SECTION, "pending_question", {})
	if typeof(pending) != TYPE_DICTIONARY:
		return {}
	if not pending.is_empty() and not _valid_question(pending):
		return {}
	var recent: Array[String] = []
	var stored_recent: Variant = config.get_value(SECTION, "recent_questions", [])
	if typeof(stored_recent) == TYPE_ARRAY:
		for prompt in stored_recent:
			if typeof(prompt) == TYPE_STRING and recent.size() < 40:
				recent.append(prompt)
	return {
		"checkpoint": checkpoint,
		"result_id": result_id,
		"elapsed_ms": elapsed,
		"taken": taken,
		"broken": crates,
		"questions": solved,
		"kept": kept,
		"gathered": gathered,
		"stumbles": stumbles,
		"misses": misses,
		"pending_question": pending,
		"recent_questions": recent,
	}


static func _valid_question(question: Dictionary) -> bool:
	if typeof(question.get("prompt")) != TYPE_STRING or typeof(question.get("answer")) != TYPE_STRING:
		return false
	var options: Variant = question.get("options")
	if typeof(options) != TYPE_ARRAY or options.size() < 2 or options.size() > 6:
		return false
	for option in options:
		if typeof(option) != TYPE_STRING:
			return false
	return options.has(question.answer)


# ------------------------------------------------------------------ best results

static func record(child_scope: String, course_id: String) -> Dictionary:
	var config: ConfigFile = read_sealed(RECORDS)
	if config == null:
		return {}
	var entry: Variant = config.get_value(_record_section(child_scope), course_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var rating: Variant = entry.get("rating")
	var time_ms: Variant = entry.get("time_ms")
	if typeof(rating) != TYPE_INT or rating < 1 or rating > 3:
		return {}
	if typeof(time_ms) != TYPE_INT or time_ms <= 0 or time_ms > MAX_ELAPSED_MS:
		return {}
	return {"rating": rating, "time_ms": time_ms}


static func store_record(child_scope: String, course_id: String, rating: int, time_ms: int) -> void:
	var best: Dictionary = record(child_scope, course_id)
	if not best.is_empty():
		var better: bool = rating > int(best.rating) or (rating == int(best.rating) and time_ms < int(best.time_ms))
		if not better:
			return
	var config: ConfigFile = read_sealed(RECORDS)
	if config == null:
		config = ConfigFile.new()
	config.set_value(_record_section(child_scope), course_id, {"rating": rating, "time_ms": time_ms})
	write_sealed(RECORDS, config)


static func _record_section(child_scope: String) -> String:
	return "best_" + (child_scope.substr(0, 24) if not child_scope.is_empty() else "standalone")
