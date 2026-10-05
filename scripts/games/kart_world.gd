class_name LumoRaceWorld
extends Node3D
## Sonnenhafen: an original closed, banked course. Decoration is GPU instanced.

const WIDTH: float = 10.8
const DECORATION_CELL: float = 48.0
const POINTS: Array[Vector3] = [
	Vector3(0, 1.6, 44),
	Vector3(27, 1.8, 43),
	Vector3(48, 3, 24),
	Vector3(38, 7, 3),
	Vector3(53, 9, -21),
	Vector3(24, 7, -48),
	Vector3(-12, 2, -42),
	Vector3(-39, 1.8, -54),
	Vector3(-58, 2.4, -20),
	Vector3(-28, 5, 0),
	Vector3(-54, 7, 21),
	Vector3(-28, 4, 45),
]

var curve: Curve3D
var length: float = 0.0
var road: MeshInstance3D
var low_detail: bool = false
var groups: Dictionary = {}
var meshes: Dictionary = {}
var materials: Dictionary = {}
var decoration_count: int = 0


func build(lightweight: bool) -> void:
	low_detail = lightweight
	_make_curve()
	_lighting()
	_terrain()
	_road()
	_settlement()
	_flush_instances()


func _make_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.25
	for i in range(POINTS.size() + 1):
		var index: int = i % POINTS.size()
		var previous: Vector3 = POINTS[posmod(index - 1, POINTS.size())]
		var following: Vector3 = POINTS[(index + 1) % POINTS.size()]
		var tangent: Vector3 = (following - previous) * 0.19
		curve.add_point(POINTS[index], -tangent, tangent)
	length = curve.get_baked_length()


func forward(distance: float) -> Vector3:
	var p: Vector3 = curve.sample_baked(fposmod(distance, length), true)
	var q: Vector3 = curve.sample_baked(fposmod(distance + 0.4, length), true)
	return (q - p).normalized()


func frame(distance: float) -> Basis:
	var ahead: Vector3 = forward(distance)
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(ahead).normalized()
	var bend: float = right.dot(forward(distance + 4.0) - ahead)
	var bank: float = clampf(-bend * 0.48, -0.10, 0.10)
	return Basis(right, up, -ahead).rotated(ahead, bank)


func position_at(distance: float, lateral: float = 0.0) -> Vector3:
	return curve.sample_baked(fposmod(distance, length), true) + frame(distance).x * lateral


func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	materials[key] = material
	return material


func _shape(kind: String) -> Mesh:
	if meshes.has(kind):
		return meshes[kind]
	var mesh: Mesh
	match kind:
		"ball":
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 12 if low_detail else 20
			sphere.rings = 6 if low_detail else 10
			mesh = sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.0
			cylinder.bottom_radius = 1.0
			cylinder.height = 1.0
			cylinder.radial_segments = 16
			mesh = cylinder
		"roof":
			var roof := PrismMesh.new()
			roof.size = Vector3.ONE
			mesh = roof
		_:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
	meshes[kind] = mesh
	return mesh


func _prop(
	kind: String, at: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY
) -> void:
	# Per-instance colours keep the palette while sharing one material. Smaller
	# spatial batches let the renderer discard decorations outside the camera.
	var backdrop: bool = size.length() > 32.0 or at.y > 25.0
	var cell := Vector2i(floori(at.x / DECORATION_CELL), floori(at.z / DECORATION_CELL))
	var key: String = kind + ("_background" if backdrop else "_" + str(cell))
	if not groups.has(key):
		groups[key] = {"kind": kind, "backdrop": backdrop, "transforms": [], "colors": []}
	groups[key].transforms.append(Transform3D(basis.scaled_local(size), at))
	groups[key].colors.append(color)
	decoration_count += 1


func _flush_instances() -> void:
	for key in groups:
		var group: Dictionary = groups[key]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = _shape(group.kind)
		instances.instance_count = group.transforms.size()
		for i in range(instances.instance_count):
			instances.set_instance_transform(i, group.transforms[i])
			instances.set_instance_color(i, group.colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Decor_" + key
		node.multimesh = instances
		var material: StandardMaterial3D = _material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		node.material_override = material
		if low_detail or group.backdrop:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	groups.clear()


func _lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("159dcc")
	atmosphere.sky_horizon_color = Color("c1eff1")
	atmosphere.ground_bottom_color = Color("678d83")
	atmosphere.ground_horizon_color = Color("c1eff1")
	atmosphere.sky_curve = 0.18
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4eaff")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 0.85
	environment.fog_enabled = not low_detail
	environment.fog_light_color = Color("b0e0e7")
	environment.fog_density = 0.002
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-49, -35, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 0.75
	sun.shadow_enabled = not low_detail
	sun.directional_shadow_max_distance = 85
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _terrain() -> void:
	_prop("cylinder", Vector3(0, -2.7, 0), Vector3(80, 5.4, 69), Color("dfa365"))
	_prop("cylinder", Vector3(0, -0.25, 0), Vector3(79.6, 0.5, 68.7), Color("7ac871"))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	water.mesh = plane
	water.position.y = -3.0
	if low_detail:
		water.material_override = _material(Color("259ec6"))
	else:
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/kart_water.gdshader")
		water.material_override = material
	add_child(water)
	var rng := RandomNumberGenerator.new()
	rng.seed = 109021
	for i in range(25):
		var angle: float = float(i) * TAU / 25
		var at := Vector3(cos(angle) * 160, 0, sin(angle) * 145)
		var height: float = rng.randf_range(18, 40)
		_prop(
			"ball", at, Vector3(21, height, 20), Color("74a897") if i % 2 == 0 else Color("85b5a3")
		)
	for i in range(100 if low_detail else 175):
		var at := Vector3(rng.randf_range(-73, 73), 0, rng.randf_range(-62, 62))
		if Vector2(at.x / 74, at.z / 63).length() > 1.0 or _near_road(at, 9.5):
			continue
		_tree(at, rng.randf_range(0.8, 1.7), rng)
	for i in range(14):
		var at := Vector3(
			rng.randf_range(-120, 120), rng.randf_range(31, 47), rng.randf_range(-120, 120)
		)
		for cloud in range(4):
			_prop(
				"ball",
				at + Vector3(cloud * 3, sin(float(cloud)) * 1.2, 0),
				Vector3(4, 2.5, 3),
				Color("f4fbf4")
			)
	# The harbour, with independently designed boats and a striped lighthouse.
	for i in range(7):
		var at := Vector3(67 + i * 1.8, -1.9, 27 - i * 8)
		_boat(at, Color("f39162") if i % 2 == 0 else Color("577ce0"))
	_lighthouse(Vector3(69, 0, -33))
	_windmill(Vector3(-14, 0, 16))


func _near_road(at: Vector3, radius: float) -> bool:
	for i in range(100):
		var p: Vector3 = position_at(float(i) * length / 100)
		if Vector2(p.x - at.x, p.z - at.z).length() < radius:
			return true
	return false


func _tree(at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	_prop(
		"cylinder", at + Vector3.UP * size * 1.7, Vector3(0.22, 3.4, 0.22) * size, Color("975b43")
	)
	var color := Color("248d70") if rng.randf() > 0.5 else Color("4bac69")
	for i in range(3):
		_prop(
			"ball",
			at + Vector3((i - 1) * 0.7, 3.2 + sin(float(i)) * 0.8, 0) * size,
			Vector3(1.35, 1.8, 1.4) * size,
			color
		)
	if not low_detail:
		_prop(
			"ball",
			at + Vector3(0, 4.6, 0) * size,
			Vector3(1, 1.1, 1.1) * size,
			color.lightened(0.13)
		)


func _road() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 420
	var step: float = length / count
	for i in range(count):
		var d: float = i * step
		var next: float = (i + 1) * step
		var p: Vector3 = position_at(d)
		var wood: bool = p.y > 5.4
		var tint := Color("bf8c56") if wood else Color("526e7c")
		if wood and i % 3 == 0:
			tint = tint.lightened(0.055)
		var vertices: Array[Vector3] = [
			position_at(d, -WIDTH / 2),
			position_at(d, WIDTH / 2),
			position_at(next, -WIDTH / 2),
			position_at(next, WIDTH / 2)
		]
		for index in [0, 2, 1, 1, 2, 3]:
			surface.set_color(tint)
			surface.set_uv(Vector2(vertices[index].x, vertices[index].z) * 0.7)
			surface.add_vertex(vertices[index])
		var basis: Basis = frame(d)
		for side in [-1.0, 1.0]:
			_prop(
				"box",
				position_at(d, side * (WIDTH / 2 + 0.1)) - basis.y * 0.03,
				Vector3(0.38, 0.19, step + 0.08),
				Color("fff5de") if i % 6 < 3 else Color("f48b63"),
				basis
			)
			if i % 3 == 0:
				_prop(
					"box",
					position_at(d, side * (WIDTH / 2 + 0.5)) + Vector3.UP * 0.72,
					Vector3(0.16, 1.5, 0.16),
					Color("5f7979"),
					basis
				)
			_prop(
				"box",
				position_at(d, side * (WIDTH / 2 + 0.5)) + Vector3.UP * 1.36,
				Vector3(0.16, 0.15, step + 0.08),
				Color("e2bd74"),
				basis
			)
		if i % 8 < 4 and not wood:
			_prop("box", p + basis.y * 0.025, Vector3(0.10, 0.025, step), Color("ebf6e5"), basis)
		if wood:
			_prop("box", p + basis.y * 0.015, Vector3(WIDTH, 0.025, 0.034), Color("8d6244"), basis)
		if i % 12 == 0 and p.y > 2:
			_prop(
				"box", p - Vector3.UP * 0.35, Vector3(WIDTH + 0.3, 0.5, 0.4), Color("80543e"), basis
			)
			for side in [-1.0, 1.0]:
				_prop(
					"box",
					position_at(d, side * 4.1) * Vector3(1, 0, 1) + Vector3.UP * (p.y - 0.2) * 0.5,
					Vector3(0.45, p.y - 0.2, 0.45),
					Color("b18a5a")
				)
	surface.generate_normals()
	road = MeshInstance3D.new()
	road.name = "BankedRoad"
	road.mesh = surface.commit()
	var material := _material(Color.WHITE).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	var noise := FastNoiseLite.new()
	noise.seed = 9302
	noise.frequency = 0.7
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.noise = noise
	texture.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color("c1c1c1"))
	ramp.set_color(1, Color("ffffff"))
	texture.color_ramp = ramp
	material.albedo_texture = texture
	road.material_override = material
	add_child(road)
	# Start markings and finish gantry.
	for row in range(2):
		for column in range(16):
			_prop(
				"box",
				position_at(row * 0.7, (column - 7.5) * 0.65) + frame(0).y * 0.03,
				Vector3(0.65, 0.035, 0.7),
				Color("f9f4df") if (row + column) % 2 == 0 else Color("263c56"),
				frame(0)
			)
	_arch(0, "LUMO · SONNENHAFEN", Color("7b68c7"))
	_arch(length * 0.47, "WOLKENBRÜCKE", Color("309caa"))
	# Paired coloured flags are the visible ordered lap checkpoints.
	var checkpoint_colors: Array[Color] = [
		Color("77d8c5"), Color("f8c968"), Color("b8a0e5"), Color("f69e88")
	]
	for gate in range(1, 8):
		var d: float = length * float(gate) / 8.0
		var basis: Basis = frame(d)
		for side in [-1.0, 1.0]:
			var at: Vector3 = position_at(d, side * 6.1)
			_prop(
				"cylinder", at + basis.y * 2.1, Vector3(0.075, 4.2, 0.075), Color("eef5df"), basis
			)
			_prop(
				"box",
				at + basis.y * 3.5 + basis.x * side * 0.65,
				Vector3(1.3, 0.8, 0.055),
				checkpoint_colors[gate % checkpoint_colors.size()],
				basis
			)
			_prop(
				"box",
				at + basis.y * 3.5 + basis.x * side * 0.65 + basis.z * 0.045,
				Vector3(0.25, 0.25, 0.035),
				Color("fff2ca"),
				basis.rotated(basis.z, PI / 4.0)
			)


func _settlement() -> void:
	var palette: Array[Color] = [Color("f4cfa0"), Color("9ad7ce"), Color("edb2a1"), Color("cfbfeb")]
	for i in range(25):
		var d: float = float(i) * length / 25.0 + 7
		var p: Vector3 = position_at(d, 11.5 if i % 2 == 0 else -12.5)
		var basis: Basis = Basis(Vector3.UP, atan2(-forward(d).x, -forward(d).z))
		_house(p, basis, palette[i % palette.size()], i)
	for i in range(36):
		var d: float = float(i) * length / 36
		var p: Vector3 = position_at(d, WIDTH / 2 + 1.3)
		_prop("cylinder", p + Vector3.UP * 2.4, Vector3(0.07, 4.8, 0.07), Color("50616d"))
		_prop("ball", p + Vector3.UP * 4.7, Vector3(0.28, 0.34, 0.28), Color("fff0b0"))
		if i % 3 == 0:
			var basis: Basis = frame(d)
			_prop(
				"box",
				p + Vector3.UP * 3.35 - basis.x * 0.5,
				Vector3(0.9, 1.25, 0.04),
				Color("a786db") if i % 2 == 0 else Color("f3ae61"),
				basis
			)
	# Navigation arrows use Lumo colours and geometry, rather than branded signs.
	for fraction in [0.10, 0.22, 0.36, 0.53, 0.67, 0.81, 0.93]:
		var d: float = fraction * length
		var p: Vector3 = position_at(d, 6.8)
		var basis: Basis = frame(d)
		var turn: float = 1.0 if basis.x.dot(forward(d + 12)) >= 0 else -1.0
		_prop("box", p + Vector3.UP * 1.8, Vector3(2.3, 1.5, 0.12), Color("26485d"), basis)
		for offset in [-0.55, 0.45]:
			_prop(
				"box",
				p + Vector3.UP * 2.04 + basis.x * offset + basis.z * 0.09,
				Vector3(0.7, 0.18, 0.05),
				Color("ffe39a"),
				basis.rotated(basis.z, -0.5 * turn)
			)
			_prop(
				"box",
				p + Vector3.UP * 1.72 + basis.x * offset + basis.z * 0.09,
				Vector3(0.7, 0.18, 0.05),
				Color("ffe39a"),
				basis.rotated(basis.z, 0.5 * turn)
			)


func _house(at: Vector3, basis: Basis, color: Color, index: int) -> void:
	var height: float = 4.3 + float(index % 3) * 1.2
	_prop("box", at + Vector3.UP * (height * 0.5 - 0.35), Vector3(5, height, 4.1), color, basis)
	_prop(
		"box",
		Vector3(at.x, at.y * 0.5 - 0.5, at.z),
		Vector3(5.25, maxf(0.5, at.y - 0.5), 4.25),
		Color("c09e79"),
		basis
	)
	_prop(
		"roof",
		at + Vector3.UP * (height + 0.45),
		Vector3(5.9, 2.2, 5.0),
		Color("e67b5e") if index % 2 == 0 else Color("577e9e"),
		basis
	)
	for side in [-1.0, 1.0]:
		for floor_index in range(2):
			var p: Vector3 = at + basis * Vector3(side * 1.3, 1.4 + floor_index * 1.9, 2.09)
			_prop("box", p, Vector3(1.1, 1.25, 0.12), Color("f8edcb"), basis)
			_prop("box", p + basis.z * 0.075, Vector3(0.82, 0.98, 0.045), Color("468da8"), basis)
			_prop("box", p + basis.z * 0.11, Vector3(0.06, 1.05, 0.055), Color("f8edcb"), basis)
	_prop(
		"box", at + basis * Vector3(0, 0.8, 2.12), Vector3(0.9, 1.8, 0.15), Color("656086"), basis
	)
	_prop(
		"box",
		at + basis * Vector3(0, 2.7, 2.6),
		Vector3(5.1, 0.18, 1.3),
		Color("f6d788"),
		basis.rotated(basis.x, -0.12)
	)
	_prop(
		"box",
		at + basis * Vector3(1.3, height + 1.4, -0.5),
		Vector3(0.6, 2.1, 0.6),
		Color("f5dbc0"),
		basis
	)
	if index % 4 == 0:
		_sign(
			at + basis * Vector3(0, 3.5, 2.3),
			basis,
			["LUMO WERFT", "SONNENCAFÉ", "WOLKENPOST", "HAFENMARKT"][index / 4 % 4],
			0.035
		)


func _sign(at: Vector3, basis: Basis, text: String, pixel_size: float = 0.028) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = pixel_size
	label.outline_size = 4
	label.modulate = Color("fff4cd")
	label.position = at
	label.basis = basis
	add_child(label)


func _arch(distance: float, text: String, color: Color) -> void:
	var basis: Basis = frame(distance)
	var at: Vector3 = position_at(distance)
	for side in [-1.0, 1.0]:
		_prop(
			"box", at + basis.x * side * 6.2 + Vector3.UP * 3.5, Vector3(0.8, 7, 0.8), color, basis
		)
	_prop("box", at + Vector3.UP * 6.4, Vector3(13.3, 1.5, 0.8), color, basis)
	# Visible on approach, from either side of the gantry.
	_sign(at + Vector3.UP * 6.4 + basis.z * 0.43, basis, text, 0.027)
	_sign(at + Vector3.UP * 6.4 - basis.z * 0.43, basis.rotated(Vector3.UP, PI), text, 0.027)


func _boat(at: Vector3, color: Color) -> void:
	_prop("ball", at, Vector3(1.8, 0.55, 4), color)
	_prop("box", at + Vector3.UP * 0.5, Vector3(2.2, 0.3, 4.7), Color("f5dfb5"))
	_prop("box", at + Vector3(0, 1.25, 0.4), Vector3(1.8, 1.5, 2.0), Color("f5edcd"))
	_prop("box", at + Vector3(0, 1.65, -0.65), Vector3(1.5, 0.7, 0.06), Color("4387b7"))
	_prop("box", at + Vector3(0, 2.1, 0.4), Vector3(2.3, 0.2, 2.6), color)
	_prop("cylinder", at + Vector3(0, 3.2, 0.4), Vector3(0.06, 2.3, 0.06), Color("e9cba1"))


func _lighthouse(at: Vector3) -> void:
	for i in range(8):
		_prop(
			"cylinder",
			at + Vector3.UP * (i * 1.5 + 0.75),
			Vector3(2.1 - i * 0.08, 1.5, 2.1 - i * 0.08),
			Color("fbefd4") if i % 2 == 0 else Color("ec8870")
		)
	_prop("cylinder", at + Vector3.UP * 12.2, Vector3(2.4, 0.45, 2.4), Color("30556b"))
	_prop("cylinder", at + Vector3.UP * 13.1, Vector3(1.45, 1.6, 1.45), Color("fbe5a5"))
	_prop("roof", at + Vector3.UP * 14.5, Vector3(4, 2, 4), Color("30556b"))


func _windmill(at: Vector3) -> void:
	_prop("cylinder", at + Vector3.UP * 4.5, Vector3(2, 9, 2), Color("eee4bf"))
	_prop("roof", at + Vector3.UP * 9.4, Vector3(5, 2.6, 5), Color("ed8b6a"))
	var hub: Vector3 = at + Vector3(0, 8.0, 2.1)
	_prop("ball", hub, Vector3.ONE * 0.45, Color("6e679a"))
	for i in range(4):
		var angle: float = PI / 4 + i * PI / 2
		var basis := Basis(Vector3.FORWARD, angle)
		_prop("box", hub + basis.y * 2.4, Vector3(0.85, 5, 0.2), Color("f7ddb7"), basis)
