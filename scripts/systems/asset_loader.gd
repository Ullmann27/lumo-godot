## AssetLoader (Autoload als 'AssetLoader').
##
## ID-basiertes Laden via assets/manifests/assets.json. API:
##   AssetLoader.get_model(id)     -> Node3D (nie null, Magenta-Placeholder)
##   AssetLoader.get_texture(id)   -> Texture2D (nie null, weisse Fallback)
##   AssetLoader.get_material(id)  -> Material (kann null sein wenn id fehlt)
##   AssetLoader.has_asset(id)     -> bool ueber ALLE Kategorien
##
## Kategorien im Manifest (alle optional):
##   models, materials, textures, normal_maps, emission_maps, particles,
##   billboards, portals, sky, ui, masks, audio
##
## Garantien:
##   - get_model() gibt IMMER einen Node zurueck (nie null)
##   - get_texture() gibt IMMER eine Texture2D zurueck (nie null)
##   - bei fehlendem Asset wird ein auffaelliger Magenta-Placeholder geliefert
##     + Warning geloggt - kein Crash bei kaputtem JSON / fehlendem Manifest
extends Node

const MANIFEST_PATH: String = "res://assets/manifests/assets.json"

const TEXTURE_CATEGORIES: Array[String] = [
	"textures",
	"normal_maps",
	"emission_maps",
	"particles",
	"billboards",
	"portals",
	"sky",
	"ui",
	"masks",
]

var _models: Dictionary = {}
var _materials: Dictionary = {}
var _audio: Dictionary = {}
var _textures_by_category: Dictionary = {}  # category -> {id -> path}
var _texture_cache: Dictionary = {}  # id -> Texture2D
var _fallback_texture: Texture2D = null


func _ready() -> void:
	_load_manifest()
	var tex_count: int = 0
	for cat in _textures_by_category.keys():
		tex_count += _textures_by_category[cat].size()
	EventBus.asset_loader_ready.emit(_models.size())
	print(
		(
			"[AssetLoader] manifest loaded: %d models, %d materials, %d textures, %d audio"
			% [_models.size(), _materials.size(), tex_count, _audio.size()]
		)
	)


## Holt ein 3D-Modell per ID.
func get_model(id: String) -> Node3D:
	if not _models.has(id):
		push_warning("[AssetLoader] unbekannte model-id: %s" % id)
		return _make_placeholder(id)
	var path: String = _models[id]
	if not ResourceLoader.exists(path):
		push_warning("[AssetLoader] model %s nicht vorhanden (%s) - Placeholder" % [id, path])
		return _make_placeholder(id)
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_warning("[AssetLoader] %s kein PackedScene" % path)
		return _make_placeholder(id)
	var node: Node = packed.instantiate()
	if not (node is Node3D):
		push_warning("[AssetLoader] %s nicht Node3D" % path)
		return _make_placeholder(id)
	return node


func has_model(id: String) -> bool:
	if not _models.has(id):
		return false
	return ResourceLoader.exists(_models[id])


## Liefert ein Material per ID. NULL wenn ID nicht im Manifest.
func get_material(id: String) -> Material:
	if not _materials.has(id):
		push_warning("[AssetLoader] unbekannte material-id: %s" % id)
		return null
	var path: String = _materials[id]
	if not ResourceLoader.exists(path):
		push_warning("[AssetLoader] material %s nicht vorhanden (%s)" % [id, path])
		return null
	var mat: Resource = ResourceLoader.load(path)
	if not (mat is Material):
		push_warning("[AssetLoader] %s ist kein Material" % path)
		return null
	print("[AssetLoader] asset_material_loaded:%s" % id)
	return mat as Material


## Liefert eine Textur per ID. Durchsucht alle Texture-Kategorien.
## Niemals null - bei fehlender ID wird eine weisse 64x64 Fallback geliefert.
func get_texture(id: String) -> Texture2D:
	if _texture_cache.has(id):
		return _texture_cache[id]
	var path: String = _lookup_texture_path(id)
	if path.is_empty():
		push_warning("[AssetLoader] asset_texture_missing_using_placeholder:%s" % id)
		var fb: Texture2D = _get_fallback_texture()
		_texture_cache[id] = fb
		return fb
	if not ResourceLoader.exists(path):
		push_warning("[AssetLoader] asset_texture_missing_using_placeholder:%s (%s)" % [id, path])
		var fb2: Texture2D = _get_fallback_texture()
		_texture_cache[id] = fb2
		return fb2
	var tex: Resource = ResourceLoader.load(path)
	if not (tex is Texture2D):
		push_warning("[AssetLoader] %s ist keine Texture2D" % path)
		var fb3: Texture2D = _get_fallback_texture()
		_texture_cache[id] = fb3
		return fb3
	print("[AssetLoader] asset_texture_loaded:%s" % id)
	_texture_cache[id] = tex as Texture2D
	return tex as Texture2D


## Generisches has_asset ueber alle Kategorien.
func has_asset(id: String) -> bool:
	if _models.has(id) or _materials.has(id) or _audio.has(id):
		return true
	for cat in _textures_by_category.keys():
		if _textures_by_category[cat].has(id):
			return true
	return false


func _lookup_texture_path(id: String) -> String:
	for cat in _textures_by_category.keys():
		var map: Dictionary = _textures_by_category[cat]
		if map.has(id):
			return map[id]
	return ""


func _get_fallback_texture() -> Texture2D:
	if _fallback_texture != null:
		return _fallback_texture
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	# Magenta-Schachbrett damit fehlende Texturen sofort ins Auge fallen.
	for y in range(64):
		for x in range(64):
			var checker: bool = ((x >> 3) + (y >> 3)) & 1
			img.set_pixel(x, y, Color(1.0, 0.0, 0.85) if checker else Color(0.2, 0.0, 0.18))
	_fallback_texture = ImageTexture.create_from_image(img)
	return _fallback_texture


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("[AssetLoader] Manifest fehlt: %s" % MANIFEST_PATH)
		return
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("[AssetLoader] Manifest nicht lesbar")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[AssetLoader] Manifest kein JSON-Objekt")
		return
	_models = parsed.get("models", {})
	_materials = parsed.get("materials", {})
	_audio = parsed.get("audio", {})
	_textures_by_category.clear()
	for cat in TEXTURE_CATEGORIES:
		_textures_by_category[cat] = parsed.get(cat, {})


## Erzeugt einen sichtbaren Magenta-Box-Platzhalter mit ID-Label damit
## fehlende Assets im Tree als auffaellige Defekte sichtbar sind.
func _make_placeholder(id: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Placeholder_" + id
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.0, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.4
	mesh.material_override = mat
	root.add_child(mesh)
	var label: Label3D = Label3D.new()
	label.text = "missing: " + id
	label.position = Vector3(0, 0.45, 0)
	label.modulate = Color(1, 1, 1, 1)
	label.pixel_size = 0.003
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root
