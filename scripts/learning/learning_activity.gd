# gdlint: disable=max-public-methods,max-returns
# The existing activity API is a tagged union. Explicit bounded guards and
# independent actions keep each kind readable without nested fallback paths.
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
var pattern_sequence: Array[String] = []
var pattern_choices: Array[String] = []
var pattern_period := 0
var pattern_candidate := -1
var pattern_hint_level := 0
var pattern_attempts := 0
var pattern_complete := false
var _pattern_candidate_confirmed := false
var _pattern_last_action := ""
var task_prompt: String = ""
var task_subject: String = ""
var task_unit: String = ""
var task_explanation: String = ""
var task_choices: Array[String] = []
var task_choice: int = -1


func configure(raw: Dictionary) -> bool:
	reset()
	pattern_sequence.clear()
	pattern_choices.clear()
	pattern_period = 0
	task_prompt = ""
	task_subject = ""
	task_unit = ""
	task_explanation = ""
	task_choices.clear()
	kind = str(raw.get("kind", "invalid"))
	match kind:
		"task_card":
			if not _configure_task_card(raw):
				kind = "invalid"
				return false
		"pattern":
			if not _configure_pattern(raw):
				kind = "invalid"
				return false
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
		"plant_parts":
			plant_part = str(raw.get("plantPart", "root"))
			if plant_part not in ["root", "stem", "leaf", "flower"]:
				kind = "invalid"
		_:
			kind = "invalid"
	return kind != "invalid"


func _configure_pattern(raw: Dictionary) -> bool:
	var sequence: Variant = raw.get("sequence")
	var choices: Variant = raw.get("choices")
	if not sequence is Array or sequence.size() < 4 or sequence.size() > 12:
		return false
	if not choices is Array or choices.size() < 2 or choices.size() > 6:
		return false
	if not _bounded_integer(raw.get("period"), 1, 4):
		return false
	var checked_sequence: Array[String] = []
	var checked_choices: Array[String] = []
	for token: Variant in sequence:
		if not _pattern_token(token):
			return false
		checked_sequence.append(token)
	for token: Variant in choices:
		if not _pattern_token(token) or checked_choices.has(token):
			return false
		checked_choices.append(token)
	# A claimed period must be the smallest demonstrable repeating group.
	# Two full repetitions are required; the visible suffix may be partial.
	var smallest := 0
	for length in range(1, 5):
		if checked_sequence.size() < length * 2:
			continue
		var repeats := true
		for index in range(length, checked_sequence.size()):
			if checked_sequence[index] != checked_sequence[index % length]:
				repeats = false
				break
		if repeats:
			smallest = length
			break
	if smallest == 0 or smallest != int(raw.period):
		return false
	if not checked_choices.has(checked_sequence[checked_sequence.size() % smallest]):
		return false
	pattern_sequence = checked_sequence
	pattern_choices = checked_choices
	pattern_period = smallest
	return true


static func _pattern_token(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 24:
		return false
	if value != value.strip_edges():
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code in [8232, 8233]:
			return false
	return true


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
	task_choice = -1
	placed.clear()
	watered = false
	sunlight = false
	inspected.clear()
	english_choice = -1
	english_hint_level = 0
	english_attempts = 0
	english_complete = false
	pattern_candidate = -1
	pattern_hint_level = 0
	pattern_attempts = 0
	pattern_complete = false
	_pattern_candidate_confirmed = false
	_pattern_last_action = ""


func token_count() -> int:
	match kind:
		"pattern":
			return pattern_choices.size()
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
	if kind in ["english_objects", "pattern"]:
		return 1
	return b if kind == "subtract_ten" else token_count()


func initial_count() -> int:
	if kind == "bridge_hundred":
		return (a % 100) / 10
	if kind == "fraction_parts":
		return a if extra > 0 else 0
	return a if kind in ["bridge_ten", "addition"] else 0


func is_complete() -> bool:
	if kind == "task_card":
		return false
	if kind == "pattern":
		return pattern_complete
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
	if (
		kind in ["invalid", "plant_parts", "english_objects", "pattern"]
		or is_complete()
		or token < 0
		or token >= token_count()
	):
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
	if (
		kind != "english_objects"
		or english_complete
		or index < 0
		or index >= english_objects.size()
	):
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


func pattern_group() -> Array[String]:
	if kind != "pattern":
		return []
	return pattern_sequence.slice(0, pattern_period)


func select_pattern_candidate(index: int) -> bool:
	if kind != "pattern" or pattern_complete or index < 0 or index >= pattern_choices.size():
		return false
	# Selection is only a proposal. Repeated input cannot reopen a confirmation.
	if pattern_candidate != index:
		_pattern_candidate_confirmed = false
	pattern_candidate = index
	_pattern_last_action = "select"
	return true


func clear_pattern_candidate() -> void:
	if kind != "pattern" or pattern_complete:
		return
	pattern_candidate = -1
	_pattern_candidate_confirmed = false
	_pattern_last_action = ""


func confirm_pattern_candidate() -> bool:
	if (
		kind != "pattern"
		or pattern_complete
		or pattern_candidate < 0
		or pattern_candidate >= pattern_choices.size()
	):
		return false
	if _pattern_candidate_confirmed:
		return false
	_pattern_candidate_confirmed = true
	_pattern_last_action = "confirm"
	pattern_attempts += 1
	var next_token := pattern_sequence[pattern_sequence.size() % pattern_period]
	pattern_complete = pattern_choices[pattern_candidate] == next_token
	return pattern_complete


func pattern_hint() -> String:
	if kind != "pattern" or pattern_complete:
		return ""
	pattern_hint_level = mini(3, pattern_hint_level + 1)
	_pattern_last_action = "hint"
	return _pattern_hint_text()


func _pattern_hint_text() -> String:
	match pattern_hint_level:
		1:
			return (
				"Die kleinste Gruppe hat %d Zeichen. Suche dieselbe Gruppe noch einmal."
				% pattern_period
			)
		2:
			return "Vergleiche die ersten beiden Gruppen. Die Zeichen stehen in derselben Reihenfolge."
		3:
			return (
				"Als Nächstes ist Stelle %d der Gruppe dran. Schau dort nach und wähle selbst."
				% [pattern_sequence.size() % pattern_period + 1]
			)
	return ""


func explanation() -> String:
	match kind:
		"task_card":
			if task_choice >= 0:
				return (
					"Dein Vorschlag: %s. In deiner Aufgabe kannst du ihn prüfen und bestätigen."
					% task_choices[task_choice]
				)
			return task_prompt if task_prompt.length() <= 220 else task_prompt.left(217) + "…"
		"pattern":
			if pattern_complete:
				return "Die Reihenfolge passt. Kehre zur Aufgabe zurück und gib dort deine Antwort."
			if _pattern_last_action == "confirm":
				return "Das passt noch nicht zur Wiederholung. Vergleiche die Gruppen oder hole einen Hinweis."
			if _pattern_last_action == "select":
				return (
					"Dein Vorschlag ist „%s“. Du kannst ihn ändern oder ausdrücklich prüfen."
					% pattern_choices[pattern_candidate]
				)
			if pattern_hint_level > 0:
				return _pattern_hint_text()
			return "Welche Gruppe wiederholt sich? Hole einen Hinweis oder wähle selbst das nächste Zeichen."
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


static func pattern_label(value: String) -> String:
	var parts := value.split("_")
	var forms := {
		"circle": "Kreis",
		"square": "Quadrat",
		"triangle": "Dreieck",
		"star": "Stern",
		"heart": "Herz",
		"diamond": "Raute"
	}
	var colors := {
		"red": "Rot",
		"blue": "Blau",
		"yellow": "Gelb",
		"green": "Grün",
		"purple": "Violett",
		"orange": "Orange"
	}
	return (
		str(forms.get(parts[-1], value))
		if parts.size() == 1
		else "%s · %s" % [forms.get(parts[-1], value), colors.get(parts[0], "")]
	)


func companion_explanation(request: String) -> Dictionary:
	# Small, transparent local explanations are derived from checked operands.
	# This helper cannot award, score or apply an answer to the original task.
	var words := request.to_lower()
	var command := words.strip_edges().trim_suffix(".").trim_suffix("!").strip_edges()
	if (
		command
		in [
			"stop",
			"stopp",
			"bitte stop",
			"bitte stopp",
			"stop bitte",
			"stopp bitte",
			"hör auf",
			"halte an"
		]
	):
		return {
			"reply": "Ich habe angehalten. Du kannst in deinem Tempo weitermachen.",
			"action": "stop"
		}
	if (
		kind in ["bridge_ten", "addition"]
		and a < 10
		and a + b > 10
		and (words.contains("warum") or words.contains("zuerst"))
	):
		var needed := 10 - a
		return {
			"reply":
			(
				"Bis zur Zehn fehlen %d: zehn minus %d ist %d. Von den %d nehmen wir zuerst %d. Dann bleiben %d übrig."
				% [needed, a, needed, b, needed, a + b - 10]
			),
			"action": "explain",
			"objectId": "bridge_two" if needed == 2 else "bridge_needed"
		}
	if kind == "syllables":
		return {
			"reply":
			"%s: %s. Jede Silbe bekommt einen eigenen Baustein." % [word, " – ".join(syllables)],
			"action": "explain",
			"objectId": "syllable_0"
		}
	if kind == "pattern":
		return {
			"reply":
			"Schau auf die markierte Gruppe. Danach beginnt dieselbe Gruppe von vorn. Suche das nächste Zeichen selbst.",
			"action": "hint",
			"objectId": "pattern_group"
		}
	if kind == "task_card":
		return {
			"reply":
			(
				task_explanation
				if not task_explanation.is_empty()
				else "Lies den Auftrag in Ruhe. Was ist gegeben, und was sollst du herausfinden? Du kannst einen Antwortvorschlag wählen und ihn anschließend in deiner Aufgabe prüfen."
			),
			"action": "explain",
			"objectId": "task_prompt"
		}
	return {"reply": explanation(), "action": "explain"}


func _configure_task_card(raw: Dictionary) -> bool:
	var prompt: Variant = raw.get("prompt", raw.get("taskPrompt", ""))
	var subject: Variant = raw.get("subject", "")
	var unit: Variant = raw.get("unit", "")
	var help: Variant = raw.get("explanation", "")
	var choices: Variant = raw.get("answerChoices", [])
	if not prompt is String or prompt.strip_edges().is_empty() or prompt.length() > 800:
		return false
	if not subject is String or subject.length() > 80 or not unit is String or unit.length() > 80:
		return false
	if not help is String or help.length() > 1200 or not choices is Array or choices.size() > 8:
		return false
	task_choices.clear()
	for choice in choices:
		if (
			not choice is String
			or choice.strip_edges().is_empty()
			or choice.length() > 120
			or choice in task_choices
		):
			return false
		task_choices.append(choice)
	task_prompt = prompt
	task_subject = subject
	task_unit = unit
	task_explanation = help
	return true


func propose_task_answer(index: int) -> bool:
	if kind != "task_card" or index < 0 or index >= task_choices.size():
		return false
	task_choice = index
	return true
