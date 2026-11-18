extends RefCounted
## Shared look of the Lumo-Lauf screens: night-blue glass panels, chunky buttons,
## the Nunito fonts of the app. All sizes are given in dp and scaled per device.

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const INK := Color("0b2247")
const GOLD := Color("ffd75e")
const CYAN := Color("53ddfd")
const WHITE := Color("f7fbff")
const MUTED := Color("c3d3ea")


## Viewport units per dp for the window a node lives in.
static func unit(node: Node) -> float:
	var view: Vector2 = node.get_viewport().get_visible_rect().size
	var window: Vector2 = Vector2(node.get_window().size)
	if window.x <= 0.0 or window.y <= 0.0:
		window = view
	var pixels_per_unit: float = maxf(0.1, minf(window.x / maxf(view.x, 1.0), window.y / maxf(view.y, 1.0)))
	return MobileRuntime.get_ui_density() / pixels_per_unit


## Safe-area margins in viewport units: x left, y top, z right, w bottom.
static func margins(node: Node, minimum_dp: float = 14.0) -> Vector4:
	var u: float = unit(node)
	var view: Vector2 = node.get_viewport().get_visible_rect().size
	var window: Vector2 = Vector2(node.get_window().size)
	if window.x <= 0.0 or window.y <= 0.0:
		window = view
	var pixels_per_unit: float = maxf(0.1, minf(window.x / maxf(view.x, 1.0), window.y / maxf(view.y, 1.0)))
	var insets: Rect2 = MobileRuntime.get_safe_area_insets()
	return Vector4(
		ceilf(maxf(minimum_dp * u, insets.position.x / pixels_per_unit)),
		ceilf(maxf(minimum_dp * u, insets.position.y / pixels_per_unit)),
		ceilf(maxf(minimum_dp * u, insets.size.x / pixels_per_unit)),
		ceilf(maxf(minimum_dp * u, insets.size.y / pixels_per_unit))
	)


static func label(text: String, size_dp: float, u: float, colour: Color = WHITE, heading: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", UI.HEADING if heading else UI.BODY)
	result.add_theme_font_size_override("font_size", roundi(size_dp * u))
	result.add_theme_color_override("font_color", colour)
	return result


static func panel(accent: Color, u: float, alpha: float = 0.94) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.09, 0.22, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	style.set_border_width_all(maxi(1, roundi(2.0 * u)))
	style.set_corner_radius_all(roundi(22.0 * u))
	style.set_content_margin_all(16.0 * u)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	style.shadow_size = roundi(10.0 * u)
	style.shadow_offset = Vector2(0, 3.0 * u)
	return style


## A chunky button: gold for the main action, glass for the others.
static func button(text: String, u: float, accent: Color = CYAN, primary: bool = false, height_dp: float = 56.0) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_ALL
	result.custom_minimum_size = Vector2(120.0, height_dp) * u
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.autowrap_mode = TextServer.AUTOWRAP_WORD
	result.add_theme_font_override("font", UI.HEADING)
	result.add_theme_font_size_override("font_size", roundi(19.0 * u))
	var face: Color = GOLD if primary else Color(0.05, 0.2, 0.38, 0.97)
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.border_color = Color("fff5ba") if primary else accent
	normal.set_border_width_all(maxi(1, roundi(2.0 * u)))
	normal.border_width_bottom = maxi(2, roundi(5.0 * u))
	normal.set_corner_radius_all(roundi(18.0 * u))
	normal.set_content_margin_all(10.0 * u)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = face.lightened(0.14)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = face.darkened(0.12)
	pressed.border_width_bottom = maxi(1, roundi(2.0 * u))
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.16, 0.22, 0.31, 0.9)
	disabled.border_color = Color(0.3, 0.37, 0.47)
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("focus", hover)
	result.add_theme_stylebox_override("pressed", pressed)
	result.add_theme_stylebox_override("disabled", disabled)
	var ink: Color = INK if primary else WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, ink)
	result.add_theme_color_override("font_disabled_color", MUTED)
	return result


static func clock(milliseconds: int) -> String:
	var seconds: int = maxi(0, milliseconds) / 1000
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func star_points(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var angle: float = -PI * 0.5 + float(index) * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * (radius if index % 2 == 0 else radius * 0.46))
	return points
