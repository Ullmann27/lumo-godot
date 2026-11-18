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
const KIT = preload("res://scripts/games/kart_ui3d.gd")
const ICONS = preload("res://scripts/games/kart_neon_icons.gd")
## Kit-Icon je Rennart des Katalogs (Overlay "Rennarten").
const RACE_KIND_ICONS := {"race": "icon_flag", "cup": "icon_trophy", "time_trial": "icon_stopwatch",
	"training": "icon_route", "arena": "icon_star_crystal"}
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
var _floor: Control
var _back: Button
var _logo: Control
var _player: Button
var _stars_chip: Button
var _highlight: Panel
var _highlight_title: Label
var _highlight_icon: Control
var _highlight_flat: StyleBoxFlat
var _overlay_flat: StyleBoxFlat
var _skin_scale := -1.0
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
## Rennarten bleiben dauerhaft im Menü, damit jede Rennart einen Tipp entfernt ist.
var _race_kinds: GridContainer
var _race_kinds_compact := false
var _race_kind_buttons: Dictionary = {}
var _live_start: Button
var _weekly_track := ""
var _stage_bounds := Rect2()
var _hub_ready := false


func _ready() -> void:
	name = "LumoKartNeonHub"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = THEME.create()
	_adopt_owner_motion()
	_layout_root = Control.new()
	_layout_root.name = "NeonLayout"
	_layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout_root)
	_veil = ColorRect.new()
	_veil.name = "NeonGlassVeil"
	_veil.color = Color("020a24", 0.10)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_root.add_child(_veil)
	# Blaues Bodenleuchten hinter den Kacheln (ein Vieleck mit Verlauf), wie die Halle im Zielbild.
	_floor = Control.new()
	_floor.name = "NeonFloorGlow"
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.draw.connect(_draw_floor)
	_floor.resized.connect(_floor.queue_redraw)
	_layout_root.add_child(_floor)
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


## Die Einstellung "weniger Bewegung" gehört dem Spiel (kart_island). Das Menü übernimmt
## sie vom nächsten Elternknoten, der sie führt, falls sie nicht schon gesetzt wurde.
func _adopt_owner_motion() -> void:
	var node := get_parent()
	while node != null and not reduced_motion:
		if "reduced_motion" in node:
			reduced_motion = bool(node.get("reduced_motion"))
			break
		node = node.get_parent()


func _draw_floor() -> void:
	var s := _floor.size
	var top := Color("0a2a9a", 0.0)
	var mid := Color("0a2a9a", 0.42)
	var low := Color("061a66", 0.62)
	_floor.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y * 0.45), Vector2(0, s.y * 0.45)]),
		PackedColorArray([top, top, mid, mid]))
	_floor.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.45), Vector2(s.x, s.y * 0.45), s, Vector2(0, s.y)]),
		PackedColorArray([mid, mid, low, low]))


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
	_stars_chip = _tile("StarsChip", str(total_stars), "", "star_gold", Color("ffc23d"), "chip")
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
	_highlight_flat = skin
	_highlight.add_theme_stylebox_override("panel", skin)
	_layout_root.add_child(_highlight)
	_highlight_icon = Control.new()
	_highlight_icon.name = "HighlightIcon"
	_highlight_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_highlight_icon.draw.connect(func(): ICONS.draw3d(_highlight_icon, "flag", _highlight_icon.size * 0.5,
		minf(_highlight_icon.size.x, _highlight_icon.size.y), Color.WHITE))
	_highlight.add_child(_highlight_icon)
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
		["race", "Rennen", "Schnelles Rennen – sofort los!", "flag", AMBER, "plate_hero_amber", "Sofort los!"],
		["cup", "Turniere", "Sternen-Cup über alle Welten", "trophy", VIOLET, "plate_hero_violet", "Sternen-Cup"],
		["season", "Saison", "Sternenpfad: echte Freischaltungen", "star", TEAL, "plate_hero_teal", "Sternenpfad"],
		["event", "Event", "Wochen-Abenteuer: " + weekly_name, "calendar", MAGENTA, "plate_hero_magenta", weekly_name],
	]:
		var id: String = spec[0]
		var tile = _tile("Mode_" + id, spec[1], spec[2], spec[3], spec[4], "hero")
		tile.plate = spec[5]
		tile.short_caption = spec[6]
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
		["garage", "Garage", "Karts tunen und lackieren", "wrench", VIOLET, "assets/kart/landing/garage_art.webp", ""],
		["world", "Strecken", "Alle Strecken entdecken", "flag", NEON, "", "road"],
		["rewards", "Belohnungen", "Deine Fahrer und Karts", "gift", MAGENTA, "", "gift"],
	]:
		var id: String = spec[0]
		var tile = _tile("Feature_" + id, spec[1], spec[2], spec[3], spec[4], "feature")
		tile.art_icon = spec[6]
		if not str(spec[5]).is_empty() and ResourceLoader.exists("res://" + str(spec[5]), "Texture2D"):
			tile.art = load("res://" + str(spec[5]))
		tile.pressed.connect(func(): _route(id))
		_feature_tiles[id] = tile
		_layout_root.add_child(tile)
	_feature_tiles["rewards"].badge = PATH.unlocked_count(total_stars) > 0


func _build_progress() -> void:
	_progress = SEASON_BAR.new()
	_progress.stars = total_stars
	_progress.reduced_motion = reduced_motion
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
		["Dock_home", "Home", "home", "home", AMBER, ""],
		["Dock_race", "Rennen", "race", "flag", NEON, ""],
		["Open_garage", "Garage", "garage", "wrench", NEON, ""],
		["Open_world", "Strecken", "world", "road", NEON, ""],
		["Dock_cup", "Turniere", "cup", "trophy", NEON, ""],
		["Dock_season", "Saison", "season", "star", NEON, ""],
		["Dock_rewards", "Belohnungen", "rewards", "gift", NEON, "Preise"],
		["Dock_event", "Event", "event", "calendar", NEON, ""],
		["Landing_settings", "Einstellungen", "settings", "gear", NEON, "Optionen"],
	]:
		var target: String = spec[2]
		var tile = _tile(spec[0], spec[1], "", spec[3], spec[4], "nav")
		# Kurzform nur für schmale Handys, auf denen das volle Wort unter 11 sp fiele.
		tile.short_title = spec[5]
		tile.active = target == "home"
		tile.pressed.connect(func(): _route(target))
		_navigation.add_child(tile)


func _route(target: String) -> void:
	match target:
		"home":
			_close_overlay()
		"race":
			# Die Leiste öffnet die Auswahl aller Rennarten; die große Kachel startet sofort.
			_open_overlay("race")
		"cup":
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
	_overlay_flat = skin
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
	_build_race_kinds(column)


## Alle fünf Rennarten des Katalogs. Das Neon-Menü startete sonst nur Rennen und
## Turnier; Zeitfahren, Training und Arena waren nur noch über die Garage erreichbar.
func _build_race_kinds(column: VBoxContainer) -> void:
	_race_kinds = GridContainer.new()
	_race_kinds.name = "RaceKinds"
	_race_kinds.columns = 1
	_race_kinds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_kinds.add_theme_constant_override("h_separation", 8)
	_race_kinds.add_theme_constant_override("v_separation", 8)
	_race_kinds.visible = false
	_overlay_list.add_child(_race_kinds)
	for entry in CATALOG.MODES:
		var id: String = str(entry.id)
		var kind := Button.new()
		# Rennen und Turnier haben schon große Kacheln mit den Namen Mode_race/Mode_cup.
		kind.name = ("RaceKind_" if id in ["race", "cup"] else "Mode_") + id
		kind.custom_minimum_size = Vector2(0, 60)
		kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kind.alignment = HORIZONTAL_ALIGNMENT_LEFT
		kind.set_meta("race_kind_name", str(entry.name))
		kind.set_meta("race_kind_description", str(entry.description))
		THEME.premium_button(kind, NEON, false)
		kind.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		kind.icon = KIT.texture(str(RACE_KIND_ICONS.get(id, "")))
		kind.expand_icon = true
		kind.pressed.connect(func(): _select_race_kind(id))
		_race_kinds.add_child(kind)
		_race_kind_buttons[id] = kind
	_live_start = Button.new()
	_live_start.name = "LiveQuickStart"
	_live_start.text = "START"
	_live_start.custom_minimum_size = Vector2(0, 64)
	THEME.premium_button(_live_start, AMBER, true)
	_live_start.pressed.connect(func(): quick_start.emit())
	_live_start.visible = false
	column.add_child(_live_start)
	_refresh_race_kinds()


func _select_race_kind(id: String) -> void:
	current_mode = id
	mode_selected.emit(id)
	_refresh_race_kinds()


func _refresh_race_kinds() -> void:
	for id in _race_kind_buttons:
		var kind: Button = _race_kind_buttons[id]
		var chosen: bool = id == current_mode
		kind.text = ("✓ " if chosen else "") + str(kind.get_meta("race_kind_name"))
		if not _race_kinds_compact:
			kind.text += "\n" + str(kind.get_meta("race_kind_description"))
		kind.tooltip_text = str(kind.get_meta("race_kind_description"))
		kind.alignment = HORIZONTAL_ALIGNMENT_CENTER if _race_kinds_compact else HORIZONTAL_ALIGNMENT_LEFT
		kind.modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.82)
	_skin_race_kinds()


## Kit-Optik für Panels und Knöpfe des Menüs im dp-Maßstab `k`. Die StyleBoxen kommen aus
## dem Zwischenspeicher des Kits; fehlt das Kit, bleiben die flachen Ersatz-Stile.
func apply_kit_skins(k: float) -> void:
	if is_equal_approx(k, _skin_scale):
		return
	_skin_scale = k
	var glass := KIT.themed("panel_glass_navy", k, Vector4(16, 14, 16, 16), Color.WHITE, Color("050d33", 0.93))
	if glass != null:
		_overlay.add_theme_stylebox_override("panel", glass)
		_highlight.add_theme_stylebox_override("panel", KIT.themed("panel_glass_navy", k, Vector4(0, 0, 0, 0)))
	else:
		_overlay_flat.set_content_margin_all(16 * k)
		_overlay_flat.set_corner_radius_all(roundi(20 * k))
		_highlight_flat.set_corner_radius_all(roundi(16 * k))
		_highlight_flat.set_border_width_all(maxi(1, roundi(2 * k)))
		_highlight_flat.shadow_size = roundi(8 * k)
	var close: Button = _overlay.find_child("CloseOverlay", true, false)
	_skin_button(close, "button_secondary_blue", k, Color.WHITE)
	_skin_button(_live_start, "button_primary_gold", k, Color("3a1c00"))
	_skin_race_kinds()


func _skin_button(button: Button, plate: String, k: float, face: Color) -> void:
	var margins := Vector4(14, 8, 14, 12)
	var normal := KIT.themed(plate, k, margins)
	if normal == null:
		return
	var pressed := KIT.themed(plate + "_pressed", k, Vector4(14, 11, 14, 9))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", KIT.themed(plate, k, margins, Color(1.1, 1.1, 1.1)))
	button.add_theme_stylebox_override("pressed", pressed if pressed != null else KIT.themed(plate, k, margins, Color(0.75, 0.77, 0.86)))
	button.add_theme_stylebox_override("focus", KIT.focus_ring(roundi(12 * k), roundi(2.5 * k)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, face)


func _skin_race_kinds() -> void:
	if _skin_scale <= 0.0:
		return
	var k := _skin_scale
	var margins := Vector4(10, 5, 10, 6)
	if KIT.themed("row_stat", k, margins) == null:
		return
	for id in _race_kind_buttons:
		var kind: Button = _race_kind_buttons[id]
		var plate := "button_secondary_blue" if id == current_mode else "row_stat"
		kind.add_theme_stylebox_override("normal", KIT.themed(plate, k, margins))
		kind.add_theme_stylebox_override("hover", KIT.themed(plate, k, margins, Color(1.12, 1.12, 1.12)))
		kind.add_theme_stylebox_override("pressed", KIT.themed(plate, k, margins, Color(0.75, 0.77, 0.86)))
		kind.add_theme_stylebox_override("focus", KIT.focus_ring(roundi(10 * k), roundi(2.5 * k)))
		kind.add_theme_constant_override("icon_max_width", roundi((30 if _race_kinds_compact else 34) * k))
		kind.add_theme_constant_override("h_separation", roundi(8 * k))


## Querformat: drei Spalten nur mit Namen, damit alle fünf Rennarten und START
## ohne Scrollen sichtbar sind. Hochformat: eine Spalte mit Beschreibung.
func set_race_kind_layout(landscape: bool, short: bool) -> void:
	_race_kinds.columns = 3 if landscape else 1
	_race_kinds_compact = landscape and short
	_refresh_race_kinds()


func _open_overlay(kind: String) -> void:
	for child in _overlay_list.get_children():
		if child == _race_kinds:
			continue
		_overlay_list.remove_child(child)
		child.queue_free()
	_race_kinds.visible = kind == "race"
	_live_start.visible = kind == "race"
	if kind == "race":
		_overlay_title.text = "Rennarten"
		_overlay_line("Wähle deine Rennart. START beginnt das Rennen.", Color("d9e6ff"))
		_overlay_list.move_child(_race_kinds, -1)
		_refresh_race_kinds()
		_overlay.visible = true
		_overlay.move_to_front()
		_layout()
		for tile in _navigation.get_children():
			tile.set_active(tile.name == "Dock_race")
		return
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
		var text := "Frei: %s %s (%d ★)" % [entry.kind, entry.name, entry.stars]
		if not done:
			text = "Noch %d ★: %s %s" % [int(entry.stars) - total_stars, entry.kind, entry.name]
		if KIT.has("icon_star_gold"):
			_overlay_line(text, Color("ffe08a") if done else Color("b8c8e8"), "icon_star_gold" if done else "icon_lock")
		else:
			_overlay_line(("★ " if done else "") + text, Color("ffd568") if done else Color("9fb4d8"))
	_overlay.visible = true
	_overlay.move_to_front()
	_layout()
	for tile in _navigation.get_children():
		tile.set_active(tile.name == ("Dock_season" if kind == "season" else "Dock_rewards"))


## Zeile im Overlay; mit `icon` (Kit-Icon) steht links ein gerendertes Zeichen.
func _overlay_line(text: String, color: Color, icon: String = "") -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	var picture := KIT.texture(icon) if not icon.is_empty() else null
	if picture == null:
		_overlay_list.add_child(label)
		return
	var row := HBoxContainer.new()
	row.set_meta("overlay_row", true)
	var image := TextureRect.new()
	image.texture = picture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size = Vector2(26, 26)
	row.add_child(image)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_overlay_list.add_child(row)


## Schrift und Icons der Overlay-Zeilen im dp-Maßstab.
func scale_overlay_lines(k: float, font_dp: float) -> void:
	for child in _overlay_list.get_children():
		if child == _race_kinds:
			continue
		if child.has_meta("overlay_row"):
			child.add_theme_constant_override("separation", roundi(8 * k))
			child.get_child(0).custom_minimum_size = Vector2(26, 26) * k
			child.get_child(1).add_theme_font_size_override("font_size", roundi(font_dp * k))
		else:
			child.add_theme_font_size_override("font_size", roundi(font_dp * k))


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
