extends RefCounted
const ENGLISH = preload("res://scripts/learning/english_vocabulary.gd")
## Deterministic manipulative state, separate from presentation and rewards.
## No independent-answer evidence is emitted by an explanatory activity.

var kind := "invalid"
var a := 0
var b := 0
var extra := 0
var word := ""
var syllables: Array[String] = []
var plant_part := "root"
var placed: Array[int] = []
var watered := false
var sunlight := false
var inspected: Array[String] = []
var english_objects: Array[String] = []
var english_meaning := ""
var english_choice := -1
var english_hint_level := 0
var english_attempts := 0
var english_complete := false

# Read-only, Flutter-verified native illustration data. There is no
# correctAnswer, childId or reward value inside these payloads.
var pattern_sequence: Array[String] = []
var pattern_choices: Array[String] = []
var pattern_unit: Array[String] = []
var pattern_period := 0
var pattern_hint_level := 0
var task_source_id := ""
var task_prompt := ""
var task_subject := ""
var task_unit := ""
var task_explanation := ""
var task_choices: Array[String] = []


func configure(raw: Dictionary) -> bool:
	reset()
	pattern_sequence.clear()
	pattern_choices.clear()
	pattern_unit.clear()
	pattern_period = 0
	task_choices.clear()
	task_source_id = ""
	task_prompt = ""
	task_subject = ""
	task_unit = ""
	task_explanation = ""
	kind = str(raw.get("kind", "invalid"))
	match kind:
		"english_objects":
			var checked := ENGLISH.checked_payload(raw)
			if checked.is_empty():
				kind = "invalid"
				return false
			word = checked.word
			english_meaning = checked.meaning
			english_objects.clear()
			for item: String in checked.objects:
				english_objects.append(item)
		"bridge_ten":
			if not _whole_number(raw.get("a")) or not _whole_number(raw.get("b")):
				kind = "invalid"
				return false
			a = int(raw.a)
			b = int(raw.b)
			if a < 1 or a > 9 or b < 1 or b > 9 or a + b <= 10:
				kind = "invalid"
		"addition", "subtract_ten", "equal_groups", "equal_sharing", "bridge_hundred", "fraction_parts":
			if (
				not _bounded_integer(raw.get("a"), 0, 900)
				or not _bounded_integer(raw.get("b"), 1, 90)
			):
				kind = "invalid"
				return false
			a = int(raw.a)
			b = int(raw.b)
			match kind:
				"addition":
					if a > 10 or b > 10 or a + b > 20:
						kind = "invalid"
				"subtract_ten":
					if a < 1 or a > 20 or b > a:
						kind = "invalid"
				"equal_groups":
					if a < 1 or a > 6 or b > 6:
						kind = "invalid"
				"equal_sharing":
					if b < 2 or b > 6 or a < b or a > 36 or a % b != 0 or a / b > 6:
						kind = "invalid"
				"bridge_hundred":
					if (
						a < 100
						or a > 890
						or a % 10 != 0
						or b < 10
						or b % 10 != 0
						or a % 100 + b < 100
					):
						kind = "invalid"
				"fraction_parts":
					if not _bounded_integer(raw.get("extra", 0), 0, 12):
						kind = "invalid"
						return false
					extra = int(raw.get("extra", 0))
					if a < 1 or b < 2 or b > 12 or a + extra > b:
						kind = "invalid"
		"syllables":
			word = str(raw.get("word", ""))
			var source: Variant = raw.get("syllables", [])
			if not source is Array or source.size() < 2 or source.size() > 5:
				kind = "invalid"
				return false
			syllables.clear()
			for item in source:
				if not item is String or item.is_empty() or item.length() > 12:
					kind = "invalid"
					return false
				syllables.append(item)
			if word.is_empty() or word.length() > 24 or "".join(syllables) != word:
				kind = "invalid"
		"pattern":
			if not _configure_pattern(raw):
				kind = "invalid"
				return false
		"task_card":
			if not _configure_task_card(raw):
				kind = "invalid"
				return false
		"plant_parts":
			plant_part = str(raw.get("plantPart", "root"))
			if plant_part not in ["root", "stem", "leaf", "flower"]:
				kind = "invalid"
		_:
			kind = "invalid"
	return kind != "invalid"


# Strictly validate the already-reviewed pattern presentation. Both existing
# Flutter adapters are supported without passing a correct-answer marker.
func _configure_pattern(raw: Dictionary) -> bool:
	var source: Variant = raw.get("sequence", raw.get("patternSequence", []))
	var choices: Variant = raw.get("choices", raw.get("patternChoices", []))
	var period: Variant = raw.get("period", 0)
	var unit: Variant = raw.get("patternUnit", [])
	if unit is Array and not unit.is_empty():
		period = unit.size()
		if not _append_checked_words(unit, pattern_unit, 1, 4):
			return false
	if not _bounded_integer(period, 1, 4):
		return false
	if not _append_checked_words(source, pattern_sequence, 4, 12):
		return false
	if not _append_checked_words(choices, pattern_choices, 2, 6):
		return false
	if pattern_choices.size() != _unique_word_count(pattern_choices):
		return false
	pattern_period = int(period)
	if pattern_sequence.size() < pattern_period * 2:
		return false
	for i in range(pattern_sequence.size()):
		if pattern_sequence[i] != pattern_sequence[i % pattern_period]:
			return false
		if not pattern_unit.is_empty() and pattern_sequence[i] != pattern_unit[i % pattern_period]:
			return false
	# Reject a visually misleading period if a smaller one already explains it.
	for candidate in range(1, pattern_period):
		if pattern_sequence.size() < candidate * 2:
			continue
		var repeats := true
		for i in range(candidate, pattern_sequence.size()):
			if pattern_sequence[i] != pattern_sequence[i % candidate]:
				repeats = false
				break
		if repeats:
			return false
	var expected_next := pattern_sequence[pattern_sequence.size() % pattern_period]
	return pattern_choices.has(expected_next)


func _configure_task_card(raw: Dictionary) -> bool:
	if not _checked_text(raw.get("sourceTaskId", ""), 180):
		return false
	if not _checked_text(raw.get("prompt", ""), 800):
		return false
	task_source_id = str(raw["sourceTaskId"])
	task_prompt = str(raw["prompt"])
	for key in ["subject", "unit"]:
		if not raw.has(key) or not _checked_text(raw[key], 80, true):
			return false
	task_subject = str(raw["subject"])
	task_unit = str(raw["unit"])
	if not _checked_text(raw.get("explanation", ""), 1200, true):
		return false
	task_explanation = str(raw.get("explanation", ""))
	var raw_choices: Variant = raw.get("answerChoices", [])
	if not _append_checked_words(raw_choices, task_choices, 0, 8, 120):
		return false
	return true


static func _checked_text(value: Variant, limit: int, allow_empty: bool = false) -> bool:
	if not value is String or value.length() > limit:
		return false
	if not allow_empty and value.strip_edges().is_empty():
		return false
	if value.find("\n") >= 0 or value.find("\r") >= 0:
		return false
	for codepoint in value.to_utf32_buffer():
		if codepoint < 32 or codepoint >= 127 and codepoint <= 159:
			return false
	return true


static func _append_checked_words(raw: Variant, output: Array[String], low: int, high: int, max_length: int = 24) -> bool:
	if not raw is Array or raw.size() < low or raw.size() > high:
		return false
	for item in raw:
		if not _checked_text(item, max_length):
			return false
		if item.strip_edges() != item:
			return false
		output.append(item)
	return true


static func _unique_word_count(input: Array[String]) -> int:
	var unique := {}
	for value in input:
		unique[value] = true
	return unique.size()



static func _whole_number(value: Variant) -> bool:
	# JSON.parse_string uses floating point numbers. Accept exact bounded
	# integers from the native JSON bridge, never truncating fractional input.
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value))
		and float(value) >= 1.0
		and float(value) <= 9.0
		and float(value) == floorf(float(value))
	)


static func _bounded_integer(value: Variant, low: int, high: int) -> bool:
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value))
		and float(value) >= low
		and float(value) <= high
		and float(value) == floorf(float(value))
	)


func reset() -> void:
	placed.clear()
	watered = false
	sunlight = false
	inspected.clear()
	english_choice = -1
	english_hint_level = 0
	english_attempts = 0
	english_complete = false
	pattern_hint_level = 0


func token_count() -> int:
	match kind:
		"english_objects":
			return english_objects.size()
		"bridge_ten", "addition":
			return b
		"subtract_ten", "equal_sharing":
			return a
		"equal_groups":
			return a * b
		"bridge_hundred":
			return b / 10
		"fraction_parts":
			return extra if extra > 0 else a
	return syllables.size()


func goal_count() -> int:
	if kind == "english_objects":
		return 1
	return b if kind == "subtract_ten" else token_count()


func initial_count() -> int:
	if kind == "bridge_hundred":
		return (a % 100) / 10
	if kind == "fraction_parts":
		return a if extra > 0 else 0
	return a if kind in ["bridge_ten", "addition"] else 0


func is_complete() -> bool:
	if kind in ["pattern", "task_card"]:
		# An illustration cannot submit or mark an exercise complete.
		return false
	if kind == "english_objects":
		return english_complete
	if kind == "plant_parts":
		return watered and sunlight and inspected.size() == 4
	return kind != "invalid" and placed.size() == goal_count()


func target_index() -> int:
	return target_for_step(placed.size())


func target_for_step(step: int) -> int:
	# A sharing round gives each group one object before any receives a second.
	# Targets are stored by group, while gestures follow this fair round order.
	if kind == "equal_sharing":
		return (step % b) * (a / b) + step / b
	return initial_count() + step


func group_count() -> int:
	return b if kind == "equal_sharing" else a


func group_size() -> int:
	return a / b if kind == "equal_sharing" else b


func count_in_group(group: int) -> int:
	if group < 0 or group >= group_count():
		return 0
	if kind == "equal_sharing":
		return placed.size() / b + (1 if group < placed.size() % b else 0)
	return clampi(placed.size() - group * b, 0, b)


func place(token: int, target: int) -> bool:
	if kind in ["invalid", "plant_parts", "english_objects", "pattern", "task_card"] or is_complete() or token < 0 or token >= token_count():
		return false
	if placed.has(token) or target != target_index():
		return false
	if kind == "syllables" and token != target:
		return false
	if kind == "subtract_ten" and a > 10 and a - placed.size() > 10 and token >= a - 10:
		return false
	placed.append(token)
	return true


func inspect_part(part: String) -> bool:
	if kind != "plant_parts" or part not in ["root", "stem", "leaf", "flower"]:
		return false
	if not inspected.has(part):
		inspected.append(part)
	return true


func choose_english(index: int) -> bool:
	if kind != "english_objects" or english_complete or index < 0 or index >= english_objects.size():
		return false
	english_choice = index
	english_attempts += 1
	english_complete = english_objects[index] == word
	return english_complete


func english_hint() -> bool:
	if kind != "english_objects" or english_complete or english_hint_level >= 2:
		return false
	english_hint_level += 1
	return true


func explanation() -> String:
	match kind:
		"pattern":
			return ("Die kleinste Wiederholung hat %d Formen. Schau dir die markierte Gruppe an und entscheide selbst in der Aufgabe." % pattern_period
				if pattern_hint_level > 0 else "Welche Form kommt als Nächstes? Suche die Gruppe, die sich immer wiederholt.")
		"task_card":
			return task_prompt if task_prompt.length() <= 180 else task_prompt.substr(0, 177) + " …"
		"english_objects":
			if english_complete:
				return "Richtig: „%s“. Wähle jetzt „Zur Aufgabe“." % english_meaning
			if english_hint_level == 2:
				return "Tippe selbst auf den hell umrandeten Gegenstand."
			if english_hint_level == 1:
				return ENGLISH.hint_for(word)
			if english_attempts > 0:
				return "Das passt noch nicht. Ein Hinweis kann dir helfen."
			return "Tippe auf den Gegenstand zum englischen Wort."
		"bridge_ten", "addition":
			var filled: int = a + placed.size()
			if kind == "addition" and a + b <= 10:
				return (
					"%d plus %d ist %d." % [a, b, a + b]
					if is_complete()
					else "Lege %d Würfel zu den %d dazu. Jetzt sind es %d." % [b, a, filled]
				)
			if placed.is_empty() and a == 10:
				return "Zehn sind schon voll. Lege die %d neuen Würfel ins zweite Feld." % b
			if placed.is_empty():
				return "%d + %d: Fülle zuerst die freien Plätze bis zehn." % [a, b]
			if filled < 10:
				return "Jetzt liegen %d im Zehnerfeld. Noch %d bis zehn." % [filled, 10 - filled]
			if filled == 10:
				return (
					"Zehn sind voll! Von den %d bleiben %d. Lege sie ins zweite Feld."
					% [b, a + b - 10]
				)
			if is_complete():
				return (
					"%d + %d = 10 + %d = %d. Du hast den Zehner selbst gefüllt."
					% [a, b, a + b - 10, a + b]
				)
			return "Zehn und %d sind %d. Lege die übrigen Würfel dazu." % [filled - 10, filled]
		"subtract_ten":
			var remaining: int = a - placed.size()
			if is_complete():
				return "%d minus %d ist %d. So viele Würfel bleiben im Feld." % [a, b, remaining]
			if remaining == 10:
				return (
					"Jetzt bleiben zehn. Nimm noch %d weg, dann hast du insgesamt %d weggenommen."
					% [b - placed.size(), b]
				)
			if remaining > 10 and a - b <= 10:
				return (
					"Nimm zuerst Würfel aus dem zweiten Feld. %d sind schon weg; %d bleiben noch bis zur Zehn."
					% [placed.size(), remaining - 10]
				)
			return (
				"Von %d nehmen wir %d weg. %d sind schon weg; %d liegen noch im Feld."
				% [a, b, placed.size(), remaining]
			)
		"equal_groups":
			if is_complete():
				return "%d Gruppen mit je %d Würfeln: %d mal %d ist %d." % [a, b, a, b, a * b]
			return (
				"Fülle %d Gruppen mit je %d Würfeln. Schon %d Gruppen sind voll."
				% [a, b, placed.size() / b]
			)
		"equal_sharing":
			if is_complete():
				return (
					"%d Würfel, %d gleiche Gruppen: Jede hat %d. %d geteilt durch %d ist %d."
					% [a, b, a / b, a, b, a / b]
				)
			if placed.is_empty():
				return (
					"Verteile %d Würfel gerecht auf %d Gruppen. Gib jeder Gruppe der Reihe nach einen Würfel."
					% [a, b]
				)
			if placed.size() % b == 0:
				return (
					"Jede Gruppe hat jetzt %d. Noch %d Würfel bleiben. Beginne die nächste Runde."
					% [placed.size() / b, a - placed.size()]
				)
			return (
				"Als Nächstes bekommt Gruppe %d einen Würfel. Noch %d liegen auf der Ablage."
				% [placed.size() % b + 1, a - placed.size()]
			)
		"bridge_hundred":
			var current: int = a + placed.size() * 10
			var boundary: int = (a / 100 + 1) * 100
			if is_complete():
				return "%d plus %d ist %d. Zehn Zehner bilden einen Hunderter." % [a, b, current]
			if current < boundary:
				return (
					"Jeder Streifen zählt zehn. Jetzt sind es %d. Ergänze zuerst bis %d."
					% [current, boundary]
				)
			return (
				"Der Hunderter ist voll. Jetzt sind es %d. Lege noch %d Zehner ins zweite Feld."
				% [current, token_count() - placed.size()]
			)
		"fraction_parts":
			if is_complete():
				return (
					"%d von %d gleich großen Teilen sind markiert: %d/%d. Die Teilgröße bleibt gleich."
					% [a + extra, b, a + extra, b]
				)
			return (
				"Im Feld: %d von %d gleich großen Teilen. Lege noch %d dazu."
				% [initial_count() + placed.size(), b, token_count() - placed.size()]
			)
		"syllables":
			if is_complete():
				return (
					"%s: %s. Das Wort hat %d Silben."
					% [word, " – ".join(syllables), syllables.size()]
				)
			return "Baue %s. Als Nächstes kommt die Silbe „%s“." % [word, syllables[placed.size()]]
		"plant_parts":
			if watered and sunlight:
				return "Licht und Wasser helfen der Pflanze zu wachsen. Entdecke ihre vier Teile."
			return "Gib Wasser und öffne die Sonne. Tippe auf Wurzel, Stängel, Blatt und Blüte."
	return "Diese Lernansicht konnte nicht sicher geladen werden."
