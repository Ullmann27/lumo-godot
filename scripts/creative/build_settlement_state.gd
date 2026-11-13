extends RefCounted
## Deterministic, offline settlement rules. Both towns use the same prices,
## production and needs. Time advances only through the child's Next Day action.
const VILLAGE = preload("res://scripts/creative/build_settlement_economy.gd")
const CLASSIC_KINDS := ["house", "farm", "lumber", "quarry", "market", "school"]
const BUILDINGS := {
	"house":
	{"title": "Wohnhaus", "cost": {"wood": 4, "stone": 3, "coins": 1}, "output": {}, "capacity": 2},
	"farm":
	{"title": "Bauernhof", "cost": {"wood": 4, "stone": 1}, "output": {"food": 5}, "capacity": 0},
	"lumber":
	{
		"title": "Holzwerkstatt",
		"cost": {"wood": 4, "stone": 2},
		"output": {"wood": 4},
		"capacity": 0
	},
	"quarry":
	{"title": "Steinbruch", "cost": {"wood": 4, "stone": 3}, "output": {"stone": 3}, "capacity": 0},
	"market":
	{
		"title": "Marktplatz",
		"cost": {"wood": 6, "stone": 4, "coins": 2},
		"output": {"coins": 2},
		"capacity": 0
	},
	"school":
	{
		"title": "Lernhaus",
		"cost": {"wood": 8, "stone": 12, "coins": 8},
		"output": {},
		"capacity": 0
	},
	"well": {"title": "Brunnen", "cost": {"wood": 2, "stone": 3}, "output": {}, "capacity": 0},
	"grain":
	{"title": "Kornfeld", "cost": {"wood": 4, "stone": 1, "coins": 1}, "output": {}, "capacity": 0},
	"bakery":
	{"title": "Bäckerei", "cost": {"wood": 6, "stone": 6, "coins": 4}, "output": {}, "capacity": 0},
	"road":
	{
		"title": "Wegeplatz",
		"cost": {"wood": 2, "stone": 3, "coins": 1},
		"output": {},
		"capacity": 0
	},
	"clinic":
	{
		"title": "Fürsorgehaus",
		"cost": {"wood": 8, "stone": 8, "coins": 6},
		"output": {},
		"capacity": 0
	},
}
const RESOURCES := ["wood", "stone", "food", "coins"]
const REGIONS := VILLAGE.REGIONS
const PLOTS := VILLAGE.PLOTS
const EXPANSION_COST := {"wood": 12, "stone": 10, "coins": 4}
const MAX_RESOURCE := 99999
const MAX_DAY := 9999
var living_village := false
var mode := "settlement"
var day := 1
var winner := ""
var last_error := ""
var _player: Dictionary
var _rival: Dictionary
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


func _init(requested_mode: String = "settlement", use_living_village: bool = false) -> void:
	mode = "rival" if requested_mode == "rival" else "settlement"
	_player = _new_town()
	_rival = _new_town()
	if use_living_village:
		enable_living_village()


static func _new_town() -> Dictionary:
	return {
		"resources": {"wood": 18, "stone": 12, "food": 12, "coins": 8},
		"population": 2,
		"region": 0,
		"plots": 9,
		"buildings": [],
		"next_id": 1,
		"food_shortfall": 0
	}


# Village markets must be buildable even after the last coin is spent.
# The same quote is used for payment and the public build button.
func building_cost(kind: String) -> Dictionary:
	if not BUILDINGS.has(kind):
		return {}
	var price: Dictionary = BUILDINGS[kind].cost.duplicate(true)
	if living_village and kind == "market":
		price.erase("coins")
	return price


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
	if not BUILDINGS.has(kind) or (not living_village and kind not in CLASSIC_KINDS):
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
	var cost: Dictionary = building_cost(kind)
	if not _affords(town, cost):
		last_error = "Dafür fehlen noch Rohstoffe. Produziere oder handle zuerst."
		return false
	_pay(town, cost)
	var new_building := {"id": "b%d" % int(town.next_id), "kind": kind, "plot": plot}
	# Exact paid prices survive Save/Load and never mint coins on demolition.
	# Older markets without this receipt retain their historical two-coin refund.
	if living_village and kind == "market":
		new_building["purchase_cost"] = cost.duplicate(true)
	town.buildings.append(new_building)
	if living_village and kind == "house":
		VILLAGE.house_built(town, "b%d" % int(town.next_id))
	town.next_id = int(town.next_id) + 1
	if living_village:
		VILLAGE.update_campaign(self, town)
	return true


func demolition_quote(plot: int) -> Dictionary:
	for building: Dictionary in _player.buildings:
		if int(building.plot) == plot:
			var definition: Dictionary = BUILDINGS[str(building.kind)]
			var removed_capacity: int = (
				4 if living_village and str(building.kind) == "house" else int(definition.capacity)
			)
			var capacity_after: int = _capacity(_player) - removed_capacity
			var affected: int = (
				maxi(0, int(_player.population) - capacity_after)
				if int(definition.capacity) > 0
				else 0
			)
			var paid_cost: Dictionary = building.get("purchase_cost", definition.cost)
			return {
				"refund": paid_cost.duplicate(true),
				"affected_residents": affected,
				"population_after":
				(
					maxi(2, mini(int(_player.population), capacity_after))
					if affected > 0
					else int(_player.population)
				)
			}
	return {}


func try_demolish(plot: int, allow_relocation: bool = false) -> bool:
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
		var quote := demolition_quote(plot)
		if int(quote.affected_residents) > 0 and not allow_relocation:
			last_error = "Deine Bewohner brauchen dieses Zuhause. Baue zuerst ein weiteres Wohnhaus."
			return false
		var before := _player.duplicate(true)
		# Recover the actual building materials, not market resale prices. This
		# keeps experimenting reversible even after Next Day has cleared Undo.
		# Existing stock never decreases; a full store simply cannot hold more.
		var paid_cost: Dictionary = quote.refund
		for resource: String in paid_cost:
			_player.resources[resource] = mini(
				MAX_RESOURCE, int(_player.resources[resource]) + int(paid_cost[resource])
			)
		# A separate, explicitly confirmed relocation is the escape route from a
		# fully housed/occupied island. The two founders remain in the starter
		# camp (the same legal state as a new town). No resident is killed.
		_player.population = int(quote.population_after)
		_player.buildings.remove_at(index)
		if living_village:
			VILLAGE.reconcile_households(_player)
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
	if living_village and received == "coins":
		VILLAGE.credit_income(_player, amount)
	else:
		_player.resources[received] = int(_player.resources[received]) + amount
	if living_village:
		VILLAGE.synchronize_pantry(_player)
		_player.trade_count = mini(VILLAGE.MAX_COUNTER, int(_player.trade_count) + 1)
		VILLAGE.update_campaign(self, _player)
	_remember(before)
	return true


static func trade_quote(resource: String, quantity: int, sell: bool) -> Dictionary:
	if resource not in ["wood", "stone", "food"] or quantity < 1 or quantity > 10:
		return {}
	var sell_rate := 3 if resource == "food" else 2
	var buy_rate := 2 if resource == "food" else 1
	return {
		"cost": {resource: quantity * sell_rate} if sell else {"coins": quantity},
		"resource": "coins" if sell else resource,
		"amount": quantity if sell else quantity * buy_rate
	}


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
	if living_village:
		last_error = VILLAGE.expansion_error(self, town)
	else:
		last_error = _legacy_expansion_error(town)
	if not last_error.is_empty():
		return false
	if living_village:
		_pay(town, VILLAGE.expansion_cost(int(town.region)))
	else:
		_pay(town, EXPANSION_COST)
	town.region = int(town.region) + 1
	town.plots = PLOTS[int(town.region)]
	if living_village:
		VILLAGE.update_campaign(self, town)
	return true


func _legacy_expansion_error(town: Dictionary) -> String:
	if int(town.region) >= 2:
		return "Alle drei Regionen sind erschlossen."
	if int(town.population) < 4:
		return "Versorge zuerst vier Bewohner."
	if _count(town, "lumber") == 0 or _count(town, "quarry") == 0:
		return (
			"Sichere zuerst die Baustoffe: Deine Stadt braucht "
			+ "eine Holzwerkstatt und einen Steinbruch."
		)
	if not _affords(town, EXPANSION_COST):
		return "Die Erschließung braucht 12 Holz, 10 Stein und 4 Münzen."
	return ""


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
	return {
		"advanced": true,
		"day": day,
		"player": own,
		"rival": neighbor,
		"rival_actions": actions,
		"winner": winner,
		"level": _level(_player)
	}


func _produce(town: Dictionary) -> Dictionary:
	if living_village:
		return VILLAGE.produce(self, town, day + 1)
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
		town.resources[resource] = mini(
			MAX_RESOURCE, int(town.resources[resource]) + int(output[resource])
		)
	var needs := int(town.population)
	town.food_shortfall = maxi(0, needs - int(town.resources.food))
	town.resources.food = maxi(0, int(town.resources.food) - needs)
	var grew := false
	if (
		int(town.food_shortfall) == 0
		and _capacity(town) > needs
		and int(town.resources.food) >= needs + 2
	):
		town.population = mini(50, needs + 1)
		grew = true
	return {
		"produced": output,
		"food_needed": needs,
		"food_shortfall": town.food_shortfall,
		"grew": grew
	}


func _rival_plan() -> Array[String]:
	var actions: Array[String] = []
	# The neighbour has the same starting supplies and uses only its own public
	# needs. No lookahead into the child's actions, free resources or teleports.
	for _action in range(3):
		var priorities: Array[String] = []
		if living_village and VILLAGE.water_capacity(self, _rival) <= int(_rival.population) + 1:
			priorities.append("well")
		if _count(_rival, "house") == 0:
			priorities.append("house")
		if _count(_rival, "farm") == 0:
			priorities.append("farm")
		if _count(_rival, "lumber") == 0:
			priorities.append("lumber")
		if _count(_rival, "quarry") == 0:
			priorities.append("quarry")
		if _capacity(_rival) <= int(_rival.population):
			priorities.append("house")
		if (
			_count(_rival, "farm") * (6 if int(_rival.region) >= 1 else 5)
			<= int(_rival.population) + 2
		):
			priorities.append("farm")
		if _count(_rival, "market") == 0:
			priorities.append("market")
		if int(_rival.population) >= 4 and int(_rival.region) < 2 and _expand_town(_rival):
			actions.append("Erschließt " + REGIONS[int(_rival.region)])
			continue
		if _count(_rival, "school") == 0 and _level(_rival) >= 2:
			priorities.append("school")
		if int(_rival.population) < 10 and _capacity(_rival) < 10:
			priorities.append("house")
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
		if not occupied.has(plot):
			return plot
	return -1


func _affords(town: Dictionary, cost: Dictionary) -> bool:
	for resource: String in cost:
		if int(town.resources[resource]) < int(cost[resource]):
			return false
	return true


func _pay(town: Dictionary, cost: Dictionary) -> void:
	for resource: String in cost:
		town.resources[resource] = int(town.resources[resource]) - int(cost[resource])


func _count(town: Dictionary, kind: String) -> int:
	var count := 0
	for building: Dictionary in town.buildings:
		if str(building.kind) == kind:
			count += 1
	return count


func _capacity(town: Dictionary) -> int:
	if living_village:
		return VILLAGE.capacity(self, town)
	return _count(town, "house") * 2


func _level(town: Dictionary) -> int:
	if _count(town, "house") < 1 or _count(town, "farm") < 1:
		return 0
	if (
		int(town.population) < 6
		or _count(town, "lumber") < 1
		or _count(town, "quarry") < 1
		or _count(town, "market") < 1
		or int(town.region) < 1
	):
		return 1
	if (
		int(town.population) < 10
		or _count(town, "school") < 1
		or _count(town, "farm") < 2
		or int(town.region) < 2
	):
		return 2
	return 3


func status() -> Dictionary:
	var level := _level(_player)
	var goals: Array[Dictionary] = []
	if level == 0:
		goals = [
			{"title": "Wohnhaus", "current": _count(_player, "house"), "target": 1},
			{"title": "Bauernhof", "current": _count(_player, "farm"), "target": 1}
		]
	elif level == 1:
		goals = [
			{"title": "Bewohner", "current": int(_player.population), "target": 6},
			{"title": "Holzwerkstatt", "current": _count(_player, "lumber"), "target": 1},
			{"title": "Steinbruch", "current": _count(_player, "quarry"), "target": 1},
			{"title": "Marktplatz", "current": _count(_player, "market"), "target": 1},
			{"title": "Neue Region", "current": int(_player.region), "target": 1}
		]
	elif level == 2:
		goals = [
			{"title": "Bewohner", "current": int(_player.population), "target": 10},
			{"title": "Lernhaus", "current": _count(_player, "school"), "target": 1},
			{"title": "Bauernhöfe", "current": _count(_player, "farm"), "target": 2},
			{"title": "Neue Regionen", "current": int(_player.region), "target": 2}
		]
	var result := {
		"day": day,
		"mode": mode,
		"level": level,
		"reached_level": level,
		"target":
		[
			"Ein Zuhause mit Versorgung",
			"Ein lebendiges Dorf",
			"Eine lernende Stadt",
			"Deine Stadt blüht!"
		][level],
		"world": REGIONS[int(_player.region)],
		"region": int(_player.region),
		"goals": goals,
		"capacity": _capacity(_player),
		"rival_level": _level(_rival),
		"winner": winner,
		"can_expand":
		(
			int(_player.region) < 2
			and int(_player.population) >= 4
			and _count(_player, "lumber") > 0
			and _count(_player, "quarry") > 0
			and _affords(_player, EXPANSION_COST)
		),
		"can_undo": not _undo.is_empty(),
		"can_redo": not _redo.is_empty(),
		"complete": level == 3
	}
	if living_village:
		result.can_expand = VILLAGE.expansion_error(self, _player).is_empty()
		result.expansion_cost = VILLAGE.expansion_cost(int(_player.region))
		result.campaign = campaign_status()
		result.economy = economy_status()
	return result


func _can_act() -> bool:
	if mode == "rival" and not winner.is_empty():
		last_error = "Der Wettbau ist abgeschlossen. Starte eine neue Welt oder baue frei weiter."
		return false
	return true


func _remember(before: Dictionary) -> void:
	_undo.append(before)
	if _undo.size() > 32:
		_undo.pop_front()
	_redo.clear()


func undo() -> bool:
	if _undo.is_empty() or not _can_act():
		return false
	_redo.append(_player.duplicate(true))
	_player = _undo.pop_back()
	last_error = ""
	return true


func redo() -> bool:
	if _redo.is_empty() or not _can_act():
		return false
	_undo.append(_player.duplicate(true))
	_player = _redo.pop_back()
	last_error = ""
	return true


func snapshot() -> Dictionary:
	return {
		"version": 2 if living_village else 1,
		"mode": mode,
		"day": day,
		"winner": winner,
		"player": _player.duplicate(true),
		"rival": _rival.duplicate(true)
	}


static func restore(data: Dictionary):
	if not _whole(data.get("version"), 1, 2) or data.get("mode") not in ["settlement", "rival"]:
		return null
	if (
		not _whole(data.get("day"), 1, MAX_DAY)
		or data.get("winner", "") not in ["", "player", "rival", "tie"]
	):
		return null
	for key in ["player", "rival"]:
		if not data.get(key) is Dictionary or not _valid_town(data[key], data.version == 2):
			return null
	var model = load("res://scripts/creative/build_settlement_state.gd").new(
		str(data.mode), data.version == 2
	)
	model.day = int(data.day)
	model.winner = str(data.get("winner", ""))
	model._player = _restored_town(data.player)
	model._rival = _restored_town(data.rival)
	if model.mode == "settlement" and not model.winner.is_empty():
		return null
	if model.winner in ["player", "tie"] and model._level(model._player) != 3:
		return null
	if model.winner in ["rival", "tie"] and model._level(model._rival) != 3:
		return null
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
		var restored_building := {
			"id": str(building.id), "kind": str(building.kind), "plot": int(building.plot)
		}
		if building.has("purchase_cost"):
			restored_building["purchase_cost"] = building.purchase_cost.duplicate(true)
		result.buildings.append(restored_building)
	if int(town.get("economy_version", 0)) == 2:
		VILLAGE.restore_fields(town, result)
	return result


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and float(value) >= minimum
		and float(value) <= maximum
	)


static func _valid_town(town: Dictionary, is_living: bool = false) -> bool:
	if not town.get("resources") is Dictionary or not town.get("buildings") is Array:
		print("[LumoGuard] StateGuard:646")
		return false
	if (
		not _whole(town.get("region"), 0, 11 if is_living else 2)
		or not _whole(town.get("population"), 2, VILLAGE.MAX_POPULATION if is_living else 50)
	):
		print("[LumoGuard] StateGuard:651")
		return false
	if (
		not _whole(town.get("plots"), 9, 1089 if is_living else 25)
		or int(town.plots) != PLOTS[int(town.region)]
	):
		print("[LumoGuard] StateGuard:656")
		return false
	if (
		not _whole(town.get("next_id"), 1, 10000)
		or not _whole(town.get("food_shortfall", 0), 0, VILLAGE.MAX_POPULATION if is_living else 50)
	):
		print("[LumoGuard] StateGuard:661")
		return false
	for resource in RESOURCES:
		if not _whole(town.resources.get(resource), 0, MAX_RESOURCE):
			print("[LumoGuard] StateGuard:664")
			return false
	if town.buildings.size() > int(town.plots):
		print("[LumoGuard] StateGuard:666")
		return false
	var occupied := {}
	var identifiers := {}
	for building: Variant in town.buildings:
		if not building is Dictionary or not BUILDINGS.has(building.get("kind", "")):
			print("[LumoGuard] StateGuard:671")
			return false
		# The only new paid-price receipt is the coin-free village market.
		# Validate it to prevent a tampered save from crediting arbitrary resources.
		if building.has("purchase_cost") and (
			not is_living
			or building.kind != "market"
			or building.purchase_cost != {"wood": 6, "stone": 4}
		):
			print("[LumoGuard] StateGuard:679")
			return false
		if not _whole(building.get("plot"), 0, int(town.plots) - 1):
			print("[LumoGuard] StateGuard:681")
			return false
		var identifier := str(building.get("id", ""))
		if not identifier.begins_with("b") or not identifier.substr(1).is_valid_int():
			print("[LumoGuard] StateGuard:684")
			return false
		var number := identifier.substr(1).to_int()
		if number < 1 or number >= int(town.next_id) or identifiers.has(identifier):
			print("[LumoGuard] StateGuard:687")
			return false
		if occupied.has(int(building.plot)):
			print("[LumoGuard] StateGuard:689")
			return false
		occupied[int(building.plot)] = true
		identifiers[identifier] = true
	if is_living and not VILLAGE.valid(town, _whole):
		print("[LumoGuard] StateGuard:693")
		return false
	return true


func enable_living_village() -> void:
	if living_village:
		return
	living_village = true
	VILLAGE.upgrade(_player)
	VILLAGE.upgrade(_rival)
	VILLAGE.update_campaign(self, _player)
	VILLAGE.update_campaign(self, _rival)
	_undo.clear()
	_redo.clear()


func campaign_status() -> Dictionary:
	return VILLAGE.campaign_status(self, _player) if living_village else {}


func economy_status() -> Dictionary:
	return VILLAGE.economy_status(self, _player) if living_village else {}


func day_report() -> Dictionary:
	return _player.last_report.duplicate(true) if living_village else {}


func public_projects() -> Array[Dictionary]:
	return VILLAGE.public_projects(_player) if living_village else []


func fund_project(id: String) -> bool:
	last_error = ""
	if not _can_act() or not living_village:
		return false
	if not VILLAGE.PROJECTS.has(id) or bool(_player.city_projects.get(id, false)):
		last_error = "Wähle ein neues Gemeinschaftsprojekt."
		return false
	var cost: int = int(VILLAGE.PROJECTS[id].cost)
	if int(_player.treasury) < cost:
		last_error = "In der Stadtkasse fehlen noch %d Münzen." % (cost - int(_player.treasury))
		return false
	var before := _player.duplicate(true)
	_player.treasury = int(_player.treasury) - cost
	_player.city_projects[id] = true
	VILLAGE.update_campaign(self, _player)
	_remember(before)
	return true


func trader_offer() -> Dictionary:
	return VILLAGE.trader_offer(_player, day) if living_village else {}


func order_delivery(id: String) -> bool:
	last_error = ""
	if not _can_act() or not living_village:
		return false
	last_error = VILLAGE.order_error(self, _player, id, day)
	if not last_error.is_empty():
		return false
	var before := _player.duplicate(true)
	VILLAGE.order(self, _player, id, day)
	VILLAGE.update_campaign(self, _player)
	_remember(before)
	return true
