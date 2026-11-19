# gdlint: disable=max-returns
# Strenge Prüfungen kehren bei jedem ungültigen Feld sofort zurück.
extends RefCounted
## Geprüfter Ablauf der Holo-Lernräume (Textaufgabe mit Zehnerübergang,
## Tunwort im Satz, Satzbau, Namenwort im Satz). Flutter liefert Aufgabe und Zwillingsaufgabe aus
## dem Aufgabenkatalog; diese Klasse prüft die Daten streng, hält den Zustand
## und bewertet nur Eingaben des Kindes. Sie vergibt nichts und speichert nichts:
## Das Ergebnis geht einmal als Zusammenfassung an die App zurück.

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")
const KINDS: Array[String] = ["holo_word_problem", "holo_sentence"]
## verb = Tunwort finden, order = Satz bauen, noun = Namenwort finden.
const MODES: Array[String] = ["verb", "order", "noun"]
const DEMOS: Array[String] = ["jump", "wave", "nod", "none"]
const TEXT_LIMIT := 240
const WORD_LIMIT := 18
## Hilfestufen: 0 keine, 1 Blick auf die Mengen/Wörter, 2 ausführliche Hilfe.
const HINT_FOCUS := 1
const HINT_FULL := 2

var kind := ""
var mode := ""
var source_task_id := ""
## "original" → "twin" → "done"
var phase := "original"
var tasks: Array[Dictionary] = []
var hint_level := 0
var attempts := 0
var wrong := 0
var original_answer := ""
var original_correct := false
var original_attempts := 0
var original_hint := 0
var twin_attempts := 0
var twin_solved := false
var last_outcome := ""
## Mathe: Äpfel im Zehnerfeld (Index der Äpfel 0..a+b-1 → Feld 0..19 oder -1).
var slot_of: Array[int] = []
var counted: Array[int] = []
## Satzbau: Kartenreihenfolge (gemischt) und gelegte Karten.
var shuffled: Array[int] = []
var placed: Array[int] = []


func configure(raw: Dictionary) -> bool:
	tasks.clear()
	kind = str(raw.get("kind", ""))
	if kind not in KINDS:
		return false
	source_task_id = str(raw.get("sourceTaskId", ""))
	if source_task_id.length() > 120 or not _plain(source_task_id):
		return false
	var first: Dictionary
	var second: Dictionary
	if kind == "holo_word_problem":
		mode = "add"
		first = _check_math(raw)
		var twin: Variant = raw.get("twin")
		second = _check_math(twin) if twin is Dictionary else {}
		if first.is_empty() or second.is_empty():
			return false
		if first.sum == second.sum or (first.a == second.a and first.b == second.b):
			return false
		if str(first.story) != str(second.story):
			return false
	else:
		mode = str(raw.get("mode", ""))
		if mode not in MODES:
			return false
		first = _check_sentence(raw)
		var twin_sentence: Variant = raw.get("twin")
		second = _check_sentence(twin_sentence) if twin_sentence is Dictionary else {}
		if first.is_empty() or second.is_empty() or first.sentence == second.sentence:
			return false
	tasks.append(first)
	tasks.append(second)
	_reset_phase("original")
	return true


func _check_math(raw: Dictionary) -> Dictionary:
	if not _int_in(raw.get("a"), 2, 9) or not _int_in(raw.get("b"), 2, 9):
		return {}
	var a := int(raw.a)
	var b := int(raw.b)
	# Nur echte Zehnerübergänge bis 20: das Zehnerfeld zeigt a + (10 - a) + Rest.
	if a + b <= 10 or a + b > 20:
		return {}
	var story := str(raw.get("story", ""))
	if story not in ["korb_aepfel"]:
		return {}
	var prompt := _text(raw.get("prompt", ""))
	if prompt.is_empty() or not prompt.contains(str(a)) or not prompt.contains(str(b)):
		return {}
	var raw_choices: Variant = raw.get("choices")
	if not raw_choices is Array or raw_choices.size() < 3 or raw_choices.size() > 4:
		return {}
	var choices: Array[int] = []
	for item: Variant in raw_choices:
		if not _int_in(item, 0, 40) or choices.has(int(item)):
			return {}
		choices.append(int(item))
	if not choices.has(a + b):
		return {}
	return {"a": a, "b": b, "sum": a + b, "story": story, "prompt": prompt, "choices": choices}


func _check_sentence(raw: Dictionary) -> Dictionary:
	var sentence := _text(raw.get("sentence", ""))
	var raw_words: Variant = raw.get("words")
	if sentence.is_empty() or not raw_words is Array:
		return {}
	if raw_words.size() < 3 or raw_words.size() > 6:
		return {}
	var words: Array[String] = []
	for item: Variant in raw_words:
		if not item is String:
			return {}
		var word := str(item)
		if word.is_empty() or word.length() > WORD_LIMIT or word.strip_edges() != word:
			return {}
		if word.contains(" ") or word.ends_with(".") or not _plain(word):
			return {}
		words.append(word)
	if " ".join(words) + "." != sentence:
		return {}
	if not _int_in(raw.get("verbIndex"), 0, words.size() - 1):
		return {}
	var question := _text(raw.get("question", ""))
	if question.is_empty() or not question.ends_with("?"):
		return {}
	var demo := str(raw.get("demo", "none"))
	if demo not in DEMOS:
		return {}
	# Satzbau braucht eindeutige Karten, sonst wäre jede Vertauschung richtig.
	var unique := {}
	for word in words:
		unique[word] = true
	if mode == "order" and unique.size() != words.size():
		return {}
	var checked := {
		"sentence": sentence,
		"words": words,
		"verbIndex": int(raw.verbIndex),
		"question": question,
		"demo": demo,
	}
	if mode == "noun":
		# Namenwort finden: genau ein gesuchtes Wort und ein bekanntes Bild,
		# das erst nach der richtigen Wahl erscheint.
		if not _int_in(raw.get("nounIndex"), 0, words.size() - 1):
			return {}
		if int(raw.nounIndex) == int(raw.verbIndex):
			return {}
		var picture := str(raw.get("picture", ""))
		if picture not in MODELS.PICTURES:
			return {}
		checked["nounIndex"] = int(raw.nounIndex)
		checked["picture"] = picture
	return checked


func current() -> Dictionary:
	if phase in ["twin", "done"]:
		return tasks[1]
	return tasks[0]


func choices() -> Array:
	if kind == "holo_word_problem":
		return current().choices
	return current().words


func _reset_phase(next_phase: String) -> void:
	phase = next_phase
	attempts = 0
	wrong = 0
	last_outcome = ""
	var task := current()
	slot_of.clear()
	counted.clear()
	shuffled.clear()
	placed.clear()
	if kind == "holo_word_problem":
		for index in range(int(task.sum)):
			slot_of.append(-1)
			counted.append(0)
	else:
		for index in range(task.words.size()):
			shuffled.append(index)
		_shuffle_cards(task.sentence.hash())


## Deterministisch gemischt, aber nie in der richtigen Reihenfolge und nie
## mit dem ersten Wort vorn: Die Lage verrät keine Lösung.
func _shuffle_cards(seed_value: int) -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = absi(seed_value) + 17
	for attempt in range(24):
		for index in range(shuffled.size() - 1, 0, -1):
			var other := generator.randi_range(0, index)
			var keep := shuffled[index]
			shuffled[index] = shuffled[other]
			shuffled[other] = keep
		if shuffled[0] != 0 and not _is_identity(shuffled):
			return
	# Fallback: einmal rotieren (ist bei ≥ 3 Karten nie die Identität).
	shuffled.clear()
	for index in range(current().words.size()):
		shuffled.append((index + 1) % current().words.size())


static func _is_identity(order: Array[int]) -> bool:
	for index in range(order.size()):
		if order[index] != index:
			return false
	return true


## Antwort auf die aktuelle Aufgabe. Liefert "correct", "wrong" oder "ignored".
func answer(value: String) -> String:
	if phase == "done":
		return "ignored"
	var task := current()
	var right := false
	match kind:
		"holo_word_problem":
			if not value.is_valid_int():
				return "ignored"
			right = int(value) == int(task.sum)
		"holo_sentence":
			if mode == "verb":
				if not task.words.has(value):
					return "ignored"
				right = value == task.words[task.verbIndex]
			elif mode == "noun":
				if not task.words.has(value):
					return "ignored"
				right = value == task.words[task.nounIndex]
			else:
				right = value == task.sentence
	attempts += 1
	if phase == "original":
		original_attempts = attempts
		original_answer = value
	if not right:
		wrong += 1
		last_outcome = "wrong"
		return "wrong"
	last_outcome = "correct"
	if phase == "original":
		original_correct = true
		original_hint = hint_level
	else:
		twin_solved = true
		twin_attempts = attempts
		phase = "done"
	return "correct"


## Nach der Originalaufgabe: dieselbe Struktur mit anderen Zahlen/Wörtern.
func start_twin() -> bool:
	if phase != "original" or not original_correct:
		return false
	_reset_phase("twin")
	return true


## Nächste Hilfestufe in fester Reihenfolge; nie überspringen.
func request_hint() -> int:
	if phase == "done":
		return hint_level
	if phase == "twin":
		# Die Zwillingsaufgabe löst das Kind selbstständig. Ein Tipp bleibt
		# erlaubt, die ausführliche Lösung wird nicht noch einmal vorgerechnet.
		return HINT_FOCUS
	hint_level = mini(HINT_FULL, hint_level + 1)
	return hint_level


## Mathe: Zählen am Apfel. Liefert die Zahl, die am Apfel erscheint.
func count_apple(index: int) -> int:
	if kind != "holo_word_problem" or index < 0 or index >= counted.size():
		return 0
	if counted[index] > 0:
		return counted[index]
	var a := int(current().a)
	var first := 0 if index < a else a
	var last := a if index < a else counted.size()
	var number := 1
	for other in range(first, last):
		if counted[other] > 0:
			number += 1
	counted[index] = number
	return number


func group_count(group: int) -> int:
	var a := int(current().a)
	var total := 0
	for index in range(counted.size()):
		if counted[index] > 0 and ((index < a) == (group == 0)):
			total += 1
	return total


## Mathe: Apfel ins Zehnerfeld legen (erstes freies Feld) oder zurück.
func toggle_frame(index: int) -> int:
	if kind != "holo_word_problem" or index < 0 or index >= slot_of.size():
		return -1
	if slot_of[index] >= 0:
		slot_of[index] = -1
		return -1
	var used := {}
	for slot in slot_of:
		if slot >= 0:
			used[slot] = true
	for slot in range(20):
		if not used.has(slot):
			slot_of[index] = slot
			return slot
	return -1


func frame_filled() -> int:
	var total := 0
	for slot in slot_of:
		if slot >= 0:
			total += 1
	return total


## Ausführliche Hilfe: erst alle a, dann (10 - a) aus der zweiten Gruppe,
## danach der Rest ins zweite Zehnerfeld. Liefert die Zuordnung Apfel → Feld.
func ten_bridge_layout() -> Array[int]:
	var task := current()
	var layout: Array[int] = []
	for index in range(int(task.sum)):
		layout.append(index)
	return layout


func bridge_parts() -> Vector2i:
	var task := current()
	var fill := 10 - int(task.a)
	return Vector2i(fill, int(task.b) - fill)


## Satzbau: Karte (Index im Satz) an die nächste freie Stelle legen.
func place_card(word_index: int) -> bool:
	if mode != "order" or placed.has(word_index):
		return false
	if word_index < 0 or word_index >= current().words.size():
		return false
	placed.append(word_index)
	return true


func take_back(word_index: int) -> bool:
	var at := placed.find(word_index)
	if at < 0:
		return false
	placed.remove_at(at)
	return true


func built_sentence() -> String:
	var words: Array[String] = []
	for index in placed:
		words.append(current().words[index])
	return " ".join(words) + "."


func summary(result_id: String) -> Dictionary:
	return {
		"resultId": result_id,
		"taskId": source_task_id,
		"kind": kind,
		"mode": mode,
		"originalAnswer": original_answer if original_correct else "",
		"originalCorrect": original_correct,
		"originalAttempts": original_attempts,
		"hintLevel": original_hint if original_correct else hint_level,
		"twinSolved": twin_solved,
		"twinAttempts": twin_attempts,
		"twinPrompt": str(tasks[1].get("prompt", tasks[1].get("sentence", ""))),
	}


static func _int_in(value: Variant, low: int, high: int) -> bool:
	if typeof(value) == TYPE_FLOAT:
		if not is_finite(value) or value != floorf(value):
			return false
	elif typeof(value) != TYPE_INT:
		return false
	return int(value) >= low and int(value) <= high


static func _plain(value: String) -> bool:
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029]:
			return false
	return true


static func _text(value: Variant) -> String:
	if not value is String:
		return ""
	var text := str(value).strip_edges()
	if text.length() > TEXT_LIMIT or not _plain(text):
		return ""
	return text
