extends SceneTree
## Gate for the rendered 3D UI kit (tools/art/render_ui_kit.py -> assets/kart/ui3d).
## The manifest is the contract for the menu code: every listed file must exist,
## import as a texture of the stated size, keep transparent corners and carry
## usable 9-slice margins. Files in the folder that the manifest forgets also fail.

const KIT_DIR := "res://assets/kart/ui3d"
const MANIFEST := KIT_DIR + "/ui_kit.json"
## Parts the Kart main menu draws (scripts/games/kart_neon_*.gd through kart_ui3d.gd).
const MENU_PARTS: Array[String] = [
	"plate_hero_amber", "plate_hero_violet", "plate_hero_teal", "plate_hero_magenta",
	"plate_feature_navy", "panel_glass_navy", "plate_nav", "plate_nav_active", "row_stat",
	"button_primary_gold", "button_primary_gold_pressed",
	"button_secondary_blue", "button_secondary_blue_pressed",
	"frame_neon_cyan", "frame_neon_amber", "bar_track", "bar_fill_gold", "bar_fill_cyan",
	"overlay_hero_streak", "overlay_glass_grid",
	"icon_flag", "icon_trophy", "icon_star_crystal", "icon_star_gold", "icon_calendar",
	"icon_wrench", "icon_gift", "icon_gear", "icon_home", "icon_route", "icon_stopwatch",
	"icon_lock", "icon_crown", "icon_back", "icon_play", "icon_rotate", "icon_chevrons",
	"icon_alert",
]

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
	if str(entry.get("kind", "")) == "overlay":
		_check_overlay(entry, file, image)
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
	if str(entry.get("kind", "")) == "plate":
		_check_plate_outline(entry, file, slice as Array)


## Light layers are drawn unstretched and clipped to the glass face of a plate: they need
## an anchor corner and must actually carry light.
func _check_overlay(entry: Dictionary, file: String, image: Image) -> void:
	if not (str(entry.get("anchor", "")) in ["top_right", "bottom_right"]):
		_fail("%s overlay needs anchor top_right or bottom_right" % file)
	var strongest := 0.0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			strongest = maxf(strongest, image.get_pixel(x, y).a)
	if strongest < 0.08:
		_fail("%s overlay is empty (strongest alpha %.3f)" % [file, strongest])


## The menu clips light layers and the focus ring to the glass face. For that the manifest
## states rim width, bottom lip and the four corner cuts; the fixed corners must lie
## inside the 9-slice margins.
func _check_plate_outline(entry: Dictionary, file: String, slice: Array) -> void:
	var pad: Variant = entry.get("glow_pad")
	if not (pad is Array) or (pad as Array).size() != 4:
		_fail("%s plate has no glow_pad [left, top, right, bottom]" % file)
		return
	if float(entry.get("rim", 0.0)) <= 0.0:
		_fail("%s plate has no rim width" % file)
	if float(entry.get("lip", -1.0)) < 0.0:
		_fail("%s plate has no lip (0 for none)" % file)
	var corners: Variant = entry.get("corners")
	if not (corners is Array) or (corners as Array).size() != 4:
		_fail("%s plate needs corners [bottom-left, bottom-right, top-right, top-left]" % file)
		return
	# manifest order -> the two 9-slice margins that have to contain that corner
	var sides := [[0, 3], [2, 3], [2, 1], [0, 1]]
	for index in 4:
		var corner: Variant = corners[index]
		if not (corner is Array) or (corner as Array).size() != 2 or not (str(corner[0]) in ["r", "c"]):
			_fail("%s corner %d must be ['r' | 'c', size]" % [file, index])
			continue
		for side: int in sides[index]:
			var needed := float(pad[side]) + float(corner[1])
			if needed > float(slice[side]):
				_fail(
					(
						"%s corner %d (%s px with glow) does not fit 9-slice margin %s"
						% [file, index, needed, slice[side]]
					)
				)


## The shared helper must hand out one cached object per part and report missing parts
## as `false`/null so that the menu falls back to its vector drawing.
func _check_helper() -> void:
	var kit: GDScript = load("res://scripts/games/kart_ui3d.gd")
	if kit.texture("icon_flag") == null or kit.texture("icon_flag") != kit.texture("icon_flag"):
		_fail("kart_ui3d.texture() must return the same cached texture")
	var box: StyleBoxTexture = kit.style_box("plate_hero_amber")
	if box == null or box != kit.style_box("plate_hero_amber"):
		_fail("kart_ui3d.style_box() must return the same cached StyleBoxTexture")
	elif box.texture_margin_left <= 0.0 or box.texture_margin_bottom <= 0.0:
		_fail("kart_ui3d.style_box() lost the 9-slice margins")
	if kit.themed("panel_glass_navy", 2.0) != kit.themed("panel_glass_navy", 2.0):
		_fail("kart_ui3d.themed() must reuse one StyleBox per plate and scale")
	if kit.texture("does_not_exist") != null or kit.style_box("does_not_exist") != null:
		_fail("kart_ui3d must return null for a part that is not in the kit")
	var outline: PackedVector2Array = kit.face_outline(
		"plate_hero_amber", Rect2(0, 0, 320, 200), 2.0
	)
	if outline.size() != 8:
		_fail("kart_ui3d.face_outline() must give eight points, got %d" % outline.size())
	var uvs: PackedVector2Array = kit.overlay_uvs("overlay_hero_streak", outline)
	if uvs.size() != outline.size():
		_fail("kart_ui3d.overlay_uvs() must give one UV per outline point")
	for uv in uvs:
		if uv.x < -0.001 or uv.x > 1.001 or uv.y < -0.001 or uv.y > 1.001:
			_fail("overlay UV %s leaves the texture (layer would smear)" % uv)
			break


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
	for part in MENU_PARTS:
		if not listed.has(part + ".webp"):
			_fail("%s.webp is used by the Kart main menu but not in the manifest" % part)
	_check_helper()
	if _failures.is_empty():
		print("[KartUi3dKit] PASS: %d assets" % assets.size())
		quit(0)
		return
	print("[KartUi3dKit] FAIL: %d problems in %d assets" % [_failures.size(), assets.size()])
	quit(1)
