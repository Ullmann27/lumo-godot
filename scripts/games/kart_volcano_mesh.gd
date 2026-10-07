extends RefCounted


## Original broken basalt rings: a crater and ridges rather than a perfect cone.
static func create() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var heights := [0.0, 0.15, 0.34, 0.56, 0.77, 0.94, 1.0]
	var radii := [1.0, 0.93, 0.76, 0.56, 0.35, 0.20, 0.18]
	var sides := 48
	for j in range(heights.size()):
		var ring := PackedVector3Array()
		for i in range(sides):
			var theta: float = i * TAU / sides
			var ridge: float = (
				1.0 + sin(theta * 7 + 0.4) * 0.065 + sin(theta * 13 + j * 0.7) * 0.028
			)
			var h: float = heights[j] + (sin(theta * 7) * 0.012 if j > 0 else 0)
			ring.append(Vector3(sin(theta) * radii[j] * ridge, h, cos(theta) * radii[j] * ridge))
		rings.append(ring)
	for j in range(rings.size() - 1):
		for i in range(sides):
			var n: int = (i + 1) % sides
			for p in [
				rings[j][i],
				rings[j + 1][i],
				rings[j + 1][n],
				rings[j][i],
				rings[j + 1][n],
				rings[j][n]
			]:
				surface.set_color(Color("5c5d76").lightened(sin(p.x * 31 + p.z * 19) * 0.08))
				surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()
