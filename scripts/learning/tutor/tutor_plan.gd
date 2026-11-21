# gdlint: disable=max-returns
extends RefCounted
## Lumo-Nachhilfe: geprüfte Abspiel-Logik für die von Flutter berechneten Pläne.
## Flutter entscheidet Pädagogik (Stufen, Wege, Zwillingsaufgaben). Diese Klasse
## prüft die Daten streng, hält den Material-Zustand und bewertet nur die
## Handgriffe des Kindes am Material. Sie vergibt nichts und speichert nichts.

const WEGE: Array[String] = ["rechenrahmen", "zahlenstrahl", "zerlegen", "verdoppeln", "tauschen"]
const STUFEN: Array[String] = ["hinweis", "teilschritt", "vorzeigen", "ueben"]
const ARTEN: Array[String] = ["perlen", "huepfen", "zerlegen", "ergebnis", "zeigen"]
const TEXT_LIMIT := 240
const STEP_LIMIT := 8

var a := 0
var b := 0
var prompt := ""
var wege: Array[String] = []
var fehler := "keines"
var rueckmeldung := ""
var weg := ""
var stufe := ""
## plans[weg][stufe] = Dictionary (geprüft)
var plans: Dictionary = {}
var schritt := 0
var reihe1 := 0
var reihe2 := 0
var position := 0
var spruenge: Array[Vector2i] = []
var zerlegung: Array[int] = []
var gewaehlt := -1
var fehlversuche := 0
var vorgezeigt := false
var fertig := false


func configure(raw: Dictionary) -> bool:
	plans.clear()
	wege.clear()
	if str(raw.get("kind", "")) != "tutor" or str(raw.get("typ", "")) != "addition_20":
		return false
	if not _int_in(raw.get("a"), 1, 19) or not _int_in(raw.get("b"), 1, 19):
		return false
	a = int(raw.a)
	b = int(raw.b)
	if a + b > 20:
		return false
	prompt = "%d + %d = ?" % [a, b]
	var raw_wege: Variant = raw.get("wege")
	if not raw_wege is Array or raw_wege.is_empty() or raw_wege.size() > WEGE.size():
		return false
	for item: Variant in raw_wege:
		if not item is String or item not in WEGE or wege.has(item):
			return false
		wege.append(item)
	fehler = str(raw.get("fehler", "keines"))
	if fehler not in ["keines", "einsDaneben", "rechenzeichen", "zehnerVergessen", "zifferndreher"]:
		return false
	rueckmeldung = _text(raw.get("rueckmeldung", ""), true)
	var raw_plans: Variant = raw.get("plaene")
	if not raw_plans is Array or raw_plans.size() != wege.size() * STUFEN.size():
		return false
	for entry: Variant in raw_plans:
		var checked := _check_plan(entry)
		if checked.is_empty():
			return false
		if not plans.has(checked.weg):
			plans[checked.weg] = {}
		if plans[checked.weg].has(checked.stufe):
			return false
		plans[checked.weg][checked.stufe] = checked
	for w: String in wege:
		if not plans.has(w) or plans[w].size() != STUFEN.size():
			return false
	var start_weg := str(raw.get("startWeg", ""))
	var start_stufe := str(raw.get("startStufe", ""))
	if start_weg not in wege or start_stufe not in STUFEN:
		return false
	select(start_weg, start_stufe)
	return true


func _check_plan(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var w := str(entry.get("weg", ""))
	var s := str(entry.get("stufe", ""))
	if w not in wege or s not in STUFEN:
		return {}
	if not _int_in(entry.get("a"), 1, 19) or not _int_in(entry.get("b"), 1, 19):
		return {}
	var pa := int(entry.a)
	var pb := int(entry.b)
	if pa + pb > 20:
		return {}
	var zwilling: bool = entry.get("zwilling", false) == true
	# Hinweis und Teilschritt arbeiten an der Originalaufgabe, Vorzeigen und
	# Üben an einer Zwillingsaufgabe mit anderem Ergebnis.
	if s in ["hinweis", "teilschritt"]:
		if zwilling or pa != a or pb != b:
			return {}
	elif not zwilling or pa + pb == a + b:
		return {}
	var raw_steps: Variant = entry.get("schritte")
	if not raw_steps is Array or raw_steps.is_empty() or raw_steps.size() > STEP_LIMIT:
		return {}
	var steps: Array[Dictionary] = []
	for raw_step: Variant in raw_steps:
		var step := _check_step(raw_step, pa + pb, s in ["hinweis", "teilschritt"])
		if step.is_empty():
			return {}
		steps.append(step)
	var einleitung := _text(entry.get("einleitung", ""))
	var lob := _text(entry.get("lob", ""))
	var abschluss := _text(entry.get("abschluss", ""))
	if einleitung.is_empty() or lob.is_empty() or abschluss.is_empty():
		return {}
	return {
		"weg": w,
		"stufe": s,
		"a": pa,
		"b": pb,
		"zwilling": zwilling,
		"einleitung": einleitung,
		"lob": lob,
		"abschluss": abschluss,
		"schritte": steps,
	}


func _check_step(raw: Variant, ergebnis: int, original: bool) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var id := str(raw.get("id", ""))
	var wer := str(raw.get("wer", ""))
	var text := _text(raw.get("text", ""))
	if id.is_empty() or id.length() > 24 or wer not in ["lumo", "kind"] or text.is_empty():
		return {}
	var action: Variant = raw.get("aktion")
	if not action is Dictionary:
		return {}
	var art := str(action.get("art", ""))
	if art not in ARTEN:
		return {}
	var checked := {"art": art}
	match art:
		"perlen":
			if not _int_in(action.get("reihe1"), 0, 10) or not _int_in(action.get("reihe2"), 0, 10):
				return {}
			checked.reihe1 = int(action.reihe1)
			checked.reihe2 = int(action.reihe2)
			if checked.reihe1 + checked.reihe2 > ergebnis:
				return {}
		"huepfen":
			if not _int_in(action.get("von"), 0, 20) or not _int_in(action.get("nach"), 1, 20):
				return {}
			checked.von = int(action.von)
			checked.nach = int(action.nach)
			if checked.nach <= checked.von:
				return {}
		"zerlegen":
			if (
				not _int_in(action.get("ganz"), 2, 19)
				or not _int_in(action.get("teil1"), 1, 18)
				or not _int_in(action.get("teil2"), 1, 18)
			):
				return {}
			checked.ganz = int(action.ganz)
			checked.teil1 = int(action.teil1)
			checked.teil2 = int(action.teil2)
			if checked.teil1 + checked.teil2 != checked.ganz:
				return {}
			var options: Variant = action.get("zerlegungen")
			if not options is Array or options.size() < 2 or options.size() > 4:
				return {}
			var list: Array = []
			var has_correct := false
			for pair: Variant in options:
				if (
					not pair is Array
					or pair.size() != 2
					or not _int_in(pair[0], 1, 18)
					or not _int_in(pair[1], 1, 18)
					or int(pair[0]) + int(pair[1]) != checked.ganz
				):
					return {}
				list.append([int(pair[0]), int(pair[1])])
				has_correct = (
					has_correct or (int(pair[0]) == checked.teil1 and int(pair[1]) == checked.teil2)
				)
			if not has_correct:
				return {}
			checked.zerlegungen = list
		"ergebnis":
			# Die Originalaufgabe wird in der Nachhilfe nie gelöst.
			if original or not _int_in(action.get("richtig"), 0, 20):
				return {}
			checked.richtig = int(action.richtig)
			if checked.richtig != ergebnis:
				return {}
			var values: Variant = action.get("optionen")
			if not values is Array or values.size() < 2 or values.size() > 4:
				return {}
			var numbers: Array[int] = []
			for value: Variant in values:
				if not _int_in(value, 0, 21) or numbers.has(int(value)):
					return {}
				numbers.append(int(value))
			if not numbers.has(checked.richtig):
				return {}
			checked.optionen = numbers
	return {"id": id, "wer": wer, "text": text, "aktion": checked}


func select(new_weg: String, new_stufe: String) -> bool:
	if not plans.has(new_weg) or not plans[new_weg].has(new_stufe):
		return false
	weg = new_weg
	stufe = new_stufe
	schritt = 0
	reihe1 = 0
	reihe2 = 0
	position = 0
	spruenge.clear()
	zerlegung.clear()
	gewaehlt = -1
	fehlversuche = 0
	vorgezeigt = false
	fertig = false
	return true


func plan() -> Dictionary:
	return plans[weg][stufe]


func steps() -> Array:
	return plan().schritte


func current() -> Dictionary:
	var list := steps()
	return list[schritt] if schritt < list.size() else {}


func lumo_turn() -> bool:
	return current().get("wer", "") == "lumo"


## Material-Art, die gerade sichtbar sein soll (das zuletzt benutzte bleibt).
func material() -> String:
	var list := steps()
	for index in range(mini(schritt, list.size() - 1), -1, -1):
		var art: String = list[index].aktion.art
		if art in ["perlen", "huepfen"]:
			return art
	for step: Dictionary in list:
		if step.aktion.art in ["perlen", "huepfen"]:
			return step.aktion.art
	return "perlen"


## Lumo führt den aktuellen Schritt aus: Zielzustand anwenden.
func demonstrate() -> Dictionary:
	var step := current()
	if step.is_empty():
		return {}
	var action: Dictionary = step.aktion
	match action.art:
		"perlen":
			reihe1 = action.reihe1
			reihe2 = action.reihe2
		"huepfen":
			_hop(action.von, action.nach)
		"zerlegen":
			zerlegung = [action.teil1, action.teil2]
		"ergebnis":
			gewaehlt = action.richtig
	vorgezeigt = true
	return action


func _hop(from: int, to: int) -> void:
	position = from
	spruenge.append(Vector2i(from, to))
	position = to


## Rückgabe: "ok", "noch", "zu_viel", "falsch", "gezeigt" (nach 2 Fehlern), "ignoriert".
func try_beads(row: int, count: int) -> String:
	var step := current()
	if step.is_empty() or lumo_turn() or vorgezeigt or step.aktion.art != "perlen":
		return "ignoriert"
	if row == 1:
		reihe1 = clampi(count, 0, 10)
	elif row == 2:
		reihe2 = clampi(count, 0, 10)
	else:
		return "ignoriert"
	if reihe1 == step.aktion.reihe1 and reihe2 == step.aktion.reihe2:
		return "ok"
	if reihe1 > step.aktion.reihe1 or reihe2 > step.aktion.reihe2:
		return _miss("zu_viel")
	return "noch"


func try_stone(number: int) -> String:
	var step := current()
	if step.is_empty() or lumo_turn() or vorgezeigt or step.aktion.art != "huepfen":
		return "ignoriert"
	if number == step.aktion.nach:
		_hop(step.aktion.von, number)
		return "ok"
	return _miss("falsch")


func try_split(first: int, second: int) -> String:
	var step := current()
	if step.is_empty() or lumo_turn() or vorgezeigt or step.aktion.art != "zerlegen":
		return "ignoriert"
	if first == step.aktion.teil1 and second == step.aktion.teil2:
		zerlegung = [first, second]
		return "ok"
	return _miss("falsch")


func try_result(value: int) -> String:
	var step := current()
	if step.is_empty() or lumo_turn() or vorgezeigt or step.aktion.art != "ergebnis":
		return "ignoriert"
	if value == step.aktion.richtig:
		gewaehlt = value
		return "ok"
	return _miss("falsch")


func _miss(kind: String) -> String:
	fehlversuche += 1
	if fehlversuche >= 2:
		demonstrate()
		return "gezeigt"
	return kind


func advance() -> void:
	schritt += 1
	fehlversuche = 0
	vorgezeigt = false
	fertig = schritt >= steps().size()


func next_stufe() -> String:
	var index := STUFEN.find(stufe)
	return STUFEN[index + 1] if index >= 0 and index + 1 < STUFEN.size() else ""


func next_weg() -> String:
	var index := wege.find(weg)
	return wege[(index + 1) % wege.size()]


static func _int_in(value: Variant, low: int, high: int) -> bool:
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(value))
		and float(value) == floorf(float(value))
		and float(value) >= low
		and float(value) <= high
	)


static func _text(value: Variant, allow_empty: bool = false) -> String:
	if not value is String:
		return ""
	var text: String = value.strip_edges()
	if text.length() > TEXT_LIMIT * 2 or (text.is_empty() and not allow_empty):
		return ""
	for code in text.to_utf32_buffer().to_int32_array():
		if code < 10 or (code > 10 and code < 32) or (code >= 127 and code <= 159):
			return ""
	return text
