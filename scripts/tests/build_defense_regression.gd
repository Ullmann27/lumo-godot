extends SceneTree
## Village defence: counter cycle, wave AI, stepwise difficulty, reference
## defence wins every level, occupation without destruction, recapture,
## tutorial order and the separate, backwards-compatible defence save.
const SIM = preload("res://scripts/creative/build_defense_sim.gd")
const DEFENSE = preload("res://scripts/creative/build_defense_state.gd")
const MODEL = preload("res://scripts/creative/build_settlement_state.gd")
const BUILDINGS := {"h1": "north", "h2": "east", "h3": "south", "h4": "west", "h5": "north", "h6": "east"}
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[BuildDefense] " + message)


func _initialize() -> void:
	_counters()
	_difficulty()
	_wave_ai()
	_reference_defense()
	_occupation()
	_tutorial_and_save()
	_village_spending()
	if failures.is_empty():
		print("[BuildDefense] PASS checks=%d" % checks)
		quit(0)
	else:
		print("[BuildDefense] FAIL %d of %d" % [failures.size(), checks])
		quit(1)


func _counters() -> void:
	for role in SIM.ROLES:
		var prey: String = SIM.BEATS[role]
		check(SIM.multiplier(role, prey) > 1.0, role + " beats " + prey)
		check(SIM.multiplier(prey, role) < 1.0, prey + " is weak against " + role)
		check(SIM.counter_of(prey) == role, "counter_of finds " + role)
	var cycle := {}
	for role in SIM.ROLES:
		cycle[SIM.BEATS[role]] = true
	check(cycle.size() == SIM.ROLES.size(), "Every role is beaten by exactly one other role")
	# Equal numbers: the counter role wins a straight fight.
	for role in SIM.ROLES:
		var lane := {"wall": 0, "towers": 0, "gate": false, "squad": {"speer": 0, "bogen": 0, "ritter": 0, "reiter": 0}}
		lane.squad[SIM.counter_of(role)] = 6
		var attackers := {"speer": 0, "bogen": 0, "ritter": 0, "reiter": 0}
		attackers[role] = 6
		check(not SIM.resolve_lane(lane, attackers, 1.0, false).breached,
			"Six %s hold against six %s" % [SIM.counter_of(role), role])


func _difficulty() -> void:
	var previous := 0
	for level in range(1, SIM.MAX_LEVEL + 1):
		var budget := SIM.wave_budget(level)
		check(budget > previous, "Wave budget rises strictly at level %d" % level)
		previous = budget
		check(SIM.enemy_toughness(level) >= SIM.enemy_toughness(maxi(1, level - 1)), "Toughness never drops")
	check(SIM.level_for(1, 0) == 1 and SIM.level_for(5, 3) == 8, "Level = chapter + defended waves")
	check(SIM.level_for(12, 999) == SIM.MAX_LEVEL, "Level is capped at the hardest step")
	# No rubber band: the wave size depends on the level only, never on the lead.
	for level in [1, 6, 14]:
		var weak := SIM.plan_wave(level, SIM.empty_defense())
		var strong := SIM.plan_wave(level, SIM.reference_defense(level))
		check(weak.budget == strong.budget and is_equal_approx(weak.toughness, strong.toughness),
			"Level %d wave strength is independent of the child's defence" % level)


func _wave_ai() -> void:
	for level in [1, 4, 9, 16]:
		var defense := SIM.reference_defense(level)
		defense.lanes.east.wall = 0
		defense.lanes.east.towers = 0
		defense.lanes.east.gate = false
		var wave := SIM.plan_wave(level, defense)
		check(wave.main_lane == "east", "Level %d hares attack the weakest lane" % level)
		var main_total := 0
		for role in SIM.ROLES:
			main_total += int(wave.groups.east[role])
		check(main_total * 2 >= wave.budget, "Most hares go to the weak lane at level %d" % level)
		var total := 0
		for lane in wave.groups:
			for role in SIM.ROLES:
				total += int(wave.groups[lane][role])
		check(total == wave.budget, "Wave uses exactly its budget at level %d" % level)
	var spears := SIM.empty_defense()
	for lane in SIM.LANES:
		spears.lanes[lane].squad.speer = 10
	var countered := SIM.plan_wave(4, spears)
	check(int(countered.groups[countered.main_lane].ritter) > 0,
		"From level 3 the hares bring knights against a spear defence")
	check(SIM.plan_wave(7, SIM.empty_defense()).groups.size() == 3, "Later waves split over three lanes")


func _reference_defense() -> void:
	for level in range(1, SIM.MAX_LEVEL + 1):
		var defense := SIM.reference_defense(level)
		var result := SIM.resolve_wave(defense, SIM.plan_wave(level, defense), BUILDINGS)
		check(result.won and result.captured.is_empty(), "Reference defence beats level %d" % level)
	# A progressing village: each defended wave makes the next one harder.
	var state = DEFENSE.new()
	var day := DEFENSE.FIRST_WAVE_DAY
	var last_budget := 0
	for wave_index in range(8):
		state.defense = SIM.reference_defense(state.level(3))
		var forecast: Dictionary = state.forecast(3)
		check(forecast.budget > last_budget, "Wave %d is harder than the last one" % wave_index)
		last_budget = forecast.budget
		var result: Dictionary = state.run_wave(day, 3, BUILDINGS)
		check(result.won, "Solid defence wins wave %d" % wave_index)
		check(state.next_wave_day == day + DEFENSE.WAVE_INTERVAL, "Next wave is announced")
		day = state.next_wave_day
	check(state.waves_won == 8 and state.level(3) == 11, "Defended waves raise the step")


func _occupation() -> void:
	var state = DEFENSE.new()
	var buildings := BUILDINGS.duplicate()
	var result: Dictionary = state.run_wave(4, 1, buildings)
	check(not result.won and not state.captured.is_empty(), "An undefended village gets occupied")
	check(buildings == BUILDINGS, "Occupation never removes a building")
	check(state.waves_won == 0 and state.level(1) == 1, "A lost wave does not raise the difficulty")
	var key: String = state.captured.keys()[0]
	check(BUILDINGS.has(key), "Only real buildings can be occupied")
	var lane: String = BUILDINGS[key]
	var weak := state.recapture(key, lane, 1)
	check(not weak.freed and state.is_captured(key), "Without guards the hares stay")
	state.train(lane, "speer", 6)
	state.train(lane, "ritter", 6)
	var strong := state.recapture(key, lane, 1)
	check(strong.freed and not state.is_captured(key), "A squad chases the hares out")
	check(buildings == BUILDINGS, "Recapture keeps every building")
	check(state.move_squad(lane, "west", "speer", 1) == "" and int(state.defense.lanes.west.squad.speer) == 1,
		"Group command moves guards to another lane")
	check(state.move_squad("west", lane, "speer", 5) != "", "Cannot move more guards than exist")


func _tutorial_and_save() -> void:
	var state = DEFENSE.new()
	check(state.tutorial_active() and state.tutorial_current().id == "build_house", "Tutorial starts at step one")
	check(not state.tutorial_event("wall"), "Steps cannot be skipped by doing a later one")
	for id in ["build_house", "gather", "wall", "tower", "train"]:
		check(state.tutorial_event(id), "Tutorial advances on " + id)
	check(state.tutorial_current().id == "defend", "Last step is the first wave")
	state.build("north", "wall")
	state.build("north", "tower")
	state.train("north", "speer", 3)
	var roundtrip = DEFENSE.restore(JSON.parse_string(JSON.stringify(state.to_data())))
	check(roundtrip != null and roundtrip.to_data() == state.to_data(), "Defence save survives JSON")
	check(roundtrip != null and roundtrip.tutorial_step == 5, "Tutorial progress is saved")
	var skipped = DEFENSE.new()
	skipped.skip_tutorial()
	var skipped_back = DEFENSE.restore(JSON.parse_string(JSON.stringify(skipped.to_data())))
	check(skipped_back != null and not skipped_back.tutorial_active(), "Skipping is saved")
	var broken: Dictionary = state.to_data()
	broken.defense.lanes.north.wall = 9
	check(DEFENSE.restore(broken) == null, "Impossible wall height is rejected")
	var broken_tutorial: Dictionary = state.to_data()
	broken_tutorial.tutorial.step = 99
	check(DEFENSE.restore(broken_tutorial) == null, "Impossible tutorial step is rejected")
	check(DEFENSE.restore({}) == null and DEFENSE.restore("x") == null, "Garbage is rejected")
	check(DEFENSE.path_for("user://lumo_village_a_1.json") == "user://lumo_village_a_1_defense.json",
		"Defence lives in its own file next to the village save")
	check(state.build("north", "gate") == "" and state.build("south", "gate") != "",
		"A gate needs a wall first")


func _village_spending() -> void:
	var city = MODEL.new("settlement", true)
	check(city.try_build("house", city._free_plot(city.player())), "Fixture builds a house")
	check(bool(city.status().can_undo),
		"Fixture has undo history")
	var before := int(city.player().resources.wood)
	check(city.spend_committed({"wood": 1}), "Defence can spend wood")
	check(int(city.player().resources.wood) == before - 1, "Wood is paid")
	check(not bool(city.status().can_undo), "Defence spending cannot be undone into a refund")
	check(not city.spend_committed({"food": 1}), "Food is never spent by defence (crop identity stays)")
	check(not city.spend_committed({"coins": 99999}), "Unaffordable spending is refused")
	var restored = MODEL.restore(JSON.parse_string(JSON.stringify(city.snapshot())))
	check(restored != null, "Village save stays valid after defence spending")
	var classic = MODEL.new("settlement", false)
	check(not classic.spend_committed({"wood": 1}), "Classic Siedlung saves are untouched")
	var cost := SIM.squad_cost({"speer": 2, "bogen": 0, "ritter": 1, "reiter": 0})
	check(int(cost.get("wood", 0)) == 4 and int(cost.get("stone", 0)) == 3 and not cost.has("food"),
		"Squad cost adds up per role without food")
