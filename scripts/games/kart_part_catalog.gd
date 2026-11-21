extends RefCounted
## Leistungsteile der Garage: neun Steckplätze mit Serie und je fünf Varianten.
##
## Jede Variante hat einen klaren Charakter und eine Abwägung – keine ist nur „besser“.
## Sie verändert die Fahrfaktoren aus kart_fleet.multipliers(): „mul“ multipliziert,
## „add“ addiert (Gelände, Rempler). Die Faktoren liest das Rennen über
## kart_powertrain.gd; der Prüfstand (kart_dyno.gd) misst mit denselben Formeln.
## Serie und eine Variante je Steckplatz kosten nichts, die übrigen werden mit Sternen aus
## dem Lernen freigeschaltet (nur auf dem Papier ausgegeben, wie in kart_tuning.gd).
## „node“ ist der Knotenname im Modell „file“ (tools/lumo_kart_art/karts/build_parts.py):
## die ersten Teile liegen in kart_parts.glb, die übrigen je Steckplatz in parts_<slot>.glb.
## Gemeinsame Grenze (PART_LIMITS): Teile und Feineinstellung zusammen verschieben jeden
## Fahrfaktor höchstens bis zu dieser Spanne – auch zehn Teile auf Tempo machen kein
## unschlagbares Kart.

const LEGACY_FILE := "res://assets/kart/production/parts/kart_parts.glb"
const SLOT_FILE := "res://assets/kart/production/parts/parts_%s.glb"
const SLOTS: Array[String] = [
	"engine", "tires", "wing", "booster", "suspension", "steering", "brakes", "gearbox", "ballast"
]
const SLOT_NAMES: Dictionary = {
	"engine": "Motor",
	"tires": "Reifen",
	"wing": "Flügel",
	"booster": "Turbo",
	"suspension": "Fahrwerk",
	"steering": "Lenkung",
	"brakes": "Bremse",
	"gearbox": "Getriebe",
	"ballast": "Gewicht",
}
## Ein Satz je Steckplatz: was dieses Bauteil am Kart macht.
const SLOT_HINTS: Dictionary = {
	"engine": "Der Motor gibt Kraft: Antritt oder Endtempo.",
	"tires": "Reifen entscheiden über Halt, Driften und Gelände.",
	"wing": "Der Flügel drückt das Kart auf die Straße oder lässt es gleiten.",
	"booster": "Der Turbo schiebt nach einem Drift – stark oder lange.",
	"suspension": "Das Fahrwerk federt Sprünge und Rempler ab.",
	"steering": "Die Lenkung bestimmt, wie eng und ruhig das Kart einlenkt.",
	"brakes": "Die Bremse bremst – und kann beim Driften helfen.",
	"gearbox": "Das Getriebe teilt die Kraft: schnell los oder schnell geradeaus.",
	"ballast": "Wo das Gewicht sitzt, ändert Lenken, Anfahren und Rempeln.",
}
## Werte, die der Prüfstand je Steckplatz zuerst zeigt (die Anzeige ergänzt geänderte Werte).
const SLOT_METRICS: Dictionary = {
	"engine": ["top_kmh", "sprint_s", "boost_kmh"],
	"tires": ["slide_m", "drift_s", "offroad_kmh"],
	"wing": ["top_kmh", "slide_m", "air_deg"],
	"booster": ["boost_kmh", "boost_s", "drift_s"],
	"suspension": ["landing_s", "radius_m", "bump_pct"],
	"steering": ["radius_m", "slide_m", "air_deg"],
	"brakes": ["brake_m", "sprint_s", "drift_s"],
	"gearbox": ["top_kmh", "sprint_s", "offroad_kmh"],
	"ballast": ["radius_m", "sprint_s", "bump_pct"],
}
## Spanne je Fahrfaktor, die Teile UND Feineinstellung zusammen erreichen dürfen
## (mul: Faktor gegenüber dem Kart ohne Teile, add: Summe der Zuschläge).
const PART_LIMITS: Dictionary = {
	"speed": [0.94, 1.035],
	"accel": [0.72, 1.24],
	"brake": [0.72, 1.32],
	"turn": [0.85, 1.15],
	"grip": [0.80, 1.22],
	"drift_charge": [0.70, 1.40],
	"drift_grip": [0.85, 1.20],
	"air_turn": [0.70, 2.00],
	"landing": [0.30, 1.80],
	"boost_power": [0.75, 1.30],
	"boost_time": [0.70, 1.40],
}
const ADD_LIMITS: Dictionary = {
	"offroad": [-0.15, 0.18],
	"stability": [-0.12, 0.18],
}
const SERIE := {
	"id": "serie",
	"name": "Serie",
	"cost": 0,
	"node": "",
	"file": "",
	"mul": {},
	"add": {},
	"short": "Ausgewogen"
}

## Rivalen-Sätze je Fahrstil in der Reihenfolge von kart_rival_racecraft.STYLES (precise,
## attacker, patient, flow, defender). Ab „Abenteuer“ fahren die Rivalen mit diesen Teilen –
## sichtbar am Kart und mit derselben Wirkung (kart_rival_racecraft.factors). In „Entdecken“
## fahren sie Serie: dort soll das Kind auch ohne Teile vorne mitfahren. Die neuen
## Steckplätze bleiben bei Rivalen Serie (feste Sätze, keine Feineinstellung).
const RIVAL_SETS: Array[Dictionary] = [
	{"tires": "haft", "wing": "gross"},
	{"engine": "sprint", "booster": "kurz"},
	{"engine": "dauer", "suspension": "sprung"},
	{"tires": "drift", "booster": "lang"},
	{"suspension": "panzer", "wing": "flach"},
]

static var _catalog: Dictionary = {}


static func _part(
	slot: String,
	id: String,
	name: String,
	cost: int,
	node: String,
	mul: Dictionary,
	add: Dictionary,
	text: String,
	short: String,
	legacy: bool = false
) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"cost": cost,
		"node": node,
		"file": LEGACY_FILE if legacy else SLOT_FILE % slot,
		"mul": mul,
		"add": add,
		"text": text,
		"short": short,
	}


static func _serie(text: String) -> Dictionary:
	return SERIE.merged({"text": text})


static func _build() -> Dictionary:
	return {
		"engine":
		[
			_serie("Ausgewogen: Werksmotor."),
			_part(
				"engine",
				"sprint",
				"Sprintmotor",
				0,
				"Engine_Sprint",
				{"accel": 1.14, "speed": 0.975},
				{},
				"Zieht schneller an, Endtempo etwas niedriger.",
				"Schneller Antritt",
				true
			),
			_part(
				"engine",
				"dauer",
				"Langstreckenmotor",
				10,
				"Engine_Long",
				{"speed": 1.022, "accel": 0.86},
				{},
				"Höheres Endtempo, braucht länger bis dahin.",
				"Hohes Endtempo",
				true
			),
			_part(
				"engine",
				"lader",
				"Turbolader-Motor",
				12,
				"Engine_Charger",
				{"boost_power": 1.16, "accel": 0.93},
				{},
				"Turbo schiebt stärker, beim Anfahren ein kleines Turboloch.",
				"Starker Turbo",
			),
			_part(
				"engine",
				"leicht",
				"Leichtbaumotor",
				10,
				"Engine_Light",
				{"accel": 1.08},
				{"stability": -0.08},
				"Leicht und flink, Rempler bremsen dafür mehr.",
				"Leicht und flink",
			),
			_part(
				"engine",
				"hybrid",
				"Hybridmotor",
				14,
				"Engine_Hybrid",
				{"boost_time": 1.2, "speed": 0.985},
				{},
				"Speichert Kraft: Turbo hält länger, Endtempo etwas niedriger.",
				"Turbo hält lange",
			),
		],
		"tires":
		[
			_serie("Ausgewogen: Werksreifen."),
			_part(
				"tires",
				"haft",
				"Haftreifen",
				0,
				"Tire_Grip",
				{"grip": 1.18, "turn": 1.03, "drift_charge": 0.8},
				{},
				"Klebt in Kurven, Drift-Turbo lädt langsamer.",
				"Klebt in Kurven",
				true
			),
			_part(
				"tires",
				"drift",
				"Driftreifen",
				8,
				"Tire_Drift",
				{"grip": 0.86, "drift_charge": 1.3, "drift_grip": 1.12},
				{},
				"Rutscht leichter, Drift-Turbo lädt schneller.",
				"Drift lädt schnell",
				true
			),
			_part(
				"tires",
				"stollen",
				"Stollenreifen",
				12,
				"Tire_Knobby",
				{"grip": 0.96, "speed": 0.985},
				{"offroad": 0.16},
				"Schnell neben der Straße, auf Asphalt etwas langsamer.",
				"Stark im Gelände",
				true
			),
			_part(
				"tires",
				"slick",
				"Rennslicks",
				10,
				"Tire_Slick",
				{"grip": 1.06, "speed": 1.008},
				{"offroad": -0.14},
				"Glatt und schnell auf Asphalt, im Gras sehr langsam.",
				"Schnell auf Asphalt",
			),
			_part(
				"tires",
				"weich",
				"Weichreifen",
				12,
				"Tire_Soft",
				{"grip": 1.08, "accel": 1.05, "speed": 0.975},
				{},
				"Greifen beim Anfahren und in Kurven, Endtempo niedriger.",
				"Greift sofort",
			),
		],
		"wing":
		[
			_serie("Ausgewogen: Werksheck."),
			_part(
				"wing",
				"gross",
				"Großflügel",
				0,
				"Wing_Big",
				{"grip": 1.12, "turn": 1.05, "speed": 0.978},
				{},
				"Hält in Kurven, langsamer geradeaus.",
				"Hält in Kurven",
				true
			),
			_part(
				"wing",
				"flach",
				"Flachflügel",
				8,
				"Wing_Flat",
				{"speed": 1.012, "grip": 0.9, "turn": 0.97},
				{},
				"Schneller geradeaus, rutscht in Kurven mehr.",
				"Schnell geradeaus",
				true
			),
			_part(
				"wing",
				"gleiter",
				"Gleitflügel",
				12,
				"Wing_Glide",
				{"air_turn": 1.8, "speed": 0.99},
				{},
				"Lenkt in der Luft, etwas langsamer geradeaus.",
				"Lenkt im Flug",
				true
			),
			_part(
				"wing",
				"klapp",
				"Klappflügel",
				10,
				"Wing_Flap",
				{"brake": 1.14, "speed": 1.005, "grip": 0.95},
				{},
				"Klappt beim Bremsen hoch: kürzerer Bremsweg, in Kurven etwas lockerer.",
				"Bremst mit Luft",
			),
			_part(
				"wing",
				"flosse",
				"Driftflosse",
				12,
				"Wing_Fin",
				{"drift_grip": 1.14, "drift_charge": 1.08, "grip": 0.94},
				{},
				"Hält den Drift ruhig und lädt ihn schneller, sonst rutscht es mehr.",
				"Ruhiger Drift",
			),
		],
		"booster":
		[
			_serie("Ausgewogen: Werksturbo."),
			_part(
				"booster",
				"kurz",
				"Kurzschub",
				0,
				"Booster_Short",
				{"boost_power": 1.25, "boost_time": 0.72},
				{},
				"Kurzer, starker Schub.",
				"Kurz und stark",
				true
			),
			_part(
				"booster",
				"lang",
				"Langschub",
				10,
				"Booster_Long",
				{"boost_power": 0.8, "boost_time": 1.35},
				{},
				"Sanfter Schub, der lange hält.",
				"Lang und sanft",
				true
			),
			_part(
				"booster",
				"doppel",
				"Doppelturbo",
				14,
				"Booster_Twin",
				{"boost_power": 1.1, "boost_time": 1.1, "speed": 0.985},
				{},
				"Zwei Turbos: mehr und längerer Schub, das Gewicht kostet Endtempo.",
				"Doppelt schieben",
			),
			_part(
				"booster",
				"zuender",
				"Schnellzünder",
				10,
				"Booster_Igniter",
				{"drift_charge": 1.18, "boost_time": 0.84},
				{},
				"Drift-Turbo zündet früher, hält aber kürzer.",
				"Zündet früh",
			),
			_part(
				"booster",
				"kalt",
				"Kaltluftturbo",
				12,
				"Booster_Cool",
				{"accel": 1.06, "boost_power": 0.88},
				{},
				"Kühle Luft hilft beim Anfahren, der Turbo-Schub ist sanfter.",
				"Hilft beim Anfahren",
			),
		],
		"suspension":
		[
			_serie("Ausgewogen: Werksfahrwerk."),
			_part(
				"suspension",
				"sprung",
				"Sprungfedern",
				0,
				"Damper_Spring",
				{"landing": 0.35, "turn": 0.96, "grip": 0.97},
				{},
				"Weiche Landung, schaukelt in Kurven mehr.",
				"Weiche Landung",
				true
			),
			_part(
				"suspension",
				"sport",
				"Sportfahrwerk",
				10,
				"Damper_Sport",
				{"turn": 1.06, "grip": 1.04, "landing": 1.6},
				{},
				"Liegt flach in Kurven, Landungen sind härter.",
				"Flach in Kurven",
				true
			),
			_part(
				"suspension",
				"panzer",
				"Schwerfahrwerk",
				12,
				"Damper_Heavy",
				{"accel": 0.94},
				{"stability": 0.15},
				"Rempler bremsen kaum, zieht etwas träger an.",
				"Hält Rempler aus",
				true
			),
			_part(
				"suspension",
				"gelaende",
				"Geländefahrwerk",
				10,
				"Damper_Offroad",
				{"landing": 0.7, "turn": 0.94},
				{"offroad": 0.1},
				"Hoch und weich: gut im Gras und bei Landungen, lenkt träger.",
				"Hoch fürs Gelände",
			),
			_part(
				"suspension",
				"luft",
				"Luftfederung",
				14,
				"Damper_Air",
				{"landing": 0.55, "grip": 1.03, "accel": 0.95},
				{},
				"Luftkissen fangen Landungen auf, der Kompressor wiegt etwas.",
				"Luftkissen",
			),
		],
		"steering":
		[
			_serie("Ausgewogen: Werkslenkung."),
			_part(
				"steering",
				"direkt",
				"Direktlenkung",
				0,
				"Steer_Direct",
				{"turn": 1.1, "grip": 0.95},
				{},
				"Lenkt enger ein, das Heck rutscht dabei leichter.",
				"Enge Kurven",
			),
			_part(
				"steering",
				"ruhig",
				"Ruhige Lenkung",
				8,
				"Steer_Calm",
				{"turn": 0.93, "grip": 1.07},
				{},
				"Fährt ruhig und rutscht wenig, braucht mehr Platz in Kurven.",
				"Fährt ruhig",
			),
			_part(
				"steering",
				"servo",
				"Servolenkung",
				10,
				"Steer_Servo",
				{"turn": 1.05, "drift_grip": 1.06, "accel": 0.96},
				{},
				"Hilft beim Lenken und Driften, die Pumpe wiegt etwas.",
				"Leicht zu lenken",
			),
			_part(
				"steering",
				"flug",
				"Fluglenkung",
				12,
				"Steer_Air",
				{"air_turn": 1.5, "turn": 0.97},
				{},
				"Lenkt in der Luft weiter, am Boden etwas träger.",
				"Lenkt im Sprung",
			),
			_part(
				"steering",
				"spur",
				"Spurhalter",
				12,
				"Steer_Track",
				{"turn": 0.95},
				{"stability": 0.08},
				"Hält die Spur bei Remplern, lenkt etwas weniger eng.",
				"Bleibt in der Spur",
			),
		],
		"brakes":
		[
			_serie("Ausgewogen: Werksbremse."),
			_part(
				"brakes",
				"sport",
				"Sportbremse",
				0,
				"Brake_Sport",
				{"brake": 1.25, "accel": 0.97},
				{},
				"Große Scheiben bremsen viel kürzer, sie wiegen etwas.",
				"Kurzer Bremsweg",
			),
			_part(
				"brakes",
				"leicht",
				"Leichtbremse",
				8,
				"Brake_Light",
				{"accel": 1.05, "brake": 0.84},
				{},
				"Leicht und flink beim Anfahren, der Bremsweg wird länger.",
				"Leicht",
			),
			_part(
				"brakes",
				"drift",
				"Driftbremse",
				10,
				"Brake_Drift",
				{"drift_charge": 1.14, "brake": 0.9},
				{},
				"Hilft beim Eindriften: Drift-Turbo lädt schneller, bremst etwas schwächer.",
				"Hilft beim Driften",
			),
			_part(
				"brakes",
				"reku",
				"Ladebremse",
				14,
				"Brake_Regen",
				{"brake": 1.08, "boost_time": 1.1, "speed": 0.988},
				{},
				"Bremsen lädt den Turbo-Speicher: Turbo hält länger, Endtempo etwas niedriger.",
				"Lädt den Turbo",
			),
			_part(
				"brakes",
				"abs",
				"Spurbremse",
				10,
				"Brake_Abs",
				{"grip": 1.05, "brake": 0.92},
				{},
				"Räder blockieren nie: das Kart bleibt in der Spur, bremst etwas länger.",
				"Blockiert nie",
			),
		],
		"gearbox":
		[
			_serie("Ausgewogen: Werksgetriebe."),
			_part(
				"gearbox",
				"kurz",
				"Kurze Übersetzung",
				0,
				"Gear_Short",
				{"accel": 1.1, "speed": 0.982},
				{},
				"Kurze Gänge: flott aus der Kurve, Endtempo etwas niedriger.",
				"Flott los",
			),
			_part(
				"gearbox",
				"lang",
				"Lange Übersetzung",
				10,
				"Gear_Long",
				{"speed": 1.015, "accel": 0.9},
				{},
				"Lange Gänge: schneller geradeaus, braucht länger bis dahin.",
				"Schnell geradeaus",
			),
			_part(
				"gearbox",
				"turbo",
				"Turbogang",
				12,
				"Gear_Overdrive",
				{"boost_power": 1.12, "accel": 0.95},
				{},
				"Ein extra Gang für den Turbo: schneller im Turbo, flacher beim Anfahren.",
				"Gang für den Turbo",
			),
			_part(
				"gearbox",
				"gelaende",
				"Kriechgang",
				10,
				"Gear_Crawler",
				{"speed": 0.988},
				{"offroad": 0.08},
				"Zieht im Gras und Sand weiter, auf Asphalt etwas langsamer.",
				"Zieht im Gelände",
			),
			_part(
				"gearbox",
				"sperre",
				"Sperrdifferenzial",
				12,
				"Gear_Locker",
				{"drift_charge": 1.1, "drift_grip": 1.05, "turn": 0.97},
				{},
				"Beide Räder schieben gleich: Drift lädt schneller, lenkt etwas träger.",
				"Drift lädt",
			),
		],
		"ballast":
		[
			_serie("Ausgewogen: Gewicht in der Mitte."),
			_part(
				"ballast",
				"vorn",
				"Gewicht vorn",
				0,
				"Ballast_Front",
				{"turn": 1.06, "air_turn": 0.85},
				{},
				"Schwere Nase lenkt besser ein, in der Luft dreht es schwerer.",
				"Lenkt gut ein",
			),
			_part(
				"ballast",
				"hinten",
				"Gewicht hinten",
				8,
				"Ballast_Rear",
				{"accel": 1.05, "turn": 0.96},
				{},
				"Gewicht auf den Hinterrädern: schiebt besser an, lenkt etwas träger.",
				"Schiebt an",
			),
			_part(
				"ballast",
				"tief",
				"Tiefer Schwerpunkt",
				10,
				"Ballast_Low",
				{"grip": 1.05, "landing": 1.25},
				{},
				"Liegt tief und rutscht weniger, Landungen sind härter.",
				"Liegt tief",
			),
			_part(
				"ballast",
				"schwer",
				"Zusatzgewicht",
				10,
				"Ballast_Heavy",
				{"accel": 0.95, "landing": 1.1},
				{"stability": 0.1},
				"Schwer wie ein Fels: Rempler bremsen kaum, zieht träger an.",
				"Schwer wie ein Fels",
			),
			_part(
				"ballast",
				"leicht",
				"Leichtbau-Platten",
				12,
				"Ballast_Light",
				{"accel": 1.04, "air_turn": 1.1},
				{"stability": -0.07},
				"Leichtes Kart: flink und wendig im Sprung, Rempler bremsen mehr.",
				"Federleicht",
			),
		],
	}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = _build()
	return _catalog


static func is_slot(slot: String) -> bool:
	return SLOTS.has(slot)


static func options(slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(catalog().get(slot, []))
	return result


static func option(slot: String, id: String) -> Dictionary:
	for item in options(slot):
		if str(item.id) == id:
			return item
	var list: Array[Dictionary] = options(slot)
	return list[0] if not list.is_empty() else {}


## Alle Modell-Dateien der Teile (für Tests und das Vorladen).
static func files() -> Array[String]:
	var result: Array[String] = []
	for slot in SLOTS:
		for item in options(slot):
			var path: String = str(item.get("file", ""))
			if not path.is_empty() and not result.has(path):
				result.append(path)
	return result


## Faktor-Änderungen der gewählten Teile ({slot: id}) und einer Feineinstellung
## ({"mul": {}, "add": {}}, siehe kart_fine_tuning.gd), begrenzt auf PART_LIMITS.
static func changes(chosen: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var mul: Dictionary = {}
	var add: Dictionary = {}
	var sources: Array[Dictionary] = []
	for slot in SLOTS:
		sources.append(option(slot, str(chosen.get(slot, "serie"))))
	sources.append(extra)
	for entry in sources:
		for key in entry.get("mul", {}):
			mul[key] = float(mul.get(key, 1.0)) * float(entry.mul[key])
		for key in entry.get("add", {}):
			add[key] = float(add.get(key, 0.0)) + float(entry.add[key])
	for key in mul:
		if PART_LIMITS.has(key):
			mul[key] = clampf(float(mul[key]), PART_LIMITS[key][0], PART_LIMITS[key][1])
	for key in add:
		if ADD_LIMITS.has(key):
			add[key] = clampf(float(add[key]), ADD_LIMITS[key][0], ADD_LIMITS[key][1])
	return {"mul": mul, "add": add}


## Wendet die gewählten Teile ({slot: id}) und eine optionale Feineinstellung auf die
## Fahrfaktoren an (neues Dictionary). Ohne Teile bleibt jeder Faktor bitgleich.
static func apply(factors: Dictionary, chosen: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = factors.duplicate()
	var delta: Dictionary = changes(chosen, extra)
	for key in delta.mul:
		result[key] = float(result.get(key, 1.0)) * float(delta.mul[key])
	for key in delta.add:
		result[key] = float(result.get(key, 0.0)) + float(delta.add[key])
	# Gelände und Rempler bleiben Anteile des Tempos (unter 1).
	if result.has("offroad"):
		result["offroad"] = clampf(float(result.offroad), 0.2, 0.92)
	if result.has("stability"):
		result["stability"] = clampf(float(result.stability), 0.2, 0.85)
	return result


## Teile des Rivalen auf Startplatz index bei der Stufe difficulty ({} = Serie).
static func rival_parts(index: int, difficulty: String) -> Dictionary:
	if index < 0 or difficulty in ["", "gemuetlich"]:
		return {}
	return RIVAL_SETS[posmod(index, RIVAL_SETS.size())].duplicate()
