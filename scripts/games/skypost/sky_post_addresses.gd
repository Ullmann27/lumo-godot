extends RefCounted
## Addresses of the deliveries as small riddles that fit the child's class:
## house numbers as sums (Mathematik), the house with the Tunwort / Namenwort /
## Wiewort (Deutsch), the delivery time on a clock (Uhrzeit, volle und halbe
## Stunde). Every riddle has exactly three answers, one per house of a district,
## and exactly one is right. Without riddles the address is the plain number.
##
## Word lists are checked: Tunwörter in der Grundform, Namenwörter großgeschrieben
## mit eindeutiger Wortart (kein "Essen"/"essen"), Wiewörter ohne zweite Bedeutung.

const VERBS: Array[String] = [
	"laufen",
	"springen",
	"lachen",
	"singen",
	"malen",
	"lesen",
	"schreiben",
	"schwimmen",
	"fliegen",
	"spielen",
	"tanzen",
	"trinken",
	"schlafen",
	"bauen",
	"rufen",
	"winken",
]
const NOUNS: Array[String] = [
	"Hund",
	"Katze",
	"Baum",
	"Blume",
	"Ball",
	"Buch",
	"Schule",
	"Sonne",
	"Apfel",
	"Vogel",
	"Brief",
	"Wolke",
	"Fisch",
	"Stern",
	"Tisch",
	"Mond",
]
const ADJECTIVES: Array[String] = [
	"groß",
	"klein",
	"rot",
	"blau",
	"schnell",
	"langsam",
	"leise",
	"warm",
	"kalt",
	"hell",
	"dunkel",
	"rund",
	"weich",
	"lustig",
	"müde",
	"süß",
]
const CLASSES := {
	"verb": {"name": "Tunwort", "hint": "Ein Tunwort sagt, was man tut: laufen, lachen, malen."},
	"noun": {"name": "Namenwort", "hint": "Ein Namenwort schreibt man groß: der Hund, die Sonne."},
	"adjective": {"name": "Wiewort", "hint": "Ein Wiewort sagt, wie etwas ist: groß, rot, leise."},
}
const HOUR_WORDS: Array[String] = [
	"zwölf",
	"eins",
	"zwei",
	"drei",
	"vier",
	"fünf",
	"sechs",
	"sieben",
	"acht",
	"neun",
	"zehn",
	"elf",
	"zwölf"
]
const RECIPIENTS: Array[String] = [
	"Frau Möwe",
	"Herrn Igel",
	"Oma Biber",
	"Kapitän Pinguin",
	"Familie Maus",
	"Frau Taube",
	"Herrn Dachs",
	"Tante Ente",
	"Opa Schaf",
	"Familie Hase",
	"Frau Robbe",
	"Herrn Maulwurf",
]


## Kind of riddle for delivery [param index] (alternates where the class allows it).
static func kind_for(subject: String, grade: int, index: int) -> String:
	if subject == "Deutsch":
		return "word"
	if grade >= 2 and index % 3 == 2:
		return "clock"
	if grade == 1 and index % 4 == 3:
		return "clock"
	return "math"


## {kind, prompt, short, answers: [3 board texts], answer: index 0..2, hint, spoken}
static func make(
	kind: String, grade: int, rng: RandomNumberGenerator, plain: bool = false
) -> Dictionary:
	var riddle: Dictionary
	match kind:
		"word":
			riddle = _word(grade, rng)
		"clock":
			riddle = _clock(grade, rng)
		_:
			riddle = _math(grade, rng, plain)
	return riddle


static func _shuffle_answers(right: String, wrong: Array, rng: RandomNumberGenerator) -> Dictionary:
	var answers: Array[String] = [right, str(wrong[0]), str(wrong[1])]
	for index in range(answers.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var keep: String = answers[index]
		answers[index] = answers[other]
		answers[other] = keep
	return {"answers": answers, "answer": answers.find(right)}


static func _math(grade: int, rng: RandomNumberGenerator, plain: bool) -> Dictionary:
	var a: int
	var b: int
	var result: int
	var text: String
	var minus: bool = grade >= 2 and rng.randf() < 0.4
	if grade <= 2:
		var limit: int = 10 if grade == 1 else 20
		if minus:
			result = rng.randi_range(2, limit - 3)
			b = rng.randi_range(1, limit - result)
			a = result + b
			text = "%d − %d" % [a, b]
		else:
			result = rng.randi_range(4, limit)
			a = rng.randi_range(1, result - 1)
			b = result - a
			text = "%d + %d" % [a, b]
	elif grade == 3:
		a = rng.randi_range(2, 9)
		b = rng.randi_range(2, 9)
		result = a * b
		text = "%d · %d" % [a, b]
	else:
		if rng.randf() < 0.5:
			a = rng.randi_range(3, 9)
			b = rng.randi_range(3, 9)
			result = a * b
			text = "%d · %d" % [a, b]
		else:
			a = rng.randi_range(2, 9) * 10
			b = rng.randi_range(11, 49)
			result = a + b
			text = "%d + %d" % [a, b]
	var wrong: Array[int] = []
	var offsets: Array[int] = [1, -1, 2, -2, 10, -10, 3]
	if grade >= 3:
		offsets = [a, -a, b, -b, 1, -1, 10, -10]
	for offset in offsets:
		var candidate: int = result + offset
		if candidate > 0 and candidate != result and not wrong.has(candidate):
			wrong.append(candidate)
		if wrong.size() == 2:
			break
	var picked: Dictionary = _shuffle_answers(str(result), wrong, rng)
	if plain:
		return {
			"kind": "number",
			"prompt": "Haus %d" % result,
			"short": "Haus %d" % result,
			"answers": picked.answers,
			"answer": picked.answer,
			"hint": "Such das Haus mit der Nummer %d." % result,
		}
	return {
		"kind": "math",
		"prompt": "Haus %s" % text,
		"short": "Haus %s = ?" % text,
		"answers": picked.answers,
		"answer": picked.answer,
		"hint": "Rechne %s. Das Ergebnis ist die Hausnummer." % text,
		"solution": "%s = %d" % [text, result],
	}


static func _word(grade: int, rng: RandomNumberGenerator) -> Dictionary:
	var classes: Array[String] = ["verb", "noun"]
	if grade >= 2:
		classes.append("adjective")
	var target: String = classes[rng.randi_range(0, classes.size() - 1)]
	var pools := {"verb": VERBS, "noun": NOUNS, "adjective": ADJECTIVES}
	var others: Array[String] = ["verb", "noun", "adjective"]
	others.erase(target)
	if grade < 2:
		var other: String = "noun" if target == "verb" else "verb"
		others.assign([other, other])
	var right: String = pools[target][rng.randi_range(0, pools[target].size() - 1)]
	var wrong: Array[String] = []
	for other in others:
		var pool: Array = pools[other]
		for attempt in range(10):
			var word: String = pool[rng.randi_range(0, pool.size() - 1)]
			if not wrong.has(word):
				wrong.append(word)
				break
	var picked: Dictionary = _shuffle_answers(right, wrong, rng)
	var name: String = CLASSES[target].name
	return {
		"kind": "word",
		"prompt": "Haus mit dem %s" % name,
		"short": "Haus mit dem %s" % name,
		"answers": picked.answers,
		"answer": picked.answer,
		"hint": CLASSES[target].hint,
		"solution": "„%s“ ist ein %s." % [right, name],
	}


## Board text "clock:H:M". Grade 1: full hours, from grade 2 also half hours.
static func _clock(grade: int, rng: RandomNumberGenerator) -> Dictionary:
	var hour: int = rng.randi_range(1, 11)
	var half: bool = grade >= 2 and rng.randf() < 0.65
	var right: String = "clock:%d:%d" % [hour, 30 if half else 0]
	var wrong: Array[String] = []
	if half:
		wrong.append("clock:%d:30" % (hour % 12 + 1))
		wrong.append("clock:%d:0" % hour)
	else:
		wrong.append("clock:%d:0" % (hour % 12 + 1))
		wrong.append("clock:%d:0" % ((hour + 9) % 12 + 1))
	var spoken: String = "halb %s" % HOUR_WORDS[hour + 1] if half else "%d Uhr" % hour
	var picked: Dictionary = _shuffle_answers(right, wrong, rng)
	var hint: String = (
		"Bei „halb“ zeigt der große Zeiger nach unten auf die 6. Der kleine steht dazwischen."
		if half
		else "Bei einer vollen Stunde zeigt der große Zeiger nach oben auf die 12."
	)
	return {
		"kind": "clock",
		"prompt": "Lieferung um %s" % spoken,
		"short": "um %s" % spoken,
		"answers": picked.answers,
		"answer": picked.answer,
		"hint": hint,
		"solution": "Die Uhr zeigt %s." % spoken,
	}


static func valid(riddle: Dictionary) -> bool:
	if typeof(riddle.get("prompt")) != TYPE_STRING or typeof(riddle.get("answers")) != TYPE_ARRAY:
		return false
	var answers: Array = riddle.answers
	if answers.size() != 3 or typeof(riddle.get("answer")) != TYPE_INT:
		return false
	var seen: Dictionary = {}
	for text in answers:
		if typeof(text) != TYPE_STRING or str(text).is_empty() or seen.has(text):
			return false
		seen[text] = true
	return int(riddle.answer) >= 0 and int(riddle.answer) < 3
