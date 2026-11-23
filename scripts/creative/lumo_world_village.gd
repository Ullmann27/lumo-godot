extends Node3D
## Read-only view of the existing village save. There is no second economy,
## duplicated save or automatic day advancement in World.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const REGION = preload("res://scripts/creative/build_settlement_region.gd")
const TERRAIN = preload("res://scripts/creative/build_village_terrain.gd")
const YARDS = preload("res://scripts/creative/build_village_yards.gd")
const VISUAL = preload("res://scripts/creative/build_settlement_visual.gd")
const ART = preload("res://scripts/creative/build_village_art.gd")
const RESIDENTS = preload("res://scripts/creative/build_settlement_residents.gd")
const ORIGIN := Vector3(600, 0, 0)
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
		if parser.parse(FileAccess.get_file_as_string(source_path)) == OK:
			model = restore_existing(parser.data, child_key, slot)
		source_status = "loaded" if model != null else "invalid"
	if model == null:
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
	var buildings: Array = model.player().buildings
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


func doorway() -> Vector3:
	return ORIGIN + Vector3(-100, TERRAIN.height(-100, 12), 12)


func summary() -> String:
	if model == null:
		return "Dieser Dorfspielstand konnte nicht gelesen werden." if source_status == "invalid" else "Hier wächst dein eigenes Dorf. Am Bauplatz öffnest du deinen vorhandenen Dorfspielstand."
	var town: Dictionary = model.player()
	return "Dein Dorf · Spielstand %d · Tag %d · %d Gebäude · %d Bewohner" % [slot, model.day, town.buildings.size(), int(town.population)]
