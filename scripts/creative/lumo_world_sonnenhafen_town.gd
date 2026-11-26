extends Node3D
## Builds Sonnenhafen from the modular Blender kit: quay platform, canal,
## bridges, piers, mole and lighthouse, house rows and landmarks, props,
## street lamps, collision and the navigation mesh for its residents.
## Repeated modules are drawn as MultiMesh batches per town chunk, all with
## the one shared village atlas material (window and lamp glass glow at night).

const LAYOUT = preload("res://scripts/creative/lumo_world_sonnenhafen_layout.gd")
const VILLAGE = preload("res://scripts/creative/build_village_art.gd")
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")
const KIT_DIR := "res://assets/creative/lumo_world/sonnenhafen/kit/"
const KIT_REPORT := KIT_DIR + "kit.json"
const BAY := LAYOUT.BAY
const STOREY := LAYOUT.STOREY
const WALL := LAYOUT.WALL
const CHUNK_WIDTH := 47.0
const TOWN_WEST := 80.0
## Visibility ranges by module class: the shell keeps the town silhouette
## readable from the mainland, details fade out early to save draw time.
const RANGES := {"shell": 320.0, "facade": 170.0, "detail": 85.0, "prop": 95.0, "harbour": 260.0}
const MODULE_CLASS := {
	"wall_plaster": "shell",
	"wall_brick": "shell",
	"wall_planks": "shell",
	"roof_bay": "shell",
	"roof_bay_slate": "shell",
	"roof_hall": "shell",
	"roof_end": "shell",
	"roof_end_planks": "shell",
	"roof_front_gable": "shell",
	"gable_front_wall": "shell",
	"gable_stepped": "shell",
	"quay_edge": "harbour",
	"pier": "harbour",
	"plinth": "facade",
	"cornice": "facade",
	"window_sash": "facade",
	"window_round": "facade",
	"window_shop": "facade",
	"window_loft": "facade",
	"door_house": "facade",
	"door_frame": "facade",
	"door_warehouse": "facade",
	"roof_end_trim": "facade",
	"gable_window": "facade",
	"gable_stepped_trim": "facade",
	"chimney": "facade",
	"dormer": "facade",
	"corner": "facade",
	"lamp_post": "prop",
	"lighthouse": "harbour",
	"crane": "harbour",
	"boat_cutter": "harbour",
	"boat_sail": "harbour",
	"rowboat": "harbour",
	"bridge_road": "harbour",
	"bridge_foot": "harbour"
}
const GROUND_TINTS := {
	"base": "cfc4b0",
	"kai": "c4bcaa",
	"hafenmarkt": "e3d6bc",
	"laternengasse": "d8ccb6",
	"hafenstrasse": "d8ccb6",
	"kanalpromenade": "d3c9b4"
}
const WATER_EDGE_HEIGHT := 1.25
const VILLAGE_TILES := [
	"plaster",
	"planks",
	"beam",
	"roof_clay",
	"roof_slate",
	"thatch",
	"stone_wall",
	"cobble",
	"window",
	"door",
	"cloth",
	"field",
	"metal",
	"bark",
	"leaves",
	"plain"
]

var layout
var world: Node3D
var tile_means: Dictionary = {}
var tintable: Array = []
var batches: Dictionary = {}
var upper_nodes: Dictionary = {}
var nav_region: NavigationRegion3D
var nav_mesh: NavigationMesh
var collision: StaticBody3D
var boats: Array[Dictionary] = []
var market_lights: Array[OmniLight3D] = []
var reduced_motion := false
var quality := "medium"
var clock := 0.0
var module_count := 0
var batch_count := 0
var night := 0.0


func setup(owner_world: Node3D, plan) -> void:
	world = owner_world
	layout = plan
	name = "SonnenhafenTown"
	reduced_motion = bool(world.get("reduced_motion")) if world != null else false
	quality = LumoQuality.tier()
	var report = JSON.parse_string(FileAccess.get_file_as_string(KIT_REPORT))
	if report is Dictionary:
		tile_means = report.get("tile_means_linear", {})
		tintable = report.get("tintable", [])
	collision = StaticBody3D.new()
	collision.name = "SonnenhafenCollision"
	add_child(collision)
	_water()
	_ground()
	_water_edges()
	_bridges()
	_piers_and_mole()
	for entry in layout.buildings:
		_building(entry)
	_props()
	_lamps()
	_boats()
	_trees()
	_flush_batches()
	_navigation()


# --- Batching -------------------------------------------------------------------


func _mesh(module: String) -> Mesh:
	var bundle = VILLAGE.bundle_at(KIT_DIR + module + ".glb", "sonnenhafen_" + module)
	for part in bundle.parts:
		return part.mesh
	return null


## Colour for a tintable module so that the shared shader reproduces the
## Builder's tint formula: instance = target / (2 * tile mean), clamped.
func tint_for(tile: String, target: Color) -> Color:
	if target.is_equal_approx(Color.WHITE):
		return Color(0.5, 0.5, 0.5)
	var mean: Array = tile_means.get(tile, [0.5, 0.5, 0.5])
	var linear := target.srgb_to_linear()
	var low := 0.0 if tile in ["plain", "plaster", "cloth"] else 0.3
	var high := 1.0 if tile in ["plain", "plaster", "cloth"] else 0.7
	return Color(
		clampf(linear.r / maxf(2.0 * float(mean[0]), 0.02), low, high),
		clampf(linear.g / maxf(2.0 * float(mean[1]), 0.02), low, high),
		clampf(linear.b / maxf(2.0 * float(mean[2]), 0.02), low, high)
	)


func _chunk(x: float) -> int:
	return clampi(int((x - TOWN_WEST) / CHUNK_WIDTH), 0, 3)


## Queue one module instance. group "" = shared town chunk; a building id puts
## the instance into that building's own batch (cut-away interiors).
func _add(module: String, xform: Transform3D, color := Color.WHITE, group := "") -> void:
	var key := "%s|%s" % [module, group if not group.is_empty() else "c%d" % _chunk(xform.origin.x)]
	if not batches.has(key):
		batches[key] = {"module": module, "group": group, "transforms": [], "colors": []}
	batches[key].transforms.append(xform)
	batches[key].colors.append(color if module in tintable else Color.WHITE)
	module_count += 1


func _flush_batches() -> void:
	var root := Node3D.new()
	root.name = "SonnenhafenModules"
	add_child(root)
	for key in batches:
		var batch: Dictionary = batches[key]
		var mesh := _mesh(str(batch.module))
		if mesh == null:
			push_warning("[Sonnenhafen] module missing: " + str(batch.module))
			continue
		var transforms: Array = batch.transforms
		var center := Vector3.ZERO
		for xform in transforms:
			center += (xform as Transform3D).origin
		center /= float(transforms.size())
		center.y = 0.0
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = transforms.size()
		var local: Array = []
		for index in range(transforms.size()):
			var placed: Transform3D = transforms[index]
			placed.origin -= center
			multi.set_instance_transform(index, placed)
			multi.set_instance_color(index, batch.colors[index])
			local.append(placed)
		multi.set_meta("authored_transforms", local)
		var node := MultiMeshInstance3D.new()
		node.name = "M_" + str(key).replace("|", "_").replace(":", "_")
		node.multimesh = multi
		node.position = center
		var kind := str(MODULE_CLASS.get(str(batch.module), "detail"))
		node.visibility_range_end = float(RANGES[kind])
		node.visibility_range_end_margin = 10.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if kind in ["detail", "prop"] or quality == "low":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var group := str(batch.group)
		if not group.is_empty():
			if not upper_nodes.has(group):
				var holder := Node3D.new()
				holder.name = "Upper_" + group
				root.add_child(holder)
				upper_nodes[group] = holder
			(upper_nodes[group] as Node3D).add_child(node)
		else:
			root.add_child(node)
		batch_count += 1
	batches.clear()


# --- Ground, water, edges -----------------------------------------------------


func _village_quad(
	parent: Node3D, area: Rect2, height: float, tile: String, color: Color, node_name: String
) -> MeshInstance3D:
	var tiles: Array = VILLAGE_TILES
	var index := tiles.find(tile)
	var uv2 := Vector2((float(index % 4) + 0.5) / 4.0, (float(index / 4) + 0.5) / 4.0)
	var scale := 1.4 if tile == "cobble" else 1.6
	var tint := tint_for(tile, color)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [
		Vector3(area.position.x, height, area.position.y),
		Vector3(area.end.x, height, area.position.y),
		Vector3(area.end.x, height, area.end.y),
		Vector3(area.position.x, height, area.end.y)
	]
	for corner_index in [0, 1, 2, 0, 2, 3]:
		var corner: Vector3 = corners[corner_index]
		st.set_normal(Vector3.UP)
		st.set_color(tint)
		st.set_uv(Vector2(corner.x, corner.z) / scale)
		st.set_uv2(uv2)
		st.add_vertex(corner)
	st.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = VILLAGE.material()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _water() -> void:
	var area: Rect2 = layout.rect(layout.data.water)
	var sea := MeshInstance3D.new()
	sea.name = "SonnenhafenSea"
	var plane := PlaneMesh.new()
	plane.size = area.size
	var detail := 8 if quality == "low" else 32
	plane.subdivide_width = detail
	plane.subdivide_depth = detail
	sea.mesh = plane
	sea.position = Vector3(area.get_center().x, float(layout.data.water_level), area.get_center().y)
	var material := ShaderMaterial.new()
	material.shader = ADVENTURE.shader("sea")
	material.set_shader_parameter("wave_normal", ADVENTURE.texture("water_normal.jpg"))
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var canal: Rect2 = layout.rect(layout.data.canal)
	var canal_sea := MeshInstance3D.new()
	canal_sea.name = "SonnenhafenCanal"
	var canal_plane := PlaneMesh.new()
	canal_plane.size = canal.size
	canal_sea.mesh = canal_plane
	canal_sea.position = Vector3(
		canal.get_center().x, float(layout.data.water_level), canal.get_center().y
	)
	canal_sea.material_override = material
	canal_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canal_sea)


func _ground() -> void:
	var holder := Node3D.new()
	holder.name = "SonnenhafenGround"
	add_child(holder)
	var plat: Rect2 = layout.platform()
	_village_quad(holder, plat, 0.0, "cobble", Color(GROUND_TINTS.base), "Paving")
	var lift := 0.006
	for street in layout.data.streets:
		var tint := Color(str(GROUND_TINTS.get(str(street.id), GROUND_TINTS.base)))
		_village_quad(
			holder, layout.rect(street.rect), lift, "cobble", tint, "Street_" + str(street.id)
		)
		lift += 0.003
	for path in layout.data.get("mainland_paths", []):
		_village_quad(
			holder, layout.rect(path.rect), 0.03, "cobble", Color("d1c6b2"), "Path_" + str(path.id)
		)
	for id in layout.interior_rects:
		var room: Rect2 = layout.interior_rects[id]
		_village_quad(holder, room, 0.04, "planks", Color("c49a6a"), "Floor_" + str(id))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(plat.size.x, 2.0, plat.size.y)
	shape.shape = box
	shape.position = Vector3(plat.get_center().x, -1.0, plat.get_center().y)
	collision.add_child(shape)
	# Quay walls on every water side of the platform.
	for side in _platform_edges(plat):
		var from: Vector2 = side.from
		var to: Vector2 = side.to
		var length := from.distance_to(to)
		var steps := int(ceil(length / 4.0))
		var direction := (to - from) / length
		var outward: Vector2 = side.out
		var yaw := atan2(outward.x, outward.y)
		for index in range(steps):
			var at := from + direction * (float(index) + 0.5) * (length / float(steps))
			var origin := Vector3(at.x, 0.0, at.y) - Vector3(outward.x, 0, outward.y) * 0.5
			var basis := Basis(Vector3.UP, yaw).scaled(
				Vector3(length / float(steps) / 4.0, 1.0, 1.0)
			)
			_add("quay_edge", Transform3D(basis, origin))
	var bank: Rect2 = layout.rect(layout.data.canal)
	var bank_steps := int(ceil(bank.size.x / 4.0))
	for index in range(bank_steps):
		var x := bank.position.x + (float(index) + 0.5) * bank.size.x / float(bank_steps)
		var basis := Basis(Vector3.UP, PI).scaled(
			Vector3(bank.size.x / float(bank_steps) / 4.0, 1.0, 1.0)
		)
		_add("quay_edge", Transform3D(basis, Vector3(x, 0.0, bank.end.y + 0.5)))


func _platform_edges(plat: Rect2) -> Array[Dictionary]:
	return [
		{
			"from": Vector2(plat.position.x, plat.position.y),
			"to": Vector2(plat.end.x, plat.position.y),
			"out": Vector2(0, -1)
		},
		{
			"from": Vector2(plat.position.x, plat.end.y),
			"to": Vector2(plat.end.x, plat.end.y),
			"out": Vector2(0, 1)
		},
		{
			"from": Vector2(plat.position.x, plat.position.y),
			"to": Vector2(plat.position.x, plat.end.y),
			"out": Vector2(-1, 0)
		},
		{
			"from": Vector2(plat.end.x, plat.position.y),
			"to": Vector2(plat.end.x, plat.end.y),
			"out": Vector2(1, 0)
		}
	]


func _wall(from: Vector2, to: Vector2, node_name: String) -> void:
	if from.distance_to(to) < 0.05:
		return
	var shape := CollisionShape3D.new()
	shape.name = node_name
	var box := BoxShape3D.new()
	var horizontal := absf(to.y - from.y) < 0.01
	box.size = Vector3(
		absf(to.x - from.x) if horizontal else 0.3,
		WATER_EDGE_HEIGHT,
		0.3 if horizontal else absf(to.y - from.y)
	)
	shape.shape = box
	shape.position = Vector3((from.x + to.x) * 0.5, WATER_EDGE_HEIGHT * 0.5, (from.y + to.y) * 0.5)
	collision.add_child(shape)


## Invisible safety rails along every waterfront; openings only where a
## bridge, pier or the mole continues the walkway.
func _water_edges() -> void:
	var plat: Rect2 = layout.platform()
	var openings_north: Array[Vector2] = []
	for bridge in layout.data.bridges:
		var area: Rect2 = layout.rect(bridge.rect)
		openings_north.append(Vector2(area.position.x, area.end.x))
	var openings_south: Array[Vector2] = []
	for pier in layout.data.get("piers", []):
		var area: Rect2 = layout.rect(pier.rect)
		openings_south.append(Vector2(area.position.x, area.end.x))
	var mole: Dictionary = layout.data.get("mole", {})
	if not mole.is_empty():
		var area: Rect2 = layout.rect(mole.rect)
		openings_south.append(Vector2(area.position.x, area.end.x))
	_rail_with_openings(
		plat.position.x, plat.end.x, plat.position.y - 0.15, openings_north, "QuayRailNorth"
	)
	_rail_with_openings(
		plat.position.x, plat.end.x, plat.end.y + 0.15, openings_south, "QuayRailSouth"
	)
	_wall(
		Vector2(plat.position.x - 0.15, plat.position.y),
		Vector2(plat.position.x - 0.15, plat.end.y),
		"QuayRailWest"
	)
	_wall(
		Vector2(plat.end.x + 0.15, plat.position.y),
		Vector2(plat.end.x + 0.15, plat.end.y),
		"QuayRailEast"
	)
	var bank: Rect2 = layout.rect(layout.data.canal)
	_rail_with_openings(
		bank.position.x, bank.end.x, bank.end.y + 0.15, openings_north, "MainlandBankRail"
	)


func _rail_with_openings(
	x0: float, x1: float, z: float, openings: Array[Vector2], label: String
) -> void:
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := x0
	var part := 0
	for gap in openings:
		_wall(Vector2(cursor, z), Vector2(gap.x, z), "%s_%d" % [label, part])
		cursor = gap.y
		part += 1
	_wall(Vector2(cursor, z), Vector2(x1, z), "%s_%d" % [label, part])


func _box_collider(center: Vector3, size: Vector3, node_name := "") -> void:
	var shape := CollisionShape3D.new()
	if not node_name.is_empty():
		shape.name = node_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	collision.add_child(shape)


func _bridges() -> void:
	for bridge in layout.data.bridges:
		var area: Rect2 = layout.rect(bridge.rect)
		var road := str(bridge.kind) == "road"
		var module := "bridge_road" if road else "bridge_foot"
		var basis := Basis.IDENTITY.scaled(
			Vector3(area.size.x / (10.0 if road else 4.0), 1.0, area.size.y / 12.0)
		)
		_add(module, Transform3D(basis, Vector3(area.get_center().x, 0.0, area.get_center().y)))
		_box_collider(
			Vector3(area.get_center().x, -0.3, area.get_center().y),
			Vector3(area.size.x, 0.6, area.size.y)
		)
		for side in [-1.0, 1.0]:
			var x: float = area.get_center().x + side * (area.size.x * 0.5 - 0.2)
			_box_collider(Vector3(x, 0.7, area.get_center().y), Vector3(0.4, 1.4, area.size.y))


func _piers_and_mole() -> void:
	for pier in layout.data.get("piers", []):
		var area: Rect2 = layout.rect(pier.rect)
		var steps := int(round(area.size.y / 4.0))
		for index in range(steps):
			var z: float = area.end.y - 2.0 - float(index) * 4.0
			_add("pier", Transform3D(Basis.IDENTITY, Vector3(area.get_center().x, 0.0, z)))
		_box_collider(
			Vector3(area.get_center().x, -0.2, area.get_center().y),
			Vector3(area.size.x, 0.4, area.size.y)
		)
		for side in [-1.0, 1.0]:
			var x: float = area.get_center().x + side * (area.size.x * 0.5 + 0.1)
			_box_collider(
				Vector3(x, WATER_EDGE_HEIGHT * 0.5, area.get_center().y),
				Vector3(0.2, WATER_EDGE_HEIGHT, area.size.y)
			)
		_box_collider(
			Vector3(area.get_center().x, WATER_EDGE_HEIGHT * 0.5, area.position.y - 0.1),
			Vector3(area.size.x, WATER_EDGE_HEIGHT, 0.2)
		)
		for z in [area.position.y + 1.0, area.position.y + area.size.y * 0.5]:
			for side in [-1.0, 1.0]:
				_add(
					"bollard",
					Transform3D(
						Basis.IDENTITY,
						Vector3(area.get_center().x + side * (area.size.x * 0.5 - 0.35), 0.0, z)
					)
				)
	var mole: Dictionary = layout.data.get("mole", {})
	if mole.is_empty():
		return
	var area: Rect2 = layout.rect(mole.rect)
	var tower := Vector3(float(mole.lighthouse[0]), 0.0, float(mole.lighthouse[1]))
	var holder := Node3D.new()
	holder.name = "Mole"
	add_child(holder)
	_village_quad(holder, area, 0.0, "stone_wall", Color("cfc8b8"), "MoleWalk")
	var square := Rect2(Vector2(tower.x, tower.z) - Vector2(8, 8), Vector2(16, 16))
	_village_quad(holder, square, 0.0, "stone_wall", Color("cfc8b8"), "LighthouseSquare")
	for edge in [Vector2(area.position.x, 0.0), Vector2(area.end.x, 0.0)]:
		var steps := int(ceil(area.size.y / 4.0))
		for index in range(steps):
			var z: float = area.end.y - 2.0 - float(index) * area.size.y / float(steps)
			var outward := -1.0 if is_equal_approx(edge.x, area.position.x) else 1.0
			var basis := Basis(Vector3.UP, outward * PI * 0.5).scaled(
				Vector3(area.size.y / float(steps) / 4.0, 1.0, 1.0)
			)
			_add("quay_edge", Transform3D(basis, Vector3(edge.x - outward * 0.5, 0.0, z)))
	for side in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		for index in range(4):
			var along := -6.0 + float(index) * 4.0
			var normal := Vector3(side.x, 0, side.y)
			var tangent := Vector3(side.y, 0, -side.x)
			var at: Vector3 = tower + normal * 7.5 + tangent * along
			if side == Vector2(0, 1) and absf(at.x - area.get_center().x) < 3.5:
				continue
			_add("quay_edge", Transform3D(Basis(Vector3.UP, atan2(side.x, side.y)), at))
	_box_collider(
		Vector3(area.get_center().x, -1.0, area.get_center().y),
		Vector3(area.size.x, 2.0, area.size.y)
	)
	_box_collider(Vector3(tower.x, -1.0, tower.z), Vector3(16, 2.0, 16))
	_box_collider(Vector3(tower.x, 6.0, tower.z), Vector3(7.0, 12.0, 7.0), "LighthouseTower")
	for side in [-1.0, 1.0]:
		var x: float = area.get_center().x + side * (area.size.x * 0.5 + 0.15)
		_box_collider(
			Vector3(x, WATER_EDGE_HEIGHT * 0.5, area.get_center().y),
			Vector3(0.3, WATER_EDGE_HEIGHT, area.size.y)
		)
	for rail in [
		[Vector3(tower.x, 0, tower.z - 8.15), Vector3(16.3, 0, 0.3)],
		[Vector3(tower.x - 8.15, 0, tower.z), Vector3(0.3, 0, 16.3)],
		[Vector3(tower.x + 8.15, 0, tower.z), Vector3(0.3, 0, 16.3)]
	]:
		_box_collider(
			rail[0] + Vector3.UP * WATER_EDGE_HEIGHT * 0.5,
			Vector3(rail[1].x, WATER_EDGE_HEIGHT, rail[1].z)
		)
	for x_side in [-1.0, 1.0]:
		var from := Vector2(tower.x + x_side * 8.15, tower.z + 8.15)
		var inner := Vector2(area.get_center().x + x_side * area.size.x * 0.5, tower.z + 8.15)
		_box_collider(
			Vector3((from.x + inner.x) * 0.5, WATER_EDGE_HEIGHT * 0.5, from.y),
			Vector3(absf(from.x - inner.x), WATER_EDGE_HEIGHT, 0.3)
		)
	_add("lighthouse", Transform3D(Basis.IDENTITY, tower))


# --- Buildings -----------------------------------------------------------------


func _wall_module(style: String) -> String:
	return {"brick": "wall_brick", "planks": "wall_planks"}.get(style, "wall_plaster")


func _wall_tile(style: String) -> String:
	return {"brick": "stone_wall", "planks": "planks"}.get(style, "plaster")


func _building(entry: Dictionary) -> void:
	var xform: Transform3D = layout.frame(entry)
	var bays := int(entry.bays)
	var width := float(bays) * BAY
	var depth := float(entry.depth)
	var storeys := int(entry.storeys)
	var style := str(entry.style)
	var wall := _wall_module(style)
	var wall_color := tint_for(_wall_tile(style), entry.color)
	var shutter_color := tint_for("planks", entry.shutters)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(entry.seed)
	var enterable := bool(entry.enterable)
	var open_front := bool(entry.open_front)
	var kind := str(entry.kind)
	var is_store := kind in ["warehouse", "kontor", "hall"]
	var shop := str(entry.shop)
	var group_upper := str(entry.id) if enterable else ""
	var depth_bays := int(round(depth / BAY))
	for storey in range(storeys):
		var y := float(storey) * STOREY
		var group := group_upper if storey > 0 else ""
		for bay in range(bays):
			var x := -width * 0.5 + BAY * (float(bay) + 0.5)
			var front := xform * Transform3D(Basis.IDENTITY, Vector3(x, y, -WALL * 0.5))
			var back := (
				xform * Transform3D(Basis(Vector3.UP, PI), Vector3(x, y, -depth + WALL * 0.5))
			)
			var door_bay := storey == 0 and bay == int(entry.door_bay)
			# Front facade
			if open_front and storey == 0:
				pass
			elif door_bay and enterable:
				_add("door_frame", front)
			else:
				_add(wall, front, wall_color, group)
				if storey == 0:
					_ground_floor_overlay(front, entry, door_bay, rng, is_store, shop)
				else:
					_upper_overlay(front, entry, rng, is_store, shutter_color, group)
			# Back facade
			_add(wall, back, wall_color, group)
			if storey > 0 or not is_store:
				if rng.randf() < 0.75:
					_add("window_sash" if not is_store else "window_loft", back, Color.WHITE, group)
			if storey < storeys - 1:
				_add(
					"cornice",
					xform * Transform3D(Basis.IDENTITY, Vector3(x, y + STOREY, -WALL * 0.5)),
					Color.WHITE,
					group_upper
				)
		# Side walls (gable ends of the block)
		for side in [-1.0, 1.0]:
			var yaw: float = side * PI * 0.5
			for index in range(depth_bays):
				var z := -BAY * (float(index) + 0.5)
				var placed := (
					xform
					* Transform3D(
						Basis(Vector3.UP, yaw), Vector3(side * (width * 0.5 - WALL * 0.5), y, z)
					)
				)
				_add(wall, placed, wall_color, group)
	if open_front:
		for bay in range(bays + 1):
			var post_x := -width * 0.5 + float(bay) * BAY
			_add("corner", xform * Transform3D(Basis.IDENTITY, Vector3(post_x, 0.0, -0.3)))
		_box_collider_local(
			xform, Vector3(0, STOREY * 0.5, -depth + WALL * 0.5), Vector3(width, STOREY, WALL)
		)
		for side in [-1.0, 1.0]:
			_box_collider_local(
				xform,
				Vector3(side * (width * 0.5 - WALL * 0.5), STOREY * 0.5, -depth * 0.5),
				Vector3(WALL, STOREY, depth)
			)
		for bay in range(bays + 1):
			var post_x := -width * 0.5 + float(bay) * BAY
			_box_collider_local(
				xform, Vector3(post_x, STOREY * 0.5, -0.3), Vector3(0.56, STOREY, 0.56)
			)
	elif enterable:
		_room_collision(entry, xform, width, depth)
	else:
		_box_collider_local(
			xform,
			Vector3(0, STOREY * storeys * 0.5, -depth * 0.5),
			Vector3(width, STOREY * storeys, depth)
		)
	_roof(entry, xform, width, depth, storeys, rng, group_upper)
	if not shop.is_empty() or not str(entry.title).is_empty():
		_sign(entry, xform, width)


func _box_collider_local(xform: Transform3D, center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform * Transform3D(Basis.IDENTITY, center)
	collision.add_child(shape)


func _room_collision(entry: Dictionary, xform: Transform3D, width: float, depth: float) -> void:
	var door_x := -width * 0.5 + BAY * (float(entry.door_bay) + 0.5)
	var gap := 1.6
	var height := STOREY
	_box_collider_local(
		xform, Vector3(0, height * 0.5, -depth + WALL * 0.5), Vector3(width, height, WALL)
	)
	for side in [-1.0, 1.0]:
		_box_collider_local(
			xform,
			Vector3(side * (width * 0.5 - WALL * 0.5), height * 0.5, -depth * 0.5),
			Vector3(WALL, height, depth)
		)
	var left := door_x - gap + width * 0.5
	_box_collider_local(
		xform,
		Vector3(-width * 0.5 + left * 0.5, height * 0.5, -WALL * 0.5),
		Vector3(left, height, WALL)
	)
	var right := width * 0.5 - door_x - gap
	_box_collider_local(
		xform,
		Vector3(width * 0.5 - right * 0.5, height * 0.5, -WALL * 0.5),
		Vector3(right, height, WALL)
	)
	# Lintel above the doorway keeps the follow camera from slipping over it.
	_box_collider_local(xform, Vector3(door_x, 3.65, -WALL * 0.5), Vector3(gap * 2.0, 0.7, WALL))


func _ground_floor_overlay(
	front: Transform3D,
	entry: Dictionary,
	door_bay: bool,
	rng: RandomNumberGenerator,
	is_store: bool,
	shop: String
) -> void:
	if is_store:
		_add("door_warehouse" if door_bay else "window_sash", front)
		return
	if door_bay:
		_add("door_house", front)
		return
	_add("plinth", front)
	if not shop.is_empty() and str(entry.kind) == "house":
		_add("window_shop", front)
		var awning: String = ["awning_red", "awning_blue", "awning_green"][int(entry.seed) % 3]
		_add(awning, front)
	elif str(entry.style) == "brick":
		_add("window_round", front)
	else:
		_add("window_sash", front)
		if rng.randf() < 0.5:
			_add("shutters", front, tint_for("planks", entry.shutters))


func _upper_overlay(
	front: Transform3D,
	_entry: Dictionary,
	rng: RandomNumberGenerator,
	is_store: bool,
	shutter_color: Color,
	group: String
) -> void:
	if is_store:
		_add("window_loft", front, Color.WHITE, group)
		return
	_add("window_sash", front, Color.WHITE, group)
	if rng.randf() < 0.55:
		_add("shutters", front, shutter_color, group)
	if rng.randf() < 0.4:
		_add("flower_box", front, Color.WHITE, group)
	elif rng.randf() < 0.12:
		_add(
			"balcony", front * Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Color.WHITE, group
		)


func _roof(
	entry: Dictionary,
	xform: Transform3D,
	width: float,
	depth: float,
	storeys: int,
	rng: RandomNumberGenerator,
	group: String
) -> void:
	var top := float(storeys) * STOREY
	var bays := int(entry.bays)
	var gable := str(entry.gable)
	var hall := depth > LAYOUT.DEPTH + 0.1
	var roof_module := (
		"roof_hall" if hall else ("roof_bay_slate" if str(entry.roof) == "slate" else "roof_bay")
	)
	var roof_tile := "roof_slate" if hall or str(entry.roof) == "slate" else "roof_clay"
	var roof_target: Color = entry.roof_tint
	if roof_tile == "roof_slate":
		roof_target = Color(["6d7987", "5f6b7a", "7d8796"][int(entry.seed) % 3])
	var roof_color := tint_for(roof_tile, roof_target)
	var wall_color := tint_for(_wall_tile(str(entry.style)), entry.color)
	if gable in ["gable", "stepped"] and bays == 3:
		_add(
			"roof_front_gable",
			xform * Transform3D(Basis.IDENTITY, Vector3(0, top, -depth * 0.5)),
			roof_color,
			group
		)
		if gable == "stepped":
			_add(
				"gable_stepped",
				xform * Transform3D(Basis.IDENTITY, Vector3(0, top, -WALL * 0.5)),
				wall_color,
				group
			)
			_add(
				"gable_stepped_trim",
				xform * Transform3D(Basis.IDENTITY, Vector3(0, top, -WALL * 0.5)),
				Color.WHITE,
				group
			)
		else:
			_add(
				"gable_front_wall",
				xform * Transform3D(Basis.IDENTITY, Vector3(0, top, -WALL * 0.5)),
				wall_color,
				group
			)
			_add(
				"gable_window",
				xform * Transform3D(Basis.IDENTITY, Vector3(0, top, -WALL * 0.5)),
				Color.WHITE,
				group
			)
		_add(
			"gable_front_wall",
			xform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, top, -depth + WALL * 0.5)),
			wall_color,
			group
		)
		_add(
			"cornice",
			xform * Transform3D(Basis.IDENTITY, Vector3(-BAY, top, -WALL * 0.5)),
			Color.WHITE,
			group
		)
		_add(
			"cornice",
			xform * Transform3D(Basis.IDENTITY, Vector3(BAY, top, -WALL * 0.5)),
			Color.WHITE,
			group
		)
	else:
		for bay in range(bays):
			var x := -width * 0.5 + BAY * (float(bay) + 0.5)
			_add(
				roof_module,
				xform * Transform3D(Basis.IDENTITY, Vector3(x, top, -depth * 0.5)),
				roof_color,
				group
			)
			_add(
				"cornice",
				xform * Transform3D(Basis.IDENTITY, Vector3(x, top - 0.1, -WALL * 0.5)),
				Color.WHITE,
				group
			)
			if not hall:
				_add(
					"gutter",
					xform * Transform3D(Basis.IDENTITY, Vector3(x, top - 0.05, -WALL * 0.5)),
					Color.WHITE,
					group
				)
			if not hall and bay % 2 == 1 and rng.randf() < 0.7:
				_add(
					"dormer",
					xform * Transform3D(Basis.IDENTITY, Vector3(x, top, -0.9)),
					Color.WHITE,
					group
				)
		var end_module := "roof_end_planks" if hall else "roof_end"
		for side in [-1.0, 1.0]:
			var end := (
				xform
				* Transform3D(
					Basis(Vector3.UP, 0.0 if side > 0 else PI),
					Vector3(side * width * 0.5, top, -depth * 0.5)
				)
			)
			_add(end_module, end, wall_color if not hall else Color.WHITE, group)
			if not hall:
				_add("roof_end_trim", end, Color.WHITE, group)
		if not hall:
			for storey in range(storeys):
				_add(
					"downpipe",
					(
						xform
						* Transform3D(
							Basis.IDENTITY,
							Vector3(width * 0.5 - 0.35, float(storey) * STOREY, -WALL * 0.5)
						)
					),
					Color.WHITE,
					group if storey > 0 else ""
				)
	if not hall and rng.randf() < 0.8:
		var chimney_x := rng.randf_range(-width * 0.3, width * 0.3)
		_add(
			"chimney",
			xform * Transform3D(Basis.IDENTITY, Vector3(chimney_x, top + 2.2, -depth * 0.62)),
			Color.WHITE,
			group
		)


func _sign(entry: Dictionary, xform: Transform3D, width: float) -> void:
	var text := str(entry.shop) if not str(entry.shop).is_empty() else str(entry.title).to_upper()
	var bracket := (
		xform * Transform3D(Basis.IDENTITY, Vector3(-width * 0.5 + 0.9, STOREY * 0.92, -WALL * 0.5))
	)
	if str(entry.kind) == "house":
		_add("sign_bracket", bracket)
		_add(
			"lamp_wall",
			xform * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 - 0.7, 3.4, -WALL * 0.5))
		)
	var label := Label3D.new()
	label.name = "Sign_" + str(entry.id).replace(":", "_")
	label.text = text
	label.font_size = 44 if str(entry.kind) != "house" else 34
	label.pixel_size = 0.01
	label.modulate = Color("fff3d0")
	label.outline_modulate = Color("2c3a44")
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.visibility_range_end = 60.0
	if str(entry.kind) == "house":
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = bracket.origin + bracket.basis * Vector3(0, -0.62, 0.9)
		label.font_size = 30
	else:
		label.position = xform * Vector3(0, STOREY * 0.98, 0.5)
		label.rotation.y = float(entry.yaw)
	add_child(label)
	label.set_meta("sign_text", text)


# --- Props, lamps, boats --------------------------------------------------------


func _props() -> void:
	for prop in layout.data.get("props", []):
		var at := Vector3(float(prop.at[0]), 0.0, float(prop.at[1]))
		var yaw := float(prop.get("yaw", 0.0))
		var prop_scale := 1.3 if str(prop.kind).begins_with("stall_") else 1.0
		_add(
			str(prop.kind), Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * prop_scale), at)
		)
		var size: Vector2 = LAYOUT.PROP_FOOTPRINTS.get(str(prop.kind), Vector2.ZERO)
		if size != Vector2.ZERO and str(prop.kind) not in ["fish_crates", "rope_coil", "anchor"]:
			var turned := absf(sin(yaw)) > 0.7
			var extent := Vector3(size.y, 1.2, size.x) if turned else Vector3(size.x, 1.2, size.y)
			if str(prop.kind) in ["stall_fish", "stall_fruit", "stall_bread"]:
				extent = Vector3(extent.x * 0.7, 1.2, extent.z * 0.6)
			_box_collider(at + Vector3.UP * 0.6, extent)
	for room_id in layout.data.get("interiors", {}):
		var room: Dictionary = layout.data.interiors[room_id]
		if room.has("counter"):
			_add("counter", _placed(room.counter))
			_box_collider(
				_placed(room.counter).origin + Vector3.UP * 0.6,
				_turned(Vector3(4.2, 1.2, 1.2), float(room.counter[2]))
			)
		for shelf in room.get("shelves", []):
			_add("shelf_goods", _placed(shelf))
			_box_collider(
				_placed(shelf).origin + Vector3.UP * 1.6,
				_turned(Vector3(3.2, 3.2, 0.9), float(shelf[2]))
			)
		for pallet in room.get("pallets", []):
			_add("crate_pallet", _placed(pallet))
			_box_collider(
				_placed(pallet).origin + Vector3.UP * 0.5,
				_turned(Vector3(2.0, 1.0, 1.6), float(pallet[2]))
			)
		if room.has("board"):
			_add("board_delivery", _placed(room.board))
		if room.has("desk"):
			_add("table_round", _placed(room.desk))
			_add("stool", _placed(room.desk) * Transform3D(Basis.IDENTITY, Vector3(1.3, 0, 0)))


func _placed(raw: Array) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(raw[2])), Vector3(float(raw[0]), 0.0, float(raw[1])))


func _turned(size: Vector3, yaw: float) -> Vector3:
	return Vector3(size.z, size.y, size.x) if absf(sin(yaw)) > 0.7 else size


func _lamps() -> void:
	for at in layout.lamps:
		_add("lamp_post", Transform3D(Basis.IDENTITY, at))
		_box_collider(at + Vector3.UP * 1.0, Vector3(0.4, 2.0, 0.4))
	if quality != "high":
		return
	for index in range(mini(4, layout.lamps.size())):
		var light := OmniLight3D.new()
		light.name = "MarketLampLight_%d" % index
		var spot_at: Vector3 = [
			Vector3(186, 4.2, -145.6),
			Vector3(214, 4.2, -145.6),
			Vector3(186, 4.2, -165.0),
			Vector3(214, 4.2, -165.0)
		][index]
		light.position = spot_at
		light.light_color = Color("ffc27a")
		light.omni_range = 11.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		market_lights.append(light)


func _boats() -> void:
	for boat in layout.data.get("boats", []):
		var mesh := _mesh(str(boat.kind))
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = "Boat_%d" % boats.size()
		node.mesh = mesh
		node.position = Vector3(
			float(boat.at[0]), float(layout.data.water_level) - 0.35, float(boat.at[1])
		)
		node.rotation.y = float(boat.yaw)
		node.visibility_range_end = RANGES.harbour
		add_child(node)
		boats.append(
			{
				"node": node,
				"base": node.position,
				"yaw": float(boat.yaw),
				"phase": float(boats.size()) * 1.3
			}
		)


func _trees() -> void:
	var transforms: Array[Transform3D] = []
	for tree in layout.data.get("trees", []):
		transforms.append(
			Transform3D(
				Basis(Vector3.UP, float(tree[0]) * 0.37).scaled(Vector3.ONE * 1.7),
				Vector3(float(tree[0]), 0.0, float(tree[1]))
			)
		)
		_box_collider(Vector3(float(tree[0]), 1.0, float(tree[1])), Vector3(0.8, 2.0, 0.8))
	VILLAGE.batch(self, "SonnenhafenTrees", "tree_oak", transforms, 140, true)


# --- Navigation ------------------------------------------------------------------


func _navigation() -> void:
	nav_mesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_radius = 0.0
	var polygons: Dictionary = layout.nav_polygons()
	nav_mesh.vertices = polygons.vertices
	for polygon in polygons.polygons:
		nav_mesh.add_polygon(polygon)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "SonnenhafenNavigation"
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	set_meta("nav_polygon_count", polygons.polygons.size())


# --- Runtime -------------------------------------------------------------------


## Hides upper floors and roof of an enterable building while Lumo is inside,
## so the follow camera looks into the room instead of onto the roof.
func update_focus(at: Vector3) -> String:
	var inside := ""
	for id in upper_nodes:
		var room: Rect2 = layout.interior_rects.get(id, Rect2())
		var within := room.grow(0.2).has_point(Vector2(at.x, at.z))
		(upper_nodes[id] as Node3D).visible = not within
		if within:
			inside = str(id)
	return inside


func tick(delta: float, evening: float) -> void:
	clock += delta
	night = evening
	for light in market_lights:
		light.visible = evening > 0.05
		light.light_energy = evening * 1.6
	if reduced_motion:
		return
	for boat in boats:
		var node: MeshInstance3D = boat.node
		var phase: float = clock * 0.9 + float(boat.phase)
		node.position = boat.base + Vector3(0, sin(phase) * 0.08, 0)
		node.rotation = Vector3(sin(phase * 0.7) * 0.02, float(boat.yaw), cos(phase * 0.8) * 0.025)
