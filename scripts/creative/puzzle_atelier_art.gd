extends RefCounted
## Visible atelier dressing for Puzzle: arched garden windows, table props,
## gold details and plants. Repeated meshes go through MultiMesh so the
## start camera stays inside the draw-call budget.
const GARDEN := preload("res://assets/creative/puzzle/atelier_garden.webp")


static func apply(root: Node3D, _kit = null, tier: String = "") -> void:
	var budget: Dictionary = LumoQuality.budget(tier)
	var density: float = clampf(float(budget.get("decor_density", 1.0)), 0.35, 1.0)
	_room(root)
	_windows(root)
	_garden(root)
	_shelves_and_books(root, density)
	_table_props(root, density)
	if density > 0.45:
		_ivy(root, density)
		_lanterns(root)
	if density > 0.72:
		_banners(root)
	_title(root)
	_window_light(root)


static func _mat(
	albedo: Color, emission: Color = Color.BLACK, energy: float = 0.0, metallic: float = 0.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.62 if metallic < 0.4 else 0.32
	mat.metallic = metallic
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


static func _xform(origin: Vector3, size: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(size), origin)


static func _batch(
	root: Node3D, mesh: Mesh, material: Material, xforms: Array[Transform3D], name: String
) -> void:
	if xforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = xforms.size()
	for i in range(xforms.size()):
		multi.set_instance_transform(i, xforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = name
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


static func _room(root: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var plaster: Array[Transform3D] = []
	# Side sections of the back wall, leaving three window openings.
	plaster.append(_xform(Vector3(-8.28, 3.2, -7.35), Vector3(7.45, 6.5, 0.4)))
	plaster.append(_xform(Vector3(8.28, 3.2, -7.35), Vector3(7.45, 6.5, 0.4)))
	plaster.append(_xform(Vector3(-1.65, 3.2, -7.35), Vector3(0.82, 6.5, 0.4)))
	plaster.append(_xform(Vector3(1.65, 3.2, -7.35), Vector3(0.82, 6.5, 0.4)))
	# Sill band and cornice across the window row.
	plaster.append(_xform(Vector3(0.0, 0.95, -7.35), Vector3(9.2, 1.9, 0.4)))
	plaster.append(_xform(Vector3(0.0, 6.22, -7.35), Vector3(9.2, 0.85, 0.4)))
	# Side walls so the room has depth from the start camera.
	plaster.append(_xform(Vector3(-12.15, 3.2, -1.6), Vector3(0.42, 6.5, 11.6)))
	plaster.append(_xform(Vector3(12.15, 3.2, -1.6), Vector3(0.42, 6.5, 11.6)))
	_batch(root, box, _mat(Color("f0d4b4")), plaster, "PuzzleWalls")
	# Arch stones over each window.
	var arches: Array[Transform3D] = []
	for x in [-3.3, 0.0, 3.3]:
		for i in range(9):
			var t: float = float(i) / 8.0
			var angle: float = PI * (1.0 - t)
			var px: float = x + cos(angle) * 1.32
			var py: float = 4.52 + sin(angle) * 1.22
			arches.append(_xform(Vector3(px, py, -7.32), Vector3(0.4, 0.3, 0.46), angle - PI * 0.5))
	_batch(root, box, _mat(Color("e8c9a0")), arches, "PuzzleArches")


static func _windows(root: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var frames: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	for x in [-3.3, 0.0, 3.3]:
		frames.append(_xform(Vector3(x - 1.28, 3.22, -7.16), Vector3(0.16, 2.64, 0.16)))
		frames.append(_xform(Vector3(x + 1.28, 3.22, -7.16), Vector3(0.16, 2.64, 0.16)))
		frames.append(_xform(Vector3(x, 1.92, -7.16), Vector3(2.56, 0.14, 0.2)))
		frames.append(_xform(Vector3(x, 4.52, -7.16), Vector3(2.56, 0.14, 0.2)))
		glass.append(_xform(Vector3(x, 3.22, -7.22), Vector3(2.38, 2.5, 0.04)))
	_batch(root, box, _mat(Color("c99558"), Color.BLACK, 0.0, 0.08), frames, "PuzzleWindowFrames")
	var pane := _mat(Color(0.62, 0.82, 0.98, 0.38), Color("d7eefe"), 0.35)
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.roughness = 0.08
	_batch(root, box, pane, glass, "PuzzleWindowGlass")


static func _garden(root: Node3D) -> void:
	var board := BoxMesh.new()
	board.size = Vector3.ONE
	var view := MeshInstance3D.new()
	view.name = "PuzzleGardenView"
	view.mesh = board
	view.position = Vector3(0.0, 3.7, -8.55)
	view.scale = Vector3(20.0, 8.6, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = GARDEN
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	view.material_override = mat
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(view)


static func _shelves_and_books(root: Node3D, density: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var wood: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		wood.append(_xform(Vector3(side * 11.15, 1.85, -3.9), Vector3(1.65, 3.7, 3.5)))
		for shelf_y in [0.55, 1.35, 2.15, 2.95]:
			wood.append(_xform(Vector3(side * 11.05, shelf_y, -3.9), Vector3(1.78, 0.1, 3.55)))
	_batch(root, box, _mat(Color("d7a66c")), wood, "PuzzleShelves")
	var books: Array[Transform3D] = []
	var colors: Array[Color] = [
		Color("4a78c4"), Color("c46a58"), Color("e0b252"), Color("5c9a68"), Color("7a5cb0")
	]
	# One MultiMesh per book color would cost 5 DC; tint via a single warm cloth instead,
	# and vary scale/rotation so the shelf still reads as a row of books.
	var book_count: int = 10 if density > 0.5 else 6
	for i in range(book_count):
		var side: float = -1.0 if i < book_count / 2 else 1.0
		var local: int = i % (book_count / 2)
		books.append(
			_xform(
				Vector3(side * 11.1, 0.82 + float(local % 4) * 0.8, -4.8 + float(local) * 0.55),
				Vector3(1.05, 0.36 + float(i % 3) * 0.05, 0.78),
				float(i) * 0.04
			)
		)
	_batch(root, box, _mat(Color("4f6fb0")), books, "PuzzleBooks")
	# A second small batch for warm-colored spines so the shelf is not monochrome.
	var warm: Array[Transform3D] = []
	for i in range(maxi(3, int(round(6.0 * density)))):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		warm.append(
			_xform(
				Vector3(side * 11.1, 1.22 + float(i % 3) * 0.8, -3.4 + float(i % 4) * 0.42),
				Vector3(1.02, 0.32, 0.7),
				0.08
			)
		)
	_batch(root, box, _mat(colors[2]), warm, "PuzzleBooksWarm")


static func _table_props(root: Node3D, density: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 16
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 8
	# Compass: brass body, gold ring, red needle, glass cap.
	var compass := Node3D.new()
	compass.name = "PuzzleCompass"
	compass.position = Vector3(-3.55, 0.12, 4.15)
	root.add_child(compass)
	_mesh(compass, cyl, Vector3(0.0, 0.02, 0.0), Vector3(0.72, 0.08, 0.72), _mat(Color("6a4a28"), Color.BLACK, 0.0, 0.35))
	_mesh(compass, cyl, Vector3(0.0, 0.08, 0.0), Vector3(0.64, 0.05, 0.64), _mat(Color("d6b25a"), Color("a67c28"), 0.2, 0.78))
	_mesh(compass, box, Vector3(0.0, 0.12, 0.02), Vector3(0.06, 0.04, 0.46), _mat(Color("c45a48"), Color("c45a48"), 0.15))
	var glass := _mat(Color(0.7, 0.85, 1.0, 0.28), Color("d7eefe"), 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(compass, cyl, Vector3(0.0, 0.14, 0.0), Vector3(0.58, 0.04, 0.58), glass)
	# Flower pots along the front edge and near the windows.
	var pots: Array[Transform3D] = []
	pots.append(_xform(Vector3(3.45, 0.16, 4.18), Vector3(0.42, 0.32, 0.42)))
	pots.append(_xform(Vector3(-4.8, 0.16, -3.85), Vector3(0.4, 0.3, 0.4)))
	if density > 0.5:
		pots.append(_xform(Vector3(4.85, 0.16, -3.7), Vector3(0.38, 0.3, 0.38)))
	_batch(root, cyl, _mat(Color("b07048")), pots, "PuzzlePots")
	var blooms: Array[Transform3D] = []
	var flower_spots: Array[Vector3] = [Vector3(3.45, 0.48, 4.18), Vector3(-4.8, 0.46, -3.85)]
	if density > 0.5:
		flower_spots.append(Vector3(4.85, 0.46, -3.7))
	for spot in flower_spots:
		for i in range(7 if density > 0.5 else 4):
			var yaw: float = float(i) * 0.9
			blooms.append(
				_xform(
					spot + Vector3(cos(yaw) * 0.16, 0.08 + float(i % 3) * 0.05, sin(yaw) * 0.16),
					Vector3(0.22, 0.2, 0.22)
				)
			)
	_batch(root, sphere, _mat(Color("6aa0e0"), Color("8ec4ff"), 0.18), blooms, "PuzzleHydrangeas")
	# Crystal on a gold stand, visible near the right window.
	_mesh(root, cyl, Vector3(5.15, 0.16, -3.55), Vector3(0.28, 0.12, 0.28), _mat(Color("d6b25a"), Color("a67c28"), 0.18, 0.8))
	_mesh(
		root,
		sphere,
		Vector3(5.15, 0.42, -3.55),
		Vector3(0.28, 0.42, 0.28),
		_mat(Color(0.55, 0.82, 1.0, 0.85), Color("9ad8ff"), 0.55, 0.2)
	)
	# Small book stack in front of the board.
	var stack: Array[Transform3D] = []
	stack.append(_xform(Vector3(-1.55, 0.1, 4.28), Vector3(0.95, 0.12, 0.7), 0.18))
	stack.append(_xform(Vector3(-1.52, 0.22, 4.28), Vector3(0.9, 0.1, 0.66), 0.05))
	stack.append(_xform(Vector3(-1.58, 0.33, 4.28), Vector3(0.86, 0.1, 0.62), -0.12))
	_batch(root, box, _mat(Color("3e6db5")), stack, "PuzzleDeskBooks")
	# Gold L-badge just in front of the board, readable from the start camera.
	_mesh(root, box, Vector3(0.0, 0.13, 3.52), Vector3(0.72, 0.08, 0.42), _mat(Color("d6b25a"), Color("a67c28"), 0.28, 0.8))
	var badge := Label3D.new()
	badge.name = "PuzzleBadgeL"
	badge.text = "L"
	badge.font_size = 48
	badge.modulate = Color("fff4d0")
	badge.position = Vector3(0.0, 0.22, 3.52)
	badge.rotation_degrees = Vector3(-90, 0, 0)
	badge.pixel_size = 0.012
	root.add_child(badge)


static func _ivy(root: Node3D, density: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var leaves: Array[Transform3D] = []
	var count: int = int(round(28.0 * density))
	for i in range(count):
		var x: float = -6.4 + float(i) * (12.8 / maxf(1.0, float(count - 1)))
		leaves.append(
			_xform(
				Vector3(x, 5.55 + sin(float(i) * 0.7) * 0.18, -7.05),
				Vector3(0.34, 0.16, 0.22),
				float(i) * 0.4
			)
		)
		if i % 3 == 0:
			leaves.append(_xform(Vector3(x, 5.15, -7.02), Vector3(0.22, 0.28, 0.14), 0.3))
	_batch(root, box, _mat(Color("3f8a52")), leaves, "PuzzleIvy")


static func _lanterns(root: Node3D) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 12
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var bodies: Array[Transform3D] = []
	var glows: Array[Transform3D] = []
	for x in [-5.4, 5.4]:
		bodies.append(_xform(Vector3(x, 5.15, -6.55), Vector3(0.22, 0.42, 0.22)))
		glows.append(_xform(Vector3(x, 5.15, -6.55), Vector3(0.28, 0.28, 0.28)))
	_batch(root, cyl, _mat(Color("8a5a28"), Color.BLACK, 0.0, 0.45), bodies, "PuzzleLanternBodies")
	_batch(root, sphere, _mat(Color("ffd89a"), Color("ffc878"), 0.7), glows, "PuzzleLanternGlows")


static func _banners(root: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cloth: Array[Transform3D] = []
	for x in [-1.65, 1.65]:
		cloth.append(_xform(Vector3(x, 4.85, -7.05), Vector3(0.55, 1.15, 0.06)))
	_batch(root, box, _mat(Color("2a4e9a"), Color("3d6fd0"), 0.12), cloth, "PuzzleBanners")


static func _title(root: Node3D) -> void:
	var title := Label3D.new()
	title.name = "PuzzleTitle"
	title.text = "LUMO PUZZLE"
	title.font_size = 86
	title.modulate = Color("ffe7a0")
	title.outline_modulate = Color("8a5a18")
	title.outline_size = 10
	title.position = Vector3(0.0, 6.42, -7.02)
	title.pixel_size = 0.018
	root.add_child(title)


static func _window_light(root: Node3D) -> void:
	var light := OmniLight3D.new()
	light.name = "PuzzleWindowFill"
	light.position = Vector3(0.0, 4.15, -6.2)
	light.light_color = Color("ffe6b8")
	light.light_energy = 0.55
	light.omni_range = 14.0
	light.shadow_enabled = false
	root.add_child(light)


static func _mesh(
	root: Node3D, mesh: Mesh, at: Vector3, size: Vector3, material: Material
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = size
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return node
