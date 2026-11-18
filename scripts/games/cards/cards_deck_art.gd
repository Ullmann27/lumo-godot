extends RefCounted
## Bild und Form der Sternendeck-Karten: ein Atlas, ein Material je Zustand,
## ein kleines Mesh je Karte mit runden Ecken, Vorder- und Rückseite.

const ATLAS_PATH := "res://assets/cards_table/deck/star_deck.webp"
const LAYOUT_PATH := "res://assets/cards_table/deck/star_deck.json"
const GLOW_PATH := "res://assets/cards_table/ui/card_glow.webp"
## Kartengröße in Welt-Einheiten (liegend: Breite auf X, Höhe auf Z).
const WIDTH := 0.26
const HEIGHT := 0.3656
const THICKNESS := 0.006
const CORNER := 0.024
const CORNER_STEPS := 4

static var _atlas: Texture2D
static var _layout: Dictionary = {}
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _glow_mesh: QuadMesh
static var _regions: Dictionary = {}


static func layout() -> Dictionary:
	if _layout.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
		if parsed is Dictionary:
			_layout = parsed
	return _layout


## Der Atlas mit Mipmaps: ohne sie flimmern Zahlen auf entfernten Karten.
static func atlas() -> Texture2D:
	if _atlas == null:
		var source: Texture2D = load(ATLAS_PATH)
		var image := source.get_image()
		if image != null and not image.is_compressed() and not image.has_mipmaps():
			image.generate_mipmaps()
			_atlas = ImageTexture.create_from_image(image)
		else:
			_atlas = source
	return _atlas


static func _cell(index: int) -> Rect2:
	var grid := layout()
	var columns := int(grid.columns)
	var size := Vector2(float(grid.cell[0]), float(grid.cell[1]))
	@warning_ignore("integer_division")
	return Rect2(Vector2(index % columns, index / columns) * size, size)


static func _cell_of(card_id: int) -> Rect2:
	var grid := layout()
	if card_id < 0:
		return _cell(int(grid.back))
	return _cell(int(grid.cards[str(card_id)]))


## Kartenbild für die Oberfläche (2D), card_id < 0 = Rückseite.
static func face_texture(card_id: int) -> AtlasTexture:
	if not _regions.has(card_id):
		var region := AtlasTexture.new()
		region.atlas = atlas()
		region.region = _cell_of(card_id).grow(-1.0)
		_regions[card_id] = region
	return _regions[card_id]


static func material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "star_card_" + kind
	mat.albedo_texture = atlas()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.42
	mat.metallic_specular = 0.45
	mat.emission_enabled = true
	mat.emission_texture = atlas()
	# Standard ist „Farbe + Textur“; Schwarz lässt nur das Kartenbild leuchten.
	mat.emission = Color.BLACK
	match kind:
		"hand":
			# Die eigene Hand bleibt in jedem Licht gut lesbar.
			mat.emission_energy_multiplier = 0.62
			mat.albedo_color = Color(0.62, 0.62, 0.62)
		"dim":
			mat.emission_energy_multiplier = 0.30
			mat.albedo_color = Color(0.36, 0.38, 0.46)
		_:
			mat.emission_energy_multiplier = 0.34
			mat.albedo_color = Color(0.86, 0.86, 0.86)
	_materials[kind] = mat
	return mat


static func glow_material(color: Color) -> StandardMaterial3D:
	var key := "glow_" + color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = load(GLOW_PATH)
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = -1
	_materials[key] = mat
	return mat


static func glow_mesh() -> QuadMesh:
	if _glow_mesh == null:
		_glow_mesh = QuadMesh.new()
		_glow_mesh.size = Vector2(WIDTH * 1.42, HEIGHT * 1.32)
		_glow_mesh.orientation = PlaneMesh.FACE_Y
	return _glow_mesh


static func _outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	var half := Vector2(WIDTH, HEIGHT) * 0.5
	var corners := [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]
	for index in range(4):
		var centre: Vector2 = corners[index] * (half - Vector2(CORNER, CORNER))
		var start := -PI * 0.5 + index * PI * 0.5
		for step in range(CORNER_STEPS + 1):
			var angle := start + PI * 0.5 * step / CORNER_STEPS
			points.append(centre + Vector2(cos(angle), sin(angle)) * CORNER)
	return points


## Mesh einer Karte: Vorderseite oben (+Y), Rückseite unten, schmaler Rand.
static func card_mesh(card_id: int) -> ArrayMesh:
	if _meshes.has(card_id):
		return _meshes[card_id]
	var grid := layout()
	var atlas_size := Vector2(float(grid.cell[0]) * int(grid.columns), float(grid.cell[1]) * int(grid.rows))
	var front := _cell_of(card_id).grow(-2.0)
	var back := _cell(int(grid.back)).grow(-2.0)
	var edge_uv := (_cell(int(grid.edge)).get_center()) / atlas_size
	var outline := _outline()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Vector2(WIDTH, HEIGHT) * 0.5
	var top := THICKNESS * 0.5
	var count := outline.size()
	for side in range(2):
		var up := side == 0
		var region := front if up else back
		var normal := Vector3.UP if up else Vector3.DOWN
		var y := top if up else -top
		for index in range(count):
			var ring: Array = [Vector2.ZERO, outline[index], outline[(index + 1) % count]]
			if not up:
				ring = [Vector2.ZERO, outline[(index + 1) % count], outline[index]]
			for point: Vector2 in ring:
				var fx := point.x / WIDTH + 0.5
				var fz := point.y / HEIGHT + 0.5
				if not up:
					fx = 1.0 - fx
				tool.set_normal(normal)
				tool.set_uv((region.position + Vector2(fx, fz) * region.size) / atlas_size)
				tool.add_vertex(Vector3(point.x, y, point.y))
	for index in range(count):
		var a := outline[index]
		var b := outline[(index + 1) % count]
		var outward := Vector3(a.x + b.x, 0.0, a.y + b.y).normalized()
		var quad := [Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, -top, b.y), Vector3(a.x, -top, a.y)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(outward)
			tool.set_uv(edge_uv)
			tool.add_vertex(quad[corner])
	var mesh := tool.commit()
	mesh.resource_name = "star_card_%d" % card_id
	mesh.custom_aabb = AABB(Vector3(-half.x, -top, -half.y), Vector3(WIDTH, THICKNESS, HEIGHT))
	_meshes[card_id] = mesh
	return mesh
