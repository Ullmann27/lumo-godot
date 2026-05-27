## AssetLoader (Autoload als 'AssetLoader').
##
## ID-basiertes Laden: `AssetLoader.get_model("lumo_fox")` statt hardcoded
## Pfade. Manifest in assets/manifests/assets.json definiert ID -> Pfad.
##
## Garantien:
##   - get_model() gibt IMMER einen Node zurueck (nie null)
##   - bei fehlendem Asset wird ein Magenta-Box-Placeholder mit Label
##     gerendert + Warning geloggt
##   - kein Crash bei kaputtem JSON / fehlendem Manifest
extends Node

const MANIFEST_PATH: String = "res://assets/manifests/assets.json"

var _models: Dictionary = {}
var _materials: Dictionary = {}
var _audio: Dictionary = {}


func _ready() -> void:
	_load_manifest()
	EventBus.asset_loader_ready.emit(_models.size())
	print(
		(
			"[AssetLoader] manifest loaded: %d models, %d materials, %d audio"
			% [_models.size(), _materials.size(), _audio.size()]
		)
	)


## Holt ein 3D-Modell per ID aus dem Manifest, instanziiert es.
## Faellt auf Magenta-Placeholder zurueck wenn ID unbekannt oder Asset fehlt.
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


## Liefert ein Material per ID (z.B. holographic_soft fuer Portal-Hover).
func get_material(id: String) -> Material:
	if not _materials.has(id):
		return null
	var path: String = _materials[id]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Material


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
