extends RefCounted
## Shared LUMO Bauwelt HUD look for the free build world and the village.
## Buttons read as physical, pressable tiles: a lighter top edge, a thick
## darker base that collapses on press, a calm hover lift and a clearly
## desaturated disabled state. Every touch target keeps at least 48 px.

const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const ICON = preload("res://scripts/creative/build_hud_icon.gd")
const MIN_TOUCH := 48.0
const INK := Color("173546")
const INK_LIGHT := Color("f6fcff")
const BAR := Color(0.035, 0.15, 0.23, 0.9)
const BAR_EDGE := Color("64d7c8")

## Face colour, base (depth) colour and text colour per variant.
const VARIANTS := {
	"cream": [Color("fbf4e2"), Color("b9a37a"), Color("183d4c")],
	"primary": [Color("ffd25a"), Color("c8861d"), Color("3b2600")],
	"teal": [Color("6fe0cf"), Color("2b8f86"), Color("08323a")],
	"sky": [Color("9fdcff"), Color("4a8fc4"), Color("0d2e47")],
	"rose": [Color("ffb3c1"), Color("c4627a"), Color("4a1020")],
	"leaf": [Color("b6ec8c"), Color("5f9e3c"), Color("1d3a0c")],
	"dark": [Color("1f4a5e"), Color("0b2230"), Color("eaf8ff")],
}


static func face(variant: String) -> Color:
	return VARIANTS.get(variant, VARIANTS.cream)[0]


static func _tile(fill: Color, base: Color, depth: int, lift: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = base
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = depth
	style.border_blend = false
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6 + lift
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	return style


## Apply the tile look to any existing Button without touching its signals.
static func style_button(button: Button, variant: String = "cream", font_size: int = 16) -> void:
	var colors: Array = VARIANTS.get(variant, VARIANTS.cream)
	var fill: Color = colors[0]
	var base: Color = colors[1]
	var text: Color = colors[2]
	button.add_theme_stylebox_override("normal", _tile(fill, base, 6, 0))
	button.add_theme_stylebox_override("hover", _tile(fill.lightened(0.12), base, 7, 0))
	button.add_theme_stylebox_override("pressed", _tile(fill.darkened(0.08), base, 2, 4))
	button.add_theme_stylebox_override("hover_pressed", _tile(fill.darkened(0.04), base, 2, 4))
	var disabled := _tile(fill.lerp(Color("c9d1cf"), 0.72), base.lerp(Color("8d9895"), 0.7), 3, 3)
	button.add_theme_stylebox_override("disabled", disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("ffffff")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(16)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["", "hover_", "pressed_", "hover_pressed_", "focus_"]:
		button.add_theme_color_override("font_" + state + "color", text)
	button.add_theme_color_override("font_disabled_color", text.lerp(Color("6d7a78"), 0.6))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, MIN_TOUCH)


static func button(
	text: String, action: Callable, width: float = 82, variant: String = "cream"
) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(maxf(width, MIN_TOUCH), MIN_TOUCH)
	control.focus_mode = Control.FOCUS_NONE
	style_button(control, variant)
	control.pressed.connect(action)
	return control


## Light parchment card for dialogs and the assignment panel.
static func card() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 0.87, 0.96)
	style.border_color = Color("d8c08c")
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.set_corner_radius_all(18)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0.03, 0.1, 0.12, 0.3)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


## Dark translucent HUD bar (top resources, bottom action dock).
static func bar() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BAR
	style.border_color = BAR_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0.01, 0.06, 0.1, 0.38)
	style.shadow_size = 8
	return style


static func label(text: String, size: int = 16, color: Color = INK) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_override("font", FONT)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override(
		"font_shadow_color", Color(0, 0, 0, 0.35) if color.get_luminance() > 0.6 else Color(1, 1, 1, 0.4)
	)
	control.add_theme_constant_override("shadow_offset_y", 1)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


## Resource chip: round icon plus bold value on a dark capsule.
## Returns the chip; its value label is stored as metadata "value".
static func chip(icon: String, tint: Color, caption: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Chip_" + icon
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.09, 0.14, 0.72)
	style.border_color = tint.darkened(0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 4
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(ICON.rect(icon, tint, 30.0))
	var value := label(caption, 16, INK_LIGHT)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	panel.set_meta("value", value)
	panel.tooltip_text = caption
	return panel


static func set_chip(chip_panel: PanelContainer, caption: String, tooltip: String = "") -> void:
	var value: Label = chip_panel.get_meta("value")
	if value.text != caption:
		value.text = caption
	chip_panel.tooltip_text = tooltip if not tooltip.is_empty() else caption
