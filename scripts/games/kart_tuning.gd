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
]
const KINDS: Array[String] = ["paint", "rims", "neon"]

var child_key: String = "standalone"
## Alle je verdienten Fortschrittssterne (von der App gemeldet, nie kleiner als der Stand beim Laden).
var lifetime_stars: int = 0
var levels: Dictionary = {}  # kart_id -> {part_id: int}
var looks: Dictionary = {}  # kart_id -> {paint: id, rims: id, neon: id}
var owned: Array[String] = []  # "paint:feuer", "rims:gold" …
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
	return []


static func option(kind: String, id: String) -> Dictionary:
	for item in options(kind):
		if str(item.id) == id:
			return item
	var list: Array[Dictionary] = options(kind)
	return list[0] if not list.is_empty() else {}


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


func multipliers(kart_id: String) -> Dictionary:
	return FLEET.multipliers(stats(kart_id), FLEET.entry(kart_id).traits)


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
		"levels": {},
		"underglow": str(neon.id) != "werk" or total_level(kart_id) >= 8,
	}
	for item in PARTS:
		result.levels[str(item.id)] = level(kart_id, str(item.id))
	return result


# ------------------------------------------------------------------ Speichern

func load_from_disk() -> void:
	levels.clear()
	looks.clear()
	owned.clear()
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
		for kind in KINDS:
			var id: String = str(config.get_value(section, kind, ""))
			if not id.is_empty():
				look[kind] = id
		if not look.is_empty():
			looks[kart_id] = look
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
	config.set_value("owned", "items", owned)
	var target: String = path()
	var temporary: String = target + ".tmp"
	if config.save(temporary) != OK:
		return false
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	return DirAccess.rename_absolute(temporary, target) == OK


## Setzt die Sterne-Obergrenze hoch (nie herunter) und merkt sie sich.
func report_lifetime(stars: int) -> void:
	if stars > lifetime_stars:
		lifetime_stars = stars
		save()
