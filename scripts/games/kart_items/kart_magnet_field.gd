extends RefCounted
## Magnetjoch, Polschuhe und magnetische Feldlinien in einem geteilten Vertexfarbennetz.

static var meshes := {}

static func mesh(low: bool) -> ArrayMesh:
	if meshes.has(low):
		return meshes[low]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := Color("ee4c43")
	var blue := Color("247cc5")
	var steel := Color("dfe9ee")
	# U-förmiges Joch am Heck. Jeder Querschnitt hat abgeflachte Flanken.
	var centre := Vector3(0, 1.04, 1.40)
	var arc := PackedVector3Array()
	for i in range(19):
		var angle := PI + PI * i / 18.0
		arc.append(centre + Vector3(cos(angle) * 0.62, sin(angle) * 0.57, 0))
	for i in range(18):
		_bar(surface, arc[i], arc[i+1], 0.17, red if i < 9 else blue, 8)
	for side in [-1.0, 1.0]:
		var pole := centre + Vector3(float(side) * 0.62, 0, 0)
		var joint := pole + Vector3(0, 0.36, -0.09)
		var tip := joint + Vector3(0, 0.23, -0.06)
		_bar(surface, pole, joint, 0.17, red if side < 0 else blue, 8)
		_bar(surface, joint, tip, 0.19, steel, 8)
		# Lines leave each pole vertically, bow out beside the wheels and return
		# over the nose to the opposite pole. Different arches show field depth.
		for k in range(1 if low else 2):
			var start := tip
			for step in range(1, 17):
				var t := float(step) / 16.0
				var angle := t * PI
				var x := (0.62 * cos(angle * 0.5) + (1.23 + 0.39 * k) * sin(angle)) * float(side)
				var y := tip.y * (1.0-t) + 0.4*t + 0.80*sin(angle*2.0) * (1.0-t)
				var z := lerpf(tip.z, -1.9 - k * 0.44, smoothstep(0.0, 1.0, t))
				var next := Vector3(x, y, z)
				_bar(surface, start, next, 0.026 + k * 0.006, Color("ffc78a") if side < 0 else Color("73edff"), 4)
				start = next
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.38
	surface.set_material(material)
	surface.index()
	var result := surface.commit()
	meshes[low] = result
	return result


static func _bar(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color, sides: int) -> void:
	var axis := (b-a).normalized()
	var across := axis.cross(Vector3.BACK)
	if across.length_squared() < 0.01:
		across = axis.cross(Vector3.UP)
	across = across.normalized()
	var around := axis.cross(across).normalized()
	for i in range(sides):
		var first := TAU*i/sides
		var second := TAU*(i+1)/sides
		var n0 := cos(first)*across + sin(first)*around
		var n1 := cos(second)*across + sin(second)*around
		var left := n0 * radius
		var right := n1 * radius
		for vertex in [a+left, b+left, b+right, a+left, b+right, a+right]:
			surface.set_color(color)
			surface.set_normal((n0+n1).normalized())
			surface.add_vertex(vertex)
		for vertex in [b,b+right,b+left]:
			surface.set_color(color)
			surface.set_normal(axis)
			surface.add_vertex(vertex)
