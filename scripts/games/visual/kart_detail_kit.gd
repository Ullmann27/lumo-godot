extends RefCounted
## Bausteine der Kart-Detailschicht: lädt das Blender-Kleinteile-Kit einmal,
## baut daraus pro Streckenabschnitt EIN zusammengeführtes Mesh je Material
## (statisches Batching: ein Draw-Call pro Abschnitt und Material, Frustum-
## Culling pro Abschnitt) und liefert die gemeinsamen Materialien.
## Reine Dekoration: keine Kollision, keine Spiel-Logik.

const PROPS_GLB: String = "res://assets/kart/details/models/kart_detail_props.glb"
const WEAR_ATLAS: String = "res://assets/kart/details/textures/kart_detail_wear_atlas.png"
const BANNER_ATLAS: String = "res://assets/kart/details/textures/kart_detail_banner_atlas.png"
const PROP_SHADER: String = "res://assets/shaders/kart_detail_props.gdshader"
const DECAL_SHADER: String = "res://assets/shaders/kart_detail_decal.gdshader"
const GLOW_SHADER: String = "res://assets/shaders/kart_detail_glow.gdshader"
## Kachelreihenfolge des Verschleiß-Atlas (Vertrag mit make_detail_textures.py).
const WEAR_TILES: Array[String] = [
	"skid", "oil", "patch", "manhole",
	"puddle", "leaves", "sand", "snow",
	"crack", "streak", "moss", "grime",
	"rust", "plaster", "rubber", "tar",
]
const BANNER_TRACKS: Array[String] = [
	"sonnenhafen", "zauberwald", "bergwelt", "holo_city", "crystal_canyon",
	"jungle_temple", "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway",
	"desert_drift", "learning_lab", "jungle_emerald_3600",
]
## Banner-Zellen 13..31: Lumo-Fantasiemarken (siehe make_detail_textures.py).
const BRAND_CELLS: Dictionary = {
	"sternenbrause": 13, "fuchsflitzer": 14, "kometen_kakao": 15, "wolkenwerk": 16,
	"gluehwurm": 17, "nova_nudeln": 18, "milos_muscheln": 19, "funkelfunk": 20,
	"blitzbeere": 21, "lumo_kart": 22, "drehwurm": 23, "schneeflocke": 24,
	"lavalolli": 25, "pixelpost": 26, "raketenroller": 27, "sandschaufel": 28,
	"zahlenzauber": 29, "mondmilch": 30, "start": 31,
}

static var _meshes: Dictionary = {}
static var _box: Array = []
static var _materials: Dictionary = {}


## Mesh-Arrays eines Kleinteils ("name" oder "name__glow"); leer, wenn es fehlt.
static func part(name: String) -> Array:
	if _meshes.is_empty():
		_load_kit()
	return _meshes.get(name, [])


static func has_part(name: String) -> bool:
	return not part(name).is_empty()


static func _load_kit() -> void:
	_meshes["__loaded"] = []
	if not ResourceLoader.exists(PROPS_GLB):
		push_warning("[KartDetail] Kleinteile-Kit fehlt: " + PROPS_GLB)
		return
	var scene: PackedScene = load(PROPS_GLB)
	var root: Node = scene.instantiate()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			var arrays: Array = mesh.surface_get_arrays(0)
			var local: Transform3D = (node as Node3D).transform
			if not local.is_equal_approx(Transform3D.IDENTITY):
				arrays[Mesh.ARRAY_VERTEX] = local * PackedVector3Array(arrays[Mesh.ARRAY_VERTEX])
			_meshes[str(node.name)] = arrays
	root.free()


## Einheitswürfel mit weißer Vertex-Farbe (Gewicht 0) für Balken und Leinen.
static func box_arrays() -> Array:
	if _box.is_empty():
		_box = BoxMesh.new().get_mesh_arrays()
		var colors := PackedColorArray()
		colors.resize((_box[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colors.fill(Color(1, 1, 1, 0))
		_box[Mesh.ARRAY_COLOR] = colors
	return _box


static func material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var shader_material := ShaderMaterial.new()
	match kind:
		"props":
			shader_material.shader = load(PROP_SHADER)
		"flock":
			shader_material.shader = load(PROP_SHADER)
			shader_material.set_shader_parameter("orbit_speed", 0.22)
			shader_material.set_shader_parameter("flap", 1.0)
		"glow":
			shader_material.shader = load(GLOW_SHADER)
		"decal", "decal_wall":
			shader_material.shader = load(DECAL_SHADER)
			shader_material.set_shader_parameter("atlas", load(WEAR_ATLAS))
			shader_material.render_priority = 1 if kind == "decal" else 0
		"banner":
			var banner := StandardMaterial3D.new()
			banner.albedo_texture = load(BANNER_ATLAS)
			banner.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			banner.alpha_scissor_threshold = 0.5
			banner.cull_mode = BaseMaterial3D.CULL_DISABLED
			banner.roughness = 0.6
			banner.emission_enabled = true
			banner.emission_texture = banner.albedo_texture
			banner.emission = Color.WHITE
			banner.emission_energy_multiplier = 0.25
			banner.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			_materials[kind] = banner
			return banner
	_materials[kind] = shader_material
	return shader_material


## Sammelt Geometrie eines Materials für einen Abschnitt.
class Batch:
	extends RefCounted
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var triangles: int = 0

	func add_arrays(arrays: Array, xform: Transform3D, tint: Color = Color.WHITE, phase: float = 0.0) -> void:
		var base: int = vertices.size()
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		vertices.append_array(xform * source_vertices)
		var normal_basis: Basis = xform.basis.inverse().transposed()
		for n: Vector3 in source_normals:
			normals.append((normal_basis * n).normalized())
		var count: int = source_vertices.size()
		var plain: bool = tint.is_equal_approx(Color.WHITE)
		for i in range(count):
			var c: Color = source_colors[i] if i < source_colors.size() else Color(1, 1, 1, 0)
			if not plain:
				c = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
			colors.append(c)
			uvs.append(Vector2.ZERO)
			uv2s.append(Vector2(phase, 0.0))
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if source_indices.is_empty():
			for i in range(count):
				indices.append(base + i)
		else:
			for i in source_indices:
				indices.append(base + i)
		triangles += (source_indices.size() if not source_indices.is_empty() else count) / 3

	## Ein Rechteck (zwei Dreiecke) – Decals, Banner, Wimpel.
	func add_quad(corners: Array, normal: Vector3, uv_rect: Rect2, color: Color, uv2: Vector2 = Vector2.ZERO) -> void:
		var base: int = vertices.size()
		var uv_corners: Array[Vector2] = [
			uv_rect.position + Vector2(0, uv_rect.size.y), uv_rect.position + uv_rect.size,
			uv_rect.position + Vector2(uv_rect.size.x, 0), uv_rect.position]
		for k in range(4):
			vertices.append(corners[k])
			normals.append(normal)
			colors.append(color)
			uvs.append(uv_corners[k])
			uv2s.append(uv2)
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
		triangles += 2

	func add_triangle(a: Vector3, b: Vector3, c: Vector3, color: Color, uv2: Vector2 = Vector2.ZERO) -> void:
		var base: int = vertices.size()
		var n: Vector3 = (b - a).cross(c - a).normalized()
		for p in [a, b, c]:
			vertices.append(p)
			normals.append(n)
			colors.append(color)
			uvs.append(Vector2.ZERO)
			uv2s.append(uv2)
		indices.append_array(PackedInt32Array([base, base + 2, base + 1]))
		triangles += 1

	func is_empty() -> bool:
		return indices.is_empty()

	## Mittelpunkt der Geometrie (für Sichtweiten-/Culling-Bezug des Knotens).
	func centre() -> Vector3:
		if vertices.is_empty():
			return Vector3.ZERO
		var box := AABB(vertices[0], Vector3.ZERO)
		for v in vertices:
			box = box.expand(v)
		return box.get_center()

	func commit(offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
		if offset != Vector3.ZERO:
			vertices = Transform3D(Basis.IDENTITY, -offset) * vertices
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static func wear_rect(tile: String) -> Rect2:
	var index: int = maxi(0, WEAR_TILES.find(tile))
	var inset: float = 6.0 / 1024.0
	return Rect2(Vector2(index % 4, index / 4) * 0.25 + Vector2(inset, inset), Vector2(0.25 - inset * 2.0, 0.25 - inset * 2.0))


static func banner_rect(cell: int) -> Rect2:
	var col: int = cell / 16
	var row: int = cell % 16
	return Rect2(Vector2(col * 0.5, row / 16.0) + Vector2(0.002, 0.002), Vector2(0.496, 1.0 / 16.0 - 0.004))


static func track_banner_cell(track_id: String) -> int:
	return maxi(0, BANNER_TRACKS.find(track_id))
