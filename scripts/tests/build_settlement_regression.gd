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
	check(town.player().resources == {"wood": 14, "stone": 9, "food": 12, "coins": 7}, "actual house costs paid")
	var with_house: Dictionary = town.snapshot()
	check(not town.try_build("farm", 0) and town.snapshot() == with_house, "occupied plot cannot duplicate purchase")
	check(town.undo() and town.snapshot() == pristine, "undo returns exact resources and building")
	check(town.redo() and town.snapshot() == with_house, "redo pays once and restores exact building")
	var detached: Dictionary = town.player()
	detached.resources.wood = 999
	check(town.player().resources.wood == 14, "public snapshot cannot alter economy")
	check(town.try_build("farm", 1), "farm purchased")
	check(town.status().level == 1, "first visible settlement goal fulfilled")
	var before_day: Dictionary = town.player()
	var result: Dictionary = town.next_day()
	check(result.advanced and result.day == 2, "explicit action advances one day")
	check(town.player().resources.food == before_day.resources.food + 5 - 2, "farm produces and citizens eat")
	check(not town.undo() and not town.redo(), "finished days cannot replay production through undo")
	check(not town.try_trade("food", 1, true), "trade requires actual market")
	var no_market: Dictionary = town.snapshot()
	check(not town.try_trade("wood", -1, true) and town.snapshot() == no_market, "negative trade cannot mint resources")
	check(town.try_build("lumber", 2), "lumber workshop purchased")
	check(town.try_build("quarry", 3), "quarry purchased")
	for _day in range(4): town.next_day()
	check(town.try_build("market", 4), "market purchased from produced resources")
	var trade_start: Dictionary = town.player().resources
	check(town.try_trade("wood", 1, true), "sell two wood for one coin")
	check(town.try_trade("wood", 1, false), "buy one wood for one coin")
	check(town.player().resources.wood == trade_start.wood - 1 and town.player().resources.coins == trade_start.coins,
		"round-trip trading cannot create value")
	var stored: Dictionary = town.snapshot()
	var restored = MODEL.restore(JSON.parse_string(JSON.stringify(stored)))
	check(restored != null and restored.snapshot() == stored, "JSON save reload preserves entire world")
	check(not restored.undo(), "save reload cannot rewind already spent old transactions")
	# A normal child can spend all stone on houses. Waiting used to leave this
	# world permanently stuck after Undo was cleared. Recover through real rules.
	var recovery = MODEL.new()
	for plot in range(4):
		check(recovery.try_build("house", plot), "ordinary overbuilding is reachable")
	recovery.next_day()
	check(not recovery.undo() and recovery.player().resources.stone == 0, "cross-day overbuilding reproduces economic dead end")
	var stuck: Dictionary = recovery.snapshot()
	check(not recovery.try_demolish(7) and recovery.snapshot() == stuck, "empty plot cannot mint demolition refunds")
	check(not recovery.try_demolish(-1) and recovery.snapshot() == stuck, "invalid demolition remains atomic")
	check(recovery.try_demolish(3), "full-cost recycling recovers from past-day mistake")
	check(recovery.player().resources.wood == 6 and recovery.player().resources.stone == 3, "recycling returns exact paid wood and stone")
	var recycled: Dictionary = recovery.snapshot()
	check(recovery.undo() and recovery.snapshot() == stuck, "undo demolition restores building and removes refund together")
	check(recovery.redo() and recovery.snapshot() == recycled, "redo demolition cannot double its refund")
	check(recovery.try_build("lumber", 3), "recovered materials buy real production")
	for _day in range(2): recovery.next_day()
	check(recovery.try_build("farm", 4), "stuck project now gains actual food production")
	check(recovery.try_demolish(2) and recovery.try_build("quarry", 2), "same project restores stone production without reset")
	var recover_reload = MODEL.restore(JSON.parse_string(JSON.stringify(recovery.snapshot())))
	check(recover_reload != null and recover_reload.snapshot() == recovery.snapshot(), "recovered project remains a valid version-one save")
	var housed = MODEL.new()
	check(housed.try_build("house", 0), "occupied home established")
	var home: Dictionary = housed.snapshot()
	check(not housed.try_demolish(0) and housed.snapshot() == home, "recycling never evicts inhabitants")
	var saturated: Dictionary = home.duplicate(true)
	saturated.player.resources.wood = MODEL.MAX_RESOURCE
	saturated.player.resources.stone = MODEL.MAX_RESOURCE
	saturated.player.resources.coins = MODEL.MAX_RESOURCE
	saturated.player.buildings.append({"id": "b2", "kind": "lumber", "plot": 1})
	saturated.player.next_id = 3
	var full = MODEL.restore(saturated)
	check(full != null and full.try_demolish(1), "full store does not lock all occupied plots")
	check(full.player().resources.wood == MODEL.MAX_RESOURCE and MODEL.restore(full.snapshot()) != null, "refund cap preserves valid resource bounds")
	for mutation in ["negative", "fractional", "overlap", "unknown", "bad_region", "fake_winner", "oversized"]:
		var bad: Dictionary = stored.duplicate(true)
		match mutation:
			"negative": bad.player.resources.wood = -1
			"fractional": bad.player.resources.wood = 1.5
			"overlap": bad.player.buildings[1].plot = bad.player.buildings[0].plot
			"unknown": bad.player.buildings[0].kind = "free_coins"
			"bad_region": bad.player.region = 4
			"fake_winner": bad.winner = "player"
			"oversized": bad.day = 1000000
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
					if action == "Baut " + str(MODEL.BUILDINGS[candidate].title): kind = candidate
				var used: Array[int] = []
				for building: Dictionary in mirror.player().buildings: used.append(int(building.plot))
				var plot := 0
				while plot in used: plot += 1
				check(not kind.is_empty() and mirror.try_build(kind, plot), "AI purchase has real cost and empty plot")
		mirror.next_day()
		check(mirror.player() == race.rival(), "rival never gets hidden resources or growth")
		var saved: Dictionary = race.snapshot()
		var reload = MODEL.restore(JSON.parse_string(JSON.stringify(saved)))
		check(reload != null and reload.snapshot() == saved, "race resumes identically every day")
		race = reload
		days += 1
	check(race.winner == "rival" and days < 90, "AI reaches actual campaign victory")
	check(mirror.status().complete and mirror.status().level == 3 and mirror.player().population >= 10,
		"all three goals and regions are attainable by child's legal commands")
	var finished: Dictionary = race.snapshot()
	check(not race.next_day().advanced and race.snapshot() == finished, "completed race does not keep changing")
	check(not race.try_build("house", 24), "finished race rejects late purchases")
	check(not race.try_demolish(0) and race.snapshot() == finished, "race result cannot be undone by late recycling")
	print("[Settlement] %s %d checks; mirrored complete AI campaign %d days" % ["PASS" if failed == 0 else "FAIL", checks, days])
	quit(0 if failed == 0 else 1)
