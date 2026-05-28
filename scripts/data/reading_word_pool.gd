## ReadingWordPool - zentrales Daten-Repository für alle Lese-Mini-Games.
##
## Statisches Wort-Inventar: 26 Wörter A-Z, jedes mit Emoji-Bild, Wort,
## Anfangsbuchstabe und vorberechnetem Distraktor-Set (für Multiple-Choice).
##
## Wird von word_picture_match, sound_letter_match, word_build genutzt.
class_name ReadingWordPool
extends RefCounted

const WORDS: Array[Dictionary] = [
	{"letter": "a", "word": "Apfel", "emoji": "🍎"},
	{"letter": "b", "word": "Ball", "emoji": "⚽"},
	{"letter": "c", "word": "Clown", "emoji": "🤡"},
	{"letter": "d", "word": "Drache", "emoji": "🐉"},
	{"letter": "e", "word": "Esel", "emoji": "🫏"},
	{"letter": "f", "word": "Fisch", "emoji": "🐟"},
	{"letter": "g", "word": "Giraffe", "emoji": "🦒"},
	{"letter": "h", "word": "Haus", "emoji": "🏠"},
	{"letter": "i", "word": "Igel", "emoji": "🦔"},
	{"letter": "j", "word": "Jacke", "emoji": "🧥"},
	{"letter": "k", "word": "Katze", "emoji": "🐱"},
	{"letter": "l", "word": "Lampe", "emoji": "💡"},
	{"letter": "m", "word": "Maus", "emoji": "🐭"},
	{"letter": "n", "word": "Nashorn", "emoji": "🦏"},
	{"letter": "o", "word": "Orange", "emoji": "🍊"},
	{"letter": "p", "word": "Pinguin", "emoji": "🐧"},
	{"letter": "q", "word": "Quark", "emoji": "🥛"},
	{"letter": "r", "word": "Rabe", "emoji": "🐦"},
	{"letter": "s", "word": "Sonne", "emoji": "☀️"},
	{"letter": "t", "word": "Tiger", "emoji": "🐯"},
	{"letter": "u", "word": "Uhu", "emoji": "🦉"},
	{"letter": "v", "word": "Vogel", "emoji": "🦅"},
	{"letter": "w", "word": "Wolke", "emoji": "☁️"},
	{"letter": "x", "word": "Xylophon", "emoji": "🎹"},
	{"letter": "y", "word": "Yacht", "emoji": "⛵"},
	{"letter": "z", "word": "Zebra", "emoji": "🦓"},
]


## Liefert eine zufaellige Frage: 1 richtiges Wort + 3 Distraktor-
## Buchstaben (zufaellig aus dem Alphabet, ohne richtigen Buchstaben).
##
## Rueckgabe: {word, emoji, letter (richtig), choices (4 gemischt)}
static func random_question() -> Dictionary:
	var entry: Dictionary = WORDS[randi() % WORDS.size()]
	var correct: String = entry["letter"]
	var pool: Array[String] = []
	for w in WORDS:
		if w["letter"] != correct:
			pool.append(w["letter"])
	pool.shuffle()
	var distractors: Array[String] = []
	for i in range(3):
		distractors.append(pool[i])
	var choices: Array[String] = [correct]
	choices.append_array(distractors)
	choices.shuffle()
	return {
		"word": entry["word"],
		"emoji": entry["emoji"],
		"letter": correct,
		"choices": choices,
	}


## Liefert N verschiedene zufaellige Fragen (ohne Duplikate).
static func random_questions(n: int) -> Array[Dictionary]:
	var indices: Array[int] = []
	for i in range(WORDS.size()):
		indices.append(i)
	indices.shuffle()
	var result: Array[Dictionary] = []
	for i in range(min(n, indices.size())):
		var entry: Dictionary = WORDS[indices[i]]
		var correct: String = entry["letter"]
		var distractor_pool: Array[String] = []
		for w in WORDS:
			if w["letter"] != correct:
				distractor_pool.append(w["letter"])
		distractor_pool.shuffle()
		var choices: Array[String] = [
			correct, distractor_pool[0], distractor_pool[1], distractor_pool[2]
		]
		choices.shuffle()
		(
			result
			. append(
				{
					"word": entry["word"],
					"emoji": entry["emoji"],
					"letter": correct,
					"choices": choices,
				}
			)
		)
	return result


## Liefert N zufaellige Worte fuer das Wort-Bau-Spiel (3-5 Buchstaben).
## Lange Worte rausgefiltert (>5 Buchstaben).
static func short_words(n: int) -> Array[Dictionary]:
	var short: Array[Dictionary] = []
	for w in WORDS:
		if w["word"].length() <= 5:
			short.append(w)
	short.shuffle()
	var result: Array[Dictionary] = []
	for i in range(min(n, short.size())):
		result.append(short[i])
	return result
