extends SceneTree
## Leistungsmessung (Container, kein Handywert): die 4.000-Menschen-Stadt aus
## build_village_bigcity_regression.gd in der echten Szene, zwei Ansichten
## (Übersicht, Nordtor nah). Gibt Zeichenaufrufe, Dreiecke (Primitive) und
## Bildzeit aus. Nur mit Renderer (xvfb, gl_compatibility):
##   -- <breite> <hoehe>
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const ECONOMY = preload("res://scripts/creative/build_settlement_economy.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const SUPPLY = preload("res://scripts/creative/build_village_supply.gd")
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const CHILD := "village_render_probe"
const SLOT := 4


func _initialize() -> void:
	call_deferred("_run")


## Stadt nach den Spielregeln: innen Häuser mit Brunnen, Märkten, Lernhäusern
## und Werkstätten, außen die Felder. Alles auf bebaubaren Plätzen.
func _city() -> Dictionary:
	var plan := SUPPLY.plan(3000, 1000, 8, true)
	var model = STATE.new("settlement", true)
	var town: Dictionary = model._player
	town.city_projects = {"irrigation": true, "bridge": true}
	town.region = ECONOMY.PLOTS.size() - 1
	town.plots = int(ECONOMY.PLOTS[town.region])
	var services := {
		"market": 24,
		"school": 12,
		"lumber": 16,
		"quarry": 16,
		"road": 40,
		"clinic": 8,
		"bakery": 6,
		"grain": 6
	}
	var inner: Array[String] = []
	var houses := int(plan.houses)
	var wells := int(plan.wells)
	var extra: Array[String] = []
	for kind in services:
		for _i in range(int(services[kind])):
			extra.append(kind)
	var step := 0
	while houses > 0 or wells > 0 or not extra.is_empty():
		if step % 4 == 3 and wells > 0:
			inner.append("well")
			wells -= 1
		elif step % 23 == 11 and not extra.is_empty():
			inner.append(extra.pop_back())
		elif houses > 0:
			inner.append("house")
			houses -= 1
		elif wells > 0:
			inner.append("well")
			wells -= 1
		else:
			inner.append(extra.pop_back())
		step += 1
	for _i in range(int(plan.farms)):
		inner.append("farm")
	town.buildings = []
	var index := 0
	for kind in inner:
		while not model.plot_buildable(index):
			index += 1
		town.buildings.append(
			{"id": "b%d" % (town.buildings.size() + 1), "kind": kind, "plot": index}
		)
		index += 1
	town.next_id = town.buildings.size() + 1
	town.households = []
	town.population = 4000
	ECONOMY.reconcile_households(town)
	town.resources = {"wood": 3000, "stone": 3000, "food": 6000, "coins": 1900}
	town.crops = {"carrots": 6000, "grain": 0, "bread": 0}
	var spent := int(ECONOMY.PROJECTS.irrigation.cost) + int(ECONOMY.PROJECTS.bridge.cost)
	town.income_total = spent * 5 + 50
	town.tax_total = town.income_total / 5
	town.tax_remainder = 0
	town.treasury = int(town.tax_total) - spent
	town.campaign_chapter = 12
	model.day = 40
	var raids = load("res://scripts/creative/build_village_raids.gd").restore(null, model)
	# Aufstellung nach den Gegnern: Bogenschützen nach Norden (Funkel fliegt),
	# Reiter nach Süden (Plünderer), Speerträger nach Osten (Belagerer).
	for site in ["schiessplatz", "kaserne", "stall"]:
		GUARDS.build_site(model, raids, site)
	for order in [
		["nord", "bogen"],
		["nord", "bogen"],
		["ost", "speer"],
		["ost", "speer"],
		["sued", "reiter"],
		["sued", "reiter"],
		["west", "schild"],
		["west", "schild"],
		["mitte", "schild"],
		["mitte", "schild"]
	]:
		GUARDS.train(model, raids, 100, order[0], order[1])
	var neighbors = NEIGHBORS.new()
	var dummy = STATE.new("settlement", true)
	# Bis Burgheim gerade die letzte Stufe seiner Befestigung baut (Wehrtürme
	# als Baustelle neben fertiger Mauer), höchstens 150 Tage.
	var guard := 0
	while int(neighbors.fort.building) != 2 and guard < 150:
		neighbors.advance_day(dummy)
		guard += 1
	print("[VillageBigCity] Nachbarn nach %d Tagen, Befestigung %s" % [guard, str(neighbors.fort)])
	return {"model": model, "raids": raids, "neighbors": neighbors}


func _measure(label: String) -> void:
	for _i in range(30):
		await process_frame
	var calls := 0
	var primitives := 0
	var frames := 20
	var started := Time.get_ticks_usec()
	for _i in range(frames):
		await RenderingServer.frame_post_draw
		calls += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)
		primitives += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		)
	var ms := float(Time.get_ticks_usec() - started) / 1000.0 / float(frames)
	print(
		(
			"[RenderProbe] %s | Zeichenaufrufe %d | Dreiecke %d | Bildzeit %.1f ms (Container)"
			% [label, calls / frames, primitives / frames, ms]
		)
	)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(
		int(args[0]) if args.size() > 0 else 1812, int(args[1]) if args.size() > 1 else 2176
	)
	var made := _city()
	var router := root.get_node("SceneRouter")
	router.launch_options = {
		"childKey": CHILD, "buildSlot": SLOT, "settlementMode": "settlement", "livingVillage": true
	}
	var script = load("res://scripts/creative/build_settlement_world.gd")
	var path: String = script.project_path(CHILD, SLOT, "village")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var envelope := {
		"version": 1,
		"child": CHILD,
		"settlement": made.model.snapshot(),
		"mode": "settlement",
		"slot": SLOT,
		"village_meta":
		{
			"meta_version": 1,
			"raids": made.raids.snapshot(made.model),
			"neighbors": made.neighbors.snapshot(),
			"tutorial": {"done": true, "step": 99, "version": 1}
		}
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	var city = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(city)
	for _i in range(6):
		await process_frame
	if is_instance_valid(city.tutorial) and city.tutorial.has_method("skip"):
		city.tutorial.skip()
	city.focus = Vector3(-REGION.TOWN_CENTER + 10.0, 0, 0)
	city.radius = 170.0
	city.tilt = 0.95
	city.orbit = -0.25
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _measure("Übersicht r=170")
	var north: Vector3 = city.guards_view.post_position("nord")
	city.focus = north + Vector3(0, 0, 10)
	city.radius = 30.0
	city.tilt = 0.5
	city.orbit = -0.5
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _measure("Nordtor nah r=30")
	city.focus = Vector3(-REGION.TOWN_CENTER, 0, 0)
	city.radius = 60.0
	city.tilt = 0.8
	city.orbit = 0.3
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _measure("Stadtmitte r=60")
	quit(0)
