class_name BuildLandmarks
extends RefCounted
## Combined-mesh landmarks for Bauwelt: Fachwerk-Werkstatt, Sternwarte,
## verzweigte Baeume, Bogenbruecke, Wasserfall mit Fels und L-Emblem.
## Footprints, collision and part IDs stay with the catalog / build_state.


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


static func add_branched_tree(body: Node) -> void:
	## Trunk plus three outward branches (bark) and a clustered crown (leaves).
	## Collision stays a 0.4 x 2 x 0.4 stem so existing saves keep their footprint.
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
	mesh_node(body, commit(bark), BuildVoxelStyle.material("bark", Color("c4a07a")), "Trunk")
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
	mesh_node(body, commit(leaves), BuildVoxelStyle.material("leaves", Color("9ed56a")), "Crown")


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
	var rock_xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20131110
	for i in range(28):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(
			2.0 + side * rng.randf_range(2.4, 5.8),
			rng.randf_range(-6.5, -0.2),
			16.6 + rng.randf_range(0.2, 6.4)
		)
		var scale := Vector3(
			rng.randf_range(0.7, 1.6), rng.randf_range(0.8, 2.2), rng.randf_range(0.8, 1.7)
		)
		rock_xforms.append(Transform3D(Basis.from_scale(scale), at))
	# cliff shoulders framing the drop
	for side in [-1.0, 1.0]:
		for k in range(5):
			var at := Vector3(2.0 + side * (2.2 + float(k) * 0.55), -2.2, 16.8 + float(k) * 0.7)
			rock_xforms.append(Transform3D(Basis.from_scale(Vector3(1.4, 4.2 - float(k) * 0.35, 1.2)), at))
	BuildVoxelStyle.multimesh(
		root,
		"CanyonRocks",
		kit.SHAPES.rock(),
		BuildVoxelStyle.material("stone", Color("cbbca6")),
		rock_xforms
	)
	# falling sheets
	var fall_xforms: Array[Transform3D] = []
	for i in range(3):
		var at := Vector3(1.2 + float(i) * 0.8, -3.2, 16.7)
		fall_xforms.append(Transform3D(Basis.from_scale(Vector3(0.55, 3.4, 0.18)), at))
	var fall_mat := ShaderMaterial.new()
	fall_mat.shader = preload("res://assets/shaders/kart_waterfall.gdshader")
	var fall_mesh := BoxMesh.new()
	fall_mesh.size = Vector3.ONE
	BuildVoxelStyle.multimesh(root, "CanyonFalls", fall_mesh, fall_mat, fall_xforms)
	# plunge pool
	var pool: MeshInstance3D = kit.box(root, Vector3(2.0, -7.15, 19.6), Vector3(6.5, 0.22, 5.5), Color("1b81bd"))
	pool.name = "CanyonPool"
	var pool_mat := ShaderMaterial.new()
	pool_mat.shader = preload("res://assets/shaders/kart_water.gdshader")
	pool.material_override = pool_mat
	# a few ferns on the rim, batched
	var plant_xforms: Array[Transform3D] = []
	for i in range(10):
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(2.0 + side * rng.randf_range(3.2, 5.2), 0.35, 16.2 + rng.randf_range(0.0, 1.4))
		var s := 0.35 + float(i % 3) * 0.08
		plant_xforms.append(Transform3D(Basis.from_scale(Vector3(s, s * 1.2, s)), at))
	var bush := SphereMesh.new()
	bush.radius = 1.0
	bush.height = 1.55
	bush.radial_segments = 10
	bush.rings = 6
	BuildVoxelStyle.multimesh(
		root, "CanyonPlants", bush, BuildVoxelStyle.material("leaves", Color("8fce5c")), plant_xforms
	)


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
