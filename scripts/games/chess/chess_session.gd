extends RefCounted
## Spielstand von Lumo Schach: laufende Partien, Schulfortschritt,
## Probespiel-Stufen, Einstellungen und gebuchte Ergebnisse.
## Eine Datei pro Kind unter user://, wie beim Kartentisch.
##
## Versioniert: ältere Fassungen werden gelesen und um fehlende Teile ergänzt,
## Partien als Startstellung + Zugliste gespeichert (damit Zurücknehmen und
## Stellungswiederholung nach dem Laden weiter stimmen). Kaputte Partien
## werden verworfen, ohne den Rest zu verlieren.

const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const VERSION := 2
const BOOKED_LIMIT := 300

var path := ""
var data: Dictionary = {}
var last_error := ""


static func path_for(child_key: String) -> String:
	var owner := child_key.strip_edges()
	if owner.is_empty():
		return "user://lumo_chess_standalone.json"
	return "user://lumo_chess_%s.json" % owner.sha256_text().substr(0, 24)


func _init(file_path: String = "") -> void:
	path = file_path
	data = _blank()


static func _blank() -> Dictionary:
	return {
		"v": VERSION,
		"games": {},
		"school": {},
		"trial": {},
		"minigames": {},
		"booked": [],
		"prefs": {"hints": true, "coords": true, "view": "3d", "level": 0, "mode": "kids"},
		"stats": {},
	}


## Lädt die Datei. Fehlt sie oder ist sie kaputt, bleibt ein leerer Stand.
## Fassung 1 (nur Partien und Schule) wird übernommen und ergänzt.
func load_file() -> bool:
	data = _blank()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	# JSON.new().parse meldet kaputte Dateien still (parse_string schreibt ERROR ins Log).
	var json := JSON.new()
	var parsed: Variant = null
	if json.parse(FileAccess.get_file_as_string(path)) == OK:
		parsed = json.data
	if not parsed is Dictionary:
		last_error = "Spielstand unlesbar"
		return false
	var version := int(parsed.get("v", 0))
	if version < 1 or version > VERSION:
		last_error = "Spielstand-Fassung %d unbekannt" % version
		return false
	for key: String in ["games", "school", "trial", "minigames", "stats"]:
		if parsed.get(key) is Dictionary:
			data[key] = parsed[key]
	if parsed.get("prefs") is Dictionary:
		for key: String in data.prefs:
			if parsed.prefs.has(key):
				data.prefs[key] = parsed.prefs[key]
	if parsed.get("booked") is Array:
		data.booked = parsed.booked
	var prefs: Dictionary = data.prefs
	prefs["hints"] = bool(prefs.get("hints", true))
	prefs["coords"] = bool(prefs.get("coords", true))
	prefs["view"] = "top" if str(prefs.get("view", "3d")) == "top" else "3d"
	prefs["level"] = clampi(int(prefs.get("level", 0)), 0, 3)
	var mode := str(prefs.get("mode", "kids"))
	prefs["mode"] = mode if mode in ["kids", "play", "pro"] else "kids"
	data.v = VERSION
	return true


## Schreibt erst in eine Nebendatei und tauscht dann aus.
func save_file() -> bool:
	if path.is_empty():
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Spielstand nicht schreibbar"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		last_error = "Spielstand nicht gespeichert (%d)" % error
	return error == OK


func pref(key: String, fallback: Variant = null) -> Variant:
	return data.prefs.get(key, fallback)


func set_pref(key: String, value: Variant) -> void:
	data.prefs[key] = value
	save_file()


# --- Partien ----------------------------------------------------------------


func has_game(slot: String) -> bool:
	return data.games.get(slot) is Dictionary


## Speichert eine Partie samt Zusatzangaben (Stufe, Farbe, Ergebnis-ID …).
func store_game(slot: String, rules: RefCounted, meta: Dictionary = {}) -> bool:
	var entry: Dictionary = rules.snapshot()
	entry["meta"] = meta.duplicate(true)
	data.games[slot] = entry
	return save_file()


## Gibt {"rules": …, "meta": {…}} zurück oder {} (kaputte Partie wird verworfen).
func resume_game(slot: String) -> Dictionary:
	if not has_game(slot):
		return {}
	var saved: Dictionary = data.games[slot]
	var rules: RefCounted = RULES.new()
	if not str(saved.get("start", "")).is_empty() and rules.restore(saved):
		var meta: Variant = saved.get("meta", {})
		return {"rules": rules, "meta": meta if meta is Dictionary else {}}
	data.games.erase(slot)
	save_file()
	return {}


func discard_game(slot: String) -> void:
	if data.games.has(slot):
		data.games.erase(slot)
		save_file()


# --- Schule und Probespiel --------------------------------------------------


func lesson_stars(lesson_id: String) -> int:
	return int(data.school.get(lesson_id, 0))


## Merkt sich die beste Sternzahl (0–3) einer Lektion.
func finish_lesson(lesson_id: String, stars: int) -> void:
	data.school[lesson_id] = maxi(lesson_stars(lesson_id), clampi(stars, 1, 3))
	save_file()


func trial_done(stage_id: String) -> bool:
	return bool(data.trial.get(stage_id, false))


func finish_trial(stage_id: String) -> void:
	data.trial[stage_id] = true
	save_file()


func minigame_best(game_id: String) -> int:
	return int(data.minigames.get(game_id, 0))


func record_minigame(game_id: String, stars: int) -> void:
	data.minigames[game_id] = maxi(minigame_best(game_id), clampi(stars, 1, 3))
	save_file()


# --- Ergebnisse -------------------------------------------------------------


func is_booked(result_id: String) -> bool:
	return data.booked.has(result_id)


## Bucht ein Ergebnis genau einmal. Gibt false zurück, wenn es schon gebucht war.
func book(result_id: String, kind: String = "", won: bool = false) -> bool:
	if result_id.is_empty() or is_booked(result_id):
		return false
	data.booked.append(result_id)
	while data.booked.size() > BOOKED_LIMIT:
		data.booked.pop_front()
	if not kind.is_empty():
		var stats: Dictionary = data.stats.get(kind, {"played": 0, "won": 0})
		stats["played"] = int(stats.get("played", 0)) + 1
		if won:
			stats["won"] = int(stats.get("won", 0)) + 1
		data.stats[kind] = stats
	save_file()
	return true
