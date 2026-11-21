extends RefCounted
## Fahrbahnränder von Lumos Riesengarten: je Abschnitt ein eigenes, durchgehendes Profil
## (Holzbrett, Grasbord, Gartenmauer, Wasserrand, Seerosen-Wulst, Terrakotta-Rand,
## Schiene, Weidenzaun, Pflanztischkante). Die Kante liegt genau auf der Kollisionswand
## (kart_garden_world._wall_mesh), damit Bild und Fahrphysik übereinstimmen.
## In Gießkanne und Schlauch sind die Wände der Bauteile selbst der Rand.
const COURSE = preload("res://scripts/games/garden/kart_garden_course.gd")
const STEP: float = 2.0
const CHUNK: float = 180.0

## Profile: Punkte (außen m, hoch m) von innen unten nach außen; Farbe je Profil.
const PROFILES: Dictionary = {
	"brett":
	{
		"points": [[0.0, -0.1], [0.0, 0.75], [0.08, 0.9], [0.32, 0.9], [0.4, 0.75], [0.4, -0.3]],
		"color": Color("c8955c"),
		"cap": Color("fff1cf"),
	},
	"gras":
	{
		"points": [[0.0, -0.1], [0.05, 0.35], [0.25, 0.6], [0.6, 0.55], [0.9, 0.2], [1.1, -0.4]],
		"color": Color("5aa53c"),
		"cap": Color("8fd35a"),
	},
	"mauer":
	{
		"points": [[0.0, -0.1], [0.0, 1.0], [0.1, 1.15], [0.7, 1.15], [0.8, 1.0], [0.8, -2.0]],
		"color": Color("b9ae9c"),
		"cap": Color("e8e0cf"),
	},
	"wasser":
	{
		"points": [[0.0, -0.1], [0.02, 0.25], [0.2, 0.35], [0.4, 0.2], [0.45, -0.6]],
		"color": Color("6fc3df"),
		"cap": Color("dff7ff"),
	},
	"seerose":
	{
		"points": [[0.0, -0.1], [0.1, 0.35], [0.35, 0.75], [0.6, 0.95], [0.85, 0.8], [1.0, 0.1]],
		"color": Color("4e8f2e"),
		"cap": Color("c2425a"),
	},
	"topf":
	{
		"points": [[0.0, -0.1], [0.0, 0.9], [0.15, 1.15], [0.55, 1.15], [0.7, 0.9], [0.7, -0.6]],
		"color": Color("c9683a"),
		"cap": Color("e48a55"),
	},
	"schiene":
	{
		"points": [[0.0, -0.1], [0.05, 0.42], [0.0, 0.5], [0.42, 0.5], [0.37, 0.42], [0.42, -0.1]],
		"color": Color("8a8f96"),
		"cap": Color("d6dbe0"),
	},
	"weide":
	{
		"points": [[0.0, -0.1], [0.0, 0.95], [0.12, 1.05], [0.28, 1.05], [0.4, 0.95], [0.4, -0.3]],
		"color": Color("8b6a43"),
		"cap": Color("b38a59"),
	},
	"tisch":
	{
		"points": [[0.0, -0.1], [0.0, 1.0], [0.05, 1.1], [0.9, 1.1], [0.9, 0.85], [0.3, 0.85]],
		"color": Color("9b7650"),
		"cap": Color("f2e6cf"),
	},
}
## Abschnitte des Randes (Meter auf der Bahn, Profil). Leere Profile: der Bauteil ist der Rand.
const RUNS: Array = [
	[0.0, 118.0, "brett"],
	[118.0, 300.0, "gras"],
	[300.0, 398.0, "mauer"],
	[398.0, 462.0, ""],
	[462.0, 521.0, "wasser"],
	[521.0, 735.0, "seerose"],
	[735.0, 984.0, ""],
	[984.0, 1236.0, "topf"],
	[1236.0, 1516.0, "schiene"],
	[1516.0, 1700.0, "weide"],
	[1700.0, 1946.0, "gras"],
	[1946.0, 2321.0, "tisch"],
	[2321.0, 2411.2, "brett"],
]

## Lücken im Rand: [von, bis, Seite]. Das Pendelgleis der Gartenbahn kreuzt links.
const GAPS: Array = [[1370.5, 1380.5, -1.0]]


static func build(world: Node3D, _geometry_only: bool) -> void:
	var root := Node3D.new()
	root.name = "RiesengartenEdges"
	world.add_child(root)
	var matte := StandardMaterial3D.new()
	matte.vertex_color_use_as_albedo = true
	matte.roughness = 0.72
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.roughness = 0.28
	metal.metallic = 0.8
	var count: int = 0
	for run in RUNS:
		var style: String = str(run[2])
		if style.is_empty():
			continue
		var start: float = float(run[0])
		var end: float = minf(float(run[1]), float(world.length))
		while start < end - 0.5:
			var stop: float = minf(end, start + CHUNK)
			var node := MeshInstance3D.new()
			node.name = "Edge_%s_%04d" % [style, int(start)]
			node.mesh = _profile_mesh(world, start, stop, PROFILES[style])
			node.material_override = metal if style == "schiene" else matte
			node.visibility_range_end = 280.0
			node.visibility_range_end_margin = 20.0
			root.add_child(node)
			count += 1
			start = stop
	world.set_meta("garden_edge_meshes", count)


static func _profile_mesh(
	world: Node3D, start: float, end: float, profile: Dictionary
) -> ArrayMesh:
	var points: Array = profile.points
	var rows: int = maxi(1, ceili((end - start) / STEP))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for row in range(rows):
			var d0: float = lerpf(start, end, float(row) / float(rows))
			var d1: float = lerpf(start, end, float(row + 1) / float(rows))
			if _in_gap(d0, d1, side):
				continue
			for k in range(points.size() - 1):
				var top: bool = k > 0 and k < points.size() - 2
				var colour: Color = profile.cap if top else profile.color
				var a0: Vector3 = _at(world, d0, side, points[k])
				var b0: Vector3 = _at(world, d0, side, points[k + 1])
				var a1: Vector3 = _at(world, d1, side, points[k])
				var b1: Vector3 = _at(world, d1, side, points[k + 1])
				var normal: Vector3 = (b0 - a0).cross(a1 - a0).normalized() * -side
				st.set_color(colour)
				for v in [a0, b0, a1, a1, b0, b1]:
					st.set_normal(normal)
					st.add_vertex(v)
	return st.commit()


static func _in_gap(d0: float, d1: float, side: float) -> bool:
	for gap in GAPS:
		if side == float(gap[2]) and d1 > float(gap[0]) and d0 < float(gap[1]):
			return true
	return false


static func _at(world: Node3D, d: float, side: float, point: Array) -> Vector3:
	var basis: Basis = world.frame(d)
	var half: float = COURSE.width_at(d) * 0.5
	return world.position_at(d, side * (half + float(point[0]))) + basis.y * float(point[1])
