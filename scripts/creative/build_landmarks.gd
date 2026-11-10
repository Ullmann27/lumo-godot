class_name BuildLandmarks
extends RefCounted
## Combined-mesh landmarks for Bauwelt: Fachwerk-Werkstatt, Sternwarte,
## verzweigte Baeume, Bogenbruecke, Wasserfall mit Fels, L-Emblem,
## Inselboden, Baukran und Uferschaum.
## Footprints, collision and part IDs stay with the catalog / build_state.

# Keep in sync with build_state.HALF. Visual rim is HALF + 0.5.
const ISLAND_HALF := 24.0
const ISLAND_EDGE := 24.5
const CANYON_Z := 24.6


static func mesh_node(root: Node, mesh: Mesh, mat: Material, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(node)
	return node


static func append_box(st: SurfaceTool, size: Vector3, at: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var box := BoxMesh.new()
	box.size = size
	st.append_from(box, 0, Transform3D(basis, at))


static func append_cyl(
	st: SurfaceTool,
	radius: float,
	height: float,
	at: Vector3,
	basis: Basis = Basis.IDENTITY,
	top: float = -1.0,
	segments: int = 10
) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = radius
	cyl.top_radius = radius if top < 0.0 else top
	cyl.height = height
	cyl.radial_segments = segments
	cyl.rings = 1
	st.append_from(cyl, 0, Transform3D(basis, at))


static func append_sphere(st: SurfaceTool, radius: float, height: float, at: Vector3, scale := Vector3.ONE) -> void:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = height
	ball.radial_segments = 10
	ball.rings = 6
	st.append_from(ball, 0, Transform3D(Basis.from_scale(scale), at))


static func commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func emblem_l(root: Node, at: Vector3, scale: float = 0.22, facing: Vector3 = Vector3(0, 0, 1)) -> void:
	## Original LUMO "L" mark as two boxes, not a third-party logo.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var look := Basis.looking_at(facing, Vector3.UP)
	append_box(st, Vector3(0.28, 1.0, 0.08) * scale, look * Vector3(-0.18, 0.05, 0) * scale + at, look)
	append_box(st, Vector3(0.62, 0.28, 0.08) * scale, look * Vector3(0.05, -0.36, 0) * scale + at, look)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d8f7ff")
	mat.emission_enabled = true
	mat.emission = Color("7ad8ff")
	mat.emission_energy_multiplier = 1.15
	mat.roughness = 0.22
	mat.metallic = 0.2
	mesh_node(root, commit(st), mat, "LEmblem")


static var _tree_bark: ArrayMesh
static var _tree_leaves: ArrayMesh
static var _fall_rocks: ArrayMesh


static func branched_tree_bark_mesh() -> ArrayMesh:
	if _tree_bark != null:
		return _tree_bark
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_cyl(bark, 0.20, 2.35, Vector3(1.0, 1.15, 1.0))
	append_cyl(bark, 0.26, 0.28, Vector3(1.0, 0.12, 1.0))
	var branches := [
		[Vector3(1.28, 2.05, 1.18), Vector3(0.55, 0.0, 0.35)],
		[Vector3(0.68, 2.15, 0.72), Vector3(-0.50, 0.12, -0.32)],
		[Vector3(1.10, 2.35, 0.62), Vector3(0.08, 0.18, -0.48)],
		[Vector3(0.85, 1.85, 1.35), Vector3(-0.28, -0.05, 0.42)]
	]
	for branch in branches:
		var tip: Vector3 = branch[0] + branch[1]
		var mid: Vector3 = (branch[0] + tip) * 0.5
		var length: float = branch[0].distance_to(tip)
		var basis := Basis.looking_at(tip - branch[0], Vector3.UP)
		# Cylinder is Y-up; looking_at points -Z, so tilt 90 deg around X in local space.
		basis = basis * Basis.from_euler(Vector3(PI * 0.5, 0, 0))
		append_cyl(bark, 0.075, length + 0.12, mid, basis, 0.045)
	_tree_bark = commit(bark)
	return _tree_bark


static func branched_tree_leaves_mesh() -> ArrayMesh:
	if _tree_leaves != null:
		return _tree_leaves
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crowns := [
		[Vector3(1.00, 3.05, 1.00), 0.85, 1.15],
		[Vector3(1.45, 2.70, 1.35), 0.62, 0.82],
		[Vector3(0.52, 2.78, 0.58), 0.58, 0.78],
		[Vector3(1.15, 2.88, 0.42), 0.55, 0.72],
		[Vector3(0.70, 2.48, 1.42), 0.50, 0.68]
	]
	for crown in crowns:
		append_sphere(leaves, float(crown[1]), float(crown[2]), crown[0])
	_tree_leaves = commit(leaves)
	return _tree_leaves


static func add_branched_tree(body: Node) -> void:
	## Trunk plus three outward branches (bark) and a clustered crown (leaves).
	## Collision stays a 0.4 x 2 x 0.4 stem so existing saves keep their footprint.
	mesh_node(body, branched_tree_bark_mesh(), BuildVoxelStyle.material("bark", Color("c4a07a")), "Trunk")
	mesh_node(body, branched_tree_leaves_mesh(), BuildVoxelStyle.material("leaves", Color("9ed56a")), "Crown")


static func build_workshop(kit: RefCounted, body: StaticBody3D, item: Dictionary) -> void:
	## Fachwerk cottage / Werkstatt, 3 x 3 x 3 cells, facing +Z.
	var sand := SurfaceTool.new()
	sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(sand, Vector3(2.86, 2.05, 2.86), Vector3(1.5, 1.03, 1.5))
	# chimney
	append_box(sand, Vector3(0.42, 0.95, 0.42), Vector3(0.48, 3.15, 0.55))
	# window sills / lintels in sandstone
	append_box(sand, Vector3(0.72, 0.10, 0.16), Vector3(0.55, 1.15, 2.95))
	append_box(sand, Vector3(0.72, 0.10, 0.16), Vector3(2.45, 1.15, 2.95))
	append_box(sand, Vector3(0.86, 0.12, 0.14), Vector3(1.50, 1.55, 2.96))
	# planter boxes
	append_box(sand, Vector3(0.70, 0.14, 0.22), Vector3(0.55, 0.92, 3.02))
	append_box(sand, Vector3(0.70, 0.14, 0.22), Vector3(2.45, 0.92, 3.02))
	mesh_node(body, commit(sand), BuildVoxelStyle.material("sand", Color("d9a86c")), "WorkshopStone")

	var timber := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	# corner posts and mid beams (Fachwerk)
	for x in [0.14, 1.50, 2.86]:
		for z in [0.14, 2.86]:
			append_box(timber, Vector3(0.16, 2.05, 0.16), Vector3(x, 1.03, z))
	for y in [0.22, 1.03, 1.95]:
		append_box(timber, Vector3(2.72, 0.12, 0.12), Vector3(1.5, y, 2.90))
		append_box(timber, Vector3(2.72, 0.12, 0.12), Vector3(1.5, y, 0.10))
		append_box(timber, Vector3(0.12, 0.12, 2.72), Vector3(0.10, y, 1.5))
		append_box(timber, Vector3(0.12, 0.12, 2.72), Vector3(2.90, y, 1.5))
	# door frame and workshop door
	append_box(timber, Vector3(0.90, 1.55, 0.08), Vector3(1.50, 0.82, 2.96))
	append_box(timber, Vector3(0.14, 1.55, 0.12), Vector3(1.08, 0.82, 2.98))
	append_box(timber, Vector3(0.14, 1.55, 0.12), Vector3(1.92, 0.82, 2.98))
	append_box(timber, Vector3(0.90, 0.12, 0.12), Vector3(1.50, 1.58, 2.98))
	mesh_node(body, commit(timber), BuildVoxelStyle.material("wood", Color("8a5a32")), "WorkshopTimber")

	var door := SurfaceTool.new()
	door.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(door, Vector3(0.62, 1.32, 0.06), Vector3(1.50, 0.78, 2.99))
	mesh_node(body, commit(door), BuildVoxelStyle.material("wood", Color("c4894a")), "WorkshopDoor")

	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prism := PrismMesh.new()
	prism.size = Vector3(3.15, 1.15, 3.15)
	roof.append_from(prism, 0, Transform3D(Basis.IDENTITY, Vector3(1.5, 2.62, 1.5)))
	mesh_node(body, commit(roof), BuildVoxelStyle.material("roof", Color("2f5aad")), "WorkshopRoof")

	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(glass, Vector3(0.48, 0.52, 0.04), Vector3(0.55, 1.42, 2.97))
	append_box(glass, Vector3(0.48, 0.52, 0.04), Vector3(2.45, 1.42, 2.97))
	append_box(glass, Vector3(0.28, 0.34, 0.03), Vector3(1.50, 1.28, 3.02))
	mesh_node(body, commit(glass), BuildVoxelStyle.material("glass", Color("9ae8ff")), "WorkshopGlass")

	var plants := SurfaceTool.new()
	plants.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_sphere(plants, 0.12, 0.18, Vector3(0.40, 1.08, 3.08))
	append_sphere(plants, 0.11, 0.16, Vector3(0.62, 1.10, 3.10))
	append_sphere(plants, 0.12, 0.18, Vector3(2.32, 1.08, 3.08))
	append_sphere(plants, 0.11, 0.16, Vector3(2.58, 1.10, 3.10))
	mesh_node(body, commit(plants), BuildVoxelStyle.material("leaves", Color("7ec85a")), "WorkshopPlanters")

	emblem_l(body, Vector3(1.50, 1.72, 3.08), 0.28, Vector3(0, 0, 1))
	kit.collision(body, item.size * 0.5, item.size * 0.96)


static func build_observatory(kit: RefCounted, body: StaticBody3D, item: Dictionary) -> void:
	## Sternwarte: sandstone drum, balcony, glass dome, short telescope. 3 x 4 x 3.
	var sand := SurfaceTool.new()
	sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_cyl(sand, 1.35, 2.15, Vector3(1.5, 1.08, 1.5), Basis.IDENTITY, 1.28, 14)
	append_cyl(sand, 1.42, 0.22, Vector3(1.5, 0.12, 1.5), Basis.IDENTITY, 1.42, 14)
	append_cyl(sand, 1.46, 0.16, Vector3(1.5, 2.18, 1.5), Basis.IDENTITY, 1.46, 14)
	# doorway surround
	append_box(sand, Vector3(0.86, 1.35, 0.16), Vector3(1.5, 0.72, 2.78))
	# balcony floor
	append_box(sand, Vector3(1.15, 0.10, 0.55), Vector3(1.5, 2.12, 2.85))
	mesh_node(body, commit(sand), BuildVoxelStyle.material("sand", Color("d9a86c")), "ObservatoryStone")

	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(wood, Vector3(0.70, 1.20, 0.06), Vector3(1.5, 0.70, 2.86))
	for x in [1.00, 2.00]:
		append_box(wood, Vector3(0.08, 0.55, 0.08), Vector3(x, 2.40, 3.05))
	append_box(wood, Vector3(1.10, 0.08, 0.08), Vector3(1.5, 2.68, 3.05))
	mesh_node(body, commit(wood), BuildVoxelStyle.material("wood", Color("8a5a32")), "ObservatoryWood")

	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	# dome
	var dome := SphereMesh.new()
	dome.radius = 1.18
	dome.height = 1.55
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 8
	glass.append_from(dome, 0, Transform3D(Basis.IDENTITY, Vector3(1.5, 2.28, 1.5)))
	# arched windows around the drum
	for i in range(5):
		var angle := -PI * 0.5 + float(i) * 0.55
		if i == 2:
			continue
		var at := Vector3(1.5 + sin(angle) * 1.32, 1.25, 1.5 + cos(angle) * 1.32)
		append_box(glass, Vector3(0.42, 0.62, 0.06), at, Basis.from_euler(Vector3(0, angle, 0)))
	mesh_node(body, commit(glass), BuildVoxelStyle.material("glass", Color("9ae8ff")), "ObservatoryGlass")

	var brass := SurfaceTool.new()
	brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_cyl(brass, 1.20, 0.10, Vector3(1.5, 2.28, 1.5), Basis.IDENTITY, 1.20, 14)
	append_cyl(brass, 0.08, 0.55, Vector3(1.5, 3.85, 1.5), Basis.IDENTITY, 0.06, 8)
	# telescope tube
	var tube_basis := Basis.from_euler(Vector3(0.55, 0.4, 0)) * Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	append_cyl(brass, 0.11, 1.15, Vector3(1.85, 3.15, 1.85), tube_basis, 0.13, 8)
	append_cyl(brass, 0.16, 0.18, Vector3(2.15, 3.40, 2.15), tube_basis, 0.16, 8)
	mesh_node(body, commit(brass), BuildVoxelStyle.material("plain", Color("c9a15a")), "ObservatoryBrass")

	emblem_l(body, Vector3(1.5, 1.85, 2.92), 0.22, Vector3(0, 0, 1))
	kit.collision(body, item.size * 0.5, item.size * 0.96)


static func add_arch_bridge(body: Node, item: Dictionary) -> void:
	## Stone arch bridge inside a 3 x 1 x 1 footprint. The arch hangs into the river.
	var sand := SurfaceTool.new()
	sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(sand, Vector3(2.98, 0.28, 0.96), Vector3(1.5, 0.72, 0.5))
	# arch ring (boxes along a semicircle under the deck)
	for i in range(7):
		var t := float(i) / 6.0
		var angle := PI * t
		var at := Vector3(0.28 + t * 2.44, 0.55 - sin(angle) * 0.55, 0.5)
		var basis := Basis.from_euler(Vector3(0, 0, PI * 0.5 - angle))
		append_box(sand, Vector3(0.22, 0.42, 0.86), at, basis)
	# rail base
	for z in [0.08, 0.92]:
		append_box(sand, Vector3(2.98, 0.12, 0.10), Vector3(1.5, 0.92, z))
	mesh_node(body, commit(sand), BuildVoxelStyle.material("sand", Color("d9a86c")), "BridgeStone")
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [0.22, 1.5, 2.78]:
		for z in [0.08, 0.92]:
			append_cyl(posts, 0.055, 0.62, Vector3(x, 1.20, z), Basis.IDENTITY, 0.055, 8)
			append_cyl(posts, 0.09, 0.10, Vector3(x, 1.54, z), Basis.IDENTITY, 0.09, 8)
	mesh_node(body, commit(posts), BuildVoxelStyle.material("plain", Color("e6d08a")), "BridgePosts")


static func add_waterfall(body: Node, item: Dictionary) -> void:
	var size: Vector3 = item.size
	var mid := Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	var water := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.85, 2.95, 0.28)
	water.mesh = sheet
	water.position = mid
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/kart_waterfall.gdshader")
	water.material_override = mat
	water.name = "FallSheet"
	body.add_child(water)
	var rocks := SurfaceTool.new()
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(rocks, Vector3(0.35, 1.1, 0.45), Vector3(0.10, 0.55, 0.55))
	append_box(rocks, Vector3(0.35, 1.4, 0.40), Vector3(0.90, 0.70, 0.50))
	append_box(rocks, Vector3(0.55, 0.35, 0.55), Vector3(0.50, 0.12, 0.70))
	append_sphere(rocks, 0.22, 0.28, Vector3(0.20, 0.22, 0.85))
	append_sphere(rocks, 0.18, 0.24, Vector3(0.80, 0.20, 0.80))
	mesh_node(body, commit(rocks), BuildVoxelStyle.material("stone", Color("d2c7b4")), "FallRocks")


static func add_improved_door(kit: RefCounted, body: Node, item: Dictionary) -> void:
	var size: Vector3 = item.size
	var mid := Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(stone, size * 0.98, mid)
	# arch cap
	append_box(stone, Vector3(0.96, 0.22, 0.12), Vector3(0.5, 1.88, 0.98))
	mesh_node(body, commit(stone), BuildVoxelStyle.material("sand", Color("d9a86c")), "DoorStone")
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(wood, Vector3(0.62, 1.55, 0.06), Vector3(0.5, 0.88, 1.00))
	append_box(wood, Vector3(0.08, 1.55, 0.07), Vector3(0.22, 0.88, 1.02))
	append_box(wood, Vector3(0.08, 1.55, 0.07), Vector3(0.78, 0.88, 1.02))
	mesh_node(body, commit(wood), BuildVoxelStyle.material("wood", Color("8a5a32")), "DoorWood")
	var pane := SurfaceTool.new()
	pane.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(pane, Vector3(0.28, 0.28, 0.03), Vector3(0.5, 1.38, 1.04))
	mesh_node(body, commit(pane), BuildVoxelStyle.material("glass", Color("9ae8ff")), "DoorGlass")
	emblem_l(body, Vector3(0.5, 1.72, 1.08), 0.16, Vector3(0, 0, 1))
	kit.collision(body, mid, size * 0.98)


static func far_castle_meshes(root: Node3D, at: Vector3, scale_factor: float) -> void:
	## Distant island silhouette, two materials only (sand + roof).
	var sand := SurfaceTool.new()
	sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-4.0, 4.0]:
		append_cyl(sand, 1.25, 5.8, Vector3(x, 2.9, 0), Basis.IDENTITY, 1.25, 10)
	append_box(sand, Vector3(6.8, 3.8, 2.8), Vector3(0, 1.9, 0))
	append_box(sand, Vector3(1.3, 2.3, 0.12), Vector3(0, 1.15, 1.42))
	var sand_node := mesh_node(
		root, commit(sand), BuildVoxelStyle.material("sand", Color("d9a86c")), "IslandCastleStone"
	)
	sand_node.position = at
	sand_node.scale = Vector3.ONE * scale_factor
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-4.0, 4.0]:
		append_cyl(roof, 1.8, 3.0, Vector3(x, 7.25, 0), Basis.IDENTITY, 0.0, 10)
	var prism := PrismMesh.new()
	prism.size = Vector3(7.4, 2.0, 3.4)
	roof.append_from(prism, 0, Transform3D(Basis.IDENTITY, Vector3(0, 4.8, 0)))
	var roof_node := mesh_node(
		root, commit(roof), BuildVoxelStyle.material("roof", Color("355fbc")), "IslandCastleRoof"
	)
	roof_node.position = at
	roof_node.scale = Vector3.ONE * scale_factor


static func add_canyon(root: Node3D, kit: RefCounted) -> void:
	## Waterfall gorge just past the near river end (z > 16), off the build grid.
	## Rocks and rim plants are batched into RiverRocks / BorderPlants by dress_world.
	# falling sheets
	var fall_xforms: Array[Transform3D] = []
	for i in range(3):
		var at := Vector3(1.2 + float(i) * 0.8, -3.2, CANYON_Z + 0.1)
		fall_xforms.append(Transform3D(Basis.from_scale(Vector3(0.55, 3.4, 0.18)), at))
	var fall_mat := ShaderMaterial.new()
	fall_mat.shader = preload("res://assets/shaders/kart_waterfall.gdshader")
	var fall_mesh := BoxMesh.new()
	fall_mesh.size = Vector3.ONE
	BuildVoxelStyle.multimesh(root, "CanyonFalls", fall_mesh, fall_mat, fall_xforms)
	# plunge pool
	var pool: MeshInstance3D = kit.box(root, Vector3(2.0, -7.15, CANYON_Z + 3.0), Vector3(6.5, 0.22, 5.5), Color("1b81bd"))
	pool.name = "CanyonPool"
	var pool_mat := ShaderMaterial.new()
	pool_mat.shader = preload("res://assets/shaders/kart_water.gdshader")
	pool.material_override = pool_mat


static var _planter: ArrayMesh


static func planter_mesh() -> ArrayMesh:
	if _planter != null:
		return _planter
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_sphere(st, 0.10, 0.16, Vector3(-0.14, 0.08, 0.0))
	append_sphere(st, 0.09, 0.14, Vector3(0.12, 0.09, 0.02))
	append_sphere(st, 0.08, 0.13, Vector3(0.00, 0.11, 0.06))
	_planter = commit(st)
	return _planter


static func waterfall_rock_mesh() -> ArrayMesh:
	if _fall_rocks != null:
		return _fall_rocks
	var rocks := SurfaceTool.new()
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(rocks, Vector3(0.35, 1.1, 0.45), Vector3(0.10, 0.55, 0.55))
	append_box(rocks, Vector3(0.35, 1.4, 0.40), Vector3(0.90, 0.70, 0.50))
	append_box(rocks, Vector3(0.55, 0.35, 0.55), Vector3(0.50, 0.12, 0.70))
	append_sphere(rocks, 0.22, 0.28, Vector3(0.20, 0.22, 0.85))
	append_sphere(rocks, 0.18, 0.24, Vector3(0.80, 0.20, 0.80))
	_fall_rocks = commit(rocks)
	return _fall_rocks


static func _is_low() -> bool:
	return LumoQuality.tier() == "low"


static func _no_shadow(node: GeometryInstance3D) -> void:
	if node != null:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _dist_xz(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	var t := 0.0 if denom < 0.0001 else clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _path_strength(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 99.0
	var left: Array[Vector2] = [
		Vector2(-8.0, -4.2), Vector2(-8.0, 1.4), Vector2(-4.4, 4.0), Vector2(-1.15, 6.0)
	]
	for i in range(left.size() - 1):
		best = minf(best, _dist_xz(p, left[i], left[i + 1]))
	var right: Array[Vector2] = [
		Vector2(4.15, 6.0), Vector2(7.1, 6.15), Vector2(11.2, 6.8), Vector2(13.2, 8.0)
	]
	for i in range(right.size() - 1):
		best = minf(best, _dist_xz(p, right[i], right[i + 1]))
	# short spur from the castle gate toward the river bank
	best = minf(best, _dist_xz(p, Vector2(-5.2, -1.0), Vector2(-1.4, 2.2)))
	return clampf(1.0 - best / 1.15, 0.0, 1.0)


static func _in_water(x: float, z: float = 0.0) -> bool:
	if x <= -0.05 or x >= 4.05:
		return false
	# Buildable river islands stay dry.
	if (z >= -14.05 and z <= -10.95) or (z >= 17.95 and z <= 21.05):
		return false
	return true


static func _lawn_y(x: float, z: float) -> float:
	var h := 0.03
	h += sin(x * 0.37 + 1.2) * sin(z * 0.29 + 0.4) * 0.13
	h += sin(x * 0.85 + z * 0.61) * 0.055
	h += sin(x * 1.65 - z * 0.9) * 0.022
	# Flatten only under the castle footprint. The front lawn (z > -0.6) stays
	# rolling so the start overview no longer reads as a flat 2012 field.
	if x > -14.2 and x < -2.8 and z > -12.4 and z < -0.6:
		h = lerpf(h, 0.025, 0.9)
	# flatten default build pads (Werkstatt, Sternwarte, trees, props)
	var pads := [
		Vector2(8.5, 6.5),
		Vector2(10.5, -0.5),
		Vector2(11.5, 4.5),
		Vector2(5.5, 8.5),
		Vector2(5.5, 5.5),
		Vector2(6.5, 4.5),
		Vector2(8.8, 10.2),
		Vector2(-20.0, 9.0),
		Vector2(19.0, 8.5),
		Vector2(2.0, -12.5),
		Vector2(2.0, 19.5)
	]
	for pad in pads:
		var d := Vector2(x - pad.x, z - pad.y).length()
		if d < 2.5:
			h = lerpf(h, 0.03, 1.0 - d / 2.5)
	var path := _path_strength(x, z)
	if path > 0.0:
		h = lerpf(h, 0.02, path)
	# soft shoreline drop toward the river
	if x < 0.0:
		var shore := -x
		if shore < 2.1:
			h = lerpf(-0.11, h, smoothstep(0.0, 1.0, shore / 2.1))
	elif x > 4.0:
		var shore_r := x - 4.0
		if shore_r < 2.1:
			h = lerpf(-0.11, h, smoothstep(0.0, 1.0, shore_r / 2.1))
	# slight rise at the outer rim
	var edge := minf(ISLAND_EDGE - absf(x) if not _in_water(x, z) else ISLAND_EDGE, ISLAND_EDGE - absf(z))
	if edge < 1.5:
		h += (1.5 - edge) * 0.07
	return h


static func _lawn_color(x: float, z: float) -> Color:
	var path := _path_strength(x, z)
	var dirt := 0.5 + 0.5 * sin(x * 0.53 + 2.1) * sin(z * 0.47 - 0.8)
	dirt += 0.15 * sin(x * 1.4 + z * 0.9)
	var c := Color(1.0, 1.0, 1.0)
	if dirt > 0.78:
		c = Color(0.70, 0.55, 0.36).lerp(Color(1, 1, 1), 1.0 - (dirt - 0.78) / 0.35)
	if path > 0.05:
		c = c.lerp(Color(0.50, 0.34, 0.20), clampf(path * 1.25, 0.0, 1.0))
	# slightly richer grass away from the path
	if path < 0.1 and dirt < 0.7:
		var lush := 0.5 + 0.5 * sin(x * 0.21 + z * 0.18)
		c = c.lerp(Color(0.90, 1.04, 0.82), lush * 0.18)
	return c


static func add_sculpted_lawn(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.8
	var strips: Array[Vector2] = [Vector2(-ISLAND_EDGE, -0.08), Vector2(4.08, ISLAND_EDGE)]
	for strip in strips:
		var x0 := strip.x
		var x1 := strip.y
		var z := -ISLAND_EDGE
		while z < ISLAND_EDGE - 0.001:
			var z2 := minf(z + step, ISLAND_EDGE)
			var x := x0
			while x < x1 - 0.001:
				var x2 := minf(x + step, x1)
				var p00 := Vector3(x, _lawn_y(x, z), z)
				var p10 := Vector3(x2, _lawn_y(x2, z), z)
				var p11 := Vector3(x2, _lawn_y(x2, z2), z2)
				var p01 := Vector3(x, _lawn_y(x, z2), z2)
				var c00 := _lawn_color(x, z)
				var c10 := _lawn_color(x2, z)
				var c11 := _lawn_color(x2, z2)
				var c01 := _lawn_color(x, z2)
				st.set_color(c00)
				st.set_uv(Vector2(p00.x, p00.z))
				st.add_vertex(p00)
				st.set_color(c10)
				st.set_uv(Vector2(p10.x, p10.z))
				st.add_vertex(p10)
				st.set_color(c11)
				st.set_uv(Vector2(p11.x, p11.z))
				st.add_vertex(p11)
				st.set_color(c00)
				st.set_uv(Vector2(p00.x, p00.z))
				st.add_vertex(p00)
				st.set_color(c11)
				st.set_uv(Vector2(p11.x, p11.z))
				st.add_vertex(p11)
				st.set_color(c01)
				st.set_uv(Vector2(p01.x, p01.z))
				st.add_vertex(p01)
				x = x2
			z = z2
	# Lawn caps on the two buildable river islands.
	var island_spans: Array[Vector2] = [Vector2(-14.05, -10.95), Vector2(17.95, 21.05)]
	for span in island_spans:
		var z: float = span.x
		while z < span.y - 0.001:
			var z2 := minf(z + step, span.y)
			var x := -0.08
			while x < 4.08 - 0.001:
				var x2 := minf(x + step, 4.08)
				var p00 := Vector3(x, _lawn_y(x, z), z)
				var p10 := Vector3(x2, _lawn_y(x2, z), z)
				var p11 := Vector3(x2, _lawn_y(x2, z2), z2)
				var p01 := Vector3(x, _lawn_y(x, z2), z2)
				var c00 := _lawn_color(x, z)
				var c10 := _lawn_color(x2, z)
				var c11 := _lawn_color(x2, z2)
				var c01 := _lawn_color(x, z2)
				st.set_color(c00)
				st.set_uv(Vector2(p00.x, p00.z))
				st.add_vertex(p00)
				st.set_color(c10)
				st.set_uv(Vector2(p10.x, p10.z))
				st.add_vertex(p10)
				st.set_color(c11)
				st.set_uv(Vector2(p11.x, p11.z))
				st.add_vertex(p11)
				st.set_color(c00)
				st.set_uv(Vector2(p00.x, p00.z))
				st.add_vertex(p00)
				st.set_color(c11)
				st.set_uv(Vector2(p11.x, p11.z))
				st.add_vertex(p11)
				st.set_color(c01)
				st.set_uv(Vector2(p01.x, p01.z))
				st.add_vertex(p01)
				x = x2
			z = z2
	var mat: StandardMaterial3D = BuildVoxelStyle.lawn_material().duplicate()
	mat.vertex_color_use_as_albedo = true
	mesh_node(root, commit(st), mat, "SculptedLawn")


static func add_island_cliffs(root: Node3D) -> void:
	## Irregular stone skirt around the island edge (replaces the flat box faces).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131114
	# west and east faces
	for side in [-1.0, 1.0]:
		for i in range(22):
			var z := -23.8 + float(i) * 2.20 + rng.randf_range(-0.25, 0.25)
			var h := 2.15 + rng.randf_range(-0.2, 0.4)
			var w := 2.3 + rng.randf_range(-0.25, 0.45)
			var depth := 0.65 + rng.randf_range(0.0, 0.55)
			append_box(st, Vector3(depth, h, w), Vector3(side * (ISLAND_EDGE + 0.35), -1.25, z))
	# south and north faces, split around the river mouth
	for zside in [-1.0, 1.0]:
		for bank in [-1.0, 1.0]:
			var x_mid := (-12.2 if bank < 0.0 else 14.2)
			for i in range(11):
				var x := x_mid + (float(i) - 5.0) * 2.15 + rng.randf_range(-0.2, 0.2)
				if _in_water(x, zside * ISLAND_EDGE):
					continue
				var h := 2.15 + rng.randf_range(-0.2, 0.35)
				var w := 0.7 + rng.randf_range(0.0, 0.5)
				var length := 2.2 + rng.randf_range(-0.2, 0.4)
				append_box(st, Vector3(length, h, w), Vector3(x, -1.25, zside * (ISLAND_EDGE + 0.35)))
	mesh_node(root, commit(st), BuildVoxelStyle.material("stone", Color("c8bca8")), "IslandCliffs")


static func _append_canyon_rocks(xforms: Array[Transform3D]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131110
	var count := 18 if _is_low() else 28
	for i in range(count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(
			2.0 + side * rng.randf_range(2.4, 5.8),
			rng.randf_range(-6.5, -0.2),
			CANYON_Z + rng.randf_range(0.2, 6.4)
		)
		var scale := Vector3(
			rng.randf_range(0.7, 1.6), rng.randf_range(0.8, 2.2), rng.randf_range(0.8, 1.7)
		)
		xforms.append(Transform3D(Basis.from_scale(scale), at))
	for side in [-1.0, 1.0]:
		for k in range(5):
			var at := Vector3(2.0 + side * (2.2 + float(k) * 0.55), -2.2, CANYON_Z + 0.2 + float(k) * 0.7)
			xforms.append(Transform3D(Basis.from_scale(Vector3(1.4, 4.2 - float(k) * 0.35, 1.2)), at))


static func _append_canyon_plants(xforms: Array[Transform3D]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131110
	var count := 6 if _is_low() else 10
	for i in range(count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(2.0 + side * rng.randf_range(3.2, 5.2), 0.35, CANYON_Z - 0.4 + rng.randf_range(0.0, 1.4))
		var s := 0.35 + float(i % 3) * 0.08
		xforms.append(Transform3D(Basis.from_scale(Vector3(s, s * 1.2, s)), at))


static func _collect_terrain_rocks() -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131113
	var xforms: Array[Transform3D] = []
	# Irregular shoreline clusters instead of a 2 m crystal-and-stone rhythm.
	var cluster_z: Array[float] = [
		-15.2, -12.8, -10.1, -8.4, -5.6, -2.9, -0.4, 2.1, 3.8, 6.7, 8.3, 10.9, 13.4, 15.3
	]
	for bank_x in [-0.42, 4.38]:
		for cz in cluster_z:
			var n := (1 + rng.randi() % 2) if _is_low() else (2 + rng.randi() % 3)
			for _k in range(n):
				var at := Vector3(
					bank_x + rng.randf_range(-0.5, 0.55),
					-0.12 + rng.randf_range(-0.05, 0.10),
					cz + rng.randf_range(-0.75, 0.75)
				)
				if at.x > 0.12 and at.x < 3.88:
					at.x = -0.08 if bank_x < 2.0 else 4.12
				var sc := Vector3(
					rng.randf_range(0.28, 0.72), rng.randf_range(0.18, 0.50), rng.randf_range(0.32, 0.88)
				)
				var basis := Basis.from_euler(
					Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
				)
				xforms.append(Transform3D(basis * Basis.from_scale(sc), at))
	# Outer rim and cliff-face boulders
	var rim := 14 if _is_low() else 26
	for side in [-1.0, 1.0]:
		for i in range(rim):
			var z := rng.randf_range(-ISLAND_EDGE + 0.2, ISLAND_EDGE - 0.2)
			var at := Vector3(side * (ISLAND_EDGE - 0.15) + rng.randf_range(-0.25, 0.25), rng.randf_range(-1.7, 0.12), z)
			var sc := Vector3(rng.randf_range(0.55, 1.45), rng.randf_range(0.45, 1.7), rng.randf_range(0.55, 1.35))
			xforms.append(Transform3D(Basis.from_scale(sc), at))
	var z_rim := 10 if _is_low() else 18
	for zside in [-1.0, 1.0]:
		for i in range(z_rim):
			var x := rng.randf_range(-ISLAND_EDGE + 0.3, ISLAND_EDGE - 0.3)
			if _in_water(x, zside * ISLAND_EDGE):
				continue
			var at := Vector3(x, rng.randf_range(-1.6, 0.12), zside * (ISLAND_EDGE - 0.15) + rng.randf_range(-0.2, 0.2))
			var sc := Vector3(rng.randf_range(0.5, 1.35), rng.randf_range(0.45, 1.5), rng.randf_range(0.5, 1.2))
			xforms.append(Transform3D(Basis.from_scale(sc), at))
	_append_canyon_rocks(xforms)
	return xforms


static func _collect_plants() -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 93231
	var xforms: Array[Transform3D] = []
	var border := 22 if _is_low() else 44
	for i in range(border):
		var at := Vector3(rng.randf_range(-ISLAND_EDGE, ISLAND_EDGE), 0.38, -ISLAND_EDGE + 0.2 if i % 2 == 0 else ISLAND_EDGE - 0.2)
		if _in_water(at.x, at.z):
			continue
		var scale := 0.40 + float(i % 3) * 0.09
		xforms.append(Transform3D(Basis.from_scale(Vector3(scale, scale * 1.15, scale)), at))
	# lawn clumps, kept off courtyards, path and pads
	var clumps := 18 if _is_low() else 50
	var guard := 0
	while xforms.size() < border + clumps and guard < 400:
		guard += 1
		var at := Vector3(rng.randf_range(-23.0, 23.0), 0.22, rng.randf_range(-23.0, 23.0))
		if _in_water(at.x, at.z) or (absf(at.x - 2.0) < 2.4 and not ((at.z >= -14.2 and at.z <= -10.8) or (at.z >= 17.8 and at.z <= 21.2))):
			continue
		if at.x > -14.0 and at.x < -3.2 and at.z > -12.0 and at.z < 3.6:
			continue
		if _path_strength(at.x, at.z) > 0.45:
			continue
		var near_pad := false
		for pad in [Vector2(8.5, 6.5), Vector2(10.5, -0.5), Vector2(8.8, 10.2), Vector2(-20.0, 9.0), Vector2(19.0, 8.5), Vector2(2.0, -12.5), Vector2(2.0, 19.5)]:
			if Vector2(at.x - pad.x, at.z - pad.y).length() < 2.4:
				near_pad = true
				break
		if near_pad:
			continue
		var scale := 0.28 + rng.randf() * 0.22
		at.y = _lawn_y(at.x, at.z) + scale * 0.55
		xforms.append(Transform3D(Basis.from_scale(Vector3(scale, scale * 1.1, scale)), at))
	_append_canyon_plants(xforms)
	return xforms


static func add_flowers(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131115
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var palette: Array[Color] = [
		Color("f3c4d8"), Color("f4d76a"), Color("f0f2e8"), Color("c9b4e8"), Color("f0a56a")
	]
	var count := 26 if _is_low() else 70
	var guard := 0
	while xforms.size() < count and guard < 600:
		guard += 1
		# bias later placements onto the visible front lawn (castle → camera)
		var at: Vector3
		if xforms.size() < int(count * 0.4):
			at = Vector3(rng.randf_range(-13.5, -1.2), 0.0, rng.randf_range(0.4, 14.0))
		else:
			at = Vector3(rng.randf_range(-23.0, 23.0), 0.0, rng.randf_range(-23.0, 23.0))
		if _in_water(at.x, at.z) or (absf(at.x - 2.0) < 2.4 and not ((at.z >= -14.2 and at.z <= -10.8) or (at.z >= 17.8 and at.z <= 21.2))):
			continue
		if at.x > -14.0 and at.x < -3.2 and at.z > -12.0 and at.z < -0.4:
			continue
		if _path_strength(at.x, at.z) > 0.35:
			continue
		at.y = _lawn_y(at.x, at.z) + 0.10
		var s := 0.18 + rng.randf() * 0.12
		var basis := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)) * Basis.from_scale(Vector3(s, s * 1.15, s))
		xforms.append(Transform3D(basis, at))
		colors.append(palette[rng.randi() % palette.size()])
	var bloom := SphereMesh.new()
	bloom.radius = 1.0
	bloom.height = 1.25
	bloom.radial_segments = 8
	bloom.rings = 5
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.albedo_color = Color.WHITE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = bloom
	multi.instance_count = xforms.size()
	for i in range(xforms.size()):
		multi.set_instance_transform(i, xforms[i])
		multi.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.name = "LawnFlowers"
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


static func add_reeds(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131116
	var xforms: Array[Transform3D] = []
	var count := 20 if _is_low() else 48
	var guard := 0
	while xforms.size() < count and guard < 300:
		guard += 1
		var bank := -0.55 if rng.randf() < 0.5 else 4.55
		var z := rng.randf_range(-23.5, 24.0)
		# cluster, not even spacing
		if int(absf(z) * 3.0) % 5 == 0:
			continue
		var at := Vector3(bank + rng.randf_range(-0.35, 0.45), 0.15, z)
		if at.x > 0.15 and at.x < 3.85:
			at.x = -0.2 if bank < 2.0 else 4.2
		var h := 0.75 + rng.randf() * 0.70
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
		xforms.append(Transform3D(tilt * Basis.from_scale(Vector3(1, h, 1)), at))
	# a few on the canyon rim
	for i in range(4 if _is_low() else 8):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(2.0 + side * rng.randf_range(2.6, 4.4), 0.2, CANYON_Z - 0.5 + rng.randf_range(0.0, 1.2))
		xforms.append(Transform3D(Basis.from_scale(Vector3(1, 0.7 + rng.randf() * 0.4, 1)), at))
	var reed := CylinderMesh.new()
	reed.top_radius = 0.035
	reed.bottom_radius = 0.06
	reed.height = 1.0
	reed.radial_segments = 6
	reed.rings = 1
	var node := BuildVoxelStyle.multimesh(
		root, "ShoreReeds", reed, BuildVoxelStyle.material("leaves", Color("5b8f46")), xforms
	)
	_no_shadow(node)


static func add_shore_foam(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131117
	var xforms: Array[Transform3D] = []
	var count := 18 if _is_low() else 42
	for i in range(count):
		var bank := -0.08 if i % 2 == 0 else 4.08
		var z := rng.randf_range(-23.8, 24.2)
		var at := Vector3(bank + rng.randf_range(-0.2, 0.2), -0.26, z)
		var sc := Vector3(rng.randf_range(0.7, 1.25), 0.12, rng.randf_range(0.9, 1.6))
		xforms.append(Transform3D(Basis.from_scale(sc), at))
	# compact foam at the waterfall lip (subtle, not ice sheets)
	for i in range(3 if _is_low() else 6):
		var at := Vector3(2.0 + rng.randf_range(-1.1, 1.1), -0.25, CANYON_Z - 0.4 + rng.randf_range(-0.25, 0.4))
		var sc := Vector3(rng.randf_range(0.40, 0.70), 0.08, rng.randf_range(0.35, 0.65))
		xforms.append(Transform3D(Basis.from_scale(sc), at))
	# plunge-pool foam around the waterfall basin
	var basin := 6 if _is_low() else 12
	for i in range(basin):
		var at := Vector3(
			2.0 + rng.randf_range(-2.2, 2.2),
			-6.96,
			CANYON_Z + 3.0 + rng.randf_range(-1.8, 1.8)
		)
		var sc := Vector3(rng.randf_range(0.8, 1.4), 0.14, rng.randf_range(0.8, 1.4))
		xforms.append(Transform3D(Basis.from_scale(sc), at))
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.94, 0.98, 1.0, 0.48)
	mat.roughness = 0.72
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.93, 0.98)
	mat.emission_energy_multiplier = 0.22
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := BuildVoxelStyle.multimesh(root, "ShoreFoam", puff, mat, xforms)
	_no_shadow(node)


static func add_sky_islands(root: Node3D, kit: RefCounted) -> void:
	## Same seven backdrop islands, batched so the pulled-back start camera stays in budget.
	var body_xforms: Array[Transform3D] = []
	var cap_xforms: Array[Transform3D] = []
	var tree_xforms: Array[Transform3D] = []
	var fall_xforms: Array[Transform3D] = []
	var fall_rock_xforms: Array[Transform3D] = []
	var castle_xforms: Array[Transform3D] = []
	for i in range(7):
		var island_at := Vector3(-35 + float(i) * 12, -7 + float(i % 3) * 3, -42 - float(i % 2) * 8)
		body_xforms.append(Transform3D(Basis.IDENTITY, island_at))
		cap_xforms.append(Transform3D(Basis.IDENTITY, island_at + Vector3.UP * 4.5))
		if i in [1, 3, 5]:
			var s := 0.7 if i != 3 else 1.0
			castle_xforms.append(Transform3D(Basis.from_scale(Vector3.ONE * s), island_at + Vector3.UP * 4.75))
		else:
			tree_xforms.append(Transform3D(Basis.IDENTITY, island_at + Vector3(-1, 4.75, -1)))
		if i % 2 == 0:
			var fall_at := island_at + Vector3(3.6, -4, 0)
			var fall_basis := Basis.from_scale(Vector3(1, 3, 1))
			fall_xforms.append(Transform3D(fall_basis, fall_at + fall_basis * Vector3(0.5, 1.5, 0.5)))
			fall_rock_xforms.append(Transform3D(fall_basis, fall_at))
	var body := BuildVoxelStyle.multimesh(
		root,
		"SkyIslandBody",
		preload("res://scripts/creative/floating_island.gd").create(),
		BuildVoxelStyle.material("stone", Color("cbbca6")),
		body_xforms
	)
	_no_shadow(body)
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 5.1
	cap_mesh.bottom_radius = 5.1
	cap_mesh.height = 0.35
	cap_mesh.radial_segments = 14
	cap_mesh.rings = 1
	_no_shadow(
		BuildVoxelStyle.multimesh(root, "SkyIslandCap", cap_mesh, BuildVoxelStyle.lawn_material(), cap_xforms)
	)
	_no_shadow(
		BuildVoxelStyle.multimesh(
			root,
			"SkyIslandCastleStone",
			_far_castle_sand_mesh(),
			BuildVoxelStyle.material("sand", Color("d9a86c")),
			castle_xforms
		)
	)
	_no_shadow(
		BuildVoxelStyle.multimesh(
			root,
			"SkyIslandCastleRoof",
			_far_castle_roof_mesh(),
			BuildVoxelStyle.material("roof", Color("355fbc")),
			castle_xforms
		)
	)
	_no_shadow(
		BuildVoxelStyle.multimesh(
			root,
			"SkyIslandTrees",
			branched_tree_bark_mesh(),
			BuildVoxelStyle.material("bark", Color("c4a07a")),
			tree_xforms
		)
	)
	_no_shadow(
		BuildVoxelStyle.multimesh(
			root,
			"SkyIslandCrowns",
			branched_tree_leaves_mesh(),
			BuildVoxelStyle.material("leaves", Color("9ed56a")),
			tree_xforms
		)
	)
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.85, 2.95, 0.28)
	var fall_mat := ShaderMaterial.new()
	fall_mat.shader = preload("res://assets/shaders/kart_waterfall.gdshader")
	_no_shadow(BuildVoxelStyle.multimesh(root, "SkyIslandFalls", sheet, fall_mat, fall_xforms))
	_no_shadow(
		BuildVoxelStyle.multimesh(
			root,
			"SkyIslandFallRocks",
			waterfall_rock_mesh(),
			BuildVoxelStyle.material("stone", Color("d2c7b4")),
			fall_rock_xforms
		)
	)
	# kit kept in the signature so call sites stay consistent with other dressers
	if kit == null:
		pass


static var _castle_sand: ArrayMesh
static var _castle_roof: ArrayMesh


static func _far_castle_sand_mesh() -> ArrayMesh:
	if _castle_sand != null:
		return _castle_sand
	var sand := SurfaceTool.new()
	sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-4.0, 4.0]:
		append_cyl(sand, 1.25, 5.8, Vector3(x, 2.9, 0), Basis.IDENTITY, 1.25, 10)
	append_box(sand, Vector3(6.8, 3.8, 2.8), Vector3(0, 1.9, 0))
	append_box(sand, Vector3(1.3, 2.3, 0.12), Vector3(0, 1.15, 1.42))
	_castle_sand = commit(sand)
	return _castle_sand


static func _far_castle_roof_mesh() -> ArrayMesh:
	if _castle_roof != null:
		return _castle_roof
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-4.0, 4.0]:
		append_cyl(roof, 1.8, 3.0, Vector3(x, 7.25, 0), Basis.IDENTITY, 0.0, 10)
	var prism := PrismMesh.new()
	prism.size = Vector3(7.4, 2.0, 3.4)
	roof.append_from(prism, 0, Transform3D(Basis.IDENTITY, Vector3(0, 4.8, 0)))
	_castle_roof = commit(roof)
	return _castle_roof


static func add_build_site(root: Node3D, at: Vector3 = Vector3(8.8, 0, 10.2)) -> void:
	## Tafel-03 timber crane and a small building site next to the Werkstatt.
	## Decor only: no collision, no catalog id, saves stay unchanged.
	var site := Node3D.new()
	site.name = "BuildSiteCrane"
	site.position = at
	site.rotation.y = 1.57
	root.add_child(site)
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(stone, Vector3(2.5, 0.28, 2.5), Vector3(0, 0.14, 0))
	append_box(stone, Vector3(0.7, 0.18, 0.7), Vector3(-1.35, 0.22, 1.15))
	mesh_node(site, commit(stone), BuildVoxelStyle.material("stone", Color("d2c7b4")), "CraneBase")
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	# four legs and mast
	for x in [-0.55, 0.55]:
		for z in [-0.55, 0.55]:
			append_box(wood, Vector3(0.16, 2.15, 0.16), Vector3(x, 1.22, z))
	append_box(wood, Vector3(1.35, 0.12, 1.35), Vector3(0, 2.32, 0))
	append_cyl(wood, 0.15, 5.4, Vector3(0, 5.05, 0), Basis.IDENTITY, 0.13, 8)
	# cabin
	append_box(wood, Vector3(0.95, 0.72, 0.8), Vector3(0.15, 7.55, 0.1))
	# boom, slightly raised
	var boom := Basis.from_euler(Vector3(0.0, 0.0, -0.42))
	append_box(wood, Vector3(7.2, 0.16, 0.18), boom * Vector3(3.2, 0, 0) + Vector3(0.1, 7.85, 0), boom)
	append_box(wood, Vector3(1.6, 0.18, 0.18), Vector3(-1.1, 7.7, 0))
	append_box(wood, Vector3(0.55, 0.7, 0.4), Vector3(-1.7, 7.35, 0))
	# scaffold and plank pile
	for sx in [-1.6, -1.05]:
		for sz in [1.0, 1.55]:
			append_box(wood, Vector3(0.08, 1.35, 0.08), Vector3(sx, 0.82, sz))
	append_box(wood, Vector3(0.85, 0.08, 0.7), Vector3(-1.32, 1.52, 1.28))
	append_box(wood, Vector3(0.9, 0.12, 0.35), Vector3(1.35, 0.34, 0.9))
	append_box(wood, Vector3(0.7, 0.10, 0.32), Vector3(1.38, 0.44, 0.95))
	mesh_node(site, commit(wood), BuildVoxelStyle.material("wood", Color("e6b84a")), "CraneWood")
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	# stay cables and hook rope
	var rope_basis := Basis.from_euler(Vector3(0.55, 0.0, 0.0))
	append_cyl(iron, 0.025, 3.4, Vector3(3.6, 6.1, 0), Basis.from_euler(Vector3(0, 0, 1.05)), 0.02, 6)
	append_cyl(iron, 0.02, 2.6, Vector3(5.4, 6.4, 0), Basis.IDENTITY, 0.02, 6)
	append_cyl(iron, 0.05, 0.16, Vector3(5.4, 5.15, 0), Basis.IDENTITY, 0.05, 6)
	append_box(iron, Vector3(0.18, 0.08, 0.08), Vector3(5.4, 5.02, 0))
	mesh_node(site, commit(iron), BuildVoxelStyle.material("plain", Color("4a4a52")), "CraneRig")
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_box(glass, Vector3(0.58, 0.58, 0.58), Vector3(5.4, 4.65, 0))
	append_box(glass, Vector3(0.5, 0.5, 0.5), Vector3(-1.35, 0.55, 1.15))
	var glass_mat: StandardMaterial3D = BuildVoxelStyle.material("glass", Color("7ae6ff"))
	var glass_node := mesh_node(site, commit(glass), glass_mat, "CraneLoad")
	# keep the hanging block readable without an extra material
	if glass_node:
		pass



static func add_dirt_patches(root: Node3D) -> void:
	## Visible earth path and patches (batched). Complements lawn vertex colors.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131118
	var xforms: Array[Transform3D] = []
	var samples: Array[Vector2] = []
	var polylines: Array = [
		[Vector2(-8.0, -4.2), Vector2(-8.0, 1.4), Vector2(-4.4, 4.0), Vector2(-1.15, 6.0)],
		[Vector2(4.15, 6.0), Vector2(7.1, 6.15), Vector2(8.4, 8.4)],
		[Vector2(-5.2, -1.0), Vector2(-1.4, 2.2)]
	]
	for line in polylines:
		for i in range(line.size() - 1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var steps := maxi(2, int(a.distance_to(b) / 0.55))
			for s in range(steps + 1):
				var p: Vector2 = a.lerp(b, float(s) / float(steps))
				samples.append(p)
	for p in samples:
		if _in_water(p.x, p.y):
			continue
		var y := _lawn_y(p.x, p.y) + 0.018
		var sc := Vector3(0.85 + rng.randf() * 0.35, 0.05, 0.70 + rng.randf() * 0.30)
		var yaw := rng.randf_range(-0.4, 0.4)
		xforms.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_scale(sc), Vector3(p.x, y, p.y)))
	# loose earth patches on the front lawn
	var extra := 5 if _is_low() else 10
	for i in range(extra):
		var at := Vector3(rng.randf_range(-12.0, -2.0), 0.0, rng.randf_range(1.0, 12.0))
		if _path_strength(at.x, at.z) > 0.5:
			continue
		at.y = _lawn_y(at.x, at.z) + 0.016
		var sc := Vector3(rng.randf_range(0.7, 1.4), 0.045, rng.randf_range(0.5, 1.1))
		xforms.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)) * Basis.from_scale(sc), at))
	var patch := CylinderMesh.new()
	patch.top_radius = 0.7
	patch.bottom_radius = 0.7
	patch.height = 1.0
	patch.radial_segments = 8
	patch.rings = 1
	var node := BuildVoxelStyle.multimesh(
		root, "DirtPatches", patch, BuildVoxelStyle.material("dirt", Color("c2a074")), xforms
	)
	_no_shadow(node)


static func dress_world(root: Node3D, kit: RefCounted) -> void:
	## Visual-only island dressing for the start overview. Collision stays on RiverBank.
	add_sculpted_lawn(root)
	add_dirt_patches(root)
	add_island_cliffs(root)
	var rock_node := BuildVoxelStyle.multimesh(
		root,
		"RiverRocks",
		kit.SHAPES.rock(),
		BuildVoxelStyle.material("stone", Color("d2c7b4")),
		_collect_terrain_rocks()
	)
	_no_shadow(rock_node)
	var bush := SphereMesh.new()
	bush.radius = 1.0
	bush.height = 1.55
	bush.radial_segments = 12
	bush.rings = 8
	var plants := BuildVoxelStyle.multimesh(
		root, "BorderPlants", bush, BuildVoxelStyle.material("leaves", Color("8fce5c")), _collect_plants()
	)
	_no_shadow(plants)
	add_flowers(root)
	add_reeds(root)
	add_sky_islands(root, kit)
	add_canyon(root, kit)
	add_shore_foam(root)
	add_build_site(root)
