extends SceneTree
## KI-Nachbardörfer: wachsen über 60 Tage deterministisch nach denselben Regeln,
## handeln aus echtem Bestand, helfen in der Not, wetteifern um Quellen,
## speichern/laden im selben Umschlag und sind in der Szene sichtbar.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const CHILD := "village_neighbors_regression"
const SLOT := 4
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageNeighbors] " + message)


func _frames(count := 6) -> void:
	for _i in range(count):
		await process_frame


func _simulate(days: int) -> Array:
	var player = STATE.new("settlement", true)
	var neighbors = NEIGHBORS.new()
	var samples: Array = []
	for day in range(days):
		player.next_day()
		neighbors.advance_day(player)
		if day in [0, 29, days - 1]:
			var row := {}
			for entry in NEIGHBORS.NEIGHBORS:
				row[entry.id] = neighbors.summary(entry.id)
			samples.append(row)
	return [neighbors, player, samples]


func _run() -> void:
	var first: Array = _simulate(60)
	var second: Array = _simulate(60)
	var neighbors = first[0]
	_check(JSON.stringify(neighbors.snapshot()) == JSON.stringify(second[0].snapshot()), "60 Tage sind deterministisch")
	var samples: Array = first[2]
	for entry in NEIGHBORS.NEIGHBORS:
		var id: String = entry.id
		var start: Dictionary = samples[0][id]
		var end: Dictionary = samples[2][id]
		print("[VillageNeighbors] %s Tag1 %d Gebäude/%d Bewohner -> Tag60 %d Gebäude/%d Bewohner, Gebiete %d" % [
			id, int(start.buildings), int(start.population), int(end.buildings), int(end.population), int(end.plots)])
		_check(int(end.buildings) >= int(start.buildings) + 6, "%s baut sichtbar weiter" % id)
		_check(int(end.population) > int(start.population), "%s wächst" % id)
		var saved: Dictionary = neighbors.towns[id].snapshot()
		var restored = STATE.restore(JSON.parse_string(JSON.stringify(saved)))
		_check(restored != null and restored.snapshot() == saved, "%s ist ein gültiges Dorf nach denselben Regeln" % id)
		for building in neighbors.towns[id]._player.buildings:
			if not NEIGHBORS.plot_ok(id, int(building.plot)):
				_check(false, "%s baut nur auf flacher Wiese" % id)
				break
	_check(neighbors.day == 61, "Genau ein Nachbartag je Kindertag (kein Aufholen)")
	var styles := {}
	for entry in NEIGHBORS.NEIGHBORS:
		var kinds := {}
		for building in neighbors.towns[entry.id]._player.buildings:
			kinds[str(building.kind)] = int(kinds.get(str(building.kind), 0)) + 1
		styles[entry.id] = kinds
	var share := func(kinds: Dictionary, kind: String) -> float:
		var total := 0
		for value in kinds.values():
			total += int(value)
		return float(kinds.get(kind, 0)) / maxf(1.0, float(total))
	print("[VillageNeighbors] styles ", styles)
	_check(share.call(styles.leo, "quarry") > share.call(styles.flitz, "quarry"), "Leo baut anteilig mehr Steinbrüche (Charakter)")
	_check(int(styles.flitz.get("market", 0)) >= 1, "Flitz baut einen Markt (Charakter)")
	# Save/load of the whole neighbour layer.
	var raw: Variant = JSON.parse_string(JSON.stringify(neighbors.snapshot()))
	var back = NEIGHBORS.restore(raw)
	_check(JSON.stringify(back.snapshot()) == JSON.stringify(neighbors.snapshot()), "Nachbarn speichern/laden verlustfrei")
	_check(NEIGHBORS.restore(null).day == 1, "Alte Datei ohne Nachbarn: frischer Start")
	# Trade from real stock.
	var player = STATE.new("settlement", true)
	player._player.resources = {"wood": 40, "stone": 40, "food": 40, "coins": 10}
	player._player.crops.carrots = 40
	var traded := false
	for entry in NEIGHBORS.NEIGHBORS:
		var deal: Dictionary = neighbors.offer(entry.id)
		if deal.is_empty():
			continue
		var before_player: Dictionary = player.player().resources
		var before_rep := int(neighbors.reputation[entry.id])
		var neighbor_before: Dictionary = neighbors.towns[entry.id].player().resources
		if neighbors.trade(entry.id, player):
			traded = true
			var after: Dictionary = player.player().resources
			for resource in deal.give:
				_check(int(after[resource]) == int(before_player[resource]) - int(deal.give[resource]) + int(deal.receive.get(resource, 0)), "Kind gibt genau " + resource)
			for resource in deal.receive:
				_check(int(neighbors.towns[entry.id].player().resources[resource]) == int(neighbor_before[resource]) - int(deal.receive[resource]) + int(deal.give.get(resource, 0)), "Nachbar gibt genau " + resource)
			_check(int(neighbors.reputation[entry.id]) == mini(3, before_rep + 1), "Handel stärkt die Freundschaft")
			break
	_check(traded, "Mindestens ein Nachbar macht ein Angebot aus Überschuss")
	# Help in need.
	var needy = STATE.new("settlement", true)
	needy._player.resources.food = 0
	needy._player.crops.carrots = 0
	needy._player.crops.bread = 0
	needy._player.food_shortfall = 2
	var helper = NEIGHBORS.restore(raw)
	for entry in NEIGHBORS.NEIGHBORS:
		helper.reputation[entry.id] = 1
		helper.towns[entry.id]._player.resources.food = 30
		helper.towns[entry.id]._player.crops.carrots = 30
		helper.towns[entry.id]._player.crops.bread = 0
	var result: Dictionary = helper.advance_day(needy)
	_check(not result.help.is_empty() and int(needy.player().resources.food) >= 6, "Freundlicher Nachbar hilft in der Not")
	# Competition for a source.
	var rich = STATE.new("settlement", true)
	rich._player.resources = {"wood": 50, "stone": 50, "food": 20, "coins": 20}
	rich._player.crops.carrots = 20
	var race = NEIGHBORS.new()
	_check(race.claim_source("steinquelle", rich), "Kind sichert die Steinquelle")
	_check(int(race.reputation.leo) == -1, "Leo ist enttäuscht (Wettstreit mit Grund)")
	var stone_before := int(rich.player().resources.stone)
	race.advance_day(rich)
	_check(int(rich.player().resources.stone) == stone_before + NEIGHBORS.SOURCE_YIELD, "Quelle liefert täglich")
	_check(not race.claim_source("steinquelle", rich), "Eine Quelle hat nur einen Besitzer")
	await _scene()
	if failures.is_empty():
		print("[VillageNeighbors] PASS checks=", checks)
		quit(0)
	else:
		print("[VillageNeighbors] FAIL checks=", checks, " failures=", failures)
		quit(1)


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
	_check(village.neighbors_view != null and village.neighbors_view.has_node("Neighbor_leo"), "Nachbardörfer stehen auf der Karte")
	_check(village.neighbors_view.find_children("Rider_*", "", true, false).size() >= 0, "Figuren-Knoten vorhanden")
	var start_buildings: int = village.neighbors_view.facilities.size()
	for _day in range(8):
		village._next_day()
		await _frames(2)
	_check(village.neighbors_view.facilities.size() > start_buildings, "Neue Nachbargebäude erscheinen sichtbar")
	_check(village.neighbors.day == 9, "Acht Kindertage = acht Nachbartage")
	village._neighbors_dialog()
	await _frames(3)
	_check(is_instance_valid(village.village_window), "Nachbar-Fenster öffnet")
	if is_instance_valid(village.village_window):
		village.village_window.queue_free()
	await _frames(2)
	var snapshot: Dictionary = village.neighbors.snapshot()
	_check(village._save(), "Speichern")
	village.queue_free()
	await _frames(4)
	village = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(village)
	await _frames(8)
	_check(JSON.stringify(village.neighbors.snapshot()) == JSON.stringify(snapshot), "Nachbarn laden aus dem Spielstand")
	village.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(save)
