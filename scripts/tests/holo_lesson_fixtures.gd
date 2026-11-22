extends RefCounted
## Aufgaben genau so, wie die App sie aus dem Aufgabenkatalog sendet
## (lib/domain/learning/holo_lesson_catalog.dart).


static func math(a: int = 8, b: int = 5, twin_a: int = 6, twin_b: int = 8) -> Dictionary:
	return {
		"kind": "holo_word_problem",
		"sourceTaskId": "task-korb-%d-%d" % [a, b],
		"story": "korb_aepfel",
		"a": a,
		"b": b,
		"prompt": prompt(a, b),
		"choices": choices(a, b),
		"twin":
		{
			"story": "korb_aepfel",
			"a": twin_a,
			"b": twin_b,
			"prompt": prompt(twin_a, twin_b),
			"choices": choices(twin_a, twin_b),
		},
	}


static func prompt(a: int, b: int) -> String:
	return "Im Korb liegen %d Äpfel. Lumo legt %d dazu. Wie viele sind es jetzt?" % [a, b]


static func choices(a: int, b: int) -> Array:
	var sum := a + b
	return [sum - 1, sum, sum + 1, sum - 10]


static func verb() -> Dictionary:
	return {
		"kind": "holo_sentence",
		"mode": "verb",
		"sourceTaskId": "task-fuchs-verb",
		"sentence": "Der kleine Fuchs springt.",
		"words": ["Der", "kleine", "Fuchs", "springt"],
		"types": ["artikel", "adjektiv", "nomen", "verb"],
		"verbIndex": 3,
		"question": "Was tut der Fuchs?",
		"demo": "jump",
		"twin":
		{
			"sentence": "Die Ente schwimmt im Teich.",
			"words": ["Die", "Ente", "schwimmt", "im", "Teich"],
			"types": ["artikel", "nomen", "verb", "andere", "nomen"],
			"verbIndex": 2,
			"question": "Was tut die Ente?",
			"demo": "none",
		},
	}


static func order() -> Dictionary:
	return {
		"kind": "holo_sentence",
		"mode": "order",
		"sourceTaskId": "task-fuchs-satz",
		"sentence": "Der kleine Fuchs springt.",
		"words": ["Der", "kleine", "Fuchs", "springt"],
		"types": ["artikel", "adjektiv", "nomen", "verb"],
		"verbIndex": 3,
		"question": "Was tut der Fuchs?",
		"demo": "jump",
		"twin":
		{
			"sentence": "Mia malt ein Bild.",
			"words": ["Mia", "malt", "ein", "Bild"],
			"types": ["nomen", "verb", "artikel", "nomen"],
			"verbIndex": 1,
			"question": "Was tut Mia?",
			"demo": "none",
		},
	}


## Namenwort finden: Sätze mit genau einem Namenwort; das Bild (Hologramm)
## erscheint erst nach der richtigen Wahl über der Karte.
static func noun() -> Dictionary:
	return {
		"kind": "holo_sentence",
		"mode": "noun",
		"sourceTaskId": "task-fuchs-namenwort",
		"sentence": "Der kleine Fuchs springt.",
		"words": ["Der", "kleine", "Fuchs", "springt"],
		"types": ["artikel", "adjektiv", "nomen", "verb"],
		"verbIndex": 3,
		"nounIndex": 2,
		"picture": "fuchs",
		"question": "Wer springt?",
		"demo": "none",
		"twin":
		{
			"sentence": "Die Katze schläft.",
			"words": ["Die", "Katze", "schläft"],
			"types": ["artikel", "nomen", "verb"],
			"verbIndex": 2,
			"nounIndex": 1,
			"picture": "katze",
			"question": "Wer schläft?",
			"demo": "none",
		},
	}


## Silben klatschen: „Banane“ (Ba-na-ne), ähnliches Wort „Sonne“ (Son-ne).
static func syllables(
	word: String = "Banane",
	parts: Array = ["Ba", "na", "ne"],
	picture: String = "banane",
	twin_word: String = "Sonne",
	twin_parts: Array = ["Son", "ne"],
	twin_picture: String = "sonne"
) -> Dictionary:
	return {
		"kind": "holo_sentence",
		"mode": "syllables",
		"sourceTaskId": "task-silben-%s" % word.to_lower(),
		"word": word,
		"syllables": parts,
		"picture": picture,
		"prompt": "Wie viele Silben hat %s?" % word,
		"twin":
		{
			"word": twin_word,
			"syllables": twin_parts,
			"picture": twin_picture,
			"prompt": "Wie viele Silben hat %s?" % twin_word,
		},
	}


static func adjective() -> Dictionary:
	return {
		"kind": "holo_sentence",
		"mode": "adjective",
		"sourceTaskId": "task-fuchs-wiewort",
		"sentence": "Der kleine Fuchs springt.",
		"words": ["Der", "kleine", "Fuchs", "springt"],
		"types": ["artikel", "adjektiv", "nomen", "verb"],
		"verbIndex": 3,
		"adjIndex": 1,
		"picture": "fuchs",
		"contrast": "size",
		"look": "klein",
		"question": "Welches Wort sagt, wie der Fuchs ist?",
		"demo": "none",
		"twin":
		{
			"sentence": "Der gelbe Ball rollt.",
			"words": ["Der", "gelbe", "Ball", "rollt"],
			"types": ["artikel", "adjektiv", "nomen", "verb"],
			"verbIndex": 3,
			"adjIndex": 1,
			"picture": "ball",
			"contrast": "color",
			"look": "gelb",
			"question": "Welches Wort sagt, wie der Ball ist?",
			"demo": "none",
		},
	}


static func reading() -> Dictionary:
	return {
		"kind": "holo_sentence",
		"mode": "reading",
		"sourceTaskId": "task-ball-unter",
		"sentence": "Der Ball liegt unter dem Tisch.",
		"words": ["Der", "Ball", "liegt", "unter", "dem", "Tisch"],
		"keyIndex": 3,
		"object": "ball",
		"place": "tisch",
		"scenes": ["darauf", "darunter", "daneben"],
		"answer": "darunter",
		"question": "Wo liegt der Ball?",
		"twin":
		{
			"sentence": "Die Katze sitzt in der Kiste.",
			"words": ["Die", "Katze", "sitzt", "in", "der", "Kiste"],
			"keyIndex": 3,
			"object": "katze",
			"place": "kiste",
			"scenes": ["daneben", "davor", "darin"],
			"answer": "darin",
			"question": "Wo sitzt die Katze?",
		},
	}
