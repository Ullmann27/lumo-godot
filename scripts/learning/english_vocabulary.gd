extends RefCounted
## Closed object vocabulary shared by the actual host task contract.
## German descriptions use the existing German local voice. The English word
## stays visible; this class does not claim an English pronunciation channel.
const ENTRIES := {
	"book": {
		"meanings": ["Buch"],
		"hint": "Dieser Gegenstand hat viele Seiten. Du kannst darin lesen.",
	},
	"pen": {
		"meanings": ["Kugelschreiber", "Stift"],
		"hint": "Damit kannst du schreiben und zeichnen. Achte auf die schmale Spitze.",
	},
	"ruler": {
		"meanings": ["Lineal"],
		"hint": "Damit misst du gerade Strecken. Die kleinen Striche zeigen die Länge.",
	},
	"ball": {
		"meanings": ["Ball"],
		"hint": "Dieser runde Gegenstand kann rollen und springen.",
	},
	"car": {
		"meanings": ["Auto"],
		"hint": "Dieses Fahrzeug fährt auf vier Rädern.",
	},
	"sun": {
		"meanings": ["Sonne"],
		"hint": "Dieses helle Himmelsobjekt gibt uns Licht und Wärme.",
	},
	"apple": {
		"meanings": ["Apfel"],
		"hint": "Diese Frucht wächst am Baum. Sie hat einen Stiel und ein Blatt.",
	},
}


static func checked_payload(raw: Dictionary) -> Dictionary:
	if raw.get("kind") != "english_objects":
		return {}
	var word: Variant = raw.get("word")
	var meaning: Variant = raw.get("meaning")
	var objects: Variant = raw.get("objects")
	if not word is String or not ENTRIES.has(word) or not meaning is String:
		return {}
	if meaning not in ENTRIES[word].meanings or not objects is Array or objects.size() != 3:
		return {}
	var seen: Array[String] = []
	for item in objects:
		if not item is String or not ENTRIES.has(item) or seen.has(item):
			return {}
		seen.append(item)
	if not seen.has(word):
		return {}
	return {"word": word, "meaning": meaning, "objects": seen.duplicate()}


static func hint_for(word: String) -> String:
	return str(ENTRIES[word].hint) if ENTRIES.has(word) else ""
