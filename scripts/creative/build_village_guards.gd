extends RefCounted
## Wachen als Verbände (Teil 6 von Heinz' Auftrag vom 18.11.2026: Mengen und
## Verwaltung). Reine Regeln, keine Szene.
##
## - Eine Wache ist ein Bewohner mit Helm: Wer ausgebildet wird, wechselt nur
##   die Rolle und wird einmal gezählt; sie isst wie jeder Bewohner 1 Portion
##   am Tag (steckt schon im Dorfverbrauch).
## - Die Gesamtzahl bleibt `raids.guards` (Verteidigung, alte Spielstände). Die
##   Verbände teilen diese Zahl auf Standorte auf: Summe == raids.guards, immer.
## - Ausbilden in Schritten 1 / 10 / 100. Obergrenze wie bisher: höchstens die
##   halbe Bevölkerung. Ab 10 auf einmal muss die eigene Ernte das ganze Dorf
##   versorgen – so gibt es 10, 100 und über 1.000 Wachen je nach Größe und
##   Versorgung, aber nie einen Zwang zur Massenrekrutierung.
## - Verlegen, Teilen, Zusammenlegen und Entlassen kosten nichts und ändern die
##   Gesamtzahl nicht (Entlassen: Wachen werden wieder Bewohner).
const SUPPLY = preload("res://scripts/creative/build_village_supply.gd")
const POSTS := {
	"mitte": "Stadtmitte", "nord": "Nordtor", "ost": "Osttor", "sued": "Südtor", "west": "Westtor"
}
const POST_ORDER := ["mitte", "nord", "ost", "sued", "west"]
const STEPS := [1, 10, 100]
const COIN_PER_GUARD := 1
## Ein Verband fasst bis zu 500 Wachen; mehr werden ein neuer Verband.
const MAX_UNIT := 500
const MAX_UNITS := 60
const NAMES := ["Fuchs", "Eule", "Dachs", "Biber", "Igel", "Reh", "Luchs", "Otter", "Falke", "Bär"]


## Verbände an die Gesamtzahl anpassen (alte Stände, Einzelausbildung, Laden).
## Fehlende Wachen kommen in die Stadtmitte, überzählige gehen zuerst aus
## den zuletzt gegründeten Verbänden.
static func reconcile(raids) -> void:
	var clean: Array = []
	var seen: Dictionary = {}
	for unit in raids.units:
		if not unit is Dictionary:
			continue
		var id := int(unit.get("id", 0))
		var size := int(unit.get("size", 0))
		var post := str(unit.get("post", "mitte"))
		if id < 1 or seen.has(id) or size < 1 or not POSTS.has(post):
			continue
		seen[id] = true
		clean.append({"id": id, "name": str(unit.get("name", "")), "size": mini(size, MAX_UNIT), "post": post})
	raids.units = clean
	var difference := int(raids.guards) - total(raids)
	while difference > 0:
		var unit := _unit_with_room(raids, "mitte")
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


static func total(raids) -> int:
	var sum := 0
	for unit in raids.units:
		sum += int(unit.size)
	return sum


static func _next_id(raids) -> int:
	var highest := 0
	for unit in raids.units:
		highest = maxi(highest, int(unit.id))
	return highest + 1


static func _new_unit(raids, post: String) -> Dictionary:
	var id := _next_id(raids)
	var unit := {
		"id": id, "name": "%s-Trupp" % NAMES[(id - 1) % NAMES.size()], "size": 0, "post": post
	}
	raids.units.append(unit)
	return unit


static func _unit_with_room(raids, post: String) -> Dictionary:
	for unit in raids.units:
		if str(unit.post) == post and int(unit.size) < MAX_UNIT:
			return unit
	return _new_unit(raids, post)


static func find(raids, id: int) -> Dictionary:
	for unit in raids.units:
		if int(unit.id) == id:
			return unit
	return {}


## Freie Plätze für neue Wachen (halbe Bevölkerung, wie bisher).
static func room(model, raids) -> int:
	return maxi(0, int(raids.max_guards(model)) - int(raids.guards))


## Warum geht diese Ausbildung nicht? "" = sie geht.
static func train_error(model, raids, count: int, post: String) -> String:
	if count not in STEPS:
		return "Wähle 1, 10 oder 100 Wachen."
	if not POSTS.has(post):
		return "Diesen Standort gibt es nicht."
	if not raids.expedition.is_empty():
		return "Die Wachen sind gerade unterwegs."
	if count > room(model, raids):
		return (
			"Dafür hat dein Dorf noch zu wenige Bewohner. Höchstens die Hälfte kann Wache sein: noch %d."
			% room(model, raids)
		)
	if count > 1:
		var reserve := SUPPLY.town_reserve(model, model._player)
		if int(reserve.balance) < 0:
			return "Erst die Versorgung sichern: Deine Ernte reicht noch nicht für alle. Baue mehr Bauernhöfe."
	if int(model._player.resources.coins) < count * COIN_PER_GUARD:
		return "Für %d Helme und Schilde brauchst du %d Münzen." % [count, count * COIN_PER_GUARD]
	if raids.units.size() >= MAX_UNITS and _unit_with_room_exists(raids, post) == false:
		return "So viele Verbände kann Lumo nicht überblicken. Lege Verbände zusammen."
	return ""


static func _unit_with_room_exists(raids, post: String) -> bool:
	for unit in raids.units:
		if str(unit.post) == post and int(unit.size) < MAX_UNIT:
			return true
	return false


## Ein Zug bildet 1, 10 oder 100 Wachen aus und stellt sie an den Standort.
static func train(model, raids, count: int, post: String) -> String:
	var error := train_error(model, raids, count, post)
	if not error.is_empty():
		return error
	if not model.exchange({"coins": count * COIN_PER_GUARD}, {}):
		return model.last_error
	raids.guards = int(raids.guards) + count
	var left := count
	while left > 0:
		var unit := _unit_with_room(raids, post)
		var add := mini(left, MAX_UNIT - int(unit.size))
		unit.size = int(unit.size) + add
		left -= add
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


## Einen Teil abspalten: ein neuer Verband am selben Standort.
static func split(raids, id: int, count: int) -> String:
	var unit := find(raids, id)
	if unit.is_empty():
		return "Diesen Verband gibt es nicht."
	if count < 1 or count >= int(unit.size):
		return "Ein Teil muss kleiner sein als der ganze Verband."
	if raids.units.size() >= MAX_UNITS:
		return "So viele Verbände kann Lumo nicht überblicken."
	unit.size = int(unit.size) - count
	var fresh := _new_unit(raids, str(unit.post))
	fresh.size = count
	return ""


## Zwei Verbände zusammenlegen (bis 500 Wachen je Verband).
static func merge(raids, into: int, from: int) -> String:
	var target := find(raids, into)
	var source := find(raids, from)
	if target.is_empty() or source.is_empty() or into == from:
		return "Wähle zwei verschiedene Verbände."
	if int(target.size) + int(source.size) > MAX_UNIT:
		return "Ein Verband fasst höchstens %d Wachen." % MAX_UNIT
	target.size = int(target.size) + int(source.size)
	raids.units.erase(source)
	return ""


## Alle Verbände an einem Standort zusammenfassen (so wenige wie möglich).
static func regroup(raids, post: String) -> void:
	var people := 0
	var kept: Array = []
	for unit in raids.units:
		if str(unit.post) == post:
			people += int(unit.size)
		else:
			kept.append(unit)
	raids.units = kept
	while people > 0:
		var unit := _new_unit(raids, post)
		unit.size = mini(people, MAX_UNIT)
		people -= int(unit.size)


## Wachen werden wieder Bewohner (kein Geld zurück, niemand verschwindet).
static func dismiss(raids, id: int, count: int) -> String:
	var unit := find(raids, id)
	if unit.is_empty() or count < 1 or count > int(unit.size):
		return "So viele Wachen hat dieser Verband nicht."
	if not raids.expedition.is_empty():
		return "Die Wachen sind gerade unterwegs."
	unit.size = int(unit.size) - count
	raids.guards = int(raids.guards) - count
	if int(unit.size) == 0:
		raids.units.erase(unit)
	return ""


## Gesamtzahl, Standorte und Versorgung für Anzeige und Bericht.
static func overview(model, raids) -> Dictionary:
	var posts := {}
	for key in POST_ORDER:
		posts[key] = 0
	for unit in raids.units:
		posts[str(unit.post)] = int(posts[str(unit.post)]) + int(unit.size)
	var reserve := SUPPLY.town_reserve(model, model._player)
	return {
		"total": int(raids.guards),
		"units": raids.units.size(),
		"posts": posts,
		"room": room(model, raids),
		"food_per_day": int(raids.guards),
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
					"size": int(item.get("size", 0)), "post": str(item.get("post", "mitte"))
				})
	reconcile(raids)
