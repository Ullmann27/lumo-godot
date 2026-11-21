extends RefCounted
## Feineinstellung je Kart: fünf Regler mit je fünf Stufen (−2 … +2, 0 = Werkseinstellung).
##
## Jede Stufe verschiebt echte Fahrfaktoren (kart_powertrain.gd) – immer als Abwägung:
## mehr Halt kostet Tempo, mehr Endtempo kostet Antritt. Das Rennen liest die Faktoren über
## kart_tuning.multipliers(), der Prüfstand misst sie mit denselben Formeln. Teile und
## Feineinstellung zusammen bleiben in kart_part_catalog.PART_LIMITS.
## Kostenlos und jederzeit zurückstellbar; gespeichert je Kind und Kart in kart_tuning.gd.

const STEPS: int = 2
const SETTINGS: Array[Dictionary] = [
	{
		"id": "pressure",
		"name": "Reifendruck",
		"low": "weich",
		"high": "hart",
		"per_step": {"speed": 0.003, "grip": -0.025},
		"metrics": ["top_kmh", "slide_m"],
		"sentence": "Mehr Druck: schneller geradeaus, rutscht mehr in Kurven.",
	},
	{
		"id": "damping",
		"name": "Fahrwerkshärte",
		"low": "weich",
		"high": "hart",
		"per_step": {"turn": 0.02, "landing": 0.18},
		"metrics": ["radius_m", "landing_s"],
		"sentence": "Härter: lenkt enger, wackelt nach Sprüngen länger.",
	},
	{
		"id": "wing_angle",
		"name": "Flügelwinkel",
		"low": "flach",
		"high": "steil",
		"per_step": {"grip": 0.03, "speed": -0.004},
		"metrics": ["slide_m", "top_kmh"],
		"sentence": "Steiler: klebt in Kurven, etwas langsamer geradeaus.",
	},
	{
		"id": "gear",
		"name": "Übersetzung",
		"low": "kurz",
		"high": "lang",
		"per_step": {"speed": 0.005, "accel": -0.06},
		"metrics": ["top_kmh", "sprint_s"],
		"sentence": "Länger: höheres Endtempo, zieht langsamer an.",
	},
	{
		"id": "steer",
		"name": "Lenkempfindlichkeit",
		"low": "ruhig",
		"high": "flink",
		"per_step": {"turn": 0.03, "grip": -0.015},
		"metrics": ["radius_m", "slide_m"],
		"sentence": "Flinker: biegt enger ein, das Heck rutscht leichter.",
	},
]
## Voreinstellungen für Kinder: ein Tipp stellt alle Regler.
const PRESETS: Array[Dictionary] = [
	{
		"id": "kurve",
		"name": "Kurvenkünstler",
		"text": "Klebt und lenkt eng, etwas langsamer geradeaus.",
		"values": {"pressure": -1, "damping": 1, "wing_angle": 2, "gear": -1, "steer": 1},
	},
	{
		"id": "sprint",
		"name": "Sprinter",
		"text": "Schnell geradeaus, rutscht in Kurven mehr.",
		"values": {"pressure": 2, "damping": 0, "wing_angle": -2, "gear": 1, "steer": -1},
	},
	{
		"id": "allround",
		"name": "Allrounder",
		"text": "Ausgewogen mit weicher Landung – für jede Strecke.",
		"values": {"pressure": 0, "damping": -1, "wing_angle": 1, "gear": 0, "steer": 0},
	},
]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry in SETTINGS:
		result.append(str(entry.id))
	return result


static func setting(id: String) -> Dictionary:
	for entry in SETTINGS:
		if str(entry.id) == id:
			return entry
	return {}


static func preset(id: String) -> Dictionary:
	for entry in PRESETS:
		if str(entry.id) == id:
			return entry
	return {}


## Gültige Einstellung: jede bekannte Stufe auf −2 … +2, Unbekanntes fällt weg.
static func sanitize(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in ids():
		var value: int = clampi(int(values.get(id, 0)), -STEPS, STEPS)
		if value != 0:
			result[id] = value
	return result


static func is_neutral(values: Dictionary) -> bool:
	return sanitize(values).is_empty()


## Welche Voreinstellung genau passt ("" = eigene Einstellung).
static func matching_preset(values: Dictionary) -> String:
	var clean: Dictionary = sanitize(values)
	for entry in PRESETS:
		if sanitize(entry["values"]) == clean:
			return str(entry.id)
	return ""


## Faktor-Änderung einer Einstellung im Format von kart_part_catalog.changes() (extra).
static func changes(values: Dictionary) -> Dictionary:
	var mul: Dictionary = {}
	var clean: Dictionary = sanitize(values)
	for id in clean:
		var step: int = int(clean[id])
		var per_step: Dictionary = setting(str(id)).get("per_step", {})
		for key in per_step:
			mul[key] = float(mul.get(key, 1.0)) * (1.0 + float(per_step[key]) * float(step))
	return {"mul": mul, "add": {}}


## Kurzer Text zur Stufe, z. B. „hart +2“ oder „Werk“.
static func step_text(id: String, value: int) -> String:
	var entry: Dictionary = setting(id)
	if value == 0:
		return "Werk"
	var word: String = str(entry.get("high" if value > 0 else "low", ""))
	return "%s %s%d" % [word, "+" if value > 0 else "−", absi(value)]
