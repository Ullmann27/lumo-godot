extends RefCounted
## Original Lumo pigmentation and iris geometry. Opaque mobile PBR, no alpha shells.


static func coat(source: Mesh, orange: Color, cream: Color, region: String) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for point in positions:
		var color: Color = orange
		if region == "tail":
			# One continuous surface carries both colours: overlapping orange and
			# white shells used to expose orange dots through the white tip.
			var angle: float = atan2(point.x, point.y - 0.25)
			var boundary: float = 0.605 + sin(angle * 5.0) * 0.023
			color = orange.lerp(cream, smoothstep(boundary, boundary + 0.052, point.z))
		elif region == "ear":
			color = orange.lerp(Color("67351f"), smoothstep(0.23, 0.40, point.y) * 0.83)
		elif region == "head":
			# Warm centre, darker crown and temples keep the rounded head readable.
			var temple: float = smoothstep(0.22, 0.43, absf(point.x))
			var crown: float = smoothstep(0.12, 0.38, point.y)
			color = orange.lerp(Color("ca5725"), temple * 0.15 + crown * 0.12)
		colors.append(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if source.has_meta("far_geometry"):
		result.set_meta("far_geometry", coat(source.get_meta("far_geometry"), orange, cream, region))
	return result


static func iris(size: Vector3) -> ArrayMesh:
	# A curved radial iris with a dark limbal ring and warm amber fibres.
	# Vertex colours survive the existing batcher and need no texture/draw pass.
	const SECTIONS: int = 64
	const RINGS: int = 10
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(RINGS + 1):
		var radius: float = float(row) / RINGS
		for segment in range(SECTIONS + 1):
			var angle: float = TAU * float(segment) / SECTIONS
			var x: float = cos(angle) * radius
			var y: float = sin(angle) * radius
			vertices.append(Vector3(x * size.x, y * size.y, -size.z * (1.0 - radius * radius)))
			normals.append(Vector3(x * 0.22, y * 0.22, -1.0).normalized())
			uvs.append(Vector2(x, y) * 0.5 + Vector2.ONE * 0.5)
			var fibre: float = sin(angle * 27.0 + radius * 8.0) * 0.5 + sin(angle * 43.0 - radius * 4.0) * 0.25
			var amber: Color = Color("93451c").lerp(Color("c88034"), clampf(0.50 + fibre * 0.25, 0.0, 1.0))
			var edge: float = smoothstep(0.78, 1.0, radius)
			var pupil_edge: float = 1.0 - smoothstep(0.50, 0.68, radius)
			colors.append(Color("3d2218") if row == 0 else amber.lerp(Color("3d2218"), maxf(edge, pupil_edge * 0.50)))
	for row in range(RINGS):
		for segment in range(SECTIONS):
			var a: int = row * (SECTIONS + 1) + segment
			var b: int = a + SECTIONS + 1
			indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
