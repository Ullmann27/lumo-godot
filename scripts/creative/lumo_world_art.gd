extends RefCounted
## Reuses the actual Treasure Island terrain, Blender nature and art dressing.
## New neighbourhoods grow east from the island; no original treasure file is edited.

const KIT = preload("res://scripts/creative/creative_kit.gd")
const NATURE = preload("res://scripts/creative/treasure_island_nature.gd")
const ISLAND_ART = preload("res://scripts/creative/treasure_island_art.gd")
const ADVENTURE = preload("res://scripts/creative/adventure_kit.gd")
const VILLAGE = preload("res://scripts/creative/build_village_art.gd")
const CHEST = preload("res://assets/creative/models/lumo_treasure_chest.glb")
const LANTERN = preload("res://assets/creative/models/lumo_lantern.glb")
const VEHICLE_DIR := "res://assets/creative/lumo_world/vehicles/"
const SIGN_MAX_DP := Vector2(320.0, 34.0)
const MARKER_MAX_DP := 48.0
const MARKER_SCALE := 0.65

var kit := KIT.new()
var zones: Dictionary = {}
var signs: Array[Label3D] = []
var sign_extents: Dictionary = {}
## Ground kept free of the authored tree scatter (open-world places and paths).
var clear_areas: Array[Rect2] = []


func build(root: Node3D) -> void:
	_treasure_island(root)
	var village := _zone(root, "Sonnendorf")
	var city := _zone(root, "Sternenstadt")
	var landscape := _zone(root, "Gartenlandschaft")
	var ground := StaticBody3D.new()
	ground.name = "MainlandTerrain"
	village.add_child(ground)
	var grass := kit.box(ground, Vector3(169, -0.5, -11), Vector3(214, 1, 174), Color.WHITE)
	grass.material_override = kit.textured("grass", Color("c4df8c"))
	kit.collision(ground, Vector3(169, -0.5, -11), Vector3(214, 1, 174))
	_bridge(village)
	_roads(village)
	_buildings(village, city)
	_garden(landscape)
	_park(city)
	_foliage(landscape)
	_vehicle(landscape, "city_bicycle", Vector3(100, 0, -25), -0.3)
	_vehicle(landscape, "kick_scooter", Vector3(97, 0, -25), 0.3)
	_sign(village, "SONNENDORF", Vector3(76, 3.3, 12), Color("7de9dc"))
	_sign(city, "STERNENSTADT", Vector3(207, 6, -10), Color("ffdd82"))
	_sign(landscape, "GEMEINSCHAFTSGARTEN", Vector3(135, 3, -66), Color("b7f583"))
	for x in range(78, 266, 18):
		for z in [-7.5, 7.5]:
			var lamp := LANTERN.instantiate() as Node3D
			lamp.position = Vector3(x, 0, z)
			lamp.scale = Vector3.ONE * 0.75
			village.add_child(lamp)
	for zone in zones.values():
		for mesh in zone.find_children("*", "GeometryInstance3D", true, false):
			mesh.visibility_range_end = 170.0
			mesh.visibility_range_end_margin = 12.0


func _zone(root: Node3D, id: String) -> Node3D:
	var node := Node3D.new()
	node.name = id
	root.add_child(node)
	zones[id] = node
	return node


func _treasure_island(root: Node3D) -> void:
	var island := _zone(root, "OriginalTreasureIsland")
	var ground := StaticBody3D.new()
	island.add_child(ground)
	var terrain := MeshInstance3D.new()
	terrain.name = "OriginalTreasureTerrain"
	terrain.mesh = NATURE.terrain_mesh()
	terrain.material_override = NATURE.terrain_material()
	terrain.extra_cull_margin = 80.0
	ground.add_child(terrain)
	kit.collision(ground, Vector3(0, -0.65, -29), Vector3(74, 1.3, 88))
	NATURE.apply(island)
	ISLAND_ART.apply(island)
	ADVENTURE.place(island, "OriginalWelcomeArch", "ruins", "arch_welcome", Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.35)))
	ADVENTURE.place(island, "OriginalGateArch", "ruins", "arch_gate", Transform3D(Basis.IDENTITY, Vector3(0, 0, -31)))
	var chest := CHEST.instantiate() as Node3D
	chest.name = "OriginalTreasureChest"
	chest.position = Vector3(0, 0, -65)
	island.add_child(chest)
	for z in range(8, -70, -8):
		for x in [-3.5, 3.5]:
			var lamp := LANTERN.instantiate() as Node3D
			lamp.position = Vector3(x, 0, z)
			island.add_child(lamp)
	_treasure_wayfinder(island)


func _treasure_wayfinder(root: Node3D) -> void:
	# A readable roadside direction, outside the avatar's central sightline.
	# This is local World dressing; the original Treasure Island is untouched.
	var sign := Node3D.new()
	sign.name = "TreasureVillageWayfinder"
	sign.position = Vector3(6.0, 0, 5.0)
	root.add_child(sign)
	var post := kit.box(sign, Vector3(0, 0.95, 0), Vector3(0.16, 1.9, 0.16), Color.WHITE)
	post.material_override = ADVENTURE.material("wood_dark")
	kit.box(sign, Vector3(0, 1.95, 0), Vector3(2.7, 0.72, 0.12), Color("193d48"))
	var label := _sign(sign, "Sonnendorf →", Vector3(0, 1.95, 0.08), Color("c8ffe0"))
	label.name = "Direction"
	label.font_size = 28
	label.pixel_size = 0.006
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.visibility_range_end = 34.0


func _bridge(root: Node3D) -> void:
	var bridge := StaticBody3D.new()
	bridge.name = "IslandToVillageBridge"
	root.add_child(bridge)
	# The island remains at its original coordinates. The boardwalk reaches the
	# mainland without changing its authored path shader or any treasure save.
	var deck := kit.box(bridge, Vector3(49, -0.09, 6), Vector3(31, 0.18, 6), Color.WHITE)
	deck.material_override = ADVENTURE.material("wood")
	kit.collision(bridge, Vector3(49, -0.09, 6), Vector3(31, 0.18, 6))
	for z in [3.15, 8.85]:
		var rail := kit.box(bridge, Vector3(49, 1.2, z), Vector3(31, 0.16, 0.18), Color.WHITE)
		rail.material_override = ADVENTURE.material("wood_dark")
		kit.collision(bridge, Vector3(49, 0.7, z), Vector3(31, 1.4, 0.18))
		for x in range(34, 65, 3):
			var post := kit.box(bridge, Vector3(x, 0.6, z), Vector3(0.18, 1.6, 0.18), Color.WHITE)
			post.material_override = ADVENTURE.material("wood_dark")
			kit.sphere(bridge, Vector3(x, 1.45, z), Vector3.ONE * 0.16, Color("ffe6a6"), true)
	var arrival := kit.box(root, Vector3(71, 0.018, 10), Vector3(18, 0.035, 14), Color("d7c69c"))
	arrival.material_override = ADVENTURE.material("stone_block")


func _roads(root: Node3D) -> void:
	kit.box(root, Vector3(169, 0.018, 0), Vector3(204, 0.035, 8.8), Color("384e64"))
	for z in [-6.25, 6.25]:
		kit.box(root, Vector3(169, 0.035, z), Vector3(204, 0.07, 3.7), Color("d7d9ca"))
	for x in range(70, 268, 8):
		if absf(float(x) - 110.0) > 7.0 and absf(float(x) - 218.0) > 7.0:
			kit.box(root, Vector3(x, 0.043, 0), Vector3(3.0, 0.018, 0.13), Color("f2de9b"))
	for crossing_x in [110.0, 218.0]:
		for z in range(-4, 5, 2):
			kit.box(root, Vector3(crossing_x, 0.048, z), Vector3(4.0, 0.02, 0.85), Color("f7f1d9"))
	# Pedestrian approach paths, also usable on a foldable portrait display.
	for x in [90.0, 110.0, 135.0, 192.0, 218.0, 239.0]:
		kit.box(root, Vector3(x, 0.024, -36), Vector3(4.3, 0.035, 58), Color("ddc8a0"))
	kit.box(root, Vector3(110, 0.023, 18), Vector3(74, 0.035, 5), Color("ddc8a0"))
	kit.box(root, Vector3(218, 0.026, -45), Vector3(72, 0.04, 5.5), Color("ddc8a0"))


func _building(root: Node3D, model_name: String, at: Vector3, width: float, yaw := 0.0) -> StaticBody3D:
	var entry = VILLAGE.bundle(model_name)
	if entry.aabb.size.x <= 0.01:
		return null
	var factor: float = width / entry.aabb.size.x
	var body := StaticBody3D.new()
	body.name = model_name + "_" + str(int(at.x)) + "_" + str(int(at.z))
	body.position = at
	body.rotation.y = yaw
	root.add_child(body)
	var visual: Node3D = VILLAGE.instance(model_name, true)
	visual.scale = Vector3.ONE * factor
	# Original village models are authored at ground y=0. Their stone skirts
	# extend to y=-0.9 for hills; lifting the AABB floor exposed those skirts
	# as metre-high barriers and raised every doorway above the walking path.
	visual.position.y = 0.0
	body.add_child(visual)
	var collision_size: Vector3 = entry.aabb.size * factor * Vector3(0.84, 0.72, 0.84)
	var center: Vector3 = (entry.aabb.position + entry.aabb.size * 0.5) * factor
	if model_name == "school":
		# Match the authored hall, not its decorative tree/window-box AABB.
		collision_size = Vector3(4.0, 2.8, 3.2) * factor
		center = Vector3.ZERO
	center.y = collision_size.y * 0.5
	kit.collision(body, center, collision_size)
	body.set_meta("authored_scale", factor)
	return body


func _school_entrance(root: Node3D, school: StaticBody3D) -> void:
	if school == null:
		return
	var factor: float = school.get_meta("authored_scale")
	# Blender source: school door at (0, .22, 1.5), its step tops at .34.
	var landing_height := 0.34 * factor + 0.035
	var landing_center := school.position + Vector3(0, 0, 1.96 * factor)
	var landing_depth := 0.70 * factor
	var width := 1.55 * factor
	var porch := StaticBody3D.new()
	porch.name = "SchoolEntranceLanding"
	root.add_child(porch)
	var at := landing_center + Vector3.UP * (landing_height - 0.08)
	var slab := kit.box(porch, at, Vector3(width, 0.16, landing_depth), Color.WHITE)
	slab.material_override = ADVENTURE.material("stone_block")
	kit.collision(porch, at, Vector3(width, 0.16, landing_depth))
	var top_z := landing_center.z + landing_depth * 0.5 - 0.06
	var bottom_z := -22.8
	var run := bottom_z - top_z
	var ramp := StaticBody3D.new()
	ramp.name = "SchoolEntranceRamp"
	ramp.position = Vector3(school.position.x, landing_height * 0.5, (bottom_z + top_z) * 0.5)
	ramp.rotation.x = atan2(landing_height, run)
	root.add_child(ramp)
	var length := sqrt(run * run + landing_height * landing_height) + 0.12
	var surface := kit.box(ramp, Vector3(0, -0.08, 0), Vector3(width, 0.16, length), Color.WHITE)
	surface.material_override = ADVENTURE.material("stone_block")
	kit.collision(ramp, Vector3(0, -0.08, 0), Vector3(width, 0.16, length))
	for side in [-1.0, 1.0]:
		kit.box(ramp, Vector3(side * (width * 0.5 - 0.07), 0.04, 0), Vector3(0.10, 0.08, length), Color("9ed8bd"))
	root.set_meta("school_entrance", Vector3(school.position.x, landing_height, landing_center.z))


func _buildings(village: Node3D, city: Node3D) -> void:
	_building(village, "house_a", Vector3(90, 0, 29), 11, PI)
	_building(village, "house_b", Vector3(116, 0, 30), 11, PI)
	_building(village, "house_c", Vector3(143, 0, 29), 12, PI)
	var school := _building(village, "school", Vector3(110, 0, -35), 18)
	_school_entrance(village, school)
	_building(village, "bakery", Vector3(82, 0, -29), 12)
	_building(village, "workshop", Vector3(151, 0, -29), 12)
	_sign(village, "Nellis Zuhause", Vector3(90, 3.1, 22), Color("ffe8b4"))
	_sign(village, "LUMO SCHULE", Vector3(110, 3.1, -25.0), Color("7be6ff"))
	_sign(village, "Brunos Werkstatt", Vector3(151, 3.8, -22), Color("b9ef9a"))
	for index in range(5):
		_building(city, ["house_b", "house_c", "house_a"][index % 3], Vector3(184 + index * 18, 0, 25), 14, PI)
	_building(city, "market", Vector3(218, 0, -26), 18)
	_building(city, "clinic", Vector3(192, 0, -31), 16)
	_building(city, "bakery", Vector3(247, 0, -30), 14)
	_building(city, "house_a", Vector3(192, 0, -68), 13)
	_building(city, "house_b", Vector3(262, 0, -68), 13)
	_sign(city, "Tildas Sternenpost", Vector3(218, 3.7, -35), Color("ffda91"))


func _garden(root: Node3D) -> void:
	kit.box(root, Vector3(135, 0.025, -59), Vector3(22, 0.05, 19), Color("c9b98b"))
	for row in range(3):
		var bed := kit.box(root, Vector3(128 + row * 7, 0.16, -62), Vector3(5, 0.32, 8), Color("694f3a"))
		bed.material_override = ADVENTURE.material("wood_dark")
		for plant in range(4):
			var flower: Node3D = VILLAGE.instance("flowers", false)
			flower.position = Vector3(128 + row * 7, 0.34, -65 + plant * 2)
			flower.scale = Vector3.ONE * 1.6
			root.add_child(flower)


func _park(root: Node3D) -> void:
	var fountain := kit.cylinder(root, Vector3(221, 0.45, -57), 3.1, 0.9, Color("c9b495"))
	fountain.material_override = ADVENTURE.material("stone_block")
	kit.cylinder(root, Vector3(221, 0.93, -57), 2.6, 0.05, Color("65c8de"))
	kit.sphere(root, Vector3(221, 1.6, -57), Vector3(0.7, 1.6, 0.7), Color("89dded"), true)
	var table := kit.box(root, Vector3(239, 1.15, -67), Vector3(4, 0.22, 2.4), Color.WHITE)
	table.material_override = ADVENTURE.material("wood")
	for x in [237.6, 240.4]:
		kit.box(root, Vector3(x, 0.5, -67), Vector3(0.16, 1, 1.8), Color("5b6656"))
	for z in [-65.2, -68.8]:
		var bench := kit.box(root, Vector3(239, 0.65, z), Vector3(4.4, 0.2, 0.65), Color.WHITE)
		bench.material_override = ADVENTURE.material("wood")
	_sign(root, "Freundschaftspark", Vector3(239, 3.4, -73), Color("baf2ae"))


func _foliage(root: Node3D) -> void:
	var density: float = clampf(float(LumoQuality.budget().get("decor_density", 1.0)), 0.35, 1.0)
	var trees: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	for index in range(int(94 * density)):
		# Stable authored scatter: no run-time game randomness or loot outcomes.
		var x: float = 70.0 + fposmod(float(index) * 43.73, 199.0)
		var z: float = -98.0 + fposmod(float(index) * 29.37, 165.0)
		if absf(z) < 11.0 or (z > -80 and z < 42 and x < 162) or (z > -78 and z < 42 and x > 175):
			continue
		if _cleared(Vector2(x, z)):
			continue
		trees.append(Transform3D(Basis(Vector3.UP, float(index) * 1.71).scaled(Vector3.ONE * (1.7 + float(index % 3) * 0.4)), Vector3(x, 0, z)))
	for x in range(78, 267, 11):
		for z in [-12.0, 13.0]:
			if absf(float(x) - 110) < 6 or absf(float(x) - 218) < 6:
				continue
			trees.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.6), Vector3(x, 0, z)))
			bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.3), Vector3(x + 3, 0, z)))
			flowers.append(Transform3D(Basis.IDENTITY, Vector3(x - 2, 0, z + 1.2)))
	VILLAGE.batch(root, "TownTreeCanopy", "tree_oak", trees, 140, true)
	VILLAGE.batch(root, "TownFlowerBeds", "flowers", flowers, 85, false)
	VILLAGE.batch(root, "TownHedges", "bush", bushes, 100, false)


func _cleared(at: Vector2) -> bool:
	for area in clear_areas:
		if area.has_point(at):
			return true
	return false


func _vehicle(root: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var scene := load(VEHICLE_DIR + id + ".glb") as PackedScene
	if scene == null:
		return null
	var visual := scene.instantiate() as Node3D
	visual.position = at
	visual.rotation.y = yaw
	root.add_child(visual)
	return visual


func _sign(root: Node3D, text: String, at: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_modulate = Color("163249")
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = at
	root.add_child(label)
	signs.append(label)
	return label


func fit_camera_hints(camera: Camera3D, marker: MeshInstance3D, density: float) -> void:
	# World-space labels must not grow across Lumo's face when a wall compresses
	# the follow camera. Cap only their near perspective size; distant signs keep
	# their authored dimensions, and the physical roadside board is untouched.
	var viewport := camera.get_viewport()
	var view := viewport.get_visible_rect().size
	var canvas_per_dp := view * density / Vector2(viewport.get_window().size).max(Vector2.ONE)
	var limit := SIGN_MAX_DP * canvas_per_dp
	limit.x = minf(limit.x, view.x * 0.55)
	var camera_space := camera.get_camera_transform().affine_inverse()
	var focal := (view.y if camera.keep_aspect == Camera3D.KEEP_HEIGHT else view.x) / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))
	var perspective := camera.projection == Camera3D.PROJECTION_PERSPECTIVE
	for label in signs:
		if label.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
			continue
		var factor := 1.0
		if perspective:
			var extent := _sign_extent(label)
			var depth := maxf(camera.near, -(camera_space * label.global_position).z)
			factor = minf(1.0, minf(limit.x / extent.x, limit.y / extent.y) * depth / focal)
		var fitted := Vector3.ONE * factor
		if not label.scale.is_equal_approx(fitted):
			label.scale = fitted
	var marker_factor := MARKER_SCALE
	if perspective:
		var diameter := marker.get_aabb().size.length() * MARKER_SCALE
		var depth := maxf(camera.near, -(camera_space * marker.global_position).z - diameter * 0.5)
		marker_factor *= minf(1.0, MARKER_MAX_DP * minf(canvas_per_dp.x, canvas_per_dp.y) * depth / (focal * diameter))
	var fitted_marker := Vector3.ONE * marker_factor
	if not marker.scale.is_equal_approx(fitted_marker):
		marker.scale = fitted_marker


func _sign_extent(label: Label3D) -> Vector2:
	var id := label.get_instance_id()
	if not sign_extents.has(id):
		# Label3D's billboard AABB is a cube. Its generated rectangle gives the
		# actual text height and width; cache it once, not on every camera tick.
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for vertex in label.generate_triangle_mesh().get_faces():
			var point := Vector2(vertex.x, vertex.y)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		sign_extents[id] = (maximum - minimum).max(Vector2.ONE * 0.001)
	return sign_extents[id]
