extends RefCounted
## Saves of Lumos Sternenpost, per child: the unfinished delivery tour or free
## flight (continue later), best results per mode and stage, the free-flight
## album (secret sparks and photos ever found) and the menu choices (glider
## colour, stage, riddles on/off). Files are sealed with a checksum (shared with
## Lumo Lauf); anything doubtful is ignored, never repaired.

const SEALED = preload("res://scripts/games/run/run_session.gd")
const ADDRESSES = preload("res://scripts/games/skypost/sky_post_addresses.gd")
const LAYOUT = preload("res://scripts/games/skypost/sky_post_layout.gd")
const VERSION: int = 1
const SECTION: String = "skypost"
const RECORDS: String = "user://skypost_records.cfg"
const MAX_ELAPSED_MS: int = 6 * 60 * 60 * 1000


static func path_for(child_scope: String, mode: String) -> String:
	var who: String = child_scope.substr(0, 24) if not child_scope.is_empty() else "standalone"
	return "user://skypost_%s_%s.cfg" % [who, mode]


static func save(path: String, identity: Dictionary, state: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", VERSION)
	for key in identity:
		config.set_value(SECTION, "id_" + str(key), identity[key])
	for key in state:
		config.set_value(SECTION, str(key), state[key])
	if not SEALED.write_sealed(path + ".tmp", config):
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


static func erase(path: String) -> void:
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")


static func _matching(path: String, identity: Dictionary) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var config: ConfigFile = SEALED.read_sealed(path)
	if config == null or typeof(config.get_value(SECTION, "version", 0)) != TYPE_INT:
		return null
	if int(config.get_value(SECTION, "version", 0)) != VERSION:
		return null
	for key in identity:
		var stored: Variant = config.get_value(SECTION, "id_" + str(key), null)
		if typeof(stored) != typeof(identity[key]) or stored != identity[key]:
			return null
	return config


## Short description of a usable save for the menu ("3 von 6 Briefen"), or "".
static func peek(path: String, identity: Dictionary) -> String:
	var config: ConfigFile = _matching(path, identity)
	if config == null:
		return ""
	if str(identity.get("mode", "")) == "delivery":
		var jobs: Variant = config.get_value(SECTION, "jobs", null)
		var done: Variant = config.get_value(SECTION, "done", null)
		if typeof(jobs) != TYPE_ARRAY or typeof(done) != TYPE_INT:
			return ""
		return "%d von %d Briefen" % [done, jobs.size()]
	var secrets: Variant = config.get_value(SECTION, "secrets", null)
	if typeof(secrets) != TYPE_INT:
		return ""
	return "Freiflug unterwegs"


## The saved delivery tour when every field is plausible, else {}.
static func load_delivery(path: String, identity: Dictionary, spark_total: int) -> Dictionary:
	var config: ConfigFile = _matching(path, identity)
	if config == null:
		return {}
	var result_id: Variant = config.get_value(SECTION, "result_id", null)
	var elapsed: Variant = config.get_value(SECTION, "elapsed_ms", null)
	var jobs: Variant = config.get_value(SECTION, "jobs", null)
	var done: Variant = config.get_value(SECTION, "done", null)
	var tries: Variant = config.get_value(SECTION, "tries", null)
	var taken: Variant = config.get_value(SECTION, "taken", null)
	if (
		typeof(result_id) != TYPE_STRING
		or str(result_id).is_empty()
		or str(result_id).length() > 200
	):
		return {}
	if typeof(elapsed) != TYPE_INT or elapsed < 0 or elapsed > MAX_ELAPSED_MS:
		return {}
	if typeof(jobs) != TYPE_ARRAY or jobs.is_empty() or jobs.size() > LAYOUT.DISTRICTS.size():
		return {}
	if typeof(done) != TYPE_INT or done < 0 or done >= jobs.size():
		return {}
	if typeof(tries) != TYPE_PACKED_INT32_ARRAY or tries.size() != jobs.size():
		return {}
	if typeof(taken) != TYPE_PACKED_BYTE_ARRAY or taken.size() != spark_total:
		return {}
	var districts: Dictionary = {}
	for job in jobs:
		if typeof(job) != TYPE_DICTIONARY:
			return {}
		var district: Variant = job.get("district")
		if (
			typeof(district) != TYPE_INT
			or district < 0
			or district >= LAYOUT.DISTRICTS.size()
			or districts.has(district)
		):
			return {}
		districts[district] = true
		if (
			str(job.get("item", "")) not in ["Brief", "Paket"]
			or typeof(job.get("recipient")) != TYPE_STRING
		):
			return {}
		if typeof(job.get("riddle")) != TYPE_DICTIONARY or not ADDRESSES.valid(job.riddle):
			return {}
	for count in tries:
		if count < 0 or count > 99:
			return {}
	for flag in taken:
		if flag > 1:
			return {}
	return {
		"result_id": result_id,
		"elapsed_ms": elapsed,
		"jobs": jobs,
		"done": done,
		"tries": tries,
		"taken": taken
	}


static func load_free(path: String, identity: Dictionary, spark_total: int) -> Dictionary:
	var config: ConfigFile = _matching(path, identity)
	if config == null:
		return {}
	var result_id: Variant = config.get_value(SECTION, "result_id", null)
	var elapsed: Variant = config.get_value(SECTION, "elapsed_ms", null)
	var secrets: Variant = config.get_value(SECTION, "secrets", null)
	var photos: Variant = config.get_value(SECTION, "photos", null)
	var taken: Variant = config.get_value(SECTION, "taken", null)
	if (
		typeof(result_id) != TYPE_STRING
		or str(result_id).is_empty()
		or str(result_id).length() > 200
	):
		return {}
	if typeof(elapsed) != TYPE_INT or elapsed < 0 or elapsed > MAX_ELAPSED_MS:
		return {}
	if typeof(secrets) != TYPE_INT or secrets < 0 or secrets >= (1 << LAYOUT.SECRETS.size()):
		return {}
	if typeof(photos) != TYPE_INT or photos < 0 or photos >= (1 << LAYOUT.PHOTOS.size()):
		return {}
	if typeof(taken) != TYPE_PACKED_BYTE_ARRAY or taken.size() != spark_total:
		return {}
	return {
		"result_id": result_id,
		"elapsed_ms": elapsed,
		"secrets": secrets,
		"photos": photos,
		"taken": taken
	}


# ------------------------------------------------------------------ records, album, choices


static func _records() -> ConfigFile:
	var config: ConfigFile = SEALED.read_sealed(RECORDS)
	return config if config != null else ConfigFile.new()


static func _write_records(config: ConfigFile) -> void:
	if SEALED.write_sealed(RECORDS + ".tmp", config):
		DirAccess.rename_absolute(RECORDS + ".tmp", RECORDS)


static func _section(child_scope: String) -> String:
	return "child_" + (child_scope.substr(0, 24) if not child_scope.is_empty() else "standalone")


## Best result of [param mode] on [param stage]: {rating, time_ms, place} or {}.
static func record(child_scope: String, mode: String, stage: String) -> Dictionary:
	var entry: Variant = _records().get_value(
		_section(child_scope), "best_%s_%s" % [mode, stage], {}
	)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var rating: Variant = entry.get("rating")
	var time_ms: Variant = entry.get("time_ms")
	var place: Variant = entry.get("place", 0)
	if typeof(rating) != TYPE_INT or rating < 1 or rating > 3:
		return {}
	if typeof(time_ms) != TYPE_INT or time_ms <= 0 or time_ms > MAX_ELAPSED_MS:
		return {}
	if typeof(place) != TYPE_INT or place < 0 or place > 4:
		return {}
	return {"rating": rating, "time_ms": time_ms, "place": place}


## Keeps the better result (higher seal; a better place in a race; then the faster time).
static func store_record(
	child_scope: String, mode: String, stage: String, rating: int, time_ms: int, place: int = 0
) -> bool:
	var best: Dictionary = record(child_scope, mode, stage)
	if not best.is_empty():
		var old_place: int = int(best.place) if int(best.place) > 0 else 9
		var new_place: int = place if place > 0 else 9
		var better: bool = (
			rating > int(best.rating)
			or (rating == int(best.rating) and new_place < old_place)
			or (
				rating == int(best.rating)
				and new_place == old_place
				and time_ms < int(best.time_ms)
			)
		)
		if not better:
			return false
	var config: ConfigFile = _records()
	config.set_value(
		_section(child_scope),
		"best_%s_%s" % [mode, stage],
		{"rating": rating, "time_ms": time_ms, "place": place}
	)
	_write_records(config)
	return true


## Free-flight album: {secrets: bitmask, photos: bitmask}.
static func album(child_scope: String) -> Dictionary:
	var config: ConfigFile = _records()
	var secrets: Variant = config.get_value(_section(child_scope), "album_secrets", 0)
	var photos: Variant = config.get_value(_section(child_scope), "album_photos", 0)
	if typeof(secrets) != TYPE_INT or secrets < 0 or secrets >= (1 << LAYOUT.SECRETS.size()):
		secrets = 0
	if typeof(photos) != TYPE_INT or photos < 0 or photos >= (1 << LAYOUT.PHOTOS.size()):
		photos = 0
	return {"secrets": secrets, "photos": photos}


static func store_album(child_scope: String, secrets: int, photos: int) -> void:
	var config: ConfigFile = _records()
	var old: Dictionary = album(child_scope)
	config.set_value(_section(child_scope), "album_secrets", int(old.secrets) | secrets)
	config.set_value(_section(child_scope), "album_photos", int(old.photos) | photos)
	_write_records(config)


static func choices(child_scope: String) -> Dictionary:
	var config: ConfigFile = _records()
	var section: String = _section(child_scope)
	var colour: Variant = config.get_value(section, "colour", "sternblau")
	var stage: Variant = config.get_value(section, "stage", "entdecken")
	var riddles: Variant = config.get_value(section, "riddles", true)
	var mode: Variant = config.get_value(section, "mode", "delivery")
	return {
		"colour": colour if typeof(colour) == TYPE_STRING else "sternblau",
		"stage":
		(
			stage
			if typeof(stage) == TYPE_STRING and stage in ["entdecken", "abenteuer", "extrem"]
			else "entdecken"
		),
		"riddles": riddles if typeof(riddles) == TYPE_BOOL else true,
		"mode":
		(
			mode
			if typeof(mode) == TYPE_STRING and mode in ["delivery", "race", "free"]
			else "delivery"
		),
	}


static func store_choices(child_scope: String, values: Dictionary) -> void:
	var config: ConfigFile = _records()
	var section: String = _section(child_scope)
	for key in ["colour", "stage", "riddles", "mode"]:
		if values.has(key):
			config.set_value(section, key, values[key])
	_write_records(config)
