extends "res://scripts/games/kart_menu_choice.gd"
## Bebilderte Streckenkarte der Streckenwahl: eigenes Motiv aus der Welt, Name und
## Fortschritt („1 von 3 Zielen“). Gewählt = heller Rahmen und Fähnchen „✓ Gewählt“.
## Erbt von der Menükarte, damit vorhandene Abläufe (Titel, caption_label) gleich bleiben.
const STAGE_DIR := "res://assets/kart/track_stage/"
const FALLBACK_DIR := "res://assets/kart/neon_previews/"
var track_id := ""
var accent := Color("53ddfd")
var achieved := 0
var locked_text := ""
var tall := true
var picture: TextureRect
var picture_frame: PanelContainer
var name_label: Label
var progress_label: Label
var pips: Control
var badge: Label
var _content: BoxContainer
var _text_column: VBoxContainer
var _ui_scale := 1.0


static func thumbnail_path(id: String) -> String:
	var own := STAGE_DIR + "cards/" + id + ".webp"
	if ResourceLoader.exists(own):
		return own
	return FALLBACK_DIR + id + ".webp"


func _init() -> void:
	super._init()
	set_meta("kart_self_sized", true)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	text = ""
	name = "TrackCard_" + track_id
	tooltip_text = title
	margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	_content = BoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_content)
	picture_frame = PanelContainer.new()
	picture_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture_frame.clip_contents = true
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("0b2149")
	frame_style.set_corner_radius_all(14)
	picture_frame.add_theme_stylebox_override("panel", frame_style)
	_content.add_child(picture_frame)
	picture = TextureRect.new()
	picture.name = "TrackPicture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := thumbnail_path(track_id)
	if ResourceLoader.exists(path):
		picture.texture = load(path)
	picture_frame.add_child(picture)
	badge = Label.new()
	badge.name = "SelectedTrack"
	badge.text = "✓ Gewählt"
	badge.add_theme_font_override("font", UI.HEADING)
	badge.add_theme_color_override("font_color", Color("04243b"))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("bff8ff")
	badge_style.set_corner_radius_all(40)
	badge_style.corner_radius_top_left = 0
	badge_style.corner_radius_bottom_left = 0
	badge_style.shadow_color = Color(0, 0.05, 0.12, 0.5)
	badge_style.shadow_size = 6
	badge.add_theme_stylebox_override("normal", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture_frame.add_child(badge)
	_text_column = VBoxContainer.new()
	_text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_text_column)
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UI.HEADING)
	title_label.add_theme_color_override("font_color", UI.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color("041330"))
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_column.add_child(title_label)
	var progress_row := HBoxContainer.new()
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_column.add_child(progress_row)
	pips = Control.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(_draw_pips)
	progress_row.add_child(pips)
	progress_label = Label.new()
	progress_label.add_theme_font_override("font", UI.BODY)
	progress_label.add_theme_color_override("font_color", Color("d9ecff"))
	progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_row.add_child(progress_label)
	# Vorhandene Abläufe schreiben die Zielzeile in caption_label; sie bleibt als
	# Tooltip-/Prüftext erhalten, sichtbar ist die klare Fortschrittszeile.
	caption_label = Label.new()
	caption_label.text = caption
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.self_modulate.a = 0.0
	caption_label.custom_minimum_size = Vector2.ZERO
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	caption_label.size = Vector2(1, 1)
	caption_label.clip_text = true
	add_child(caption_label)
	refresh_state()
	apply_size(_ui_scale, false)


## Auswahl, Fortschritt und Sperre aus den echten Daten übernehmen.
func refresh_state() -> void:
	if not is_instance_valid(title_label):
		return
	title_label.text = title
	if not locked_text.is_empty():
		progress_label.text = locked_text
	else:
		progress_label.text = "%d von 3 Zielen" % clampi(achieved, 0, 3)
	badge.visible = selected
	picture.modulate = Color(0.45, 0.52, 0.62) if disabled else Color.WHITE
	title_label.modulate = Color("96acc5") if disabled else Color.WHITE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, _style(state))
	pips.queue_redraw()


func _style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var lit := selected or state in ["hover", "pressed", "focus"]
	style.bg_color = Color(0.05, 0.16, 0.33, 0.97) if selected else Color(0.03, 0.09, 0.2, 0.93)
	if state == "disabled":
		style.bg_color = Color(0.03, 0.06, 0.12, 0.9)
	var edge := Color("bff8ff") if selected else Color(accent, 0.55 if lit else 0.3)
	style.border_color = edge
	style.set_border_width_all(roundi((5 if selected else 2) * _ui_scale))
	style.set_corner_radius_all(roundi(20 * _ui_scale))
	style.shadow_color = Color(accent, 0.5) if selected else Color(0, 0.02, 0.06, 0.45)
	style.shadow_size = roundi((14 if selected else 6) * _ui_scale)
	style.shadow_offset = Vector2(0, 0 if selected else 4 * _ui_scale)
	return style


## tall: Bild oben, Text darunter (Hochformat-Leiste). Sonst Bild links (Querformat-Liste).
func set_tall(value: bool) -> void:
	tall = value
	if is_instance_valid(_content):
		_content.vertical = tall


func apply_size(scale_factor: float, _compact: bool = false, _tight: bool = false) -> void:
	_ui_scale = scale_factor
	if not is_instance_valid(title_label):
		return
	_content.vertical = tall
	_content.add_theme_constant_override("separation", roundi((8 if tall else 12) * scale_factor))
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(8 * scale_factor))
	var inner := custom_minimum_size - Vector2.ONE * 16 * scale_factor
	if tall:
		var picture_height := maxf(0.0, inner.y - 64 * scale_factor)
		picture_frame.custom_minimum_size = Vector2(0, picture_height)
		picture_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture_frame.size_flags_horizontal = Control.SIZE_FILL
	else:
		picture_frame.custom_minimum_size = Vector2(
			minf(inner.y * 16.0 / 9.0, inner.x * 0.4), inner.y
		)
		picture_frame.size_flags_vertical = Control.SIZE_FILL
		picture_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	(picture_frame.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(
		roundi(14 * scale_factor)
	)
	# Lange Namen („Candy Cloud Circuit“) brechen in der schmalen Querformat-Liste um.
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF if tall else TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 1 if tall else 2
	title_label.add_theme_font_size_override(
		"font_size", roundi((22 if tall else 20) * scale_factor)
	)
	title_label.add_theme_constant_override("outline_size", roundi(2 * scale_factor))
	progress_label.add_theme_font_size_override("font_size", roundi(16 * scale_factor))
	pips.custom_minimum_size = Vector2(52, 20) * scale_factor
	badge.add_theme_font_size_override("font_size", roundi(15 * scale_factor))
	var badge_style := badge.get_theme_stylebox("normal") as StyleBoxFlat
	badge_style.content_margin_left = 10 * scale_factor
	badge_style.content_margin_right = 14 * scale_factor
	badge_style.content_margin_top = 3 * scale_factor
	badge_style.content_margin_bottom = 3 * scale_factor
	refresh_state()


func _draw_pips() -> void:
	var radius := 6.0 * _ui_scale
	for index in range(3):
		var center := Vector2(radius + 1.0 + index * radius * 2.7, pips.size.y * 0.5)
		if index < achieved:
			pips.draw_circle(center, radius, UI.GOLD)
		else:
			pips.draw_circle(center, radius, Color(1, 1, 1, 0.18))
			pips.draw_arc(
				center, radius - 1.0, 0, TAU, 20, Color(1, 1, 1, 0.55), 1.5 * _ui_scale, true
			)


func _highlight(_hovered: bool) -> void:
	pass
