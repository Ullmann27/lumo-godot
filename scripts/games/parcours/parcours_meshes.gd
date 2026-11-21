extends RefCounted
## Geometrie der Parcours-Fahrbahn aus denselben Platten, auf denen das Kart fährt:
## Oberseite (mit Kantenlicht und Mittellinie), Seiten, Unterseite, Geländer, Stützen.
## Statische Platten landen in wenigen gemeinsamen Flächen (wenige Draw-Calls),
## bewegliche bekommen je einen eigenen Knoten, der der Kurszeit folgt.

## Godot zeigt Dreiecke im Uhrzeigersinn (vom Betrachter aus) als Vorderseite.
const FRONT_SIGN: float = -1.0
## Sammelt Dreiecke je Material. Schlüssel: "surface:<stil>", "body", "rail", "trim" …
var tools: Dictionary = {}
## Lage, in die alle folgenden Dreiecke gelegt werden (statische Platten: Ruhelage).
var xform: Transform3D = Transform3D.IDENTITY


func tool_for(key: String) -> SurfaceTool:
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	return tools[key]


func is_empty() -> bool:
	return tools.is_empty()


## Baut das Mesh. `materials` ordnet Schlüssel zu Materialien.
func commit(materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in tools:
		var st: SurfaceTool = tools[key]
		if str(key).begins_with("surface"):
			st.generate_tangents()
		st.commit(mesh)
		var material: Material = materials.get(key, materials.get("body"))
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func quad(
	key: String,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color = Color.BLACK,
	uv: Array = [],
	uv2: Array = [],
	outward: Vector3 = Vector3.ZERO
) -> void:
	var st := tool_for(key)
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	if normal.length() < 0.5:
		normal = (c - a).cross(d - a).normalized()
	if outward.length() > 0.001 and normal.dot(outward) < 0.0:
		normal = -normal
	var points: Array[Vector3] = [a, b, c, d]
	var tri: Array[int] = [0, 1, 2, 0, 2, 3]
	if (b - a).cross(c - a).dot(normal) * FRONT_SIGN < 0.0:
		tri = [0, 2, 1, 0, 3, 2]
	var world_normal: Vector3 = (xform.basis * normal).normalized()
	for k in tri:
		st.set_normal(world_normal)
		st.set_color(color)
		if not uv.is_empty():
			st.set_uv(uv[k])
		if not uv2.is_empty():
			st.set_uv2(uv2[k])
		st.add_vertex(xform * points[k])


func tri(key: String, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var st := tool_for(key)
	var normal: Vector3 = outward.normalized()
	var points: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) * FRONT_SIGN < 0.0:
		points = [a, c, b]
	for p in points:
		st.set_normal((xform.basis * normal).normalized())
		st.set_color(Color.BLACK)
		st.add_vertex(xform * p)


func box(key: String, centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var h: Vector3 = size * 0.5
	var corners: Array[Vector3] = []
	for z in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for x in [-1.0, 1.0]:
				corners.append(centre + basis * Vector3(h.x * x, h.y * y, h.z * z))
	# Indizes: x + 2y + 4z
	var faces: Array = [
		[1, 3, 7, 5], [4, 6, 2, 0], [2, 6, 7, 3], [0, 1, 5, 4], [5, 7, 6, 4], [0, 2, 3, 1]
	]
	for f in faces:
		var mid: Vector3 = (corners[f[0]] + corners[f[2]]) * 0.5
		quad(
			key,
			corners[f[0]],
			corners[f[1]],
			corners[f[2]],
			corners[f[3]],
			Color.BLACK,
			[],
			[],
			mid - centre
		)


func cylinder(
	key: String,
	bottom: Vector3,
	top: Vector3,
	radius_bottom: float,
	radius_top: float,
	sides: int = 10
) -> void:
	var axis: Vector3 = (top - bottom).normalized()
	var side: Vector3 = (
		axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	)
	var other: Vector3 = axis.cross(side).normalized()
	for i in range(sides):
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var d0: Vector3 = side * cos(a0) + other * sin(a0)
		var d1: Vector3 = side * cos(a1) + other * sin(a1)
		quad(
			key,
			bottom + d0 * radius_bottom,
			bottom + d1 * radius_bottom,
			top + d1 * radius_top,
			top + d0 * radius_top,
			Color.BLACK,
			[],
			[],
			d0 + d1
		)
		tri(key, top, top + d0 * radius_top, top + d1 * radius_top, axis)


## Querschnitt einer Platte bei u (0..1) in Plattenkoordinaten: Mitte, rechts, Höhe.
static func frame_at(slab: Dictionary, u: float) -> Dictionary:
	if str(slab.kind) == "box":
		var length: float = float(slab.length)
		return {
			"centre": Vector3(0.0, float(slab.rise) * u, -length * u),
			"right": Vector3.RIGHT,
			"along": length * u
		}
	var a: float = lerpf(float(slab.a0), float(slab.a1), u)
	var radial := Vector3(cos(a), 0.0, sin(a))
	var span: float = float(slab.a1) - float(slab.a0)
	return {
		"centre":
		radial * float(slab.radius) + Vector3.UP * lerpf(float(slab.y0), float(slab.y1), u),
		"right": radial if span > 0.0 else -radial,
		"along": float(slab.radius) * absf(span) * u
	}


static func segments_for(slab: Dictionary) -> int:
	if str(slab.kind) == "box":
		return maxi(1, ceili(float(slab.length) / 6.0))
	var arc_length: float = float(slab.radius) * absf(float(slab.a1) - float(slab.a0))
	return maxi(4, ceili(arc_length / 2.0))


## Fahrbahn einer Platte. `thickness` ist die Plattendicke, `surface_key` das Oberflächen-
## material, `centre_line` zeichnet die gelbe Mittellinie (schmale Brücken).
func slab(
	slab_data: Dictionary,
	surface_key: String,
	thickness: float,
	centre_line: bool,
	solid_to: float = INF,
	body_key: String = "body"
) -> void:
	var width: float = float(slab_data.width)
	var open_left: float = 0.0 if bool(slab_data.rail_left) else 1.0
	var open_right: float = 0.0 if bool(slab_data.rail_right) else 1.0
	var tint := Color(open_left, open_right, 1.0 if centre_line else 0.0)
	var count: int = segments_for(slab_data)
	var disc: bool = str(slab_data.get("style", "")) in ["disc", "sun_disc"]
	if disc:
		tint = Color(0, 1, 0)
	for i in range(count):
		var f0: Dictionary = frame_at(slab_data, float(i) / count)
		var f1: Dictionary = frame_at(slab_data, float(i + 1) / count)
		var l0: Vector3 = f0.centre - (f0.right as Vector3) * width * 0.5
		var r0: Vector3 = f0.centre + (f0.right as Vector3) * width * 0.5
		var l1: Vector3 = f1.centre - (f1.right as Vector3) * width * 0.5
		var r1: Vector3 = f1.centre + (f1.right as Vector3) * width * 0.5
		var a0: float = float(f0.along)
		var a1: float = float(f1.along)
		var uv := [Vector2(a0, 0.0), Vector2(a0, width), Vector2(a1, width), Vector2(a1, 0.0)]
		var uv2 := [
			Vector2(0.0, width), Vector2(width, 0.0), Vector2(width, 0.0), Vector2(0.0, width)
		]
		_top(surface_key, l0, r0, r1, l1, tint, uv, uv2)
		var down := Vector3.DOWN * thickness
		var bl0: Vector3 = l0 + down
		var br0: Vector3 = r0 + down
		var bl1: Vector3 = l1 + down
		var br1: Vector3 = r1 + down
		if solid_to < INF:
			bl0.y = solid_to
			br0.y = solid_to
			bl1.y = solid_to
			br1.y = solid_to
		var out_left: Vector3 = -(f0.right as Vector3)
		var out_right: Vector3 = f0.right
		quad(body_key, l1, bl1, bl0, l0, Color.BLACK, [], [], out_left)
		quad(body_key, r0, br0, br1, r1, Color.BLACK, [], [], out_right)
		quad(body_key, bl0, bl1, br1, br0, Color.BLACK, [], [], Vector3.DOWN)
		# Helle Zierleiste an der Plattenkante.
		var t1 := Vector3.DOWN * 0.03
		var t2 := Vector3.DOWN * 0.2
		var lift_l: Vector3 = out_left * 0.02
		var lift_r: Vector3 = out_right * 0.02
		quad(
			"trim",
			l1 + t1 + lift_l,
			l1 + t2 + lift_l,
			l0 + t2 + lift_l,
			l0 + t1 + lift_l,
			Color.BLACK,
			[],
			[],
			out_left
		)
		quad(
			"trim",
			r0 + t1 + lift_r,
			r0 + t2 + lift_r,
			r1 + t2 + lift_r,
			r1 + t1 + lift_r,
			Color.BLACK,
			[],
			[],
			out_right
		)
		var ahead: Vector3 = (f1.centre as Vector3) - (f0.centre as Vector3)
		if i == 0 and str(slab_data.kind) == "box" and not disc:
			quad(body_key, l0, bl0, br0, r0, Color.BLACK, [], [], -ahead)
		if i == count - 1 and str(slab_data.kind) == "box" and not disc:
			quad(body_key, r1, br1, bl1, l1, Color.BLACK, [], [], ahead)
	for side in [-1.0, 1.0]:
		var railed: bool = bool(slab_data.rail_right) if side > 0.0 else bool(slab_data.rail_left)
		if railed:
			rail(slab_data, side)


func _top(
	key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, uv: Array, uv2: Array
) -> void:
	quad(key, a, b, c, d, tint, uv, uv2, Vector3.UP)


## Geländer: Pfosten alle 2,6 m, Handlauf und Mittelstange als durchgehende Leisten.
func rail(slab_data: Dictionary, side: float) -> void:
	var width: float = float(slab_data.width)
	var count: int = segments_for(slab_data) * 2
	var total: float = float(frame_at(slab_data, 1.0).along)
	var next_post: float = 0.4
	for i in range(count):
		var f0: Dictionary = frame_at(slab_data, float(i) / count)
		var f1: Dictionary = frame_at(slab_data, float(i + 1) / count)
		var p0: Vector3 = f0.centre + (f0.right as Vector3) * (width * 0.5 - 0.12) * side
		var p1: Vector3 = f1.centre + (f1.right as Vector3) * (width * 0.5 - 0.12) * side
		for h in [0.98, 0.52]:
			var dir: Vector3 = p1 - p0
			var centre: Vector3 = (p0 + p1) * 0.5 + Vector3.UP * h
			var basis := (
				Basis.looking_at(dir.normalized(), Vector3.UP) if dir.length() > 0.01 else Basis()
			)
			box(
				"rail",
				centre,
				Vector3(0.11 if h > 0.9 else 0.07, 0.11 if h > 0.9 else 0.07, dir.length() + 0.04),
				basis
			)
		while next_post <= float(f1.along) and next_post <= total:
			var u: float = clampf(next_post / maxf(total, 0.01), 0.0, 1.0)
			var f: Dictionary = frame_at(slab_data, u)
			var p: Vector3 = f.centre + (f.right as Vector3) * (width * 0.5 - 0.12) * side
			box("rail_post", p + Vector3.UP * 0.5, Vector3(0.16, 1.0, 0.16))
			next_post += 2.6


## Stützen unter statischen Platten bis in die Wolken bzw. den Boden.
func supports(slab_data: Dictionary, depth: float, spacing: float, key: String = "support") -> void:
	var total: float = float(frame_at(slab_data, 1.0).along)
	var count: int = maxi(1, floori(total / spacing))
	var width: float = float(slab_data.width)
	for i in range(count):
		var u: float = (float(i) + 0.5) / count
		var f: Dictionary = frame_at(slab_data, u)
		var top: Vector3 = (f.centre as Vector3) + Vector3.DOWN * 0.5
		if width > 7.0:
			for side in [-1.0, 1.0]:
				var p: Vector3 = top + (f.right as Vector3) * width * 0.3 * side
				cylinder(key, p + Vector3.DOWN * depth, p, 0.55, 0.38, 10)
		else:
			cylinder(key, top + Vector3.DOWN * depth, top, 0.5, 0.32, 10)
