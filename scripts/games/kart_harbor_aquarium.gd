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
			for vertex in [0, 1, 2, 0, 2, 3]:
				water_surface.add_vertex(outer[vertex])
		if section % 2 == 0:
			_rib(world, a)
	_rib(world, world.length * START + SPAN)
	surface.generate_normals()
	var glass := MeshInstance3D.new()
	glass.name = "AquariumGlass"
	glass.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.64, 0.8, 0.24)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.16
	glass.material_override = material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animation.add_child(glass)
	water_surface.generate_normals()
	var water := MeshInstance3D.new()
	water.mesh = water_surface.commit()
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://assets/shaders/kart_aquarium.gdshader")
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animation.add_child(water)
	for index in range(4 if world.low_detail else 8):
		var d: float = world.length * START + 3.0 + float(index) * 3.3
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var school := Node3D.new()
		school.position = world.position_at(d, side * 7.7) + Vector3.UP * (2.4 + index % 3)
		school.basis = world.frame(d)
		school.set_meta("rest", school.position)
		animation.add_child(school)
		animation.fish.append(school)
		var mesh := SphereMesh.new()
		mesh.radius = 0.4
		mesh.height = 0.8
		mesh.radial_segments = 12
		mesh.rings = 6
		var body := MeshInstance3D.new()
		body.mesh = mesh
		body.scale = Vector3(0.45, 0.75, 1.6)
		var coat := StandardMaterial3D.new()
		coat.albedo_color = Color("ffbe56") if index % 2 == 0 else Color("8be8ed")
		body.material_override = coat
		school.add_child(body)
		var tail := MeshInstance3D.new()
		var fin := PrismMesh.new()
		fin.size = Vector3(0.12, 0.65, 0.45)
		tail.mesh = fin
		tail.position.z = 0.65
		tail.rotation.x = PI * 0.5
		tail.material_override = coat
		school.add_child(tail)
		for sign_x in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			eye.mesh = mesh
			eye.scale = Vector3.ONE * 0.10
			eye.position = Vector3(sign_x * 0.17, 0.09, -0.30)
			var black := StandardMaterial3D.new()
			black.albedo_color = Color("091b28")
			eye.material_override = black
			school.add_child(eye)
		for bubble in range(3):
			world._prop(
				"ball",
				school.position + Vector3(0, 0.8 + bubble * 0.42, 0.5),
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
			rest + Vector3(0, sin(age * 0.8 + index) * 0.18, sin(age * 0.45 + index) * 0.6)
		)
