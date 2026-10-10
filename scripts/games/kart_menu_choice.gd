extends Button
## Native button with a separate title, caption and original icon. Children never
## intercept touch events; selection, disabled state and keyboard focus stay native.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
var title := ""
var caption := ""
var artwork: Texture2D
var title_label: Label
var caption_label: Label
var icon_view: TextureRect
var icon_plate: PanelContainer
var icon_style: StyleBoxFlat
var row: HBoxContainer
var margin: MarginContainer
var selected := false
var selection_mark: Label
var sheen: ColorRect
var sheen_material: ShaderMaterial


func _ready() -> void:
	text = ""
	tooltip_text = title + ". " + caption
	sheen = ColorRect.new()
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glass := Shader.new()
	glass.code = """
shader_type canvas_item;
uniform vec2 card_size = vec2(300.0, 72.0);
uniform float corner = 16.0;
void fragment() {
	vec2 q = abs((UV - 0.5) * card_size) - card_size * 0.5 + vec2(corner);
	float distance_to_edge = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float rounded_mask = 1.0 - smoothstep(-0.5, 0.5, distance_to_edge);
	float light = 0.15 * pow(1.0 - UV.y, 2.0) + 0.03 * (1.0 - UV.x);
	COLOR = vec4(0.78, 0.94, 1.0, light * rounded_mask);
}
"""
	sheen_material = ShaderMaterial.new()
	sheen_material.shader = glass
	sheen.material = sheen_material
	add_child(sheen)
	resized.connect(func(): sheen_material.set_shader_parameter("card_size", size))
	margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	icon_view = TextureRect.new()
	icon_view.texture = artwork
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_plate = PanelContainer.new()
	icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_style = StyleBoxFlat.new()
	var mode_hues := {
		"Einzelrennen": Color("25d9ec"),
		"Zeitfahren": Color("2d91f2"),
		"Kristall-Arena": Color("b760ed"),
		"Sternen-Cup": Color("d2a643"),
		"Freies Training": Color("425b8a"),
	}
	icon_style.bg_color = mode_hues.get(title, Color("234d72"))
	icon_style.bg_color.a = 0.64
	icon_style.border_color = Color(0.77, 0.95, 1.0, 0.3)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(12)
	icon_style.set_content_margin_all(8)
	icon_plate.add_theme_stylebox_override("panel", icon_style)
	icon_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_plate)
	icon_plate.add_child(icon_view)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UI.HEADING)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	caption_label = Label.new()
	caption_label.text = caption
	caption_label.add_theme_color_override("font_color", Color("e7f2ff"))
	caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_label)
	selection_mark = Label.new()
	selection_mark.name = "SelectedMode"
	selection_mark.text = "✓"
	selection_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_mark.add_theme_font_override("font", UI.HEADING)
	selection_mark.add_theme_color_override("font_color", Color("adffff"))
	selection_mark.add_theme_color_override("font_outline_color", Color("15536e"))
	selection_mark.add_theme_constant_override("outline_size", 3)
	var check_background := StyleBoxFlat.new()
	check_background.bg_color = Color("144667")
	check_background.border_color = Color("8affff")
	check_background.set_border_width_all(1)
	check_background.set_corner_radius_all(10)
	selection_mark.add_theme_stylebox_override("normal", check_background)
	selection_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	selection_mark.visible = selected
	add_child(selection_mark)
	if disabled:
		icon_view.modulate = Color(0.55, 0.65, 0.78)
		title_label.modulate = Color("96acc5")
	apply_size(1.0, false)


func apply_size(scale_factor: float, compact: bool, tight: bool = false) -> void:
	if not is_instance_valid(title_label):
		return
	# The icon+badge previously forced a ~90 px row even when the button was
	# 31–50 px high. Children then painted over the next mode. Size the
	# actual child controls rather than reducing only button.minimum_size.
	var icon_size: float = (30.0 if compact else (38.0 if tight else 51.0)) * scale_factor
	icon_view.custom_minimum_size = Vector2.ONE * icon_size
	icon_style.set_content_margin_all(roundi((2 if compact else (3 if tight else 6)) * scale_factor))
	row.add_theme_constant_override("separation", roundi((6 if compact else (8 if tight else 14)) * scale_factor))
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi((6 if compact else (8 if tight else 12)) * scale_factor))
	if selected:
		margin.add_theme_constant_override("margin_right", roundi(24 * scale_factor))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side, roundi((0 if compact else (2 if tight else 7)) * scale_factor)
		)
	title_label.add_theme_font_size_override(
		"font_size", roundi((16 if compact else (21 if tight else 24)) * scale_factor)
	)
	caption_label.add_theme_font_size_override("font_size", roundi((12 if tight else 13) * scale_factor))
	caption_label.visible = not compact
	selection_mark.add_theme_font_size_override("font_size", roundi(14 * scale_factor))
	selection_mark.offset_left = -23 * scale_factor
	selection_mark.offset_right = -5 * scale_factor
	selection_mark.offset_top = 4 * scale_factor
	selection_mark.offset_bottom = 23 * scale_factor
	sheen_material.set_shader_parameter("corner", 16 * scale_factor)
