extends RefCounted
## Bild-Modelle der Deutsch-Holo-Räume (Namenwort, Wiewort, Silben, Lesen):
## kleine, eigene Spielzeugfiguren aus gerundeten Grundkörpern. Jede Figur hat
## getrennte Materialien (Fell, Bauch, Augen …), eine klare leuchtende Kontur
## (Inverted Hull als next_pass), einen echten Schatten und darunter einen
## weichen Bodenschatten, der auch im LOW-Profil ohne Echtzeitschatten trägt.
## Handytauglich: ein gemeinsames Material je Farbe (statischer Cache), geteilte
## Meshes, keine Texturen. Die Figuren schauen nach +x (Seitenansicht).

const MODELS = preload("res://scripts/learning/holo/holo_models.gd")

## Alle Bilder, die die App senden darf.
const PICTURES: Array[String] = [
	"fuchs",
	"katze",
	"hase",
	"ente",
	"hund",
	"vogel",
	"sonne",
	"apfel",
	"ball",
	"baum",
	"haus",
	"blume",
	"banane",
	"tomate",
	"regenbogen",
]
## Möbel und Behälter der Lese-Szenen.
const PROPS: Array[String] = ["tisch", "stuhl", "kiste"]
## Farbwörter, die eine Figur annehmen kann (Wiewort-Hilfe „zwei Figuren“).
const COLOR_WORDS := {
	"rot": Color("e8423a"),
	"gelb": Color("ffd23f"),
	"grün": Color("5cc24a"),
	"blau": Color("3f8cff"),
	"weiß": Color("f4f1ea"),
	"braun": Color("9a6a3f"),
}
const OUTLINE := Color("8ff0ff")
const INK := Color("1d1a22")

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Gemeinsames Material je Farbe: weich schattiert, Fresnel-Kante im
## Hologramm-Cyan und leuchtende Außenkontur.
static func material(color: Color, outline: bool = true) -> Material:
	var key := "%s_%s" % [color.to_html(false), outline]
	if not _materials.has(key):
		var base := MODELS.rim_material(color, Color("9ff2ff"), 0.5)
		base.set_shader_parameter("rim_strength", 0.55)
		base.set_shader_parameter("self_light", 0.16)
		_materials[key] = MODELS.with_outline(base, OUTLINE, 0.014) if outline else base
	return _materials[key]


## Baut die Figur. `main` ersetzt die Hauptfarbe (z. B. „gelbe Ente“);
## ohne Angabe gilt die natürliche Farbe.
static func build(id: String, main: Color = Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.name = "Bild_%s" % id
	var custom := main.a > 0.0
	match id:
		"fuchs":
			_fox(root, main if custom else Color("f07a2a"))
		"katze":
			_cat(root, main if custom else Color("9aa3ad"))
		"hase":
			_rabbit(root, main if custom else Color("d9d2c6"))
		"ente":
			_duck(root, main if custom else Color("ffd23f"))
		"hund":
			_dog(root, main if custom else Color("b07a4a"))
		"vogel":
			_bird(root, main if custom else Color("3f8cff"))
		"sonne":
			_sun(root)
		"ball":
			_ball(root, main if custom else Color("e8423a"))
		"baum":
			_tree(root, main if custom else Color("46b04a"))
		"haus":
			_house(root, main if custom else Color("f3e2c0"))
		"blume":
			_flower(root, main if custom else Color("e8423a"))
		"banane":
			_banana(root)
		"tomate":
			_tomato(root)
		"regenbogen":
			_rainbow(root)
		"tisch":
			_table(root)
		"stuhl":
			_chair(root)
		"kiste":
			_crate(root)
		_:
			_apple(root, main if custom else Color("e0302b"))
	_ground_shadow(root, _footprint(id))
	return root


## Standfläche je Figur (Radius des weichen Bodenschattens).
static func _footprint(id: String) -> float:
	match id:
		"tisch", "regenbogen":
			return 0.75
		"stuhl", "kiste", "haus", "fuchs", "hund":
			return 0.55
		"sonne":
			return 0.0
	return 0.42


static func _ground_shadow(root: Node3D, radius: float) -> void:
	if radius <= 0.0:
		return
	var disc := MeshInstance3D.new()
	disc.name = "Bodenschatten"
	if not _meshes.has("shadow_disc"):
		var plane := PlaneMesh.new()
		plane.size = Vector2(2, 2)
		_meshes.shadow_disc = plane
	disc.mesh = _meshes.shadow_disc
	if not _materials.has("shadow_disc"):
		var shade := ShaderMaterial.new()
		var code := Shader.new()
		code.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0, 0.02, 0.06);
	ALPHA = 0.5 * smoothstep(1.0, 0.35, r);
}
"""
		shade.shader = code
		_materials.shadow_disc = shade
	disc.material_override = _materials.shadow_disc
	disc.scale = Vector3(radius * 1.2, 1.0, radius)
	disc.position.y = 0.012
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)


# ---------------------------------------------------------------- Bausteine


static func part(
	root: Node3D,
	mesh: Mesh,
	color: Color,
	at: Vector3,
	degrees: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE,
	outline: bool = true
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, outline)
	node.position = at
	node.rotation_degrees = degrees
	node.scale = scale_value
	root.add_child(node)
	return node


static func sphere(radius: float) -> Mesh:
	var key := "sphere_%.3f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 24
		mesh.rings = 12
		_meshes[key] = mesh
	return _meshes[key]


static func capsule(radius: float, height: float) -> Mesh:
	var key := "capsule_%.3f_%.3f" % [radius, height]
	if not _meshes.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = maxf(height, radius * 2.0)
		mesh.radial_segments = 18
		mesh.rings = 6
		_meshes[key] = mesh
	return _meshes[key]


static func cone(radius: float, height: float, tip: float = 0.0) -> Mesh:
	var key := "cone_%.3f_%.3f_%.3f" % [radius, height, tip]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = tip
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 1
		_meshes[key] = mesh
	return _meshes[key]


## Abgerundeter Quader mit Fase (Wortkarten-Geometrie), mit Außenseiten
## als Vorderseiten: Nur so sitzt die leuchtende Kontur (Inverted Hull)
## außen und die Fresnel-Kante stimmt.
static func block(size_value: Vector3) -> Mesh:
	var key := "block_%.3f_%.3f_%.3f" % [size_value.x, size_value.y, size_value.z]
	if _meshes.has(key):
		return _meshes[key]
	var source := MODELS.card_mesh(size_value)
	var mesh := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var order := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and arrays[Mesh.ARRAY_INDEX].size() > 0:
			order = arrays[Mesh.ARRAY_INDEX]
		else:
			for index in range(vertices.size()):
				order.append(index)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for start in range(0, order.size() - 2, 3):
			for corner in [0, 2, 1]:
				var vertex := order[start + corner]
				if surface == 0 and normals.size() > vertex:
					tool.set_normal(normals[vertex])
				tool.add_vertex(vertices[vertex])
		if surface > 0:
			tool.generate_normals()
		tool.commit(mesh)
	_meshes[key] = mesh
	return mesh


## Dreiecksprisma (Giebel): Grundseite entlang z, Spitze oben, Tiefe entlang x.
static func gable(width: float, height: float, depth: float) -> Mesh:
	var key := "gable_%.3f_%.3f_%.3f" % [width, height, depth]
	if not _meshes.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var half := depth * 0.5
		var corners := [
			Vector3(0, 0, -width * 0.5), Vector3(0, 0, width * 0.5), Vector3(0, height, 0)
		]
		for side in [-1.0, 1.0]:
			var tri := [corners[0], corners[1], corners[2]]
			if side < 0.0:
				tri = [corners[0], corners[2], corners[1]]
			for corner: Vector3 in tri:
				tool.add_vertex(corner + Vector3(half * side, 0, 0))
		for edge in range(3):
			var a: Vector3 = corners[edge]
			var b: Vector3 = corners[(edge + 1) % 3]
			var quad := [
				a + Vector3(half, 0, 0),
				a + Vector3(-half, 0, 0),
				b + Vector3(-half, 0, 0),
				b + Vector3(half, 0, 0)
			]
			for index in [0, 1, 2, 0, 2, 3]:
				tool.add_vertex(quad[index])
		tool.generate_normals()
		_meshes[key] = tool.commit()
	return _meshes[key]


static func ring(inner: float, outer: float) -> Mesh:
	var key := "ring_%.3f_%.3f" % [inner, outer]
	if not _meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 40
		mesh.ring_segments = 10
		_meshes[key] = mesh
	return _meshes[key]


static func bend(key: String, path: PackedVector3Array, radius: float) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = MODELS.tube(path, radius, 10)
	return _meshes[key]


static func _eyes(root: Node3D, at: Vector3, apart: float, size_value: float = 0.035) -> void:
	for side in [-1.0, 1.0]:
		part(
			root,
			sphere(size_value),
			INK,
			at + Vector3(0, 0, side * apart),
			Vector3.ZERO,
			Vector3.ONE,
			false
		)
		part(
			root,
			sphere(size_value * 0.35),
			Color.WHITE,
			at + Vector3(size_value * 0.75, size_value * 0.35, side * apart),
			Vector3.ZERO,
			Vector3.ONE,
			false
		)


# ---------------------------------------------------------------- Tiere


static func _fox(root: Node3D, fur: Color) -> void:
	var white := Color("f6efe4")
	var dark := fur.darkened(0.45)
	part(root, capsule(0.2, 0.72), fur, Vector3(0, 0.46, 0), Vector3(0, 0, 90))
	part(root, sphere(0.15), white, Vector3(0.22, 0.42, 0), Vector3.ZERO, Vector3(0.8, 1.0, 1.15))
	part(root, sphere(0.2), fur, Vector3(0.4, 0.72, 0))
	part(root, capsule(0.075, 0.26), white, Vector3(0.58, 0.66, 0), Vector3(0, 0, -90))
	part(root, sphere(0.036), INK, Vector3(0.71, 0.67, 0), Vector3.ZERO, Vector3.ONE, false)
	_eyes(root, Vector3(0.54, 0.79, 0), 0.095)
	for side in [-1.0, 1.0]:
		part(
			root, cone(0.085, 0.22), fur, Vector3(0.36, 0.95, side * 0.1), Vector3(side * -12, 0, 0)
		)
		part(
			root,
			cone(0.045, 0.12),
			dark,
			Vector3(0.375, 0.93, side * 0.1),
			Vector3(side * -12, 0, 0)
		)
		for front in [-1.0, 1.0]:
			part(root, capsule(0.052, 0.34), fur, Vector3(front * 0.22, 0.17, side * 0.11))
			part(root, sphere(0.062), dark, Vector3(front * 0.22 + 0.03, 0.03, side * 0.11))
	part(root, capsule(0.12, 0.58), fur, Vector3(-0.47, 0.56, 0), Vector3(0, 0, 55))
	part(root, sphere(0.112), white, Vector3(-0.68, 0.73, 0))


static func _cat(root: Node3D, fur: Color) -> void:
	var pink := Color("f2a0b4")
	part(root, capsule(0.17, 0.62), fur, Vector3(0, 0.42, 0), Vector3(0, 0, 90))
	part(root, sphere(0.19), fur, Vector3(0.34, 0.67, 0))
	part(root, sphere(0.03), pink, Vector3(0.53, 0.64, 0), Vector3.ZERO, Vector3.ONE, false)
	_eyes(root, Vector3(0.49, 0.72, 0), 0.08, 0.032)
	for side in [-1.0, 1.0]:
		part(
			root, cone(0.075, 0.16), fur, Vector3(0.32, 0.87, side * 0.1), Vector3(side * -14, 0, 0)
		)
		part(
			root,
			cone(0.04, 0.09),
			pink,
			Vector3(0.335, 0.86, side * 0.1),
			Vector3(side * -14, 0, 0)
		)
		for front in [-1.0, 1.0]:
			part(root, capsule(0.045, 0.32), fur, Vector3(front * 0.19, 0.16, side * 0.09))
	var path := PackedVector3Array()
	for step in range(9):
		var t := step / 8.0
		path.append(Vector3(-0.27 - sin(t * 1.6) * 0.2, 0.45 + t * 0.48, 0))
	part(root, bend("cat_tail", path, 0.04), fur, Vector3.ZERO)


static func _rabbit(root: Node3D, fur: Color) -> void:
	var pink := Color("f2a0b4")
	part(root, sphere(0.27), fur, Vector3(0, 0.33, 0))
	part(root, sphere(0.17), fur, Vector3(0.2, 0.62, 0))
	part(root, sphere(0.03), pink, Vector3(0.36, 0.6, 0), Vector3.ZERO, Vector3.ONE, false)
	_eyes(root, Vector3(0.32, 0.67, 0), 0.07, 0.03)
	for side in [-1.0, 1.0]:
		part(
			root,
			capsule(0.052, 0.42),
			fur,
			Vector3(0.16, 0.92, side * 0.07),
			Vector3(side * 8, 0, -10)
		)
		part(
			root,
			capsule(0.026, 0.3),
			pink,
			Vector3(0.195, 0.93, side * 0.07),
			Vector3(side * 8, 0, -10),
			Vector3.ONE,
			false
		)
		part(root, capsule(0.07, 0.3), fur, Vector3(-0.03, 0.08, side * 0.15), Vector3(0, 0, 80))
	part(root, sphere(0.085), Color("fbf8f2"), Vector3(-0.27, 0.36, 0))


static func _duck(root: Node3D, feathers: Color) -> void:
	var beak := Color("ff9a3c")
	part(root, sphere(0.3), feathers, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1.3, 0.8, 0.9))
	part(root, capsule(0.09, 0.26), feathers, Vector3(0.26, 0.54, 0), Vector3(0, 0, -15))
	part(root, sphere(0.15), feathers, Vector3(0.3, 0.68, 0))
	part(root, sphere(0.09), beak, Vector3(0.46, 0.65, 0), Vector3.ZERO, Vector3(1.4, 0.45, 1.0))
	_eyes(root, Vector3(0.39, 0.73, 0), 0.075, 0.028)
	part(root, cone(0.1, 0.22), feathers, Vector3(-0.42, 0.47, 0), Vector3(0, 0, 60))
	for side in [-1.0, 1.0]:
		part(
			root,
			sphere(0.16),
			feathers.darkened(0.12),
			Vector3(-0.03, 0.42, side * 0.24),
			Vector3.ZERO,
			Vector3(1.4, 0.55, 0.35)
		)
	part(
		root,
		ring(0.44, 0.5),
		Color("7fd4ff"),
		Vector3(0, 0.12, 0),
		Vector3.ZERO,
		Vector3.ONE,
		false
	)


static func _dog(root: Node3D, fur: Color) -> void:
	var light := fur.lightened(0.35)
	var dark := fur.darkened(0.4)
	part(root, capsule(0.2, 0.7), fur, Vector3(0, 0.46, 0), Vector3(0, 0, 90))
	part(root, sphere(0.2), fur, Vector3(0.38, 0.72, 0))
	part(root, capsule(0.09, 0.26), light, Vector3(0.57, 0.66, 0), Vector3(0, 0, -90))
	part(root, sphere(0.045), INK, Vector3(0.7, 0.68, 0), Vector3.ZERO, Vector3.ONE, false)
	_eyes(root, Vector3(0.52, 0.8, 0), 0.09)
	for side in [-1.0, 1.0]:
		part(
			root,
			capsule(0.062, 0.27),
			dark,
			Vector3(0.33, 0.69, side * 0.2),
			Vector3(side * 12, 0, 0)
		)
		for front in [-1.0, 1.0]:
			part(root, capsule(0.056, 0.36), fur, Vector3(front * 0.22, 0.18, side * 0.12))
			part(root, sphere(0.066), light, Vector3(front * 0.22 + 0.03, 0.03, side * 0.12))
	part(root, capsule(0.042, 0.32), fur, Vector3(-0.42, 0.66, 0), Vector3(0, 0, 40))


static func _bird(root: Node3D, feathers: Color) -> void:
	var beak := Color("ffc53a")
	part(root, sphere(0.22), feathers, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.25, 1.0, 0.9))
	part(
		root,
		sphere(0.15),
		feathers.lightened(0.45),
		Vector3(0.1, 0.44, 0),
		Vector3.ZERO,
		Vector3(1.0, 1.0, 1.05)
	)
	part(root, sphere(0.13), feathers, Vector3(0.24, 0.74, 0))
	part(root, cone(0.05, 0.14), beak, Vector3(0.4, 0.74, 0), Vector3(0, 0, -90))
	_eyes(root, Vector3(0.32, 0.78, 0), 0.07, 0.026)
	for side in [-1.0, 1.0]:
		part(
			root,
			sphere(0.16),
			feathers.darkened(0.2),
			Vector3(-0.04, 0.55, side * 0.19),
			Vector3(side * 25, 0, 0),
			Vector3(1.25, 0.32, 0.8)
		)
		part(
			root,
			capsule(0.02, 0.28),
			beak,
			Vector3(0.0, 0.2, side * 0.06),
			Vector3.ZERO,
			Vector3.ONE,
			false
		)
		part(
			root,
			capsule(0.018, 0.12),
			beak,
			Vector3(0.05, 0.07, side * 0.06),
			Vector3(0, 0, 90),
			Vector3.ONE,
			false
		)
	part(
		root,
		cone(0.085, 0.22),
		feathers.darkened(0.2),
		Vector3(-0.31, 0.56, 0),
		Vector3(0, 0, 70),
		Vector3(1, 1, 0.4)
	)


static func _sun(root: Node3D) -> void:
	var gold := Color("ffcf3a")
	part(root, sphere(0.3), gold, Vector3(0, 0.62, 0))
	for side in [-1.0, 1.0]:
		part(
			root,
			sphere(0.036),
			INK,
			Vector3(side * 0.1, 0.7, 0.27),
			Vector3.ZERO,
			Vector3.ONE,
			false
		)
	part(
		root,
		capsule(0.018, 0.16),
		INK,
		Vector3(0, 0.55, 0.285),
		Vector3(0, 0, 90),
		Vector3.ONE,
		false
	)
	for ray in range(10):
		var angle := TAU * ray / 10.0
		var at := Vector3(cos(angle) * 0.46, 0.62 + sin(angle) * 0.46, 0)
		part(root, cone(0.065, 0.2), Color("ffb02e"), at, Vector3(0, 0, rad_to_deg(angle) - 90))


# ---------------------------------------------------------------- Dinge


static func _apple(root: Node3D, skin: Color) -> void:
	var fruit := part(root, MODELS.apple(), skin, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 1.3)
	fruit.name = "Apfel"
	part(root, MODELS.stem(), Color("6a4424"), Vector3(0.01, 0.82, 0), Vector3(0, 0, -12))
	part(
		root,
		MODELS.leaf(),
		Color("4fb548"),
		Vector3(0.04, 0.86, 0),
		Vector3(20, -30, 18),
		Vector3.ONE * 1.3
	)


static func _ball(root: Node3D, color: Color) -> void:
	part(root, sphere(0.34), color, Vector3(0, 0.34, 0))
	part(
		root,
		ring(0.33, 0.36),
		Color("f6f1e6"),
		Vector3(0, 0.34, 0),
		Vector3(90, 0, 0),
		Vector3.ONE,
		false
	)
	part(
		root,
		ring(0.33, 0.36),
		Color("3f8cff"),
		Vector3(0, 0.34, 0),
		Vector3(90, 0, 90),
		Vector3.ONE,
		false
	)
	part(
		root,
		sphere(0.06),
		Color("ffd23f"),
		Vector3(0, 0.68, 0),
		Vector3.ZERO,
		Vector3(1, 0.3, 1),
		false
	)


static func _tree(root: Node3D, leaves: Color) -> void:
	var bark := Color("8a5a32")
	part(root, cone(0.13, 0.62, 0.08), bark, Vector3(0, 0.31, 0))
	part(root, sphere(0.3), leaves, Vector3(0, 0.82, 0))
	part(root, sphere(0.24), leaves.darkened(0.12), Vector3(-0.22, 0.7, 0.05))
	part(root, sphere(0.24), leaves.lightened(0.08), Vector3(0.22, 0.72, -0.04))
	part(root, sphere(0.22), leaves, Vector3(0.02, 1.04, 0))


static func _house(root: Node3D, wall: Color) -> void:
	var roof := Color("d4553a")
	var wood := Color("8a5a32")
	var glass := Color("9fdcff")
	part(root, block(Vector3(0.8, 0.56, 0.7)), wall, Vector3(0, 0.28, 0), Vector3(0, 90, 0))
	for side in [-1.0, 1.0]:
		part(
			root,
			block(Vector3(0.9, 0.06, 0.52)),
			roof,
			Vector3(0, 0.72, side * 0.19),
			Vector3(side * 40, 0, 0)
		)
	part(root, gable(0.8, 0.34, 0.66), wall.darkened(0.06), Vector3(0, 0.56, 0))
	part(root, block(Vector3(0.18, 0.3, 0.04)), wood, Vector3(0.36, 0.16, -0.12), Vector3(0, 90, 0))
	part(
		root, block(Vector3(0.18, 0.16, 0.04)), glass, Vector3(0.36, 0.34, 0.16), Vector3(0, 90, 0)
	)
	part(root, block(Vector3(0.1, 0.24, 0.1)), Color("b0413a"), Vector3(-0.16, 0.92, -0.2))


static func _flower(root: Node3D, petals: Color) -> void:
	var stalk := Color("4fb548")
	part(root, capsule(0.025, 0.7), stalk, Vector3(0, 0.35, 0))
	part(root, MODELS.leaf(), stalk, Vector3(0.0, 0.3, 0.02), Vector3(10, 0, 30), Vector3.ONE * 1.4)
	part(
		root,
		MODELS.leaf(),
		stalk,
		Vector3(0.0, 0.42, -0.02),
		Vector3(-10, 180, 30),
		Vector3.ONE * 1.2
	)
	var center := Vector3(0, 0.76, 0)
	for petal in range(6):
		var angle := TAU * petal / 6.0
		part(
			root,
			sphere(0.1),
			petals,
			center + Vector3(cos(angle) * 0.13, sin(angle) * 0.13, 0),
			Vector3(0, 0, rad_to_deg(angle) - 90),
			Vector3(0.9, 1.4, 0.5)
		)
	part(
		root,
		sphere(0.075),
		Color("ffcf3a"),
		center + Vector3(0, 0, 0.04),
		Vector3.ZERO,
		Vector3(1, 1, 0.6)
	)


static func _banana(root: Node3D) -> void:
	var yellow := Color("ffd84a")
	var path := PackedVector3Array()
	for step in range(13):
		var t := step / 12.0
		var angle := lerpf(-0.95, 0.95, t)
		path.append(Vector3(sin(angle) * 0.42, 0.5 - cos(angle) * 0.42, 0))
	part(root, bend("banana", path, 0.075), yellow, Vector3(0, 0.02, 0), Vector3(0, 0, 0))
	part(root, sphere(0.075), yellow, path[0] + Vector3(0, 0.02, 0))
	part(
		root,
		cone(0.045, 0.12, 0.03),
		Color("6a4424"),
		path[-1] + Vector3(0.03, 0.07, 0),
		Vector3(0, 0, -50)
	)
	part(
		root,
		sphere(0.04),
		Color("5a3a1e"),
		path[0] + Vector3(-0.05, 0.0, 0),
		Vector3.ZERO,
		Vector3.ONE,
		false
	)


static func _tomato(root: Node3D) -> void:
	part(
		root,
		sphere(0.32),
		Color("e8402e"),
		Vector3(0, 0.3, 0),
		Vector3.ZERO,
		Vector3(1.0, 0.82, 1.0)
	)
	for leaf_index in range(5):
		var angle := TAU * leaf_index / 5.0
		part(
			root,
			cone(0.05, 0.2),
			Color("4fb548"),
			Vector3(cos(angle) * 0.08, 0.56, sin(angle) * 0.08),
			Vector3(0, -rad_to_deg(angle), -75),
			Vector3(1, 1, 0.5)
		)
	part(root, capsule(0.02, 0.12), Color("4fb548"), Vector3(0, 0.6, 0))


static func _rainbow(root: Node3D) -> void:
	var bands := [
		Color("e8423a"), Color("ffb02e"), Color("ffd23f"), Color("5cc24a"), Color("3f8cff")
	]
	for index in range(bands.size()):
		var radius := 0.62 - index * 0.075
		var path := PackedVector3Array()
		for step in range(17):
			var angle := PI * step / 16.0
			path.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0))
		part(root, bend("rainbow_%d" % index, path, 0.04), bands[index], Vector3(0, 0.05, 0))
	for side in [-1.0, 1.0]:
		for puff in range(3):
			part(
				root,
				sphere(0.11 - puff * 0.02),
				Color("f4f1ea"),
				Vector3(side * (0.48 + puff * 0.12), 0.08 + puff * 0.02, 0)
			)


# ---------------------------------------------------------------- Lese-Szenen


static func _table(root: Node3D) -> void:
	var wood := Color("c08a54")
	part(root, block(Vector3(1.3, 0.8, 0.09)), wood, Vector3(0, 0.62, 0), Vector3(90, 0, 0))
	for x in [-0.52, 0.52]:
		for z in [-0.28, 0.28]:
			part(root, capsule(0.045, 0.6), wood.darkened(0.2), Vector3(x, 0.3, z))


static func _chair(root: Node3D) -> void:
	var wood := Color("6fa8dc")
	part(root, block(Vector3(0.62, 0.62, 0.08)), wood, Vector3(0, 0.42, 0), Vector3(90, 0, 0))
	part(root, block(Vector3(0.62, 0.52, 0.07)), wood, Vector3(-0.28, 0.72, 0), Vector3(0, 90, 0))
	for x in [-0.24, 0.24]:
		for z in [-0.24, 0.24]:
			part(root, capsule(0.035, 0.42), wood.darkened(0.25), Vector3(x, 0.2, z))


## Offene Kiste: Boden und vier Wände, oben offen (man sieht hinein).
static func _crate(root: Node3D) -> void:
	var wood := Color("c9934e")
	part(
		root,
		block(Vector3(0.9, 0.7, 0.06)),
		wood.darkened(0.15),
		Vector3(0, 0.04, 0),
		Vector3(90, 0, 0)
	)
	part(root, block(Vector3(0.9, 0.42, 0.06)), wood, Vector3(0, 0.22, 0.33))
	part(root, block(Vector3(0.9, 0.42, 0.06)), wood, Vector3(0, 0.22, -0.33))
	part(root, block(Vector3(0.7, 0.42, 0.06)), wood, Vector3(0.43, 0.22, 0), Vector3(0, 90, 0))
	part(root, block(Vector3(0.7, 0.42, 0.06)), wood, Vector3(-0.43, 0.22, 0), Vector3(0, 90, 0))


## Höhe der Oberseite (auf dem Tisch/Stuhl/Kistenrand) und Innenboden.
static func prop_top(id: String) -> float:
	return {"tisch": 0.67, "stuhl": 0.46, "kiste": 0.45}.get(id, 0.0)


static func prop_inside(id: String) -> float:
	return 0.08 if id == "kiste" else 0.0


## Halbe Breite des Möbels entlang x (für „daneben“).
static func prop_half_width(id: String) -> float:
	return {"tisch": 0.66, "stuhl": 0.34, "kiste": 0.46}.get(id, 0.4)
