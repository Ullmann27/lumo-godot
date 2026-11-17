extends RefCounted
## One reusable unit chamfer box, not subdivisions on every individual object.
## Same exact outer bounds as the original BoxMesh; never used for collisions.
static var _box: ArrayMesh

static func chamfer_box() -> ArrayMesh:
	if _box != null:
		return _box
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const H := 0.5
	const Q := 0.46
	# Six inset planar faces.
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for uv in [Vector2(-Q, -Q), Vector2(Q, -Q), Vector2(Q, Q), Vector2(-Q, Q)]:
				var p := Vector3.ZERO
				p[axis] = sign_value * H
				p[u] = uv.x
				p[v] = uv.y
				points.append(p)
			_polygon(surface, points, normal)
	# Twelve diagonal edge strips, all inside the original unit cube.
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for su in [-1.0, 1.0]:
			for sv in [-1.0, 1.0]:
				var points: Array[Vector3] = []
				for offset in [Vector3(-Q, H, Q), Vector3(Q, H, Q), Vector3(Q, Q, H), Vector3(-Q, Q, H)]:
					var p := Vector3.ZERO
					p[axis] = offset.x
					p[u] = offset.y * su
					p[v] = offset.z * sv
					points.append(p)
				var normal := Vector3.ZERO
				normal[u] = su
				normal[v] = sv
				_polygon(surface, points, normal.normalized())
	# Eight corner triangles join the face and edge cuts without open seams.
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var signs := Vector3(x, y, z)
				_polygon(surface, [Vector3(H, Q, Q) * signs,
					Vector3(Q, H, Q) * signs, Vector3(Q, Q, H) * signs], signs.normalized())
	_box = surface.commit()
	_box.resource_name = "LumoCraftedChamfer44"
	return _box

static func _polygon(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	for index in range(1, points.size() - 1):
		var a: Vector3 = points[0]
		var b: Vector3 = points[index]
		var c: Vector3 = points[index + 1]
		# Godot's front faces are clockwise viewed from the outside.
		if (b - a).cross(c - a).dot(normal) > 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		for p in [a, b, c]:
			surface.set_normal(normal)
			surface.set_uv(Vector2(p.x + 0.5, p.z + 0.5))
			surface.add_vertex(p)
