extends RefCounted
## Tuning-Werkstatt: Teile verbessern (Stufe 0–5) und Aussehen wählen (Lack, Felgen, Neon).
##
## Bezahlt wird mit Fortschrittssternen aus dem Lernen: Das Budget ist die Summe ALLER je
## verdienten Sterne (die App meldet sie beim Start). Die Sterne für die Belohnungen der App
## (Sticker, Spielzeit …) bleiben unberührt, Tuning nimmt dem Kind nichts weg. Ausgegeben wird
## nur auf dem Papier: Wer ein Kart zurücksetzt, bekommt alle Sterne dafür zurück.
## Der Spielstand liegt pro Kind in user://kart_workshop_<kind>.cfg und wird beim Laden geprüft;
## „ausgegeben“ wird immer aus den Stufen neu gerechnet, nie blind übernommen.
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
## Leistungsteile (Motor, Reifen, Flügel, Turbo, Fahrwerk) mit echter Wirkung aufs Fahren.
const PART_CATALOG = preload("res://scripts/games/kart_part_catalog.gd")
const MAX_LEVEL: int = 5
## Preis der Stufe 1 bis 5 (einzeln, nicht kumuliert). Ein Teil kostet bis zur Höchststufe 68 Sterne.
const LEVEL_COSTS: Array[int] = [4, 8, 12, 18, 26]
const PARTS: Array[Dictionary] = [
	{"id": "motor", "name": "Motor", "hint": "Mehr Tempo und mehr Zug aus der Kurve.", "bonus": {"speed": 0.4, "accel": 0.2}},
	{"id": "bremsen", "name": "Bremsen", "hint": "Kürzerer Bremsweg, mehr Kontrolle.", "bonus": {"brake": 0.5}},
	{"id": "reifen", "name": "Reifen", "hint": "Mehr Halt und genaueres Lenken.", "bonus": {"handling": 0.4}},
	{"id": "turbo", "name": "Turbo", "hint": "Stärkerer und längerer Boost.", "bonus": {"turbo": 0.5}},
]
## Aussehen: Lack ändert Karosserie, Zierleisten und Akzent; Felgen die Räder; Neon alle Leuchtteile.
const PAINTS: Array[Dictionary] = [
	{"id": "werk", "name": "Werkslack", "cost": 0},
	{"id": "feuer", "name": "Feuerrot", "cost": 6, "paint": Color("b3202a"), "trim": Color("f4f1ee"), "accent": Color("ffc23a")},
	{"id": "sonne", "name": "Sonnengelb", "cost": 6, "paint": Color("f0b92a"), "trim": Color("22242c"), "accent": Color("ff6a2c")},
	{"id": "minze", "name": "Minze", "cost": 6, "paint": Color("1d9a86"), "trim": Color("e9fff9"), "accent": Color("ff9a3c")},
	{"id": "violett", "name": "Violett", "cost": 6, "paint": Color("5a2fa8"), "trim": Color("e9ddff"), "accent": Color("ff7ad9")},
	{"id": "bonbon", "name": "Bonbonrosa", "cost": 8, "paint": Color("e0488f"), "trim": Color("fff1f8"), "accent": Color("5fe3ff")},
	{"id": "perle", "name": "Perlweiß", "cost": 10, "paint": Color("e6edf6"), "trim": Color("2b5aa8"), "accent": Color("ff8a2c")},
	{"id": "nacht", "name": "Nachtschwarz", "cost": 10, "paint": Color("12151d"), "trim": Color("7f8aa0"), "accent": Color("5fe3ff")},
	{"id": "gold", "name": "Goldglanz", "cost": 20, "paint": Color("d9a52a"), "trim": Color("fff4cf"), "accent": Color("1d3e8a")},
	{"id": "kupfer", "name": "Kupfer", "cost": 4, "paint": Color("9a512c"), "trim": Color("eee1cb"), "accent": Color("46d0bb")},
	{"id": "jade", "name": "Jade", "cost": 4, "paint": Color("326b46"), "trim": Color("e0ed9c"), "accent": Color("fbb84a")},
	{"id": "karmin", "name": "Karmin", "cost": 6, "paint": Color("77293d"), "trim": Color("d4a688"), "accent": Color("ff9265")},
	{"id": "koralle", "name": "Koralle", "cost": 4, "paint": Color("f07258"), "trim": Color("33234a"), "accent": Color("ffd47a")},
	{"id": "himmel", "name": "Himmelblau", "cost": 2, "paint": Color("73bee0"), "trim": Color("174269"), "accent": Color("ffe29b")},
	{"id": "ultramarin", "name": "Ultramarin", "cost": 4, "paint": Color("2944a5"), "trim": Color("d1eaf1"), "accent": Color("fab041")},
	{"id": "lagune", "name": "Lagune", "cost": 4, "paint": Color("096079"), "trim": Color("dedfff"), "accent": Color("71e9d2")},
	{"id": "lavendel", "name": "Lavendel", "cost": 4, "paint": Color("a899d6"), "trim": Color("563757"), "accent": Color("fff0bb")},
	{"id": "brombeere", "name": "Brombeere", "cost": 6, "paint": Color("622567"), "trim": Color("f1c3cd"), "accent": Color("adf290")},
	{"id": "malve", "name": "Malve", "cost": 4, "paint": Color("b35b77"), "trim": Color("ffdfbe"), "accent": Color("92e4da")},
	{"id": "tanne", "name": "Tannengrün", "cost": 4, "paint": Color("153b36"), "trim": Color("f2dd9e"), "accent": Color("f07d56")},
	{"id": "limette", "name": "Limette", "cost": 2, "paint": Color("92b929"), "trim": Color("103631"), "accent": Color("e2f1a0")},
	{"id": "creme", "name": "Creme", "cost": 4, "paint": Color("edd9ad"), "trim": Color("914b39"), "accent": Color("68a7b3")},
	{"id": "schiefer", "name": "Schiefer", "cost": 6, "paint": Color("48596b"), "trim": Color("e0e1cc"), "accent": Color("ff9b52")},
	{"id": "bernstein", "name": "Bernstein", "cost": 4, "paint": Color("e99829"), "trim": Color("345476"), "accent": Color("fff0bf")},
]
const RIMS: Array[Dictionary] = [
	{"id": "chrom", "name": "Chrom", "cost": 0, "color": Color("c9d6e6")},
	{"id": "schwarz", "name": "Schwarz", "cost": 4, "color": Color("232a38")},
	{"id": "rot", "name": "Rennrot", "cost": 4, "color": Color("d6323a")},
	{"id": "gold", "name": "Gold", "cost": 8, "color": Color("e8b73a")},
	{"id": "neon", "name": "Neon", "cost": 6, "color": Color("ffffff")},
]
const NEONS: Array[Dictionary] = [
	{"id": "werk", "name": "Wie ab Werk", "cost": 0},
	{"id": "cyan", "name": "Türkis", "cost": 4, "color": Color("5fe3ff")},
	{"id": "pink", "name": "Pink", "cost": 4, "color": Color("ff5ce6")},
	{"id": "gruen", "name": "Grün", "cost": 4, "color": Color("7dff7a")},
	{"id": "orange", "name": "Orange", "cost": 4, "color": Color("ff9a3c")},
	{"id": "weiss", "name": "Weiß", "cost": 4, "color": Color("f2fbff")},
	{"id": "rot", "name": "Rot", "cost": 4, "color": Color("ff4549")},
	{"id": "violett", "name": "Violett", "cost": 4, "color": Color("ab78ff")},
	{"id": "blau", "name": "Blau", "cost": 4, "color": Color("4b77ff")},
	{"id": "goldgelb", "name": "Goldgelb", "cost": 4, "color": Color("ffe358")},
	{"id": "mint", "name": "Mint", "cost": 4, "color": Color("3affb1")},
	{"id": "eisblau", "name": "Eisblau", "cost": 4, "color": Color("a9ceff")},
]
const KINDS: Array[String] = ["paint", "rims", "neon"]
## Radaufsätze und Auspuffblenden sind kostenlose Optikteile.
## „node“ ist der Knotenname im angegebenen GLB, ohne „file“ gilt kart_parts.glb.
const WHEEL_COVERS: Array[Dictionary] = [
	{"id": "serie", "name": "Serie", "cost": 0, "node": ""},
	{"id": "turbine", "name": "Turbinenrad", "cost": 0, "node": "WheelCover_Turbine"},
	{"id": "stern", "name": "Sternrad", "cost": 0, "node": "WheelCover_Star"},
]
const EXHAUSTS: Array[Dictionary] = [
	{"id": "serie", "name": "Serie", "cost": 0, "node": ""},
	{"id": "rakete", "name": "Raketendüse", "cost": 0, "node": "ExhaustTip_Rocket"},
	{"id": "doppel", "name": "Doppelrohr", "cost": 0, "node": "ExhaustTip_Twin"},
	{"id": "rally", "name": "Rallyrohr", "cost": 0, "node": "ExhaustTip_Rally", "file": PART_CATALOG.WORKSHOP_FILE},
	{"id": "schiefer", "name": "Sechskantblende", "cost": 0, "node": "ExhaustTip_Slate", "file": PART_CATALOG.WORKSHOP_FILE},
	{"id": "kupfer", "name": "Kupferrohr", "cost": 0, "node": "ExhaustTip_Copper", "file": PART_CATALOG.WORKSHOP_FILE},
	{"id": "gitter", "name": "Gitterdüse", "cost": 0, "node": "ExhaustTip_Vent", "file": PART_CATALOG.WORKSHOP_FILE},
	{"id": "versatz", "name": "Versetzte Doppelblende", "cost": 0, "node": "ExhaustTip_Slash", "file": PART_CATALOG.WORKSHOP_FILE},
]
## Alle Steckplätze der Garage: zuerst die neun Leistungsteile (kart_part_catalog.SLOTS),
## dann die zwei Optik-Teile.
const PART_SLOTS: Array[String] = [
	"engine", "tires", "wing", "booster", "suspension", "steering", "brakes", "gearbox",
	"ballast", "wheel_cover", "exhaust"
]
## Reine Optik („Aussehen“), ohne Einfluss aufs Fahren.
const LOOK_SLOTS: Array[String] = ["wheel_cover", "exhaust"]
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
	"wheel_cover": "Radkappe",
	"exhaust": "Auspuff",
}
## Feineinstellung (Reifendruck, Fahrwerkshärte, Flügelwinkel, Übersetzung, Lenkung).
const FINE = preload("res://scripts/games/kart_fine_tuning.gd")
## Erweiterte Optik je Kart (Garage, Bereich „Optik“), sichtbar in Garage und Rennen:
## Lackart, Zweitfarbe (Zierteile), Aufkleber-Satz, Startnummer, Cockpit-Farbe (Sitzbezug).
## Lumo selbst bleibt unverändert (Originalmodell, kein Helm).
const FINISH_TYPES: Array[Dictionary] = [
	{"id": "werk", "name": "Wie ab Werk", "cost": 0},
	{"id": "matte", "name": "Matt", "cost": 0},
	{"id": "metallic", "name": "Metallic", "cost": 0},
	{"id": "pearl", "name": "Perlmutt", "cost": 4},
	{"id": "glitter", "name": "Glitzer", "cost": 6},
]
const TWO_TONES: Array[Dictionary] = [
	{"id": "aus", "name": "Einfarbig", "cost": 0},
	{"id": "weiss", "name": "Weiß", "cost": 0, "color": Color("f2f5fa")},
	{"id": "schwarz", "name": "Schwarz", "cost": 0, "color": Color("1b1f27")},
	{"id": "gold", "name": "Gold", "cost": 4, "color": Color("e2b13c")},
	{"id": "tuerkis", "name": "Türkis", "cost": 4, "color": Color("27c2c8")},
	{"id": "orange", "name": "Orange", "cost": 4, "color": Color("ff8a2c")},
	{"id": "pink", "name": "Pink", "cost": 4, "color": Color("ff5ca8")},
]
## Aufkleber aus kart_sticker_atlas.png (Fantasie-Marken, keine echten): vorn und hinten.
const STICKER_SETS: Array[Dictionary] = [
	{"id": "werk", "name": "Wie ab Werk", "cost": 0},
	{"id": "fuchs", "name": "Fuchsstern", "cost": 0, "stickers": ["fuchsstern", "pfotenpower"]},
	{"id": "blitz", "name": "Blitzbox", "cost": 0, "stickers": ["blitzbox", "turbotee"]},
	{"id": "zahlen", "name": "Zahlenzauber", "cost": 3, "stickers": ["zahlenzauber", "lerncrew"]},
	{"id": "polar", "name": "Polarlicht", "cost": 3, "stickers": ["polarlicht", "kometen"]},
	{"id": "rallye", "name": "Rallye", "cost": 3, "stickers": ["checker", "mondreifen"]},
	{"id": "hafen", "name": "Sonnenhafen", "cost": 3, "stickers": ["sonnenhafen", "wolkenwerk"]},
]
const COCKPITS: Array[Dictionary] = [
	{"id": "werk", "name": "Wie ab Werk", "cost": 0},
	{"id": "rot", "name": "Rennrot", "cost": 0, "color": Color("c4303a")},
	{"id": "blau", "name": "Tiefblau", "cost": 0, "color": Color("2448a8")},
	{"id": "gruen", "name": "Grün", "cost": 3, "color": Color("2f9a52")},
	{"id": "gelb", "name": "Sonnengelb", "cost": 3, "color": Color("e9b72c")},
	{"id": "lila", "name": "Lila", "cost": 3, "color": Color("7a46c8")},
]
## Startnummer: 0 = wie ab Werk (Platz in der Flotte), sonst 1 bis 99, kostenlos.
const MAX_NUMBER: int = 99
## Optik-Arten, die gespeichert werden (zusätzlich zu Lack, Felgen, Neon).
const LOOK_KINDS: Array[String] = ["finish_type", "two_tone", "stickers", "number", "cockpit"]
static var _numbers: Array[Dictionary] = []

var child_key: String = "standalone"
## Alle je verdienten Fortschrittssterne (von der App gemeldet, nie kleiner als der Stand beim Laden).
var lifetime_stars: int = 0
var levels: Dictionary = {}  # kart_id -> {part_id: int}
var looks: Dictionary = {}  # kart_id -> {paint: id, rims: id, neon: id}
var owned: Array[String] = []  # "paint:feuer", "rims:gold" …
var tunes: Dictionary = {}  # kart_id -> {setting_id: -2..2} (Feineinstellung, 0 fehlt)
var save_enabled: bool = true


static func path_for(child: String) -> String:
	var safe: String = ""
	for character in child:
		safe += character if (character.is_valid_identifier() or character == "-" or character.is_valid_int()) else "_"
	return "user://kart_workshop_%s.cfg" % (safe.substr(0, 80) if not safe.is_empty() else "standalone")


func _init(child: String = "standalone", stars: int = 0) -> void:
	child_key = child
	lifetime_stars = maxi(0, stars)
	load_from_disk()


func path() -> String:
	return path_for(child_key)


# ------------------------------------------------------------------ Katalog

static func part(id: String) -> Dictionary:
	for item in PARTS:
		if str(item.id) == id:
			return item
	return {}


static func options(kind: String) -> Array[Dictionary]:
	match kind:
		"paint":
			return PAINTS
		"rims":
			return RIMS
		"neon":
			return NEONS
		"wheel_cover":
			return WHEEL_COVERS
		"exhaust":
			return EXHAUSTS
		"finish_type":
			return FINISH_TYPES
		"two_tone":
			return TWO_TONES
		"stickers":
			return STICKER_SETS
		"cockpit":
			return COCKPITS
		"number":
			return numbers()
	if PART_CATALOG.is_slot(kind):
		return PART_CATALOG.options(kind)
	return []


static func option(kind: String, id: String) -> Dictionary:
	for item in options(kind):
		if str(item.id) == id:
			return item
	var list: Array[Dictionary] = options(kind)
	return list[0] if not list.is_empty() else {}


## Startnummern als Auswahl: „werk“ und 1 bis 99 (alle kostenlos).
static func numbers() -> Array[Dictionary]:
	if _numbers.is_empty():
		_numbers.append({"id": "werk", "name": "Wie ab Werk", "cost": 0})
		for number in range(1, MAX_NUMBER + 1):
			_numbers.append({"id": str(number), "name": "Nr. %d" % number, "cost": 0, "number": number})
	return _numbers


static func cost_of_level(level: int) -> int:
	return LEVEL_COSTS[clampi(level, 1, MAX_LEVEL) - 1]


## Summe der Preise bis zur gegebenen Stufe.
static func cost_to_reach(level: int) -> int:
	var sum: int = 0
	for index in range(clampi(level, 0, MAX_LEVEL)):
		sum += LEVEL_COSTS[index]
	return sum


# ------------------------------------------------------------------ Stand

func level(kart_id: String, part_id: String) -> int:
	var kart: Dictionary = levels.get(kart_id, {})
	return clampi(int(kart.get(part_id, 0)), 0, MAX_LEVEL)


func total_level(kart_id: String) -> int:
	var sum: int = 0
	for item in PARTS:
		sum += level(kart_id, str(item.id))
	return sum


func spent_on_parts() -> int:
	var sum: int = 0
	for kart_id in levels:
		for item in PARTS:
			sum += cost_to_reach(level(str(kart_id), str(item.id)))
	return sum


func spent_on_looks() -> int:
	var sum: int = 0
	for key in owned:
		var pieces: PackedStringArray = key.split(":")
		if pieces.size() == 2:
			sum += int(option(pieces[0], pieces[1]).get("cost", 0))
	return sum


func spent() -> int:
	return spent_on_parts() + spent_on_looks()


func available() -> int:
	return maxi(0, lifetime_stars - spent())


## Preis der nächsten Stufe; −1, wenn das Teil schon die Höchststufe hat.
func next_cost(kart_id: String, part_id: String) -> int:
	var current: int = level(kart_id, part_id)
	return -1 if current >= MAX_LEVEL else cost_of_level(current + 1)


func can_upgrade(kart_id: String, part_id: String) -> bool:
	var price: int = next_cost(kart_id, part_id)
	return not part(part_id).is_empty() and price >= 0 and price <= available()


func upgrade(kart_id: String, part_id: String) -> bool:
	if not can_upgrade(kart_id, part_id):
		return false
	var kart: Dictionary = levels.get(kart_id, {})
	kart[part_id] = level(kart_id, part_id) + 1
	levels[kart_id] = kart
	save()
	return true


## Setzt alle Teile eines Karts auf Stufe 0 zurück und gibt die Sterne zurück (Aussehen bleibt).
func refund(kart_id: String) -> int:
	var back: int = 0
	for item in PARTS:
		back += cost_to_reach(level(kart_id, str(item.id)))
	if back > 0:
		levels.erase(kart_id)
		save()
	return back


# ------------------------------------------------------------------ Werte

func bonus(kart_id: String) -> Dictionary:
	var result: Dictionary = {}
	for key in FLEET.STATS:
		result[key] = 0.0
	for item in PARTS:
		var current: int = level(kart_id, str(item.id))
		for stat in item.bonus:
			result[stat] = float(result[stat]) + float(item.bonus[stat]) * float(current)
	return result


## Grundwerte plus Tuning, begrenzt auf die Skala.
func stats(kart_id: String) -> Dictionary:
	var base: Dictionary = FLEET.base_stats(kart_id)
	var extra: Dictionary = bonus(kart_id)
	var result: Dictionary = {}
	for key in FLEET.STATS:
		result[key] = minf(FLEET.MAX_STAT, float(base[key]) + float(extra[key]))
	return result


## Fahrfaktoren mit Tuning-Stufen, montierten Leistungsteilen und Feineinstellung
## (so fährt das Rennen).
func multipliers(kart_id: String) -> Dictionary:
	return PART_CATALOG.apply(
		FLEET.multipliers(stats(kart_id), FLEET.entry(kart_id).traits), mounted(kart_id),
		FINE.changes(tune(kart_id))
	)


## Faktoren mit einer anderen Teile-Auswahl bzw. Feineinstellung (Prüfstand: „nachher“ vor
## dem Montieren). tune_values = null: gespeicherte Feineinstellung.
func multipliers_with(kart_id: String, parts: Dictionary, tune_values: Variant = null) -> Dictionary:
	var chosen_parts: Dictionary = mounted(kart_id)
	for key in parts:
		if PART_CATALOG.is_slot(str(key)):
			chosen_parts[key] = parts[key]
	var values: Dictionary = tune(kart_id) if not (tune_values is Dictionary) else tune_values
	return PART_CATALOG.apply(
		FLEET.multipliers(stats(kart_id), FLEET.entry(kart_id).traits), chosen_parts,
		FINE.changes(values)
	)


## Faktoren des Karts ganz ohne Teile und Feineinstellung (Vergleich „Serie“ im Prüfstand).
func multipliers_stock(kart_id: String) -> Dictionary:
	return FLEET.multipliers(stats(kart_id), FLEET.entry(kart_id).traits)


# ------------------------------------------------------------------ Feineinstellung

## Gespeicherte Feineinstellung eines Karts ({setting: -2..2}, fehlende = 0).
func tune(kart_id: String) -> Dictionary:
	return FINE.sanitize(tunes.get(kart_id, {}))


func tune_value(kart_id: String, setting_id: String) -> int:
	return int(tune(kart_id).get(setting_id, 0))


## Speichert eine ganze Feineinstellung (kostenlos, jederzeit änderbar).
func set_tune(kart_id: String, values: Dictionary) -> void:
	var clean: Dictionary = FINE.sanitize(values)
	if clean.is_empty():
		tunes.erase(kart_id)
	else:
		tunes[kart_id] = clean
	save()


func set_tune_value(kart_id: String, setting_id: String, value: int) -> void:
	var values: Dictionary = tune(kart_id)
	values[setting_id] = value
	set_tune(kart_id, values)


## Voreinstellung („kurve“, „sprint“, „allround“) übernehmen.
func apply_preset(kart_id: String, preset_id: String) -> bool:
	var entry: Dictionary = FINE.preset(preset_id)
	if entry.is_empty():
		return false
	set_tune(kart_id, entry["values"])
	return true


## Feineinstellung auf Werk zurücksetzen.
func reset_tune(kart_id: String) -> void:
	set_tune(kart_id, {})


## Montierte Leistungsteile eines Karts: {slot: id}.
func mounted(kart_id: String) -> Dictionary:
	var result: Dictionary = {}
	for slot in PART_CATALOG.SLOTS:
		result[slot] = chosen(kart_id, slot)
	return result


## Fahrwerte aus demselben Antrieb wie die Fahrphysik (kart_powertrain.gd, kart_island._drive_player).
## Höchsttempo, Beschleunigung und Bremsweg kommen aus dem aktuellen Antrieb.
## Der Bremsweg aus 72 km/h integriert denselben Geschwindigkeitsnachlauf wie die Fahrt.


static func performance_for(factors: Dictionary) -> Dictionary:
	return {
		"top_kmh": POWERTRAIN.top_speed(factors, POWERTRAIN.race_pace()) * 3.6,
		"zero_to_54_s": 15.0 / POWERTRAIN.acceleration(factors, false),
		"brake_m": POWERTRAIN.stopping_distance(factors),
	}


func performance(kart_id: String, with_tuning: bool = true) -> Dictionary:
	if with_tuning:
		return performance_for(multipliers(kart_id))
	return performance_for(FLEET.multipliers(FLEET.base_stats(kart_id), FLEET.entry(kart_id).traits))


# ------------------------------------------------------------------ Aussehen

func has_option(kind: String, id: String) -> bool:
	return int(option(kind, id).get("cost", 0)) == 0 or owned.has("%s:%s" % [kind, id])


func chosen(kart_id: String, kind: String) -> String:
	var look: Dictionary = looks.get(kart_id, {})
	var id: String = str(look.get(kind, ""))
	var list: Array[Dictionary] = options(kind)
	for item in list:
		if str(item.id) == id and has_option(kind, id):
			return id
	return str(list[0].id)


func can_buy_option(kind: String, id: String) -> bool:
	var entry: Dictionary = option(kind, id)
	return str(entry.get("id", "")) == id and not has_option(kind, id) and int(entry.cost) <= available()


func buy_option(kind: String, id: String) -> bool:
	if not can_buy_option(kind, id):
		return false
	owned.append("%s:%s" % [kind, id])
	save()
	return true


## A build can include locked parts from several slots. Validate the whole basket
## before spending stars and persist it once, including when storage is unavailable.
func unlock_parts(parts: Dictionary) -> bool:
	var purchases: Array[String] = []
	var price := 0
	for slot in parts:
		var id := str(parts[slot])
		var entry := option(slot, id)
		if not PART_SLOTS.has(slot) or str(entry.get("id", "")) != id:
			return false
		if not has_option(slot, id):
			purchases.append("%s:%s" % [slot, id])
			price += int(entry.cost)
	if price > available():
		return false
	owned.append_array(purchases)
	if save():
		return true
	for key in purchases:
		owned.erase(key)
	return false


func mount_parts(kart_id: String, parts: Dictionary) -> bool:
	var previous: Dictionary = looks.get(kart_id, {})
	var equipped := previous.duplicate()
	for slot in parts:
		var id := str(parts[slot])
		if not PART_SLOTS.has(slot) or str(option(slot, id).get("id", "")) != id or not has_option(slot, id):
			return false
		equipped[slot] = id
	if equipped == previous:
		return true
	var existed := looks.has(kart_id)
	looks[kart_id] = equipped
	if save():
		return true
	if existed:
		looks[kart_id] = previous
	else:
		looks.erase(kart_id)
	return false


## Wählt ein besessenes Aussehen für ein Kart.
func choose(kart_id: String, kind: String, id: String) -> bool:
	if str(option(kind, id).get("id", "")) != id or not has_option(kind, id):
		return false
	var look: Dictionary = looks.get(kart_id, {})
	look[kind] = id
	looks[kart_id] = look
	save()
	return true


## Fertige Darstellung für den Fahrzeugbau: Farben und Tuning-Stufen.
func look(kart_id: String) -> Dictionary:
	var base: Dictionary = FLEET.entry(kart_id).look
	var paint: Dictionary = option("paint", chosen(kart_id, "paint"))
	var rims: Dictionary = option("rims", chosen(kart_id, "rims"))
	var neon: Dictionary = option("neon", chosen(kart_id, "neon"))
	var result: Dictionary = {
		"body": str(base.body),
		"paint": paint.get("paint", base.paint),
		"trim": paint.get("trim", base.trim),
		"accent": paint.get("accent", base.accent),
		"neon": neon.get("color", base.neon),
		"rim": rims.get("color", Color("c9d6e6")),
		"rim_neon": str(rims.id) == "neon",
		"wheel_cover": chosen(kart_id, "wheel_cover"),
		"exhaust": chosen(kart_id, "exhaust"),
		"levels": {},
		"underglow": str(neon.id) != "werk" or total_level(kart_id) >= 8,
	}
	for slot in PART_CATALOG.SLOTS:
		result[slot] = chosen(kart_id, slot)
	for item in PARTS:
		result.levels[str(item.id)] = level(kart_id, str(item.id))
	return result.merged(look_extras(kart_id, {}), true)


## Erweiterte Optik als Look-Schlüssel für den Fahrzeugbau (kart_production_vehicle.gd).
## override: {kind: id} offene Vorschau (Garage), sonst gespeicherte Wahl.
func look_extras(kart_id: String, override: Dictionary) -> Dictionary:
	var pick := func(kind: String) -> Dictionary:
		var id: String = str(override.get(kind, chosen(kart_id, kind)))
		return option(kind, id)
	var result: Dictionary = {}
	var finish: Dictionary = pick.call("finish_type")
	result["finish_type"] = str(finish.get("id", "werk"))
	var two: Dictionary = pick.call("two_tone")
	if two.has("color"):
		result["two_tone"] = two.color
	var stickers: Dictionary = pick.call("stickers")
	if stickers.has("stickers"):
		result["stickers"] = (stickers.stickers as Array).duplicate()
	var number: Dictionary = pick.call("number")
	result["number"] = int(number.get("number", 0))
	var cockpit: Dictionary = pick.call("cockpit")
	if cockpit.has("color"):
		result["cockpit"] = cockpit.color
	return result


# ------------------------------------------------------------------ Speichern

func load_from_disk() -> void:
	levels.clear()
	looks.clear()
	owned.clear()
	tunes.clear()
	var config := ConfigFile.new()
	if config.load(path()) != OK:
		return
	for kart_id in FLEET.ids():
		var section: String = "kart_" + kart_id
		var kart: Dictionary = {}
		for item in PARTS:
			var value: int = clampi(int(config.get_value(section, str(item.id), 0)), 0, MAX_LEVEL)
			if value > 0:
				kart[str(item.id)] = value
		if not kart.is_empty():
			levels[kart_id] = kart
		var look: Dictionary = {}
		for kind in KINDS + PART_SLOTS + LOOK_KINDS:
			var id: String = str(config.get_value(section, kind, ""))
			if not id.is_empty():
				look[kind] = id
		if not look.is_empty():
			looks[kart_id] = look
		var tune_values: Dictionary = {}
		for setting_id in FINE.ids():
			tune_values[setting_id] = int(config.get_value(section, "tune_" + setting_id, 0))
		tune_values = FINE.sanitize(tune_values)
		if not tune_values.is_empty():
			tunes[kart_id] = tune_values
	var raw: Variant = config.get_value("owned", "items", [])
	if raw is Array or raw is PackedStringArray:
		for entry in raw:
			var key: String = str(entry)
			var pieces: PackedStringArray = key.split(":")
			if pieces.size() == 2 and not option(pieces[0], pieces[1]).is_empty() and str(option(pieces[0], pieces[1]).id) == pieces[1] and not owned.has(key):
				owned.append(key)
	# Der gespeicherte Höchststand der verdienten Sterne darf nie sinken (z. B. wenn die App einmal 0 meldet).
	lifetime_stars = maxi(lifetime_stars, int(config.get_value("meta", "lifetime", 0)))


func save() -> bool:
	if not save_enabled:
		return true
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("meta", "lifetime", lifetime_stars)
	for kart_id in levels:
		for part_id in levels[kart_id]:
			config.set_value("kart_" + str(kart_id), str(part_id), int(levels[kart_id][part_id]))
	for kart_id in looks:
		for kind in looks[kart_id]:
			config.set_value("kart_" + str(kart_id), str(kind), str(looks[kart_id][kind]))
	for kart_id in tunes:
		var clean: Dictionary = FINE.sanitize(tunes[kart_id])
		for setting_id in clean:
			config.set_value("kart_" + str(kart_id), "tune_" + str(setting_id), int(clean[setting_id]))
	config.set_value("owned", "items", owned)
	var target: String = path()
	var temporary: String = target + ".tmp"
	if config.save(temporary) != OK:
		return false
	# Replace in the same directory. Removing the previous profile first would
	# lose the mounted setup if the rename fails or the app closes between calls.
	return DirAccess.rename_absolute(temporary, target) == OK


## Setzt die Sterne-Obergrenze hoch (nie herunter) und merkt sie sich.
func report_lifetime(stars: int) -> void:
	if stars > lifetime_stars:
		lifetime_stars = stars
		save()
