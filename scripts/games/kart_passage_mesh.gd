extends RefCounted
## Gemeinsame Mesh- und Materialhelfer der LUMO-Passagen (Bänder entlang der Fahrbahn).


static func material(
	color: Color, glow: float = 0.0, rough: float = 0.6, metal: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


static func strip(
	world,
	a: float,
	b: float,
	left: float,
	right: float,
	top: float,
	bottom: float,
	step: float = 1.0
) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = maxi(1, ceili((b - a) / step))
	for i in range(count):
		var d0: float = lerpf(a, b, float(i) / count)
		var d1: float = lerpf(a, b, float(i + 1) / count)
		var y0: Vector3 = world.frame(d0).y
		var y1: Vector3 = world.frame(d1).y
		var l0: Vector3 = world.position_at(d0, left)
		var r0: Vector3 = world.position_at(d0, right)
		var l1: Vector3 = world.position_at(d1, left)
		var r1: Vector3 = world.position_at(d1, right)
		quad(tool, l0 + y0 * top, r0 + y0 * top, r1 + y1 * top, l1 + y1 * top, y0)
		if bottom < top:
			quad(tool, r0 + y0 * bottom, l0 + y0 * bottom, l1 + y1 * bottom, r1 + y1 * bottom, -y0)
			var side: Vector3 = world.frame(d0).x
			quad(tool, r0 + y0 * top, r0 + y0 * bottom, r1 + y1 * bottom, r1 + y1 * top, side)
			quad(tool, l0 + y0 * bottom, l0 + y0 * top, l1 + y1 * top, l1 + y1 * bottom, -side)
	if bottom < top:
		for end in [a, b]:
			var basis: Basis = world.frame(end)
			var facing: Vector3 = basis.z if end == a else -basis.z
			var lt: Vector3 = world.position_at(end, left) + basis.y * top
			var rt: Vector3 = world.position_at(end, right) + basis.y * top
			var lb: Vector3 = world.position_at(end, left) + basis.y * bottom
			var rb: Vector3 = world.position_at(end, right) + basis.y * bottom
			if end == a:
				quad(tool, lt, rt, rb, lb, facing)
			else:
				quad(tool, rt, lt, lb, rb, facing)
	return tool.commit()


static func quad(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3
) -> void:
	for corner in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		tool.add_vertex(corner)


static func mesh_node(
	parent: Node3D, mesh_name: String, mesh: Mesh, material: Material
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func arrow_mesh(world, line: float, lanes: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var d: float = line - 6.0 - float(i) * 6.0
		var frame: Basis = world.frame(d)
		for lane in lanes:
			var tip: Vector3 = world.position_at(d + 1.1, float(lane)) + frame.y * 0.03
			var l: Vector3 = world.position_at(d - 0.6, float(lane) - 0.9) + frame.y * 0.03
			var r: Vector3 = world.position_at(d - 0.6, float(lane) + 0.9) + frame.y * 0.03
			for corner in [l, tip, r]:
				tool.set_normal(frame.y)
				tool.add_vertex(corner)
	return tool.commit()
