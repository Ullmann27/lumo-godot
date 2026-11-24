extends RefCounted
## Bausteine der Kartentisch-Oberfläche im Lumo-Stil (Navy, Cyan, Gold).
## Nutzt das gerenderte 3D-UI-Kit unter assets/kart/ui3d als 9-Slice.
## Alle Maße sind dp; `scale` ist die Bildschirmdichte.

const THEME = preload("res://scripts/games/kart_ui_theme.gd")
const KIT_DIR := "res://assets/kart/ui3d/"
const NAVY := Color("061839")
const CYAN := Color("53ddfd")
const GOLD := Color("ffc94a")
const WHITE := Color("f7fbff")
const MUTED := Color("b8c8df")

static var _kit: Dictionary = {}
static var _boxes: Dictionary = {}
static var _textures: Dictionary = {}


static func _entry(file: String) -> Dictionary:
	if _kit.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KIT_DIR + "ui_kit.json"))
		if parsed is Dictionary:
			for asset: Dictionary in parsed.get("assets", []):
				_kit[str(asset.file)] = asset
	return _kit.get(file, {})


## 9-Slice-Fläche aus dem Kit, passend zur Dichte verkleinert. Der Leuchtrand
## ragt über das Steuerelement hinaus, der feste Körper füllt es genau.
static func slice(file: String, scale: float, margin: float = 12.0) -> StyleBox:
	var key := "%s@%.3f/%.1f" % [file, scale, margin]
	if _boxes.has(key):
		return _boxes[key]
	var entry := _entry(file)
	var source: Texture2D = load(KIT_DIR + file) if ResourceLoader.exists(KIT_DIR + file) else null
	if entry.is_empty() or source == null or entry.get("nine_slice") == null:
		var flat := THEME.premium_panel(CYAN, false)
		flat.set_content_margin_all(margin * scale)
		_boxes[key] = flat
		return flat
	var factor := scale / float(_kit_scale())
	var image := source.get_image()
	if image.is_compressed():
		image.decompress()
	var width := maxi(8, int(roundf(image.get_width() * factor)))
	var height := maxi(8, int(roundf(image.get_height() * factor)))
	image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	var cut: Array = entry.nine_slice
	var pad: Array = entry.get("glow_pad", [0, 0, 0, 0])
	var sides := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	for index in range(4):
		box.set_texture_margin(sides[index], floorf(float(cut[index]) * factor))
		box.set_expand_margin(sides[index], float(pad[index]) * factor)
		box.set_content_margin(sides[index], margin * scale)
	_boxes[key] = box
	return box


static func _kit_scale() -> float:
	_entry("")
	return 2.0


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


static func label(text: String, size: float, scale: float, color: Color = WHITE, heading: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", THEME.HEADING if heading else THEME.BODY)
	node.add_theme_font_size_override("font_size", maxi(8, int(roundf(size * scale))))
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.0, 0.03, 0.12, 0.75))
	node.add_theme_constant_override("shadow_offset_y", maxi(1, int(scale)))
	node.add_theme_constant_override("shadow_outline_size", maxi(1, int(2 * scale)))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func wrapped(text: String, size: float, scale: float, color: Color = WHITE) -> Label:
	var node := label(text, size, scale, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func surface(face: Color, edge: Color, scale: float, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = edge
	box.set_border_width_all(maxi(1, roundi(scale)))
	box.set_corner_radius_all(roundi(13.0 * scale))
	box.set_content_margin_all(margin * scale)
	box.shadow_color = Color(0.02, 0.05, 0.09, 0.33)
	box.shadow_size = roundi(3.0 * scale)
	box.shadow_offset = Vector2(0, 2.0 * scale)
	return box


## Glänzender Knopf: "gold" für die Hauptaktion, "blue" für alles andere.
static func button(text: String, kind: String, scale: float, min_width: float = 56.0, font: float = 20.0) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size = Vector2(min_width, 56.0) * scale
	node.add_theme_font_override("font", THEME.HEADING)
	node.add_theme_font_size_override("font_size", int(roundf(font * scale)))
	var gold := kind == "gold"
	var fill := Color("f3c76a") if gold else Color("23434d")
	var edge := Color("ffe3a3") if gold else Color("6f989b")
	var normal := surface(fill, edge, scale, 10.0)
	var pressed := surface(fill.darkened(.18), edge, scale, 10.0)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", surface(fill.lightened(.09), edge, scale, 10.0))
	node.add_theme_stylebox_override("focus", surface(fill, Color.WHITE, scale, 10.0))
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", pressed)
	var face := Color("3a2400") if gold else WHITE
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, face)
	node.add_theme_color_override("font_disabled_color", Color(face, 0.45))
	return node


## Umschalter für Auswahlreihen (Mitspieler, Stärke, Runden).
static func choice(text: String, selected: bool, scale: float, min_width: float = 64.0) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_ALL
	node.toggle_mode = false
	node.custom_minimum_size = Vector2(min_width, 52.0) * scale
	node.add_theme_font_override("font", THEME.HEADING)
	node.add_theme_font_size_override("font_size", int(roundf(17 * scale)))
	var box := surface(Color("f3c76a") if selected else Color("294653"), Color("f4db9f") if selected else Color("64818a"), scale, 7.0)
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, box)
	# Gewählt: dunkle Schrift auf der goldenen Fläche, sonst weiß auf Blau – gut lesbar.
	var face := Color("2a1600") if selected else WHITE
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, face)
	if selected:
		node.add_theme_color_override("font_outline_color", Color(1.0, 0.93, 0.6, 0.6))
		node.add_theme_constant_override("outline_size", int(roundf(2 * scale)))
	return node


static func panel(file: String, scale: float, margin: float = 16.0) -> PanelContainer:
	var node := PanelContainer.new()
	if file == "panel_glass_navy.webp" or file == "row_stat.webp":
		node.add_theme_stylebox_override("panel", surface(Color("192f3df7"), Color("567783"), scale, margin))
	else:
		node.add_theme_stylebox_override("panel", slice(file, scale, margin))
	return node


static func picture(path: String, size: float, scale: float) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(size, size) * scale
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func spacer(height: float, scale: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height * scale)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
