extends RefCounted
## Original Lumo pigmentation and iris geometry. Opaque mobile PBR, no alpha shells.


static func smile_shell(low_detail: bool = false) -> ArrayMesh:
	# A closed, curved mouth volume fitted to the cream muzzle. Both corners
	# rise into the cheeks; the centre recedes toward the chin. No floating oval.
	var columns := 12 if low_detail else 32
	var rows := 4 if low_detail else 12
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for back in range(2):
		for row in range(rows + 1):
			var v := float(row) / rows
			for column in range(columns + 1):
				var u := float(column) / columns * 2.0 - 1.0
				var upper := -0.195 + 0.042 * u * u
				var lower := -0.295 + 0.142 * u * u
				vertices.append(
					Vector3(
						u * 0.176,
						lerpf(upper, lower, v),
						-0.387 + 0.036 * u * u + v * 0.010 + back * 0.018
					)
				)
				normals.append(Vector3(u * 0.38, 0.08, -1.0 if back == 0 else 1.0).normalized())
	var stride := columns + 1
	var side_size := stride * (rows + 1)
	for row in range(rows):
		for column in range(columns):
			var a := row * stride + column
			var b := a + stride
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
			indices.append_array(
				PackedInt32Array(
					[
						a + side_size,
						a + 1 + side_size,
						b + side_size,
						a + 1 + side_size,
						b + 1 + side_size,
						b + side_size
					]
				)
			)
	# Close all four edges; the outer side edges taper naturally to smile corners.
	var edge := PackedInt32Array()
	for column in range(stride):
		edge.append(column)
	for row in range(1, rows + 1):
		edge.append(row * stride + columns)
	for column in range(columns - 1, -1, -1):
		edge.append(rows * stride + column)
	for row in range(rows - 1, 0, -1):
		edge.append(row * stride)
	for index in range(edge.size()):
		var a := edge[index]
		var b := edge[(index + 1) % edge.size()]
		indices.append_array(
			PackedInt32Array([a, b, a + side_size, b, b + side_size, a + side_size])
		)
	# Discard the zero-area triangles at the tapered corners and derive
	# consistent smooth normals from the actual closed surface winding.
	var solid_indices := PackedInt32Array()
	normals.fill(Vector3.ZERO)
	for triangle in range(0, indices.size(), 3):
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		if normal.length_squared() <= 0.00000000000001:
			continue
		solid_indices.append_array(PackedInt32Array([a, b, c]))
		for index in [a, b, c]:
			normals[index] += normal
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	indices = solid_indices
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not low_detail:
		result.set_meta("far_geometry", smile_shell(true))
	return result


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
		result.set_meta(
			"far_geometry", coat(source.get_meta("far_geometry"), orange, cream, region)
		)
	return result


static func eye_overlay(
	size: Vector3,
	support: Vector3,
	offset: Vector2,
	gap: float,
	pigmented: bool,
	low_detail: bool = false
) -> ArrayMesh:
	# The coloured iris and dark pupil share the white ellipsoid's curvature.
	# A constant translation would leave their edges floating or buried.
	var arrays: Array = iris(size, low_detail).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	for index in range(vertices.size()):
		var point := vertices[index]
		var x := (point.x + offset.x) / support.x
		var y := (point.y + offset.y) / support.y
		var z := sqrt(maxf(0.001, 1.0 - x * x - y * y))
		vertices[index].z = -support.z * z - gap
		normals.append(Vector3(x / support.x, y / support.y, -z / support.z).normalized())
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not pigmented:
		arrays[Mesh.ARRAY_COLOR] = null
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if not low_detail:
		result.set_meta("far_geometry", eye_overlay(size, support, offset, gap, pigmented, true))
	return result


static func iris(size: Vector3, low_detail: bool = false) -> ArrayMesh:
	# A curved radial iris with a dark limbal ring and warm amber fibres.
	# Vertex colours survive the existing batcher and need no texture/draw pass.
	var sections: int = 16 if low_detail else 64
	var rings: int = 4 if low_detail else 10
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(rings + 1):
		var radius: float = float(row) / rings
		for segment in range(sections + 1):
			var angle: float = TAU * float(segment) / sections
			var x: float = cos(angle) * radius
			var y: float = sin(angle) * radius
			vertices.append(Vector3(x * size.x, y * size.y, -size.z * (1.0 - radius * radius)))
			normals.append(Vector3(x * 0.22, y * 0.22, -1.0).normalized())
			uvs.append(Vector2(x, y) * 0.5 + Vector2.ONE * 0.5)
			var fibre: float = (
				sin(angle * 27.0 + radius * 8.0) * 0.5 + sin(angle * 43.0 - radius * 4.0) * 0.25
			)
			var amber: Color = Color("93451c").lerp(
				Color("c88034"), clampf(0.50 + fibre * 0.25, 0.0, 1.0)
			)
			var edge: float = smoothstep(0.78, 1.0, radius)
			var pupil_edge: float = 1.0 - smoothstep(0.50, 0.68, radius)
			colors.append(
				(
					Color("3d2218")
					if row == 0
					else amber.lerp(Color("3d2218"), maxf(edge, pupil_edge * 0.50))
				)
			)
	for row in range(rings):
		for segment in range(sections):
			var a: int = row * (sections + 1) + segment
			var b: int = a + sections + 1
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
