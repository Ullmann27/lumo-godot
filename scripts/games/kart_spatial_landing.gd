extends Control
## Native, touch-sized controls over the garage's single live 3D stage.
signal mode_selected(mode_id: String)
signal quick_start
signal open_settings
signal return_to_games

const UI = preload("res://scripts/games/kart_ui_theme.gd")
const WORDMARK = preload("res://scripts/games/kart_wordmark.gd")
const CHOICE = preload("res://scripts/games/kart_menu_choice.gd")
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
	_footer.add_child(_back)
	_start = _button("▶  START", func(): quick_start.emit(), true)
	_start.name = "LiveQuickStart"
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
		card.selected = id == current_mode
		for state in ["normal", "hover", "focus", "pressed"]:
			card.add_theme_stylebox_override(state, UI.premium_panel(
				GOLD if card.selected else CYAN, card.selected or state != "normal"))
		if is_instance_valid(card.selection_mark):
			card.selection_mark.visible = card.selected
		if is_instance_valid(card.sheen_material):
			card.sheen_material.set_shader_parameter("highlight", 0.8 if card.selected else 0.0)


func _layout() -> void:
	if not is_inside_tree() or not is_instance_valid(_footer):
		return
	var viewport_size := get_viewport_rect().size
	var window_dp := Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if window_dp.x <= 0 or window_dp.y <= 0 or size.x <= 0 or size.y <= 0:
		return
	var scale_factor := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	var available := size / scale_factor
	_layout_root.scale = Vector2.ONE * scale_factor
	_layout_root.size = available
	var portrait := available.x < available.y
	var narrow := available.x < 520
	var short_view := available.y < 440
	var margin := 12.0 if narrow or short_view else 20.0
	var header_height := 48.0 if short_view else 68.0
	_rect(_header, Rect2(margin, margin, available.x - margin * 2, header_height))
	_logo.custom_minimum_size = Vector2(126 if narrow or short_view else 176, header_height)
	_stars.add_theme_font_size_override("font_size", 16 if narrow else 22)
	_settings.text = "⚙" if narrow else "Optionen"
	_settings.tooltip_text = "Einstellungen"
	var footer_height := 52.0 if short_view else 60.0
	var footer_y := available.y - margin - footer_height
	_rect(_footer, Rect2(margin, footer_y, available.x - margin * 2, footer_height))
	_back.custom_minimum_size = Vector2(48, footer_height)
	_start.custom_minimum_size = Vector2(48, footer_height)
	_back.text = "← Spiele" if narrow else "← Spielewelt"
	_start.add_theme_font_size_override("font_size", 21 if narrow else 25)
	var nav_height := 104.0 if narrow else 52.0
	_navigation.columns = 3 if narrow else 5
	var nav_y := footer_y - nav_height - 10
	_rect(_navigation, Rect2(margin, nav_y, available.x - margin * 2, nav_height))
	for button in _navigation.get_children():
		button.add_theme_font_size_override("font_size", 14 if narrow else 16)
		button.custom_minimum_size = Vector2(48, 48)
	var horizontal_modes := portrait or short_view
	_modes.columns = 3 if horizontal_modes else 1
	var modes_rect := Rect2(margin, margin + header_height + 20, clampf(available.x * 0.27, 210, 320), 248)
	if horizontal_modes:
		modes_rect = Rect2(margin, nav_y - (84.0 if portrait else 60.0) - 10, available.x - margin * 2, 84 if portrait else 60)
	_rect(_modes, modes_rect)
	for id in _mode_buttons:
		var card = _mode_buttons[id]
		card.apply_size(1.0, true)
		card.custom_minimum_size = Vector2(48, 60 if horizontal_modes else 76)
		card.title_label.text = {"race": "Solo", "cup": "Grand Prix", "time_trial": "Zeitrennen"}[id] if narrow else card.title
		card.title_label.add_theme_font_size_override("font_size", 13 if horizontal_modes else 20)
		card.caption_label.visible = not horizontal_modes
		card.icon_plate.visible = not narrow
		card.row.add_theme_constant_override("separation", 7)
		card.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


func _rect(control: Control, bounds: Rect2) -> void:
	control.position = bounds.position
	control.size = bounds.size
