extends "res://scripts/games/kart_spatial_landing.gd"
## Real native LUMO Kart home. All cards are Controls/Buttons with genuine routes.
## No baked reference screenshot and no fabricated purchases/season levels.
signal preview_rotate_requested(radians: float)

const THEME = preload("res://scripts/games/kart_ui_theme.gd")
const MODES = preload("res://scripts/games/kart_home_mode_choice.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const NEON := Color("21ccff")
const AMBER := Color("ffb52d")
const VIOLET := Color("9658ff")
const MAGENTA := Color("ff55d2")
const BACK := Color("081438")
const TRACKS := [
	["volcano_night", "Vulkan", "🌋", "assets/kart/neon_previews/volcano_night.webp"],
	["jungle_emerald_3600", "Dschungel", "🌿", "assets/kart/neon_previews/jungle_emerald_3600.webp"],
	["desert_drift", "Wüste", "☀", "assets/kart/neon_previews/desert_drift.webp"],
	["sonnenhafen", "Sonnenhafen", "⛵", "assets/kart/neon_previews/sonnenhafen.webp"],
]

var _hub_ready := false
var _header_profile: Button
var _highlight: PanelContainer
var _highlight_title: Label
var _highlight_image: TextureRect
var _highlight_pick: Button
var _track_row: HBoxContainer
var _track_scroll: ScrollContainer
var _track_buttons: Dictionary = {}
var _featured_track := "volcano_night"
var _extra_modes: GridContainer
var _arena_card: Button
var _season_card: Button
var _features: HBoxContainer
var _reward_card: Button
var _progress: PanelContainer
var _progress_label: Label
var _dock: ScrollContainer
var _rotation_left: Button
var _rotation_right: Button
var _reward_popup: AcceptDialog
var _season_stars: int = 0
var _neon_veil: ColorRect


func _ready() -> void:
	super._ready()
	# Keep the original native source's selection contract for actual races.
	for id in _mode_buttons:
		var button = _mode_buttons[id]
		button.title = {"race": "Rennen", "cup": "Turniere", "time_trial": "Zeitfahren"}[id]
		button.caption = {"race": "Schnelle Rennen", "cup": "Gegen die Besten", "time_trial": "Bestzeit jagen"}[id]
		button.accent = {"race": AMBER, "cup": VIOLET, "time_trial": NEON}[id]
		button.update_selected(id == current_mode)
	_header_profile = _action("LumoFox  ·  Fahrer", NEON, func(): mode_selected.emit("driver"), "PlayerCard")
	var avatar_path := "res://assets/kart/landing/lumo_avatar.webp"
	if ResourceLoader.exists(avatar_path, "Texture2D"):
		_header_profile.icon = load(avatar_path)
		_header_profile.expand_icon = true
	_header.add_child(_header_profile)
	_header.move_child(_header_profile, 1)
	_neon_veil = ColorRect.new()
	_neon_veil.name = "NeonGlassVeil"
	_neon_veil.color = Color("020a24", 0.30)
	_neon_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_root.add_child(_neon_veil)
	_layout_root.move_child(_neon_veil, 0)
	_build_featured_tracks()
	_build_extra_modes()
	_build_features()
	_build_progress()
	_build_dock()
	_build_rotators()
	_reward_popup = AcceptDialog.new()
	_reward_popup.title = "Deine Sterne"
	_reward_popup.dialog_text = "Du hast %d Sterne gesammelt. Spiele Rennen, um weitere Sterne zu verdienen." % total_stars
	add_child(_reward_popup)
	# The existing footer and all original choices remain usable.
	_hub_ready = true
	_layout()


func _action(title: String, accent: Color, callback: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	button.name = node_name if not node_name.is_empty() else "Action_" + title
	button.text = title
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.pressed.connect(callback)
	button.add_theme_font_override("font", THEME.HEADING)
	_skin(button, accent)
	return button


func _skin(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("0b2255", 0.95) if state == "normal" else Color("194889", 0.99)
		if state == "pressed":
			panel.bg_color = Color("15547e", 1.0)
		panel.border_color = accent.darkened(0.17) if state == "normal" else accent.lightened(0.20)
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(12)
		panel.set_content_margin_all(8)
		panel.shadow_color = Color(accent.r, accent.g, accent.b, 0.32 if state in ["hover", "focus"] else 0.15)
		panel.shadow_size = 5 if state in ["hover", "focus"] else 2
		button.add_theme_stylebox_override(state, panel)
	button.add_theme_color_override("font_color", Color("f3faff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _panel(accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("08183d", 0.93)
	skin.border_color = accent
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(18)
	skin.set_content_margin_all(8)
	skin.shadow_color = Color(accent.r, accent.g, accent.b, 0.23)
	skin.shadow_size = 5
	panel.add_theme_stylebox_override("panel", skin)
	return panel


func _build_featured_tracks() -> void:
	_highlight = _panel(NEON)
	_highlight.name = "StreckenHighlight"
	_layout_root.add_child(_highlight)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	_highlight.add_child(stack)
	_highlight_title = Label.new()
	_highlight_title.text = "⌁  Strecken-Highlight"
	_highlight_title.add_theme_color_override("font_color", Color.WHITE)
	_highlight_title.add_theme_font_override("font", THEME.HEADING)
	stack.add_child(_highlight_title)
	var hero := HBoxContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(hero)
	_highlight_image = TextureRect.new()
	_highlight_image.name = "FeaturedTrackArtwork"
	_highlight_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_highlight_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_highlight_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(_highlight_image)
	_highlight_pick = _action("Vulkan  ❯", AMBER, func(): _track_select(_featured_track), "PlayFeaturedTrack")
	hero.add_child(_highlight_pick)
	_track_scroll = ScrollContainer.new()
	_track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_track_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(_track_scroll)
	_track_row = HBoxContainer.new()
	_track_row.add_theme_constant_override("separation", 4)
	_track_scroll.add_child(_track_row)
	for entry in TRACKS:
		var id: String = entry[0]
		var label: String = entry[1]
		if not _available_track(id):
			continue
		var accent := AMBER if id == "volcano_night" else (Color("62ed9b") if id == "jungle_emerald_3600" else NEON)
		var tile := _action(label, accent, func(): _feature_track(id), "Track_" + id)
		_track_buttons[id] = tile
		_track_row.add_child(tile)
	_feature_track("volcano_night")


func _available_track(id: String) -> bool:
	for entry in CATALOG.TRACKS:
		if str(entry.id) == id:
			return true
	return false


func _feature_track(id: String) -> void:
	if not _available_track(id):
		return
	_featured_track = id
	var label := id
	for row in TRACKS:
		if row[0] == id:
			label = row[1]
			var candidate := "res://" + str(row[3])
			if ResourceLoader.exists(candidate, "Texture2D"):
				_highlight_image.texture = load(candidate)
			break
	_highlight_pick.text = label + "  ❯"
	for key in _track_buttons:
		var button: Button = _track_buttons[key]
		_skin(button, AMBER if key == id else NEON)


func _track_select(id: String) -> void:
	if _available_track(id):
		mode_selected.emit(id)
		mode_selected.emit("world")


func _build_extra_modes() -> void:
	_extra_modes = GridContainer.new()
	_extra_modes.name = "NeonExtraModes"
	_layout_root.add_child(_extra_modes)
	_season_card = _action("✦  Saison", NEON, func(): mode_selected.emit("modes"), "OpenSeason")
	_arena_card = _action("✧  Event", MAGENTA, func(): _choose("arena"), "OpenEvent")
	_extra_modes.add_child(_season_card)
	_extra_modes.add_child(_arena_card)


func _build_features() -> void:
	_features = HBoxContainer.new()
	_features.name = "FeatureCards"
	_layout_root.add_child(_features)
	for row in [
		["Garage", "garage", VIOLET],
		["Strecken", "world", NEON],
	]:
		_features.add_child(_action(row[0], row[2], func(): mode_selected.emit(row[1]), "Feature_" + row[1]))
	_reward_card = _action("Geschenke", MAGENTA, _show_rewards, "Feature_rewards")
	_features.add_child(_reward_card)


func _show_rewards() -> void:
	_reward_popup.dialog_text = "Deine gesammelten Sterne: %d\nWeitere Sterne erhältst du beim Spielen." % total_stars
	_reward_popup.popup_centered(Vector2i(420, 210))


func _build_progress() -> void:
	_progress = _panel(VIOLET)
	_progress.name = "Sternenpfad"
	_layout_root.add_child(_progress)
	_progress_label = Label.new()
	_progress_label.name = "ActualStarsProgress"
	_progress_label.text = "✦ Sternenpfad  ·  %d gesammelte Sterne" % total_stars
	_progress_label.add_theme_font_override("font", THEME.HEADING)
	_progress_label.add_theme_color_override("font_color", Color("ffd568"))
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_child(_progress_label)


func _build_dock() -> void:
	_dock = ScrollContainer.new()
	_dock.name = "NeonNavigationScroll"
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dock.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.mouse_filter = Control.MOUSE_FILTER_PASS
	_layout_root.add_child(_dock)
	_navigation.reparent(_dock, false)
	# Eight genuine routes. The navigation scrolls on narrow screens so targets
	# stay at least 48dp and never overlap the Android system inset.
	for child in _navigation.get_children():
		if child.name not in ["Open_garage", "Open_world"]:
			_navigation.remove_child(child)
			child.queue_free()
	var original: Array[Control] = []
	for child in _navigation.get_children():
		original.append(child)
	for child in original:
		child.reparent(self, false)
	for entry in [
		["⌂ Home", "home", AMBER],
		["⚑ Rennen", "race", NEON],
		["Garage", "garage", NEON],
		["Strecken", "world", NEON],
		["Turniere", "cup", VIOLET],
		["✦ Saison", "season", NEON],
		["Geschenke", "rewards", MAGENTA],
		["Event", "arena", MAGENTA],
		["⚙ Optionen", "settings", NEON],
	]:
		var target: String = entry[1]
		var button: Button
		if target == "garage":
			button = get_node("Open_garage") as Button
		elif target == "world":
			button = get_node("Open_world") as Button
		else:
			button = _action(entry[0], entry[2], func(): _route_dock(target), "Dock_" + target)
		button.text = entry[0]
		_skin(button, entry[2])
		_navigation.add_child(button)


func _route_dock(target: String) -> void:
	match target:
		"home":
			_focus_home()
		"race", "cup", "arena":
			_choose(target)
		"season":
			mode_selected.emit("modes")
		"rewards":
			_show_rewards()
		"settings":
			open_settings.emit()


func _focus_home() -> void:
	_feature_track("volcano_night")
	_choose("race")


func _build_rotators() -> void:
	_rotation_left = _action("↶", NEON, func(): preview_rotate_requested.emit(-PI / 8.0), "RotateKartLeft")
	_rotation_right = _action("↷", NEON, func(): preview_rotate_requested.emit(PI / 8.0), "RotateKartRight")
	_layout_root.add_child(_rotation_left)
	_layout_root.add_child(_rotation_right)
	_rotation_left.tooltip_text = "Kart nach links drehen"
	_rotation_right.tooltip_text = "Kart nach rechts drehen"


func _choose(id: String) -> void:
	current_mode = id
	_refresh_selection()
	mode_selected.emit(id)


func _layout() -> void:
	super._layout()
	if not _hub_ready or not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	var window_dp := Vector2(get_window().size) / MobileRuntime.get_ui_density()
	if window_dp.x <= 0.0 or window_dp.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var factor := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	var available := size / factor
	var portrait := available.y > available.x
	var compact := available.y < 460.0
	var margin := 10.0 if compact else 13.0
	var gap := 7.0
	_neon_veil.position = Vector2.ZERO
	_neon_veil.size = size
	_header.visible = available.y >= 280.0
	var header_h := 62.0 if not compact else 48.0
	_rect(_header, Rect2(margin, margin, available.x - margin * 2, header_h), factor)
	_header_profile.custom_minimum_size = Vector2(76 if compact else 136, 48) * factor
	_header_profile.text = "LumoFox" if compact else "LumoFox  ·  Fahrer"
	_header_profile.add_theme_font_size_override("font_size", roundi((13 if compact else 16) * factor))
	# The logo is drawn by the actual native LumoKartWordmark Control.
	_logo.custom_minimum_size = Vector2(128 if compact else 180, header_h) * factor
	var header_bottom := margin + (header_h + gap if _header.visible else 0.0)
	var dock_h := 56.0
	var footer_h := 48.0 if compact else 54.0
	var dock_y := available.y - margin - dock_h
	var footer_y := dock_y - gap - footer_h
	_dock.position = Vector2(margin, dock_y) * factor
	_dock.size = Vector2(available.x - margin * 2, dock_h) * factor
	_navigation.columns = 9
	_navigation.custom_minimum_size = Vector2(9 * (68 if compact else 94), dock_h) * factor
	_navigation.position = Vector2.ZERO
	_navigation.add_theme_constant_override("h_separation", roundi(5 * factor))
	for child in _navigation.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(68 if compact else 94, 48) * factor
			child.add_theme_font_size_override("font_size", roundi((12 if compact else 15) * factor))
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rect(_footer, Rect2(margin, footer_y, available.x - margin * 2, footer_h), factor)
	_back.add_theme_font_size_override("font_size", roundi(16 * factor))
	_start.add_theme_font_size_override("font_size", roundi((21 if available.x < 520 else 25) * factor))
	_start.text = "▶ START"
	_back.text = "← Spielewelt" if available.x >= 440 else "← Spiele"
	_skin(_start, AMBER)
	_skin(_back, NEON)
	# The live Godot SubViewport fills the model slot, never a screenshot.
	var hero_top := header_bottom
	var hero_bottom: float
	_highlight.visible = not compact
	_progress.visible = not compact
	_features.visible = not compact
	if portrait:
		hero_bottom = minf(available.y * 0.48, footer_y - 252.0)
		var track_x := available.x * 0.53
		_rect(_highlight, Rect2(track_x, hero_top + 7, available.x - track_x - margin, maxf(120.0, hero_bottom - hero_top - 15)), factor)
		var mode_y := hero_bottom + gap
		var cards_h := 76.0 if available.x >= 390.0 else 124.0
		_modes.columns = 3
		_extra_modes.columns = 1 if available.x < 390.0 else 2
		_rect(_modes, Rect2(margin, mode_y, (available.x - margin * 2) * 0.73, cards_h), factor)
		_rect(_extra_modes, Rect2(margin + (available.x - margin * 2) * 0.74, mode_y, (available.x - margin * 2) * 0.26, cards_h), factor)
		_rect(_features, Rect2(margin, mode_y + cards_h + gap, available.x - margin * 2, 77), factor)
		_rect(_progress, Rect2(margin, mode_y + cards_h + 84 + gap, available.x - margin * 2, 62), factor)
	else:
		hero_bottom = minf(available.y * 0.66, footer_y - 128.0)
		var feature_w := minf(available.x * 0.36, 450.0)
		_rect(_highlight, Rect2(available.x - margin - feature_w, hero_top, feature_w, maxf(90.0, hero_bottom - hero_top - 7)), factor)
		var mode_y := hero_bottom + gap
		if compact:
			mode_y = footer_y - 57.0
		_modes.columns = 3
		_extra_modes.columns = 2
		_rect(_modes, Rect2(margin, mode_y, available.x * 0.52, 63), factor)
		_rect(_extra_modes, Rect2(margin + available.x * 0.53, mode_y, available.x * 0.45 - margin, 63), factor)
		_rect(_features, Rect2(margin, mode_y + 68, available.x * 0.54, 54), factor)
		_rect(_progress, Rect2(margin + available.x * 0.56, mode_y + 68, available.x * 0.43 - margin, 54), factor)
	for id in _mode_buttons:
		var card = _mode_buttons[id]
		card.apply_size(factor, true)
		card.custom_minimum_size = Vector2(48, 48) * factor
		card.caption_label.hide()
		card.title_label.add_theme_font_size_override("font_size", roundi(13 * factor))
	for child in _extra_modes.get_children():
		child.custom_minimum_size = Vector2(48, 48) * factor
		child.add_theme_font_size_override("font_size", roundi(12 * factor))
	for child in _features.get_children():
		child.custom_minimum_size = Vector2(48, 48) * factor
		child.add_theme_font_size_override("font_size", roundi(13 * factor))
	_highlight_title.add_theme_font_size_override("font_size", roundi((12 if compact else 16) * factor))
	_highlight_pick.custom_minimum_size = Vector2(60 if compact else 85, 48) * factor
	_highlight_pick.add_theme_font_size_override("font_size", roundi(12 * factor))
	_track_scroll.visible = not compact
	for item in _track_buttons.values():
		item.custom_minimum_size = Vector2(62, 48) * factor
		item.add_theme_font_size_override("font_size", roundi((10 if compact else 12) * factor))
	_progress_label.add_theme_font_size_override("font_size", roundi((12 if compact else 16) * factor))
	_rotation_left.add_theme_font_size_override("font_size", roundi(19 * factor))
	_rotation_right.add_theme_font_size_override("font_size", roundi(19 * factor))
	var rot_y := hero_bottom - 58
	_rect(_rotation_left, Rect2(margin + 3, rot_y, 48, 48), factor)
	_rect(_rotation_right, Rect2(available.x * (0.47 if portrait else 0.59) - 48, rot_y, 48, 48), factor)
	# The old five-button strip is now the real nine-item scroll dock.
	# All model, track, reward and settings controls are native touch surfaces.
	call_deferred("_publish_stage_region")


func _publish_stage_region() -> void:
	if not _hub_ready or size.x <= 0.0 or size.y <= 0.0:
		return
	var factor := _layout_scale
	var available := size / factor
	var portrait := available.y > available.x
	var top := _header.position.y + _header.size.y + 8.0 * factor if _header.visible else 12.0 * factor
	var height := maxf(48.0 * factor, _rotation_left.position.y - top + 8.0 * factor)
	var left := 12.0 * factor
	var width := _highlight.position.x - left - 12.0 * factor if portrait else size.x - _highlight.size.x - left - 30.0 * factor
	if not _highlight.visible:
		width = size.x - left - 24.0 * factor
	var region := Rect2(Vector2(left, top), Vector2(maxf(48.0 * factor, width), height))
	stage_region_changed.emit(Rect2(region.position / size, region.size / size))
