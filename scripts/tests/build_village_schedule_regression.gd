extends SceneTree
## Zeitplan der Herausforderungen (Heinz TEIL 6): friedliche Aufbauphase,
## erste kleine Herausforderung frühestens Tag 8 UND erst nach Haus+Hof,
## funktionierender Versorgung und gesehenem „Schützen“; Ankündigung ≥ 2
## selbst ausgelöste Tage; wer länger braucht, behält die Zeit; keine Uhr bei
## geschlossener App; schaffbare erste Begegnung; Erholung nach Niederlage;
## eine Eigenschaft je Stufe; nie zwei Systeme am selben Tag; Absender auf
## der Karte; alte Spielstände laden.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const RAIDS = preload("res://scripts/creative/build_village_raids.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const SCHEDULE = preload("res://scripts/creative/build_village_schedule.gd")
const DEFENSE = preload("res://scripts/creative/build_defense_state.gd")
const CHILD := "village_schedule_regression"
const SLOT := 6
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageSchedule] " + message)


func _frames(count := 6) -> void:
	for _i in range(count):
		await process_frame


## Ein Dorf mit Haus, zwei Höfen, Brunnen und vollem Kornlager (Räuber-Anlass).
func _ready_model():
	var model = STATE.new("settlement", true)
	for kind in ["house", "farm", "farm", "well", "house"]:
		model.try_build(kind, model._free_plot(model._player))
	model._player.resources.food = 60
	model._player.crops.carrots = 60
	return model


## Ein Tag wie im Spiel: Tageswechsel, Zeitplan, Angriffe (mit Zeitplan).
func _day(model, raids, schedule, neighbors = null, tutorial_done := true) -> Dictionary:
	var report: Dictionary = model.next_day()
	schedule.after_day(model, report)
	if int(model._player.resources.food) < 40:
		model._player.resources.food = 40
		model._player.crops.carrots = 40
	return raids.advance_day(model, neighbors, 0, tutorial_done, schedule)


func _run() -> void:
	_peaceful_start()
	_child_keeps_time()
	_first_encounter()
	_recovery()
	_stages()
	_calendar()
	_rival_sender()
	_old_saves()
	await _scene()
	if failures.is_empty():
		print("[VillageSchedule] PASS checks=", checks)
		quit(0)
	else:
		print("[VillageSchedule] FAIL checks=", checks, " failures=", failures)
		quit(1)


func _peaceful_start() -> void:
	var model = _ready_model()
	var raids = RAIDS.new()
	var schedule = SCHEDULE.new()
	schedule.defense_seen = true
	var first_warning := -1
	for _i in range(20):
		var report := _day(model, raids, schedule)
		if report.has("warning") and first_warning < 0:
			first_warning = int(model.day)
			var warning: Dictionary = report.warning
			_check(int(warning.arrive_day) - int(warning.announce_day) >= SCHEDULE.MIN_NOTICE,
				"Ankündigung mindestens %d Tage vorher (%d)" % [SCHEDULE.MIN_NOTICE, int(warning.arrive_day) - int(warning.announce_day)])
			_check(not str(warning.reason).is_empty(), "Ankündigung nennt den Anlass")
	print("[VillageSchedule] erste Ankündigung an Tag ", first_warning)
	_check(first_warning >= SCHEDULE.FIRST_DAY, "Keine Ankündigung vor Tag %d (erste: %d)" % [SCHEDULE.FIRST_DAY, first_warning])
	_check(first_warning > 0, "Mit erfüllten Bedingungen kommt die erste kleine Herausforderung")
	# Missing conditions each block on their own (day 12, food full).
	for missing in ["haus_hof", "versorgung", "schutz", "einfuehrung"]:
		var probe = _ready_model()
		var rules = RAIDS.new()
		var plan = SCHEDULE.new()
		plan.defense_seen = missing != "schutz"
		plan.supply_streak = 0 if missing == "versorgung" else SCHEDULE.SUPPLY_DAYS
		if missing == "haus_hof":
			probe = STATE.new("settlement", true)
			probe.try_build("farm", 0)
			probe._player.resources.food = 60
		probe.day = 12
		var report: Dictionary = rules.advance_day(probe, null, 0, missing != "einfuehrung", plan)
		_check(not report.has("warning"), "Ohne „%s“ keine Herausforderung" % missing)
		_check(missing in plan.missing(probe, missing != "einfuehrung") or missing == "einfuehrung", "Fehlende Bedingung benannt: " + missing)


func _child_keeps_time() -> void:
	# A slow child: no farm until day 20, Schützen never opened until day 25.
	var model = STATE.new("settlement", true)
	model.try_build("house", 0)
	model._player.resources.food = 60
	var raids = RAIDS.new()
	var schedule = SCHEDULE.new()
	var announced := -1
	for _i in range(40):
		if int(model.day) == 20:
			model.try_build("farm", model._free_plot(model._player))
			model.try_build("well", model._free_plot(model._player))
		if int(model.day) == 25:
			schedule.defense_seen = true
		var report := _day(model, raids, schedule)
		if report.has("warning") and announced < 0:
			announced = int(model.day)
	print("[VillageSchedule] langsames Kind: erste Ankündigung an Tag ", announced)
	_check(announced >= 25, "Wer länger braucht, behält die Zeit (Ankündigung erst Tag %d)" % announced)
	_check(announced > 0 and announced <= 30, "Danach kommt die Herausforderung trotzdem (Tag %d)" % announced)


func _first_encounter() -> void:
	var model = _ready_model()
	model._player.population = 10
	model._player.resources.coins = 8
	var raids = RAIDS.new()
	var schedule = SCHEDULE.new()
	schedule.defense_seen = true
	schedule.supply_streak = SCHEDULE.SUPPLY_DAYS
	model.day = 9
	var report: Dictionary = raids.advance_day(model, null, 0, true, schedule)
	_check(report.has("warning") and int(report.warning.level) == 1, "Erste Begegnung ist Stufe 1")
	var help: String = SCHEDULE.simple_help(raids, model)
	_check(help.begins_with("Bilde") and help.contains("Wache"), "Lumo nennt eine einfache Handlung: " + help)
	var count := int(help.split(" ")[1])
	_check(count >= 1 and count <= 5, "Wenige Wachen reichen (%d)" % count)
	for _i in range(count):
		_check(raids.train_guard(model).is_empty(), "Wache ausbilden")
	_check(bool(raids.forecast().ready), "Mit der genannten Handlung reicht der Schutz")
	model.day = int(raids.pending.arrive_day)
	var result: Dictionary = raids.advance_day(model, null, 0, true, schedule).raid
	_check(str(result.outcome) == "abgewehrt", "Erste Begegnung mit wenigen Wachen geschafft")


func _recovery() -> void:
	var model = _ready_model()
	model._player.population = 10
	for kind in ["grain", "bakery", "lumber"]:
		model.try_build(kind, model._free_plot(model._player))
	var raids = RAIDS.new()
	var schedule = SCHEDULE.new()
	schedule.defense_seen = true
	schedule.supply_streak = SCHEDULE.SUPPLY_DAYS
	model.day = 10
	var warn: Dictionary = raids.advance_day(model, null, 0, true, schedule)
	_check(warn.has("warning"), "Angekündigt")
	var level_before := int(raids.pending.level)
	model.day = int(raids.pending.arrive_day)
	var houses := int(model._count(model._player, "house"))
	var result: Dictionary = raids.advance_day(model, null, 0, true, schedule).raid
	_check(str(result.outcome) != "abgewehrt", "Ohne Schutz verloren")
	for entry in result.damaged:
		_check(str(entry.kind) not in ["house", "well"], "Wohnhaus/Brunnen bleiben heil (%s)" % str(entry.kind))
	_check(int(model._working(model._player, "farm")) >= raids.safe_farms(model), "Die nötigen Höfe arbeiten weiter")
	_check(int(model._player.resources.food) >= int(model._player.population) * 3, "Mindestens drei Tage Essen bleiben")
	_check(int(model._count(model._player, "house")) == houses, "Wohnraum bleibt")
	var lost_day := int(model.day)
	_check(int(schedule.recover_until) == lost_day + SCHEDULE.RECOVERY_DAYS, "Erholungsphase beginnt")
	var next_warning := -1
	for _i in range(30):
		var report := _day(model, raids, schedule)
		if report.has("warning") and next_warning < 0:
			next_warning = int(model.day)
			_check(int(report.warning.level) <= level_before, "Nächster Versuch ist nicht stärker (Stufe %d)" % int(report.warning.level))
	_check(next_warning >= lost_day + SCHEDULE.RECOVERY_DAYS, "Keine neue Ankündigung in der Erholung (Tag %d, verloren %d)" % [next_warning, lost_day])
	_check(next_warning > 0, "Danach geht es weiter")
	var plan := SCHEDULE.new()
	plan.defense_seen = true
	plan.supply_streak = 5
	model.day = lost_day + 1
	plan.recover_until = lost_day + SCHEDULE.RECOVERY_DAYS
	_check("erholung" in plan.missing(model, true), "Erholung ist als Grund benannt")


func _stages() -> void:
	var previous: Dictionary = SCHEDULE.stage(1)
	_check(int(previous.group) <= 4 and int(previous.sides) == 1, "Stufe 1: kleine Gruppe aus einer Richtung")
	for level in range(2, RAIDS.MAX_LEVEL + 1):
		var now: Dictionary = SCHEDULE.stage(level)
		var changed := int(int(now.group) != int(previous.group)) + int(int(now.sides) != int(previous.sides))
		_check(changed == 1, "Stufe %d steigert genau eine Eigenschaft (%s → %s)" % [level, previous, now])
		_check(not SCHEDULE.stage_change(level).is_empty(), "Lumo sagt, was neu ist (Stufe %d)" % level)
		previous = now


func _calendar() -> void:
	# Hasenwellen und Besuche/Konflikte: nie am selben Tag.
	_check(DEFENSE.FIRST_WAVE_DAY >= SCHEDULE.FIRST_DAY, "Erste Hasenwelle nicht vor Tag %d" % SCHEDULE.FIRST_DAY)
	var model = _ready_model()
	model._player.resources.coins = 60
	var raids = RAIDS.new()
	var schedule = SCHEDULE.new()
	schedule.defense_seen = true
	var hare_day := schedule.free_day(DEFENSE.FIRST_WAVE_DAY, "hasen")
	schedule.claim(hare_day, "hasen")
	var arrivals: Dictionary = {}
	var hare_days: Array[int] = [hare_day]
	for _i in range(80):
		var report := _day(model, raids, schedule)
		if report.has("warning"):
			var day := int(report.warning.arrive_day)
			_check(not hare_days.has(day), "Besuch nicht am Hasentag %d" % day)
			arrivals[day] = true
		if int(model.day) == hare_days[-1]:
			schedule.release(int(model.day))
			var next := schedule.free_day(int(model.day) + DEFENSE.WAVE_INTERVAL, "hasen")
			_check(not arrivals.has(next) or next != int(raids.pending.get("arrive_day", -1)), "Nächste Hasenwelle weicht aus")
			schedule.claim(next, "hasen")
			hare_days.append(next)
		if report.has("raid"):
			_check(not hare_days.has(int(report.raid.day)), "Angriff kam nicht am Hasentag")
	print("[VillageSchedule] Hasentage ", hare_days.slice(0, 6), " Besuche ", arrivals.keys().slice(0, 6))
	_check(arrivals.size() >= 2, "Über 80 Tage mehrere Besuche (%d)" % arrivals.size())
	var shared := 0
	for day in arrivals:
		shared += int(hare_days.has(int(day)))
	_check(shared == 0, "Kein Tag mit zwei Systemen (%d)" % shared)
	# A reserved day pushes the arrival, the notice only grows.
	var busy = SCHEDULE.new()
	busy.defense_seen = true
	busy.supply_streak = 5
	var probe = _ready_model()
	probe.day = 10
	busy.claim(13, "hasen")
	busy.claim(14, "konflikt")
	var rules = RAIDS.new()
	var report: Dictionary = rules.advance_day(probe, null, 0, true, busy)
	_check(report.has("warning") and int(report.warning.arrive_day) == 15, "Belegte Tage werden übersprungen (Ankunft %s)" % str(report.get("warning", {}).get("arrive_day", "-")))


func _rival_sender() -> void:
	var model = _ready_model()
	model._player.resources = {"wood": 80, "stone": 80, "food": 10, "coins": 30}
	model._player.crops.carrots = 10
	var neighbors = NEIGHBORS.new()
	_check(neighbors.claim_source("steinquelle", model), "Kind sichert die Steinquelle")
	neighbors.reputation.leo = -2
	var raids = RAIDS.new()
	var schedule = SCHEDULE.new()
	schedule.defense_seen = true
	schedule.supply_streak = 5
	model.day = 12
	var report: Dictionary = raids.advance_day(model, neighbors, 0, true, schedule)
	_check(report.has("warning") and str(report.warning.threat) == "rivale", "Konflikt mit einer Nachbarstadt angekündigt")
	if not report.has("warning"):
		return
	var by := str(report.warning.by)
	_check(NEIGHBORS.spec(by).has("site"), "Absender hat einen Ort auf der Karte")
	_check(raids.threat_title(raids.pending).contains(str(NEIGHBORS.spec(by).town)), "Titel nennt die Stadt: " + raids.threat_title(raids.pending))
	_check(str(report.warning.reason).contains("zurück"), "Anlass: " + str(report.warning.reason))
	_check(str(schedule.calendar.get(int(raids.pending.arrive_day), "")) == "konflikt", "Konflikt steht im Kalender")
	_check(raids.negotiation_cost().size() > 0, "Verhandeln bleibt eine echte Alternative")
	var arrive := int(raids.pending.arrive_day)
	_check(raids.negotiate(model, neighbors).is_empty(), "Geschenk schließt Frieden")
	schedule.release(arrive)
	_check(not schedule.calendar.has(arrive), "Frieden gibt den Tag frei")
	_check(str(raids.last_result.outcome) == "frieden", "Sichtbarer Ausgang: Frieden")


func _old_saves() -> void:
	var model = _ready_model()
	model.day = 30
	var raw_raids := {"version": 1, "parts": {"wall": 1}, "guards": 2, "next_check": 31, "defended": 1}
	var raids = RAIDS.restore(raw_raids, model)
	var schedule = SCHEDULE.restore(null, model, raids)
	_check(schedule.defense_seen, "Altes Dorf mit Mauer kennt „Schützen“")
	_check(schedule.supply_ok(), "Altes Dorf mit Hof: Versorgung gilt als laufend")
	var fresh = SCHEDULE.restore(null, STATE.new("settlement", true), null)
	_check(not fresh.defense_seen and fresh.supply_streak == 0, "Neues Dorf: nichts vorausgesetzt")
	var round_trip = SCHEDULE.restore(JSON.parse_string(JSON.stringify(schedule.snapshot())), model, raids)
	_check(JSON.stringify(round_trip.snapshot()) == JSON.stringify(schedule.snapshot()), "Zeitplan speichert/lädt verlustfrei")
	var broken = SCHEDULE.restore({"version": 1, "calendar": {"x": "hasen", "12": "fremd", "13": "hasen"}}, model, raids)
	_check(broken.calendar.size() == 1 and str(broken.calendar.get(13, "")) == "hasen", "Kaputte Kalendereinträge werden verworfen")


func _scene() -> void:
	root.size = Vector2i(1280, 720)
	var world_script = load("res://scripts/creative/build_settlement_world.gd")
	var save: String = world_script.project_path(CHILD, SLOT, "village")
	DirAccess.remove_absolute(save)
	var launch := {"childKey": CHILD, "buildSlot": SLOT, "settlementMode": "settlement", "livingVillage": true}
	root.get_node("SceneRouter").launch_options = launch
	var village: Node = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	village.tutorial.skip()
	var model = village.model
	for kind in ["house", "farm", "farm", "well"]:
		model.try_build(kind, village._next_free_plot())
	model._player.resources.food = 50
	model._player.crops.carrots = 50
	village._rebuild()
	var first := -1
	for _i in range(12):
		village._next_day()
		await _frames(2)
		if is_instance_valid(village.village_window):
			village.village_window.queue_free()
			await _frames(2)
		if not village.raids.pending.is_empty() and first < 0:
			first = int(model.day)
	_check(first < 0, "Ohne gesehenes „Schützen“ keine Ankündigung (bis Tag %d)" % int(model.day))
	_check(village.dock.is_open("schuetzen"), "„Schützen“ hat sich an einem passenden Moment geöffnet")
	village.select_dock_section("schuetzen")
	_check(village.schedule.defense_seen, "Bereich angetippt: Verteidigung kennengelernt")
	village._next_day()
	await _frames(4)
	_check(not village.raids.pending.is_empty(), "Danach kommt die erste kleine Herausforderung")
	var dialog: Window = village.village_window
	var texts: Array[String] = []
	if is_instance_valid(dialog):
		for label in dialog.find_children("*", "Label", true, false):
			texts.append((label as Label).text)
	var joined := " ".join(texts)
	_check(joined.contains("Krummzahn") or joined.contains("Funkel"), "Schutz-Plan zeigt, wer kommt")
	_check(joined.contains("Bilde") or joined.contains("Baue") or joined.contains("reicht"), "Schutz-Plan zeigt die einfache Handlung")
	var sign: Label3D = village.raids_view.get_node_or_null("SenderSign")
	_check(sign != null and sign.text.contains(village.raids.threat_title(village.raids.pending)), "Warnschild über dem Absender auf der Karte")
	var arrive := int(village.raids.pending.arrive_day)
	var day_now := int(model.day)
	village._save()
	village.queue_free()
	await _frames(4)
	# App closed and opened again: no attack clock ran.
	village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	_check(int(village.model.day) == day_now and int(village.raids.pending.get("arrive_day", -1)) == arrive,
		"Bei geschlossener App läuft keine Angriffsuhr (Tag %d/%d, Ankunft %s/%d)" % [int(village.model.day), day_now, str(village.raids.pending.get("arrive_day", -1)), arrive])
	_check(village.schedule.defense_seen and str(village.schedule.calendar.get(arrive, "")) != "", "Zeitplan kommt mit dem Spielstand zurück")
	village.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(save)
