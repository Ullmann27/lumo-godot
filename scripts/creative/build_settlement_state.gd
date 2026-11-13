extends RefCounted
## Deterministic, offline settlement rules. Both towns use the same prices,
## production and needs. Time advances only through the child's Next Day action.
const BUILDINGS := {
	"house": {"title": "Wohnhaus", "cost": {"wood": 4, "stone": 3, "coins": 1}, "output": {}, "capacity": 2},
	"farm": {"title": "Bauernhof", "cost": {"wood": 4, "stone": 1}, "output": {"food": 5}, "capacity": 0},
	"lumber": {"title": "Holzwerkstatt", "cost": {"wood": 4, "stone": 2}, "output": {"wood": 4}, "capacity": 0},
	"quarry": {"title": "Steinbruch", "cost": {"wood": 4, "stone": 3}, "output": {"stone": 3}, "capacity": 0},
	"market": {"title": "Marktplatz", "cost": {"wood": 6, "stone": 4, "coins": 2}, "output": {"coins": 2}, "capacity": 0},
	"school": {"title": "Lernhaus", "cost": {"wood": 8, "stone": 12, "coins": 8}, "output": {}, "capacity": 0},
}
const RESOURCES := ["wood", "stone", "food", "coins"]
const REGIONS := ["Wiesenwinkel", "Flussufer", "Sonnenhöhe"]
const PLOTS := [9, 16, 25]
const EXPANSION_COST := {"wood": 12, "stone": 10, "coins": 4}
const MAX_RESOURCE := 99999
const MAX_DAY := 9999
var mode := "settlement"
var day := 1
var winner := ""
var last_error := ""
var _player: Dictionary
var _rival: Dictionary
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


func _init(requested_mode: String = "settlement") -> void:
	mode = "rival" if requested_mode == "rival" else "settlement"
	_player = _new_town()
	_rival = _new_town()


static func _new_town() -> Dictionary:
	return {"resources": {"wood": 18, "stone": 12, "food": 12, "coins": 8},
		"population": 2, "region": 0, "plots": 9, "buildings": [], "next_id": 1,
		"food_shortfall": 0}


func player() -> Dictionary:
	return _player.duplicate(true)


func rival() -> Dictionary:
	return _rival.duplicate(true)


func try_build(kind: String, plot: int) -> bool:
	last_error = ""
	if not _can_act():
		return false
	var before := _player.duplicate(true)
	if not _buy(_player, kind, plot):
		return false
	_remember(before)
	return true


func _buy(town: Dictionary, kind: String, plot: int) -> bool:
	if not BUILDINGS.has(kind):
		last_error = "Wähle ein vorhandenes Gebäude."
		return false
	if plot < 0 or plot >= int(town.plots):
		last_error = "Dieses Grundstück ist noch nicht erschlossen."
		return false
	if int(town.next_id) >= 10000:
		last_error = "Dieses Projekt hat seine Baugeschichte gefüllt. Öffne ein weiteres Projekt."
		return false
	for building: Dictionary in town.buildings:
		if int(building.plot) == plot:
			last_error = "Dieses Grundstück ist bereits bebaut."
			return false
	if not _affords(town, BUILDINGS[kind].cost):
		last_error = "Dafür fehlen noch Rohstoffe. Produziere oder handle zuerst."
		return false
	_pay(town, BUILDINGS[kind].cost)
	town.buildings.append({"id": "b%d" % int(town.next_id), "kind": kind, "plot": plot})
	town.next_id = int(town.next_id) + 1
	return true


func try_demolish(plot: int) -> bool:
	last_error = ""
	if not _can_act():
		return false
	if plot < 0 or plot >= int(_player.plots):
		last_error = "Wähle ein eigenes bebautes Grundstück."
		return false
	for index in range(_player.buildings.size()):
		var building: Dictionary = _player.buildings[index]
		if int(building.plot) != plot:
			continue
		var definition: Dictionary = BUILDINGS[str(building.kind)]
		if int(definition.capacity) > 0 and _capacity(_player) - int(definition.capacity) < int(_player.population):
			last_error = "Deine Bewohner brauchen dieses Zuhause. Baue zuerst ein weiteres Wohnhaus."
			return false
		var before := _player.duplicate(true)
		# Recover the actual building materials, not market resale prices. This
		# keeps experimenting reversible even after Next Day has cleared Undo.
		# Existing stock never decreases; a full store simply cannot hold more.
		for resource: String in definition.cost:
			_player.resources[resource] = mini(MAX_RESOURCE, int(_player.resources[resource]) + int(definition.cost[resource]))
		_player.buildings.remove_at(index)
		_remember(before)
		return true
	last_error = "Auf diesem Grundstück steht noch kein Gebäude."
	return false


func try_trade(resource: String, quantity: int, sell: bool) -> bool:
	last_error = ""
	if not _can_act():
		return false
	var quote := trade_quote(resource, quantity, sell)
	if quote.is_empty():
		last_error = "Wähle 1 bis 10 Handelseinheiten."
		return false
	if _count(_player, "market") == 0:
		last_error = "Baue zuerst einen Marktplatz."
		return false
	var cost: Dictionary = quote.cost
	if not _affords(_player, cost):
		last_error = "Dafür reicht dein Vorrat nicht."
		return false
	var received: String = quote.resource
	var amount: int = quote.amount
	if int(_player.resources[received]) + amount > MAX_RESOURCE:
		last_error = "Dein Lager ist voll."
		return false
	var before := _player.duplicate(true)
	_pay(_player, cost)
	_player.resources[received] = int(_player.resources[received]) + amount
	_remember(before)
	return true


static func trade_quote(resource: String, quantity: int, sell: bool) -> Dictionary:
	if resource not in ["wood", "stone", "food"] or quantity < 1 or quantity > 10:
		return {}
	var sell_rate := 3 if resource == "food" else 2
	var buy_rate := 2 if resource == "food" else 1
	return {"cost": {resource: quantity * sell_rate} if sell else {"coins": quantity},
		"resource": "coins" if sell else resource, "amount": quantity if sell else quantity * buy_rate}


func expand() -> bool:
	last_error = ""
	if not _can_act():
		return false
	var before := _player.duplicate(true)
	if not _expand_town(_player):
		return false
	_remember(before)
	return true


func _expand_town(town: Dictionary) -> bool:
	if int(town.region) >= REGIONS.size() - 1:
		last_error = "Alle drei Regionen sind erschlossen."
		return false
	if int(town.population) < 4:
		last_error = "Versorge zuerst vier Bewohner."
		return false
	if not _affords(town, EXPANSION_COST):
		last_error = "Die Erschließung braucht 12 Holz, 10 Stein und 4 Münzen."
		return false
	_pay(town, EXPANSION_COST)
	town.region = int(town.region) + 1
	town.plots = PLOTS[int(town.region)]
	return true


func next_day() -> Dictionary:
	last_error = ""
	if not _can_act() or day >= MAX_DAY:
		if day >= MAX_DAY:
			last_error = "Diese Stadt hat die maximale Tageszahl erreicht."
		return {"advanced": false, "message": last_error}
	var actions: Array[String] = []
	if mode == "rival":
		actions = _rival_plan()
	var own := _produce(_player)
	var neighbor: Dictionary = {}
	if mode == "rival":
		neighbor = _produce(_rival)
	day += 1
	_undo.clear()
	_redo.clear()
	var own_complete := _level(_player) == 3
	var rival_complete := mode == "rival" and _level(_rival) == 3
	if mode == "rival":
		if own_complete and rival_complete:
			winner = "tie"
		elif own_complete:
			winner = "player"
		elif rival_complete:
			winner = "rival"
	last_error = ""
	return {"advanced": true, "day": day, "player": own, "rival": neighbor,
		"rival_actions": actions, "winner": winner, "level": _level(_player)}


func _produce(town: Dictionary) -> Dictionary:
	var output := {"wood": 0, "stone": 0, "food": 0, "coins": 0}
	for building: Dictionary in town.buildings:
		var production: Dictionary = BUILDINGS[str(building.kind)].output
		for resource: String in production:
			output[resource] = int(output[resource]) + int(production[resource])
	# New regions have tangible value beyond plot count.
	if int(town.region) >= 1:
		output.food = int(output.food) + _count(town, "farm")
	if int(town.region) >= 2:
		output.stone = int(output.stone) + _count(town, "quarry")
	for resource: String in RESOURCES:
		town.resources[resource] = mini(MAX_RESOURCE, int(town.resources[resource]) + int(output[resource]))
	var needs := int(town.population)
	town.food_shortfall = maxi(0, needs - int(town.resources.food))
	town.resources.food = maxi(0, int(town.resources.food) - needs)
	var grew := false
	if int(town.food_shortfall) == 0 and _capacity(town) > needs and int(town.resources.food) >= needs + 2:
		town.population = mini(50, needs + 1)
		grew = true
	return {"produced": output, "food_needed": needs, "food_shortfall": town.food_shortfall, "grew": grew}


func _rival_plan() -> Array[String]:
	var actions: Array[String] = []
	# The neighbour has the same starting supplies and uses only its own public
	# needs. No lookahead into the child's actions, free resources or teleports.
	for _action in range(3):
		var priorities: Array[String] = []
		if _count(_rival, "house") == 0: priorities.append("house")
		if _count(_rival, "farm") == 0: priorities.append("farm")
		if _count(_rival, "lumber") == 0: priorities.append("lumber")
		if _count(_rival, "quarry") == 0: priorities.append("quarry")
		if _capacity(_rival) <= int(_rival.population): priorities.append("house")
		if _count(_rival, "farm") * (6 if int(_rival.region) >= 1 else 5) <= int(_rival.population) + 2:
			priorities.append("farm")
		if _count(_rival, "market") == 0: priorities.append("market")
		if int(_rival.population) >= 4 and int(_rival.region) < 2 and _expand_town(_rival):
			actions.append("Erschließt " + REGIONS[int(_rival.region)])
			continue
		if _count(_rival, "school") == 0 and _level(_rival) >= 2: priorities.append("school")
		if int(_rival.population) < 10 and _capacity(_rival) < 10: priorities.append("house")
		var plot := _free_plot(_rival)
		var built := false
		if plot >= 0:
			for kind: String in priorities:
				if _buy(_rival, kind, plot):
					actions.append("Baut " + str(BUILDINGS[kind].title))
					built = true
					break
		if not built:
			break
	return actions


func _free_plot(town: Dictionary) -> int:
	var occupied := {}
	for building: Dictionary in town.buildings:
		occupied[int(building.plot)] = true
	for plot in range(int(town.plots)):
		if not occupied.has(plot): return plot
	return -1


func _affords(town: Dictionary, cost: Dictionary) -> bool:
	for resource: String in cost:
		if int(town.resources[resource]) < int(cost[resource]): return false
	return true


func _pay(town: Dictionary, cost: Dictionary) -> void:
	for resource: String in cost:
		town.resources[resource] = int(town.resources[resource]) - int(cost[resource])


func _count(town: Dictionary, kind: String) -> int:
	var count := 0
	for building: Dictionary in town.buildings:
		if str(building.kind) == kind: count += 1
	return count


func _capacity(town: Dictionary) -> int:
	return _count(town, "house") * 2


func _level(town: Dictionary) -> int:
	if _count(town, "house") < 1 or _count(town, "farm") < 1: return 0
	if int(town.population) < 6 or _count(town, "lumber") < 1 or _count(town, "quarry") < 1 or _count(town, "market") < 1 or int(town.region) < 1: return 1
	if int(town.population) < 10 or _count(town, "school") < 1 or _count(town, "farm") < 2 or int(town.region) < 2: return 2
	return 3


func status() -> Dictionary:
	var level := _level(_player)
	var goals: Array[Dictionary] = []
	if level == 0:
		goals = [{"title": "Wohnhaus", "current": _count(_player, "house"), "target": 1},
			{"title": "Bauernhof", "current": _count(_player, "farm"), "target": 1}]
	elif level == 1:
		goals = [{"title": "Bewohner", "current": int(_player.population), "target": 6},
			{"title": "Holzwerkstatt", "current": _count(_player, "lumber"), "target": 1},
			{"title": "Steinbruch", "current": _count(_player, "quarry"), "target": 1},
			{"title": "Marktplatz", "current": _count(_player, "market"), "target": 1},
			{"title": "Neue Region", "current": int(_player.region), "target": 1}]
	elif level == 2:
		goals = [{"title": "Bewohner", "current": int(_player.population), "target": 10},
			{"title": "Lernhaus", "current": _count(_player, "school"), "target": 1},
			{"title": "Bauernhöfe", "current": _count(_player, "farm"), "target": 2},
			{"title": "Neue Regionen", "current": int(_player.region), "target": 2}]
	return {"day": day, "mode": mode, "level": level, "reached_level": level,
		"target": ["Ein Zuhause mit Versorgung", "Ein lebendiges Dorf", "Eine lernende Stadt", "Deine Stadt blüht!"][level],
		"world": REGIONS[int(_player.region)], "region": int(_player.region), "goals": goals,
		"capacity": _capacity(_player), "rival_level": _level(_rival), "winner": winner,
		"can_expand": int(_player.region) < 2 and int(_player.population) >= 4 and _affords(_player, EXPANSION_COST),
		"can_undo": not _undo.is_empty(), "can_redo": not _redo.is_empty(), "complete": level == 3}


func _can_act() -> bool:
	if mode == "rival" and not winner.is_empty():
		last_error = "Der Wettbau ist abgeschlossen. Starte eine neue Welt oder baue frei weiter."
		return false
	return true


func _remember(before: Dictionary) -> void:
	_undo.append(before)
	if _undo.size() > 32: _undo.pop_front()
	_redo.clear()


func undo() -> bool:
	if _undo.is_empty() or not _can_act(): return false
	_redo.append(_player.duplicate(true))
	_player = _undo.pop_back()
	last_error = ""
	return true


func redo() -> bool:
	if _redo.is_empty() or not _can_act(): return false
	_undo.append(_player.duplicate(true))
	_player = _redo.pop_back()
	last_error = ""
	return true


func snapshot() -> Dictionary:
	return {"version": 1, "mode": mode, "day": day, "winner": winner,
		"player": _player.duplicate(true), "rival": _rival.duplicate(true)}


static func restore(data: Dictionary):
	if data.get("version") != 1 or data.get("mode") not in ["settlement", "rival"]:
		return null
	if not _whole(data.get("day"), 1, MAX_DAY) or data.get("winner", "") not in ["", "player", "rival", "tie"]:
		return null
	for key in ["player", "rival"]:
		if not data.get(key) is Dictionary or not _valid_town(data[key]): return null
	var model = load("res://scripts/creative/build_settlement_state.gd").new(str(data.mode))
	model.day = int(data.day)
	model.winner = str(data.get("winner", ""))
	model._player = _restored_town(data.player)
	model._rival = _restored_town(data.rival)
	if model.mode == "settlement" and not model.winner.is_empty(): return null
	if model.winner in ["player", "tie"] and model._level(model._player) != 3: return null
	if model.winner in ["rival", "tie"] and model._level(model._rival) != 3: return null
	return model


static func _restored_town(town: Dictionary) -> Dictionary:
	# JSON numbers arrive as floats. Restore the canonical integer representation
	# before arithmetic and exact snapshot comparisons; never round invalid input.
	var result := _new_town()
	for key in ["population", "region", "plots", "next_id", "food_shortfall"]:
		result[key] = int(town.get(key, 0))
	for resource in RESOURCES:
		result.resources[resource] = int(town.resources[resource])
	for building: Dictionary in town.buildings:
		result.buildings.append({"id": str(building.id), "kind": str(building.kind), "plot": int(building.plot)})
	return result


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _valid_town(town: Dictionary) -> bool:
	if not town.get("resources") is Dictionary or not town.get("buildings") is Array: return false
	if not _whole(town.get("region"), 0, 2) or not _whole(town.get("population"), 2, 50): return false
	if not _whole(town.get("plots"), 9, 25) or int(town.plots) != PLOTS[int(town.region)]: return false
	if not _whole(town.get("next_id"), 1, 10000) or not _whole(town.get("food_shortfall", 0), 0, 50): return false
	for resource in RESOURCES:
		if not _whole(town.resources.get(resource), 0, MAX_RESOURCE): return false
	if town.buildings.size() > int(town.plots): return false
	var occupied := {}
	var identifiers := {}
	for building: Variant in town.buildings:
		if not building is Dictionary or not BUILDINGS.has(building.get("kind", "")): return false
		if not _whole(building.get("plot"), 0, int(town.plots) - 1): return false
		var identifier := str(building.get("id", ""))
		if not identifier.begins_with("b") or not identifier.substr(1).is_valid_int(): return false
		var number := identifier.substr(1).to_int()
		if number < 1 or number >= int(town.next_id) or identifiers.has(identifier): return false
		if occupied.has(int(building.plot)): return false
		occupied[int(building.plot)] = true
		identifiers[identifier] = true
	return true
