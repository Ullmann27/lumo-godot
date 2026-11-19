extends SceneTree
## Gelände der Dorfwelt: Höhenkarte, bebaubar/nicht bebaubar, Spielstände,
## Grundstücke folgen dem Gelände, Budgets je Qualitätsstufe.
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const LIFE = preload("res://scripts/creative/build_village_life.gd")
const ATMOSPHERE = preload("res://scripts/creative/build_village_atmosphere.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageTerrain] " + message)


func _frames(count := 4) -> void:
	for _i in range(count):
		await process_frame


func _run() -> void:
	_check(TERRAIN.ensure(), "Die Höhenkarte ist geladen")
	var grid := TERRAIN.grid_size()
	_check(grid == Vector2i(353, 257), "Höhenkarte 353 × 257 Punkte (2,5 m)")
	_check(TERRAIN.size().x >= 860.0 and TERRAIN.size().y >= 630.0, "Große zusammenhängende Karte (880 × 640 m)")
	var lowest := INF
	var highest := -INF
	for iz in range(grid.y):
		for ix in range(grid.x):
			var h := TERRAIN.grid_height(ix, iz)
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	_check(lowest < TERRAIN.WATER_LEVEL - 4.0, "See, Fluss und Küste liegen unter dem Wasserspiegel")
	_check(highest > 45.0, "Berge über der Schneegrenze")
	_check(TERRAIN.is_water(TERRAIN.river_center(0.0), 0.0), "Der Fluss fließt durch die Talmitte")
	_check(TERRAIN.height(-100, -270) > 20.0, "Bergkette im Norden")
	_check(TERRAIN.height(0, 260) < TERRAIN.WATER_LEVEL, "Küste im Süden")
	# Inverse plot addressing (taps on terrain select the cell underneath).
	for index in range(REGION.MAX_PLOTS):
		if REGION.plot_index_at(REGION.plot_coordinate(index)) != index:
			_check(false, "Feldadresse umkehrbar: %d" % index)
			break
	_check(REGION.plot_index_at(Vector2i(33, 0)) == -1, "Außerhalb der Stadt (Ring 32) gibt es kein Feld")
	_check(REGION.plot_index_at(Vector2i(17, 0)) >= 1089, "Ring 17 ist neues Bauland hinter dem alten Ortsteil")
	# Buildability: early rings always buildable, rocky hills/shore not.
	for opponent in [false, true]:
		for index in range(225):
			if TERRAIN.plot_blocked(index, opponent):
				_check(false, "Frühe Felder sind bebaubar: %d" % index)
				break
		var blocked := 0
		for index in range(1089):
			if TERRAIN.plot_blocked(index, opponent):
				blocked += 1
		_check(blocked > 40 and blocked < 300, "Felshügel/Ufer sperren einige äußere Felder im alten Ortsteil: %d" % blocked)
	var steep_found := 0
	for index in range(225, REGION.MAX_PLOTS):
		if not TERRAIN.plot_blocked(index, false):
			continue
		var at := REGION.plot_position(index, false)
		var spread := 0.0
		for dx in [-2.3, 2.3]:
			for dz in [-2.3, 2.3]:
				spread = maxf(spread, absf(TERRAIN.height(at.x + dx, at.z + dz) - at.y))
		if spread > 0.5 or at.y < TERRAIN.WATER_LEVEL + 1.0 or TERRAIN.steepness(at.x, at.z) > 0.08:
			steep_found += 1
	_check(steep_found > 20, "Gesperrte Felder sind wirklich steil, felsig oder nass: %d" % steep_found)
	# Plots follow the terrain.
	var plot_zero := REGION.plot_position(0)
	_check(is_equal_approx(plot_zero.y, TERRAIN.height(plot_zero.x, plot_zero.z) + 0.03), "Grundstück liegt auf dem Gelände")
	_check(is_equal_approx(plot_zero.x, -105.3) and is_equal_approx(plot_zero.z, -5.3), "Alte Feldadresse bleibt exakt")
	# Rules: a new building on a blocked plot is refused without side effects.
	var model = STATE.new("settlement", true)
	var town: Dictionary = model._player
	town.region = 11
	town.plots = REGION.MAX_PLOTS
	town.resources = {"wood": 999, "stone": 999, "food": 999, "coins": 999}
	var blocked_plot := -1
	for index in range(REGION.MAX_PLOTS):
		if TERRAIN.plot_blocked(index, false):
			blocked_plot = index
			break
	_check(blocked_plot >= 225, "Ein gesperrtes äußeres Feld existiert")
	var before: Dictionary = model.snapshot()
	_check(not model.try_build("house", blocked_plot), "Auf Fels/Hang wird nicht gebaut")
	_check(model.last_error.contains("Fels"), "Kindgerechte Begründung: " + model.last_error)
	_check(model.snapshot() == before, "Abgelehnter Bau verändert nichts")
	_check(not model.plot_buildable(blocked_plot), "Regel ist im Spielmodell verankert")
	_check(model.try_build("house", 0), "Wiese bleibt bebaubar")
	# _free_plot never hands out a blocked cell.
	town.buildings = []
	for index in range(REGION.MAX_PLOTS):
		if index != blocked_plot and not TERRAIN.plot_blocked(index, false) and index < blocked_plot:
			town.buildings.append({"id": "f%d" % index, "kind": "road", "plot": index})
	var free := model._free_plot(model.player())
	_check(free > blocked_plot and not TERRAIN.plot_blocked(free, false), "Freier Bauplatz überspringt Fels")
	# Old saves: a building that already stands on a now-blocked cell still loads.
	# The published 2178-house scale fixture puts houses on EVERY cell,
	# including cells that are rock or shore now: such saves must still load.
	var legacy = STATE.new("rival", true)
	for legacy_town: Dictionary in [legacy._player, legacy._rival]:
		legacy_town.region = 11
		legacy_town.plots = 1089
		legacy_town.population = 2180
		legacy_town.next_id = 1090
		legacy_town.buildings = []
		legacy_town.households = []
		for index in range(1089):
			var id := "b%d" % (index + 1)
			legacy_town.buildings.append({"id": id, "kind": "house", "plot": index})
			legacy_town.households.append({"building_id": id, "adults": 2, "children": 0, "supplied_days": 20})
	var saved: Dictionary = legacy.snapshot()
	var restored = STATE.restore(JSON.parse_string(JSON.stringify(saved)))
	_check(restored != null and restored.snapshot() == saved, "Alter Spielstand mit Häusern auf jetzt gesperrten Feldern lädt unverändert")
	# Classic settlement stays completely flat and unrestricted.
	var classic = STATE.new("settlement", false)
	_check(classic.plot_buildable(blocked_plot), "Klassische Siedlung kennt keine Geländesperre")
	# Budgets per profile.
	var region_budget: Dictionary = REGION.BUDGETS
	_check(float(region_budget.low.trees) < float(region_budget.medium.trees) and float(region_budget.medium.trees) < float(region_budget.high.trees), "Vegetation LOW < MEDIUM < HIGH")
	_check(int(LIFE.BUDGETS.low.smoke) < int(LIFE.BUDGETS.high.smoke), "Rauchquellen LOW < HIGH")
	_check(not bool(ATMOSPHERE.SHADOWS.low.enabled) and bool(ATMOSPHERE.SHADOWS.high.enabled), "Schatten nur ab MEDIUM")
	_check(float(ATMOSPHERE.SHADOWS.medium.distance) < float(ATMOSPHERE.SHADOWS.high.distance), "HIGH: weitere Schattendistanz")
	var counts: Dictionary = {}
	var performance := root.get_node("PerformanceManager")
	for tier in [0, 2]:
		performance.call("set_profile", tier, false)
		var region = REGION.new()
		root.add_child(region)
		region.build_landscape("settlement")
		var landscape: Node = region.landscape
		counts[tier] = {
			"trees": int(region.get_meta("wilderness_trees", 0)),
			"terrain": int(landscape.get_meta("terrain_triangles", 0)),
		}
		_check(region.get_node("PlayerLand").find_children("*", "CollisionShape3D", true, false).size() > 0, "Begehbares Gelände hat Kollision")
		region.queue_free()
		await _frames()
	_check(int(counts[0].trees) < int(counts[2].trees), "LOW pflanzt weniger Wald als HIGH: %s" % str(counts))
	_check(int(counts[0].terrain) < int(counts[2].terrain), "LOW nutzt gröberes Geländenetz: %s" % str(counts))
	performance.call("set_profile", 1, false)
	print("[VillageTerrain] counts ", JSON.stringify(counts))
	if failures.is_empty():
		print("[VillageTerrain] PASS checks=", checks)
		quit(0)
	else:
		print("[VillageTerrain] FAIL checks=", checks, " failures=", failures)
		quit(1)
