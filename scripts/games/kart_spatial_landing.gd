extends Control
## Native, touch-sized controls over the garage's single live 3D stage.
signal mode_selected(mode_id: String)
signal quick_start
signal open_settings
signal return_to_games
signal stage_region_changed(region: Rect2)

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const WORDMARK = preload("res://scripts/games/kart_wordmark.gd")
const CHOICE = preload("res://scripts/games/kart_home_mode_choice.gd")
const GOLD := Color("ffce4c")
const CYAN := Color("51cdec")
var total_stars := 0
var current_mode := "cup"
var _layout_root: Control
var _header: HBoxContainer
var _modes: GridContainer
var _navigation: GridContainer
var _footer: HBoxContainer
var _mode_buttons: Dictionary = {}
var _logo: Control
var _stars: Label
var _start: Button
var _back: Button
var _settings: Button
var _layout_scale := 1.0


func _ready() -> void:
	name = "LumoKartSpatialLanding"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.create()
	_layout_root = Control.new()
	_layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout_root)
	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_constant_override("separation", 10)
	_layout_root.add_child(_header)
	_logo = WORDMARK.new()
	_header.add_child(_logo)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(spacer)
	_stars = Label.new()
	_stars.text = "★ %d" % total_stars
	_stars.add_theme_color_override("font_color", GOLD)
	_stars.add_theme_font_size_override("font_size", 22)
	_stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_stars)
	_settings = _button("Optionen", func(): open_settings.emit())
	_settings.size_flags_horizontal = Control.SIZE_FILL
	_header.add_child(_settings)
	_modes = GridContainer.new()
	_modes.add_theme_constant_override("v_separation", 8)
	_modes.add_theme_constant_override("h_separation", 8)
	_layout_root.add_child(_modes)
	for spec in [["race", "Einzelrennen", "Direkt auf die Strecke", "race"],
		["cup", "Grand Prix", "Dein Sternenpokal", "cup"],
		["time_trial", "Zeitrennen", "Schlage deine Bestzeit", "clock"]]:
		var card := CHOICE.new()
		card.name = "Mode_" + spec[0]
		card.title = spec[1]
		card.caption = spec[2]
		card.artwork = load("res://assets/kart/menu/%s.svg" % spec[3])
		card.selected = current_mode == spec[0]
		card.accent = {"race": Color("58d7d8"), "cup": Color("ffb94b"), "time_trial": Color("a7b9ff")}[spec[0]]
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_choose.bind(spec[0]))
		_modes.add_child(card)
		_mode_buttons[spec[0]] = card
	_navigation = GridContainer.new()
	_navigation.columns = 5
	_navigation.add_theme_constant_override("h_separation", 6)
	_navigation.add_theme_constant_override("v_separation", 6)
	_layout_root.add_child(_navigation)
	for spec in [["driver", "Fahrer"], ["garage", "Garage"], ["world", "Strecken"],
		["difficulty", "Tempo"], ["modes", "Mehr Modi"]]:
		var button := _button(spec[1], func(): mode_selected.emit(spec[0]))
		button.name = "Open_" + spec[0]
		_navigation.add_child(button)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	_layout_root.add_child(_footer)
	_back = _button("← Spielewelt", func(): return_to_games.emit())
	_back.name = "ReturnToGames"
	_back.size_flags_stretch_ratio = 1.0
	_footer.add_child(_back)
	_start = _button("▶  START", func(): quick_start.emit(), true)
	_start.name = "LiveQuickStart"
	_start.size_flags_stretch_ratio = 2.5
	_footer.add_child(_start)
	_refresh_selection()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")


func _button(caption: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(48, 52)
	button.add_theme_font_size_override("font_size", 16)
	UI.premium_button(button, GOLD if primary else CYAN, primary)
	button.pressed.connect(callback)
	return button


func _choose(id: String) -> void:
	current_mode = id
	_refresh_selection()
	mode_selected.emit(id)


func _refresh_selection() -> void:
	for id in _mode_buttons:
		var card = _mode_buttons[id]
		card.update_selected(id == current_mode)


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(_footer):
		return
	var viewport_size := get_viewport_rect().size
	var window_dp := Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if window_dp.x <= 0 or window_dp.y <= 0 or size.x <= 0 or size.y <= 0:
		return
	var scale_factor := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	_layout_scale = scale_factor
	var available := size / scale_factor
	# Rasterize text at the final UI resolution. Scaling a parent Control makes
	# small glyphs blurry when the portrait viewport is stretched back down.
	_layout_root.scale = Vector2.ONE
	_layout_root.size = size
	var portrait := available.x < available.y
	var narrow := available.x < 520
	var short_view := available.y < 440
	_header.visible = available.y >= 300
	var margin := 12.0 if narrow or short_view else 20.0
	var header_height := 48.0 if short_view else 68.0
	_header.add_theme_constant_override("separation", roundi(10 * scale_factor))
	_logo.custom_minimum_size = Vector2(126 if narrow or short_view else 176, header_height) * scale_factor
	_stars.add_theme_font_size_override("font_size", roundi((16 if narrow else 22) * scale_factor))
	_settings.text = "⚙" if narrow else "Optionen"
	_settings.tooltip_text = "Einstellungen"
	_settings.custom_minimum_size = Vector2(48 if narrow else 112, 48) * scale_factor
	_settings.add_theme_font_size_override("font_size", roundi(16 * scale_factor))
	header_height = maxf(header_height, _header.get_combined_minimum_size().y / scale_factor)
	_rect(_header, Rect2(margin, margin, available.x - margin * 2, header_height), scale_factor)
	var footer_height := 52.0 if short_view else 60.0
	var footer_y := available.y - margin - footer_height
	_rect(_footer, Rect2(margin, footer_y, available.x - margin * 2, footer_height), scale_factor)
	_footer.add_theme_constant_override("separation", roundi(10 * scale_factor))
	_back.custom_minimum_size = Vector2(48, footer_height) * scale_factor
	_start.custom_minimum_size = Vector2(48, footer_height) * scale_factor
	_back.text = "← Spiele" if narrow else "← Spielewelt"
	_back.add_theme_font_size_override("font_size", roundi(16 * scale_factor))
	_start.add_theme_font_size_override("font_size", roundi((21 if narrow else 25) * scale_factor))
	var nav_height := 104.0 if narrow else (48.0 if short_view else 52.0)
	_navigation.columns = 3 if narrow else 5
	var nav_y := footer_y - nav_height - 8
	_rect(_navigation, Rect2(margin, nav_y, available.x - margin * 2, nav_height), scale_factor)
	for axis in ["h_separation", "v_separation"]:
		_navigation.add_theme_constant_override(axis, roundi(6 * scale_factor))
	for button in _navigation.get_children():
		button.add_theme_font_size_override("font_size", roundi((14 if narrow else 16) * scale_factor))
		button.custom_minimum_size = Vector2(48, 48) * scale_factor
	var modes_top := margin + (header_height + 8 if _header.visible else 0.0)
	var mode_gap := 4.0 if short_view else 8.0
	var stack_height := nav_y - modes_top - 8.0
	var mode_height := minf(76.0, (stack_height - mode_gap * 2) / 3.0)
	# Wide Android surfaces can be only ~350dp tall. Keep the three modes
	# beside the live model whenever three real 48dp rows fit, rather than
	# painting full-width rows across its chassis and face.
	var horizontal_modes := portrait or mode_height < 48.0
	_modes.columns = 3 if horizontal_modes else 1
	var modes_rect := Rect2(margin, modes_top, clampf(available.x * 0.29, 210, 320), mode_height * 3 + mode_gap * 2)
	if horizontal_modes:
		modes_rect = Rect2(margin, nav_y - (84.0 if portrait else 60.0) - 10, available.x - margin * 2, 84 if portrait else 60)
	for axis in ["h_separation", "v_separation"]:
		_modes.add_theme_constant_override(axis, roundi(mode_gap * scale_factor))
	for id in _mode_buttons:
		var card = _mode_buttons[id]
		card.apply_size(scale_factor, true)
		card.custom_minimum_size = Vector2(48, 60 if horizontal_modes else mode_height) * scale_factor
		card.title_label.text = {"race": "Solo", "cup": "Pokal", "time_trial": "Zeit"}[id] if narrow else card.title
		card.title_label.add_theme_font_size_override("font_size", roundi((13 if horizontal_modes else (16 if short_view else 20)) * scale_factor))
		card.caption_label.visible = not horizontal_modes and not short_view
		card.icon_plate.show()
		if narrow:
			card.icon_view.custom_minimum_size = Vector2.ONE * 23.0 * scale_factor
		card.row.add_theme_constant_override("separation", roundi(7 * scale_factor))
		card.caption_label.get_parent().add_theme_constant_override("separation", roundi(2 * scale_factor))
		card.selection_mark.add_theme_constant_override("outline_size", roundi(3 * scale_factor))
		card.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_rect(_modes, modes_rect, scale_factor)
	call_deferred("_publish_stage_region")


func _publish_stage_region() -> void:
	var inset := 8.0 * _layout_scale
	var clear := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2)
	if _header.visible:
		clear.position.y = _header.position.y + _header.size.y + inset
	clear.end.y = _navigation.position.y - inset
	if _modes.columns == 1:
		clear.position.x = _modes.position.x + _modes.size.x + inset
		clear.end.x = size.x - inset
	else:
		clear.end.y = _modes.position.y - inset
	if clear.has_area():
		stage_region_changed.emit(Rect2(clear.position / size, clear.size / size))


func _rect(control: Control, bounds: Rect2, ui_scale: float) -> void:
	control.position = bounds.position * ui_scale
	control.size = bounds.size * ui_scale
