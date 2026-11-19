extends RefCounted
## Gemeinsamer Baukasten für Lumos Spielzimmer (Kartentisch, Memory, Vier
## gewinnt): lädt die in Blender gebauten Möbel und gibt ihnen eigene
## Materialien mit den selbst erzeugten Texturen.
##
## Die GLB-Dateien tragen nur Materialnamen; hier werden sie zu Holz mit
## Maserung, Filz mit Gebrauchsspuren, Messing, Keramik usw. Alle Shader sind
## StandardMaterial3D – laufen auf Mobile und gl_compatibility gleich.
## Quellen: tools/lumo_table_art/build_room_props.py, make_room_textures.py.

const MODELS := "res://assets/table_room/models/%s.glb"
const TEX := "res://assets/table_room/textures/%s.webp"

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}
static var _materials_tier := ""


## Qualitätsstufe: "low", "medium" oder "high".
static func tier() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("PerformanceManager"):
		return str(tree.root.get_node("PerformanceManager").get_profile_name())
	return "medium"


static func texture(name: String) -> Texture2D:
	var path := TEX % name
	if not ResourceLoader.exists(path):
		push_warning("[TableRoom] Textur fehlt: " + name)
		return null
	return load(path)


static func _base(key: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "room_" + key
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


## Holz: Weltraum-Triplanar, damit jedes Möbel ohne eigene UV gemasert ist.
static func _wood(key: String, albedo: String, tint: Color, scale: float, normal: String = "") -> StandardMaterial3D:
	var material := _base(key, tint, 0.62)
	material.albedo_texture = texture(albedo)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if not normal.is_empty() and tier() != "low":
		material.normal_enabled = true
		material.normal_texture = texture(normal)
		material.normal_scale = 0.6
	# Ein Hauch Klarlack: Glanzkante unter der Lampe.
	if tier() == "high":
		material.clearcoat_enabled = true
		material.clearcoat = 0.35
		material.clearcoat_roughness = 0.35
	return material


static func material(key: String) -> Material:
	# Profilwechsel (z. B. in den Einstellungen) baut die Materialien neu.
	if _materials_tier != tier():
		_materials.clear()
		_materials_tier = tier()
	if _materials.has(key):
		return _materials[key]
	if "-" in key:
		return _tinted(key)
	var material: StandardMaterial3D
	match key:
		"oak":
			material = _wood(key, "oak_albedo", Color(1, 1, 1), 0.9, "oak_normal")
		"walnut":
			material = _wood(key, "walnut_albedo", Color(1, 1, 1), 1.3)
		"wall":
			material = _wood(key, "wall_planks_albedo", Color(0.92, 0.86, 0.82), 0.42, "wall_planks_normal")
			material.uv1_triplanar_sharpness = 8.0
		"floor":
			material = _base(key, Color(0.95, 0.9, 0.86), 0.7)
			material.albedo_texture = texture("floor_albedo")
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if tier() != "low":
				material.normal_enabled = true
				material.normal_texture = texture("floor_normal")
				material.normal_scale = 0.5
		"felt":
			material = _base(key, Color(1, 1, 1), 0.96)
			material.albedo_texture = texture("felt_worn")
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			# Der Sternenkreis im Filz leuchtet sacht (atmet über emission_energy).
			material.emission_enabled = true
			material.emission_texture = load("res://assets/cards_table/table/table_glow.webp")
			material.emission = Color.BLACK
			material.emission_energy_multiplier = 1.4
			material.rim_enabled = tier() == "high"
			material.rim = 0.25
			material.rim_tint = 0.8
		"rug":
			material = _base(key, Color(1, 1, 1), 1.0)
			material.albedo_texture = texture("rug_braided")
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.5
		"brass", "gold":
			material = _base(key, Color("d9aa55") if key == "brass" else Color("f4c24a"), 0.3, 0.9)
			if key == "gold":
				material.emission_enabled = true
				material.emission = Color("ffb52e")
				material.emission_energy_multiplier = 0.12
		"iron":
			material = _base(key, Color("2c2a2e"), 0.45, 0.6)
		"cushion":
			material = _base(key, Color("c0503a"), 0.95)
			material.rim_enabled = true
			material.rim = 0.35
		"book", "box":
			material = _base(key, Color(1, 1, 1), 0.78)
			material.vertex_color_use_as_albedo = true
			if key == "book":
				material.albedo_texture = texture("book_spines")
		"leaf":
			material = _base(key, Color(1, 1, 1), 0.55)
			material.vertex_color_use_as_albedo = true
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.rim_enabled = tier() != "low"
			material.rim = 0.3
			material.backlight_enabled = tier() == "high"
			material.backlight = Color(0.25, 0.4, 0.1)
		"glass":
			material = _base(key, Color(0.8, 0.92, 1.0, 0.32), 0.05, 0.0)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.metallic_specular = 0.9
			material.emission_enabled = true
			material.emission = Color("ffd27a")
			material.emission_energy_multiplier = 0.6
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		"lamp_shade":
			material = _base(key, Color("2f5a4c"), 0.38, 0.55)
		"lamp_bulb", "flame":
			material = _base(key, Color("ffe2a0"), 0.4)
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(1.0, 0.86, 0.55) * (2.4 if key == "lamp_bulb" else 3.0)
		"chalkboard":
			material = _base(key, Color(1, 1, 1), 0.92)
			material.albedo_texture = texture("chalkboard")
		"clock_face":
			material = _base(key, Color(1, 1, 1), 0.6)
			material.albedo_texture = texture("clock_face")
		"pot":
			material = _base(key, Color("b8653d"), 0.85)
		"soil":
			material = _base(key, Color("3a2618"), 1.0)
		"ceramic":
			material = _base(key, Color("f3efe6"), 0.22)
			material.metallic_specular = 0.7
		"cocoa":
			material = _base(key, Color("5a3420"), 0.25)
		"cookie":
			material = _base(key, Color("d39a55"), 0.9)
		"choc":
			material = _base(key, Color("3b2116"), 0.6)
		"juice":
			material = _base(key, Color(1.0, 0.6, 0.18, 0.86), 0.15)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"candle":
			material = _base(key, Color("f6e9cf"), 0.6)
			material.subsurf_scatter_enabled = false
		"chalk":
			material = _base(key, Color("f4f1e6"), 1.0)
		"globe":
			material = _base(key, Color("3a7bbf"), 0.35)
		_:
			material = _base(key, Color(1, 1, 1), 0.7)
	_materials[key] = material
	return material


## Farbvariante „basis-rrggbb“: gleiches Material, eigene Grundfarbe.
static func _tinted(key: String) -> Material:
	var made := (material(key.get_slice("-", 0)) as StandardMaterial3D).duplicate() as StandardMaterial3D
	made.resource_name = "room_" + key
	made.vertex_color_use_as_albedo = false
	made.albedo_color = Color(key.get_slice("-", 1))
	_materials[key] = made
	return made


## Instanziert ein Möbelstück und ersetzt seine Materialien. Gibt null zurück,
## wenn die Datei fehlt (die Szene bleibt dann ohne dieses Stück spielbar).
static func prop(name: String) -> Node3D:
	if not _scenes.has(name):
		var path := MODELS % name
		_scenes[name] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _scenes[name]
	if scene == null:
		push_warning("[TableRoom] Möbel fehlt: " + name)
		return null
	var node := scene.instantiate() as Node3D
	node.name = name.capitalize().replace(" ", "")
	skin(node)
	return node


static func skin(root: Node) -> void:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var source := instance.mesh.surface_get_material(surface)
			var key := source.resource_name if source != null else ""
			# Godot hängt bei doppelten Namen Ziffern an ("oak.001").
			key = key.get_slice(".", 0)
			instance.set_surface_override_material(surface, material(key))
		if instance.name in ["Bulb", "Flame"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Kontaktschatten-Material (weiches Alpha-Rechteck) für Karten und Steine.
static func shadow_material(strength: float = 0.5) -> StandardMaterial3D:
	var key := "contact_shadow_%.2f" % strength
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture("card_shadow")
	material.albedo_color = Color(0.02, 0.01, 0.03, strength)
	material.render_priority = -2
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials[key] = material
	return material
