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
	row.add_child(icon_view)
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
	caption_label.add_theme_color_override("font_color", Color("b9d1e5"))
	caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_label)
	if disabled:
		icon_view.modulate = Color(0.55, 0.65, 0.78)
		title_label.modulate = Color("96acc5")
	apply_size(1.0, false)


func apply_size(scale_factor: float, compact: bool) -> void:
	if not is_instance_valid(title_label):
		return
	var icon_size: float = (28.0 if compact else 54.0) * scale_factor
	icon_view.custom_minimum_size = Vector2.ONE * icon_size
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi(12 * scale_factor))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side, roundi((5 if compact else 9) * scale_factor)
		)
	title_label.add_theme_font_size_override(
		"font_size", roundi((14 if compact else 21) * scale_factor)
	)
	caption_label.add_theme_font_size_override("font_size", roundi(13 * scale_factor))
	caption_label.visible = not compact
