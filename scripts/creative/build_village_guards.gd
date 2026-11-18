extends RefCounted
## Wachen als Verbände mit Truppenart (Teil 6 von Heinz' Auftrag vom 18.11.2026
## und Nachtrag „echte Soldaten“). Reine Regeln, keine Szene. Die Arten,
## Stärken und die Begegnungsauflösung stehen in build_village_troops.gd.
##
## - Ein Soldat ist ein Bewohner in anderer Rolle: Wer ausgebildet wird,
##   wechselt nur die Rolle und wird einmal gezählt; er isst wie jeder Bewohner
##   1 Portion am Tag (steckt schon im Dorfverbrauch). Reiter brauchen für ihr
##   Pferd 1 Essen mehr: `town.troop_upkeep` (vom Verband abgeleitet).
## - Die Gesamtzahl bleibt `raids.guards` (alte Spielstände, Verteidigung). Die
##   Verbände teilen sie auf Art und Standort auf: Summe == raids.guards, immer.
##   Alte Stände mit nur einer Zahl werden zu Schildwachen in der Stadtmitte.
## - Ausbilden in Schritten 1 / 10 / 100. Obergrenze wie bisher: höchstens die
##   halbe Bevölkerung. Ab 10 auf einmal muss die eigene Ernte das ganze Dorf
##   versorgen – so gibt es 10, 100 und über 1.000 Soldaten je nach Größe und
##   Versorgung, aber nie einen Zwang zur Massenrekrutierung.
const SUPPLY = preload("res://scripts/creative/build_village_supply.gd")
const TROOPS = preload("res://scripts/creative/build_village_troops.gd")
const POSTS := {
	"mitte": "Stadtmitte", "nord": "Nordtor", "ost": "Osttor", "sued": "Südtor", "west": "Westtor"
}
const POST_ORDER := ["mitte", "nord", "ost", "sued", "west"]
const STEPS := [1, 10, 100]
const COIN_PER_GUARD := 1
## Ein Verband fasst bis zu 500 Soldaten; mehr werden ein neuer Verband.
const MAX_UNIT := 500
const MAX_UNITS := 60
const NAMES := ["Fuchs", "Eule", "Dachs", "Biber", "Igel", "Reh", "Luchs", "Otter", "Falke", "Bär"]
## Woher und als was die Gegner der Dorfwelt kommen (Lager, Höhle, Nachbarn).
const THREAT_ATTACKER := {"raeuber": "pluenderer", "rivale": "belagerer", "drache": "flieger"}
const THREAT_SIDE := {"raeuber": "sued", "rivale": "ost", "drache": "nord"}


## Verbände an die Gesamtzahl anpassen (alte Stände, Einzelausbildung, Laden).
## Fehlende Soldaten werden Schildwachen in der Stadtmitte, überzählige gehen
## zuerst aus den zuletzt gegründeten Verbänden.
static func reconcile(raids) -> void:
	var clean: Array = []
	var seen: Dictionary = {}
	for unit in raids.units:
		if not unit is Dictionary:
			continue
		var id := int(unit.get("id", 0))
		var size := int(unit.get("size", 0))
		var post := str(unit.get("post", "mitte"))
		var kind := str(unit.get("type", "schild"))
		if id < 1 or seen.has(id) or size < 1 or not POSTS.has(post):
			continue
		if not TROOPS.TYPES.has(kind):
			kind = "schild"
		seen[id] = true
		clean.append({"id": id, "name": str(unit.get("name", "")), "size": mini(size, MAX_UNIT), "post": post, "type": kind})
	raids.units = clean
	var difference := int(raids.guards) - total(raids)
	while difference > 0:
		var unit := _unit_with_room(raids, "mitte", "schild")
		var add := mini(difference, MAX_UNIT - int(unit.size))
		unit.size = int(unit.size) + add
		difference -= add
	var index: int = raids.units.size() - 1
	while difference < 0 and index >= 0:
		var unit: Dictionary = raids.units[index]
		var take := mini(-difference, int(unit.size))
		unit.size = int(unit.size) - take
		difference += take
		index -= 1
	raids.units = raids.units.filter(func(unit: Dictionary) -> bool: return int(unit.size) > 0)


## Pferdefutter der Reiter in den Dorfverbrauch übernehmen.
static func apply_upkeep(model, raids) -> void:
	if model != null:
		model._player["troop_upkeep"] = TROOPS.upkeep(raids.units)


static func total(raids) -> int:
	var sum := 0
	for unit in raids.units:
		sum += int(unit.size)
	return sum


static func count_of(raids, kind: String) -> int:
	var sum := 0
	for unit in raids.units:
		if str(unit.get("type", "schild")) == kind:
			sum += int(unit.size)
	return sum


static func _next_id(raids) -> int:
	var highest := 0
	for unit in raids.units:
		highest = maxi(highest, int(unit.id))
	return highest + 1


static func _new_unit(raids, post: String, kind := "schild") -> Dictionary:
	var id := _next_id(raids)
	var unit := {
		"id": id, "name": "%s-Trupp" % NAMES[(id - 1) % NAMES.size()], "size": 0, "post": post, "type": kind
	}
	raids.units.append(unit)
	return unit


static func _unit_with_room(raids, post: String, kind := "schild") -> Dictionary:
	for unit in raids.units:
		if str(unit.post) == post and str(unit.get("type", "schild")) == kind and int(unit.size) < MAX_UNIT:
			return unit
	return _new_unit(raids, post, kind)


static func find(raids, id: int) -> Dictionary:
	for unit in raids.units:
		if int(unit.id) == id:
			return unit
	return {}


## Freie Plätze für neue Soldaten (halbe Bevölkerung, wie bisher).
static func room(model, raids) -> int:
	return maxi(0, int(raids.max_guards(model)) - int(raids.guards))


static func has_site(raids, kind: String) -> bool:
	var site := TROOPS.site_needed(kind)
	return site.is_empty() or bool(raids.troop_sites.get(site, false))


## Ausbildungsstätte bauen (Schießplatz, Kaserne, Stall) – bezahlt aus dem Dorf.
static func build_site(model, raids, site: String) -> String:
	if not TROOPS.SITES.has(site):
		return "Diese Ausbildungsstätte gibt es nicht."
	if bool(raids.troop_sites.get(site, false)):
		return "%s steht schon." % str(TROOPS.SITES[site].title)
	if not model.exchange(TROOPS.SITES[site].cost, {}):
		return "Für %s fehlt noch etwas." % str(TROOPS.SITES[site].title)
	raids.troop_sites[site] = true
	return ""


## Warum geht diese Ausbildung nicht? "" = sie geht.
static func train_error(model, raids, count: int, post: String, kind := "schild") -> String:
	if count not in STEPS:
		return "Wähle 1, 10 oder 100 Soldaten."
	if not POSTS.has(post) or not TROOPS.TYPES.has(kind):
		return "Diesen Standort oder diese Truppe gibt es nicht."
	if not raids.expedition.is_empty():
		return "Die Wachen sind gerade unterwegs."
	if not has_site(raids, kind):
		return "Für %s brauchst du zuerst: %s." % [TROOPS.title(kind), str(TROOPS.SITES[TROOPS.site_needed(kind)].title)]
	if count > room(model, raids):
		return (
			"Dafür hat dein Dorf noch zu wenige Bewohner. Höchstens die Hälfte kann Soldat sein: noch %d."
			% room(model, raids)
		)
	if count > 1 or int(TROOPS.TYPES[kind].upkeep) > 0:
		var reserve := SUPPLY.town_reserve(model, model._player)
		var extra := int(TROOPS.TYPES[kind].upkeep) * count
		if int(reserve.balance) - extra < 0:
			return "Erst die Versorgung sichern: Deine Ernte reicht dann nicht für alle. Baue mehr Bauernhöfe."
	if not model._affords(model._player, TROOPS.cost(kind, count)):
		return "Für %d %s fehlt noch etwas aus dem Lager." % [count, TROOPS.title(kind, count)]
	if raids.units.size() >= MAX_UNITS and not _unit_with_room_exists(raids, post, kind):
		return "So viele Verbände kann Lumo nicht überblicken. Lege Verbände zusammen."
	return ""


static func _unit_with_room_exists(raids, post: String, kind: String) -> bool:
	for unit in raids.units:
		if str(unit.post) == post and str(unit.get("type", "schild")) == kind and int(unit.size) < MAX_UNIT:
			return true
	return false


## Ein Zug bildet 1, 10 oder 100 Soldaten einer Art aus und stellt sie auf.
static func train(model, raids, count: int, post: String, kind := "schild") -> String:
	var error := train_error(model, raids, count, post, kind)
	if not error.is_empty():
		return error
	if not model.exchange(TROOPS.cost(kind, count), {}):
		return model.last_error
	raids.guards = int(raids.guards) + count
	var left := count
	while left > 0:
		var unit := _unit_with_room(raids, post, kind)
		var add := mini(left, MAX_UNIT - int(unit.size))
		unit.size = int(unit.size) + add
		left -= add
	apply_upkeep(model, raids)
	return ""


## Ganzen Verband an einen anderen Standort verlegen.
static func move(raids, id: int, post: String) -> String:
	var unit := find(raids, id)
	if unit.is_empty() or not POSTS.has(post):
		return "Diesen Verband gibt es nicht."
	if not raids.expedition.is_empty():
		return "Die Wachen sind gerade unterwegs."
	unit.post = post
	return ""


## Einen Teil abspalten: ein neuer Verband gleicher Art am selben Standort.
static func split(raids, id: int, count: int) -> String:
	var unit := find(raids, id)
	if unit.is_empty():
		return "Diesen Verband gibt es nicht."
	if count < 1 or count >= int(unit.size):
		return "Ein Teil muss kleiner sein als der ganze Verband."
	if raids.units.size() >= MAX_UNITS:
		return "So viele Verbände kann Lumo nicht überblicken."
	unit.size = int(unit.size) - count
	var fresh := _new_unit(raids, str(unit.post), str(unit.get("type", "schild")))
	fresh.size = count
	return ""


## Zwei Verbände gleicher Art zusammenlegen (bis 500 je Verband).
static func merge(raids, into: int, from: int) -> String:
	var target := find(raids, into)
	var source := find(raids, from)
	if target.is_empty() or source.is_empty() or into == from:
		return "Wähle zwei verschiedene Verbände."
	if str(target.get("type", "schild")) != str(source.get("type", "schild")):
		return "Nur gleiche Truppen bilden einen Verband."
	if int(target.size) + int(source.size) > MAX_UNIT:
		return "Ein Verband fasst höchstens %d Soldaten." % MAX_UNIT
	target.size = int(target.size) + int(source.size)
	raids.units.erase(source)
	return ""


## Alle Verbände an einem Standort je Art zusammenfassen.
static func regroup(raids, post: String) -> void:
	var people := {}
	var kept: Array = []
	for unit in raids.units:
		if str(unit.post) == post:
			var kind := str(unit.get("type", "schild"))
			people[kind] = int(people.get(kind, 0)) + int(unit.size)
		else:
			kept.append(unit)
	raids.units = kept
	for kind in TROOPS.KINDS:
		var left := int(people.get(kind, 0))
		while left > 0:
			var unit := _new_unit(raids, post, kind)
			unit.size = mini(left, MAX_UNIT)
			left -= int(unit.size)


## Soldaten werden wieder Bewohner (kein Geld zurück, niemand verschwindet).
static func dismiss(raids, id: int, count: int, model = null) -> String:
	var unit := find(raids, id)
	if unit.is_empty() or count < 1 or count > int(unit.size):
		return "So viele Soldaten hat dieser Verband nicht."
	if not raids.expedition.is_empty():
		return "Die Wachen sind gerade unterwegs."
	unit.size = int(unit.size) - count
	raids.guards = int(raids.guards) - count
	if int(unit.size) == 0:
		raids.units.erase(unit)
	apply_upkeep(model, raids)
	return ""


## Verteidigungspunkte der Verbände gegen eine Bedrohung der Dorfwelt.
static func defense(raids, threat: String) -> float:
	var away := int(raids.expedition.get("guards", 0))
	var units: Array = raids.units
	if away > 0:
		# Unterwegs sind zuerst Soldaten aus der Stadtmitte.
		units = raids.units.duplicate(true)
		for unit in units:
			if away <= 0:
				break
			if str(unit.post) == "mitte":
				var take := mini(away, int(unit.size))
				unit.size = int(unit.size) - take
				away -= take
	return TROOPS.points(
		units, str(THREAT_ATTACKER.get(threat, "pluenderer")), str(THREAT_SIDE.get(threat, "sued")), raids.parts
	)


## Ein Satz für das Kind: wer kommt, wohin, welche Truppe hilft.
static func advice(threat: String) -> String:
	var side := str(THREAT_SIDE.get(threat, "sued"))
	return TROOPS.advice(str(THREAT_ATTACKER.get(threat, "pluenderer")), str(POSTS[side]))


## Gesamtzahl, Standorte, Arten und Versorgung für Anzeige und Bericht.
static func overview(model, raids) -> Dictionary:
	var posts := {}
	var kinds := {}
	for key in POST_ORDER:
		posts[key] = 0
	for kind in TROOPS.KINDS:
		kinds[kind] = 0
	var mix := {}
	for unit in raids.units:
		var kind := str(unit.get("type", "schild"))
		posts[str(unit.post)] = int(posts[str(unit.post)]) + int(unit.size)
		kinds[kind] = int(kinds[kind]) + int(unit.size)
		var key := "%s|%s" % [str(unit.post), kind]
		mix[key] = int(mix.get(key, 0)) + int(unit.size)
	var reserve := SUPPLY.town_reserve(model, model._player)
	return {
		"total": int(raids.guards),
		"units": raids.units.size(),
		"posts": posts,
		"kinds": kinds,
		"mix": mix,
		"room": room(model, raids),
		"food_per_day": int(raids.guards) + TROOPS.upkeep(raids.units),
		"horse_food": TROOPS.upkeep(raids.units),
		"supplied": int(reserve.balance) >= 0,
		"reserve_text": SUPPLY.reserve_text(reserve),
	}


## Vor dem Speichern abgleichen: wer `guards` direkt ändert (Regeln, Tests),
## bekommt nie einen Stand, in dem Verbände und Gesamtzahl auseinanderlaufen.
static func snapshot(raids) -> Array:
	reconcile(raids)
	return raids.units.duplicate(true)


static func restore(raids, raw: Variant) -> void:
	raids.units = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				raids.units.append({
					"id": int(item.get("id", 0)), "name": str(item.get("name", "")).left(40),
					"size": int(item.get("size", 0)), "post": str(item.get("post", "mitte")),
					"type": str(item.get("type", "schild"))
				})
	reconcile(raids)
