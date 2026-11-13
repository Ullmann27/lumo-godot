extends RefCounted
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


func configure(raw: Dictionary) -> bool:
	reset()
	kind = str(raw.get("kind", "invalid"))
	match kind:
		"bridge_ten":
			if not _whole_number(raw.get("a")) or not _whole_number(raw.get("b")):
				kind = "invalid"
				return false
			a = int(raw.a)
			b = int(raw.b)
			if a < 1 or a > 9 or b < 1 or b > 9 or a + b <= 10:
				kind = "invalid"
		"addition", "subtract_ten", "equal_groups", "bridge_hundred", "fraction_parts":
			if not _bounded_integer(raw.get("a"), 0, 900) or not _bounded_integer(raw.get("b"), 1, 90):
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
				"bridge_hundred":
					if a < 100 or a > 890 or a % 10 != 0 or b < 10 or b % 10 != 0 or a % 100 + b < 100:
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


static func _whole_number(value: Variant) -> bool:
	# JSON.parse_string uses floating point numbers. Accept exact bounded
	# integers from the native JSON bridge, never truncating fractional input.
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 1.0 and float(value) <= 9.0 and float(value) == floorf(float(value))


static func _bounded_integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= low and float(value) <= high and float(value) == floorf(float(value))


func reset() -> void:
	placed.clear()
	watered = false
	sunlight = false
	inspected.clear()


func token_count() -> int:
	match kind:
		"bridge_ten", "addition": return b
		"subtract_ten": return a
		"equal_groups": return a * b
		"bridge_hundred": return b / 10
		"fraction_parts": return extra if extra > 0 else a
	return syllables.size()


func goal_count() -> int:
	return b if kind == "subtract_ten" else token_count()


func initial_count() -> int:
	if kind == "bridge_hundred":
		return (a % 100) / 10
	if kind == "fraction_parts":
		return a if extra > 0 else 0
	return a if kind in ["bridge_ten", "addition"] else 0


func is_complete() -> bool:
	if kind == "plant_parts":
		return watered and sunlight and inspected.size() == 4
	return kind != "invalid" and placed.size() == goal_count()


func target_index() -> int:
	return initial_count() + placed.size()


func place(token: int, target: int) -> bool:
	if kind in ["invalid", "plant_parts"] or is_complete() or token < 0 or token >= token_count():
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


func explanation() -> String:
	match kind:
		"bridge_ten", "addition":
			var filled: int = a + placed.size()
			if kind == "addition" and a + b <= 10:
				return "%d plus %d ist %d." % [a, b, a + b] if is_complete() else "Lege %d Würfel zu den %d dazu. Jetzt sind es %d." % [b, a, filled]
			if placed.is_empty():
				return "%d + %d: Fülle zuerst die freien Plätze bis zehn." % [a, b]
			if filled < 10:
				return "Jetzt liegen %d im Zehnerfeld. Noch %d bis zehn." % [filled, 10 - filled]
			if filled == 10:
				return "Zehn sind voll! Von den %d bleiben %d. Lege sie ins zweite Feld." % [b, a + b - 10]
			if is_complete():
				return "%d + %d = 10 + %d = %d. Du hast den Zehner selbst gefüllt." % [a, b, a + b - 10, a + b]
			return "Zehn und %d sind %d. Lege die übrigen Würfel dazu." % [filled - 10, filled]
		"subtract_ten":
			var remaining: int = a - placed.size()
			if is_complete():
				return "%d minus %d ist %d. So viele Würfel bleiben im Feld." % [a, b, remaining]
			if remaining == 10:
				return "Jetzt bleiben zehn. Nimm noch %d weg, dann hast du insgesamt %d weggenommen." % [b - placed.size(), b]
			return "Von %d nehmen wir %d weg. %d sind schon weg; %d liegen noch im Feld." % [a, b, placed.size(), remaining]
		"equal_groups":
			if is_complete():
				return "%d Gruppen mit je %d Würfeln: %d mal %d ist %d." % [a, b, a, b, a * b]
			return "Fülle %d Gruppen mit je %d Würfeln. Schon %d Gruppen sind voll." % [a, b, placed.size() / b]
		"bridge_hundred":
			var current: int = a + placed.size() * 10
			if is_complete():
				return "%d plus %d ist %d. Zehn Zehner bilden einen Hunderter." % [a, b, current]
			return "Jeder Streifen zählt zehn. Jetzt sind es %d. Ergänze zuerst bis %d." % [current, (a / 100 + 1) * 100]
		"fraction_parts":
			if is_complete():
				return "%d von %d gleich großen Teilen sind markiert: %d/%d. Die Teilgröße bleibt gleich." % [a + extra, b, a + extra, b]
			return "Das Ganze hat %d gleich große Teile. Lege %d Teile hinein." % [b, a + extra]
		"syllables":
			if is_complete():
				return "%s: %s. Das Wort hat %d Silben." % [word, " – ".join(syllables), syllables.size()]
			return "Baue %s. Als Nächstes kommt die Silbe „%s“." % [word, syllables[placed.size()]]
		"plant_parts":
			if watered and sunlight:
				return "Licht und Wasser helfen der Pflanze zu wachsen. Entdecke ihre vier Teile."
			return "Gib Wasser und öffne die Sonne. Tippe auf Wurzel, Stängel, Blatt und Blüte."
	return "Diese Lernansicht konnte nicht sicher geladen werden."
