extends SceneTree
const MODEL = preload("res://scripts/creative/build_settlement_state.gd")
var checks := 0
var failed := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error("[Settlement] " + label)


func _initialize() -> void:
	var town = MODEL.new()
	var pristine: Dictionary = town.snapshot()
	for request in [["unknown", 0], ["house", -1], ["house", 9]]:
		check(not town.try_build(request[0], request[1]), "invalid building rejected")
		check(town.snapshot() == pristine, "rejected action is atomic")
	check(town.try_build("house", 0), "first house purchased")
	check(
		town.player().resources == {"wood": 14, "stone": 9, "food": 12, "coins": 7},
		"actual house costs paid"
	)
	var with_house: Dictionary = town.snapshot()
	check(
		not town.try_build("farm", 0) and town.snapshot() == with_house,
		"occupied plot cannot duplicate purchase"
	)
	check(town.undo() and town.snapshot() == pristine, "undo returns exact resources and building")
	check(
		town.redo() and town.snapshot() == with_house, "redo pays once and restores exact building"
	)
	var detached: Dictionary = town.player()
	detached.resources.wood = 999
	check(town.player().resources.wood == 14, "public snapshot cannot alter economy")
	check(town.try_build("farm", 1), "farm purchased")
	check(town.status().level == 1, "first visible settlement goal fulfilled")
	var before_day: Dictionary = town.player()
	var result: Dictionary = town.next_day()
	check(result.advanced and result.day == 2, "explicit action advances one day")
	check(
		town.player().resources.food == before_day.resources.food + 5 - 2,
		"farm produces and citizens eat"
	)
	check(
		not town.undo() and not town.redo(), "finished days cannot replay production through undo"
	)
	check(not town.try_trade("food", 1, true), "trade requires actual market")
	var no_market: Dictionary = town.snapshot()
	check(
		not town.try_trade("wood", -1, true) and town.snapshot() == no_market,
		"negative trade cannot mint resources"
	)
	check(town.try_build("lumber", 2), "lumber workshop purchased")
	check(town.try_build("quarry", 3), "quarry purchased")
	for _day in range(4):
		town.next_day()
	check(town.try_build("market", 4), "market purchased from produced resources")
	var trade_start: Dictionary = town.player().resources
	check(town.try_trade("wood", 1, true), "sell two wood for one coin")
	check(town.try_trade("wood", 1, false), "buy one wood for one coin")
	check(
		(
			town.player().resources.wood == trade_start.wood - 1
			and town.player().resources.coins == trade_start.coins
		),
		"round-trip trading cannot create value"
	)
	var stored: Dictionary = town.snapshot()
	var restored = MODEL.restore(JSON.parse_string(JSON.stringify(stored)))
	check(
		restored != null and restored.snapshot() == stored,
		"JSON save reload preserves entire world"
	)
	check(not restored.undo(), "save reload cannot rewind already spent old transactions")
	# A normal child can spend all stone on houses. Waiting used to leave this
	# world permanently stuck after Undo was cleared. Recover through real rules.
	var recovery = MODEL.new()
	for plot in range(4):
		check(recovery.try_build("house", plot), "ordinary overbuilding is reachable")
	recovery.next_day()
	check(
		not recovery.undo() and recovery.player().resources.stone == 0,
		"cross-day overbuilding reproduces economic dead end"
	)
	var stuck: Dictionary = recovery.snapshot()
	check(
		not recovery.try_demolish(7) and recovery.snapshot() == stuck,
		"empty plot cannot mint demolition refunds"
	)
	check(
		not recovery.try_demolish(-1) and recovery.snapshot() == stuck,
		"invalid demolition remains atomic"
	)
	check(recovery.try_demolish(3), "full-cost recycling recovers from past-day mistake")
	check(
		recovery.player().resources.wood == 6 and recovery.player().resources.stone == 3,
		"recycling returns exact paid wood and stone"
	)
	var recycled: Dictionary = recovery.snapshot()
	check(
		recovery.undo() and recovery.snapshot() == stuck,
		"undo demolition restores building and removes refund together"
	)
	check(
		recovery.redo() and recovery.snapshot() == recycled,
		"redo demolition cannot double its refund"
	)
	check(recovery.try_build("lumber", 3), "recovered materials buy real production")
	for _day in range(2):
		recovery.next_day()
	check(recovery.try_build("farm", 4), "stuck project now gains actual food production")
	check(
		recovery.try_demolish(2) and recovery.try_build("quarry", 2),
		"same project restores stone production without reset"
	)
	var recover_reload = MODEL.restore(JSON.parse_string(JSON.stringify(recovery.snapshot())))
	check(
		recover_reload != null and recover_reload.snapshot() == recovery.snapshot(),
		"recovered project remains a valid version-one save"
	)
	var housed = MODEL.new()
	check(housed.try_build("house", 0), "occupied home established")
	var home: Dictionary = housed.snapshot()
	check(
		not housed.try_demolish(0) and housed.snapshot() == home,
		"recycling never relocates inhabitants without confirmation"
	)
	check(
		(
			housed.demolition_quote(0).affected_residents == 2
			and housed.demolition_quote(0).population_after == 2
		),
		"last home explains that the two founders need the starter camp"
	)
	check(
		(
			housed.try_demolish(0, true)
			and housed.player().population == 2
			and housed.player().buildings.is_empty()
		),
		"confirmed last-home removal preserves the founders"
	)
	check(housed.undo() and housed.snapshot() == home, "last-home relocation is fully reversible")
	var saturated: Dictionary = home.duplicate(true)
	saturated.player.resources.wood = MODEL.MAX_RESOURCE
	saturated.player.resources.stone = MODEL.MAX_RESOURCE
	saturated.player.resources.coins = MODEL.MAX_RESOURCE
	saturated.player.buildings.append({"id": "b2", "kind": "lumber", "plot": 1})
	saturated.player.next_id = 3
	var full = MODEL.restore(saturated)
	check(full != null and full.try_demolish(1), "full store does not lock all occupied plots")
	check(
		(
			full.player().resources.wood == MODEL.MAX_RESOURCE
			and MODEL.restore(full.snapshot()) != null
		),
		"refund cap preserves valid resource bounds"
	)
	# Expansion consumes materials permanently. It must not strand a town whose
	# only remaining capital is occupied housing after selling its workshops.
	var expansion = MODEL.new()
	for choice in [["house", 0], ["house", 1], ["lumber", 2], ["quarry", 3]]:
		check(
			expansion.try_build(choice[0], choice[1]),
			"legal expansion audit starts with real buildings"
		)
	for _day in range(10):
		expansion.next_day()
	check(expansion.try_build("market", 4), "audit market is purchased, not injected")
	for _trade in range(3):
		check(expansion.try_trade("wood", 5, true), "audit sells actual wood")
	check(
		expansion.try_trade("wood", 5, false) and expansion.try_trade("wood", 5, true),
		"audit wood exchange uses UI quantity"
	)
	for _trade in range(2):
		check(expansion.try_trade("stone", 5, true), "audit sells actual stone")
	check(
		expansion.try_trade("stone", 5, false) and expansion.try_trade("stone", 5, true),
		"audit stone exchange uses UI quantity"
	)
	for plot in [2, 3, 4]:
		check(expansion.try_demolish(plot), "audit recycles production legally")
	var vulnerable: Dictionary = expansion.snapshot()
	check(
		(
			expansion.player().population == 4
			and expansion.player().resources.wood == 15
			and expansion.player().resources.stone == 11
		),
		"exact independently found cross-day expansion trap reproduced"
	)
	check(
		(
			not expansion.status().can_expand
			and not expansion.expand()
			and expansion.snapshot() == vulnerable
		),
		"HUD and model reject irreversible expansion before sustainable supply"
	)
	check(
		expansion.try_build("lumber", 2) and expansion.try_build("quarry", 3),
		"blocked expansion keeps enough resources to rebuild"
	)
	for _day in range(2):
		expansion.next_day()
	check(
		expansion.status().can_expand and expansion.expand(),
		"same town expands after establishing production"
	)
	var expanded_stock: Dictionary = expansion.player().resources
	expansion.next_day()
	check(
		(
			expansion.player().resources.wood > expanded_stock.wood
			and expansion.player().resources.stone > expanded_stock.stone
		),
		"expanded town remains productive beyond cleared Undo"
	)
	# Independently found legal trap: food stockpiling followed by eight occupied
	# houses can fill all nine plots while consuming every building material.
	# Confirmation is essential: ordinary recycling must never silently evict.
	var crowded = MODEL.new()
	check(
		crowded.try_build("lumber", 0) and crowded.try_build("farm", 3),
		"housing audit starts from ordinary purchases"
	)
	crowded.next_day()
	check(crowded.try_build("quarry", 1), "housing audit earns its stone supply")
	for _day in range(6):
		crowded.next_day()
	check(crowded.try_build("market", 2), "housing audit funds its market")
	check(
		(
			crowded.try_trade("wood", 5, true)
			and crowded.try_trade("stone", 5, true)
			and crowded.try_trade("stone", 5, false)
		),
		"housing audit uses actual public trade quotes"
	)
	for plot in [0, 1, 2]:
		check(
			crowded.try_demolish(plot),
			"housing audit legally exchanges workshops for housing capital"
		)
	for _day in range(100):
		crowded.next_day()
	for plot in [0, 1, 2, 4, 5, 6, 7, 8]:
		check(
			crowded.try_build("house", plot), "housing audit buys every house from earned resources"
		)
	for _day in range(14):
		crowded.next_day()
	var crowded_save: Dictionary = crowded.snapshot()
	check(
		(
			crowded.player().population == 16
			and crowded.player().resources.wood == 0
			and crowded.player().resources.stone == 0
		),
		"exact full-housing dead end reached without injected state"
	)
	check(
		not crowded.try_demolish(8) and crowded.snapshot() == crowded_save,
		"unconfirmed relocation has no side effects"
	)
	var relocation: Dictionary = crowded.demolition_quote(8)
	check(
		(
			relocation.affected_residents == 2
			and relocation.population_after == 14
			and relocation.refund == MODEL.BUILDINGS.house.cost
		),
		"relocation quote explains actual residents and materials"
	)
	relocation.refund.wood = 99999
	check(
		crowded.demolition_quote(8).refund.wood == 4 and crowded.snapshot() == crowded_save,
		"preview cannot mutate the building price or world"
	)
	check(
		crowded.try_demolish(8, true) and crowded.player().population == 14,
		"explicitly confirmed relocation frees a real plot"
	)
	var relocated: Dictionary = crowded.snapshot()
	check(
		crowded.undo() and crowded.snapshot() == crowded_save,
		"undo brings residents and their home back together"
	)
	check(
		crowded.redo() and crowded.snapshot() == relocated,
		"redo cannot duplicate refund or remove residents twice"
	)
	var crowded_reload = MODEL.restore(JSON.parse_string(JSON.stringify(relocated)))
	check(
		crowded_reload != null and crowded_reload.snapshot() == relocated,
		"relocated population survives restart without migration"
	)
	check(
		crowded_reload.try_build("quarry", 8),
		"refunded home restores stone production on its freed plot"
	)
	check(
		crowded_reload.try_demolish(7, true) and crowded_reload.try_build("lumber", 7),
		"second chosen relocation restores wood supply"
	)
	var recovery_stock: Dictionary = crowded_reload.player().resources
	crowded_reload.next_day()
	check(
		(
			crowded_reload.player().resources.wood > recovery_stock.wood
			and crowded_reload.player().resources.stone > recovery_stock.stone
		),
		"formerly locked full town now produces both materials after Undo expires"
	)
	check(crowded_reload.demolition_quote(24).is_empty(), "unbuilt plot has no relocation quote")
	for mutation in [
		"negative", "fractional", "overlap", "unknown", "bad_region", "fake_winner", "oversized"
	]:
		var bad: Dictionary = stored.duplicate(true)
		match mutation:
			"negative":
				bad.player.resources.wood = -1
			"fractional":
				bad.player.resources.wood = 1.5
			"overlap":
				bad.player.buildings[1].plot = bad.player.buildings[0].plot
			"unknown":
				bad.player.buildings[0].kind = "free_coins"
			"bad_region":
				bad.player.region = 4
			"fake_winner":
				bad.winner = "player"
			"oversized":
				bad.day = 1000000
		check(MODEL.restore(bad) == null, "malformed save rejected: " + mutation)

	# Independently replay every visible AI action through the child's public
	# purchase/expansion API. Equal resulting towns prove identical prices,
	# production, food consumption and expansion rules over the full race.
	var race = MODEL.new("rival")
	var mirror = MODEL.new("settlement")
	var days := 0
	while race.winner.is_empty() and days < 90:
		var event: Dictionary = race.next_day()
		check(event.advanced, "rival day advances")
		for action: String in event.rival_actions:
			if action.begins_with("Erschließt "):
				check(mirror.expand(), "AI expansion is affordable by identical public rules")
			else:
				var kind := ""
				for candidate: String in MODEL.BUILDINGS:
					if action == "Baut " + str(MODEL.BUILDINGS[candidate].title):
						kind = candidate
				var used: Array[int] = []
				for building: Dictionary in mirror.player().buildings:
					used.append(int(building.plot))
				var plot := 0
				while plot in used:
					plot += 1
				check(
					not kind.is_empty() and mirror.try_build(kind, plot),
					"AI purchase has real cost and empty plot"
				)
		mirror.next_day()
		check(mirror.player() == race.rival(), "rival never gets hidden resources or growth")
		var saved: Dictionary = race.snapshot()
		var reload = MODEL.restore(JSON.parse_string(JSON.stringify(saved)))
		check(reload != null and reload.snapshot() == saved, "race resumes identically every day")
		race = reload
		days += 1
	check(race.winner == "rival" and days < 90, "AI reaches actual campaign victory")
	check(
		(
			mirror.status().complete
			and mirror.status().level == 3
			and mirror.player().population >= 10
		),
		"all three goals and regions are attainable by child's legal commands"
	)
	var finished: Dictionary = race.snapshot()
	check(
		not race.next_day().advanced and race.snapshot() == finished,
		"completed race does not keep changing"
	)
	check(not race.try_build("house", 24), "finished race rejects late purchases")
	check(
		not race.try_demolish(0) and race.snapshot() == finished,
		"race result cannot be undone by late recycling"
	)
	print(
		(
			"[Settlement] %s %d checks; mirrored complete AI campaign %d days"
			% ["PASS" if failed == 0 else "FAIL", checks, days]
		)
	)
	quit(0 if failed == 0 else 1)
