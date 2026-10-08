extends Button
## Auswahlkarte für ein Kart: Vorschaubild, Name, Klasse, fünf Wertebalken und – wenn noch
## gesperrt – wie viele Fortschrittssterne fehlen. Kinder fassen den ganzen Button an, die
## Teile darauf fangen keine Tipps ab.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const BARS = preload("res://scripts/games/kart_stat_bars.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const THUMBNAIL: String = "res://assets/kart/fleet/%s.png"
var item: Dictionary = {}
var locked: bool = false
var missing_stars: int = 0
var tuning_level: int = 0
var stats: Dictionary = {}
var bonus: Dictionary = {}
var thumb: TextureRect
var title_label: Label
var role_label: Label
var lock_label: Label
var bars
var margin: MarginContainer
var badge: Label


func _init() -> void:
	# Skaliert sich selbst; die Garage soll Mindestgrößen hier nicht ein zweites Mal setzen.
	set_meta("kart_self_sized", true)


func _ready() -> void:
	text = ""
	tooltip_text = "%s · %s" % [item.name, item.role]
	margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	thumb = TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = THUMBNAIL % str(item.id)
	if ResourceLoader.exists(path):
		thumb.texture = load(path)
	row.add_child(thumb)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)
	title_label = Label.new()
	title_label.text = str(item.name)
	title_label.add_theme_font_override("font", UI.HEADING)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	role_label = Label.new()
	var tag_text: String = str(item.tag).to_lower()
	role_label.text = "%s · %s" % [str(item.role).to_upper(), tag_text.substr(0, 1).to_upper() + tag_text.substr(1)]
	role_label.add_theme_color_override("font_color", Color("74e5f5"))
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(role_label)
	bars = BARS.new()
	bars.show_labels = false
	bars.show_numbers = false
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(bars)
	bars.set_values(stats, bonus, true)
	lock_label = Label.new()
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_label.add_theme_color_override("font_color", Color("ffd06a"))
	lock_label.text = "Gesperrt · ab %d ★" % int(item.unlock) if missing_stars <= 0 else "Gesperrt · noch %d ★" % missing_stars
	lock_label.visible = locked
	column.add_child(lock_label)
	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_color_override("font_color", Color("ffd06a"))
	badge.visible = tuning_level > 0 and not locked
	badge.text = "Tuning %d" % tuning_level
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_top = 6
	badge.offset_right = -12
	add_child(badge)
	if locked:
		thumb.modulate = Color(0.34, 0.42, 0.55)
		title_label.modulate = Color("96acc5")
		bars.modulate = Color(1, 1, 1, 0.45)
	apply_size(1.0, false)


func apply_size(scale_factor: float, compact: bool) -> void:
	if not is_instance_valid(title_label):
		return
	var thumb_width: float = (86.0 if compact else 150.0) * scale_factor
	thumb.custom_minimum_size = Vector2(thumb_width, 0)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi(10 * scale_factor))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi((4 if compact else 8) * scale_factor))
	title_label.add_theme_font_size_override("font_size", roundi((15 if compact else 21) * scale_factor))
	role_label.add_theme_font_size_override("font_size", roundi((10 if compact else 12) * scale_factor))
	lock_label.add_theme_font_size_override("font_size", roundi((11 if compact else 13) * scale_factor))
	badge.add_theme_font_size_override("font_size", roundi(11 * scale_factor))
	bars.row_height = (7.0 if compact else 10.0) * scale_factor
	bars.visible = not compact or not locked
	role_label.visible = not compact
