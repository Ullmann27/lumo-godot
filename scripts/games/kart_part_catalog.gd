extends RefCounted
## Leistungsteile der Garage: fünf Steckplätze mit Serie und je zwei bis drei Varianten.
##
## Jede Variante hat einen klaren Charakter und eine Abwägung – keine ist nur „besser“.
## Sie verändert die Fahrfaktoren aus kart_fleet.multipliers(): „mul“ multipliziert,
## „add“ addiert (Gelände, Rempler). Die Faktoren liest das Rennen über
## kart_powertrain.gd; der Prüfstand (kart_dyno.gd) misst mit denselben Formeln.
## Serie und eine Variante je Steckplatz kosten nichts, die übrigen werden mit Sternen aus
## dem Lernen freigeschaltet (nur auf dem Papier ausgegeben, wie in kart_tuning.gd).
## „node“ ist der Knotenname in assets/kart/production/parts/kart_parts.glb
## (tools/lumo_kart_art/karts/build_parts.py), „mount“ der Montagepunkt am Kart.

const SLOTS: Array[String] = ["engine", "tires", "wing", "booster", "suspension"]
const SLOT_NAMES: Dictionary = {
	"engine": "Motor",
	"tires": "Reifen",
	"wing": "Flügel",
	"booster": "Turbo",
	"suspension": "Fahrwerk",
}
## Werte, die der Prüfstand je Steckplatz zeigt (höchstens drei, kindgerecht).
const SLOT_METRICS: Dictionary = {
	"engine": ["top_kmh", "sprint_s"],
	"tires": ["slide_m", "drift_s", "offroad_kmh"],
	"wing": ["top_kmh", "slide_m", "air_deg"],
	"booster": ["boost_kmh", "boost_s"],
	"suspension": ["landing_s", "radius_m", "bump_pct"],
}
const SERIE := {
	"id": "serie",
	"name": "Serie",
	"cost": 0,
	"node": "",
	"mul": {},
	"add": {},
	"short": "Ausgewogen"
}

## Rivalen-Sätze je Fahrstil in der Reihenfolge von kart_rival_racecraft.STYLES (precise,
## attacker, patient, flow, defender). Ab „Abenteuer“ fahren die Rivalen mit diesen Teilen –
## sichtbar am Kart und mit derselben Wirkung (kart_rival_racecraft.factors). In „Entdecken“
## fahren sie Serie: dort soll das Kind auch ohne Teile vorne mitfahren.
const RIVAL_SETS: Array[Dictionary] = [
	{"tires": "haft", "wing": "gross"},
	{"engine": "sprint", "booster": "kurz"},
	{"engine": "dauer", "suspension": "sprung"},
	{"tires": "drift", "booster": "lang"},
	{"suspension": "panzer", "wing": "flach"},
]

static var _catalog: Dictionary = {}


static func _build() -> Dictionary:
	return {
		"engine":
		[
			SERIE.merged({"text": "Ausgewogen: Werksmotor."}),
			{
				"id": "sprint",
				"name": "Sprintmotor",
				"cost": 0,
				"node": "Engine_Sprint",
				"mul": {"accel": 1.14, "speed": 0.975},
				"add": {},
				"text": "Zieht schneller an, Endtempo etwas niedriger.",
				"short": "Schneller Antritt",
			},
			{
				"id": "dauer",
				"name": "Langstreckenmotor",
				"cost": 10,
				"node": "Engine_Long",
				"mul": {"speed": 1.022, "accel": 0.86},
				"add": {},
				"text": "Höheres Endtempo, braucht länger bis dahin.",
				"short": "Hohes Endtempo",
			},
		],
		"tires":
		[
			SERIE.merged({"text": "Ausgewogen: Werksreifen."}),
			{
				"id": "haft",
				"name": "Haftreifen",
				"cost": 0,
				"node": "Tire_Grip",
				"mul": {"grip": 1.18, "turn": 1.03, "drift_charge": 0.8},
				"add": {},
				"text": "Klebt in Kurven, Drift-Turbo lädt langsamer.",
				"short": "Klebt in Kurven",
			},
			{
				"id": "drift",
				"name": "Driftreifen",
				"cost": 8,
				"node": "Tire_Drift",
				"mul": {"grip": 0.86, "drift_charge": 1.3, "drift_grip": 1.12},
				"add": {},
				"text": "Rutscht leichter, Drift-Turbo lädt schneller.",
				"short": "Drift lädt schnell",
			},
			{
				"id": "stollen",
				"name": "Stollenreifen",
				"cost": 12,
				"node": "Tire_Knobby",
				"mul": {"grip": 0.96, "speed": 0.985},
				"add": {"offroad": 0.16},
				"text": "Schnell neben der Straße, auf Asphalt etwas langsamer.",
				"short": "Stark im Gelände",
			},
		],
		"wing":
		[
			SERIE.merged({"text": "Ausgewogen: Werksheck."}),
			{
				"id": "gross",
				"name": "Großflügel",
				"cost": 0,
				"node": "Wing_Big",
				"mul": {"grip": 1.12, "turn": 1.05, "speed": 0.978},
				"add": {},
				"text": "Hält in Kurven, langsamer geradeaus.",
				"short": "Hält in Kurven",
			},
			{
				"id": "flach",
				"name": "Flachflügel",
				"cost": 8,
				"node": "Wing_Flat",
				"mul": {"speed": 1.012, "grip": 0.9, "turn": 0.97},
				"add": {},
				"text": "Schneller geradeaus, rutscht in Kurven mehr.",
				"short": "Schnell geradeaus",
			},
			{
				"id": "gleiter",
				"name": "Gleitflügel",
				"cost": 12,
				"node": "Wing_Glide",
				"mul": {"air_turn": 1.8, "speed": 0.99},
				"add": {},
				"text": "Lenkt in der Luft, etwas langsamer geradeaus.",
				"short": "Lenkt im Flug",
			},
		],
		"booster":
		[
			SERIE.merged({"text": "Ausgewogen: Werksturbo."}),
			{
				"id": "kurz",
				"name": "Kurzschub",
				"cost": 0,
				"node": "Booster_Short",
				"mul": {"boost_power": 1.25, "boost_time": 0.72},
				"add": {},
				"text": "Kurzer, starker Schub.",
				"short": "Kurz und stark",
			},
			{
				"id": "lang",
				"name": "Langschub",
				"cost": 10,
				"node": "Booster_Long",
				"mul": {"boost_power": 0.8, "boost_time": 1.35},
				"add": {},
				"text": "Sanfter Schub, der lange hält.",
				"short": "Lang und sanft",
			},
		],
		"suspension":
		[
			SERIE.merged({"text": "Ausgewogen: Werksfahrwerk."}),
			{
				"id": "sprung",
				"name": "Sprungfedern",
				"cost": 0,
				"node": "Damper_Spring",
				"mul": {"landing": 0.35, "turn": 0.96, "grip": 0.97},
				"add": {},
				"text": "Weiche Landung, schaukelt in Kurven mehr.",
				"short": "Weiche Landung",
			},
			{
				"id": "sport",
				"name": "Sportfahrwerk",
				"cost": 10,
				"node": "Damper_Sport",
				"mul": {"turn": 1.06, "grip": 1.04, "landing": 1.6},
				"add": {},
				"text": "Liegt flach in Kurven, Landungen sind härter.",
				"short": "Flach in Kurven",
			},
			{
				"id": "panzer",
				"name": "Schwerfahrwerk",
				"cost": 12,
				"node": "Damper_Heavy",
				"mul": {"accel": 0.94},
				"add": {"stability": 0.15},
				"text": "Rempler bremsen kaum, zieht etwas träger an.",
				"short": "Hält Rempler aus",
			},
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


## Wendet die gewählten Teile ({slot: id}) auf Fahrfaktoren an (neues Dictionary).
static func apply(factors: Dictionary, chosen: Dictionary) -> Dictionary:
	var result: Dictionary = factors.duplicate()
	for slot in SLOTS:
		var entry: Dictionary = option(slot, str(chosen.get(slot, "serie")))
		for key in entry.get("mul", {}):
			result[key] = float(result.get(key, 1.0)) * float(entry.mul[key])
		for key in entry.get("add", {}):
			result[key] = float(result.get(key, 0.0)) + float(entry.add[key])
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
