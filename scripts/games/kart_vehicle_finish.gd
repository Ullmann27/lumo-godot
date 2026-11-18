extends RefCounted
## Lack, Startnummer und Fantasie-Aufkleber der gebauten Aurora-Karosserien.
##
## Jedes der 14 Kart-Designs bekommt auf seiner Karosserie (comet/glider/turbo):
##  - eine eigene Lackart: matt, metallic (Klarlack mit Flakes) oder perlmutt (Klarlack + Schimmer)
##  - seine Startnummer (Platz in der Flotte, fest je Design) auf Nase und beiden Seitenschildern
##  - zwei bis vier Fantasie-Aufkleber aus kart_sticker_atlas.png (keine echten Marken)
## Nummern und Aufkleber hängen an den Markern Decal_* aus build_karts.py und sind nur in der
## nahen LOD sichtbar. Flakes (Detail-Normal-Map) gibt es nur im Profil HIGH bzw. im Schaustück.

const FLEET = preload("res://scripts/games/kart_fleet.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const ATLAS_PATH := "res://assets/kart/production/details/kart_sticker_atlas.png"
const FLAKE_PATH := "res://assets/kart/production/details/kart_flake_normal.png"
const ATLAS_CELLS := 4
## Zellen im Atlas (siehe tools/art/make_kart_detail_textures.py).
const STICKER_CELLS: Dictionary = {
	"fuchsstern": 0, "sternkraft": 1, "funkeloel": 2, "mondreifen": 3, "lerncrew": 4,
	"blitzbox": 5, "wolkenwerk": 6, "kometen": 7, "zahlenzauber": 8, "igelgrip": 9,
	"polarlicht": 10, "sonnenhafen": 11, "checker": 12, "pfotenpower": 13, "turbotee": 14,
	"lumostripe": 15,
}
## Lackart und Aufkleber je Design. Vorn/hinten je Seite; Lumos Comet trägt den Fuchsstern.
const DESIGNS: Dictionary = {
	"comet": {"finish": "metallic", "stickers": ["fuchsstern", "sternkraft"]},
	"gecko_velo": {"finish": "pearl", "stickers": ["igelgrip", "funkeloel"]},
	"boru_rally": {"finish": "matte", "stickers": ["checker", "mondreifen"]},
	"glider": {"finish": "pearl", "stickers": ["wolkenwerk", "lerncrew"]},
	"nala_comet": {"finish": "metallic", "stickers": ["kometen", "pfotenpower"]},
	"noa_tide": {"finish": "pearl", "stickers": ["polarlicht", "sonnenhafen"]},
	"iva_aurora": {"finish": "pearl", "stickers": ["polarlicht", "zahlenzauber"]},
	"turbo": {"finish": "metallic", "stickers": ["lumostripe", "turbotee"]},
	"zuri_volt": {"finish": "metallic", "stickers": ["blitzbox", "funkeloel"]},
	"blitz": {"finish": "metallic", "stickers": ["blitzbox", "checker"]},
	"terra": {"finish": "matte", "stickers": ["mondreifen", "igelgrip"]},
	"koloss": {"finish": "matte", "stickers": ["checker", "turbotee"]},
	"phantom": {"finish": "pearl", "stickers": ["kometen", "mondreifen"]},
	"stella": {"finish": "metallic", "stickers": ["sternkraft", "fuchsstern"]},
}
const FINISHES: Array[String] = ["matte", "metallic", "pearl"]

static var _sticker_material: StandardMaterial3D
static var _sticker_meshes: Dictionary = {}


static func finish_of(design: String) -> String:
	return str(DESIGNS.get(design, {}).get("finish", "metallic"))


static func stickers_of(design: String) -> Array:
	return DESIGNS.get(design, {}).get("stickers", ["fuchsstern", "sternkraft"])


## Startnummer = Platz des Designs in der Flotte (1 = Lumos Comet). Fest, keine Zufallszahl.
static func number_of(design: String) -> int:
	var index: int = FLEET.ids().find(design)
	return index + 1 if index >= 0 else 0


## Lackart auf eine (bereits duplizierte) Lack-Kopie anwenden. flakes = Detail-Normal-Map.
static func apply_paint(material: StandardMaterial3D, finish: String, flakes: bool) -> void:
	material.clearcoat_enabled = finish != "matte"
	material.rim_enabled = false
	material.detail_enabled = false
	match finish:
		"matte":
			material.metallic = 0.04
			material.roughness = 0.66
			material.metallic_specular = 0.35
		"pearl":
			material.metallic = 0.22
			material.roughness = 0.24
			material.clearcoat = 1.0
			material.clearcoat_roughness = 0.06
			# Perlmutt: weicher heller Schimmer an den Kanten des Lacks.
			material.rim_enabled = true
			material.rim = 0.28
			material.rim_tint = 0.65
		_:
			material.metallic = 0.58
			material.roughness = 0.30
			material.clearcoat = 0.85
			material.clearcoat_roughness = 0.10
	if flakes and finish != "matte":
		var flake := load(FLAKE_PATH) as Texture2D
		if flake != null:
			material.detail_enabled = true
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
			material.detail_normal = flake
			material.uv1_scale = Vector3(26.0, 26.0, 1.0) if finish == "metallic" else Vector3(40.0, 40.0, 1.0)


## Nummern und Aufkleber an die Marker hängen. Gibt die erzeugten Knoten zurück (für LOD).
static func dress(asset_root: Node3D, design: String, look: Dictionary) -> Array[Node3D]:
	var made: Array[Node3D] = []
	if asset_root == null:
		return made
	var number: int = number_of(design)
	var stickers: Array = stickers_of(design)
	for marker in asset_root.find_children("Decal_*", "Node3D", true, false):
		var key := str(marker.name)
		var holder := Node3D.new()
		holder.name = "Dress_" + key.trim_prefix("Decal_")
		marker.add_child(holder)
		if key.contains("Nose"):
			_face_forward_readable(marker, holder)
		if key.begins_with("Decal_Number") and number > 0:
			holder.add_child(_number_label(number, 0.10 if key.contains("Nose") else 0.062, look))
			made.append(holder)
		elif key.begins_with("Decal_Sticker"):
			var sticker: String = str(stickers[0 if key.contains("Front") else mini(1, stickers.size() - 1)])
			var quad := MeshInstance3D.new()
			quad.name = "Sticker_" + sticker
			quad.mesh = _sticker_mesh(sticker, 0.10)
			quad.material_override = _sticker_mat()
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(quad)
			made.append(holder)
		else:
			holder.free()
	return made


## Die Nasen-Nummer liegt fast waagerecht: von vorn lesbar, Oberkante zeigt zum Cockpit.
static func _face_forward_readable(marker: Node3D, holder: Node3D) -> void:
	# In Karosserie-Koordinaten rechnen (funktioniert auch außerhalb des Baums).
	var normal: Vector3 = marker.basis.z.normalized()
	var up: Vector3 = Vector3.BACK - normal * Vector3.BACK.dot(normal)
	if up.length() < 0.2:
		return
	up = up.normalized()
	var right: Vector3 = up.cross(normal).normalized()
	holder.basis = marker.basis.orthonormalized().inverse() * Basis(right, up, normal)


static func _number_label(number: int, height: float, look: Dictionary) -> Label3D:
	var label := Label3D.new()
	label.name = "StartNumber"
	label.text = str(number)
	label.font = FONT
	label.font_size = 96
	# Ziffernhöhe ~ 0.72 * font_size Pixel.
	label.pixel_size = height / (96.0 * 0.72)
	var paint: Color = look.get("paint", Color("0f2450"))
	label.modulate = paint.darkened(0.35) if paint.get_luminance() > 0.25 else paint
	label.outline_size = 10
	label.outline_modulate = Color(look.get("accent", Color("ffc23a")))
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.shaded = true
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = Vector3(0, 0, 0.0015)
	return label


static func _sticker_mat() -> StandardMaterial3D:
	if _sticker_material == null:
		_sticker_material = StandardMaterial3D.new()
		_sticker_material.resource_name = "FantasySticker"
		_sticker_material.albedo_texture = load(ATLAS_PATH)
		_sticker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_sticker_material.alpha_scissor_threshold = 0.5
		_sticker_material.roughness = 0.32
		_sticker_material.metallic_specular = 0.6
		_sticker_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _sticker_material


static func _sticker_mesh(sticker: String, width: float) -> ArrayMesh:
	var key := "%s:%.3f" % [sticker, width]
	if _sticker_meshes.has(key):
		return _sticker_meshes[key]
	var cell: int = int(STICKER_CELLS.get(sticker, 0))
	var u0: float = float(cell % ATLAS_CELLS) / ATLAS_CELLS
	var v0: float = floorf(cell / float(ATLAS_CELLS)) / ATLAS_CELLS
	var step: float = 1.0 / ATLAS_CELLS
	var h: float = width * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, h, 0), Vector3(h, h, 0), Vector3(h, -h, 0), Vector3(-h, -h, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(u0, v0), Vector2(u0 + step, v0), Vector2(u0 + step, v0 + step), Vector2(u0, v0 + step)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sticker_meshes[key] = mesh
	return mesh
