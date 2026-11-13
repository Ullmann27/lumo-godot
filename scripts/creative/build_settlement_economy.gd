extends RefCounted
## Living-village rules shared by the child and the neighbour. No wall-clock
## timers, paid currency or hidden AI income; one action advances one village day.
const MAX_RESOURCE := 99999
const MAX_POPULATION := 4096
const MAX_COUNTER := 99999999
const REGIONS := [
	"Wiesenwinkel", "Flussufer", "Sonnenhöhe", "Apfelhain", "Kornfelder", "Mühlenweg",
	"Birkenviertel", "Seegärten", "Hügelstadt", "Blütenpark", "Sternental", "Lumo-Land"
]
const PLOTS := [9, 16, 25, 49, 81, 121, 169, 225, 361, 529, 729, 1089]
const PROJECTS := {
	"playground": {"title": "Gemeinsamer Spielplatz", "cost": 8, "description": "Alle Familien haben einen Ort zum Spielen. Das Dorf wird zufriedener."},
	"bridge": {"title": "Lieferbrücke", "cost": 12, "description": "Die Werkstätten liefern täglich je einen Baustoff mehr."},
	"irrigation": {"title": "Gemeinsame Bewässerung", "cost": 16, "description": "Zwölf Bewohner bekommen Wasser. Jeder Bauernhof erntet zwei Karotten mehr."},
	"library": {"title": "Offene Bücherei", "cost": 20, "description": "Familien lernen gemeinsam. Zufriedene Familientage zählen schneller."}
}
const OFFERS := {
	"carrots": {"title": "Karottenkiste", "cost": {"coins": 4}, "receive": {"food": 12}, "delay": 1},
	"materials": {"title": "Baustoffwagen", "cost": {"coins": 6}, "receive": {"wood": 8, "stone": 6}, "delay": 1},
	"grain": {"title": "Kornwagen", "cost": {"coins": 3}, "receive": {"grain": 9}, "delay": 1}
}
const COUNTERS := [
	"treasury", "tax_remainder", "income_total", "tax_total", "trade_count",
	"deliveries_ordered", "bread_batches", "healthy_days", "campaign_chapter",
	"next_delivery_id", "order_day", "orders_today"
]


static func upgrade(town: Dictionary) -> void:
	if int(town.get("economy_version", 0)) == 2:
		return
	town.economy_version = 2
	town.treasury = 0
	town.tax_remainder = 0
	town.income_total = 0
	town.tax_total = 0
	town.trade_count = 0
	town.deliveries_ordered = 0
	town.bread_batches = 0
	town.healthy_days = 0
	town.campaign_chapter = 0
	town.next_delivery_id = 1
	town.order_day = 0
	town.orders_today = 0
	town.city_projects = {}
	town.crops = {"carrots": int(town.resources.food), "grain": 0, "bread": 0}
	town.deliveries = []
	town.households = []
	town.pending_income = {"gross_income": 0, "city_contribution": 0, "net_income": 0}
	town.last_report = empty_report()
	reconcile_households(town)


static func empty_report() -> Dictionary:
	return {
		"day": 1, "produced": {"wood": 0, "stone": 0, "food": 0, "coins": 0},
		"food_needed": 2, "food_shortfall": 0, "grew": false, "gross_income": 0,
		"city_contribution": 0, "net_income": 0, "tax_percent": 20,
		"tax_remainder": 0, "treasury": 0, "arrivals": 0, "births": 0,
		"deliveries_received": [], "water_shortfall": 0,
		"message": "Lumo wartet auf deinen ersten Dorftag."
	}


static func house_built(town: Dictionary, building_id: String) -> void:
	var arrivals := 1 if int(town.population) < MAX_POPULATION else 0
	town.households.append({"building_id": building_id, "adults": arrivals, "children": 0, "supplied_days": 0})
	town.population = int(town.population) + arrivals


static func reconcile_households(town: Dictionary) -> void:
	var previous := {}
	for family: Dictionary in town.households:
		previous[str(family.building_id)] = family.duplicate(true)
	var families: Array = []
	var unassigned := maxi(0, int(town.population) - 2)
	for building: Dictionary in town.buildings:
		if str(building.kind) != "house":
			continue
		var family: Dictionary = previous.get(str(building.id), {"building_id": str(building.id), "adults": 0, "children": 0, "supplied_days": 0})
		var adults := mini(unassigned, mini(2, int(family.adults)))
		unassigned -= adults
		var children := mini(unassigned, mini(2, int(family.children)))
		unassigned -= children
		family.adults = adults
		family.children = children
		families.append(family)
	for family: Dictionary in families:
		var adults := mini(unassigned, 2 - int(family.adults))
		family.adults = int(family.adults) + adults
		unassigned -= adults
		var children := mini(unassigned, 2 - int(family.children))
		family.children = int(family.children) + children
		unassigned -= children
	town.households = families


static func capacity(model, town: Dictionary) -> int:
	return mini(MAX_POPULATION, 2 + model._count(town, "house") * 4)


static func water_capacity(model, town: Dictionary) -> int:
	return 4 + model._count(town, "well") * 12 + (12 if bool(town.city_projects.get("irrigation", false)) else 0)


static func expansion_cost(region: int) -> Dictionary:
	var step := maxi(0, region - 1)
	return {"wood": 12 + step * 6, "stone": 10 + step * 4, "coins": 4 + step * 2}


static func expansion_error(model, town: Dictionary) -> String:
	if int(town.region) >= REGIONS.size() - 1:
		return "Dein Lumo-Land ist vollständig erschlossen."
	var residents := 4 if int(town.region) < 2 else 4 + int(town.region) * 2
	if int(town.population) < residents:
		return "Versorge zuerst %d Bewohner." % residents
	if model._count(town, "lumber") == 0 or model._count(town, "quarry") == 0:
		return "Baue zuerst eine Holzwerkstatt und einen Steinbruch."
	if int(town.region) >= 2 and (model._count(town, "well") == 0 or model._count(town, "road") == 0):
		return "Das größere Dorf braucht einen Brunnen und einen Wegeplatz."
	var cost := expansion_cost(int(town.region))
	if not model._affords(town, cost):
		return "Für das nächste Gebiet brauchst du %d Holz, %d Stein und %d Münzen." % [cost.wood, cost.stone, cost.coins]
	return ""


static func income_quote(town: Dictionary, gross: int) -> Dictionary:
	var combined := gross + int(town.tax_remainder)
	var contribution := combined / 5
	return {"gross_income": gross, "city_contribution": contribution, "net_income": gross - contribution, "tax_remainder": combined % 5}


static func credit_income(town: Dictionary, requested: int) -> Dictionary:
	# Bound gross income before changing either purse, so no tax or private
	# earnings disappear at the storage limit. Integer fifths retain small sales.
	var low := 0
	var high := maxi(0, mini(requested, MAX_COUNTER - int(town.income_total)))
	while low < high:
		var middle := (low + high + 1) / 2
		var candidate := income_quote(town, middle)
		if int(town.resources.coins) + int(candidate.net_income) <= MAX_RESOURCE and int(town.treasury) + int(candidate.city_contribution) <= MAX_RESOURCE:
			low = middle
		else:
			high = middle - 1
	var paid := income_quote(town, low)
	town.resources.coins = int(town.resources.coins) + int(paid.net_income)
	town.treasury = int(town.treasury) + int(paid.city_contribution)
	town.tax_remainder = int(paid.tax_remainder)
	town.income_total = int(town.income_total) + low
	town.tax_total = int(town.tax_total) + int(paid.city_contribution)
	for key in ["gross_income", "city_contribution", "net_income"]:
		town.pending_income[key] = int(town.pending_income[key]) + int(paid[key])
	return paid


static func synchronize_pantry(town: Dictionary) -> void:
	var edible := int(town.crops.carrots) + int(town.crops.bread)
	var difference := int(town.resources.food) - edible
	if difference >= 0:
		town.crops.carrots = int(town.crops.carrots) + difference
	else:
		var from_carrots := mini(-difference, int(town.crops.carrots))
		town.crops.carrots = int(town.crops.carrots) - from_carrots
		town.crops.bread = int(town.crops.bread) - (-difference - from_carrots)


static func produce(model, town: Dictionary, tomorrow: int) -> Dictionary:
	var report := empty_report()
	report.day = tomorrow
	report.deliveries_received = _receive_deliveries(town, tomorrow)
	var output := {"wood": 0, "stone": 0, "food": 0, "coins": 0}
	var wells := water_capacity(model, town)
	var enough_water := wells >= int(town.population)
	var farms: int = model._count(town, "farm")
	var carrots := farms * (5 if enough_water else 3)
	if int(town.region) >= 1:
		carrots += farms
	if bool(town.city_projects.get("irrigation", false)):
		carrots += farms * 2
	carrots = mini(carrots, MAX_RESOURCE - int(town.resources.food))
	town.crops.carrots = int(town.crops.carrots) + carrots
	town.resources.food = int(town.resources.food) + carrots
	output.food = carrots
	var grain: int = model._count(town, "grain") * (4 if enough_water else 2)
	town.crops.grain = mini(MAX_RESOURCE, int(town.crops.grain) + grain)
	var batches := mini(model._count(town, "bakery"), int(town.crops.grain) / 3)
	batches = mini(batches, (MAX_RESOURCE - int(town.resources.food)) / 4)
	town.crops.grain = int(town.crops.grain) - batches * 3
	town.crops.bread = int(town.crops.bread) + batches * 4
	town.resources.food = int(town.resources.food) + batches * 4
	town.bread_batches = mini(MAX_COUNTER, int(town.bread_batches) + batches)
	output.food = int(output.food) + batches * 4
	var bridge_bonus := 1 if bool(town.city_projects.get("bridge", false)) else 0
	output.wood = model._count(town, "lumber") * (4 + bridge_bonus)
	output.stone = model._count(town, "quarry") * (3 + bridge_bonus + (1 if int(town.region) >= 2 else 0))
	for resource in ["wood", "stone"]:
		output[resource] = mini(int(output[resource]), MAX_RESOURCE - int(town.resources[resource]))
		town.resources[resource] = int(town.resources[resource]) + int(output[resource])
	var gross: int = model._count(town, "market") * 2
	if model._count(town, "road") > 0:
		gross += model._count(town, "market")
	var paid := credit_income(town, gross)
	output.coins = int(paid.net_income)
	var needs := int(town.population)
	town.food_shortfall = maxi(0, needs - int(town.resources.food))
	town.resources.food = maxi(0, int(town.resources.food) - needs)
	synchronize_pantry(town)
	var satisfied := int(town.food_shortfall) == 0 and enough_water
	if satisfied:
		town.healthy_days = mini(MAX_COUNTER, int(town.healthy_days) + 1)
	var growth := _grow_families(model, town, satisfied)
	report.produced = output
	report.food_needed = needs
	report.food_shortfall = int(town.food_shortfall)
	report.water_shortfall = maxi(0, needs - wells)
	report.arrivals = growth.arrivals
	report.births = growth.births
	report.grew = int(growth.arrivals) + int(growth.births) > 0
	for key in ["gross_income", "city_contribution", "net_income"]:
		report[key] = int(town.pending_income[key])
		town.pending_income[key] = 0
	report.tax_remainder = int(town.tax_remainder)
	report.treasury = int(town.treasury)
	report.message = "Alle hatten heute genug zu essen."
	if int(report.food_shortfall) > 0:
		report.message = "Es fehlen %d Portionen. Nelli hilft: Baue einen Bauernhof oder bestelle Karotten." % int(report.food_shortfall)
	elif int(report.water_shortfall) > 0:
		report.message = "Essen ist da. Ein Brunnen bringt noch %d Bewohnern Wasser." % int(report.water_shortfall)
	elif int(report.births) > 0:
		report.message = "%d neue Kinder wohnen im Dorf. Plane mehr Essen und Wasser ein." % int(report.births)
	elif int(report.arrivals) > 0:
		report.message = "%d Freunde sind zu ihren Familien gezogen. Dein Dorf wächst." % int(report.arrivals)
	town.last_report = report.duplicate(true)
	update_campaign(model, town)
	return report


static func _grow_families(model, town: Dictionary, satisfied: bool) -> Dictionary:
	var arrivals := 0
	var births := 0
	for family: Dictionary in town.households:
		if not satisfied:
			continue
		family.supplied_days = mini(9999, int(family.supplied_days) + (2 if bool(town.city_projects.get("library", false)) else 1))
		# Growth requires an extra day's food buffer and an actual water place.
		# Shortages pause growth; residents are never killed or taken away.
		if int(town.resources.food) < int(town.population) + 2 or int(town.population) >= water_capacity(model, town) or int(town.population) >= MAX_POPULATION:
			continue
		if int(family.adults) == 0 or (int(family.adults) == 1 and int(family.supplied_days) >= 3):
			family.adults = int(family.adults) + 1
			town.population = int(town.population) + 1
			arrivals += 1
		elif int(family.adults) == 2 and model._count(town, "school") > 0 and int(family.children) < 2 and int(family.supplied_days) >= 8 + int(family.children) * 6:
			family.children = int(family.children) + 1
			town.population = int(town.population) + 1
			births += 1
	return {"arrivals": arrivals, "births": births}


static func trader_offer(town: Dictionary, day: int) -> Dictionary:
	var offers: Array[Dictionary] = []
	for id: String in OFFERS:
		var offer: Dictionary = OFFERS[id].duplicate(true)
		offer.id = id
		offers.append(offer)
	return {"available": (day - 1) % 3 == 0, "name": "Tilda", "arrives_in": (3 - ((day - 1) % 3)) % 3, "offers": offers, "orders_left": 3 - (int(town.orders_today) if int(town.order_day) == day else 0)}


static func order_error(model, town: Dictionary, id: String, day: int) -> String:
	if not OFFERS.has(id):
		return "Wähle eine Lieferung aus Tildas Wagen."
	if (day - 1) % 3 != 0:
		return "Tilda kommt alle drei Dorftage. Ihr nächster Besuch steht am Markt."
	if int(town.order_day) == day and int(town.orders_today) >= 3:
		return "Tildas drei Wagen sind unterwegs. Warte auf ihren nächsten Besuch."
	if town.deliveries.size() >= 32:
		return "Lass zuerst deine bestellten Wagen ankommen."
	if not model._affords(town, OFFERS[id].cost):
		return "Für diese Lieferung fehlen noch Münzen."
	return ""


static func order(model, town: Dictionary, id: String, day: int) -> void:
	model._pay(town, OFFERS[id].cost)
	if int(town.order_day) != day:
		town.order_day = day
		town.orders_today = 0
	town.orders_today = int(town.orders_today) + 1
	town.deliveries.append({"id": int(town.next_delivery_id), "offer": id, "arrival_day": day + int(OFFERS[id].delay)})
	town.next_delivery_id = int(town.next_delivery_id) + 1
	town.deliveries_ordered = mini(MAX_COUNTER, int(town.deliveries_ordered) + 1)


static func _receive_deliveries(town: Dictionary, today: int) -> Array[String]:
	var received: Array[String] = []
	var waiting: Array = []
	for delivery: Dictionary in town.deliveries:
		if int(delivery.arrival_day) > today:
			waiting.append(delivery)
			continue
		var offer: Dictionary = OFFERS[str(delivery.offer)]
		var fits := true
		for key: String in offer.receive:
			var stock: int = int(town.crops.grain) if key == "grain" else int(town.resources[key])
			if stock + int(offer.receive[key]) > MAX_RESOURCE:
				fits = false
		if not fits:
			waiting.append(delivery)
			continue
		for key: String in offer.receive:
			if key == "grain":
				town.crops.grain = int(town.crops.grain) + int(offer.receive[key])
			else:
				town.resources[key] = int(town.resources[key]) + int(offer.receive[key])
		synchronize_pantry(town)
		received.append(str(offer.title))
	town.deliveries = waiting
	return received


static func public_projects(town: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in PROJECTS:
		var item: Dictionary = PROJECTS[id].duplicate(true)
		item.id = id
		item.completed = bool(town.city_projects.get(id, false))
		result.append(item)
	return result


static func economy_status(model, town: Dictionary) -> Dictionary:
	var result: Dictionary = town.last_report.duplicate(true)
	result.treasury = int(town.treasury)
	result.tax_percent = 20
	result.tax_remainder = int(town.tax_remainder)
	result.residents = int(town.population)
	result.households = town.households.size()
	result.children = 0
	for family: Dictionary in town.households:
		result.children = int(result.children) + int(family.children)
	result.water_capacity = water_capacity(model, town)
	result.food_needed = int(town.population)
	result.food_balance = int(town.resources.food) - int(town.population)
	result.roads = model._count(town, "road")
	result.happiness = clampi(65 + (10 if model._count(town, "clinic") > 0 else 0) + (10 if bool(town.city_projects.get("playground", false)) else 0) + (10 if bool(town.city_projects.get("library", false)) else 0) - (30 if int(town.food_shortfall) > 0 else 0) - (20 if int(town.population) > int(result.water_capacity) else 0), 0, 100)
	result.deliveries = town.deliveries.duplicate(true)
	result.projects = town.city_projects.duplicate(true)
	result.crops = town.crops.duplicate(true)
	result.income_total = int(town.income_total)
	result.tax_total = int(town.tax_total)
	result.pending_income = town.pending_income.duplicate(true)
	return result


static func _chapter(model, town: Dictionary, index: int) -> Dictionary:
	var data := {"friend": "Lumo", "title": "", "story": "", "task": "", "hint": "", "goals": []}
	var pop := int(town.population)
	match index:
		0:
			data.merge({"friend": "Nelli", "title": "Ein Zuhause im Wiesenwinkel", "story": "Lumo und seine Freunde wollen ein Dorf gründen. Nelli bringt die ersten Karotten mit.", "task": "Baue ein Wohnhaus und einen Bauernhof.", "hint": "Tippe ein freies Grundstück an. Das Haus bringt einen Bewohner; der Bauernhof liefert Essen.", "goals": [_goal("Wohnhaus", model._count(town, "house"), 1), _goal("Bauernhof", model._count(town, "farm"), 1)]}, true)
		1:
			data.merge({"friend": "Nelli", "title": "Wasser für alle", "story": "Ein Freund zieht zur Familie. Mehr Bewohner brauchen auch mehr Wasser.", "task": "Baue einen Brunnen und versorge vier Bewohner.", "hint": "Drei gut versorgte Familientage bringen einen zweiten Erwachsenen ins Haus.", "goals": [_goal("Brunnen", model._count(town, "well"), 1), _goal("Bewohner", pop, 4)]}, true)
		2:
			data.merge({"friend": "Bruno", "title": "Brunos Bauwerkstatt", "story": "Bruno hilft beim Bauen. Holz und Steine wachsen aber nicht in der Geldbörse.", "task": "Baue Holzwerkstatt und Steinbruch.", "hint": "Mit eigenen Baustoffen kannst du dein Dorf weiterbauen, auch wenn die Münzen knapp sind.", "goals": [_goal("Holzwerkstatt", model._count(town, "lumber"), 1), _goal("Steinbruch", model._count(town, "quarry"), 1)]}, true)
		3:
			data.merge({"friend": "Tilda", "title": "Tildas erster Handel", "story": "Tilda fährt mit ihrem Lieferwagen zwischen den Dörfern. Du entscheidest, was deine Stadt braucht.", "task": "Baue den Markt und handle oder bestelle eine Lieferung.", "hint": "Schau zuerst auf den Preis und den Vorrat. Tilda kommt alle drei Dorftage.", "goals": [_goal("Markt", model._count(town, "market"), 1), _goal("Handel", int(town.trade_count) + int(town.deliveries_ordered), 1)]}, true)
		4:
			data.merge({"title": "Zwei von zehn für die Stadt", "story": "In Lumo-Land teilen alle einen Teil ihres Einkommens. Die Stadtkasse gehört der Gemeinschaft.", "task": "Verdiene insgesamt zehn Münzen und beobachte den Stadtbeitrag.", "hint": "Die Lumo-Spielregel lautet 20 Prozent: Von zehn Münzen gehen zwei in die Stadtkasse. Kleine Reste werden mitgezählt.", "goals": [_goal("Verdiente Münzen", int(town.income_total), 10), _goal("Stadtbeitrag", int(town.tax_total), 2)]}, true)
		5:
			data.merge({"friend": "Nelli", "title": "Vom Korn zum Brot", "story": "Nelli sät Korn. In der Bäckerei werden daraus Brote für die Nachbarschaft.", "task": "Baue Kornfeld und Bäckerei. Backe drei Portionen.", "hint": "Eine Bäckerei macht pro Tag aus drei Korn vier Portionen Brot.", "goals": [_goal("Kornfeld", model._count(town, "grain"), 1), _goal("Bäckerei", model._count(town, "bakery"), 1), _goal("Backrunden", int(town.bread_batches), 3)]}, true)
		6:
			data.merge({"title": "Platz für eine Familie", "story": "Die Freunde wohnen schon lange zusammen. Nun werden die Familien größer.", "task": "Baue ein Lernhaus und versorge das erste Kind.", "hint": "Nach acht gut versorgten Familientagen kann ein Kind einziehen. Nahrung, Wasser und Lernhaus müssen bereit sein.", "goals": [_goal("Lernhaus", model._count(town, "school"), 1), _goal("Kinder", _children(town), 1)]}, true)
		7:
			data.merge({"friend": "Bruno", "title": "Unsere gemeinsame Brücke", "story": "Eine Brücke hilft allen. Deshalb bezahlt sie die Stadtkasse.", "task": "Erschließe den Apfelhain, baue einen Wegeplatz und finanziere die Lieferbrücke.", "hint": "Öffne die Stadtkasse. Der Beitrag wird nur einmal verdient und nur einmal ausgegeben.", "goals": [_goal("Gebiete", int(town.region) + 1, 4), _goal("Wegeplatz", model._count(town, "road"), 1), _goal("Lieferbrücke", int(bool(town.city_projects.get("bridge", false))), 1)]}, true)
		8:
			data.merge({"friend": "Tilda", "title": "Ein Dorf mit vielen Aufgaben", "story": "Tilda sieht, wie dein Dorf wächst. Vorräte, Familien und Baustoffe brauchen einen guten Plan.", "task": "Versorge 24 Bewohner und erschließe sechs Gebiete.", "hint": "Mehr Bewohner brauchen mehr Bauernhöfe, Brunnen und Wohnhäuser.", "goals": [_goal("Bewohner", pop, 24), _goal("Gebiete", int(town.region) + 1, 6), _goal("Versorgte Tage", int(town.healthy_days), 8)]}, true)
		9:
			data.merge({"title": "Eine Stadt sorgt füreinander", "story": "Die Gemeinschaft baut einen Spielplatz und ein Fürsorgehaus. Niemand muss alles alleine schaffen.", "task": "Baue ein Fürsorgehaus und finanziere Spielplatz und Bewässerung.", "hint": "Die Bewässerung hilft Bewohnern und Feldern; der Spielplatz macht Familien zufriedener.", "goals": [_goal("Fürsorgehaus", model._count(town, "clinic"), 1), _goal("Spielplatz", int(bool(town.city_projects.get("playground", false))), 1), _goal("Bewässerung", int(bool(town.city_projects.get("irrigation", false))), 1)]}, true)
		10:
			data.merge({"friend": "Bruno", "title": "Aus Nachbarn wird eine Stadt", "story": "Jedes Viertel braucht gute Wege und Orte zum Lernen. Du entscheidest, wo die Stadt als Nächstes wächst.", "task": "Versorge 48 Bewohner, erschließe neun Gebiete und eröffne die Bücherei.", "hint": "Auch eine große Stadt beginnt mit kleinen, nachvollziehbaren Entscheidungen.", "goals": [_goal("Bewohner", pop, 48), _goal("Gebiete", int(town.region) + 1, 9), _goal("Bücherei", int(bool(town.city_projects.get("library", false))), 1)]}, true)
		_:
			data.merge({"title": "Das große Lumo-Land", "story": "Lumo und seine Freunde feiern eure Stadt. Jetzt ist Platz für ganz eigene Ideen und neue Viertel.", "task": "Erschließe alle zwölf Gebiete und versorge 80 Bewohner.", "hint": "Mit acht Wegeplätzen, zwei Lernhäusern und zwei Fürsorgehäusern bereitest du die große Stadt vor.", "goals": [_goal("Gebiete", int(town.region) + 1, 12), _goal("Bewohner", pop, 80), _goal("Wegeplätze", model._count(town, "road"), 8), _goal("Lernhäuser", model._count(town, "school"), 2), _goal("Fürsorgehäuser", model._count(town, "clinic"), 2)]}, true)
	return data


static func _goal(title: String, current: int, target: int) -> Dictionary:
	return {"title": title, "current": current, "target": target}


static func _children(town: Dictionary) -> int:
	var children := 0
	for family: Dictionary in town.households:
		children += int(family.children)
	return children


static func update_campaign(model, town: Dictionary) -> void:
	while int(town.campaign_chapter) < 12:
		var chapter := _chapter(model, town, int(town.campaign_chapter))
		var done := true
		for goal: Dictionary in chapter.goals:
			if int(goal.current) < int(goal.target):
				done = false
		if not done:
			return
		town.campaign_chapter = int(town.campaign_chapter) + 1


static func campaign_status(model, town: Dictionary) -> Dictionary:
	var chapter: int = mini(11, int(town.campaign_chapter))
	var result := _chapter(model, town, chapter)
	result.chapter = chapter + 1
	result.total = 12
	result.complete = int(town.campaign_chapter) == 12
	if result.complete:
		result.title = "Dein Lumo-Land lebt!"
		result.task = "Baue frei weiter und versorge deine Stadt."
		result.story = "Alle zwölf Dorfgeschichten sind geschafft. Deine Stadt bleibt erhalten und wächst mit deinen Ideen."
	return result


static func valid(town: Dictionary, whole: Callable) -> bool:
	if town.get("economy_version") != 2:
		return false
	for key: String in COUNTERS:
		if not whole.call(town.get(key), 0, MAX_COUNTER):
			return false
	if int(town.treasury) > MAX_RESOURCE or int(town.tax_remainder) > 4 or int(town.campaign_chapter) > 12 or int(town.orders_today) > 3 or int(town.next_delivery_id) < 1:
		return false
	if int(town.tax_total) != int(town.income_total) / 5 or int(town.tax_remainder) != int(town.income_total) % 5:
		return false
	if not town.get("city_projects") is Dictionary or not town.get("crops") is Dictionary or not town.get("households") is Array or not town.get("deliveries") is Array:
		return false
	var spent := 0
	for id: Variant in town.city_projects:
		if not id is String or not PROJECTS.has(id) or town.city_projects[id] != true:
			return false
		spent += int(PROJECTS[id].cost)
	if int(town.treasury) != int(town.tax_total) - spent:
		return false
	for crop in ["carrots", "grain", "bread"]:
		if not whole.call(town.crops.get(crop), 0, MAX_RESOURCE):
			return false
	if int(town.crops.carrots) + int(town.crops.bread) != int(town.resources.food):
		return false
	var houses := {}
	for building: Dictionary in town.buildings:
		if building.kind == "house":
			houses[str(building.id)] = true
	if town.households.size() != houses.size():
		return false
	var people := 2
	for family: Variant in town.households:
		if not family is Dictionary or not houses.has(family.get("building_id")):
			return false
		if not whole.call(family.get("adults"), 0, 2) or not whole.call(family.get("children"), 0, 2) or not whole.call(family.get("supplied_days"), 0, 9999):
			return false
		houses.erase(family.building_id)
		people += int(family.adults) + int(family.children)
	if people != int(town.population):
		return false
	if town.deliveries.size() > 32:
		return false
	var delivery_ids := {}
	for delivery: Variant in town.deliveries:
		if not delivery is Dictionary or not OFFERS.has(delivery.get("offer")):
			return false
		if not whole.call(delivery.get("id"), 1, int(town.next_delivery_id) - 1) or not whole.call(delivery.get("arrival_day"), 1, 10000):
			return false
		if delivery_ids.has(int(delivery.id)):
			return false
		delivery_ids[int(delivery.id)] = true
	if not town.get("pending_income") is Dictionary or not town.get("last_report") is Dictionary:
		return false
	for key in ["gross_income", "city_contribution", "net_income"]:
		if not whole.call(town.pending_income.get(key), 0, MAX_COUNTER):
			return false
	if int(town.pending_income.gross_income) != int(town.pending_income.city_contribution) + int(town.pending_income.net_income):
		return false
	var report: Dictionary = town.last_report
	var defaults := empty_report()
	for key: String in defaults:
		if not report.has(key):
			return false
	for key in ["day", "food_needed", "food_shortfall", "gross_income", "city_contribution", "net_income", "tax_percent", "tax_remainder", "treasury", "arrivals", "births", "water_shortfall"]:
		if not whole.call(report[key], 0, MAX_COUNTER):
			return false
	if report.tax_percent != 20 or int(report.tax_remainder) > 4 or not report.grew is bool or not report.message is String or str(report.message).length() > 1024:
		return false
	if int(report.gross_income) != int(report.city_contribution) + int(report.net_income):
		return false
	if not report.produced is Dictionary or not report.deliveries_received is Array or report.deliveries_received.size() > 32:
		return false
	for key in ["wood", "stone", "food", "coins"]:
		if not whole.call(report.produced.get(key), 0, MAX_RESOURCE):
			return false
	for item: Variant in report.deliveries_received:
		if not item is String or item.length() > 80:
			return false
	return true


static func restore_fields(source: Dictionary, destination: Dictionary) -> void:
	for key: String in COUNTERS:
		destination[key] = int(source[key])
	destination.economy_version = 2
	destination.city_projects = source.city_projects.duplicate(true)
	destination.crops = {}
	for crop in ["carrots", "grain", "bread"]:
		destination.crops[crop] = int(source.crops[crop])
	destination.households = []
	for family: Dictionary in source.households:
		destination.households.append({"building_id": str(family.building_id), "adults": int(family.adults), "children": int(family.children), "supplied_days": int(family.supplied_days)})
	destination.deliveries = []
	for delivery: Dictionary in source.deliveries:
		destination.deliveries.append({"id": int(delivery.id), "offer": str(delivery.offer), "arrival_day": int(delivery.arrival_day)})
	destination.pending_income = {}
	for key in ["gross_income", "city_contribution", "net_income"]:
		destination.pending_income[key] = int(source.pending_income[key])
	destination.last_report = source.last_report.duplicate(true)
	for key: String in destination.last_report:
		if destination.last_report[key] is float:
			destination.last_report[key] = int(destination.last_report[key])
	for key: String in destination.last_report.produced:
		destination.last_report.produced[key] = int(destination.last_report.produced[key])
