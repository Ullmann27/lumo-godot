extends RefCounted
## Gerendertes 3D-UI-Kit (assets/kart/ui3d, gebaut von tools/art/render_ui_kit.py).
## Lädt das Manifest genau einmal, hält Texturen, 9-Slice-Ränder und StyleBoxen im Speicher
## und zeichnet Platten im richtigen Maßstab: Die Texturen sind doppelt für die
## 720er-Grundfläche gebaut, Godot kann StyleBoxTexture-Ränder aber nicht skalieren.
## Fehlt eine Datei, liefern die Zeichenfunktionen `false`; der Aufrufer zeichnet dann
## seinen Vektor-Ersatz.
const DIR := "res://assets/kart/ui3d/"
const MANIFEST := DIR + "ui_kit.json"
## Texturpixel je dp: design_scale 2 auf 720 px Breite = 360 dp.
const TEX_PER_DP := 4.0
const SCALED_BOX = preload("res://scripts/games/kart_ui3d_box.gd")

static var _loaded := false
static var _entries: Dictionary = {}
static var _textures: Dictionary = {}
static var _boxes: Dictionary = {}
static var _themed: Dictionary = {}
static var _rings: Dictionary = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (parsed is Dictionary) or not (parsed.get("assets") is Array):
		push_warning("Kart-UI-Kit: Manifest fehlt, Menü zeichnet den Vektor-Ersatz")
		return
	for entry: Variant in parsed["assets"]:
		if entry is Dictionary:
			_entries[str(entry.get("file", "")).get_basename()] = entry


static func has(name: String) -> bool:
	return texture(name) != null


static func entry(name: String) -> Dictionary:
	_load()
	return _entries.get(name, {})


## Textur mit Mipmaps (Icons werden bis auf ein Fünftel verkleinert). Einmal je Name.
static func texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	_load()
	var result: Texture2D = null
	var path := DIR + name + ".webp"
	if _entries.has(name) and ResourceLoader.exists(path, "Texture2D"):
		var source := load(path) as Texture2D
		if source != null:
			result = source
			var image := source.get_image()
			if image != null and not image.is_empty() and not image.is_compressed():
				image.generate_mipmaps()
				result = ImageTexture.create_from_image(image)
	_textures[name] = result
	return result


## StyleBoxTexture mit den 9-Slice-Rändern des Manifests (Ränder in Texturpixeln, unskaliert).
static func style_box(name: String) -> StyleBoxTexture:
	if _boxes.has(name):
		return _boxes[name]
	var box: StyleBoxTexture = null
	var tex := texture(name)
	var slice: Variant = entry(name).get("nine_slice")
	if tex != null and slice is Array and (slice as Array).size() == 4:
		box = StyleBoxTexture.new()
		box.texture = tex
		box.texture_margin_left = float(slice[0])
		box.texture_margin_top = float(slice[1])
		box.texture_margin_right = float(slice[2])
		box.texture_margin_bottom = float(slice[3])
	_boxes[name] = box
	return box


static func _pad(name: String) -> Array:
	var pad: Variant = entry(name).get("glow_pad")
	return pad if pad is Array and (pad as Array).size() == 4 else [0, 0, 0, 0]


## Maßstab Texturpixel -> Zeichenfläche. Kleiner als der Regelwert, wenn die Fläche sonst
## nicht für die festen Ecken reicht.
static func plate_scale(name: String, size: Vector2, k: float, fit_height: bool = false) -> float:
	var box := style_box(name)
	if box == null:
		return k / TEX_PER_DP
	var pad := _pad(name)
	if fit_height:
		# Balken und Schilder: die ganze Kappe wächst mit der Höhe, die Enden bleiben rund.
		return size.y / maxf(box.texture.get_height() - float(pad[1]) - float(pad[3]), 1.0)
	var min_w := box.texture_margin_left + box.texture_margin_right - float(pad[0]) - float(pad[2])
	var min_h := box.texture_margin_top + box.texture_margin_bottom - float(pad[1]) - float(pad[3])
	return minf(k / TEX_PER_DP, minf(size.x / maxf(min_w, 1.0), size.y / maxf(min_h, 1.0)))


## Zeichnet die Platte so, dass ihr fester Körper genau `rect` füllt; der Leuchtrand
## (glow_pad) liegt außerhalb. `false`, wenn die Textur fehlt.
static func draw_plate_rid(item: RID, name: String, rect: Rect2, k: float, tint: Color = Color.WHITE, fit_height: bool = false) -> bool:
	var box := style_box(name)
	if box == null or rect.size.x < 1.0 or rect.size.y < 1.0:
		return false
	var s := plate_scale(name, rect.size, k, fit_height)
	var pad := _pad(name)
	var origin := rect.position - Vector2(float(pad[0]), float(pad[1])) * s
	var full := rect.size / s + Vector2(float(pad[0]) + float(pad[2]), float(pad[1]) + float(pad[3]))
	RenderingServer.canvas_item_add_set_transform(item, Transform2D(Vector2(s, 0), Vector2(0, s), origin))
	RenderingServer.canvas_item_add_nine_patch(
		item,
		Rect2(Vector2.ZERO, full),
		Rect2(Vector2.ZERO, box.texture.get_size()),
		box.texture.get_rid(),
		Vector2(box.texture_margin_left, box.texture_margin_top),
		Vector2(box.texture_margin_right, box.texture_margin_bottom),
		RenderingServer.NINE_PATCH_STRETCH,
		RenderingServer.NINE_PATCH_STRETCH,
		true,
		tint
	)
	RenderingServer.canvas_item_add_set_transform(item, Transform2D.IDENTITY)
	return true


static func draw_plate(canvas: CanvasItem, name: String, rect: Rect2, k: float, tint: Color = Color.WHITE, fit_height: bool = false) -> bool:
	return draw_plate_rid(canvas.get_canvas_item(), name, rect, k, tint, fit_height)


## Fortschrittsbalken aus Rinne und Füllung; `false`, wenn das Kit fehlt.
static func draw_bar(canvas: CanvasItem, fill: String, rect: Rect2, ratio: float, k: float) -> bool:
	if not draw_plate(canvas, "bar_track", rect, k, Color.WHITE, true):
		return false
	if ratio > 0.0:
		var inner := rect.grow(-1.0 * k)
		inner.size.x = maxf(inner.size.y, inner.size.x * clampf(ratio, 0.0, 1.0))
		draw_plate(canvas, fill, inner, k, Color.WHITE, true)
	return true


## Umriss des Glasfelds einer Platte (im Uhrzeigersinn ab oben links), um `inset_dp`
## zusätzlich nach innen gesetzt. Für Lichtschichten und den Fokusring.
static func face_outline(name: String, rect: Rect2, k: float, inset_dp: float = 0.0) -> PackedVector2Array:
	var data := entry(name)
	var s := plate_scale(name, rect.size, k)
	var rim := float(data.get("rim", 0.0)) + 1.0
	var inset := rim * s + inset_dp * k
	var x0 := rect.position.x + inset
	var y0 := rect.position.y + inset
	var x1 := rect.end.x - inset
	var y1 := rect.end.y - float(data.get("lip", 0.0)) * s - inset
	var cuts: Array[float] = [0.0, 0.0, 0.0, 0.0]  # unten links, unten rechts, oben rechts, oben links
	var corners: Variant = data.get("corners")
	if corners is Array and (corners as Array).size() == 4:
		for index in 4:
			var corner: Array = corners[index]
			var amount := float(corner[1])
			if str(corner[0]) == "c":
				cuts[index] = maxf(0.0, amount * s - inset * 0.586)
			else:
				cuts[index] = maxf(0.0, amount * s - inset) * 0.586
	var limit := minf(x1 - x0, y1 - y0) * 0.5
	for index in 4:
		cuts[index] = minf(cuts[index], limit)
	return PackedVector2Array([
		Vector2(x0, y0 + cuts[3]), Vector2(x0 + cuts[3], y0),
		Vector2(x1 - cuts[2], y0), Vector2(x1, y0 + cuts[2]),
		Vector2(x1, y1 - cuts[1]), Vector2(x1 - cuts[1], y1),
		Vector2(x0 + cuts[0], y1), Vector2(x0, y1 - cuts[0]),
	])


## UV-Koordinaten, die eine Lichtschicht unverzerrt (deckend, am Anker des Manifests) über
## den Umriss legen.
static func overlay_uvs(name: String, outline: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	var tex := texture(name)
	if tex == null or outline.is_empty():
		return uvs
	var low := outline[0]
	var high := outline[0]
	for point in outline:
		low = low.min(point)
		high = high.max(point)
	var size := tex.get_size()
	var factor := maxf((high.x - low.x) / size.x, (high.y - low.y) / size.y)
	var drawn := size * factor
	var origin := Vector2(high.x - drawn.x, low.y)
	if str(entry(name).get("anchor", "top_right")) == "bottom_right":
		origin.y = high.y - drawn.y
	uvs.resize(outline.size())
	for index in outline.size():
		uvs[index] = (outline[index] - origin) / drawn
	return uvs


static func draw_overlay(canvas: CanvasItem, name: String, outline: PackedVector2Array, uvs: PackedVector2Array, tint: Color = Color.WHITE) -> bool:
	var tex := texture(name)
	if tex == null or outline.size() < 3 or uvs.size() != outline.size():
		return false
	canvas.draw_colored_polygon(outline, tint, uvs, tex)
	return true


## Icon mittig auf `centre`, Kantenlänge `size`. `flip` spiegelt waagerecht.
static func draw_icon(canvas: CanvasItem, name: String, centre: Vector2, size: float, tint: Color = Color.WHITE, flip: bool = false) -> bool:
	var tex := texture(name)
	if tex == null:
		return false
	var half := Vector2(size, size) * 0.5
	var rect := Rect2(centre - half, half * 2.0)
	if flip:
		rect.size.x = -size  # negative Breite spiegelt an Ort und Stelle
	canvas.draw_texture_rect(tex, rect, false, tint)
	return true


## StyleBox für gewöhnliche Buttons und Panels: zeichnet die Platte im dp-Maßstab `k`.
## Je Name und Maßstab genau eine Instanz.
static func themed(name: String, k: float, content_dp: Vector4 = Vector4(12, 8, 12, 8), tint: Color = Color.WHITE, backing: Color = Color(0, 0, 0, 0)) -> StyleBox:
	var key := "%s@%.3f/%s/%s/%s" % [name, k, content_dp, tint.to_html(), backing.to_html()]
	if _themed.has(key):
		return _themed[key]
	var box: StyleBox = null
	if style_box(name) != null:
		box = SCALED_BOX.new()
		box.kit = load("res://scripts/games/kart_ui3d.gd")
		box.plate = name
		box.ui_scale = k
		box.tint = tint
		box.backing = backing
		box.content_margin_left = content_dp.x * k
		box.content_margin_top = content_dp.y * k
		box.content_margin_right = content_dp.z * k
		box.content_margin_bottom = content_dp.w * k
	_themed[key] = box
	return box


## Weißer Fokusring als wiederverwendete StyleBox (ein Objekt je Radius und Strichstärke).
static func focus_ring(radius: int, width: int) -> StyleBoxFlat:
	var key := radius * 64 + width
	if _rings.has(key):
		return _rings[key]
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(1, 1, 1, 0.92)
	ring.set_border_width_all(maxi(1, width))
	ring.set_corner_radius_all(radius)
	ring.anti_aliasing = true
	_rings[key] = ring
	return ring
