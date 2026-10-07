extends RefCounted
## Original, instanced architectural kit. All positions are beside/below the
## existing physical roadway; race routes, checkpoints and wall limits stay shared.

const CREAM := Color("f5dcc2")
const ROSE := Color("df72a9")
const BERRY := Color("b94782")
const INK := Color("383353")
const GOLD := Color("f1bd61")
const MINT := Color("77d5cc")
const BASALT := Color("35374c")


static func build(world) -> void:
	match world.track_id:
		"candy_cloud":
			_candy_world(world)
		"volcano_night":
			_volcano_world(world)
		"sonnenhafen":
			_harbour_fronts(world)
		"desert_drift":
			_desert_city(world)


static func _piece(
	world,
	kind: String,
	at: Vector3,
	local: Vector3,
	size: Vector3,
	color: Color,
	basis: Basis,
	glow: bool = false
) -> void:
	world._prop(kind, at + basis * local, size, color, basis, glow)


static func _window(
	world,
	at: Vector3,
	basis: Basis,
	width: float,
	height: float,
	frame_color: Color = CREAM,
	light: Color = INK
) -> void:
	_piece(world, "box", at, Vector3.ZERO, Vector3(width, height, 0.22), frame_color, basis)
	_piece(
		world,
		"box",
		at,
		Vector3(0, 0, 0.14),
		Vector3(width * 0.72, height * 0.76, 0.12),
		light,
		basis
	)
	_piece(
		world,
		"box",
		at,
		Vector3(0, 0, 0.22),
		Vector3(width * 0.08, height * 0.80, 0.06),
		frame_color,
		basis
	)
	_piece(
		world,
		"box",
		at,
		Vector3(0, -height * 0.54, 0.18),
		Vector3(width * 1.25, 0.16, 0.40),
		frame_color,
		basis
	)
	_piece(
		world,
		"ball",
		at,
		Vector3(0, height * 0.5, 0),
		Vector3(width * 0.5, width * 0.36, 0.13),
		frame_color,
		basis
	)
	_piece(
		world,
		"ball",
		at,
		Vector3(0, height * 0.5, 0.10),
		Vector3(width * 0.35, width * 0.25, 0.08),
		light,
		basis
	)


static func _tower(
	world, at: Vector3, basis: Basis, height: float, radius: float, color: Color, roof: Color
) -> void:
	_piece(
		world,
		"cylinder",
		at,
		Vector3(0, height * 0.5, 0),
		Vector3(radius, height, radius),
		color,
		basis
	)
	for level in range(4):
		var y: float = 0.45 + float(level) * (height - 1.0) / 3.0
		_piece(
			world,
			"cylinder",
			at,
			Vector3(0, y, 0),
			Vector3(radius * 1.09, 0.23, radius * 1.09),
			CREAM,
			basis
		)
		if level > 0:
			for side in range(4):
				var face: Basis = basis * Basis(Vector3.UP, float(side) * PI * 0.5)
				_window(
					world,
					at + basis * Vector3(0, y - 1.2, 0) + face.z * radius,
					face,
					radius * 0.70,
					1.25,
					CREAM,
					INK
				)
	_piece(
		world,
		"cylinder",
		at,
		Vector3(0, height + 0.15, 0),
		Vector3(radius * 1.20, 0.5, radius * 1.20),
		roof,
		basis
	)
	for tier in range(3):
		var r: float = radius * (1.35 - tier * 0.29)
		var y: float = height + 0.7 + tier * 1.12
		_piece(world, "cone", at, Vector3(0, y + 0.8, 0), Vector3(r, 2.45, r), roof, basis)
		_piece(
			world,
			"cylinder",
			at,
			Vector3(0, y - 0.35, 0),
			Vector3(r * 1.02, 0.12, r * 1.02),
			CREAM,
			basis
		)
	_piece(
		world, "cylinder", at, Vector3(0, height + 5.1, 0), Vector3(0.06, 1.4, 0.06), GOLD, basis
	)
	_piece(world, "star", at, Vector3(0, height + 5.9, 0), Vector3.ONE * 0.35, GOLD, basis)
	_piece(world, "box", at, Vector3(0.5, height + 5.3, 0), Vector3(0.9, 0.5, 0.08), MINT, basis)


static func palace(world, at: Vector3, basis: Basis, scale: float = 1.0) -> void:
	var b: Basis = basis.scaled_local(Vector3.ONE * scale)
	# Layered cake foundation, recessed windows, cornices, four turrets and a spire.
	_piece(world, "cylinder", at, Vector3(0, -0.8, 0), Vector3(12.5, 2.0, 9.0), BERRY, b)
	_piece(world, "cylinder", at, Vector3(0, 0.35, 0), Vector3(12.8, 0.35, 9.3), CREAM, b)
	_piece(world, "box", at, Vector3(0, 3.9, 0), Vector3(16, 7.1, 9.5), ROSE, b)
	for level in [0.9, 3.9, 7.4]:
		_piece(world, "box", at, Vector3(0, level, 0), Vector3(16.6, 0.3, 10.1), CREAM, b)
	for face_index in [0, 1]:
		var face: Basis = b * Basis(Vector3.UP, face_index * PI)
		for row in range(2):
			for column in range(7):
				var local := Vector3((column - 3) * 2.1, 2.1 + row * 3.1, 4.83)
				_window(world, at + face * local, face, 0.90, 1.55)
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			_tower(
				world,
				at + b * Vector3(side * 8, 0, depth * 4.5),
				b,
				10.5 if depth > 0 else 13.0,
				1.85,
				ROSE.lightened(0.12),
				BERRY
			)
	_piece(world, "box", at, Vector3(0, 10.5, 0), Vector3(8.5, 5.8, 7), ROSE.lightened(0.16), b)
	for y in [7.7, 10.6, 13.5]:
		_piece(world, "box", at, Vector3(0, y, 0), Vector3(9.1, 0.28, 7.6), CREAM, b)
	for column in range(3):
		_window(world, at + b * Vector3((column - 1) * 2.5, 10.7, 3.58), b, 1.1, 2.0)
	_tower(world, at + b * Vector3(0, 13.5, 0), b, 8.5, 2.0, ROSE, BERRY)
	# Icing scallops and candy studs are real 3D silhouettes, not a facade image.
	for i in range(17):
		for depth in [-1.0, 1.0]:
			_piece(
				world,
				"ball",
				at,
				Vector3((i - 8) * 0.94, 7.0, depth * 4.98),
				Vector3(0.5, 0.45, 0.18),
				CREAM,
				b
			)
	for i in range(9):
		_piece(
			world,
			"ball",
			at,
			Vector3((i - 4) * 1.68, 0.9, 5.1),
			Vector3.ONE * 0.28,
			[ROSE, MINT, GOLD][i % 3],
			b
		)
	# Central opening reads clearly against the light walls from the racing camera.
	_piece(world, "box", at, Vector3(0, 1.8, 4.98), Vector3(2.5, 3.2, 0.26), INK, b)
	_piece(world, "ball", at, Vector3(0, 3.3, 4.99), Vector3(1.25, 1.25, 0.15), INK, b)
	_piece(world, "arch", at, Vector3(0, 3.2, 5.1), Vector3(1.28, 1.28, 0.22), GOLD, b)
	world.set_meta("palace_count", int(world.get_meta("palace_count", 0)) + 1)


static func donut(world, at: Vector3, basis: Basis, radius: float, icing: Color) -> void:
	world._prop("torus", at, Vector3.ONE * radius * 2.0, Color("b97938"), basis)
	world._prop("icing", at, Vector3.ONE * radius * 2.0, icing, basis)
	for i in range(22 if not world.low_detail else 10):
		var angle: float = i * 2.39996
		var ring: float = radius * (0.72 + sin(i * 4.7) * 0.15)
		var p := Vector3(sin(angle) * ring, radius * 0.21, cos(angle) * ring)
		var twist: Basis = basis * Basis(Vector3.UP, angle + i * 0.9)
		world._prop(
			"box",
			at + basis * p,
			Vector3(0.14, 0.11, 0.42),
			[CREAM, MINT, GOLD, BERRY][i % 4],
			twist
		)


static func _cloud_island(world, at: Vector3, radius: float) -> void:
	for i in range(9 if not world.low_detail else 5):
		var angle: float = i * TAU / 9.0
		var p: Vector3 = (
			at + Vector3(cos(angle) * radius * 0.6, sin(i * 2.1) * 0.7, sin(angle) * radius * 0.45)
		)
		world._prop(
			"ball",
			p,
			Vector3(radius * 0.47, radius * 0.25, radius * 0.42),
			Color("d9d8f1") if i % 3 == 0 else Color("eae2e8")
		)


static func _candy_world(world) -> void:
	var stations: Array = [
		[0.062, -1.0, 1.1],
		[0.16, 1.0, 1.45],
		[0.34, -1.0, 0.9],
		[0.57, 1.0, 1.25],
		[0.83, -1.0, 1.0]
	]
	for station in stations:
		var d: float = world.length * station[0]
		var basis: Basis = world.frame(d)
		var side: float = station[1]
		var at: Vector3 = world.position_at(d, side * (24.0 + station[2] * 3.0))
		_cloud_island(world, at - Vector3.UP * 3, 19)
		var face: Basis = basis * Basis(Vector3.UP, -PI * 0.5 * side)
		palace(world, at, face, station[2])
	for i in range(24):
		var d: float = world.length * (i + 0.4) / 24.0
		var b: Basis = world.frame(d)
		var side: float = -1.0 if i % 2 else 1.0
		var at: Vector3 = world.position_at(d, side * (13.0 + i % 3 * 2.0))
		_cloud_island(world, at - Vector3.UP * 5, 9)
		if i % 3 != 0:
			donut(
				world,
				at + Vector3.UP * 5.0,
				b * Basis(Vector3.RIGHT, PI * 0.5),
				3.0 + (i % 2),
				[ROSE, MINT, BERRY][i % 3]
			)
		else:
			var cookie_basis: Basis = b * Basis(Vector3.RIGHT, PI * 0.5)
			world._prop(
				"cylinder",
				at + Vector3.UP * 4,
				Vector3(2.8, 0.6, 2.8),
				Color("c48a4c"),
				cookie_basis
			)
			for chip in range(10):
				var angle: float = chip * 2.39996
				var p := Vector3(
					cos(angle) * (1.2 + chip % 2 * 0.6), 0.38, sin(angle) * (1.2 + chip % 2 * 0.6)
				)
				world._prop(
					"ball",
					at + Vector3.UP * 4 + cookie_basis * p,
					Vector3(0.3, 0.15, 0.26),
					Color("513c44"),
					cookie_basis
				)
	# A candy arcade forms a short architectural passage without occupying the road.
	for i in range(5):
		var d: float = world.length * 0.265 + i * 7.0
		var b: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d)
		world._prop("arch", at + b.y * 2.8, Vector3(7.2, 6.0, 1.0), CREAM, b)
		for side in [-1.0, 1.0]:
			_piece(
				world,
				"cylinder",
				at,
				Vector3(side * 7.7, 1.2, 0),
				Vector3(0.75, 4.0, 0.75),
				ROSE,
				b
			)
			_piece(world, "ball", at, Vector3(side * 7.7, 4.0, 0), Vector3.ONE * 0.9, MINT, b)
		_piece(world, "star", at, Vector3(0, 10.0, 0), Vector3.ONE * 0.55, GOLD, b)
	# Distant cloud banks replace the flat, empty sky/sea junction.
	for i in range(18):
		var angle: float = i * TAU / 18.0
		_cloud_island(world, Vector3(sin(angle) * 185, -4 + i % 3 * 4, cos(angle) * 185), 28)


static func _volcano_world(world) -> void:
	# Stone aqueduct supports along the suspended circuit.
	for i in range(36):
		var d: float = world.length * (i + 0.5) / 36.0
		if world.in_gap(d):
			continue
		var b: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d)
		for side in [-1.0, 1.0]:
			var face: Basis = b * Basis(Vector3.UP, PI * 0.5)
			world._prop(
				"arch", at + b.x * side * 5.6 - Vector3.UP * 8, Vector3(9.3, 6.6, 1.1), BASALT, face
			)
			_piece(
				world,
				"box",
				at,
				Vector3(side * 5.6, -8.5, 10.3),
				Vector3(2.1, 15, 2.7),
				Color("454251"),
				b
			)
			_piece(
				world,
				"box",
				at,
				Vector3(side * 5.6, -0.65, 0),
				Vector3(1.6, 0.7, 24),
				Color("685265"),
				b
			)
			_piece(
				world,
				"box",
				at,
				Vector3(side * 6.0, 1.0, 0),
				Vector3(0.13, 0.14, 4.6),
				Color("ffa735"),
				b,
				true
			)
	for fraction in [0.075, 0.31, 0.58, 0.88]:
		var d: float = world.length * fraction
		var b: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d)
		world._prop("arch", at + b.y * 3.5, Vector3(7.4, 7.0, 1.8), Color("6c5360"), b)
		world._prop(
			"arch", at + b.y * 3.5 + b.z * 1.0, Vector3(7.15, 6.8, 0.14), Color("ec9744"), b, true
		)
		for side in [-1.0, 1.0]:
			_piece(world, "box", at, Vector3(side * 8.9, 6.3, 0), Vector3(3.9, 14, 4.8), BASALT, b)
			for y in [1.0, 5.0, 9.0, 13.0]:
				_piece(
					world,
					"box",
					at,
					Vector3(side * 8.9, y, 0),
					Vector3(4.25, 0.35, 5.1),
					Color("82616b"),
					b
				)
			for tooth in [-1.0, 0.0, 1.0]:
				_piece(
					world,
					"box",
					at,
					Vector3(side * 8.9 + tooth * 1.4, 14.0, 0),
					Vector3(0.7, 1.4, 4.7),
					BASALT,
					b
				)
			for y in [4.0, 8.2]:
				_window(
					world,
					at + b * Vector3(side * 8.9, y, 2.48),
					b,
					1.0,
					2.3,
					Color("82616b"),
					Color("e98934")
				)
			_piece(
				world,
				"cylinder",
				at,
				Vector3(side * 7.2, 3.3, 3.0),
				Vector3(0.14, 2.6, 0.14),
				BASALT,
				b
			)
			_piece(
				world,
				"crystal",
				at,
				Vector3(side * 7.2, 5.0, 3.0),
				Vector3(0.5, 1.25, 0.5),
				Color("ffb74e"),
				b,
				true
			)
		world.set_meta("volcano_gate_count", int(world.get_meta("volcano_gate_count", 0)) + 1)
	# Bold chevrons and transverse warm strips make acceleration readable at speed.
	for i in range(35):
		var d: float = world.length * (i + 0.2) / 35.0
		if world.in_gap(d):
			continue
		var b: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d) + b.y * 0.045
		for side in [-1.0, 1.0]:
			world._prop(
				"box",
				at + b.x * side * 1.1,
				Vector3(2.9, 0.035, 0.6),
				Color("ffd16b"),
				b * Basis(Vector3.UP, side * -0.43),
				true
			)


static func _harbour_fronts(world) -> void:
	# A connected coastal promenade: balconies, arcades, striped shop awnings.
	for i in range(10):
		var d: float = world.length * (0.115 + i * 0.023)
		var b: Basis = world.frame(d) * Basis(Vector3.UP, PI * 0.5)
		var at: Vector3 = world.position_at(d, -14.7)
		at.y = world._ground_height(at.x, at.z)
		var tint: Color = [Color("dc997e"), Color("d7bd80"), Color("76b4b5"), Color("a798c3")][
			i % 4
		]
		_piece(world, "box", at, Vector3(0, 4.5, 0), Vector3(7, 9, 5), tint, b)
		_piece(world, "roof", at, Vector3(0, 10, 0), Vector3(7.8, 2.2, 5.8), Color("52647c"), b)
		for y in [0.4, 3.3, 6.3, 9.0]:
			_piece(world, "box", at, Vector3(0, y, 0), Vector3(7.4, 0.22, 5.4), CREAM, b)
		for row in range(3):
			for column in range(3):
				_window(
					world,
					at + b * Vector3((column - 1) * 2.1, 1.9 + row * 2.9, 2.6),
					b,
					0.95,
					1.65,
					CREAM,
					Color("354c67")
				)
		for stripe in range(12):
			_piece(
				world,
				"box",
				at,
				Vector3((stripe - 5.5) * 0.55, 3.1, 3.3),
				Vector3(0.56, 0.18, 1.7),
				CREAM if stripe % 2 else tint.darkened(0.2),
				b
			)
		_piece(world, "box", at, Vector3(0, 6.0, 3.0), Vector3(6.3, 0.18, 1.2), CREAM, b)
		for railing in range(15):
			_piece(
				world,
				"box",
				at,
				Vector3((railing - 7) * 0.4, 6.5, 3.55),
				Vector3(0.05, 0.9, 0.05),
				Color("37495f"),
				b
			)


static func _desert_city(world) -> void:
	for i in range(12):
		var d: float = world.length * (0.06 + i * 0.013)
		var b: Basis = world.frame(d)
		var at: Vector3 = world.position_at(d, 33 + i % 3 * 14)
		var h: float = 18 + i % 5 * 8
		_piece(
			world, "glass_tower", at, Vector3(0, h * 0.5, 0), Vector3(7, h, 8), Color("6b879c"), b
		)
		for y in range(3, int(h), 4):
			_piece(world, "box", at, Vector3(0, y, 0), Vector3(7.2, 0.12, 8.2), Color("c3b3a2"), b)
		_piece(
			world,
			"box",
			at,
			Vector3(-3.6, h * 0.55, 4.13),
			Vector3(0.12, h * 0.85, 0.1),
			MINT,
			b,
			true
		)
		_piece(world, "cone", at, Vector3(0, h + 2, 0), Vector3(3, 5, 3), Color("c7c5bb"), b)


static func arch_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(20):
		var a: float = float(segment) * PI / 20.0
		var b: float = float(segment + 1) * PI / 20.0
		var points: Array[Vector3] = []
		for z in [-0.5, 0.5]:
			for r in [1.0, 1.18]:
				points.append(Vector3(cos(a) * r, sin(a) * r, z))
				points.append(Vector3(cos(b) * r, sin(b) * r, z))
		for face in [
			[0, 2, 1, 1, 2, 3],
			[4, 5, 6, 5, 7, 6],
			[0, 1, 4, 1, 5, 4],
			[2, 6, 3, 3, 6, 7],
			[0, 4, 2, 2, 4, 6],
			[1, 3, 5, 3, 7, 5]
		]:
			for index in face:
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()


static func icing_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for u in range(48):
		for v in range(10):
			var points: Array[Vector3] = []
			for du in [0, 1]:
				var angle: float = (u + du) * TAU / 48.0
				var drip: float = 0.25 + pow(0.5 + 0.5 * sin(angle * 9), 5) * 0.45
				for dv in [0, 1]:
					var around: float = -drip + (v + dv) * (PI + 2.0 * drip) / 10.0
					var radius: float = 0.385 + cos(around) * 0.119
					points.append(
						Vector3(
							cos(angle) * radius, sin(around) * 0.119 + 0.008, sin(angle) * radius
						)
					)
			for index in [0, 2, 1, 1, 2, 3]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()
