extends Control
## Calm, readable race announcement: a glass pill behind the race message label.
## Added as a child of the message Label with show_behind_parent, so the label keeps its
## text, size and place in the layout (tests read message.text); this only draws the
## backing, sized to the actual line, and lets a new message settle in with a short,
## single scale-in (none with reduced motion). Warnings get a coral rim, good news gold.

const WARN_WORDS: Array[String] = ["Falsche", "trifft", "Achtung", "Rivale", "dreht sich", "Zu weit", "erwischt", "warn"]
const GOOD_WORDS: Array[String] = ["Turbo", "Boost", "geschafft", "Perfekt", "Super", "LOS", "Platz", "Ziel", "Treffer", "Rückenwind"]

var reduced_motion: bool = false
var _last_text: String = ""
var _settle: float = 0.0


func _init() -> void:
	name = "MessagePlate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var label: Label = get_parent() as Label
	if label == null:
		return
	if label.text != _last_text:
		_last_text = label.text
		_settle = 0.0 if reduced_motion or label.text.is_empty() else 1.0
		queue_redraw()
	if _settle > 0.0:
		_settle = maxf(0.0, _settle - delta / 0.22)
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2.ONE * (1.0 + 0.07 * _settle)
		queue_redraw()
	elif label.scale != Vector2.ONE:
		label.scale = Vector2.ONE


static func tone(text: String) -> Color:
	for word in WARN_WORDS:
		if word in text:
			return Color("ff7a6a")
	for word in GOOD_WORDS:
		if word in text:
			return Color("ffd23f")
	return Color("6fe6ff")


func _draw() -> void:
	var label: Label = get_parent() as Label
	if label == null or label.text.strip_edges().is_empty() or not label.visible:
		return
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var lines: int = maxi(1, mini(label.get_line_count(), label.get_visible_line_count()) if label.get_visible_line_count() > 0 else 1)
	var widest: float = 0.0
	if lines <= 1:
		widest = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	else:
		widest = label.size.x * 0.92
	var line_height: float = font.get_height(font_size)
	var pad := Vector2(font_size * 0.9, font_size * 0.28)
	var plate_size := Vector2(minf(label.size.x, widest + pad.x * 2.0), line_height * lines + pad.y * 2.0)
	var text_top: float = (label.size.y - line_height * lines) * 0.5
	var rect := Rect2(Vector2((label.size.x - plate_size.x) * 0.5, text_top - pad.y), plate_size)
	var rim: Color = tone(label.text)
	var radius: int = roundi(plate_size.y * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.15, 0.72)
	style.border_color = Color(rim, 0.9)
	style.set_border_width_all(maxi(2, roundi(font_size * 0.1)))
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(rim, 0.22)
	style.shadow_size = maxi(2, roundi(font_size * 0.35))
	style.anti_aliasing = true
	draw_style_box(style, rect)
