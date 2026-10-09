extends RefCounted
## Short, opaque, genuinely three-dimensional fur. No alpha shells or billboard.
## Surface-area sampling avoids dense bands at the poles of the sculpted meshes.


static func build(
	source: Mesh, color: Color, count: int, strand_length: float, seed_value: int
) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var source_colors: PackedColorArray = (
		arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	)
	var cumulative := PackedFloat32Array()
	var total: float = 0.0
	for i in range(0, indices.size(), 3):
		total += (
			(
				(vertices[indices[i + 1]] - vertices[indices[i]])
				. cross(vertices[indices[i + 2]] - vertices[indices[i]])
				. length()
			)
			* 0.5
		)
		cumulative.append(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(count):
		var target_area: float = rng.randf() * total
		var low: int = 0
		var high: int = cumulative.size() - 1
		while low < high:
			var middle: int = (low + high) / 2
			if cumulative[middle] < target_area:
				low = middle + 1
			else:
				high = middle
		var a: int = indices[low * 3]
		var b: int = indices[low * 3 + 1]
		var c: int = indices[low * 3 + 2]
		var root_weight: float = sqrt(rng.randf())
		var split: float = rng.randf()
		var wa: float = 1.0 - root_weight
		var wb: float = root_weight * (1.0 - split)
		var wc: float = root_weight * split
		var normal: Vector3 = (normals[a] * wa + normals[b] * wb + normals[c] * wc).normalized()
		var at: Vector3 = vertices[a] * wa + vertices[b] * wb + vertices[c] * wc - normal * 0.001
		var groom: Vector3 = Vector3.DOWN - normal * normal.dot(Vector3.DOWN)
		if groom.length_squared() < 0.001:
			groom = Vector3.RIGHT.cross(normal)
		groom = groom.normalized()
		var tangent: Vector3 = normal.cross(groom).normalized()
		var length_value: float = strand_length * rng.randf_range(0.68, 1.2)
		var tip: Vector3 = at + normal * length_value * 0.55 + groom * length_value * 0.65
		var width: float = length_value * 0.075
		var pigment: Color = color
		if source_colors.size() == vertices.size():
			pigment *= source_colors[a] * wa + source_colors[b] * wb + source_colors[c] * wc
		# Fine, gently shaded fibres avoid the coarse confetti appearance of
		# wide, high-contrast triangles while keeping the same strand budget.
		var root_color: Color = pigment.darkened(rng.randf_range(0.0, 0.045))
		var tip_color: Color = pigment.lightened(rng.randf_range(0.01, 0.035))
		# A narrow triangular prism remains visible from both race and garage cameras.
		var root_points: Array[Vector3] = [
			at - tangent * width, at + tangent * width, at + normal * width
		]
		for face in range(3):
			var p: Vector3 = root_points[face]
			var q: Vector3 = root_points[(face + 1) % 3]
			var face_normal: Vector3 = (tip - p).cross(q - p).normalized()
			if face_normal.dot(normal) < 0.0:
				var swap: Vector3 = p
				p = q
				q = swap
				face_normal = -face_normal
			surface.set_normal((normal * 0.8 + face_normal * 0.2).normalized())
			surface.set_color(root_color)
			surface.add_vertex(p)
			surface.add_vertex(q)
			surface.set_color(tip_color)
			surface.add_vertex(tip)
	surface.index()
	return surface.commit()
