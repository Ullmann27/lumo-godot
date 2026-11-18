extends RefCounted
## KI-Nachbardörfer auf derselben großen Karte. Jedes Dorf ist ein eigenes
## Spielmodell (build_settlement_state.gd) und spielt nach GENAU denselben
## Regeln wie das Kind: bauen kostet dieselben Rohstoffe, Erträge und Hunger
## sind gleich, Erweitern braucht dieselben Bedingungen. Entscheidungen hängen
## nur vom eigenen Bestand, dem Charakter und dem Tag ab (deterministisch).
## Zeit läuft nur mit „Nächster Tag“ des Kindes – nie, wenn die App zu ist.
## Einzige Stellschraube (dokumentiert): BUILDS_PER_DAY – ein Nachbar baut
## höchstens so viele Gebäude pro Tag; er bekommt nie Gratis-Rohstoffe.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const VERSION := 1
const BUILDS_PER_DAY := 1
const MAX_REPUTATION := 3
const MIN_REPUTATION := -2
## Bündnis ab diesem Ansehen: hilft beim Verteidigen und in der Not.
const ALLY_REPUTATION := 3
## Rohstoffquellen auf der Karte, um die gewetteifert wird (+2 je Tag).
const SOURCES := {
	"steinquelle": {"title": "Steinquelle am Hügel", "at": Vector2(-158.0, -62.0), "resource": "stone", "cost": {"wood": 10, "coins": 4}},
	"holzhain": {"title": "Holzhain am Waldrand", "at": Vector2(-190.0, 30.0), "resource": "wood", "cost": {"stone": 8, "coins": 4}},
}
const SOURCE_YIELD := 2
## Place on the map: every neighbour village is at most 9 × 9 sites (ring 4),
## so the three towns and the child's district never overlap.
const MAX_SITES := 81
const NEIGHBORS := [
	{
		"id": "leo", "name": "Leo", "animal": "lion", "town": "Burgheim", "trait": "burgenbauer",
		"text": "Stolzer Burgenbauer. Liebt Stein und hohe Mauern.",
		"site": Vector2(150.0, 0.0), "color": "f4ae52", "variant": 1, "wants": "steinquelle",
		"order": ["house", "quarry", "farm", "lumber", "house", "well", "quarry", "house", "farm", "market", "house", "school"],
	},
	{
		"id": "ella", "name": "Ella", "animal": "owl", "town": "Eulenstein", "trait": "erfinderin",
		"text": "Schlaue Erfinderin. Baut Lernhäuser und Werkstätten.",
		"site": Vector2(62.0, -40.0), "color": "c7a585", "variant": 2, "wants": "holzhain",
		"order": ["house", "farm", "lumber", "quarry", "well", "house", "school", "farm", "house", "grain", "bakery", "clinic"],
	},
	{
		"id": "flitz", "name": "Flitz", "animal": "squirrel", "town": "Nusshausen", "trait": "haendler",
		"text": "Fleißiger Händler. Hat immer etwas zum Tauschen.",
		"site": Vector2(78.0, 48.0), "color": "f39154", "variant": 0, "wants": "",
		"order": ["house", "farm", "market", "lumber", "house", "farm", "quarry", "road", "house", "market", "well", "grain"],
	},
]
var towns: Dictionary = {}
var reputation: Dictionary = {}
var last_help: Dictionary = {}
var sources: Dictionary = {}
var chronicle: Array = []
var day := 1


static func spec(id: String) -> Dictionary:
	for entry in NEIGHBORS:
		if entry.id == id:
			return entry
	return {}


static func plot_world(id: String, index: int) -> Vector3:
	var site: Vector2 = spec(id).get("site", Vector2.ZERO)
	var coordinate := REGION.plot_coordinate(index)
	var x := site.x + coordinate.x * REGION.SPACING
	var z := site.y + coordinate.y * REGION.SPACING
	return Vector3(x, TERRAIN.height(x, z) + 0.03, z)


## A neighbour only builds on flat meadow (same rule as the child's land).
static func plot_ok(id: String, index: int) -> bool:
	var at := plot_world(id, index)
	var spread := 0.0
	for dx in [-2.2, 2.2]:
		for dz in [-2.2, 2.2]:
			spread = maxf(spread, absf(TERRAIN.height(at.x + dx, at.z + dz) - at.y))
	return spread < 0.9 and at.y > TERRAIN.WATER_LEVEL + 0.9 and absf(at.x - TERRAIN.river_center(at.z)) > 12.0


func _init() -> void:
	for entry in NEIGHBORS:
		towns[entry.id] = STATE.new("settlement", true)
		reputation[entry.id] = 0
		last_help[entry.id] = -99


func snapshot() -> Dictionary:
	var data := {"version": VERSION, "day": day, "towns": {}, "reputation": reputation.duplicate(),
		"last_help": last_help.duplicate(), "sources": sources.duplicate(), "log": chronicle.slice(-24)}
	for id in towns:
		data.towns[id] = towns[id].snapshot()
	return data


## Old saves have no neighbours: they start fresh on day 1 of their own.
static func restore(raw: Variant):
	var result = load("res://scripts/creative/build_village_neighbors.gd").new()
	if not raw is Dictionary or raw.get("version") != VERSION:
		return result
	result.day = maxi(1, int(raw.get("day", 1)))
	for id in result.towns.keys():
		var saved: Variant = raw.get("towns", {}).get(id)
		if saved is Dictionary:
			var model = STATE.restore(saved)
			if model != null and model.living_village:
				result.towns[id] = model
		result.reputation[id] = clampi(int(raw.get("reputation", {}).get(id, 0)), MIN_REPUTATION, MAX_REPUTATION)
		result.last_help[id] = int(raw.get("last_help", {}).get(id, -99))
	for key in raw.get("sources", {}):
		if SOURCES.has(str(key)):
			result.sources[str(key)] = str(raw.sources[key])
	for line in raw.get("log", []):
		result.chronicle.append(str(line))
	return result


func allied(id: String) -> bool:
	return int(reputation.get(id, 0)) >= ALLY_REPUTATION


func mood(id: String) -> String:
	var value := int(reputation.get(id, 0))
	if value >= ALLY_REPUTATION:
		return "verbündet"
	if value >= 1:
		return "freundlich"
	if value <= -1:
		return "verärgert"
	return "neutral"


func _note(text: String) -> void:
	chronicle.append("Tag %d: %s" % [day, text])
	if chronicle.size() > 48:
		chronicle = chronicle.slice(-48)


func _free_plot(id: String) -> int:
	var model = towns[id]
	var town: Dictionary = model._player
	var used: Dictionary = {}
	for building in town.buildings:
		used[int(building.plot)] = true
	for index in range(mini(int(town.plots), MAX_SITES)):
		if not used.has(index) and plot_ok(id, index):
			return index
	return -1


## The neighbour's turn for one village day: build by character, trade at
## its own market when short, expand when allowed, then the day passes with
## the same production/hunger rules. Returns a short report.
func advance_one(id: String) -> Dictionary:
	var entry := spec(id)
	var model = towns[id]
	var town: Dictionary = model._player
	var built: Array[String] = []
	var order: Array = entry.order
	for _attempt in range(BUILDS_PER_DAY):
		var plot := _free_plot(id)
		if plot < 0:
			break
		# A sensible builder: materials first, food before hunger, homes when
		# full, then the character's own plan. Tries in order until one is
		# affordable under the normal prices.
		var wishes: Array[String] = []
		if model._count(town, "lumber") == 0:
			wishes.append("lumber")
		if model._count(town, "quarry") == 0:
			wishes.append("quarry")
		if int(town.resources.food) < int(town.population) * 2 + 4:
			wishes.append("farm")
		if model._capacity(town) <= int(town.population) + 1:
			wishes.append("house")
		wishes.append(str(order[posmod(town.buildings.size(), order.size())]))
		wishes.append_array(["farm", "lumber", "house", "quarry"])
		for kind in wishes:
			if model.try_build(kind, plot):
				built.append(kind)
				break
	if model._count(town, "market") > 0:
		for resource in ["wood", "stone"]:
			if int(town.resources[resource]) < 4 and int(town.resources.food) > 14:
				model.try_trade(resource, 5, false)
	if model.expand():
		_note("%s erschließt neues Land." % str(entry.town))
	var report: Dictionary = model.next_day()
	if not built.is_empty():
		_note("%s baut %s." % [str(entry.town), ", ".join(built.map(func(k): return str(STATE.BUILDINGS[k].title)))])
	return {"built": built, "advanced": bool(report.get("advanced", false))}


## One village day for every neighbour plus their relations with the child.
## Called exactly once per child day (after the child's own day).
func advance_day(player_model) -> Dictionary:
	day += 1
	var reports := {}
	for entry in NEIGHBORS:
		reports[entry.id] = advance_one(entry.id)
	# Owned sources yield every day; neighbours may claim a free source they want.
	for key in SOURCES:
		var owner := str(sources.get(key, ""))
		var resource: String = SOURCES[key].resource
		if owner == "player":
			player_model.exchange({}, {resource: SOURCE_YIELD})
		elif towns.has(owner):
			towns[owner].exchange({}, {resource: SOURCE_YIELD})
	for entry in NEIGHBORS:
		var wanted: String = entry.wants
		if wanted.is_empty() or sources.has(wanted):
			continue
		var model = towns[entry.id]
		if model._affords(model._player, SOURCES[wanted].cost) and int(model._player.population) >= 6:
			model.exchange(SOURCES[wanted].cost, {})
			sources[wanted] = entry.id
			_note("%s sichert sich die %s." % [str(entry.name), str(SOURCES[wanted].title)])
	# Help in need: a friendly neighbour with spare food sends a basket.
	var help := {}
	var town: Dictionary = player_model._player
	if int(town.food_shortfall) > 0 or int(town.resources.food) < int(town.population):
		for entry in NEIGHBORS:
			var id: String = entry.id
			var model = towns[id]
			if int(reputation[id]) >= 1 and day - int(last_help[id]) >= 5 and int(model._player.resources.food) >= 20:
				if model.exchange({"food": 6}, {}) and player_model.exchange({}, {"food": 6}):
					last_help[id] = day
					help = {"id": id, "food": 6}
					_note("%s schickt dir 6 Essen." % str(entry.name))
					break
	return {"neighbors": reports, "help": help}


## A fair offer from real stock: the neighbour's largest surplus for what it lacks.
func offer(id: String) -> Dictionary:
	var model = towns[id]
	var stock: Dictionary = model._player.resources
	var best := ""
	var poor := ""
	for resource in ["wood", "stone", "food"]:
		if best.is_empty() or int(stock[resource]) > int(stock[best]):
			best = resource
		if poor.is_empty() or int(stock[resource]) < int(stock[poor]):
			poor = resource
	if best == poor or int(stock[best]) < 15:
		return {}
	var amount := 5 + (1 if int(reputation[id]) >= 2 else 0)
	return {"give": {poor: 5}, "receive": {best: amount}}


func trade(id: String, player_model) -> bool:
	var deal := offer(id)
	if deal.is_empty():
		return false
	var model = towns[id]
	if not player_model._affords(player_model._player, deal.give) or not model._affords(model._player, deal.receive):
		return false
	if not player_model.exchange(deal.give, deal.receive):
		return false
	model.exchange(deal.receive, deal.give)
	reputation[id] = mini(MAX_REPUTATION, int(reputation[id]) + 1)
	_note("Handel mit %s." % str(spec(id).name))
	return true


func gift(id: String, player_model, gift_food := 4) -> bool:
	if not player_model.exchange({"food": gift_food}, {}):
		return false
	towns[id].exchange({}, {"food": gift_food})
	reputation[id] = mini(MAX_REPUTATION, int(reputation[id]) + 1)
	_note("Geschenk an %s." % str(spec(id).name))
	return true


func claim_source(key: String, player_model) -> bool:
	if not SOURCES.has(key) or sources.has(key):
		return false
	if not player_model.exchange(SOURCES[key].cost, {}):
		return false
	sources[key] = "player"
	for entry in NEIGHBORS:
		if entry.wants == key:
			reputation[entry.id] = maxi(MIN_REPUTATION, int(reputation[entry.id]) - 1)
			_note("%s ist enttäuscht: die Quelle gehört jetzt dir." % str(entry.name))
	return true


func summary(id: String) -> Dictionary:
	var town: Dictionary = towns[id]._player
	return {"population": int(town.population), "buildings": town.buildings.size(), "plots": int(town.plots),
		"resources": town.resources.duplicate(), "mood": mood(id), "reputation": int(reputation[id])}
