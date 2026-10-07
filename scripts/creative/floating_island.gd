extends RefCounted
## Original tapering floating rock geometry with a level lawn surface.
static func create() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for j in range(4):
		var ring := PackedVector3Array()
		for i in range(24):
			var angle: float = float(i) * TAU / 24.0
			var radius: float = [5.0, 4.6, 2.8, 0.25][j] * (1.0 + sin(angle * 5.0) * 0.055)
			ring.append(Vector3(cos(angle) * radius, [4.5, 2.6, -0.8, -5.0][j], sin(angle) * radius))
		rings.append(ring)
	for j in range(3):
		for i in range(24):
			var n: int = (i + 1) % 24
			for p in [rings[j][i], rings[j][n], rings[j + 1][n], rings[j][i], rings[j + 1][n], rings[j + 1][i]]:
				surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()
