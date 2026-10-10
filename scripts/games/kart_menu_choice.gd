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
var selected: bool = false
var margin: MarginContainer


func _ready() -> void:
	text = ""
	tooltip_text = title + ". " + caption
	margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var row := HBoxContainer.new()
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
	var icon_style := StyleBoxFlat.new()
	var mode_hues := {
		"Einzelrennen": Color("25d9ec"),
		"Zeitfahren": Color("2d91f2"),
		"Kristall-Arena": Color("b760ed"),
		"Sternen-Cup": Color("d2a643"),
		"Freies Training": Color("425b8a"),
	}
	icon_style.bg_color = mode_hues.get(title, Color("234d72"))
	icon_style.bg_color.a = 0.79
	icon_style.set_corner_radius_all(18)
	icon_style.set_content_margin_all(8)
	icon_plate.add_theme_stylebox_override("panel", icon_style)
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
	if selected:
		var check := Label.new()
		check.name = "SelectedCheck"
		check.text = "✓"
		check.add_theme_font_override("font", UI.HEADING)
		check.add_theme_font_size_override("font_size", 18)
		check.add_theme_color_override("font_color", Color("faffff"))
		check.add_theme_color_override("font_outline_color", Color("124d69"))
		check.add_theme_constant_override("outline_size", 4)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(check)
		check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		check.position = Vector2(-28, 4)
	if disabled:
		icon_view.modulate = Color(0.55, 0.65, 0.78)
		title_label.modulate = Color("96acc5")
	apply_size(1.0, false)


func apply_size(scale_factor: float, compact: bool, dense: bool = false) -> void:
	if not is_instance_valid(title_label):
		return
	var icon_size: float = (28.0 if compact else (38.0 if dense else 54.0)) * scale_factor
	var icon_style: StyleBoxFlat = icon_plate.get_theme_stylebox("panel").duplicate()
	icon_style.set_content_margin_all(5 if compact or dense else 8)
	icon_plate.add_theme_stylebox_override("panel", icon_style)
	icon_view.custom_minimum_size = Vector2.ONE * icon_size
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi(12 * scale_factor))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side, roundi((4 if compact or dense else 9) * scale_factor)
		)
	title_label.add_theme_font_size_override(
		"font_size", roundi((14 if compact else (18 if dense else 21)) * scale_factor)
	)
	caption_label.add_theme_font_size_override("font_size", roundi((11 if dense else 13) * scale_factor))
	caption_label.visible = not compact
