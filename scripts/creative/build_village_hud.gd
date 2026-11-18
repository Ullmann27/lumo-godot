extends RefCounted
## Spiel-HUD der Dorfwelt im Lumo-Stil (baut auf build_hud_style.gd auf):
## weiche Glas- und Holztafeln, gezeichnete Rohstoffsymbole mit großen Zahlen,
## Gebäudekarten mit echtem Modellbild, Fortschrittsbalken. Jede Bedienfläche
## ist mindestens 48 dp groß. Zeigt nur Zahlen, die der Aufrufer übergibt.
const HUD = preload("res://scripts/creative/build_hud_style.gd")
const FONT = preload("res://assets/fonts/Nunito-Black.ttf")
const UI := "res://assets/creative/village3d/ui/"
const ICONS := {
	"wood": "res_wood", "stone": "res_stone", "food": "res_food", "coins": "res_coins",
	"population": "res_people", "plots": "res_plots", "day": "res_day", "treasury": "res_treasury",
	"happiness": "res_happy", "water": "res_water", "grain": "res_grain",
}
const INK_LIGHT := Color("f7fbff")
const GOLD := Color("ffd25a")


static func texture(name: String) -> Texture2D:
	var path := UI + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


static func panel(kind := "glass", margin := 10) -> StyleBox:
	var art := texture("panel_" + kind)
	if art == null:
		return HUD.bar() if kind != "parchment" else HUD.card()
	var style := StyleBoxTexture.new()
	style.texture = art
	style.texture_margin_left = 26
	style.texture_margin_right = 26
	style.texture_margin_top = 26
	style.texture_margin_bottom = 26
	style.content_margin_left = margin + 4
	style.content_margin_right = margin + 4
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


static func label(text: String, size := 16, color := INK_LIGHT) -> Label:
	var control := HUD.label(text, size, color)
	control.add_theme_color_override("font_outline_color", Color(0.03, 0.1, 0.14, 0.85))
	control.add_theme_constant_override("outline_size", 4 if color.get_luminance() > 0.5 else 0)
	return control


## Rohstoff: gezeichnetes Symbol + große Zahl auf einer Glaskapsel.
## Kompatibel mit HUD.set_chip (Metadaten "value").
static func chip(resource: String) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.name = "Chip_" + resource
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := panel("chip", 2)
	if style is StyleBoxTexture:
		style.content_margin_left = 6
		style.content_margin_right = 14
	holder.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture(ICONS.get(resource, "res_plots"))
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var value := label("", 21)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	holder.set_meta("value", value)
	holder.set_meta("icon", icon)
	return holder


static func button(text: String, action: Callable, width := 110.0, variant := "cream", size := 15) -> Button:
	var control := HUD.button(text, action, width, variant)
	control.add_theme_font_size_override("font_size", size)
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 50.0)
	return control


## Rund und kompakt für die Kamera-Leiste.
static func round_button(text: String, action: Callable, tooltip: String) -> Button:
	var control := HUD.button(text, action, 52.0, "dark")
	control.custom_minimum_size = Vector2(52, 52)
	control.add_theme_font_size_override("font_size", 22)
	control.tooltip_text = tooltip
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := control.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style != null:
			style.set_corner_radius_all(26)
			style.bg_color.a = 0.86
			control.add_theme_stylebox_override(state, style)
	return control


## Gebäudekarte: echtes Modellbild links, Name und Kosten rechts.
static func building_card(kind: String, text: String, action: Callable) -> Button:
	var card := HUD.button(text, action, 218.0, "cream")
	card.name = "BuildCard_" + kind
	card.custom_minimum_size = Vector2(218, 86)
	card.add_theme_font_size_override("font_size", 15)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.icon = texture("bld_" + kind)
	card.expand_icon = true
	card.add_theme_constant_override("icon_max_width", 80)
	card.add_theme_constant_override("h_separation", 8)
	card.clip_text = false
	return card


## Fortschrittszeile: Name, Balken, „2/3“. Gibt die Zeile zurück.
static func progress_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := label("", 14)
	caption.custom_minimum_size.x = 120
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(caption)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.02, 0.08, 0.12, 0.7)
	back.set_corner_radius_all(7)
	back.border_color = Color(1, 1, 1, 0.18)
	back.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(7)
	fill.border_color = Color("fff1b0")
	fill.border_width_top = 2
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var count := label("", 14, GOLD)
	count.custom_minimum_size.x = 44
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count)
	row.set_meta("caption", caption)
	row.set_meta("bar", bar)
	row.set_meta("count", count)
	return row


static func set_progress(row: HBoxContainer, title: String, current: int, target: int) -> void:
	(row.get_meta("caption") as Label).text = title
	var bar: ProgressBar = row.get_meta("bar")
	bar.max_value = maxi(1, target)
	bar.value = clampi(current, 0, maxi(1, target))
	var done := current >= target
	(row.get_meta("count") as Label).text = ("✓ " if done else "") + "%d/%d" % [current, target]
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
	fill.bg_color = Color("8fe07a") if done else GOLD
