class_name LumoWorldMeshes
extends RefCounted
## Small original meshes authored by mathematical profiles. No external assets.


static func profile(points: Array[Vector2], sides: int = 20, irregularity: float = 0.0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(points.size() - 1):
		for side in range(sides):
			var vertices: Array[Vector3] = []
			for corner in [[ring, side], [ring, side + 1], [ring + 1, side], [ring + 1, side + 1]]:
				var angle: float = float(corner[1]) * TAU / sides
				var p: Vector2 = points[corner[0]]
				var variation: float = 1.0 + irregularity * (sin(angle * 3.0 + p.y * 2.2) * 0.56 + cos(angle * 5.0 - p.y) * 0.44)
				vertices.append(Vector3(cos(angle) * p.x * variation, p.y, sin(angle) * p.x * variation))
			for index in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()


static func crown() -> ArrayMesh:
	# Broad, asymmetric, clustered canopy rather than a spherical tree primitive.
	return profile([
		Vector2(0.12, -0.82), Vector2(0.67, -0.72), Vector2(0.97, -0.35),
		Vector2(1.0, 0.08), Vector2(0.84, 0.53), Vector2(0.46, 0.85), Vector2(0.0, 1.0)
	], 14, 0.14)


static func fir() -> ArrayMesh:
	return profile([
		Vector2(0, 0), Vector2(1.0, 0.10), Vector2(0.66, 0.36),
		Vector2(0.83, 0.38), Vector2(0.45, 0.66), Vector2(0.64, 0.65),
		Vector2(0.22, 0.94), Vector2(0.34, 0.91), Vector2(0, 1.25)
	], 13, 0.10)


static func rock() -> ArrayMesh:
	return profile([
		Vector2(0.64, -0.50), Vector2(1.0, -0.21), Vector2(0.93, 0.25),
		Vector2(0.51, 0.68), Vector2(0.06, 0.81)
	], 9, 0.19)


static func mountain() -> ArrayMesh:
	return profile([
		Vector2(1.0, 0), Vector2(0.91, 0.17), Vector2(0.67, 0.33),
		Vector2(0.52, 0.51), Vector2(0.27, 0.68), Vector2(0.15, 0.83), Vector2(0.0, 1.0)
	], 11, 0.26)


static func sail() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0, 0, 0), Vector3(0, 4.8, 0), Vector3(0, 0.5, 2.8), Vector3(0, 0.5, 2.8), Vector3(0, 4.8, 0), Vector3(0, 0, 0)]:
		surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()


static func boat_hull() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Array[Vector3] = [Vector3(0, 0.6, -2.8), Vector3(1.0, 0.4, -1.25), Vector3(1.1, 0.3, 1.75), Vector3(0.75, 0.3, 2.25), Vector3(-0.75, 0.3, 2.25), Vector3(-1.1, 0.3, 1.75), Vector3(-1.0, 0.4, -1.25)]
	for i in range(top.size()):
		var a: Vector3 = top[i]
		var b: Vector3 = top[(i + 1) % top.size()]
		var c: Vector3 = Vector3(a.x * 0.5, -0.55, a.z * 0.84)
		var d: Vector3 = Vector3(b.x * 0.5, -0.55, b.z * 0.84)
		for p in [a, c, b, b, c, d, Vector3(0, 0.35, 0), b, a]:
			surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()


static func flower() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for petal in range(6):
		var a: float = float(petal) * TAU / 6
		var b: float = a + TAU / 6
		for p in [Vector3(0, 0.03, 0), Vector3(cos(a) * 0.34, 0.10, sin(a) * 0.34), Vector3(cos(b) * 0.34, 0.10, sin(b) * 0.34)]:
			surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()


static func crystal() -> ArrayMesh:
	return profile([Vector2(0, 0), Vector2(0.7, 0.17), Vector2(0.65, 1.1), Vector2(0, 1.7)], 6)


static func glass_tower() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector2]=[Vector2(-0.42,-0.5),Vector2(0.42,-0.5),Vector2(0.5,-0.42),Vector2(0.5,0.42),Vector2(0.42,0.5),Vector2(-0.42,0.5),Vector2(-0.5,0.42),Vector2(-0.5,-0.42)]
	for i in range(corners.size()):
		var a: Vector2=corners[i]
		var b: Vector2=corners[(i+1)%corners.size()]
		var bottom_a:=Vector3(a.x,-0.5,a.y)
		var bottom_b:=Vector3(b.x,-0.5,b.y)
		var top_a:=Vector3(a.x*0.92,0.5,a.y*0.92)
		var top_b:=Vector3(b.x*0.92,0.5,b.y*0.92)
		for p in [bottom_a,bottom_b,top_a,bottom_b,top_b,top_a,Vector3(0,0.5,0),top_a,top_b]:
			surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()
