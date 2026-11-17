extends SceneTree
## Gate for the rendered 3D UI kit (tools/art/render_ui_kit.py -> assets/kart/ui3d).
## The manifest is the contract for the menu code: every listed file must exist,
## import as a texture of the stated size, keep transparent corners and carry
## usable 9-slice margins. Files in the folder that the manifest forgets also fail.

const KIT_DIR := "res://assets/kart/ui3d"
const MANIFEST := KIT_DIR + "/ui_kit.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	_failures.append(message)
	print("[KartUi3dKit] FAIL: %s" % message)


func _check_asset(entry: Dictionary) -> void:
	var file := str(entry.get("file", ""))
	var path := KIT_DIR.path_join(file)
	if file.is_empty() or not FileAccess.file_exists(path):
		_fail("%s is listed but missing" % file)
		return
	if str(entry.get("use", "")).strip_edges().is_empty():
		_fail("%s has no intended use" % file)
	var size: Array = entry.get("size", [])
	if size.size() != 2:
		_fail("%s has no [width, height] size" % file)
		return
	var texture := load(path) as Texture2D
	if texture == null:
		_fail("%s does not load as a texture" % file)
		return
	var width := int(size[0])
	var height := int(size[1])
	if texture.get_width() != width or texture.get_height() != height:
		_fail(
			(
				"%s is %dx%d, manifest says %dx%d"
				% [file, texture.get_width(), texture.get_height(), width, height]
			)
		)
	var image := texture.get_image()
	if image == null or image.is_empty():
		_fail("%s gives no pixel data" % file)
		return
	if image.is_compressed():
		image.decompress()
	for corner: Vector2i in [
		Vector2i(0, 0),
		Vector2i(width - 1, 0),
		Vector2i(0, height - 1),
		Vector2i(width - 1, height - 1)
	]:
		var alpha := image.get_pixelv(corner).a
		if alpha > 0.0:
			_fail("%s corner %s is not transparent (alpha %.3f)" % [file, corner, alpha])
	var slice: Variant = entry.get("nine_slice")
	if slice == null:
		return
	if not (slice is Array) or (slice as Array).size() != 4:
		_fail("%s nine_slice must be [left, top, right, bottom] or null" % file)
		return
	var limits: Array[float] = [width * 0.5, height * 0.5, width * 0.5, height * 0.5]
	for index in 4:
		var margin := float(slice[index])
		if margin <= 0.0 or margin >= limits[index]:
			_fail(
				(
					"%s nine_slice[%d] = %s must be > 0 and < %s"
					% [file, index, margin, limits[index]]
				)
			)


func _run() -> void:
	var text := FileAccess.get_file_as_string(MANIFEST)
	var manifest: Variant = JSON.parse_string(text)
	if not (manifest is Dictionary) or not (manifest.get("assets") is Array):
		_fail("%s is missing or has no assets list" % MANIFEST)
		quit(1)
		return
	var assets: Array = manifest["assets"]
	var listed: Dictionary = {}
	for entry: Variant in assets:
		if not (entry is Dictionary):
			_fail("manifest entry is not an object: %s" % str(entry))
			continue
		listed[str(entry.get("file", ""))] = true
		_check_asset(entry)
	for file in DirAccess.get_files_at(KIT_DIR):
		if file.get_extension() == "webp" and not listed.has(file):
			_fail("%s is in the folder but not in the manifest" % file)
	if assets.is_empty():
		_fail("manifest lists no assets")
	if _failures.is_empty():
		print("[KartUi3dKit] PASS: %d assets" % assets.size())
		quit(0)
		return
	print("[KartUi3dKit] FAIL: %d problems in %d assets" % [_failures.size(), assets.size()])
	quit(1)
