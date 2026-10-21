extends RefCounted
## Lumo Next Gen: one shared, low-cost native Godot UI skin.
## Keeps the exact Nunito font files shared with the Flutter application.
const BODY = preload("res://assets/fonts/Nunito-Bold.ttf")
const HEADING = preload("res://assets/fonts/Nunito-Black.ttf")
const NIGHT := Color("03193f")
const NAVY := Color("061839")
const GLASS := Color("082851")
const CYAN := Color("53ddfd")
const GOLD := Color("ffc94a")
const WHITE := Color("f7fbff")
const MUTED := Color("b8c8df")


static func create() -> Theme:
	var result := Theme.new()
	result.default_font = BODY
	result.default_font_size = 22
	result.set_font("font", "Button", BODY)
	result.set_font("font", "Label", BODY)
	result.set_color("font_color", "Label", WHITE)
	result.set_color("font_color", "Button", WHITE)
	return result


## The same four corner radii, spacing and semantic accents serve the 3D hub
## and the Kart start flow. This is a real 9-patch-like StyleBox, not a screenshot.
static func premium_panel(accent: Color = CYAN, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.085, 0.20, 0.95)
	if selected:
		style.bg_color = Color(0.035, 0.19, 0.32, 0.97)
	style.border_color = accent if selected else accent.darkened(0.26)
	style.border_color.a = 0.95 if selected else 0.74
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.23 if selected else 0.12)
	style.shadow_size = 10 if selected else 5
	style.shadow_offset = Vector2(0, 3)
	return style


static func premium_button(button: Button, accent: Color = CYAN, gold_action: bool = false) -> void:
	button.theme = create()
	button.add_theme_font_override("font", HEADING)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 56.0)
	button.focus_mode = Control.FOCUS_ALL
	var normal := premium_panel(accent, false)
	if gold_action:
		normal.bg_color = GOLD
		normal.border_color = Color("fff5ba")
		normal.shadow_color = Color(1, 0.65, 0.12, 0.24)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("ffe678") if gold_action else Color("12476b")
	hover.border_color = Color("fff9d3") if gold_action else accent
	hover.shadow_size = 12
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.shadow_size = 3
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("26364b")
	disabled.border_color = Color("455971")
	button.add_theme_stylebox_override("disabled", disabled)
	var face := NAVY if gold_action else WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, face)
	button.add_theme_color_override("font_disabled_color", MUTED)
