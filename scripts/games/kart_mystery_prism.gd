class_name LumoMysteryPrism
extends RefCounted
## Original faceted Lumo pickup. Shared geometry uses only two opaque surfaces.

const POINTS: Array[Vector3] = [
	Vector3(0, 0.68, 0),
	Vector3(0, -0.68, 0),
	Vector3(0.54, 0, 0),
	Vector3(0, 0, 0.54),
	Vector3(-0.54, 0, 0),
	Vector3(0, 0, -0.54),
]
static var core_mesh: ArrayMesh
static var edge_mesh: ArrayMesh
static var violet: StandardMaterial3D
static var gold: StandardMaterial3D


static func build(parent: Node3D) -> void:
	if core_mesh == null:
		_make_shared_geometry()
	var core := MeshInstance3D.new()
	core.name = "MysteryPrismCore"
	core.mesh = core_mesh
	core.material_override = violet
	parent.add_child(core)
	var edges := MeshInstance3D.new()
	edges.name = "MysteryPrismEdges"
	edges.mesh = edge_mesh
	edges.material_override = gold
	parent.add_child(edges)
	parent.set_meta("mystery_visual", "lumo_prism")


static func _finish(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.32
	material.roughness = 0.28
	material.clearcoat_enabled = true
	material.clearcoat = 0.7
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	return material


static func _make_shared_geometry() -> void:
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pairs: Array[Vector2i] = []
	for ring in range(4):
		var a: int = 2 + ring
		var b: int = 2 + (ring + 1) % 4
		for index in [0, b, a, 1, a, b]:
			core.add_vertex(POINTS[index])
		pairs.append_array([Vector2i(0, a), Vector2i(1, a), Vector2i(a, b)])
	core.generate_normals()
	core_mesh = core.commit()
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pair in pairs:
		_edge(edges, POINTS[pair.x], POINTS[pair.y])
	edges.generate_normals()
	edge_mesh = edges.commit()
	violet = _finish(Color("6442b9"), 0.12)
	gold = _finish(Color("ffcb58"), 0.38)


static func _edge(tool: SurfaceTool, start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var reference := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var u := direction.cross(reference).normalized() * 0.022
	var v := direction.cross(u).normalized() * 0.022
	for segment in range(8):
		var angle_a: float = float(segment) * TAU / 8.0
		var angle_b: float = float(segment + 1) * TAU / 8.0
		var offset_a := u * cos(angle_a) + v * sin(angle_a)
		var offset_b := u * cos(angle_b) + v * sin(angle_b)
		for point in [
			start + offset_a,
			end + offset_b,
			end + offset_a,
			start + offset_a,
			start + offset_b,
			end + offset_b,
		]:
			tool.add_vertex(point)
