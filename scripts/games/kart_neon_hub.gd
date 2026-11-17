extends Control
## LUMO Kart Hauptmenü (Neon-Glas, Zielbild 17.11.2026).
## Jede Kachel führt in eine echte Szene/Route von kart_island.gd. Keine vorgetäuschten Werte:
## Stufe, Sternenpfad und Belohnungen werden aus echten Sternen und echten Freischalt-Schwellen
## berechnet; das Wochen-Abenteuer ist eine feste Offline-Rotation über vorhandene Strecken.
signal mode_selected(mode_id: String)
signal quick_start
signal open_settings
signal return_to_games
signal stage_region_changed(region: Rect2)
signal preview_rotate_requested(radians: float)

const THEME = preload("res://scripts/games/kart_ui_theme.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const WORDMARK = preload("res://scripts/games/kart_wordmark.gd")
const TILE = preload("res://scripts/games/kart_neon_tile.gd")
const PLAYER_CARD = preload("res://scripts/games/kart_neon_player_card.gd")
const SEASON_BAR = preload("res://scripts/games/kart_neon_season_bar.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
const ADAPTIVE_LAYOUT = preload("res://scripts/games/kart_neon_layout.gd")
const NEON := Color("21ccff")
const AMBER := Color("ffa91f")
const VIOLET := Color("8a5cff")
const TEAL := Color("1fb8d8")
const MAGENTA := Color("ff4fc8")
const TRACKS := [
	["volcano_night", "Vulkan", "assets/kart/neon_previews/volcano_night.webp"],
	["jungle_emerald_3600", "Dschungel", "assets/kart/neon_previews/jungle_emerald_3600.webp"],
	["desert_drift", "Wüste", "assets/kart/neon_previews/desert_drift.webp"],
	["sonnenhafen", "Sonnenhafen", "assets/kart/neon_previews/sonnenhafen.webp"],
]
const TRACK_NAMES := {
	"volcano_night": "Vulkan", "jungle_emerald_3600": "Dschungel", "desert_drift": "Wüste",
	"sonnenhafen": "Sonnenhafen", "winter_sprint": "Winter-Sprint", "galaxy_ringway": "Galaxy Ringway",
	"crystal_canyon": "Kristall-Canyon", "zauberwald": "Zauberwald",
}

var total_stars := 0
var current_mode := "race"
var reduced_motion := false
var _layout_scale := 1.0
var _layout_root: Control
var _veil: ColorRect
var _back: Button
var _logo: Control
var _player: Button
var _stars_chip: Button
var _highlight: Panel
var _highlight_title: Label
var _highlight_pick: Button
var _track_buttons: Dictionary = {}
var _featured_track := "volcano_night"
var _dots: Control
var _mode_tiles: Dictionary = {}
var _feature_tiles: Dictionary = {}
var _progress: Button
var _progress_label: Label
var _dock: ScrollContainer
var _navigation: HBoxContainer
var _rotation_left: Button
var _rotation_right: Button
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_list: VBoxContainer
var _weekly_track := ""
var _stage_bounds := Rect2()
var _hub_ready := false


func _ready() -> void:
	name = "LumoKartNeonHub"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = THEME.create()
	_layout_root = Control.new()
	_layout_root.name = "NeonLayout"
	_layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout_root)
	_veil = ColorRect.new()
	_veil.name = "NeonGlassVeil"
	_veil.color = Color("020a24", 0.10)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_root.add_child(_veil)
	_build_header()
	_build_highlight()
	_build_modes()
	_build_features()
	_build_progress()
	_build_dock()
	_build_rotators()
	_build_overlay()
	_hub_ready = true
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	call_deferred("_layout")


func _tile(node_name: String, title: String, caption: String, icon: String, accent: Color, style: String) -> Button:
	var tile = TILE.new()
	tile.name = node_name
	tile.title = title
	tile.caption = caption
	tile.icon_kind = icon
	tile.accent = accent
	tile.tile_style = style
	tile.reduced_motion = reduced_motion
	return tile


func _build_header() -> void:
	_back = _tile("ReturnToGames", "", "", "back", NEON, "chip")
	_back.tooltip_text = "Zurück zur Spielewelt"
	_back.pressed.connect(func(): return_to_games.emit())
	_layout_root.add_child(_back)
	_logo = WORDMARK.new()
	_layout_root.add_child(_logo)
	_player = PLAYER_CARD.new()
	_player.stars = total_stars
	var avatar_path := "res://assets/kart/landing/lumo_avatar.webp"
	if ResourceLoader.exists(avatar_path, "Texture2D"):
		_player.avatar = load(avatar_path)
	_player.pressed.connect(func(): mode_selected.emit("driver"))
	_layout_root.add_child(_player)
	_stars_chip = _tile("StarsChip", str(total_stars), "", "star", Color("ffc23d"), "chip")
	_stars_chip.tooltip_text = "Deine echten Sterne"
	_stars_chip.pressed.connect(func(): _open_overlay("rewards"))
	_layout_root.add_child(_stars_chip)


func _build_highlight() -> void:
	_highlight = Panel.new()
	_highlight.name = "StreckenHighlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("071a45", 0.88)
	skin.border_color = NEON
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(16)
	skin.shadow_color = Color(NEON.r, NEON.g, NEON.b, 0.28)
	skin.shadow_size = 8
	_highlight.add_theme_stylebox_override("panel", skin)
	_layout_root.add_child(_highlight)
	_highlight_title = Label.new()
	_highlight_title.text = "Strecken-Highlight"
	_highlight_title.add_theme_font_override("font", THEME.HEADING)
	_highlight_title.add_theme_color_override("font_color", Color.WHITE)
	_highlight_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_highlight.add_child(_highlight_title)
	_highlight_pick = _tile("PlayFeaturedTrack", "Vulkan", "", "", AMBER, "thumb")
	_highlight_pick.active = true
	_highlight_pick.pressed.connect(func(): _track_select(_featured_track))
	_highlight.add_child(_highlight_pick)
	for entry in TRACKS:
		var id: String = entry[0]
		if not _available_track(id):
			continue
		var thumb = _tile("Track_" + id, entry[1], "", "", NEON, "thumb")
		var path := "res://" + str(entry[2])
		if ResourceLoader.exists(path, "Texture2D"):
			thumb.art = load(path)
		thumb.pressed.connect(func(): _feature_track(id))
		_track_buttons[id] = thumb
		_highlight.add_child(thumb)
	_dots = Control.new()
	_dots.name = "HighlightDots"
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	_highlight.add_child(_dots)
	_feature_track("volcano_night")


func _draw_dots() -> void:
	var count := _track_buttons.size()
	if count == 0:
		return
	var r := _dots.size.y * 0.32
	var step := r * 3.2
	var x0 := (_dots.size.x - step * (count - 1)) * 0.5
	var index := 0
	for id in _track_buttons:
		_dots.draw_circle(Vector2(x0 + step * index, _dots.size.y * 0.5), r, NEON if id == _featured_track else Color(1, 1, 1, 0.3))
		index += 1


func _available_track(id: String) -> bool:
	for entry in CATALOG.TRACKS:
		if str(entry.id) == id:
			return true
	return false


func _feature_track(id: String) -> void:
	if not _available_track(id):
		return
	_featured_track = id
	_highlight_pick.title = TRACK_NAMES.get(id, id)
	_highlight_pick.tooltip_text = "%s fahren – Strecke wählen" % _highlight_pick.title
	if _track_buttons.has(id):
		_highlight_pick.art = _track_buttons[id].art
	for key in _track_buttons:
		_track_buttons[key].set_active(key == id)
	_highlight_pick.queue_redraw()
	if is_instance_valid(_dots):
		_dots.queue_redraw()
	if _hub_ready:
		call_deferred("_layout")


func _track_select(id: String) -> void:
	if _available_track(id):
		mode_selected.emit(id)
		mode_selected.emit("world")


func _build_modes() -> void:
	var tracks: Array = []
	for entry in CATALOG.TRACKS:
		tracks.append(str(entry.id))
	_weekly_track = PATH.weekly_track(tracks)
	var weekly_name: String = TRACK_NAMES.get(_weekly_track, "Abenteuer")
	for spec in [
		["race", "Rennen", "Schnelles Rennen – sofort los!", "flag", AMBER],
		["cup", "Turniere", "Sternen-Cup über alle Welten", "trophy", VIOLET],
		["season", "Saison", "Sternenpfad: echte Freischaltungen", "star", TEAL],
		["event", "Event", "Wochen-Abenteuer: " + weekly_name, "calendar", MAGENTA],
	]:
		var id: String = spec[0]
		var tile = _tile("Mode_" + id, spec[1], spec[2], spec[3], spec[4], "hero")
		tile.pressed.connect(func(): _press_mode(id))
		_mode_tiles[id] = tile
		_layout_root.add_child(tile)
	_mode_tiles["event"].badge = not _weekly_track.is_empty()
	# Alter Name bleibt für vorhandene Menü-Tests erhalten.
	_mode_tiles["race"].set_meta("legacy_name", "LiveQuickStart")


func _press_mode(id: String) -> void:
	match id:
		"race":
			_start("race")
		"cup":
			_start("cup")
		"season":
			_open_overlay("season")
		"event":
			if not _weekly_track.is_empty():
				mode_selected.emit(_weekly_track)
			_start("race")


func _start(mode: String) -> void:
	current_mode = mode
	mode_selected.emit(mode)
	quick_start.emit()


func _build_features() -> void:
	for spec in [
		["garage", "Garage", "Karts ansehen, tunen und lackieren", "wrench", VIOLET, "assets/kart/landing/garage_art.webp"],
		["world", "Strecken", "Alle Strecken entdecken und wählen", "flag", NEON, ""],
		["rewards", "Belohnungen", "Deine freigeschalteten Fahrer und Karts", "gift", MAGENTA, ""],
	]:
		var id: String = spec[0]
		var tile = _tile("Feature_" + id, spec[1], spec[2], spec[3], spec[4], "feature")
		if not str(spec[5]).is_empty() and ResourceLoader.exists("res://" + str(spec[5]), "Texture2D"):
			tile.art = load("res://" + str(spec[5]))
		tile.pressed.connect(func(): _route(id))
		_feature_tiles[id] = tile
		_layout_root.add_child(tile)
	_feature_tiles["rewards"].badge = PATH.unlocked_count(total_stars) > 0


func _build_progress() -> void:
	_progress = SEASON_BAR.new()
	_progress.stars = total_stars
	_progress.pressed.connect(func(): _open_overlay("season"))
	_layout_root.add_child(_progress)
	# Zugänglicher Klartext des Fortschritts (auch für Tests und Screenreader).
	_progress_label = Label.new()
	_progress_label.name = "ActualStarsProgress"
	_progress_label.visible = false
	var progress := PATH.path_progress(total_stars)
	_progress_label.text = "%d gesammelte Sterne · %d / %d · %s" % [total_stars, progress.x, progress.y, _progress.summary()]
	_progress.add_child(_progress_label)


func _build_dock() -> void:
	_dock = ScrollContainer.new()
	_dock.name = "NeonNavigationScroll"
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_dock.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.mouse_filter = Control.MOUSE_FILTER_PASS
	_layout_root.add_child(_dock)
	_navigation = HBoxContainer.new()
	_navigation.name = "NeonNavigation"
	_dock.add_child(_navigation)
	for spec in [
		["Dock_home", "Home", "home", "home", AMBER],
		["Dock_race", "Rennen", "race", "flag", NEON],
		["Open_garage", "Garage", "garage", "wrench", NEON],
		["Open_world", "Strecken", "world", "road", NEON],
		["Dock_cup", "Turniere", "cup", "trophy", NEON],
		["Dock_season", "Saison", "season", "star", NEON],
		["Dock_rewards", "Belohnungen", "rewards", "gift", NEON],
		["Dock_event", "Event", "event", "calendar", NEON],
		["Landing_settings", "Einstellungen", "settings", "gear", NEON],
	]:
		var target: String = spec[2]
		var tile = _tile(spec[0], spec[1], "", spec[3], spec[4], "nav")
		tile.active = target == "home"
		tile.pressed.connect(func(): _route(target))
		_navigation.add_child(tile)


func _route(target: String) -> void:
	match target:
		"home":
			_close_overlay()
		"race", "cup":
			_press_mode(target)
		"season", "event":
			_press_mode(target)
		"rewards":
			_open_overlay("rewards")
		"garage", "world", "driver":
			mode_selected.emit(target)
		"settings":
			open_settings.emit()


func _build_rotators() -> void:
	_rotation_left = _tile("RotateKartLeft", "", "", "rotate_left", NEON, "chip")
	_rotation_right = _tile("RotateKartRight", "", "", "rotate_right", NEON, "chip")
	_rotation_left.tooltip_text = "Kart nach links drehen"
	_rotation_right.tooltip_text = "Kart nach rechts drehen"
	_rotation_left.pressed.connect(func(): preview_rotate_requested.emit(-PI / 8.0))
	_rotation_right.pressed.connect(func(): preview_rotate_requested.emit(PI / 8.0))
	_layout_root.add_child(_rotation_left)
	_layout_root.add_child(_rotation_right)


func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.name = "SternenpfadOverlay"
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("08133a", 0.97)
	skin.border_color = VIOLET.lightened(0.2)
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(20)
	skin.set_content_margin_all(16)
	skin.shadow_color = Color(0, 0, 0, 0.5)
	skin.shadow_size = 18
	_overlay.add_theme_stylebox_override("panel", skin)
	_overlay.visible = false
	add_child(_overlay)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_overlay.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_overlay_title = Label.new()
	_overlay_title.add_theme_font_override("font", THEME.HEADING)
	_overlay_title.add_theme_font_size_override("font_size", 24)
	_overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_overlay_title)
	var close := Button.new()
	close.name = "CloseOverlay"
	close.text = "Schließen"
	close.custom_minimum_size = Vector2(120, 56)
	THEME.premium_button(close, AMBER, true)
	close.pressed.connect(_close_overlay)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_overlay_list = VBoxContainer.new()
	_overlay_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_overlay_list)


func _open_overlay(kind: String) -> void:
	for child in _overlay_list.get_children():
		_overlay_list.remove_child(child)
		child.queue_free()
	var unlocked := PATH.unlocked_count(total_stars)
	var all := PATH.milestones()
	if kind == "season":
		_overlay_title.text = "Sternenpfad"
		_overlay_line("Du hast %d echte Sterne. Sterne verdienst du in Rennen und beim Lernen in der App." % total_stars, Color("d9e6ff"))
	else:
		_overlay_title.text = "Belohnungen"
		_overlay_line("%d von %d Belohnungen freigeschaltet. Nichts davon kann man kaufen." % [unlocked, all.size()], Color("d9e6ff"))
	for entry in all:
		var done := total_stars >= int(entry.stars)
		if kind == "rewards" and not done and entry != PATH.next_milestone(total_stars):
			continue
		var text := "★ Frei: %s %s (%d ★)" % [entry.kind, entry.name, entry.stars]
		if not done:
			text = "Noch %d ★: %s %s" % [int(entry.stars) - total_stars, entry.kind, entry.name]
		_overlay_line(text, Color("ffd568") if done else Color("9fb4d8"))
	_overlay.visible = true
	_overlay.move_to_front()
	_layout()
	for tile in _navigation.get_children():
		tile.set_active(tile.name == ("Dock_season" if kind == "season" else "Dock_rewards"))


func _overlay_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	_overlay_list.add_child(label)


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.visible = false
	for tile in _navigation.get_children():
		tile.set_active(tile.name == "Dock_home")


func handle_back() -> bool:
	if is_instance_valid(_overlay) and _overlay.visible:
		_close_overlay()
		return true
	return false


func _layout() -> void:
	if not _hub_ready or not is_inside_tree():
		return
	ADAPTIVE_LAYOUT.arrange(self)
	_publish_stage_region()


func _publish_stage_region() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or not _stage_bounds.has_area():
		return
	stage_region_changed.emit(Rect2(_stage_bounds.position / size, _stage_bounds.size / size))
