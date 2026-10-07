extends Node3D
## Original circular crystal arena; its flat surface supports completely free driving.
const RADIUS: float = 39.0
var pickups: Array[Vector3] = []
var obstacles: Array[Vector3] = []

func build(lightweight: bool) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("07182f")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8badde")
	settings.ambient_light_energy = 0.85
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -30, 0)
	key.light_color = Color("d5eaff")
	key.light_energy = 1.8
	key.shadow_enabled = not lightweight
	add_child(key)
	_cylinder(Vector3(0, -1.2, 0), RADIUS + 1.8, 2.2, Color("102f51"))
	_cylinder(Vector3(0, -0.07, 0), RADIUS, 0.12, Color("254969"))
	_ring(RADIUS, Color("73e8f9"), 0.13)
	_ring(25, Color("4a7899"), 0.03)
	_ring(13, Color("78abca"), 0.03)
	for i in range(12):
		var angle: float = TAU * i / 12
		var p := Vector3(cos(angle), 0, sin(angle)) * (RADIUS + 1.0)
		_cylinder(p + Vector3.UP * 1.0, 0.3, 2.0, Color("78dfff"))
		var tower := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(5, 8 + (i % 3) * 4, 5)
		tower.mesh = mesh
		tower.position = p * 1.9 + Vector3.DOWN * 7
		tower.material_override = _material(Color("123558"))
		add_child(tower)
	for i in range(4):
		var p := Vector3(cos(TAU * i / 4), 0, sin(TAU * i / 4)) * 16
		obstacles.append(p)
		_cylinder(p + Vector3.UP * 0.7, 2.2, 1.4, Color("1e7891"))
		_cylinder(p + Vector3.UP * 1.45, 2.25, 0.1, Color("9eecfa"))
	for ring in [8.0, 22.0, 32.0]:
		for i in range(10):
			var angle: float = TAU * i / 10 + ring * 0.018
			pickups.append(Vector3(cos(angle), 0.9, sin(angle)) * Vector3(ring, 1, ring))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.38
	material.metallic = 0.25
	return material

func _cylinder(position: Vector3, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64 if radius > 10 else 24
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	add_child(node)

func _ring(radius: float, color: Color, height: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.09
	mesh.outer_radius = radius + 0.09
	mesh.rings = 80
	mesh.ring_segments = 8
	node.mesh = mesh
	node.position.y = height
	node.material_override = _material(color)
	add_child(node)
