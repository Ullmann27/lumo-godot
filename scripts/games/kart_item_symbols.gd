extends RefCounted
## Original solid LUMO emblems. The same geometry identifies the earned item
## above a rival and the three possible outcomes on a skill-resonance gate.
## No camera-facing sprites, random awards, collision bodies or gameplay rules.

const KINDS: Array[String] = ["boost", "shield", "pulse"]
const COLORS := {
	"boost": Color("ffd166"),
	"shield": Color("66e8ff"),
	"pulse": Color("c58cff"),
}
const TITLES := {"boost": "Rückenwind", "shield": "Sternenschild", "pulse": "Lichtimpuls"}
const MEANINGS := {
	"boost": "Schub nach vorne",
	"shield": "Schutz vor Treffern",
	"pulse": "Rivalen in der Nähe verlangsamen",
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func build(kind: String) -> Node3D:
	assert(KINDS.has(kind), "Only an actual LUMO item has a world-space emblem.")
	var root := Node3D.new()
	root.name = "ItemSymbol_" + kind
	root.set_meta("lumo_item_symbol", kind)
	root.set_meta("lumo_item_title", str(TITLES[kind]))
	root.set_meta("lumo_item_meaning", str(MEANINGS[kind]))
	var motion := Node3D.new()
	motion.name = "SymbolMotion"
	root.add_child(motion)
	var body := MeshInstance3D.new()
	body.name = "SolidEmblem"
	body.mesh = mesh_for(kind)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motion.add_child(body)
	if kind == "pulse":
		for index in range(2):
			var arc := MeshInstance3D.new()
			arc.name = "PulseWave%d" % index
			arc.mesh = _wave_mesh()
			arc.material_override = accent_material(kind)
			arc.rotation.z = PI * float(index)
			arc.position.z = 0.02
			arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			motion.add_child(arc)
	return root


static func advance(symbol: Node3D, clock: float, reduce_motion: bool = false) -> void:
	if not is_instance_valid(symbol):
		return
	var motion := symbol.get_node_or_null("SymbolMotion") as Node3D
	if motion == null:
		return
	var phase: float = 0.0 if reduce_motion or not is_finite(clock) else clock
	# A small turn reveals thickness but never makes the meaning disappear edge-on.
	motion.position.y = 0.0 if reduce_motion else sin(phase * 2.0) * 0.045
	motion.rotation = Vector3(0.0, 0.0 if reduce_motion else sin(phase * 1.3) * 0.22, 0.0)
	for index in range(2):
		var wave := motion.get_node_or_null("PulseWave%d" % index) as Node3D
		if wave == null:
			continue
		var swell: float = 1.0 if reduce_motion else 1.0 + sin(phase * 2.4 + index * PI) * 0.065
		wave.scale = Vector3(swell, swell, 1.0)


static func accent_material(kind: String) -> StandardMaterial3D:
	var key: String = kind + "_accent"
	if not _materials.has(key):
		_materials[key] = _finish(COLORS[kind], 0.42, 0.25, 0.34)
	return _materials[key] as StandardMaterial3D


static func _finish(color: Color, metallic: float, roughness: float, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.55
	mat.clearcoat_roughness = 0.23
	mat.emission_enabled = glow > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = glow
	# Closed front/back volumes use correct clockwise front-face winding.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat


static func mesh_for(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind] as ArrayMesh
	var surfaces: Array[SurfaceTool] = []
	for _index in range(3):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(surface)
	match kind:
		"boost":
			# A broad swept arrow and a second wind streamer form an asymmetric,
			# directional silhouette; no lightning bolt or borrowed franchise icon.
			_solid(surfaces, PackedVector2Array([
				Vector2(-0.68, 0.12), Vector2(-0.45, 0.29), Vector2(0.10, 0.29),
				Vector2(0.04, 0.53), Vector2(0.76, 0.09), Vector2(0.13, -0.31),
				Vector2(0.19, -0.07), Vector2(-0.33, -0.07),
			]), 0.26, 0.065)
			_solid(surfaces, PackedVector2Array([
				Vector2(-0.68, -0.21), Vector2(-0.48, -0.12), Vector2(-0.12, -0.12),
				Vector2(-0.22, -0.30), Vector2(-0.49, -0.30), Vector2(-0.77, -0.43),
			]), 0.20, 0.04)
			_inlay(surfaces[2], PackedVector2Array([
				Vector2(-0.42, 0.13), Vector2(0.27, 0.13), Vector2(0.22, 0.04),
				Vector2(-0.48, 0.04),
			]), 0.155)
		"shield":
			_solid(surfaces, PackedVector2Array([
				Vector2(0.0, 0.74), Vector2(0.58, 0.52), Vector2(0.55, -0.08),
				Vector2(0.37, -0.40), Vector2(0.0, -0.72), Vector2(-0.37, -0.40),
				Vector2(-0.55, -0.08), Vector2(-0.58, 0.52),
			]), 0.34, 0.075)
			# A simple raised protective crest is distinct even without colour.
			_inlay(surfaces[2], PackedVector2Array([
				Vector2(0.0, 0.39), Vector2(0.10, 0.13), Vector2(0.34, 0.05),
				Vector2(0.10, -0.04), Vector2(0.0, -0.34), Vector2(-0.10, -0.04),
				Vector2(-0.34, 0.05), Vector2(-0.10, 0.13),
			]), 0.20)
		"pulse":
			# A six-lobed pulse core and two open wave crescents read as an area effect.
			var core := PackedVector2Array()
			for index in range(12):
				var angle: float = float(index) * TAU / 12.0 + PI * 0.5
				var radius: float = 0.50 if index % 2 == 0 else 0.26
				core.append(Vector2(cos(angle), sin(angle)) * radius)
			_solid(surfaces, core, 0.30, 0.045)
			_inlay(surfaces[2], _circle(0.125, 12), 0.18)
		_:
			assert(false, "Unknown LUMO item emblem")
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		surface.commit(mesh)
	mesh.surface_set_material(0, _finish(Color("18394b"), 0.48, 0.37, 0.04))
	mesh.surface_set_material(1, accent_material(kind))
	mesh.surface_set_material(2, _finish(Color("fff4d9"), 0.30, 0.29, 0.18))
	_meshes[kind] = mesh
	return mesh


static func _circle(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) * TAU / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot treats clockwise triangles as front-facing. Match the supplied
	# outward normal explicitly so double-sided shading cannot invert the light.
	var reverse: bool = (b - a).cross(c - a).dot(normal) > 0.0
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.add_vertex(c if reverse else b)
	tool.set_normal(normal)
	tool.add_vertex(b if reverse else c)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(tool, a, b, c, normal)
	_triangle(tool, a, c, d, normal)


static func _solid(surfaces: Array[SurfaceTool], points: PackedVector2Array, depth: float, bevel: float) -> void:
	var polygon: PackedVector2Array = points.duplicate()
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var inner := PackedVector2Array()
	var centre := Vector2.ZERO
	for point in polygon:
		centre += point
	centre /= float(polygon.size())
	for point in polygon:
		inner.append(centre + (point - centre) * 0.86)
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(inner)
	assert(not indices.is_empty(), "The item silhouette must be a valid solid polygon.")
	var front: float = depth * 0.5
	for index in range(0, indices.size(), 3):
		var a: Vector2 = inner[indices[index]]
		var b: Vector2 = inner[indices[index + 1]]
		var c: Vector2 = inner[indices[index + 2]]
		_triangle(surfaces[1], Vector3(a.x, a.y, front), Vector3(b.x, b.y, front), Vector3(c.x, c.y, front), Vector3.BACK)
		_triangle(surfaces[1], Vector3(c.x, c.y, -front), Vector3(b.x, b.y, -front), Vector3(a.x, a.y, -front), Vector3.FORWARD)
	for index in range(polygon.size()):
		var next: int = (index + 1) % polygon.size()
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[next]
		var ai: Vector2 = inner[index]
		var bi: Vector2 = inner[next]
		var outward := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		_quad(surfaces[0], Vector3(a.x,a.y,-front+bevel), Vector3(b.x,b.y,-front+bevel),
			Vector3(b.x,b.y,front-bevel), Vector3(a.x,a.y,front-bevel), outward)
		_quad(surfaces[1], Vector3(a.x,a.y,front-bevel), Vector3(b.x,b.y,front-bevel),
			Vector3(bi.x,bi.y,front), Vector3(ai.x,ai.y,front), (outward + Vector3.BACK).normalized())
		_quad(surfaces[1], Vector3(ai.x,ai.y,-front), Vector3(bi.x,bi.y,-front),
			Vector3(b.x,b.y,-front+bevel), Vector3(a.x,a.y,-front+bevel), (outward + Vector3.FORWARD).normalized())


static func _inlay(tool: SurfaceTool, points: PackedVector2Array, depth: float) -> void:
	var polygon: PackedVector2Array = points.duplicate()
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	assert(not indices.is_empty())
	for index in range(0, indices.size(), 3):
		var a: Vector2 = polygon[indices[index]]
		var b: Vector2 = polygon[indices[index + 1]]
		var c: Vector2 = polygon[indices[index + 2]]
		_triangle(tool, Vector3(a.x,a.y,depth), Vector3(b.x,b.y,depth), Vector3(c.x,c.y,depth), Vector3.BACK)
		_triangle(tool, Vector3(c.x,c.y,-depth), Vector3(b.x,b.y,-depth), Vector3(a.x,a.y,-depth), Vector3.FORWARD)
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var outward := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		_quad(tool, Vector3(a.x,a.y,-depth), Vector3(b.x,b.y,-depth),
			Vector3(b.x,b.y,depth), Vector3(a.x,a.y,depth), outward)


static func _wave_mesh() -> ArrayMesh:
	if _meshes.has("pulse_wave"):
		return _meshes["pulse_wave"] as ArrayMesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(15):
		var a: float = -PI * 0.31 + float(index) * PI * 0.62 / 15.0
		var b: float = -PI * 0.31 + float(index + 1) * PI * 0.62 / 15.0
		var r0: float = 0.65
		var r1: float = 0.75
		var p0 := Vector2(cos(a), sin(a)) * r0
		var p1 := Vector2(cos(b), sin(b)) * r0
		var p2 := Vector2(cos(b), sin(b)) * r1
		var p3 := Vector2(cos(a), sin(a)) * r1
		_quad(tool, Vector3(p0.x,p0.y,0.075),Vector3(p1.x,p1.y,0.075),Vector3(p2.x,p2.y,0.075),Vector3(p3.x,p3.y,0.075),Vector3.BACK)
		_quad(tool, Vector3(p3.x,p3.y,-0.075),Vector3(p2.x,p2.y,-0.075),Vector3(p1.x,p1.y,-0.075),Vector3(p0.x,p0.y,-0.075),Vector3.FORWARD)
		var normal := Vector3(cos((a+b)*0.5),sin((a+b)*0.5),0)
		_quad(tool,Vector3(p3.x,p3.y,0.075),Vector3(p2.x,p2.y,0.075),Vector3(p2.x,p2.y,-0.075),Vector3(p3.x,p3.y,-0.075),normal)
		_quad(tool,Vector3(p0.x,p0.y,-0.075),Vector3(p1.x,p1.y,-0.075),Vector3(p1.x,p1.y,0.075),Vector3(p0.x,p0.y,0.075),-normal)
		if index == 0:
			_quad(tool, Vector3(p0.x,p0.y,0.075),Vector3(p3.x,p3.y,0.075),
				Vector3(p3.x,p3.y,-0.075),Vector3(p0.x,p0.y,-0.075),Vector3(sin(a),-cos(a),0))
		if index == 14:
			_quad(tool, Vector3(p2.x,p2.y,0.075),Vector3(p1.x,p1.y,0.075),
				Vector3(p1.x,p1.y,-0.075),Vector3(p2.x,p2.y,-0.075),Vector3(-sin(b),cos(b),0))
	var mesh: ArrayMesh = tool.commit()
	_meshes["pulse_wave"] = mesh
	return mesh
