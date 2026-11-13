extends SceneTree
## Exercise the shipped living-village APIs, independent accounting identities,
## long legal progression, legacy migration and malformed-save boundaries.
const MODEL = preload("res://scripts/creative/build_settlement_state.gd")
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[VillageEconomy] " + message)


func build(model, kind: String) -> bool:
	return model.try_build(kind, model._free_plot(model.player()))


func reload_check(model, message: String):
	var before: Dictionary = model.snapshot()
	var restored = MODEL.restore(JSON.parse_string(JSON.stringify(before)))
	check(restored != null and restored.snapshot() == before, message)
	return restored if restored != null else model


func _initialize() -> void:
	var city = MODEL.new("settlement", true)
	check(
		city.living_village and city.snapshot().version == 2,
		"production opt-in owns a version-two economy"
	)
	check(
		city.player().plots == 9 and MODEL.PLOTS.back() == 1089,
		"world expands from nine to 1089 plots"
	)
	# Reproduce the zero-coin campaign soft-lock on a fresh village.
	var broke = MODEL.new("settlement", true)
	broke._player.resources.coins = 0
	check(
		broke.building_cost("market") == {"wood": 6, "stone": 4},
		"living market has an exact coin-free purchase quote"
	)
	check(build(broke, "market"), "a child with zero coins can open the market")
	check(
		broke.player().resources.coins == 0
		and not broke.demolition_quote(0).refund.has("coins"),
		"zero-coin market neither spends nor refunds imaginary coins"
	)
	broke = reload_check(broke, "market cost receipt survives a saved village")
	check(
		broke.try_demolish(0) and broke.player().resources.coins == 0,
		"demolishing the zero-coin market cannot mint coins"
	)
	# Marketplaces bought before the version-two upgrade still refund the coins paid.
	var old_market = MODEL.new("settlement")
	check(build(old_market, "market"), "historical market uses its original two-coin price")
	old_market.enable_living_village()
	check(
		old_market.demolition_quote(0).refund.get("coins", 0) == 2,
		"upgraded older market retains its actual historical price"
	)
	check(
		old_market.try_demolish(0) and old_market.player().resources.coins == 8,
		"upgraded old market refunds the two previously spent coins"
	)
	var untouched: Dictionary = city.snapshot()
	check(
		not city.try_build("house", 9) and city.snapshot() == untouched,
		"unearned region cannot be built through API"
	)
	check(
		not city.order_delivery("fake") and city.snapshot() == untouched, "unknown cargo is atomic"
	)
	check(
		not city.fund_project("bridge") and city.snapshot() == untouched,
		"empty city purse cannot fund infrastructure"
	)
	check(
		build(city, "house") and city.player().population == 3,
		"a purchased house immediately welcomes one resident"
	)
	var house: Dictionary = city.snapshot()
	check(
		city.undo() and city.snapshot() == untouched,
		"house undo removes resident and cost together"
	)
	check(city.redo() and city.snapshot() == house, "house redo cannot duplicate its resident")
	for kind in ["farm", "lumber", "quarry", "well"]:
		check(build(city, kind), "ordinary starting supplies build " + kind)
	for i in range(3):
		var previous: Dictionary = city.player()
		var event: Dictionary = city.next_day()
		check(
			event.advanced and event.player.food_needed == previous.population,
			"daily report uses actual resident food need"
		)
		check(
			(
				city.player().resources.food
				== int(previous.resources.food) + 5 - int(previous.population)
			),
			"carrot production and meals conserve actual stock"
		)
	check(
		city.player().population == 4 and city.player().households[0].adults == 2,
		"partner arrives after three supplied family days"
	)
	check(not city.undo(), "completed day cannot replay production through undo")
	check(build(city, "market"), "market purchased using earned materials")
	var coins_before := int(city.player().resources.coins)
	for i in range(5):
		city.next_day()
	check(
		city.player().income_total == 10 and city.player().tax_total == 2,
		"ten earned coins contribute exactly two city coins"
	)
	check(
		city.player().resources.coins == coins_before + 8 and city.player().treasury == 2,
		"private purse plus city purse conserve gross income"
	)
	check(city.player().tax_remainder == 0, "five-part income remainder closes exactly")
	var before_trade: Dictionary = city.snapshot()
	check(city.try_trade("wood", 1, true), "small sale uses the public market")
	check(
		city.player().tax_remainder == 1 and city.player().treasury == 2,
		"one coin keeps its tax fraction instead of rounding it away"
	)
	check(
		city.undo() and city.snapshot() == before_trade,
		"undo restores tax remainder, treasury and market stock together"
	)
	check(city.redo(), "redo restores one genuine transaction")
	for i in range(4):
		check(city.try_trade("wood", 1, true), "small sale remains funded by actual wood")
	check(
		city.player().income_total == 15 and city.player().tax_total == 3,
		"five tiny sales pay same twenty-percent contribution as one five-coin sale"
	)
	var report: Dictionary = city.next_day().player
	check(
		report.gross_income == 7 and report.city_contribution == 1 and report.net_income == 6,
		"day report includes actual market sales and daily earnings once"
	)
	city = reload_check(city, "fractional tax remainder survives real JSON roundtrip")
	for i in range(13):
		city.next_day()
	check(city.player().treasury >= 8, "city contribution funds an affordable real project")
	var before_project: Dictionary = city.snapshot()
	var private_purse := int(city.player().resources.coins)
	check(city.fund_project("playground"), "playground spends city money")
	check(
		(
			city.player().resources.coins == private_purse
			and city.player().treasury == int(before_project.player.treasury) - 8
		),
		"public investment charges only the city purse"
	)
	var after_project: Dictionary = city.snapshot()
	check(
		not city.fund_project("playground") and city.snapshot() == after_project,
		"public project cannot be paid twice"
	)
	check(
		city.undo() and city.snapshot() == before_project,
		"public project undo restores exact public funds"
	)
	check(
		city.redo() and city.snapshot() == after_project,
		"public project redo cannot mint public funds"
	)
	check(
		city.economy_status().happiness == 75, "funded playground has a measurable community effect"
	)
	check(city.expand(), "sustainable town opens a genuine second region")
	check(city.player().plots == 16, "first expansion preserves old plot progression")
	check(
		build(city, "grain") and build(city, "bakery"), "field and bakery are real paid facilities"
	)
	var before_bread: Dictionary = city.player()
	var baked: Dictionary = city.next_day().player
	check(
		city.player().crops.grain == int(before_bread.crops.grain) + 4 - 3,
		"bread production consumes exactly three harvested grain"
	)
	check(baked.produced.food == 10, "river farm and bakery produce six carrots plus four bread")
	check(
		city.player().crops.carrots + city.player().crops.bread == city.player().resources.food,
		"food count never double-counts carrots and bread"
	)
	check(build(city, "school"), "learning house purchased from real city income")
	city.next_day()
	check(
		city.economy_status().children >= 1 and city.player().population >= 5,
		"well-fed family receives a child with learning infrastructure"
	)
	while (city.day - 1) % 3 != 0:
		city.next_day()
	check(city.trader_offer().available, "merchant visits on the announced day")
	var before_order: Dictionary = city.snapshot()
	check(city.order_delivery("carrots"), "child can order an affordable visible carrot shipment")
	check(
		(
			city.player().resources.food == before_order.player.resources.food
			and city.player().resources.coins == int(before_order.player.resources.coins) - 4
		),
		"order pays now and does not instantly invent delivered food"
	)
	var ordered: Dictionary = city.snapshot()
	check(
		city.undo() and city.snapshot() == before_order,
		"cancel-by-undo removes both cargo and payment"
	)
	check(city.redo() and city.snapshot() == ordered, "delivery redo restores one cargo only")
	city = reload_check(city, "pending delivery and family age persist")
	var delivery_report: Dictionary = city.next_day().player
	check(
		(
			delivery_report.deliveries_received == ["Karottenkiste"]
			and city.player().deliveries.is_empty()
		),
		"paid wagon delivers exactly once on the next day"
	)
	check(
		not city.order_delivery("carrots"), "merchant absence cannot be bypassed through callback"
	)
	city = reload_check(city, "received cargo stays received after restart")
	check(city.next_day().player.deliveries_received.is_empty(), "restart never replays old cargo")
	var protected_house: Dictionary = city.snapshot()
	check(
		not city.try_demolish(0) and city.snapshot() == protected_house,
		"living families cannot silently lose their only home"
	)
	check(
		city.try_demolish(0, true) and city.player().population == 2,
		"explicit relocation preserves both founders"
	)
	check(city.player().households.is_empty(), "removed house cannot keep a ghost family")
	check(
		city.undo() and city.snapshot() == protected_house,
		"relocation undo restores family children and ages"
	)
	city = reload_check(city, "restored family remains canonical after JSON serialization")
	_test_migration()
	_test_invalid(city.snapshot())
	_test_ai()
	_test_long_campaign()
	print("[VillageEconomy] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _test_migration() -> void:
	var legacy = MODEL.new()
	for kind in ["house", "farm", "lumber", "quarry"]:
		check(build(legacy, kind), "migration starts with a legal old building")
	for i in range(8):
		legacy.next_day()
	var old: Dictionary = legacy.snapshot()
	var loaded = MODEL.restore(JSON.parse_string(JSON.stringify(old)))
	check(
		loaded != null and not loaded.living_village,
		"legacy save reads through its exact old schema"
	)
	loaded.enable_living_village()
	check(
		(
			loaded.player().resources == old.player.resources
			and loaded.player().population == old.player.population
			and loaded.player().buildings == old.player.buildings
		),
		"migration retains every old resource, resident and building"
	)
	check(
		loaded.day == legacy.day and loaded.player().treasury == 0,
		"migration preserves day and does not invent historical tax"
	)
	var migrated: Dictionary = loaded.snapshot()
	loaded.enable_living_village()
	check(loaded.snapshot() == migrated, "migration is idempotent")
	loaded = reload_check(loaded, "migrated village saves in the canonical new format")
	check(
		build(loaded, "well") and loaded.next_day().advanced,
		"migrated town participates in the same new production rules"
	)


func _test_invalid(valid: Dictionary) -> void:
	for mutation in [
		"tax",
		"remainder",
		"treasury",
		"family",
		"age",
		"crop",
		"delivery",
		"chapter",
		"project",
		"report",
		"fraction",
		"overlap",
		"region",
		"resource",
		"day",
		"pending"
	]:
		var data: Dictionary = valid.duplicate(true)
		match mutation:
			"tax":
				data.player.tax_total += 1
			"remainder":
				data.player.tax_remainder = 5
			"treasury":
				data.player.treasury += 1
			"family":
				data.player.households.append(data.player.households[0].duplicate(true))
			"age":
				data.player.households[0].supplied_days = -1
			"crop":
				data.player.crops.bread += 1
			"delivery":
				data.player.deliveries.append({"id": 9999, "offer": "carrots", "arrival_day": 1})
			"chapter":
				data.player.campaign_chapter = 13
			"project":
				data.player.city_projects.free_castle = true
			"report":
				data.player.last_report.produced.wood = -1
			"fraction":
				data.player.resources.coins = 0.5
			"overlap":
				data.player.buildings[1].plot = data.player.buildings[0].plot
			"region":
				data.player.region = 12
			"resource":
				data.player.resources.food = -2
			"day":
				data.day = 9999999
			"pending":
				data.player.pending_income.net_income += 1
		check(MODEL.restore(data) == null, "malformed new save is rejected: " + mutation)


func _test_ai() -> void:
	var race = MODEL.new("rival", true)
	var mirror = MODEL.new("settlement", true)
	var turns := 0
	while race.winner.is_empty() and turns < 90:
		var event: Dictionary = race.next_day()
		for action: String in event.rival_actions:
			if action.begins_with("Erschließt "):
				check(mirror.expand(), "new rival expansion is affordable by the child")
			else:
				var matched := false
				for kind: String in MODEL.BUILDINGS:
					if action == "Baut " + str(MODEL.BUILDINGS[kind].title):
						matched = build(mirror, kind)
				check(matched, "new rival construction is an actual public purchase")
		mirror.next_day()
		check(
			mirror.player() == race.rival(),
			"AI has exactly the child's food, families, contribution and income"
		)
		race = reload_check(race, "new rival resumes identically after a saved turn")
		turns += 1
	check(race.winner == "rival" and turns < 90, "fair new rival can complete the competitive town")
	var finished: Dictionary = race.snapshot()
	check(
		(
			not race.next_day().advanced
			and not race.order_delivery("carrots")
			and not race.fund_project("bridge")
			and race.snapshot() == finished
		),
		"finished race locks all new and old economy mutations"
	)
	print("[VillageEconomy] mirrored new AI victory turns=", turns)


func _test_long_campaign() -> void:
	var city = MODEL.new("settlement", true)
	var turns := 0
	while not city.campaign_status().complete and turns < 350:
		for action in range(6):
			var town: Dictionary = city.player()
			var priorities: Array[String] = []
			if city._count(town, "house") == 0:
				priorities.append("house")
			if city._count(town, "farm") == 0:
				priorities.append("farm")
			if city._count(town, "lumber") == 0:
				priorities.append("lumber")
			if city._count(town, "quarry") == 0:
				priorities.append("quarry")
			if (
				city._count(town, "well") == 0
				or city.economy_status().water_capacity < int(town.population) + 8
			):
				priorities.append("well")
			if city._count(town, "market") == 0:
				priorities.append("market")
			if int(town.population) < 4:
				priorities.append("house")
			if city.status().can_expand:
				check(
					city.expand(),
					"campaign expansion follows actual sustainable resource requirements"
				)
				continue
			if (
				city._count(town, "farm") * 6 + city._count(town, "bakery") * 4
				< int(town.population) + 8
			):
				priorities.append("farm")
			if city._count(town, "road") < 1:
				priorities.append("road")
			if city._count(town, "school") < 1:
				priorities.append("school")
			if city._count(town, "grain") < 1:
				priorities.append("grain")
			if city._count(town, "bakery") < 1:
				priorities.append("bakery")
			if city._count(town, "market") < 4:
				priorities.append("market")
			if city._count(town, "lumber") < 3:
				priorities.append("lumber")
			if city._count(town, "quarry") < 3:
				priorities.append("quarry")
			if city._count(town, "clinic") < 2:
				priorities.append("clinic")
			if city._count(town, "school") < 2:
				priorities.append("school")
			if city._count(town, "house") < 24:
				priorities.append("house")
			if city._count(town, "road") < 8:
				priorities.append("road")
			var acted := false
			for kind in priorities:
				if build(city, kind):
					acted = true
					break
			if not acted:
				break
		if city._count(city.player(), "market") > 0 and int(city.player().trade_count) == 0:
			city.try_trade("wood", 1, true)
		for project: Dictionary in city.public_projects():
			if not project.completed and int(city.player().treasury) >= int(project.cost):
				check(city.fund_project(str(project.id)), "campaign finances a real public project")
		var before: Dictionary = city.player()
		var report: Dictionary = city.next_day().player
		check(
			report.gross_income == int(report.net_income) + int(report.city_contribution),
			"long campaign preserves daily two-purse accounting"
		)
		check(
			city.player().tax_total == int(city.player().income_total) / 5,
			"long campaign preserves aggregate twenty-percent contribution"
		)
		check(
			city.player().crops.carrots + city.player().crops.bread == city.player().resources.food,
			"long campaign preserves food inventory identity"
		)
		if turns % 13 == 0:
			city = reload_check(city, "large campaign state survives a real save/reload")
		turns += 1
	check(city.campaign_status().complete, "all twelve campaign chapters are legally reachable")
	check(
		city.player().plots == 1089 and city.player().population >= 80,
		"largest playable region and growing town are actually reached"
	)
	check(
		city.economy_status().children > 0 and city.player().city_projects.size() == 4,
		"completed city contains families and all four paid public services"
	)
	check(city.next_day().advanced, "long campaign completion preserves ongoing free city play")
	city = reload_check(city, "complete large city remains playable after restart")
	print(
		"[VillageEconomy] legal campaign turns=",
		turns,
		" plots=",
		city.player().plots,
		" residents=",
		city.player().population,
		" chapter=",
		city.campaign_status().chapter
	)
