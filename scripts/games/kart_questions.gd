class_name KartQuestions
extends RefCounted

const ARTICLES: Array = [
	["Hund", "der"],
	["Sonne", "die"],
	["Haus", "das"],
	["Katze", "die"],
	["Buch", "das"],
	["Baum", "der"],
	["Blume", "die"],
	["Kind", "das"],
	["Ball", "der"],
	["Schule", "die"],
	["Auto", "das"],
	["Apfel", "der"],
]
const RHYMES: Array = [
	["Haus", "Maus", "Baum", "Hut"],
	["Hut", "Mut", "Ball", "Haus"],
	["Ball", "Fall", "Hut", "Sonne"],
	["Rose", "Dose", "Haus", "Buch"],
	["Hund", "rund", "rot", "hell"],
	["Bein", "Stein", "Ball", "Buch"],
]
const STORIES: Array[String] = [
	"Lumo sammelt %d Muscheln. %d kommen dazu. Wie viele sind es?",
	"Im Garten stehen %d Blumen. Lumo pflanzt %d dazu. Wie viele wachsen jetzt?",
	"Auf dem Fest sind %d Kinder. %d kommen noch. Wie viele feiern zusammen?",
	"Im Regal liegen %d Bücher. %d neue kommen dazu. Wie viele sind es jetzt?",
]
const WORLD_FACTS: Array = [
	[
		[
			"Was ziehst du bei Regen an?",
			"Regenjacke",
			"Badehose",
			"Sonnenhut",
			"Eine Regenjacke hält die Regentropfen ab."
		],
		[
			"Was hilft dir im Dunkeln auf dem Schulweg?",
			"Reflektor",
			"Radiergummi",
			"Seifenblase",
			"Reflektoren werfen Licht zurück. Andere sehen dich dadurch besser."
		],
		[
			"Welches Tier legt Eier?",
			"Huhn",
			"Katze",
			"Hund",
			"Hühner legen Eier. Katzen und Hunde bringen lebende Junge zur Welt."
		],
		[
			"Wie überquerst du eine Straße sicher?",
			"Schauen und warten",
			"Blind loslaufen",
			"Auf der Straße spielen",
			"Bleib am Rand stehen. Schau in beide Richtungen und warte, bis der Weg frei ist."
		],
		[
			"Welcher Gegenstand gehört in die Schultasche?",
			"Heft",
			"Kochtopf",
			"Gartenstuhl",
			"In deinem Heft kannst du in der Schule schreiben und zeichnen."
		],
	],
	[
		[
			"Was kommt nach dem Winter?",
			"Frühling",
			"Herbst",
			"Sommer",
			"Die Reihenfolge ist Frühling, Sommer, Herbst, Winter."
		],
		[
			"Was braucht eine Pflanze zum Wachsen?",
			"Wasser und Licht",
			"Nur Plastik",
			"Nur Steine",
			"Pflanzen brauchen unter anderem Wasser und Licht zum Wachsen."
		],
		[
			"Wohin gehört eine leere Glasflasche?",
			"Altglas",
			"Biomüll",
			"Altpapier",
			"Glas wird getrennt gesammelt. Es kann zu neuem Glas verarbeitet werden."
		],
		[
			"Welches Organ pumpt Blut durch den Körper?",
			"Herz",
			"Magen",
			"Ohr",
			"Dein Herz arbeitet wie eine Pumpe und bewegt das Blut."
		],
		[
			"Wo ist Radfahren besonders sicher?",
			"Auf dem Radweg",
			"Auf der Autobahn",
			"Zwischen parkenden Autos",
			"Ein Radweg ist für Fahrräder vorgesehen. Achte trotzdem auf andere Verkehrsteilnehmer."
		],
	],
	[
		[
			"In welchem Bundesland liegt Gänserndorf?",
			"Niederösterreich",
			"Tirol",
			"Kärnten",
			"Lumos Heimat Gänserndorf liegt in Niederösterreich."
		],
		[
			"Was passiert mit Wasser, wenn es gefriert?",
			"Es wird Eis",
			"Es wird Sand",
			"Es verschwindet",
			"Bei genügend Kälte wird flüssiges Wasser zu festem Eis."
		],
		[
			"Was ist eine erneuerbare Energiequelle?",
			"Sonnenlicht",
			"Erdöl",
			"Kohle",
			"Die Sonne liefert immer wieder Energie. Kohle und Erdöl sind begrenzte Vorräte."
		],
		[
			"Wie heißt ein großer Fluss in Österreich?",
			"Donau",
			"Nil",
			"Amazonas",
			"Die Donau fließt unter anderem durch Linz und Wien."
		],
		[
			"Warum waschen wir vor dem Essen die Hände?",
			"Um Keime zu entfernen",
			"Um größer zu werden",
			"Um schneller zu laufen",
			"Gründliches Händewaschen entfernt Schmutz und viele Keime."
		],
	],
	[
		[
			"Wie heißt die Hauptstadt von Österreich?",
			"Wien",
			"Graz",
			"Linz",
			"Wien ist die Hauptstadt Österreichs und zugleich ein Bundesland."
		],
		[
			"Was wird beim Verdunsten aus Wasser?",
			"Wasserdampf",
			"Eis",
			"Metall",
			"Flüssiges Wasser wird beim Verdunsten zu unsichtbarem Wasserdampf."
		],
		[
			"Wie viele Bundesländer hat Österreich?",
			"9",
			"6",
			"12",
			"Österreich besteht aus neun Bundesländern."
		],
		[
			"Wie heißt der höchste Berg Österreichs?",
			"Großglockner",
			"Schneeberg",
			"Dachstein",
			"Der Großglockner ist mit 3.798 Metern der höchste Berg Österreichs."
		],
		[
			"Was hilft, Trinkwasser zu sparen?",
			"Hahn beim Einseifen schließen",
			"Hahn ständig laufen lassen",
			"Wasser absichtlich verschütten",
			"Beim Einseifen brauchst du kein laufendes Wasser. Drehe den Hahn erst zum Abspülen auf."
		],
	],
]


static func make(grade: int, subject: String, rng: RandomNumberGenerator) -> Dictionary:
	grade = clampi(grade, 1, 4)
	if subject == "Sachunterricht":
		var entries: Array = WORLD_FACTS[grade - 1]
		var fact: Array = entries[rng.randi_range(0, entries.size() - 1)]
		return _question(fact[0], fact[1], [fact[2], fact[3]], fact[4], rng)
	if subject == "Logik":
		if grade == 1 and rng.randf() < 0.5:
			return _question(
				"Rot, Blau, Rot, Blau, … Welche Farbe folgt?",
				"Rot",
				["Grün", "Blau"],
				"Immer abwechselnd: Rot und dann Blau. Nach Blau kommt wieder Rot.",
				rng
			)
		var start: int = rng.randi_range(1, [4, 15, 30, 80][grade - 1])
		var step: int = rng.randi_range(1, [1, 5, 10, 25][grade - 1])
		var result: int = start + 3 * step
		var prompt: String = (
			"%d, %d, %d, … Welche Zahl folgt?" % [start, start + step, start + 2 * step]
		)
		var hint: String = "Von Zahl zu Zahl kommen immer %d dazu." % step
		if grade == 4 and rng.randf() < 0.5:
			result = start + step * 3 + 3
			prompt = (
				"%d, %d, %d, … Welche Zahl folgt?" % [start, start + step, start + 2 * step + 1]
			)
			hint = (
				"Die Schritte werden um 1 größer: erst +%d, dann +%d, als Nächstes +%d."
				% [step, step + 1, step + 2]
			)
		return _question(prompt, str(result), [str(result + 1), str(result - 1)], hint, rng)
	if subject == "Deutsch":
		if grade == 1 and rng.randf() < 0.5:
			var entry: Array = RHYMES[rng.randi_range(0, RHYMES.size() - 1)]
			return _question(
				"Was reimt sich auf „%s“?" % entry[0],
				entry[1],
				[entry[2], entry[3]],
				"Sprich die Wörter langsam. Achte auf den gleichen Klang am Ende.",
				rng
			)
		if grade == 2:
			var syllables: Array = [
				["Son-ne", "2"],
				["Ba-na-ne", "3"],
				["Schmet-ter-ling", "3"],
				["Ball", "1"],
				["Blu-me", "2"],
				["Re-gen-bo-gen", "4"]
			]
			var entry: Array = syllables[rng.randi_range(0, syllables.size() - 1)]
			var wrong: Array = ["1", "2", "3", "4"]
			wrong.erase(entry[1])
			return _question(
				"Wie viele Silben hat „%s“?" % str(entry[0]).replace("-", ""),
				entry[1],
				wrong,
				"Klatsche die Sprechsilben: " + entry[0],
				rng
			)
		if grade == 3:
			var words: Array = [
				["laufen", "Tunwort"],
				["Buch", "Namenwort"],
				["warm", "Wiewort"],
				["spielen", "Tunwort"],
				["Schule", "Namenwort"],
				["leise", "Wiewort"],
				["lachen", "Tunwort"],
				["Blume", "Namenwort"],
				["rund", "Wiewort"]
			]
			var entry: Array = words[rng.randi_range(0, words.size() - 1)]
			var wrong: Array = ["Namenwort", "Tunwort", "Wiewort"]
			wrong.erase(entry[1])
			return _question(
				"Welche Wortart ist „%s“?" % entry[0],
				entry[1],
				wrong,
				"Namenwörter benennen Dinge. Tunwörter sagen, was jemand tut. Wiewörter beschreiben.",
				rng
			)
		if grade == 4:
			var verbs: Array = [
				["gehen", "ging"],
				["sehen", "sah"],
				["lesen", "las"],
				["kommen", "kam"],
				["fahren", "fuhr"],
				["schreiben", "schrieb"],
				["trinken", "trank"],
				["finden", "fand"]
			]
			var entry: Array = verbs[rng.randi_range(0, verbs.size() - 1)]
			var wrong: Array = [entry[0], "wird " + entry[0]]
			return _question(
				"Wie lautet „%s“ in der Mitvergangenheit?" % entry[0],
				entry[1],
				wrong,
				"Denke an gestern. Die Mitvergangenheit erzählt, was früher geschah.",
				rng
			)
		var word: Array = ARTICLES[rng.randi_range(0, ARTICLES.size() - 1)]
		var wrong: Array = ["der", "die", "das"]
		wrong.erase(word[1])
		return _question(
			"Welcher Artikel passt? … %s" % word[0],
			word[1],
			wrong,
			"Sprich den Namen mit einem Begleiter: der, die oder das.",
			rng
		)
	var limit: int = [0, 10, 100, 1000, 10000][grade]
	var a: int = rng.randi_range(1, limit - 1)
	var b: int = rng.randi_range(1, limit - a)
	var result: int = a + b
	var prompt: String = "%d + %d = ?" % [a, b]
	var hint: String = "Starte bei %d. Zähle %d weiter, in kleinen Schritten." % [a, b]
	if grade >= 3:
		hint = (
			"Zerlege %d nach Stellenwerten. Addiere Tausender, Hunderter, Zehner und Einer passend zu %d."
			% [b, a]
		)
	var variant: int = rng.randi_range(0, 3)
	if grade >= 2 and variant == 0:
		a = rng.randi_range(2, 10)
		b = rng.randi_range(2, 10)
		result = a * b
		prompt = "%d · %d = ?" % [a, b]
		hint = "Nimm %d Gruppen mit je %d Dingen. Zähle die Gruppen zusammen." % [a, b]
	elif variant == 1:
		b = rng.randi_range(1, a)
		result = a - b
		prompt = "%d − %d = ?" % [a, b]
		hint = "Starte bei %d und gehe %d Schritte zurück." % [a, b]
		if grade >= 3:
			hint = (
				"Zerlege %d in Hunderter, Zehner und Einer. Ziehe diese Teile nacheinander von %d ab."
				% [b, a]
			)
	elif variant == 2:
		prompt = STORIES[rng.randi_range(0, STORIES.size() - 1)] % [a, b]
	var offset: int = rng.randi_range(1, mini(8, result + 1))
	var wrong_numbers: Array = [str(result + offset), str(maxi(0, result - offset))]
	if wrong_numbers[1] == str(result):
		wrong_numbers[1] = str(result + offset + 1)
	return _question(prompt, str(result), wrong_numbers, hint, rng)


static func _question(
	prompt: String, answer: String, wrong: Array, hint: String, rng: RandomNumberGenerator
) -> Dictionary:
	var options: Array = [answer, wrong[0], wrong[1]]
	for i in range(options.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: String = options[i]
		options[i] = options[j]
		options[j] = swap
	return {"prompt": prompt, "answer": answer, "options": options, "hint": hint}
