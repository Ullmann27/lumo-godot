extends Node3D
## The existing living-village economy projected directly into Lumo World.
## This is the single authoritative village model/save: World does not create
## a second economy. Building, production and expansion operate on this model.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const YARDS = preload("res://scripts/creative/build_village_yards.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const RESIDENTS = preload("res://scripts/creative/build_settlement_residents.gd")
const ORIGIN := Vector3(600, 0, 0)
const WEST_ENTRY_X := -320.0
const WEST_ENTRY_BLEND_WIDTH := 20.0
const MAX_NEAR := 80
var model
var region: Node3D
var residents: Node3D
var facilities: Dictionary = {}
var far_nodes: Array[Node3D] = []
var source_path := ""
var source_status := "empty"
var child_key := "standalone"
var slot := 1
var last_focus := Vector3.INF
var village_meta: Dictionary = {}


static func save_path_for(child: String, project_slot: int) -> String:
	return "user://lumo_settlement_%s_%d_village.json" % [child.sha256_text(), clampi(project_slot, 1, 6)]


static func restore_existing(raw: Variant, child: String, project_slot: int):
	if not raw is Dictionary or raw.get("version") != 1:
		return null
	if raw.get("child") != child or raw.get("slot") != project_slot or raw.get("mode") != "settlement":
		return null
	if not raw.get("settlement") is Dictionary:
		return null
	var restored = STATE.restore(raw.settlement)
	return restored if restored != null and restored.mode == "settlement" and restored.living_village else null


func setup(child: String, project_slot: int) -> void:
	child_key = child if not child.is_empty() else "standalone"
	slot = clampi(project_slot, 1, 6)
	source_path = save_path_for(child_key, slot)
	position = ORIGIN
	region = REGION.new()
	# The authored heightmap now starts at -440, not -320. Importing its
	# western mountains unchanged put a 70m ridge across Sonnendorf's road.
	# Crop only this projection; all saved plots begin east of the blend.
	region.terrain_west_entry_x = WEST_ENTRY_X
	region.terrain_west_entry_blend_width = WEST_ENTRY_BLEND_WIDTH
	add_child(region)
	region.build_landscape("settlement")
	# The original terrain paints paths in world coordinates; translate only
	# this instance's lookup rectangles with its position in the larger World.
	var terrain_material: ShaderMaterial = region.landscape.terrain_material
	var paint_rect: Vector4 = terrain_material.get_shader_parameter("paint_rect")
	paint_rect.x += ORIGIN.x
	terrain_material.set_shader_parameter("paint_rect", paint_rect)
	var water_material: ShaderMaterial = region.landscape.water_material
	var depth_rect: Vector4 = water_material.get_shader_parameter("depth_rect")
	depth_rect.x += ORIGIN.x
	water_material.set_shader_parameter("depth_rect", depth_rect)
	if FileAccess.file_exists(source_path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(source_path)) == OK and parser.data is Dictionary:
			model = restore_existing(parser.data, child_key, slot)
			if parser.data.get("village_meta", {}) is Dictionary:
				village_meta = parser.data.get("village_meta", {}).duplicate(true)
			source_status = "loaded" if model != null else "invalid"
		else:
			source_status = "invalid"
	if model == null and source_status != "invalid":
		# First Open-World entry creates the official living-village model in
		# memory. It is persisted only after an explicit build/day/expand action.
		model = STATE.new("settlement", true)
		source_status = "new"
	if model == null:
		# Never replace unreadable/foreign village bytes with a new economy.
		region.set_unlocked_plots(0, false)
		return
	var town: Dictionary = model.player()
	region.set_unlocked_plots(int(town.plots), false)
	region.set_far_bank_open(bool(town.get("city_projects", {}).get("bridge", false)))
	var built: Array = []
	for building in town.buildings:
		built.append(int(building.plot))
	region.set_built_plots(built, false)
	var yards := YARDS.new()
	add_child(yards)
	yards.sync(town.get("yards", []))
	residents = RESIDENTS.new()
	add_child(residents)
	residents.configure(LumoQuality.tier())
	residents.sync(town)
	update_focus(ORIGIN + Vector3(-100, 0, 0), 0.0)
	set_meta("projected_buildings", town.buildings.size())
	set_meta("source_path", source_path)
	set_meta("source_child", child_key)


func surface_height(world_x: float, world_z: float) -> float:
	return region.landscape.surface_height(world_x - ORIGIN.x, world_z - ORIGIN.z)


func update_focus(world_position: Vector3, delta: float) -> void:
	var local := world_position - ORIGIN
	region.update_focus(local)
	region.advance(delta)
	if is_instance_valid(residents):
		residents.set_focus(local)
		residents.advance(delta, false)
	if model == null or local.distance_squared_to(last_focus) < 100.0:
		return
	last_focus = local
	var buildings: Array = model.player().buildings.duplicate(true)
	var distances: Dictionary = {}
	for building in buildings:
		distances[str(building.id)] = YARDS.building_at(building).distance_squared_to(local)
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(distances[str(a.id)]) < float(distances[str(b.id)]))
	var active: Dictionary = {}
	var far: Dictionary = {}
	var near_count := 0
	for building in buildings:
		var id := str(building.id)
		var at: Vector3 = YARDS.building_at(building) + Vector3.UP * 0.06
		var variant := posmod(int(building.plot) * 7, 3)
		var yaw := (float(posmod(int(building.plot) * 13, 5)) - 2.0) * 0.035
		if near_count < MAX_NEAR and float(distances[id]) < 60.0 * 60.0:
			near_count += 1
			active[id] = true
			if not facilities.has(id):
				var node: StaticBody3D = VISUAL.create(str(building.kind), false, variant)
				node.position = at
				node.rotation.y = yaw
				node.set_meta("saved_building_id", id)
				node.set_meta("saved_plot", int(building.plot))
				add_child(node)
				facilities[id] = node
		else:
			var model_name: String = VISUAL.model_for(str(building.kind), variant)
			if not far.has(model_name):
				far[model_name] = []
			far[model_name].append(Transform3D(Basis(Vector3.UP, yaw), at))
	for id in facilities.keys():
		if not active.has(id):
			facilities[id].queue_free()
			facilities.erase(id)
	for node in far_nodes:
		node.queue_free()
	far_nodes.clear()
	for model_name in far:
		var node: MultiMeshInstance3D = ART.batch(self, "SavedFar_" + model_name, model_name, far[model_name], 0.0, false)
		if node != null:
			far_nodes.append(node)


func save() -> bool:
	if model == null or source_status == "invalid":
		return false
	var file := FileAccess.open(source_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 1,
		"child": child_key,
		"settlement": model.snapshot(),
		"mode": "settlement",
		"slot": slot,
		"village_meta": village_meta
	}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(source_path + ".tmp", source_path) != OK:
		return false
	source_status = "loaded"
	return true


func _refresh_projection() -> void:
	if model == null:
		return
	var town: Dictionary = model.player()
	region.set_unlocked_plots(int(town.plots), false)
	region.set_far_bank_open(bool(town.get("city_projects", {}).get("bridge", false)))
	var built: Array = []
	for building in town.buildings:
		built.append(int(building.plot))
	region.set_built_plots(built, false)
	if is_instance_valid(residents):
		residents.sync(town)
	last_focus = Vector3.INF
	update_focus(ORIGIN + Vector3(-REGION.TOWN_CENTER, 0, 0), 0.0)
	set_meta("projected_buildings", town.buildings.size())


func town() -> Dictionary:
	return model.player() if model != null else {}


func build_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if model == null:
		return result
	for kind in STATE.BUILDINGS.keys():
		var spec: Dictionary = STATE.BUILDINGS[kind]
		result.append({
			"kind": str(kind),
			"title": str(spec.title),
			"cost": model.building_cost(str(kind))
		})
	return result


func plot_world(plot: int) -> Vector3:
	if model == null or plot < 0 or plot >= int(model.player().plots):
		return ORIGIN
	var local := REGION.plot_position(plot, false)
	return ORIGIN + local


func plot_from_world(world_position: Vector3) -> int:
	if model == null:
		return -1
	var local := world_position - ORIGIN
	var coordinate := Vector2i(
		roundi((local.x + REGION.TOWN_CENTER) / REGION.SPACING),
		roundi(local.z / REGION.SPACING)
	)
	var plot := REGION.plot_index_at(coordinate)
	return plot if plot >= 0 and plot < int(model.player().plots) else -1


func plot_buildable(plot: int) -> bool:
	return model != null and plot >= 0 and plot < int(model.player().plots) and model.plot_buildable(plot)


func next_free_plot(after := -1) -> int:
	if model == null:
		return -1
	var town_state: Dictionary = model.player()
	var used: Dictionary = {}
	for building in town_state.buildings:
		used[int(building.plot)] = true
	var count := int(town_state.plots)
	for offset in range(count):
		var plot := posmod(after + 1 + offset, count)
		if not used.has(plot) and model.plot_buildable(plot) and model.site_available(town_state, plot):
			return plot
	return -1


func try_build(kind: String, plot: int) -> Dictionary:
	if model == null or source_status == "invalid":
		return {"ok": false, "message": "Der Dorfspielstand ist nicht verfügbar."}
	if not model.try_build(kind, plot):
		return {"ok": false, "message": model.last_error}
	if not save():
		model.undo()
		return {"ok": false, "message": "Das Gebäude konnte nicht sicher gespeichert werden."}
	_refresh_projection()
	var spec: Dictionary = STATE.BUILDINGS.get(kind, {})
	return {"ok": true, "message": "%s gebaut." % str(spec.get("title", kind))}


func advance_day() -> Dictionary:
	if model == null or source_status == "invalid":
		return {"advanced": false, "message": "Der Dorfspielstand ist nicht verfügbar."}
	var report: Dictionary = model.next_day()
	if bool(report.get("advanced", false)):
		if not save():
			model.undo()
			return {"advanced": false, "message": "Der neue Tag konnte nicht sicher gespeichert werden."}
		_refresh_projection()
	return report


func expand_town() -> Dictionary:
	if model == null or source_status == "invalid":
		return {"ok": false, "message": "Der Dorfspielstand ist nicht verfügbar."}
	if not model.expand():
		return {"ok": false, "message": model.last_error}
	if not save():
		model.undo()
		return {"ok": false, "message": "Die Erweiterung konnte nicht sicher gespeichert werden."}
	_refresh_projection()
	return {"ok": true, "message": "Neues Bauland freigeschaltet."}


func resource_text() -> String:
	if model == null:
		return "Dorfwirtschaft nicht geladen"
	var state: Dictionary = model.player()
	var resources: Dictionary = state.resources
	return "Tag %d · Holz %d · Stein %d · Essen %d · Münzen %d · Bewohner %d" % [
		model.day,
		int(resources.wood),
		int(resources.stone),
		int(resources.food),
		int(resources.coins),
		int(state.population)
	]


func doorway() -> Vector3:
	return ORIGIN + Vector3(-100, TERRAIN.height(-100, 12), 12)


func summary() -> String:
	if model == null:
		return "Dieser Dorfspielstand konnte nicht gelesen werden." if source_status == "invalid" else "Hier wächst dein eigenes Dorf. Am Bauplatz öffnest du deinen vorhandenen Dorfspielstand."
	var town: Dictionary = model.player()
	return "Dein Dorf · Spielstand %d · Tag %d · %d Gebäude · %d Bewohner" % [slot, model.day, town.buildings.size(), int(town.population)]
