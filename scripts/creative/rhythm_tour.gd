extends RefCounted
## Additive campaign data inside the existing child-specific rhythm ConfigFile.
## Free play and original song/best keys are deliberately untouched.
const SECTION := "tour_v1"
const STAGES = [
	{"id": "wiese", "title": "Wiesenbühne", "song": 0, "hits": 16, "holds": 0, "slides": 0,
		"story": "Lumo lädt die Waldtiere ein. Bring die ersten Sterne zum Leuchten."},
	{"id": "wolken", "title": "Wolkenkonzert", "song": 1, "hits": 18, "holds": 1, "slides": 0,
		"story": "Die Wolken tragen deine Musik weiter. Halte einen langen Ton bis zum Ende."},
	{"id": "funken", "title": "Funkenfest", "song": 2, "hits": 20, "holds": 0, "slides": 1,
		"story": "Beim Lichterfest wandern die Töne. Folge einem Pfeil in die Nachbarspur."},
	{"id": "mond", "title": "Mondfinale", "song": 3, "hits": 22, "holds": 1, "slides": 1,
		"story": "Alle Freunde sind da. Verbinde Tippen, Halten und Wischen im Finale."}
]
var cleared: Array[int] = [0, 0, 0]
var best_hits: Dictionary = {}
var attempts: Dictionary = {}
var last_result := ""


func read_from(config: ConfigFile) -> bool:
	cleared.assign([0, 0, 0])
	best_hits.clear()
	attempts.clear()
	last_result = ""
	if not config.has_section(SECTION):
		return true
	if config.get_value(SECTION, "version", 0) != 1:
		return false
	for difficulty in range(3):
		var value = config.get_value(SECTION, "cleared_%d" % difficulty, 0)
		if not value is int or value < 0 or value > STAGES.size():
			return false
		cleared[difficulty] = value
		for index in range(STAGES.size()):
			var key := _key(index, difficulty)
			var hits = config.get_value(SECTION, "hits_" + key, 0)
			var count = config.get_value(SECTION, "attempts_" + key, 0)
			best_hits[key] = clampi(hits, 0, 40) if hits is int else 0
			attempts[key] = clampi(count, 0, 1000000) if count is int else 0
	last_result = str(config.get_value(SECTION, "last_result", "")).substr(0, 160)
	return true


func write_to(config: ConfigFile) -> void:
	config.set_value(SECTION, "version", 1)
	for difficulty in range(3):
		config.set_value(SECTION, "cleared_%d" % difficulty, cleared[difficulty])
		for index in range(STAGES.size()):
			var key := _key(index, difficulty)
			config.set_value(SECTION, "hits_" + key, int(best_hits.get(key, 0)))
			config.set_value(SECTION, "attempts_" + key, int(attempts.get(key, 0)))
	config.set_value(SECTION, "last_result", last_result)


static func _key(index: int, difficulty: int) -> String:
	return "%d_%s" % [difficulty, STAGES[index].id]


func stage(index: int, difficulty: int) -> Dictionary:
	if index < 0 or index >= STAGES.size() or difficulty < 0 or difficulty > 2:
		return {}
	var result: Dictionary = STAGES[index].duplicate(true)
	result.hits += difficulty * 2
	result.unlocked = index <= cleared[difficulty]
	result.completed = index < cleared[difficulty]
	result.best_hits = int(best_hits.get(_key(index, difficulty), 0))
	return result


func next_stage(difficulty: int) -> int:
	return mini(cleared[clampi(difficulty, 0, 2)], STAGES.size() - 1)


func goal_text(index: int, difficulty: int) -> String:
	var goal: Dictionary = stage(index, difficulty)
	if goal.is_empty():
		return ""
	var text := "%d von 40 Tönen treffen" % int(goal.hits)
	if int(goal.holds) > 0:
		text += " · 1 langen Ton halten"
	if int(goal.slides) > 0:
		text += " · 1 Pfeil wischen"
	return text + ". Fehler sind erlaubt!"


func record(index: int, difficulty: int, notes: Array, result_id: String) -> Dictionary:
	var goal: Dictionary = stage(index, difficulty)
	if goal.is_empty() or not bool(goal.unlocked) or result_id.is_empty() or result_id == last_result:
		return {"accepted": false, "passed": false}
	# The scene supplies actual judged notes; unfinished rounds cannot unlock
	# a new stage or be counted repeatedly as practice attempts.
	if notes.size() != 40:
		return {"accepted": false, "passed": false}
	var hits := 0
	var holds := 0
	var slides := 0
	for note in notes:
		if not note is Dictionary or int(note.get("state", -1)) not in [2, 3] or str(note.get("kind", "")) not in ["tap", "hold", "slide", "star"]:
			return {"accepted": false, "passed": false}
		if int(note.state) == 2:
			hits += 1
			holds += 1 if str(note.kind) == "hold" else 0
			slides += 1 if str(note.kind) == "slide" else 0
	var passed := hits >= int(goal.hits) and holds >= int(goal.holds) and slides >= int(goal.slides)
	var key := _key(index, difficulty)
	best_hits[key] = maxi(int(best_hits.get(key, 0)), hits)
	attempts[key] = mini(int(attempts.get(key, 0)) + 1, 1000000)
	last_result = result_id
	var newly_completed := passed and index == cleared[difficulty]
	if newly_completed:
		cleared[difficulty] += 1
	return {"accepted": true, "passed": passed, "newly_completed": newly_completed,
		"hits": hits, "holds": holds, "slides": slides, "complete": cleared[difficulty] == STAGES.size()}
