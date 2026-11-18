extends SceneTree
## Große Stadt in der echten Dorfszene: 4.000 Menschen (3.000 + 1.000 Wachen),
## Versorgung aus eigenen Höfen, Verbände auf der Karte, Nachbarstädte mit
## Baustellen. Prüft Laden aus dem Spielstand, Auswahl per Finger bis in die
## Ecken der 65 × 65-Stadt, Lumo zu Fuß am Rand, Felder ziehen, Verbände im
## Dialog und den Tageswechsel. Mit `-- --capture` (echter Renderer und
## LUMO_CAPTURE_DIR) entstehen Belegbilder in 1812 × 2176.
## Zeiten sind Container-Messungen, keine Handywerte.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const ECONOMY = preload("res://scripts/creative/build_settlement_economy.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const SUPPLY = preload("res://scripts/creative/build_village_supply.gd")
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const CHILD := "village_bigcity_regression"
const SLOT := 5
var checks := 0
var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_warning("[VillageBigCity] " + message)


func _frames(count := 4) -> void:
	for _frame in range(count):
		await process_frame


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	for _i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null:
		_check(
			image.save_png(capture_dir.path_join(name + ".png")) == OK, name + ": Bild gespeichert"
		)
		print("[VillageBigCity] Bild ", capture_dir.path_join(name + ".png"), " ", image.get_size())


## Alle drei Nachbarstädte mit Namensschild sichtbar (zwischen den Leisten).
func _check_town_signs(city, label: String) -> void:
	var view: Rect2 = city.get_viewport().get_visible_rect()
	var seen := 0
	for id in ["leo", "ella", "flitz"]:
		var holder: Node = city.neighbors_view.get_node_or_null("Neighbor_" + id)
		var sign: Label3D = holder.get_node_or_null("TownSign") if holder != null else null
		if sign == null or city.camera.is_position_behind(sign.global_position):
			continue
		var point: Vector2 = city.camera.unproject_position(sign.global_position)
		# Schilder sind breit: ihr Ankerpunkt muss deutlich innerhalb liegen.
		if view.grow_individual(-view.size.x * 0.14, -20.0, -view.size.x * 0.14, -20.0).has_point(
			point
		):
			seen += 1
	_check(seen == 3, "%s: alle drei Nachbarstädte mit Schild im Bild (%d)" % [label, seen])


## Verbände-Tafel: nichts seitlich abgeschnitten, Touch-Ziele ≥ 126 px, alles erreichbar.
func _check_board(city, screen: Vector2i) -> void:
	var board: Control = city.troop_board
	var scale: float = root.get_final_transform().x.x
	var area: Rect2 = board.get_global_rect()
	var safe: Rect2 = city.safe_ui.get_global_rect()
	_check(safe.grow(1.0).encloses(area), "%s: Tafel liegt ganz im Bild" % str(screen))
	_check(
		area.size.y >= safe.size.y * 0.45,
		"%s: Tafel ist groß (%.0f von %.0f)" % [str(screen), area.size.y, safe.size.y]
	)
	var buttons := 0
	var small := 0
	var cut := 0
	for node in board.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.is_visible_in_tree():
			continue
		buttons += 1
		var rect := button.get_global_rect()
		if rect.size.y * scale < 125.5 or rect.size.x * scale < 125.5:
			small += 1
		if rect.position.x < area.position.x - 1.0 or rect.end.x > area.end.x + 1.0:
			cut += 1
	_check(buttons >= 4 * 3 + 5, "%s: alle Knöpfe da (%d)" % [str(screen), buttons])
	_check(small == 0, "%s: Touch-Ziele mindestens 126 px (%d zu klein)" % [str(screen), small])
	_check(cut == 0, "%s: kein Knopf seitlich abgeschnitten (%d)" % [str(screen), cut])
	var cards := board.find_children("TroopCard_*", "", true, false)
	_check(cards.size() == 4, "%s: vier Truppenkarten" % str(screen))
	for card in cards:
		var rect: Rect2 = (card as Control).get_global_rect()
		_check(
			rect.position.x >= area.position.x - 1.0 and rect.end.x <= area.end.x + 1.0,
			"%s: %s passt in die Breite" % [str(screen), card.name]
		)
	var scroll: ScrollContainer = board.find_child("TroopBoardScroll", true, false)
	var content: Control = scroll.get_child(0)
	_check(
		scroll.get_v_scroll_bar().max_value >= content.size.y - 1.0,
		"%s: der ganze Inhalt ist durch Rollen erreichbar" % str(screen)
	)
	print(
		(
			"[VillageBigCity] Tafel %s: Maßstab %.2f, %d Knöpfe, Fläche %s, Inhalt %.0f hoch"
			% [str(screen), scale, buttons, str(area.size), content.size.y]
		)
	)


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
		_check(GUARDS.build_site(model, raids, site).is_empty(), "Ausbildungsstätte " + site)
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
		var error := GUARDS.train(model, raids, 100, order[0], order[1])
		_check(error.is_empty(), "100 %s am %s: %s" % [order[1], order[0], error])
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


func _screen_of(city, plot: int) -> Vector2:
	return city.camera.unproject_position(city._plot_world(plot) + Vector3.UP * 0.1)


func _run() -> void:
	var size := Vector2i(906, 1088)
	if "--capture" in OS.get_cmdline_user_args():
		capture_dir = OS.get_environment("LUMO_CAPTURE_DIR")
		if DisplayServer.get_name() == "headless" or capture_dir.is_empty():
			push_error(
				"[VillageBigCity] Bilder brauchen einen echten Renderer und LUMO_CAPTURE_DIR"
			)
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(capture_dir)
		size = Vector2i(1812, 2176)
		var wanted := OS.get_environment("LUMO_CAPTURE_SIZE").split("x")
		if wanted.size() == 2 and wanted[0].is_valid_int() and wanted[1].is_valid_int():
			size = Vector2i(int(wanted[0]), int(wanted[1]))
	root.size = size
	var made := _city()
	var model = made.model
	var raids = made.raids
	var neighbors = made.neighbors
	_check(
		STATE.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) != null,
		"Großstadt ist ein gültiger Spielstand"
	)
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
		"settlement": model.snapshot(),
		"mode": "settlement",
		"slot": SLOT,
		"village_meta":
		{
			"meta_version": 1,
			"raids": raids.snapshot(model),
			"neighbors": neighbors.snapshot(),
			"tutorial": {"done": true, "step": 99, "version": 1}
		}
	}
	var text := JSON.stringify(envelope)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print(
		(
			"[VillageBigCity] Spielstand %d Bytes, %d Gebäude, %d Wachen"
			% [text.length(), model._player.buildings.size(), int(raids.guards)]
		)
	)
	var started := Time.get_ticks_usec()
	var city = load("res://scenes/creative/build_settlement_world.tscn").instantiate()
	root.add_child(city)
	await _frames(6)
	var open_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if is_instance_valid(city.tutorial) and city.tutorial.has_method("skip"):
		city.tutorial.skip()
	_check(int(city.model._player.population) == 4000, "Stadt mit 4.000 Menschen geladen")
	_check(
		int(city.raids.guards) == 1000 and GUARDS.total(city.raids) == 1000,
		"1.000 gespeicherte Wachen geladen"
	)
	_check(city.raids.units.size() == 5, "Verbände geladen (%d)" % city.raids.units.size())
	_check(
		(
			GUARDS.count_of(city.raids, "reiter") == 200
			and int(city.model._player.troop_upkeep) == 200
		),
		"200 Reiter, ihre Pferde essen mit"
	)
	_check(
		city.guards_view.find_children("Formation_reiter", "", true, false).size() == 1,
		"Reiter-Gruppe mit eigenem Modell auf der Karte"
	)
	_check(int(city.guards_view.get_meta("total", 0)) == 1000, "Kartenschilder zeigen 1.000 Wachen")
	_check(
		int(city.guards_view.get_meta("shown_figures", 0)) <= 5 * 24,
		(
			"Aus der Ferne repräsentative Gruppen statt 1.000 Figuren (%d)"
			% int(city.guards_view.get_meta("shown_figures", 0))
		)
	)
	_check(
		int(city.guards_view.get_meta("sites", 0)) == 3,
		"Kaserne, Schießplatz und Stall stehen als Gebäude auf der Karte"
	)
	var nord_holder: Node = city.guards_view.get_node_or_null("Post_nord")
	_check(
		nord_holder != null and nord_holder.get_node_or_null("Banner") != null,
		"Banner mit Truppenzeichen am Nordtor"
	)
	var reserve := SUPPLY.town_reserve(city.model, city.model._player)
	_check(
		int(reserve.balance) >= 0,
		"Eigene Ernte versorgt die Stadt (%d Überschuss am Tag)" % int(reserve.balance)
	)
	_check(
		city.resource_chips.food.tooltip_text.contains("Vorrat reicht noch"),
		"Vorratsanzeige: " + city.resource_chips.food.tooltip_text
	)
	# Nachbarstädte mit Baustellen und Befestigung.
	_check(
		not city.neighbors.current_project("leo").is_empty(),
		"Burgheim baut gerade: " + str(city.neighbors.current_project("leo"))
	)
	var signs := 0
	for id in city.neighbors_view.project_signs:
		if city.neighbors_view.project_signs[id].visible:
			signs += 1
	_check(signs >= 1, "Baustellenschilder über den Nachbarstädten (%d)" % signs)
	_check(city.neighbors_view.walls.has("leo"), "Burgheims Befestigung steht auf der Karte")
	# Übersicht der ganzen Stadt.
	city.focus = Vector3(-REGION.TOWN_CENTER + 10.0, 0, 0)
	city.radius = 170.0
	city.tilt = 0.95
	city.orbit = -0.25
	city._clamp_focus()
	started = Time.get_ticks_usec()
	city._rebuild()
	city._camera_update(true)
	var rebuild_ms := float(Time.get_ticks_usec() - started) / 1000.0
	await _frames(8)
	_check(
		int(city.get_meta("detailed_facilities", 0)) <= 96,
		"Höchstens 96 Detailgebäude, der Rest gebündelt"
	)
	await _capture("01_grossstadt_uebersicht")
	# Nah: Verband am Nordtor.
	var north: Vector3 = city.guards_view.post_position("nord")
	city.focus = north + Vector3(0, 0, 10)
	city.radius = 30.0
	city.tilt = 0.5
	city.orbit = -0.5
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _frames(8)
	await _capture("02_bogenschuetzen_nordtor_nah")
	var south: Vector3 = city.guards_view.post_position("sued")
	city.focus = south + Vector3(0, 0, 6)
	city.radius = 26.0
	city.tilt = 0.45
	city.orbit = 0.6
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _frames(8)
	await _capture("02b_reiter_suedtor_nah")
	# Wohnviertel nah.
	city.focus = Vector3(-REGION.TOWN_CENTER + 20.0, 0, 18.0)
	city.radius = 46.0
	city.tilt = 0.62
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _frames(8)
	await _capture("03_grossstadt_nah")
	# Nachbarstädte mit Baustellen.
	city.show_neighbor_towns()
	await _frames(8)
	_check_town_signs(city, "Hochformat")
	await _capture("04_nachbarstaedte_karte")
	var portrait_size := root.size
	root.size = Vector2i(portrait_size.y, portrait_size.x)
	await _frames(4)
	city._layout()
	city.show_neighbor_towns()
	await _frames(8)
	_check_town_signs(city, "Querformat")
	await _capture("04b_nachbarstaedte_karte_quer")
	root.size = portrait_size
	await _frames(4)
	city._layout()
	city.focus = Vector3(190.0, 0, 2.0)
	city.radius = 62.0
	city.tilt = 0.6
	city.orbit = 0.35
	city._clamp_focus()
	city._rebuild()
	city._camera_update(true)
	await _frames(8)
	await _capture("05_burgheim_befestigung_nah")
	# Auswahl per Finger in allen vier Ecken der größten Stadt.
	city.radius = 40.0
	city.tilt = 0.75
	city.orbit = 0.0
	for corner in [
		Vector2i(-32, -32), Vector2i(-32, 32), Vector2i(32, -32), Vector2i(32, 32), Vector2i(-31, 0)
	]:
		var plot := REGION.plot_index_at(corner)
		var where: Vector3 = city._plot_world(plot)
		city.focus = where
		city._clamp_focus()
		city._rebuild()
		city._camera_update(true)
		await _frames(4)
		var picked: int = city.plot_at_screen(_screen_of(city, plot))
		_check(picked == plot, "Finger trifft Eckfeld %s (%d → %d)" % [str(corner), plot, picked])
		if city.model.plot_buildable(plot):
			city._pick_plot(_screen_of(city, plot))
			_check(city.selected_plot == plot, "Eckfeld %s wird ausgewählt" % str(corner))
	# Felder ziehen: freie Plätze am Ostufer, ein Fingerzug.
	var start := -1
	for index in range(4224, 0, -1):
		if city.model.plot_buildable(index) and TERRAIN.plot_far_bank(index):
			var used := false
			for building in city.model._player.buildings:
				if int(building.plot) == index:
					used = true
					break
			if not used:
				start = index
				break
	_check(start >= 0, "Freie Plätze am Ostufer für Felder")
	if start >= 0:
		var cell := REGION.plot_coordinate(start)
		var finish := REGION.plot_index_at(cell - Vector2i(signi(cell.x), signi(cell.y)) * 3)
		city.focus = (city._plot_world(start) + city._plot_world(finish)) * 0.5
		city.radius = 36.0
		city.tilt = 0.9
		city._rebuild()
		city._camera_update(true)
		await _frames(4)
		var farms_before: int = city.model._count(city.model._player, "farm")
		city._toggle_field_drag()
		_check(city.field_drag, "„Felder ziehen“ ist an")
		city._field_drag_begin(_screen_of(city, start))
		city._field_drag_update(_screen_of(city, finish))
		print(
			(
				"[VillageBigCity] Felder ziehen von %d %s nach %d %s: Zug %d → %d, Bildschirm %s → %s, %s"
				% [
					start,
					str(cell),
					finish,
					str(REGION.plot_coordinate(finish)),
					city.drag_from,
					city.drag_to,
					str(_screen_of(city, start)),
					str(_screen_of(city, finish)),
					city.feedback.text
				]
			)
		)
		_check(
			city.field_preview != null and city.field_preview.visible, "Vorschau-Rechteck sichtbar"
		)
		await _capture("06_felder_ziehen_vorschau")
		city._field_drag_finish()
		var farms_after: int = city.model._count(city.model._player, "farm")
		_check(
			farms_after > farms_before + 4,
			"Ein Zug legt viele Höfe an (%d → %d)" % [farms_before, farms_after]
		)
		city._toggle_field_drag()
	# Lumo zu Fuß am äußersten Westrand.
	city._toggle_walk()
	var edge: Vector3 = city._plot_world(REGION.plot_index_at(Vector2i(-32, 0)))
	city.explorer.start_at(edge + Vector3.UP * 0.1)
	for _i in range(20):
		city._physics_process(1.0 / 60.0)
		await physics_frame
	_check(
		int(city.explorer.rescue_count) == 0, "Lumo steht am Westrand auf Gelände (keine Rettung)"
	)
	city._toggle_walk()
	# Verbände im Dialog: öffnen, zusammenlegen.
	city._guard_units_dialog()
	await _frames(3)
	_check(
		city.troop_board.visible and city.troop_board.name == "TroopBoard",
		"Verbände-Tafel geöffnet"
	)
	_check(city.dock_section() == "schuetzen", "Tafel gehört zum Bereich „Schützen“")
	if city.troop_board.visible:
		var before_size := root.size
		# Wie auf dem Gerät: Fold mit 2,625 Pixeln je dp. Die Dorfszene rechnet
		# ihre Fläche selbst aus Fenstergröße und Dichte (creative_runtime.gd).
		var bridge: Node = root.get_node("HostBridge")
		var options: Dictionary = bridge.get("_options")
		for screen in [Vector2i(1812, 2176), Vector2i(1080, 2340), Vector2i(2176, 1812)]:
			options["displayDensity"] = 2.625
			bridge.set("_options", options)
			root.size = screen
			await _frames(4)
			city._layout()
			await _frames(4)
			city._layout()
			await _frames(3)
			_check_board(city, screen)
			await _capture("07_verbaende_tafel_%dx%d" % [screen.x, screen.y])
		options.erase("displayDensity")
		bridge.set("_options", options)
		root.size = before_size
		await _frames(4)
		city._layout()
		await _frames(2)
		city.troop_board_action("regroup", "", 0)
		await _frames(4)
	_check(
		int(city.raids.guards) == 1000 and city.raids.units.size() <= 5,
		"Zusammengelegt: 1.000 Wachen in höchstens 5 Verbänden"
	)
	city.troop_board.close()
	await _frames(3)
	# Tageswechsel in der Szene (Stadt, Nachbarn, Angriffsplan, Speichern).
	started = Time.get_ticks_usec()
	city._next_day()
	var day_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(int(city.model.day) == 41, "Tag 41")
	_check(int(city.model._player.food_shortfall) == 0, "Nach dem Tageswechsel sind alle satt")
	_check(int(city.raids.guards) == 1000, "Alle 1.000 Wachen nach dem Tageswechsel")
	var saved_text := FileAccess.get_file_as_string(path)
	var raw: Variant = JSON.parse_string(saved_text)
	_check(
		raw is Dictionary and int(raw.village_meta.raids.guards) == 1000,
		"Gespeichert mit 1.000 Wachen (%d Bytes)" % saved_text.length()
	)
	print(
		(
			"[Tabelle] Großstadt-Szene (Container) | Öffnen %.0f ms | Neuaufbau Übersicht %.1f ms | Tageswechsel mit Speichern %.1f ms | Spielstand %d Bytes"
			% [open_ms, rebuild_ms, day_ms, saved_text.length()]
		)
	)
	city.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(path)
	var soundscape := root.get_node_or_null("GameSoundscape")
	if soundscape != null and soundscape.has_method("release_audio"):
		soundscape.release_audio()
	for _i in range(24):
		await process_frame
	if failures.is_empty():
		print("[VillageBigCity] PASS checks=%d" % checks)
		quit(0)
	else:
		print("[VillageBigCity] FAIL checks=%d failures=%s" % [checks, JSON.stringify(failures)])
		quit(1)
