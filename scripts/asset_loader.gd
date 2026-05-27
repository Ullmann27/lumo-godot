## Procedural Asset Loader.
##
## Scannt beim Start `res://assets/models/` nach .glb-Dateien und
## instanziiert sie als Kinder dieses Knotens. Keine Hardcoding -
## neue Modelle die der KI-Asset-Pipeline (`tools/fetch_assets.py`)
## abgelegt werden, erscheinen beim naechsten App-Start automatisch.
##
## Layout: instanziierte Modelle werden horizontal verteilt (X-Achse).
class_name AssetLoader
extends Node3D

## Quell-Ordner mit .glb / .gltf Dateien.
@export var models_dir: String = "res://assets/models/"

## Abstand zwischen instanziierten Modellen auf der X-Achse.
@export var spacing_x: float = 2.5


func _ready() -> void:
	var loaded: int = await _scan_and_load()
	EventBus.assets_load_complete.emit(loaded)
	print("[AssetLoader] %d Modelle aus %s geladen" % [loaded, models_dir])


func _scan_and_load() -> int:
	var dir: DirAccess = DirAccess.open(models_dir)
	if dir == null:
		push_warning("[AssetLoader] %s nicht lesbar" % models_dir)
		return 0
	dir.list_dir_begin()
	var index: int = 0
	while true:
		var fname: String = dir.get_next()
		if fname == "":
			break
		if dir.current_is_dir():
			continue
		if not (fname.ends_with(".glb") or fname.ends_with(".gltf")):
			continue
		var full_path: String = models_dir.path_join(fname)
		var instance: Node = _instance_model(full_path)
		if instance == null:
			continue
		instance.position = Vector3((float(index) - 0.5) * spacing_x, 0.0, 0.0)
		add_child(instance)
		EventBus.asset_instanced.emit(full_path, instance)
		index += 1
	dir.list_dir_end()
	return index


func _instance_model(path: String) -> Node:
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		var doc: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		var err: Error = doc.append_from_file(path, state)
		if err != OK:
			push_warning("[AssetLoader] %s nicht ladbar (Error %d)" % [path, err])
			return null
		return doc.generate_scene(state)
	return null
