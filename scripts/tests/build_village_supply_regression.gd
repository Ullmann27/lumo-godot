extends SceneTree
## Teil 4–6 (Welt, Versorgung, Wachen) – reine Regeln, headless:
##  1. Versorgungsrechnung (Heinz' Tabelle) mit Häusern, Brunnen, Bauplätzen
##  2. Flächenmessung der echten Karte (bebaubarer Anteil je Ring)
##  3. Alter Spielstand lädt mit gleichen Grundstücks- und Gebäude-IDs
##  4. 30-Tage-Läufe für 40 / 400 / 4.000 Menschen mit ausgefallener Ernte
##  5. 1.000 Wachen: speichern, laden, umgruppieren, Tageswechsel (Zeit, Größe)
##  6. Felder zusammenziehen (ein Zug, ein Rückgängig-Schritt)
##  7. Nachbarstädte über 81 Plätze, Baustellen, Interessen, eigene Gebiete
## Tabellen erscheinen als Zeilen „[Tabelle] …“ (Container-Messung, kein Handy).
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const ECONOMY = preload("res://scripts/creative/build_settlement_economy.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const SUPPLY = preload("res://scripts/creative/build_village_supply.gd")
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const FIELDS = preload("res://scripts/creative/build_village_fields.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const OLD_BLOCKED := "res://tools/lumo_village_art/old_blocked_player_1089.json"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageSupply] " + message)


func _table(text: String) -> void:
	print("[Tabelle] " + text)


func _run() -> void:
	_calculation()
	_area()
	_old_save()
	_thirty_days()
	_thousand_guards()
	_fields()
	_neighbors()
	if failures.is_empty():
		print("[VillageSupply] PASS checks=%d" % checks)
		quit(0)
	else:
		print("[VillageSupply] FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
		quit(1)


# 1 ---------------------------------------------------------------- Rechnung
func _calculation() -> void:
	var expected := {40: [10, 6], 400: [96, 60], 4000: [960, 600]}
	for people in [40, 400, 4000]:
		var guards: int = people / 4
		var civil: int = people - guards
		for column in range(2):
			var daily: int = [5, 8][column]
			var got := SUPPLY.farms_needed(civil, guards, daily)
			_check(got == int(expected[people][column]), "Höfe für %d+%d bei %d: %d" % [civil, guards, daily, got])
		for daily in [5, 6, 8]:
			var plan := SUPPLY.plan(civil, guards, daily, daily == 8)
			_table("Rechnung | %d Zivil + %d Wachen | %d Nahrung/Hof | Höfe %d | Häuser %d | Brunnen %d | Grundplätze %d | +25 %% = %d Zellen | Hoffläche %.0f m²" % [
				civil, guards, daily, int(plan.farms), int(plan.houses), int(plan.wells), int(plan.base_cells),
				int(plan.cells), float(plan.farm_area_m2)])
	var big := SUPPLY.plan(3000, 1000, 8, true)
	_check(int(big.houses) == 1000, "4.000 Menschen brauchen 1.000 Wohnhäuser (2 + 4 je Haus)")
	_check(int(big.wells) == 332, "Mit Bewässerung 332 Brunnen (4 + 12 je Brunnen + 12)")
	_check(int(big.base_cells) == 1932, "600 + 1.000 + 332 = 1.932 Grundplätze")
	_check(int(big.cells) == 2415, "Entwurfswert 2.415 Zellen (+25 %)")
	_check(is_equal_approx(float(big.farm_area_m2), 16854.0), "600 Hofzellen = 16.854 m² Rasterfläche")
	_check(SUPPLY.square_side_for(2415, 0.59) == 64, "64 × 64 reicht ab 59 % bebaubar")
	_check(SUPPLY.square_side_for(2415, 0.58) > 64, "Bei 58 % reicht 64 × 64 nicht")
	# Die echten Regeln: 5 nur in Region 0 (9 Plätze), ab Region 1 sind es 6.
	_check(SUPPLY.farm_yield(0, false) == 5 and SUPPLY.farm_yield(1, false) == 6 and SUPPLY.farm_yield(1, true) == 8, "Hofertrag 5 / 6 / 8 wie im Spiel")
	_check(SUPPLY.farm_yield(1, true, false) == 6, "Ohne Wasser 3 statt 5 (+1 +2)")
	var info := SUPPLY.reserve(20, 0, 5)
	_check(int(info.days_without_harvest) == 4 and SUPPLY.reserve_text(info).contains("4 Tage"), "Anzeige: „Dein Vorrat reicht noch 4 Tage“")
	var growing := SUPPLY.reserve(10, 12, 10)
	_check(int(growing.days) == -1 and SUPPLY.reserve_text(growing).contains("auch wenn eine Ernte ausfällt"), "Wachsender Vorrat: Tage ohne Ernte")
	_check(SUPPLY.reserve_text(SUPPLY.reserve(0, 12, 10)).contains("Lager ist leer"), "20 % Überschuss ist noch kein Lager")


# 2 ---------------------------------------------------------- Flächenmessung
func _area() -> void:
	_check(REGION.MAX_PLOTS == 4225 and int(ECONOMY.PLOTS.back()) == 4225, "Stadt bis 65 × 65 = 4.225 Plätze")
	var model = STATE.new("settlement", true)
	for ring in [16, 18, 20, 22, 24, 26, 28, 30, 32]:
		var total: int = (ring * 2 + 1) * (ring * 2 + 1)
		var free := 0
		var east := 0
		for index in range(total):
			if not TERRAIN.plot_blocked(index, false):
				free += 1
				if TERRAIN.plot_far_bank(index):
					east += 1
		_table("Fläche | Ring %d | %d × %d = %d Plätze | bebaubar %d (%.1f %%) | diesseits %d | Ostufer %d" % [
			ring, ring * 2 + 1, ring * 2 + 1, total, free, 100.0 * float(free) / float(total), free - east, east])
		if ring == 32:
			_check(free >= 2415, "Ganze Karte: mindestens 2.415 bebaubare Zellen (%d)" % free)
			_check(free - east >= 2415, "Schon diesseits des Flusses ≥ 2.415 (%d)" % (free - east))
			_check(float(free) / float(total) > 0.59, "Bebaubarer Anteil über 59 %% (%.1f %%)" % (100.0 * float(free) / float(total)))
	var reasons := {}
	for key in TERRAIN.REASONS:
		reasons[key] = TERRAIN.reason_count(key)
	_table("Sperrgründe | %s | Ostufer (Brücke nötig) %d" % [JSON.stringify(reasons), TERRAIN.far_bank_count()])
	_check(int(reasons.water) > 100 and int(reasons.slope) > 100, "Fluss und Hänge sind gekennzeichnet")
	_check(int(reasons.reserved) > 0, "Höhle, Lager und Hain bleiben frei")
	# Alte Karte: genau dieselben 114 gesperrten Felder im 33 × 33-Ortsteil.
	var old: Array = JSON.parse_string(FileAccess.get_file_as_string(OLD_BLOCKED))
	var lookup := {}
	for index in old:
		lookup[int(index)] = true
	var same := true
	for index in range(1089):
		if TERRAIN.plot_blocked(index, false) != lookup.has(index):
			same = false
	_check(old.size() == 114 and same, "Alter Ortsteil: dieselben 975 bebaubaren und 114 gesperrten Felder")
	# Eigene Gebiete: Nachbarn überschneiden sich weder mit der Stadt noch miteinander.
	var player_half := (32.5) * REGION.SPACING
	var sites: Array = TERRAIN.NEIGHBOR_SITES.values()
	for a in range(sites.size()):
		var site: Vector2 = sites[a]
		var outside_town: bool = (
			absf(site.x + REGION.TOWN_CENTER) > player_half + TERRAIN.NEIGHBOR_HALF
			or absf(site.y) > player_half + TERRAIN.NEIGHBOR_HALF
		)
		_check(outside_town, "Nachbargebiet liegt außerhalb der Stadt des Kindes")
		for b in range(a + 1, sites.size()):
			var other: Vector2 = sites[b]
			var apart := maxf(absf(site.x - other.x), absf(site.y - other.y)) > TERRAIN.NEIGHBOR_HALF * 2.0
			_check(apart, "Nachbargebiete überschneiden sich nicht")
	# Das Ostufer braucht die Brücke.
	var far := -1
	for index in range(4225):
		if TERRAIN.plot_far_bank(index):
			far = index
			break
	model._player.region = ECONOMY.PLOTS.size() - 1
	model._player.plots = 4225
	model._player.resources = {"wood": 999, "stone": 999, "food": 999, "coins": 999}
	model._player.crops.carrots = 999
	_check(far >= 1089 and not model.plot_buildable(far), "Ostufer ohne Lieferbrücke gesperrt")
	_check(not model.try_build("house", far) and model.last_error.contains("Lieferbrücke"), "Begründung nennt die Lieferbrücke")
	model._player.city_projects["bridge"] = true
	_check(model.plot_buildable(far) and model.try_build("house", far), "Mit Lieferbrücke wird das Ostufer Bauland")
	var water := TERRAIN.plot_reason(REGION.plot_index_at(Vector2i(19, 0)))
	_check(water == "water", "Flussfeld trägt den Grund „Wasser“: " + water)


# 3 ------------------------------------------------------- alter Spielstand
func _old_save() -> void:
	# Ein Spielstand vom alten Stand: 1.089 Felder, Region 11, Häuser überall
	# auf den damals bebaubaren Feldern, Spieler-Gebäude mit festen IDs.
	var legacy = STATE.new("settlement", true)
	var town: Dictionary = legacy._player
	town.region = 11
	town.plots = 1089
	town.buildings = []
	town.households = []
	var number := 1
	for index in range(1089):
		if index % 3 != 0:
			continue
		var id := "b%d" % number
		town.buildings.append({"id": id, "kind": "house" if index % 2 == 0 else "farm", "plot": index})
		if index % 2 == 0:
			town.households.append({"building_id": id, "adults": 2, "children": 0, "supplied_days": 5})
		number += 1
	town.next_id = number
	town.population = 2 + town.households.size() * 2
	town.resources = {"wood": 5000, "stone": 5000, "food": 900, "coins": 900}
	town.crops = {"carrots": 900, "grain": 0, "bread": 0}
	var saved: Dictionary = legacy.snapshot()
	var text := JSON.stringify({"save_version": 1, "settlement": saved})
	var raw: Dictionary = JSON.parse_string(text)
	var restored = STATE.restore(raw.settlement)
	_check(restored != null, "Alter 1.089-Spielstand lädt")
	if restored == null:
		return
	_check(restored.snapshot() == saved, "Alter Spielstand bleibt Feld für Feld gleich")
	var positions := {}
	for building in restored._player.buildings:
		var coordinate := REGION.plot_coordinate(int(building.plot))
		var legacy_x := -100.0 + coordinate.x * 5.3
		positions[str(building.id)] = REGION.plot_position(int(building.plot))
		if not is_equal_approx(positions[str(building.id)].x, legacy_x):
			_check(false, "Gebäude %s bleibt an seiner Stelle" % str(building.id))
			break
	# Erweitern auf die neue Fläche: IDs und Lagen bleiben, neue Felder kommen dazu.
	restored._player.population = maxi(int(restored._player.population), 60)
	ECONOMY.reconcile_households(restored._player)
	var service_plots := {"lumber": 1088, "quarry": 1087, "well": 1085, "road": 1084}
	for kind in service_plots:
		restored._player.buildings.append({"id": "b%d" % int(restored._player.next_id), "kind": kind, "plot": int(service_plots[kind])})
		restored._player.next_id = int(restored._player.next_id) + 1
	ECONOMY.reconcile_households(restored._player)
	var before_ids: Array = restored._player.buildings.map(func(b): return [str(b.id), int(b.plot)])
	_check(restored.expand(), "Altes Dorf erschließt die neue Region „%s“: %s" % [ECONOMY.REGIONS[12], restored.last_error])
	_check(int(restored._player.plots) == 1369, "Neue Region bringt 1.369 Plätze")
	var after_ids: Array = restored._player.buildings.map(func(b): return [str(b.id), int(b.plot)])
	_check(before_ids == after_ids, "Alle Gebäude-IDs und Grundstücke bleiben nach dem Erweitern gleich")
	var new_plot := -1
	for index in range(1089, 1369):
		if restored.plot_buildable(index):
			new_plot = index
			break
	_check(new_plot >= 1089 and restored.try_build("house", new_plot), "Auf neuem Bauland (Ring 17/18) wird gebaut")
	var again = STATE.restore(JSON.parse_string(JSON.stringify(restored.snapshot())))
	_check(again != null and again.snapshot() == restored.snapshot(), "Erweiterter Stand speichert und lädt verlustfrei")
	# Alter Nachbar-Stand ohne Gebiete/Baustellen lädt; IDs bleiben.
	var neighbors = NEIGHBORS.new()
	for _day in range(12):
		neighbors.advance_day(legacy)
	var raw_neighbors: Dictionary = JSON.parse_string(JSON.stringify(neighbors.snapshot()))
	raw_neighbors.erase("sites")
	raw_neighbors.erase("fort")
	var back = NEIGHBORS.restore(raw_neighbors)
	var same := true
	for id in neighbors.towns:
		if JSON.stringify(back.towns[id].snapshot().player.buildings) != JSON.stringify(neighbors.towns[id].snapshot().player.buildings):
			same = false
	_check(same, "Alter Nachbar-Stand ohne Baustellen lädt mit gleichen Gebäude-IDs")


# 4 -------------------------------------------------------------- 30 Tage
## Eine echte Stadt nach den Spielregeln: Höfe, Häuser, Brunnen auf bebaubaren
## Plätzen der kleinsten passenden Region, Bevölkerung in Familien.
func _city(civil: int, guards: int, irrigation: bool, stock: int):
	var people := civil + guards
	var daily := SUPPLY.farm_yield(1, irrigation)
	var plan := SUPPLY.plan(civil, guards, daily, irrigation)
	var model = STATE.new("settlement", true)
	var town: Dictionary = model._player
	town.city_projects = {"irrigation": true} if irrigation else {}
	var region := 1
	while region < ECONOMY.PLOTS.size() - 1:
		var free := 0
		for index in range(int(ECONOMY.PLOTS[region])):
			if model.plot_buildable(index):
				free += 1
		if free >= int(plan.base_cells):
			break
		region += 1
	town.region = region
	town.plots = int(ECONOMY.PLOTS[region])
	var kinds: Array[String] = []
	for _i in range(int(plan.houses)):
		kinds.append("house")
	for _i in range(int(plan.farms)):
		kinds.append("farm")
	for _i in range(int(plan.wells)):
		kinds.append("well")
	town.buildings = []
	var index := 0
	for kind in kinds:
		while not model.plot_buildable(index):
			index += 1
		town.buildings.append({"id": "b%d" % (town.buildings.size() + 1), "kind": kind, "plot": index})
		index += 1
	town.next_id = town.buildings.size() + 1
	town.households = []
	town.population = people
	ECONOMY.reconcile_households(town)
	town.resources = {"wood": 500, "stone": 500, "food": stock, "coins": 2000}
	town.crops = {"carrots": stock, "grain": 0, "bread": 0}
	town.treasury = 0
	for key in ["income_total", "tax_total", "tax_remainder"]:
		town[key] = 0
	if irrigation:
		# Bezahlte Projekte: der Stadtbeitrag deckt genau die Kosten.
		town.income_total = int(ECONOMY.PROJECTS.irrigation.cost) * 5
		town.tax_total = int(ECONOMY.PROJECTS.irrigation.cost)
	return {"model": model, "plan": plan}


func _thirty_days() -> void:
	for people in [40, 400, 4000]:
		var guards: int = people / 4
		for irrigation in [false, true]:
			for fail_day in [3, 20]:
				var made: Dictionary = _city(people - guards, guards, irrigation, 0)
				var model = made.model
				var plan: Dictionary = made.plan
				_check(STATE.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) != null, "Teststadt %d ist ein gültiger Spielstand" % people)
				var town: Dictionary = model._player
				var farms: Array = []
				for building in town.buildings:
					if str(building.kind) == "farm":
						farms.append(int(building.plot))
				var shortfall_days := 0
				var short_total := 0
				var lowest := 999999
				var recovered := -1
				var last_report: Dictionary = {}
				var water := ECONOMY.water_capacity(model, town)
				var reserve_line := ""
				var started := Time.get_ticks_usec()
				for day in range(1, 31):
					if day == fail_day:
						for plot in farms:
							model.damaged_plots[plot] = true
					var working: int = model._working(town, "farm")
					var report: Dictionary = model.next_day()
					model.damaged_plots.clear()
					var own: Dictionary = report.player
					if int(own.food_shortfall) > 0:
						shortfall_days += 1
						short_total += int(own.food_shortfall)
					lowest = mini(lowest, int(model._player.resources.food))
					if day > fail_day and recovered < 0 and int(own.food_shortfall) == 0:
						recovered = day
					if day == fail_day:
						_check(working == 0 and int(own.produced.food) == 0, "Ausgefallene Ernte an Tag %d: kein Ertrag" % day)
					elif day != fail_day:
						_check(int(own.produced.food) == int(plan.farms) * int(plan.daily_yield), "Ertrag = Höfe × Tagesertrag (%d Menschen, Tag %d)" % [people, day])
					if day == fail_day - 1:
						reserve_line = SUPPLY.reserve_text(SUPPLY.town_reserve(model, model._player))
					last_report = own
				var micros := Time.get_ticks_usec() - started
				var final_food := int(model._player.resources.food)
				_check(int(model._player.population) == people, "Bevölkerung bleibt %d (Rollen: %d Zivil + %d Wachen)" % [people, people - guards, guards])
				_check(water >= people, "Wasser reicht für alle (%d ≥ %d)" % [water, people])
				_check(final_food > 0, "Nach 30 Tagen ist wieder Vorrat da (%d)" % final_food)
				_table("30 Tage | %d Menschen (%d+%d) | Ertrag %d/Hof | Region %d (%d Plätze) | Höfe %d arbeitend | Brunnen %d, Wasser %d | Ertrag %d/Tag | Verbrauch %d/Tag | Ernteausfall Tag %d | Mangeltage %d (fehlend %d) | tiefster Vorrat %d | wieder satt ab Tag %d | Vorrat Tag 30: %d | Anzeige vor Ausfall: %s | Rechenzeit %.1f ms" % [
					people, people - guards, guards, int(plan.daily_yield), int(town.region), int(town.plots), int(plan.farms),
					int(plan.wells), water, int(plan.farms) * int(plan.daily_yield), people, fail_day, shortfall_days, short_total,
					lowest, recovered, final_food, reserve_line, float(micros) / 1000.0])
				if fail_day == 20:
					_check(shortfall_days == 0, "Mit 17 Tagen Überschuss übersteht die Stadt (%d) einen Ernteausfall" % people)
				else:
					_check(shortfall_days >= 1, "Frühe Missernte bei leerem Lager: 20 %% Überschuss reicht nicht (%d)" % people)


# 5 ------------------------------------------------------- 1.000 Wachen
func _thousand_guards() -> void:
	var made: Dictionary = _city(3000, 1000, true, 4000)
	var model = made.model
	var raids = load("res://scripts/creative/build_village_raids.gd").restore(null, model)
	var neighbors = NEIGHBORS.new()
	model._player.resources.coins = 1500
	# Kleine Stadt: keine Massenrekrutierung möglich.
	var small: Dictionary = _city(30, 10, false, 20)
	var small_raids = load("res://scripts/creative/build_village_raids.gd").restore(null, small.model)
	small.model._player.resources.coins = 500
	_check(not GUARDS.train(small.model, small_raids, 100, "mitte").is_empty(), "40 Menschen: 100 Wachen gehen nicht")
	_check(GUARDS.train(small.model, small_raids, 10, "mitte").is_empty(), "40 Menschen: 10 Wachen gehen")
	var mid: Dictionary = _city(300, 100, true, 200)
	var mid_raids = load("res://scripts/creative/build_village_raids.gd").restore(null, mid.model)
	mid.model._player.resources.coins = 500
	_check(GUARDS.train(mid.model, mid_raids, 100, "nord").is_empty(), "400 Menschen: 100 Wachen in einem Zug")
	var started := Time.get_ticks_usec()
	var taps := 0
	for post in ["nord", "ost", "sued", "west", "mitte"]:
		for _i in range(2):
			_check(GUARDS.train(model, raids, 100, post).is_empty(), "100 Wachen am " + post)
			taps += 1
	var train_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(int(raids.guards) == 1000 and GUARDS.total(raids) == 1000, "1.000 Wachen in Verbänden")
	_check(taps == 10, "1.000 Wachen mit 10 Zügen statt 1.000-mal tippen")
	_check(int(model._player.resources.coins) == 500, "Jede Wache kostet genau 1 Münze")
	_check(int(model._player.population) == 4000, "Rekrutierte wechseln nur die Rolle: 4.000 Menschen")
	var info := GUARDS.overview(model, raids)
	_check(int(info.posts.nord) == 200 and int(info.food_per_day) == 1000, "Gesamtzahl je Standort und Versorgung")
	# Speichern -> Laden.
	started = Time.get_ticks_usec()
	var envelope := {"save_version": 1, "settlement": model.snapshot(), "village_meta": {"raids": raids.snapshot(model), "neighbors": neighbors.snapshot()}}
	var text := JSON.stringify(envelope)
	var save_ms := float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var raw: Dictionary = JSON.parse_string(text)
	var loaded = STATE.restore(raw.settlement)
	var loaded_raids = load("res://scripts/creative/build_village_raids.gd").restore(raw.village_meta.raids, loaded)
	var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(loaded != null and int(loaded_raids.guards) == 1000 and GUARDS.total(loaded_raids) == 1000, "1.000 Wachen laden vollständig")
	_check(JSON.stringify(loaded_raids.units) == JSON.stringify(raids.units), "Verbände laden mit Standort und Größe")
	# Umgruppieren.
	started = Time.get_ticks_usec()
	var first: Dictionary = loaded_raids.units[0]
	_check(GUARDS.move(loaded_raids, int(first.id), "west").is_empty(), "Verband verlegen")
	_check(GUARDS.split(loaded_raids, int(first.id), 40).is_empty(), "Verband teilen")
	for post in GUARDS.POST_ORDER:
		GUARDS.regroup(loaded_raids, post)
	var regroup_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(int(loaded_raids.guards) == 1000 and GUARDS.total(loaded_raids) == 1000, "Umgruppieren verliert niemanden")
	_check(loaded_raids.units.size() <= 5, "Je Standort ein Verband nach dem Zusammenlegen (%d)" % loaded_raids.units.size())
	# Tageswechsel mit Nachbarn und Angriffsplan.
	var neighbors_loaded = NEIGHBORS.restore(raw.village_meta.neighbors)
	started = Time.get_ticks_usec()
	var report: Dictionary = loaded.next_day()
	neighbors_loaded.advance_day(loaded)
	loaded_raids.advance_day(loaded, neighbors_loaded, 12)
	var day_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(bool(report.advanced) and int(report.player.food_shortfall) == 0, "Tageswechsel mit 1.000 Wachen: alle satt")
	_check(int(loaded_raids.guards) == 1000, "Nach dem Tageswechsel sind alle Wachen da")
	_check(not GUARDS.train(loaded, loaded_raids, 100, "mitte").is_empty() or int(loaded._player.resources.coins) >= 100, "Ausbildung bleibt an Münzen gebunden")
	_table("1.000 Wachen (Container) | Ausbilden 10 Züge %.2f ms | Speichern %.2f ms | Laden %.2f ms | Umgruppieren %.2f ms | Tageswechsel %.2f ms | Spielstand %d Bytes | Verbände %d → %d" % [
		train_ms, save_ms, load_ms, regroup_ms, day_ms, text.length(), raids.units.size(), loaded_raids.units.size()])
	_check(text.length() < 1500000, "Spielstand einer 4.000-Menschen-Stadt bleibt unter 1,5 MB")


# 6 ------------------------------------------------------- Felder ziehen
func _fields() -> void:
	var model = STATE.new("settlement", true)
	var town: Dictionary = model._player
	town.region = 8
	town.plots = int(ECONOMY.PLOTS[8])
	town.resources = {"wood": 2000, "stone": 2000, "food": 50, "coins": 50}
	town.crops.carrots = 50
	var from := REGION.plot_index_at(Vector2i(-7, -7))
	var to := REGION.plot_index_at(Vector2i(-2, -2))
	var plots := FIELDS.area(model, from, to)
	_check(plots.size() == 36, "Rechteck 6 × 6 = 36 freie Plätze (%d)" % plots.size())
	var before: Dictionary = model.player()
	var built: Array[int] = model.try_build_many("farm", plots)
	_check(built.size() == 36 and model._count(model._player, "farm") == 36, "Ein Zug legt 36 Höfe an")
	_check(int(model._player.resources.wood) == 2000 - 36 * 4, "Jeder Hof zum normalen Preis bezahlt")
	_check(model.undo() and model.player() == before, "Ein Rückgängig-Schritt nimmt den ganzen Zug zurück")
	town = model._player
	town.resources.wood = 4 * 10
	built = model.try_build_many("farm", plots)
	_check(built.size() == 10 and model.last_error.contains("Rohstoffe"), "Fehlen Rohstoffe, endet die Reihe dort (10)")
	_check(FIELDS.area(model, from, REGION.plot_index_at(Vector2i(30, 30))).is_empty(), "Riesige Rechtecke werden abgelehnt (Schutz)")


# 7 ------------------------------------------------------- Nachbarstädte
func _neighbors() -> void:
	_check(NEIGHBORS.MAX_SITES > 81, "Nachbarn haben mehr als 81 Plätze (%d)" % NEIGHBORS.MAX_SITES)
	var player = STATE.new("settlement", true)
	player._player.resources = {"wood": 99, "stone": 99, "food": 99, "coins": 99}
	player._player.crops.carrots = 99
	var neighbors = NEIGHBORS.new()
	var saw_site := {}
	var saw_fort := false
	var saw_trade_farm := false
	var max_index := {}
	for _day in range(150):
		neighbors.advance_day(player)
		for entry in NEIGHBORS.NEIGHBORS:
			var id := str(entry.id)
			var project: Dictionary = neighbors.current_project(id)
			if not project.is_empty():
				saw_site[id] = true
				if str(project.kind) == "fort":
					saw_fort = true
				if id == "flitz" and str(project.why).contains("Handel"):
					saw_trade_farm = true
			for building in neighbors.towns[id]._player.buildings:
				max_index[id] = maxi(int(max_index.get(id, 0)), int(building.plot))
	for entry in NEIGHBORS.NEIGHBORS:
		var id := str(entry.id)
		var summary: Dictionary = neighbors.summary(id)
		_table("Nachbar 150 Tage | %s | Bewohner %d | Gebäude %d | Plätze %d | höchster Platz %d | Interesse %s | Befestigung %d" % [
			str(entry.town), int(summary.population), int(summary.buildings), int(summary.plots), int(max_index.get(id, 0)),
			str(summary.interest), int(summary.fort)])
		_check(saw_site.has(id), "%s zeigt sichtbare Baustellen" % str(entry.town))
		for building in neighbors.towns[id]._player.buildings:
			if not NEIGHBORS.plot_ok(id, int(building.plot)):
				_check(false, "%s baut nur in seinem Gebiet auf ebenem Land" % str(entry.town))
				break
	_check(saw_fort and int(neighbors.fort.stage) >= 1, "Burgheim baut sichtbar eine Befestigung (Stufe %d)" % int(neighbors.fort.stage))
	_check(saw_trade_farm, "Nusshausen baut einen Hof für seinen Handel")
	var biggest := 0
	for id in max_index:
		biggest = maxi(biggest, int(max_index[id]))
	_check(biggest >= 81, "Mindestens ein Nachbar baut über die alten 81 Plätze hinaus (%d)" % biggest)
	var raw: Variant = JSON.parse_string(JSON.stringify(neighbors.snapshot()))
	var back = NEIGHBORS.restore(raw)
	_check(JSON.stringify(back.snapshot()) == JSON.stringify(neighbors.snapshot()), "Baustellen und Befestigung speichern/laden verlustfrei")
