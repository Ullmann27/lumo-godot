extends SceneTree
## Angriffsskala (build_village_attack_scale.gd): Begegnungen wachsen mit der Stadt.
## Stadt 40 / 400 / 4.000: mit passender Verteidigung knapp gewonnen, ohne
## Verteidigung verloren – und die Grundversorgung bleibt. 1.000 schlecht
## aufgestellte Soldaten wehren nicht mehr alles ab; mehrere Richtungen
## verlangen Verbände an jedem Tor. Alte Spielstände ohne Heer laden wie bisher.
## Reine Regeln, headless.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const RAIDS = preload("res://scripts/creative/build_village_raids.gd")
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const SCALE = preload("res://scripts/creative/build_village_attack_scale.gd")
const TROOPS = preload("res://scripts/creative/build_village_troops.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[AttackScale] " + message)


func _town(population: int):
	var model = STATE.new("settlement", true)
	model._player.resources = {"wood": 400, "stone": 400, "food": 90, "coins": 20}
	model._player.crops.carrots = 90
	model.day = 30
	for index in range(8):
		model.try_build(
			["farm", "farm", "house", "lumber", "quarry", "market", "well", "house"][index], index
		)
	model._player.population = population
	return model


func _army(raids, post: String, kind: String, count: int) -> void:
	raids.guards = count
	raids.units = []
	if count > 0:
		var left := count
		var id := 1
		while left > 0:
			var size := mini(left, GUARDS.MAX_UNIT)
			raids.units.append(
				{"id": id, "name": "Trupp %d" % id, "size": size, "post": post, "type": kind}
			)
			left -= size
			id += 1
	for site in TROOPS.SITES:
		raids.troop_sites[site] = true


## Kündigt die Räuber an und gibt raids zurück (Heer nach Bewohnerzahl).
func _announce(model, level := 1):
	var raids = RAIDS.new()
	for _i in range(level - 1):
		raids.faced["raeuber"] = int(raids.faced.get("raeuber", 0)) + 1
	var report: Dictionary = raids.advance_day(model, null, 3, true)
	_check(report.has("warning") and str(report.warning.threat) == "raeuber", "Räuber angekündigt")
	return raids


func _resolve(model, raids) -> Dictionary:
	model.day = int(raids.pending.arrive_day)
	return raids.advance_day(model, null, 3, true).get("raid", {})


func _sizes() -> void:
	for population in [40, 400, 4000]:
		# Ohne Verteidigung: verloren, aber satt und nichts zerstört.
		var bare = _town(population)
		var raids = _announce(bare)
		var army: Dictionary = raids.pending.army
		var buildings: int = bare._player.buildings.size()
		var lost := _resolve(bare, raids)
		_check(
			str(lost.get("outcome", "")) != "abgewehrt",
			"%d Bewohner ohne Verteidigung verlieren" % population
		)
		_check(bare._player.buildings.size() == buildings, "%d: nichts wird zerstört" % population)
		_check(
			bare._working(bare._player, "farm") == 2, "%d: beide Höfe arbeiten weiter" % population
		)
		_check(
			lost.damaged.all(func(entry): return str(entry.kind) not in ["farm", "house", "well"]),
			"%d: Höfe, Häuser und Brunnen bleiben heil" % population
		)
		# Passend vorbereitet: jeder achte Bewohner ein Reiter am Südtor (gegen
		# Plünderer), bei großen Städten dazu eine Palisade.
		# Kleine Dörfer: so viele Reiter, wie für „Das reicht!“ nötig sind (Lumos Rat).
		var ready = _town(population)
		var plan = _announce(ready)
		var soldiers: int = population / 8
		if population <= 100:
			soldiers = 1
			_army(plan, "sued", "reiter", soldiers)
			while not bool(plan.forecast().ready) and soldiers < population / 2:
				soldiers += 1
				_army(plan, "sued", "reiter", soldiers)
		_army(plan, "sued", "reiter", soldiers)
		if population > 100:
			plan.parts.wall = 1
		var view: Dictionary = plan.forecast()
		var won := _resolve(ready, plan)
		var ratio := float(won.get("have", 0.0)) / maxf(1.0, float(won.get("need", 1.0)))
		print(
			(
				"[AttackScale] %d Bewohner, %d Reiter: %d Angreifer, Bedarf %.1f, Schutz %.1f (%.2f) – %s"
				% [
					population,
					soldiers,
					int(army.people),
					float(won.need),
					float(won.have),
					ratio,
					str(won.outcome)
				]
			)
		)
		_check(
			str(won.get("outcome", "")) == "abgewehrt",
			"%d Bewohner gut vorbereitet: abgewehrt" % population
		)
		_check(
			ratio >= 1.0 and ratio <= 2.0,
			"%d: gefordert, nicht überrollt (%.2f)" % [population, ratio]
		)
		_check(
			not str(view.army).is_empty(),
			"%d: Vorhersage nennt die Angreifer: %s" % [population, str(view.army)]
		)
		# Die falsche Truppe hilft deutlich weniger (Gegenstücke zählen).
		if population >= 400:
			var wrong = _town(population)
			var plan_wrong = _announce(wrong)
			_army(plan_wrong, "sued", "schild", population / 8)
			plan_wrong.parts.wall = 1
			var bad := _resolve(wrong, plan_wrong)
			_check(
				float(bad.have) < float(won.have),
				"%d: Schildwachen helfen gegen Plünderer weniger als Reiter" % population
			)
	_check(SCALE.army(40, 1).extra == 0, "Ein kleines Dorf erlebt die gewohnte kleine Gruppe")
	_check(
		SCALE.army(4000, 1).people > SCALE.army(400, 1).people * 5, "Das Heer wächst mit der Stadt"
	)


func _thousand() -> void:
	# 1.000 Soldaten, alle als Schildwachen in der Stadtmitte, gegen eine späte
	# Stufe aus mehreren Richtungen: das reicht nicht mehr.
	var model = _town(4000)
	var raids = _announce(model, 6)
	var gates: Array = raids.attack_sides(raids.pending)
	_check(gates.size() >= 2, "Späte Stufe: mehrere Richtungen (%d)" % gates.size())
	_army(raids, "mitte", "schild", 1000)
	var lazy: float = raids.defense_points("raeuber")
	var need: float = raids.need_points(raids.pending)
	_check(
		lazy < need,
		"1.000 Soldaten in der Mitte wehren nicht alles ab (%.0f < %.0f)" % [lazy, need]
	)
	# Gleich viele, aber auf die Tore verteilt und als passende Art: deutlich besser.
	raids.units = []
	var share := 1000 / gates.size()
	var id := 1
	for side in gates:
		raids.units.append(
			{"id": id, "name": "T%d" % id, "size": share, "post": side, "type": "reiter"}
		)
		id += 1
	raids.guards = share * gates.size()
	var spread: float = raids.defense_points("raeuber")
	_check(spread > lazy * 1.5, "Aufstellung an den Toren zählt (%.0f statt %.0f)" % [spread, lazy])
	# Alles an EIN Tor: das schwächste Tor entscheidet.
	_army(raids, str(gates[0]), "reiter", 1000)
	var one_gate: float = raids.defense_points("raeuber")
	_check(one_gate < spread, "Nur ein Tor besetzt: die anderen Tore sind offen")


func _old_saves() -> void:
	# Alter Spielstand: angekündigter Angriff ohne Heer – rechnet wie bisher.
	var model = _town(400)
	var raids = _announce(model)
	var snap: Dictionary = raids.snapshot(model)
	snap.pending.erase("army")
	var restored = RAIDS.restore(JSON.parse_string(JSON.stringify(snap)), model)
	_check(
		is_equal_approx(
			restored.need_points(restored.pending), restored.attack_points("raeuber", 1)
		),
		"Alter Stand ohne Heer: gewohnte Stärke"
	)
	_check(restored.attack_sides(restored.pending).size() == 1, "Alter Stand: eine Richtung")
	_check(
		str(restored.forecast().army).is_empty(),
		"Alter Stand: kein erfundenes Heer in der Vorhersage"
	)
	# Neuer Stand: Heer übersteht Speichern und Laden.
	var again = RAIDS.restore(JSON.parse_string(JSON.stringify(raids.snapshot(model))), model)
	_check(
		int(again.pending.army.people) == int(raids.pending.army.people),
		"Heer übersteht Speichern/Laden (%d)" % int(again.pending.army.people)
	)
	_check(
		is_equal_approx(again.need_points(again.pending), raids.need_points(raids.pending)),
		"Gleiche Stärke nach dem Laden"
	)


func _run() -> void:
	_sizes()
	_thousand()
	_old_saves()
	if failures.is_empty():
		print("[AttackScale] PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			print("[AttackScale] FAIL " + failure)
		print("[AttackScale] FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
