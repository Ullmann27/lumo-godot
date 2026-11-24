extends SceneTree
## Dorfwelt Teil 3: Angriffe mit Grund und Vorwarnung, Verteidigung als Plan,
## Auswertung, Reparatur, Vorräte zurückholen, Verhandeln, Bündnis, Speichern/
## Laden (auch alte Dateien) – erst als Regeln über ein automatisches Durchspiel,
## dann in der echten Szene mit Tippen auf die echten Knöpfe.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const RAIDS = preload("res://scripts/creative/build_village_raids.gd")
const SCHEDULE = preload("res://scripts/creative/build_village_schedule.gd")
const CHILD := "village_raids_regression"
const SLOT := 6
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageRaids] " + message)


func _frames(count := 6) -> void:
	for _i in range(count):
		await process_frame


## A sensible child: builds homes, food and materials, plans defence after a
## warning when `defend` is set, repairs, and sends guards to recover loot.
func _bot_day(model, raids, neighbors, defend: bool) -> Dictionary:
	var town: Dictionary = model._player
	for _attempt in range(2):
		var plot: int = model._free_plot(town)
		if plot < 0:
			model.expand()
			break
		var wishes: Array[String] = []
		if model._count(town, "lumber") < 2:
			wishes.append("lumber")
		if model._count(town, "quarry") < 2:
			wishes.append("quarry")
		if model._count(town, "well") == 0:
			wishes.append("well")
		if int(town.resources.food) < int(town.population) * 2 + 4:
			wishes.append("farm")
		if model._capacity(town) <= int(town.population) + 1:
			wishes.append("house")
		wishes.append_array(["market", "farm", "house", "school", "grain"])
		for kind in wishes:
			if model.try_build(kind, plot):
				break
	model.expand()
	if defend:
		for plot in model.damaged_plots.keys():
			raids.repair(model, int(plot))
		if not raids.pending.is_empty():
			for _round in range(12):
				var view: Dictionary = raids.forecast()
				if bool(view.ready):
					break
				var weights: Dictionary = RAIDS.THREATS[str(view.threat)].weights
				var built := false
				for kind in ["trap", "tower", "wall", "ditch", "gate"]:
					if float(weights[kind]) >= 0.8 and raids.build(kind, model).is_empty():
						built = true
						break
				if not built and not raids.train_guard(model).is_empty():
					break
		if not raids.stash.is_empty():
			raids.start_expedition("zurueckholen", model)
	model.next_day()
	neighbors.advance_day(model)
	return raids.advance_day(model, neighbors, int(town.campaign_chapter), true)


func _play(days: int, defend: bool) -> Dictionary:
	var model = STATE.new("settlement", true)
	var neighbors = NEIGHBORS.new()
	var raids = RAIDS.new()
	var warnings: Array = []
	var results: Array = []
	var first_chapter_day := -1
	for _day in range(days):
		var report := _bot_day(model, raids, neighbors, defend)
		if first_chapter_day < 0 and int(model._player.campaign_chapter) >= RAIDS.FIRST_CHAPTER:
			first_chapter_day = int(model.day)
		if report.has("warning"):
			warnings.append(report.warning)
		if report.has("raid"):
			results.append(report.raid)
	return {"model": model, "raids": raids, "neighbors": neighbors, "warnings": warnings, "results": results,
		"chapter_day": first_chapter_day}


func _run() -> void:
	_rules_early()
	_rules_playthrough()
	_rules_targeted()
	_rules_save()
	await _scene()
	if failures.is_empty():
		print("[VillageRaids] PASS checks=", checks)
		quit(0)
	else:
		print("[VillageRaids] FAIL checks=", checks, " failures=", failures)
		quit(1)


func _rules_early() -> void:
	var model = STATE.new("settlement", true)
	var raids = RAIDS.new()
	model._player.resources.food = 80
	model._player.crops.carrots = 80
	model._player.resources.coins = 60
	for _day in range(12):
		model.next_day()
		var report: Dictionary = raids.advance_day(model, null, 0, true)
		_check(not report.has("warning"), "Kein Angriff vor Kapitel 3 (Tag %d)" % int(model.day))
	model.day = 3
	var early: Dictionary = raids.advance_day(model, null, 5, true)
	_check(not early.has("warning"), "Kein Angriff vor Tag %d" % RAIDS.FIRST_DAY)
	model.day = 12
	var unfinished: Dictionary = raids.advance_day(model, null, 5, false)
	_check(not unfinished.has("warning"), "Kein Angriff, solange Lumos Einführung läuft")


func _rules_playthrough() -> void:
	var first := _play(100, true)
	var again := _play(100, true)
	_check(JSON.stringify(first.raids.snapshot(first.model)) == JSON.stringify(again.raids.snapshot(again.model)), "100 Tage sind deterministisch")
	_check(JSON.stringify(first.model.snapshot()) == JSON.stringify(again.model.snapshot()), "Dorf nach 100 Tagen identisch")
	var warnings: Array = first.warnings
	var results: Array = first.results
	print("[VillageRaids] planendes Kind: Kapitel 3 ab Tag %d, %d Warnungen, %d Angriffe: %s" % [
		int(first.chapter_day), warnings.size(), results.size(), ", ".join(results.map(func(r): return "%s@%d=%s(%.0f/%.0f)" % [r.threat, int(r.day), r.outcome, float(r.have), float(r.need)]))])
	_check(warnings.size() >= 4, "Über 100 Tage kommen mehrere Angriffe mit Ankündigung")
	_check(results.size() >= 3, "Angekündigte Angriffe kommen auch")
	var by_day := {}
	for warning in warnings:
		by_day[int(warning.arrive_day)] = warning
		_check(int(warning.arrive_day) - int(warning.announce_day) == RAIDS.WARNING_DAYS, "Vorwarnung %d Tage" % RAIDS.WARNING_DAYS)
		_check(not str(warning.reason).is_empty(), "Jeder Angriff hat einen Grund")
	for result in results:
		_check(by_day.has(int(result.day)), "Angriff am angekündigten Tag (%d)" % int(result.day))
	var defended := results.filter(func(r): return str(r.outcome) == "abgewehrt").size()
	_check(defended * 4 >= results.size() * 3, "Planendes Kind wehrt die meisten Angriffe ab (%d/%d)" % [defended, results.size()])
	var kinds := {}
	for warning in warnings:
		kinds[str(warning.threat)] = true
	_check(kinds.has("raeuber") and kinds.has("drache"), "Räuber und Drache kommen aus ihrem Grund: " + str(kinds.keys()))
	_check(int(first.raids.fame) >= defended, "Abwehr bringt Wappen")
	var careless := _play(100, false)
	var lost: int = careless.results.filter(func(r): return str(r.outcome) != "abgewehrt").size()
	print("[VillageRaids] Kind ohne Schutz: %d Angriffe, %d verloren, beschädigt jetzt %d" % [careless.results.size(), lost, careless.model.damaged_plots.size()])
	_check(lost >= 1, "Ohne Schutz gehen Angriffe verloren")
	for result in careless.results:
		_check(result.damaged.size() <= 2, "Höchstens zwei Gebäude beschädigt, nichts zerstört")
	var buildings := int(careless.model._player.buildings.size())
	_check(buildings >= 10, "Niederlagen zerstören nie Gebäude (%d stehen)" % buildings)
	_check(int(careless.model.day) == 101, "Das Spiel geht nach Niederlagen weiter")


func _rich_model():
	var model = STATE.new("settlement", true)
	model._player.resources = {"wood": 200, "stone": 200, "food": 60, "coins": 30}
	model._player.crops.carrots = 60
	model._player.population = 10
	model.day = 20
	for index in range(6):
		model.try_build(["farm", "quarry", "market", "lumber", "farm", "house"][index], index)
	return model


func _rules_targeted() -> void:
	# Robbers: real reason, defence plan, damage without destruction, repair, recovery.
	var model = _rich_model()
	var raids = RAIDS.new()
	var report: Dictionary = raids.advance_day(model, null, 3, true)
	_check(report.has("warning") and str(report.warning.threat) == "raeuber", "Volles Kornlager lockt die Räuber")
	_check(str(report.warning.reason).contains(str(model._player.resources.food)), "Grund nennt den echten Vorrat")
	var forecast: Dictionary = raids.forecast()
	_check(not bool(forecast.ready) and float(forecast.need) > 0.0, "Ohne Schutz reicht es nicht (Vorhersage)")
	model.day = int(raids.pending.arrive_day)
	var food_before := int(model._player.resources.food)
	var damaged_before: int = model.damaged_plots.size()
	var lost: Dictionary = raids.advance_day(model, null, 3, true).raid
	_check(str(lost.outcome) == "verloren", "Ungeschützt: verloren")
	_check(model.damaged_plots.size() == damaged_before + 2, "Zwei Gebäude beschädigt")
	# Grundversorgung (Heinz TEIL 6): die Höfe, die das Dorf satt machen, bleiben heil.
	_check(lost.damaged.all(func(entry): return str(entry.kind) not in ["farm", "house", "well"]), "Räuber lassen Höfe, Häuser und Brunnen stehen")
	var taken := food_before - int(model._player.resources.food)
	_check(taken > 0 and taken <= int(food_before * RAIDS.MAX_LOSS_SHARE), "Verlust höchstens 30 %% (%d von %d)" % [taken, food_before])
	_check(model._player.buildings.size() == 6, "Nichts wird zerstört")
	var plot := int(lost.damaged[0].plot)
	var with_damage: Dictionary = model.economy_status()
	var farms_working: int = model._working(model._player, "farm")
	_check(farms_working == 2, "Beide Höfe arbeiten weiter")
	_check(model._working(model._player, str(lost.damaged[0].kind)) == 0, "Beschädigte Gebäude arbeiten nicht")
	var wood_before := int(model._player.resources.wood)
	_check(raids.repair(model, plot).is_empty(), "Reparieren")
	_check(int(model._player.resources.wood) == wood_before - 2, "Reparatur kostet die Hälfte (2 Holz)")
	_check(model._working(model._player, str(lost.damaged[0].kind)) == 1, "Repariertes Gebäude arbeitet wieder")
	_check(not with_damage.is_empty(), "Wirtschaftsstatus lesbar")
	_check(not raids.stash.is_empty(), "Mitgenommene Vorräte liegen im Lager")
	_check(not raids.start_expedition("zurueckholen", model).is_empty(), "Zurückholen braucht Wachen")
	raids.train_guard(model)
	raids.train_guard(model)
	var stash_food := int(raids.stash.food)
	var food_mid := int(model._player.resources.food)
	_check(raids.start_expedition("zurueckholen", model).is_empty(), "Wachen brechen auf")
	_check(raids.defense_points("raeuber") < 2.0 * RAIDS.UNIT.guard * 1.2 - 0.01, "Unterwegs zählen die Wachen nicht zur Abwehr")
	model.day += 2
	var back: Dictionary = raids.advance_day(model, null, 3, true)
	_check(back.has("expedition") and int(model._player.resources.food) == food_mid + int(ceil(stash_food * RAIDS.RECOVER_SHARE)), "70 % kommen zurück")
	_check(raids.stash.is_empty() and int(raids.fame) == 1, "Zurückholen bringt ein Wappen")
	# Planned defence wins and unlocks parts.
	model.day = int(raids.next_check)
	model._player.resources.food = 60
	model._player.crops.carrots = 60
	raids.advance_day(model, null, 3, true)
	_check(not raids.pending.is_empty(), "Neue Warnung nach der Pause")
	for kind in ["wall", "trap", "trap", "trap", "tower"]:
		_check(raids.build(kind, model).is_empty(), "Baue " + kind)
	_check(raids.build_error("ditch", model).is_empty(), "Graben ist mit 1 Wappen frei")
	_check(raids.build_error("gate", model).is_empty(), "Tor nach der Mauer")
	var blocked: String = raids.build_error("wall", model)
	_check(blocked.is_empty(), "Steinmauer mit 1 Wappen")
	raids.build("ditch", model)
	_check(bool(raids.forecast().ready), "Mit Plan reicht der Schutz")
	model.day = int(raids.pending.arrive_day)
	var won: Dictionary = raids.advance_day(model, null, 3, true).raid
	_check(str(won.outcome) == "abgewehrt" and won.damaged.is_empty(), "Geplanter Schutz wehrt ab")
	_check(int(raids.fame) == 2 and not won.reward.is_empty(), "Sieg bringt Wappen und Beute")
	# Dragon: walls barely help, towers do.
	var dragon = RAIDS.new()
	dragon.parts.wall = 3
	var wall_points: float = dragon.defense_points("drache")
	var robber_points: float = dragon.defense_points("raeuber")
	_check(wall_points < robber_points * 0.3, "Funkel fliegt über Mauern")
	dragon.parts.tower = 2
	_check(dragon.defense_points("drache") > wall_points + 12.0, "Türme helfen gegen den Drachen")
	var shiny = _rich_model()
	shiny._player.resources.food = 10
	shiny._player.crops.carrots = 10
	shiny._player.resources.coins = 45
	var flight: Dictionary = dragon.advance_day(shiny, null, 3, true)
	_check(flight.has("warning") and str(flight.warning.threat) == "drache", "Münzschatz lockt Funkel")
	# Rival: the source is the reason; negotiating or an ally help.
	var rich = _rich_model()
	var neighbors = NEIGHBORS.new()
	_check(neighbors.claim_source("steinquelle", rich), "Kind sichert die Steinquelle")
	var siege = RAIDS.new()
	var announced: Dictionary = siege.advance_day(rich, neighbors, 3, true)
	_check(announced.has("warning") and str(announced.warning.threat) == "rivale" and str(announced.warning.by) == "leo", "Leo will die Steinquelle zurück")
	var ally_before: float = siege.defense_points("rivale", false)
	neighbors.reputation.flitz = 3
	_check(siege.call_ally("flitz", neighbors).is_empty(), "Verbündeter Flitz kommt")
	_check(not siege.call_ally("leo", neighbors).is_empty(), "Angreifer kann nicht helfen")
	_check(float(siege.forecast().have) > ally_before + 10.0, "Bündnis stärkt den Schutz")
	var leo_stone := int(neighbors.towns.leo._player.resources.stone)
	_check(siege.negotiate(rich, neighbors).is_empty(), "Verhandeln mit Geschenk")
	_check(siege.pending.is_empty() and int(neighbors.reputation.leo) == 0, "Frieden: Leo ist wieder neutral")
	_check(int(neighbors.towns.leo._player.resources.stone) == leo_stone + 8, "Leo bekommt das Geschenk wirklich")
	var lose_rich = _rich_model()
	var lose_neighbors = NEIGHBORS.new()
	lose_neighbors.claim_source("steinquelle", lose_rich)
	var lose = RAIDS.new()
	lose.advance_day(lose_rich, lose_neighbors, 3, true)
	lose_rich.day = int(lose.pending.arrive_day)
	var siege_result: Dictionary = lose.advance_day(lose_rich, lose_neighbors, 3, true).raid
	_check(str(siege_result.outcome) == "verloren" and str(lose_neighbors.sources.steinquelle) == "leo", "Verlorene Belagerung: Quelle geht zurück")


func _rules_save() -> void:
	var model = _rich_model()
	model._player.population = 2
	var neighbors = NEIGHBORS.new()
	var raids = RAIDS.new()
	raids.advance_day(model, neighbors, 3, true)
	model.day = int(raids.pending.arrive_day)
	raids.advance_day(model, neighbors, 3, true)
	raids.advance_day(model, neighbors, 3, true)
	raids.train_guard(model)
	var raw: Variant = JSON.parse_string(JSON.stringify(raids.snapshot(model)))
	# A second village with the same buildings stands in for the loaded save file.
	var other = _rich_model()
	var back = RAIDS.restore(raw, other)
	var left := JSON.stringify(back.snapshot(other))
	var right := JSON.stringify(raids.snapshot(model))
	if left != right:
		print("[VillageRaids] save diff\n", left, "\n", right)
	_check(left == right, "Angriffe speichern/laden verlustfrei")
	_check(other.damaged_plots.size() == model.damaged_plots.size() and model.damaged_plots.size() > 0, "Beschädigte Gebäude kommen mit")
	var fresh = RAIDS.restore(null, model)
	_check(fresh.pending.is_empty() and fresh.next_check >= int(model.day) + 2, "Alte Datei ohne Angriffe: ruhiger Neustart")
	var odd = RAIDS.restore({"version": 1, "parts": {"wall": 99}, "pending": {"threat": "unbekannt"}}, model)
	_check(int(odd.parts.wall) == 3 and odd.pending.is_empty(), "Kaputte Werte werden begrenzt")


func _screen(village: Node, local: Vector2) -> Vector2:
	return village.safe_ui.get_global_transform_with_canvas() * local


func _touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _tap_screen(point: Vector2) -> void:
	await _touch(point, true)
	await _touch(point, false)
	await _frames(4)


func _tap_control(village: Node, control: Control) -> void:
	await _tap_screen(_screen(village, village._hud_rect(control).get_center()))


## Taps a button inside the open village dialog (an embedded window).
func _tap_dialog_button(village: Node, prefix: String) -> bool:
	var dialog: Window = village.village_window
	if not is_instance_valid(dialog):
		return false
	for button in dialog.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with(prefix) and not (button as Button).disabled:
			var scroll := button.get_parent().get_parent() as ScrollContainer
			if scroll != null:
				scroll.ensure_control_visible(button)
				await _frames(2)
			var rect: Rect2 = (button as Control).get_global_rect()
			await _tap_screen(Vector2(dialog.position) + rect.get_center())
			return true
	return false


func _scene() -> void:
	root.size = Vector2i(1280, 720)
	var world_script = load("res://scripts/creative/build_settlement_world.gd")
	var save: String = world_script.project_path(CHILD, SLOT, "village")
	DirAccess.remove_absolute(save)
	root.get_node("SceneRouter").launch_options = {"childKey": CHILD, "buildSlot": SLOT, "settlementMode": "settlement", "livingVillage": true}
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	village.tutorial.skip()
	await _frames(2)
	_check(village.raids_view != null and village.raids_view.has_node("RobberCamp"), "Krummzahns Lager steht auf der Karte")
	_check(village.raids_view.has_node("DragonNest"), "Funkels Höhle steht auf der Karte")
	var model = village.model
	model._player.resources = {"wood": 160, "stone": 160, "food": 50, "coins": 20}
	model._player.crops.carrots = 50
	model._player.population = 8
	model._player.campaign_chapter = 3
	for index in range(5):
		model.try_build(["farm", "quarry", "market", "farm", "house"][index], village._next_free_plot())
	model.day = 12
	# Zeitplan: Versorgung läuft und „Schützen“ wurde schon einmal geöffnet.
	village.schedule.supply_streak = SCHEDULE.SUPPLY_DAYS
	village.dock.unlock_all()
	village.select_dock_section("schuetzen")
	village._rebuild()
	# Real input: tap "Nächster Tag" until Krummzahn announces himself.
	await _tap_control(village, village.day_button)
	await _frames(4)
	_check(not village.raids.pending.is_empty(), "Nach einem Tag kommt die Warnung")
	_check(village.raid_alert.visible and village.raid_alert.text.contains("Krummzahn"), "Warnschild nennt den Angreifer")
	_check(is_instance_valid(village.village_window) and village.village_window.name == "DefenseDialog", "Lumo öffnet den Schutz-Plan")
	var arrive := int(village.raids.pending.arrive_day)
	_check(arrive - int(model.day) == RAIDS.WARNING_DAYS, "Drei Tage Zeit zum Planen")
	# Plan the defence with real taps in the dialog.
	for prefix in ["Holzpalisade", "Netzfalle", "Netzfalle", "Wachturm", "Wache ausbilden", "Wache ausbilden", "Netzfalle"]:
		await _frames(3)
		if not is_instance_valid(village.village_window):
			village._defense_dialog()
			await _frames(3)
		_check(await _tap_dialog_button(village, prefix), "Knopf %s antippen" % prefix)
		await _frames(3)
	print("[VillageRaids] Szene: Schutz ", village.raids.parts, " Wachen ", village.raids.guards, " Vorhersage ", village.raids.forecast())
	_check(int(village.raids.parts.wall) == 1 and int(village.raids.parts.trap) >= 2 and int(village.raids.guards) == 2, "Getippte Schutzbauten sind bezahlt und gebaut")
	_check(int(village.raids_view.ring.get_meta("walls", 0)) > 4, "Mauerring sichtbar")
	_check(int(village.raids_view.ring.get_meta("towers", 0)) == 1, "Turm sichtbar")
	_check(int(village.raids_view.ring.get_meta("guards", 0)) == 2, "Wachen stehen am Tor")
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(3)
	while int(model.day) < arrive:
		await _tap_control(village, village.day_button)
		await _frames(3)
		if is_instance_valid(village.village_window):
			village.village_window.queue_free()
			await _frames(2)
	_check(village.raids_view.playing(), "Die Angriffsszene läuft")
	_check(int(village.raids_view.get_meta("scene_actors", 0)) >= 4, "Räuber laufen sichtbar heran")
	for _i in range(40):
		await physics_frame
	village.raids_view.finish_now()
	await _frames(4)
	var result: Dictionary = village.raids.last_result
	print("[VillageRaids] Szene-Ergebnis ", result.outcome, " ", result.have, "/", result.need)
	_check(str(result.outcome) == "abgewehrt", "Geplanter Schutz wehrt Krummzahn ab")
	_check(is_instance_valid(village.village_window) and village.village_window.name == "RaidResult", "Auswertung als kurze Szene")
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)
	# A lost raid: damage, repair with a tap.
	model._player.resources.coins = 60
	model.day = int(village.raids.next_check)
	await _tap_control(village, village.day_button)
	await _frames(3)
	_check(str(village.raids.pending.get("threat", "")) == "drache", "Münzschatz lockt Funkel in die Szene")
	# For this part the village is unprotected, so Funkel wins and leaves damage.
	for kind in village.raids.parts:
		village.raids.parts[kind] = 0
	village.raids.guards = 0
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)
	while not village.raids.pending.is_empty():
		await _tap_control(village, village.day_button)
		await _frames(3)
		if is_instance_valid(village.village_window):
			village.village_window.queue_free()
			await _frames(2)
	village.raids_view.finish_now()
	await _frames(4)
	print("[VillageRaids] Drache ", village.raids.last_result.outcome, " beschädigt ", model.damaged_plots.keys())
	_check(str(village.raids.last_result.outcome) != "abgewehrt" and not model.damaged_plots.is_empty(), "Funkel war stärker: Schaden")
	_check(int(village.raids_view.damage_root.get_meta("damaged", 0)) == model.damaged_plots.size(), "Baugerüst an beschädigten Gebäuden")
	_check(await _tap_dialog_button(village, "Zum Schutz-Plan"), "Vom Bericht zum Plan")
	await _frames(6)
	var damaged_before: int = model.damaged_plots.size()
	_check(await _tap_dialog_button(village, "Marktplatz reparieren"), "Reparieren antippen")
	await _frames(4)
	_check(model.damaged_plots.size() == damaged_before - 1, "Repariert")
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)
	var snapshot: Dictionary = village.raids.snapshot(model)
	_check(village._save(), "Speichern")
	village.queue_free()
	await _frames(4)
	village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	_check(JSON.stringify(village.raids.snapshot(village.model)) == JSON.stringify(snapshot), "Angriffe und Schäden laden aus dem Spielstand")
	village.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(save)
	# Old save without raid layer still loads.
	var old := FileAccess.open(save, FileAccess.WRITE)
	var legacy = STATE.new("settlement", true)
	old.store_string(JSON.stringify({"version": 1, "child": CHILD, "settlement": legacy.snapshot(), "mode": "settlement", "slot": SLOT}))
	old.close()
	village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	_check(village.raids != null and village.raids.pending.is_empty() and village.model.damaged_plots.is_empty(), "Alter Spielstand lädt ohne Angriffe")
	village.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(save)
