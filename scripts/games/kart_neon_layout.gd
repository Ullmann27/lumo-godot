extends RefCounted
## Layout des Neon-Hauptmenüs in dp. Hochformat (Handy), fast quadratisch (Fold7 innen),
## Querformat hoch (Tablet/Fold quer) und flaches Querformat (Handy quer).
## Touch-Ziele: Modus-Kacheln >= 64 dp, Leiste >= 56 dp breit und 64 dp hoch, Chips >= 48 dp.
const MIN_TOUCH := 48.0


static func _place(control: Control, rect: Rect2, k: float) -> void:
	control.position = (rect.position * k).round()
	control.size = (rect.size * k).round()
	if "ui_scale" in control:
		control.ui_scale = k
	control.queue_redraw()


static func arrange(hub: Control) -> void:
	var viewport_size := hub.get_viewport_rect().size
	var runtime: Node = hub.get_tree().root.get_node_or_null("MobileRuntime")
	var density := 1.0
	if runtime != null and runtime.has_method("get_ui_density"):
		density = maxf(float(runtime.call("get_ui_density")), 0.25)
	var window_dp := Vector2(hub.get_window().size) / density
	if window_dp.x <= 0.0 or window_dp.y <= 0.0 or hub.size.x <= 0.0 or hub.size.y <= 0.0:
		return
	var k := maxf(viewport_size.x / window_dp.x, viewport_size.y / window_dp.y)
	k = maxf(k, 0.25)
	hub._layout_scale = k
	hub._layout_root.size = hub.size
	hub._veil.position = Vector2.ZERO
	hub._veil.size = hub.size
	var area := hub.size / k
	var landscape := area.x >= area.y * 1.15
	var short := landscape and area.y < 560.0
	var m := 10.0
	var g := 8.0
	var header_h := 52.0 if short else 62.0
	var nav_h := 60.0 if short else 66.0
	_header(hub, Rect2(m, m, area.x - 2 * m, header_h), k)
	var nav_rect := Rect2(m, area.y - m - nav_h, area.x - 2 * m, nav_h)
	_nav(hub, nav_rect, k, short)
	var top := m + header_h + g
	var bottom := nav_rect.position.y - g
	if landscape:
		_landscape(hub, Rect2(m, top, area.x - 2 * m, bottom - top), k, g, short)
	else:
		_portrait(hub, Rect2(m, top, area.x - 2 * m, bottom - top), k, g)
	if hub._overlay.visible:
		var w := minf(area.x - 2 * m, 560.0)
		var h := minf(area.y - 2 * m, 620.0)
		hub._overlay.position = (Vector2((area.x - w) * 0.5, (area.y - h) * 0.5) * k).round()
		hub._overlay.size = (Vector2(w, h) * k).round()
		hub._overlay.scale = Vector2.ONE
		_scale_overlay(hub, k)


static func _scale_overlay(hub: Control, k: float) -> void:
	hub._overlay_title.add_theme_font_size_override("font_size", roundi(24 * k))
	for label in hub._overlay_list.get_children():
		label.add_theme_font_size_override("font_size", roundi(17 * k))
	var close: Button = hub._overlay.find_child("CloseOverlay", true, false)
	close.custom_minimum_size = Vector2(120, 56) * k
	close.add_theme_font_size_override("font_size", roundi(18 * k))
	var skin: StyleBoxFlat = hub._overlay.get_theme_stylebox("panel")
	skin.set_content_margin_all(16 * k)
	skin.set_corner_radius_all(roundi(20 * k))


static func _header(hub: Control, r: Rect2, k: float) -> void:
	var narrow := r.size.x < 420.0
	var chip := MIN_TOUCH
	_place(hub._back, Rect2(r.position.x, r.position.y + (r.size.y - chip) * 0.5, chip, chip), k)
	var logo_w := 78.0 if narrow else clampf(r.size.x * 0.27, 110.0, 190.0)
	_place(hub._logo, Rect2(r.position.x + chip + 2, r.position.y - 2, logo_w, r.size.y + 4), k)
	var stars_w := 70.0 if narrow else 96.0
	_place(hub._stars_chip, Rect2(r.end.x - stars_w, r.position.y + (r.size.y - chip) * 0.5, stars_w, chip), k)
	var px := r.position.x + chip + logo_w + 6
	var card_w := minf(r.end.x - stars_w - 6 - px, 340.0)
	var card_h := minf(r.size.y, 50.0 if narrow else 56.0)
	_place(hub._player, Rect2(px, r.position.y + (r.size.y - card_h) * 0.5, maxf(card_w, 96.0), card_h), k)


## Auf schmalen Handys bleiben nur Ziele in der Leiste, die nicht schon als große Kachel da sind.
const NARROW_NAV := ["Dock_home", "Dock_race", "Open_garage", "Open_world", "Dock_rewards", "Landing_settings"]


static func _nav(hub: Control, r: Rect2, k: float, short: bool) -> void:
	_place(hub._dock, r, k)
	var visible: Array = []
	for tile in hub._navigation.get_children():
		var keep: bool = r.size.x / 9.0 >= 58.0 or str(tile.name) in NARROW_NAV
		tile.visible = keep
		if keep:
			visible.append(tile)
	var count := visible.size()
	var sep := clampf((r.size.x - 56.0 * count) / maxf(count - 1, 1), 0.0, 4.0)
	var item_w := maxf(56.0, (r.size.x - sep * (count - 1)) / count)
	hub._navigation.add_theme_constant_override("separation", floori(sep * k))
	for tile in visible:
		tile.custom_minimum_size = (Vector2(item_w, r.size.y) * k).floor()
		tile.ui_scale = k
		tile.compact = short
		tile.queue_redraw()
	hub._navigation.custom_minimum_size = Vector2(0, r.size.y * k)


static func _hero_and_rotators(hub: Control, r: Rect2, k: float) -> void:
	hub._stage_bounds = Rect2(r.position * k, r.size * k)
	var b := MIN_TOUCH
	_place(hub._rotation_left, Rect2(r.position.x + 4, r.end.y - b - 4, b, b), k)
	_place(hub._rotation_right, Rect2(r.end.x - b - 4, r.end.y - b - 4, b, b), k)


static func _highlight(hub: Control, r: Rect2, k: float, strip: bool) -> void:
	_place(hub._highlight, r, k)
	var skin: StyleBoxFlat = hub._highlight.get_theme_stylebox("panel")
	skin.set_corner_radius_all(roundi(16 * k))
	skin.set_border_width_all(maxi(1, roundi(2 * k)))
	skin.shadow_size = roundi(8 * k)
	var pad := 4.0 if strip else 8.0
	var inner := Rect2(pad, pad, r.size.x - 2 * pad, r.size.y - 2 * pad)
	var thumbs: Array = []
	for id in hub._track_buttons:
		# Wie im Zielbild: groß die gewählte Strecke, klein die übrigen drei.
		var thumb: Control = hub._track_buttons[id]
		thumb.visible = id != hub._featured_track
		if thumb.visible:
			thumbs.append(thumb)
	if strip:
		hub._highlight_title.visible = false
		hub._dots.visible = false
		var big_w := inner.size.x * 0.4
		_place(hub._highlight_pick, Rect2(inner.position, Vector2(big_w, inner.size.y)), k)
		var tw := (inner.size.x - big_w - 6.0 * thumbs.size()) / maxf(thumbs.size(), 1)
		for i in range(thumbs.size()):
			_place(thumbs[i], Rect2(inner.position.x + big_w + 6 + i * (tw + 6), inner.position.y, tw, inner.size.y), k)
		return
	hub._highlight_title.visible = true
	hub._dots.visible = true
	var title_h := 26.0
	hub._highlight_title.position = (Vector2(inner.position.x + 4, inner.position.y) * k).round()
	hub._highlight_title.size = (Vector2(inner.size.x, title_h) * k).round()
	hub._highlight_title.add_theme_font_size_override("font_size", roundi(17 * k))
	var dots_h := 10.0
	var thumb_h := clampf(inner.size.y * 0.26, 48.0, 84.0)
	var big_h := inner.size.y - title_h - thumb_h - dots_h - 12
	_place(hub._highlight_pick, Rect2(inner.position.x, inner.position.y + title_h + 2, inner.size.x, big_h), k)
	var ty := inner.position.y + title_h + 2 + big_h + 6
	var tw2 := (inner.size.x - 5.0 * (thumbs.size() - 1)) / maxf(thumbs.size(), 1)
	for i in range(thumbs.size()):
		_place(thumbs[i], Rect2(inner.position.x + i * (tw2 + 5), ty, tw2, thumb_h), k)
	_place(hub._dots, Rect2(inner.position.x, ty + thumb_h + 2, inner.size.x, dots_h), k)


static func _mode_row(hub: Control, r: Rect2, k: float, columns: int, compact: bool) -> void:
	var ids := ["race", "cup", "season", "event"]
	var rows := ceili(4.0 / columns)
	var w := (r.size.x - 8.0 * (columns - 1)) / columns
	var h := (r.size.y - 8.0 * (rows - 1)) / rows
	for i in range(4):
		var tile = hub._mode_tiles[ids[i]]
		tile.compact = compact
		var col := i % columns
		var row := i / columns
		_place(tile, Rect2(r.position.x + col * (w + 8), r.position.y + row * (h + 8), w, h), k)


static func _feature_row(hub: Control, r: Rect2, k: float, compact: bool) -> void:
	var ids := ["garage", "world", "rewards"]
	var w := (r.size.x - 16.0) / 3.0
	for i in range(3):
		var tile = hub._feature_tiles[ids[i]]
		tile.compact = compact
		_place(tile, Rect2(r.position.x + i * (w + 8), r.position.y, w, r.size.y), k)


static func _portrait(hub: Control, r: Rect2, k: float, g: float) -> void:
	var season_h := clampf(r.size.y * 0.1, 58.0, 76.0)
	var mode_h := clampf(r.size.y * 0.2, 88.0, 138.0)
	var feature_h := clampf(r.size.y * 0.15, 66.0, 116.0)
	var top_h := r.size.y - season_h - mode_h - feature_h - 3 * g
	if top_h < 210.0:
		var deficit := 210.0 - top_h
		feature_h = maxf(64.0, feature_h - deficit * 0.5)
		mode_h = maxf(76.0, mode_h - deficit * 0.5)
		top_h = r.size.y - season_h - mode_h - feature_h - 3 * g
	var hero_w := r.size.x * (0.5 if r.size.x >= 560.0 else 0.46)
	_hero_and_rotators(hub, Rect2(r.position, Vector2(hero_w - g * 0.5, top_h)), k)
	_highlight(hub, Rect2(r.position.x + hero_w + g * 0.5, r.position.y, r.size.x - hero_w - g * 0.5, top_h), k, false)
	var y := r.position.y + top_h + g
	_mode_row(hub, Rect2(r.position.x, y, r.size.x, mode_h), k, 4, r.size.x < 380.0)
	y += mode_h + g
	_feature_row(hub, Rect2(r.position.x, y, r.size.x, feature_h), k, feature_h < 80.0)
	y += feature_h + g
	_place(hub._progress, Rect2(r.position.x, y, r.size.x, season_h), k)


static func _landscape(hub: Control, r: Rect2, k: float, g: float, short: bool) -> void:
	var left_w := r.size.x * (0.42 if short else 0.44)
	var right := Rect2(r.position.x + left_w + g, r.position.y, r.size.x - left_w - g, r.size.y)
	if short:
		var season_h := 52.0
		_hero_and_rotators(hub, Rect2(r.position, Vector2(left_w, r.size.y - season_h - g)), k)
		_place(hub._progress, Rect2(r.position.x, r.end.y - season_h, left_w, season_h), k)
		var strip_h := clampf(right.size.y * 0.26, 60.0, 80.0)
		var feature_h := clampf(right.size.y * 0.22, 54.0, 72.0)
		var modes_h := right.size.y - strip_h - feature_h - 2 * g
		_highlight(hub, Rect2(right.position, Vector2(right.size.x, strip_h)), k, true)
		_mode_row(hub, Rect2(right.position.x, right.position.y + strip_h + g, right.size.x, modes_h), k, 4 if modes_h < 150.0 else 2, true)
		_feature_row(hub, Rect2(right.position.x, right.end.y - feature_h, right.size.x, feature_h), k, true)
		return
	var hero_h := r.size.y * 0.56
	_hero_and_rotators(hub, Rect2(r.position, Vector2(left_w, hero_h)), k)
	_highlight(hub, Rect2(r.position.x, r.position.y + hero_h + g, left_w, r.size.y - hero_h - g), k, false)
	var season_h := clampf(right.size.y * 0.13, 58.0, 80.0)
	var feature_h := clampf(right.size.y * 0.2, 70.0, 120.0)
	var modes_h := right.size.y - season_h - feature_h - 2 * g
	_mode_row(hub, Rect2(right.position, Vector2(right.size.x, modes_h)), k, 2, false)
	_feature_row(hub, Rect2(right.position.x, right.position.y + modes_h + g, right.size.x, feature_h), k, false)
	_place(hub._progress, Rect2(right.position.x, right.end.y - season_h, right.size.x, season_h), k)
