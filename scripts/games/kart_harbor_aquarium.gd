extends Node3D
## Sonnenhafen aquarium and cone slalom. The middle racing line stays clear.
const START: float = 0.53
const SPAN: float = 30.0
var fish: Array[Node3D] = []
var age: float = 0.0


static func build(world) -> void:
	if world.track_id != "sonnenhafen":
		return
	var animation := Node3D.new()
	animation.set_script(load("res://scripts/games/kart_harbor_aquarium.gd"))
	animation.name = "HarborAquarium"
	world.add_child(animation)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_surface := SurfaceTool.new()
	water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices: int = 12
	var sides: int = 12
	for section in range(slices):
		var a: float = world.length * START + SPAN * float(section) / slices
		var b: float = world.length * START + SPAN * float(section + 1) / slices
		for arc in range(sides):
			var angle_a: float = PI * float(arc) / sides
			var angle_b: float = PI * float(arc + 1) / sides
			var points: Array[Vector3] = [
				_arch_point(world, a, angle_a),
				_arch_point(world, b, angle_a),
				_arch_point(world, b, angle_b),
				_arch_point(world, a, angle_b),
			]
			for vertex in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(points[vertex])
			var outer: Array[Vector3] = [
				_arch_point(world, a, angle_a, 9.2),
				_arch_point(world, b, angle_a, 9.2),
				_arch_point(world, b, angle_b, 9.2),
				_arch_point(world, a, angle_b, 9.2),
			]
			var water_uv: Array[Vector2] = [
				Vector2(SPAN * section / slices, float(arc) / sides),
				Vector2(SPAN * (section + 1) / slices, float(arc) / sides),
				Vector2(SPAN * (section + 1) / slices, float(arc + 1) / sides),
				Vector2(SPAN * section / slices, float(arc + 1) / sides),
			]
			for vertex in [0, 1, 2, 0, 2, 3]:
				water_surface.set_uv(water_uv[vertex])
				water_surface.add_vertex(outer[vertex])
		if section % 2 == 0:
			_rib(world, a)
	_rib(world, world.length * START + SPAN)
	surface.generate_normals()
	var glass := MeshInstance3D.new()
	glass.name = "AquariumGlass"
	glass.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.64, 0.8, 0.16)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.16
	glass.material_override = material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animation.add_child(glass)
	water_surface.generate_normals()
	var water := MeshInstance3D.new()
	water.name = "AquariumWater"
	water.mesh = water_surface.commit()
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://assets/shaders/kart_aquarium.gdshader")
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animation.add_child(water)
	_portal(world, world.length * START)
	_portal(world, world.length * START + SPAN)
	var reef_count: int = 3 if world.low_detail else 4
	for index in range(reef_count):
		var d: float = world.length * START + 4.0 + float(index) * 22.0 / (reef_count - 1)
		_reef(world, d, -1.0 if index % 2 == 0 else 1.0, index)
	var shared_fish: ArrayMesh = _fish_mesh()
	var coat := StandardMaterial3D.new()
	coat.vertex_color_use_as_albedo = true
	coat.vertex_color_is_srgb = true
	coat.roughness = 0.48
	var leader_count: int = 4 if world.low_detail else 8
	for index in range(leader_count):
		var d: float = world.length * START + 4.0 + float(index) * 22.0 / (leader_count - 1)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var school := Node3D.new()
		school.name = "FishLeader%d" % index
		school.basis = world.frame(d)
		school.position = (
			world.position_at(d, side * 7.65) + school.basis.y * (2.3 + (index % 3) * 0.6)
		)
		school.set_meta("rest", school.position)
		animation.add_child(school)
		animation.fish.append(school)
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = shared_fish
		instances.instance_count = 3 if world.low_detail else 5
		var formation: Array[Vector3] = [
			Vector3.ZERO,
			Vector3(0.12, 0.34, 0.95),
			Vector3(-0.12, -0.30, 1.45),
			Vector3(0.08, 0.52, 2.15),
			Vector3(-0.12, -0.12, 2.55),
		]
		for member in range(instances.instance_count):
			var size: float = 1.0 if member == 0 else 0.68 + 0.06 * (member % 3)
			var heading := Basis(Vector3.UP, side * (0.07 if member % 2 == 0 else -0.07))
			instances.set_instance_transform(
				member, Transform3D(heading.scaled_local(Vector3.ONE * size), formation[member])
			)
			instances.set_instance_color(
				member, Color("ffbd65") if index % 2 == 0 else Color("9ce8ed")
			)
		var rendered := MultiMeshInstance3D.new()
		rendered.name = "FishSchool"
		rendered.multimesh = instances
		rendered.material_override = coat
		rendered.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		school.add_child(rendered)
		for bubble in range(3):
			world._prop(
				"ball",
				(
					world.position_at(d, side * 8.1)
					+ school.basis * Vector3(0, 1.0 + bubble * 0.43, 0.5)
				),
				Vector3.ONE * (0.06 + bubble * 0.018),
				Color("8ddce5"),
				Basis.IDENTITY,
				true
			)
	for index in range(6):
		var d: float = world.length * 0.30 + float(index) * 4.5
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var base: Vector3 = world.position_at(d, side * 3.9)
		var frame: Basis = world.frame(d)
		world._prop("box", base + frame.y * 0.08, Vector3(0.95, 0.16, 0.95), Color("173650"), frame)
		world._prop(
			"cone", base + frame.y * 0.64, Vector3(0.44, 1.12, 0.44), Color("ff8a39"), frame
		)
		world._prop(
			"cylinder", base + frame.y * 0.67, Vector3(0.21, 0.15, 0.21), Color("fff3db"), frame
		)
		world.action_obstacles.append(base)
	world.set_meta("action_tunnel_start", world.length * START)
	world.set_meta("action_tunnel_span", SPAN)


static func _fish_mesh() -> ArrayMesh:
	# One coloured surface includes the body, cream belly, fins, eyes and catchlights.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 12
	body.rings = 6
	_mesh_part(surface, body, Vector3(0.19, 0.31, 0.60), Vector3.ZERO, Color.WHITE)
	_mesh_part(surface, body, Vector3(0.17, 0.19, 0.49), Vector3(0, -0.13, -0.05), Color("fff6de"))
	_fish_tail(surface)
	var fin := PrismMesh.new()
	fin.size = Vector3.ONE
	_mesh_part(surface, fin, Vector3(0.09, 0.22, 0.34), Vector3(0, 0.30, 0.05), Color("ffe5b1"))
	var eye := SphereMesh.new()
	eye.radius = 1.0
	eye.height = 2.0
	eye.radial_segments = 8
	eye.rings = 3
	for side in [-1.0, 1.0]:
		_mesh_part(
			surface, eye, Vector3.ONE * 0.052, Vector3(side * 0.177, 0.09, -0.30), Color("112331")
		)
		_mesh_part(
			surface, eye, Vector3.ONE * 0.017, Vector3(side * 0.218, 0.11, -0.315), Color.WHITE
		)
	surface.index()
	return surface.commit()


static func _fish_tail(surface: SurfaceTool) -> void:
	# A shallow fork reads as a fin from the driver's side view, with real thickness.
	var outline: Array[Vector2] = [
		Vector2(0, 0.45), Vector2(0.29, 0.98), Vector2(0, 0.86), Vector2(-0.29, 0.98)
	]
	var vertices: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for point in outline:
			vertices.append(Vector3(side * 0.045, point.x, point.y))
	var faces: Array = [[0, 1, 2], [0, 2, 3], [4, 6, 5], [4, 7, 6]]
	for index in range(4):
		var next: int = (index + 1) % 4
		faces.append([index, index + 4, next + 4])
		faces.append([index, next + 4, next])
	for face in faces:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		for point in [a, b, c]:
			surface.set_color(Color("e8a26b"))
			surface.set_normal(normal)
			surface.add_vertex(point)


static func _mesh_part(
	surface: SurfaceTool,
	mesh: Mesh,
	size: Vector3,
	at: Vector3,
	color: Color,
	rotation: Basis = Basis.IDENTITY
) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var transform := Transform3D(rotation.scaled_local(size), at)
	var normal_frame: Basis = transform.basis.inverse().transposed()
	for index in indices:
		surface.set_color(color)
		surface.set_normal((normal_frame * normals[index]).normalized())
		surface.add_vertex(transform * vertices[index])


static func _reef(world, distance: float, side: float, variant: int) -> void:
	# Opaque props share the world's existing spatial batches and remain behind the glass.
	var frame: Basis = world.frame(distance)
	var base: Vector3 = world.position_at(distance)
	for rock in [
		[Vector3(side * 8.0, 0.26, 0), Vector3(0.55, 0.55, 1.7)],
		[Vector3(side * 8.15, 0.53, 0.75), Vector3(0.44, 0.68, 0.70)],
		[Vector3(side * 7.7, 0.25, -1.0), Vector3(0.32, 0.40, 0.58)],
	]:
		world._prop("rock", base + frame * rock[0], rock[1], Color("365c68"), frame)
	for stem in range(3):
		var z: float = -1.10 + stem * 0.95
		for leaf in range(3):
			var at := Vector3(
				side * (8.12 + stem * 0.025), 0.85 + leaf * 0.66, z + sin(leaf + stem) * 0.16
			)
			var sway: Basis = frame * Basis(Vector3.RIGHT, sin(leaf * 1.4 + variant) * 0.25)
			world._prop(
				"ball",
				base + frame * at,
				Vector3(0.10, 0.51, 0.23),
				Color("55bca0") if leaf % 2 == 0 else Color("268e91"),
				sway
			)
	var coral: Color = Color("ff8a79") if variant % 2 == 0 else Color("bb9af4")
	var root_at := Vector3(side * 7.65, 0.45, -0.1)
	var crown := Vector3(side * 7.65, 1.20, -0.1)
	world._beam(base + frame * root_at, base + frame * crown, 0.12, coral)
	for branch in range(3):
		var tip := Vector3(
			side * (7.68 + 0.12 * (branch % 2)), 1.3 + 0.25 * (branch % 2), -0.7 + branch * 0.6
		)
		world._beam(base + frame * crown, base + frame * tip, 0.10, coral)
		world._prop("ball", base + frame * tip, Vector3(0.13, 0.22, 0.13), coral, frame)
	world._prop(
		"ball",
		base + frame * Vector3(side * 7.55, 0.63, 0.88),
		Vector3(0.20, 0.35, 0.26),
		Color("f4c971"),
		frame
	)


static func _portal(world, distance: float) -> void:
	for index in range(12):
		var a: Vector3 = _arch_point(world, distance, PI * index / 12.0, 9.2)
		var b: Vector3 = _arch_point(world, distance, PI * (index + 1) / 12.0, 9.2)
		world._beam(a, b, 0.30, Color("163c54"))
	for index in range(0, 13, 3):
		var angle: float = PI * index / 12.0
		world._beam(
			_arch_point(world, distance, angle),
			_arch_point(world, distance, angle, 9.2),
			0.20,
			Color("eadfbe")
		)


static func _arch_point(world, distance: float, angle: float, radius: float = 7.1) -> Vector3:
	var frame: Basis = world.frame(distance)
	return (
		world.position_at(distance)
		+ frame * Vector3(cos(angle) * radius, 0.2 + sin(angle) * radius, 0)
	)


static func _rib(world, distance: float) -> void:
	for index in range(12):
		var a: Vector3 = _arch_point(world, distance, PI * index / 12.0)
		var b: Vector3 = _arch_point(world, distance, PI * (index + 1) / 12.0)
		world._beam(a, b, 0.14, Color("13516b"))
		world._prop("ball", a, Vector3.ONE * 0.105, Color("71e9ee"), Basis.IDENTITY, true)


func _process(delta: float) -> void:
	age += delta
	for index in range(fish.size()):
		var rest: Vector3 = fish[index].get_meta("rest")
		fish[index].position = (
			rest
			+ (
				fish[index].basis
				* Vector3(0, sin(age * 0.8 + index) * 0.18, sin(age * 0.45 + index) * 0.6)
			)
		)
