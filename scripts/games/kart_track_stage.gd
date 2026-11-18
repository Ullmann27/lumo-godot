extends Control
## Streckenwahl als Bühne der gewählten Rennwelt (Kart-Menü, Abschnitt „Strecken“).
## Oben das größte Bild der Seite: ein nah an der Fahrbahn gerendertes Standbild der
## echten Strecke, bei vorhandenem Clip eine kurze stumme Kamerafahrt darüber.
## Name und Ziel unten links, Karte aus der echten Mittellinie oben rechts.
## Darunter (Hochformat) bzw. rechts (Querformat) die bebilderten Streckenkarten.
## Die Rundkurs-Übersicht (3D) bleibt über „Strecke ansehen“ erreichbar.
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const CARD = preload("res://scripts/games/kart_track_card.gd")
const CHOICE = preload("res://scripts/games/kart_menu_choice.gd")
const PLAYER = preload("res://scripts/games/kart_track_preview_player.gd")
const STAGE_DIR := "res://assets/kart/track_stage/"
const FALLBACK_DIR := "res://assets/kart/neon_previews/"
const ACCENT := Color("4fe3d2")
const MAPS := "res://scripts/games/kart_track_maps.gd"
var menu: Control
var track_id := ""
var overview := false
var active := false
var backdrop: TextureRect
var stage_frame: PanelContainer
var still: TextureRect
var previous_still: TextureRect
var player
var scrim: TextureRect
var info_panel: VBoxContainer
var world_label: Label
var name_label: Label
var goal_label: Label
var progress_label: Label
var map_panel: PanelContainer
var map_view: Control
var overview_button: Button
var load_ms := 0.0
var _map_points: PackedVector2Array = PackedVector2Array()
var _map_track := ""
var _map_cache: Dictionary = {}
var _saved_update_mode := -1
var _podium_hidden := false
var _fade: Tween
var _scale := 1.0
var _portrait := true


func _init() -> void:
	name = "TrackStage"
	set_meta("kart_self_sized", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	backdrop = TextureRect.new()
	backdrop.name = "StageBackdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.set_color(0, Color("0a2a5e"))
	gradient.set_color(1, Color("030c24"))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.fill = GradientTexture2D.FILL_RADIAL
	fill.fill_from = Vector2(0.5, 0.25)
	fill.fill_to = Vector2(1.15, 1.1)
	fill.width = 256
	fill.height = 256
	backdrop.texture = fill
	add_child(backdrop)
	stage_frame = PanelContainer.new()
	stage_frame.name = "StagePicture"
	stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.clip_contents = true
	add_child(stage_frame)
	previous_still = _picture("PreviousStill")
	still = _picture("Still")
	player = PLAYER.new()
	player.name = "TrackPreviewPlayer"
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_frame.add_child(player)
	scrim = TextureRect.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var shade := Gradient.new()
	shade.set_color(0, Color(0.01, 0.03, 0.1, 0.0))
	shade.set_color(1, Color(0.01, 0.03, 0.1, 0.82))
	shade.add_point(0.55, Color(0.01, 0.03, 0.1, 0.1))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = shade
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(0, 1)
	shade_texture.width = 8
	shade_texture.height = 128
	scrim.texture = shade_texture
	stage_frame.add_child(scrim)
	var border := Panel.new()
	border.name = "StageBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_frame.add_child(border)
	info_panel = VBoxContainer.new()
	info_panel.name = "TrackInfo"
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_panel)
	world_label = _text("RENNWELT", UI.BODY, ACCENT)
	name_label = _text("", UI.HEADING, UI.WHITE)
	goal_label = _text("", UI.BODY, Color("eef7ff"))
	progress_label = _text("", UI.HEADING, UI.GOLD)
	for label in [world_label, name_label, goal_label, progress_label]:
		label.add_theme_color_override("font_outline_color", Color("020b20"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		info_panel.add_child(label)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel = PanelContainer.new()
	map_panel.name = "TrackMap"
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_panel)
	map_view = Control.new()
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.draw.connect(_draw_map)
	map_panel.add_child(map_view)
	overview_button = Button.new()
	overview_button.name = "TrackOverview"
	overview_button.text = "Strecke ansehen"
	overview_button.focus_mode = Control.FOCUS_ALL
	overview_button.add_theme_font_override("font", UI.HEADING)
	overview_button.pressed.connect(toggle_overview)
	add_child(overview_button)


func _picture(node_name: String) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = node_name
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_frame.add_child(picture)
	return picture


func _text(value: String, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	return label


static func still_path(id: String) -> String:
	var own := STAGE_DIR + id + ".webp"
	if ResourceLoader.exists(own):
		return own
	return FALLBACK_DIR + id + ".webp"


func attach(owner_menu: Control) -> void:
	menu = owner_menu


## Gilt die Bühne gerade? Nur im Abschnitt „Strecken“ für Rennen auf einer Strecke.
func wanted() -> bool:
	if menu == null or not menu.is_visible_in_tree():
		return false
	if int(menu.step) != 3 or bool(menu.get("_landing_active")):
		return false
	if is_instance_valid(menu.get("workshop_view")):
		return false
	return str(menu.setup.mode) not in ["cup", "arena"]


func card_for(id: String) -> Control:
	if menu == null:
		return null
	for child in menu.choices.get_children():
		if child is CARD and child.track_id == id:
			return child
	return null


## Solange das Bild die Strecke zeigt, bleibt das schon gebaute 3D-Diorama stehen;
## die passende Welt entsteht erst für „Strecke ansehen“ (siehe _apply_overview).
func defers_world() -> bool:
	return wanted() and not overview and is_instance_valid(menu.get("preview_world"))


func picture_rect() -> Rect2:
	return stage_frame.get_global_rect()


func is_preview_playing() -> bool:
	return player.is_playing()


func preview_player_count() -> int:
	return find_children("*", "VideoStreamPlayer", true, false).size()


## Nach jedem Neuaufbau der Auswahl: Menükarten gegen Bildkarten tauschen und
## Bild, Name, Ziel und Karte gemeinsam auf die gewählte Strecke setzen.
func sync() -> void:
	if menu == null:
		return
	if int(menu.step) == 3:
		_replace_cards()
	_update_state()


func _replace_cards() -> void:
	if str(menu.setup.mode) in ["cup", "arena"]:
		return
	var tracks: Array = menu.CATALOG.TRACKS
	var difficulty := str(menu.setup.difficulty)
	var children: Array = menu.choices.get_children()
	for index in range(mini(children.size(), tracks.size())):
		var old = children[index]
		var entry: Dictionary = tracks[index]
		var id := str(entry.id)
		var card
		if old is CARD:
			card = old
		elif old is CHOICE:
			card = CARD.new()
			card.track_id = id
			card.title = str(entry.name)
			card.caption = old.caption
			card.disabled = old.disabled
			card.reduced_motion = bool(menu.reduced_motion)
			card.accent = entry.get("color", ACCENT)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.pressed.connect(func(): menu._select("track", id))
			menu.choices.add_child(card)
			menu.choices.move_child(card, index)
			menu.choices.remove_child(old)
			old.queue_free()
		else:
			continue
		card.selected = str(menu.setup.track) == id
		card.achieved = menu.track_pass.stage(id, difficulty) if menu.track_pass != null else 0
		card.locked_text = (
			"" if not card.disabled else "Ab %d Sternen" % int(entry.get("unlock", 0))
		)
		card.set_tall(_portrait)
		card.refresh_state()


func _update_state() -> void:
	var want := wanted()
	if want != active:
		active = want
		if not active:
			overview = false
	_sync_podium()
	visible = active
	if not active:
		player.set_paused(true)
		_restore_viewport()
		return
	var id := str(menu.setup.track)
	if id != track_id:
		_show_track(id)
	_update_texts()
	_apply_overview()


func _show_track(id: String) -> void:
	var started := Time.get_ticks_usec()
	if is_instance_valid(_fade):
		_fade.kill()
	var reduced := bool(menu.reduced_motion)
	if not reduced and still.texture != null:
		previous_still.texture = still.texture
		previous_still.modulate.a = 1.0
	else:
		previous_still.texture = null
	var path := still_path(id)
	still.texture = load(path) if ResourceLoader.exists(path) else null
	track_id = id
	still.modulate.a = 1.0
	if previous_still.texture != null:
		_fade = create_tween()
		_fade.tween_property(previous_still, "modulate:a", 0.0, 0.22)
		_fade.tween_callback(func(): previous_still.texture = null)
	player.reduced_motion = reduced
	player.set_paused(false)
	player.show_track(id)
	_map_track = ""
	load_ms = (Time.get_ticks_usec() - started) / 1000.0


func _update_texts() -> void:
	var entry: Dictionary = menu.CATALOG.entry(menu.CATALOG.TRACKS, track_id)
	name_label.text = str(entry.get("name", track_id))
	var tag := str(entry.get("tag", "")).split(" · ")[0]
	world_label.text = tag if not tag.is_empty() else "RENNWELT"
	var achieved := 0
	if menu.track_pass != null:
		achieved = menu.track_pass.stage(track_id, str(menu.setup.difficulty))
	goal_label.text = (
		(
			"Alle drei Ziele geschafft!"
			if achieved >= 3
			else "Nächstes Ziel: " + menu.track_pass.goal_text(achieved)
		)
		if menu.track_pass != null
		else str(entry.get("description", ""))
	)
	progress_label.text = "%d von 3 Zielen" % achieved
	progress_label.visible = menu.track_pass != null
	_refresh_map()


func _refresh_map() -> void:
	if _map_track == track_id:
		return
	var maps := _maps()
	if maps.has(track_id):
		_map_points = PackedVector2Array()
		for point in maps[track_id]:
			_map_points.append(Vector2(float(point[0]), float(point[1])))
		_map_track = track_id
		map_view.queue_redraw()
		return
	var world = menu.get("preview_world")
	if (
		_map_track == track_id
		or not is_instance_valid(world)
		or str(world.get("track_id")) != track_id
	):
		return
	var route: Curve3D = world.get("curve")
	if route == null or route.get_baked_length() <= 0.0:
		return
	_map_points = PackedVector2Array()
	for sample in range(96):
		var point := route.sample_baked(route.get_baked_length() * sample / 96.0)
		_map_points.append(Vector2(point.x, point.z))
	_map_track = track_id
	map_view.queue_redraw()


## Mittellinien aller Strecken (vom Render-Skript aus den echten Kurven geschrieben).
func _maps() -> Dictionary:
	if _map_cache.is_empty() and ResourceLoader.exists(MAPS):
		_map_cache = load(MAPS).POINTS
	return _map_cache


func _draw_map() -> void:
	if _map_points.size() < 3:
		return
	var bounds := Rect2(_map_points[0], Vector2.ZERO)
	for point in _map_points:
		bounds = bounds.expand(point)
	var area := Rect2(Vector2.ZERO, map_view.size).grow(-6.0 * _scale)
	if not bounds.has_area() or not area.has_area():
		return
	var fit := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var offset := area.get_center() - bounds.get_center() * fit
	var line := PackedVector2Array()
	for point in _map_points:
		line.append(point * fit + offset)
	line.append(line[0])
	map_view.draw_polyline(line, Color(0, 0.02, 0.08, 0.7), 8.0 * _scale, true)
	map_view.draw_polyline(line, Color("f2fbff"), 4.0 * _scale, true)
	map_view.draw_circle(line[0], 6.0 * _scale, UI.GOLD)


func toggle_overview() -> void:
	overview = not overview
	_apply_overview()
	if menu != null and menu.has_method("_apply_responsive_layout"):
		menu._apply_responsive_layout.call_deferred()


func _apply_overview() -> void:
	if not active:
		return
	overview_button.text = "Bild zeigen" if overview else "Strecke ansehen"
	for control in [backdrop, stage_frame, info_panel, map_panel]:
		control.visible = not overview
	mouse_filter = Control.MOUSE_FILTER_IGNORE if overview else Control.MOUSE_FILTER_STOP
	player.set_paused(overview or not bool(menu.get("_application_active")))
	var viewport: SubViewport = menu.preview_viewport
	if overview:
		var world = menu.get("preview_world")
		if not is_instance_valid(world) or str(world.get("track_id")) != track_id:
			menu.preview_signature = ""
			menu._refresh_preview()
		_restore_viewport()
	else:
		# Das 3D-Diorama ist vollständig verdeckt: nicht weiter rendern.
		if _saved_update_mode < 0:
			_saved_update_mode = viewport.render_target_update_mode
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _restore_viewport() -> void:
	if _saved_update_mode >= 0 and menu != null and is_instance_valid(menu.preview_viewport):
		menu.preview_viewport.render_target_update_mode = _saved_update_mode
	_saved_update_mode = -1


## Der leuchtende Garagenteller gehört nicht in die Streckenwahl (auch nicht in die Übersicht).
func _sync_podium() -> void:
	var hide_podium: bool = (
		menu != null and int(menu.step) == 3 and not bool(menu.get("_landing_active"))
	)
	if hide_podium == _podium_hidden:
		return
	_podium_hidden = hide_podium
	for node_name in ["TranslucentHeroStage", "HeroStageUnderlayer"]:
		var node := menu.preview.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = not hide_podium
	for ring in menu.stage_rings:
		ring.visible = not hide_podium


func _process(_delta: float) -> void:
	if menu == null:
		return
	var want := wanted()
	if want != active or (active and str(menu.setup.track) != track_id):
		_update_state()
	elif active:
		player.set_paused(overview or not bool(menu.get("_application_active")))
	_sync_podium()


## Aufteilung der Seite in dp (Werte wie im übrigen Menü). Gibt das Rechteck der
## Kartenauswahl zurück; die Bühne selbst nimmt den größten zusammenhängenden Rest.
func layout(
	available: Vector2, top: float, footer_y: float, margin: float, portrait: bool, ui_scale: float
) -> Rect2:
	_scale = ui_scale
	_portrait = portrait
	var stage_rect: Rect2
	var cards_rect: Rect2
	if portrait:
		var cards_height := clampf(available.y * 0.27, 176.0, 232.0)
		var cards_y := footer_y - 12.0 - cards_height
		stage_rect = Rect2(margin, top, available.x - margin * 2, cards_y - 14.0 - top)
		cards_rect = Rect2(margin, cards_y, available.x - margin * 2, cards_height)
	else:
		var cards_width := clampf(available.x * 0.38, 260.0, 400.0)
		var stage_width := available.x - margin * 3 - cards_width
		stage_rect = Rect2(margin, top, stage_width, footer_y - 12.0 - top)
		cards_rect = Rect2(margin * 2 + stage_width, top, cards_width, footer_y - 12.0 - top)
	position = Vector2.ZERO
	size = available * ui_scale
	stage_frame.position = stage_rect.position * ui_scale
	stage_frame.size = stage_rect.size * ui_scale
	var radius := roundi(26 * ui_scale)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("0b2149")
	frame_style.set_corner_radius_all(radius)
	stage_frame.add_theme_stylebox_override("panel", frame_style)
	var border_style := StyleBoxFlat.new()
	border_style.draw_center = false
	border_style.border_color = Color(ACCENT, 0.75)
	border_style.set_border_width_all(roundi(3 * ui_scale))
	border_style.set_corner_radius_all(radius)
	(stage_frame.get_node("StageBorder") as Panel).add_theme_stylebox_override(
		"panel", border_style
	)
	# Unten links: Name und Ziel in der ruhigen, abgedunkelten Ecke.
	var pad := 18.0
	var info_width := minf(stage_rect.size.x - pad * 2 - 150.0, 430.0)
	world_label.add_theme_font_size_override("font_size", roundi(14 * ui_scale))
	name_label.add_theme_font_size_override(
		"font_size", roundi((34 if stage_rect.size.x > 480 else 30) * ui_scale)
	)
	goal_label.add_theme_font_size_override("font_size", roundi(18 * ui_scale))
	progress_label.add_theme_font_size_override("font_size", roundi(18 * ui_scale))
	for label in [world_label, name_label, goal_label, progress_label]:
		label.add_theme_constant_override("outline_size", roundi(4 * ui_scale))
		label.add_theme_constant_override("shadow_offset_y", roundi(2 * ui_scale))
	info_panel.add_theme_constant_override("separation", roundi(2 * ui_scale))
	info_panel.size = Vector2(info_width, 0) * ui_scale
	info_panel.custom_minimum_size = Vector2(info_width, 0) * ui_scale
	info_panel.reset_size()
	var info_height := info_panel.get_combined_minimum_size().y / ui_scale
	info_panel.position = (
		(stage_rect.position + Vector2(pad, stage_rect.size.y - pad - info_height)) * ui_scale
	)
	var scrim_height := minf(stage_rect.size.y, info_height + pad * 2 + 70.0)
	scrim.position = Vector2(0, stage_rect.size.y - scrim_height) * ui_scale
	scrim.size = Vector2(stage_rect.size.x, scrim_height) * ui_scale
	for picture in [still, previous_still, player, stage_frame.get_node("StageBorder")]:
		picture.position = Vector2.ZERO
		picture.size = stage_rect.size * ui_scale
	# Oben rechts: Karte aus der echten Mittellinie.
	var map_size := Vector2(clampf(stage_rect.size.x * 0.24, 104.0, 150.0), 0)
	map_size.y = map_size.x * 0.72
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.01, 0.05, 0.14, 0.62)
	map_style.border_color = Color(1, 1, 1, 0.28)
	map_style.set_border_width_all(roundi(1.5 * ui_scale))
	map_style.set_corner_radius_all(roundi(16 * ui_scale))
	map_panel.add_theme_stylebox_override("panel", map_style)
	map_panel.position = (
		(stage_rect.position + Vector2(stage_rect.size.x - 14.0 - map_size.x, 14.0)) * ui_scale
	)
	map_panel.size = map_size * ui_scale
	map_view.custom_minimum_size = Vector2.ZERO
	map_view.queue_redraw()
	# Unten rechts: zur Rundkurs-Übersicht (48 dp Touchfläche).
	UI.premium_button(overview_button, ACCENT)
	overview_button.add_theme_font_size_override("font_size", roundi(15 * ui_scale))
	overview_button.custom_minimum_size = Vector2(140, 48) * ui_scale
	overview_button.reset_size()
	var button_size := overview_button.get_combined_minimum_size() / ui_scale
	overview_button.position = (stage_rect.end - Vector2(14.0, 14.0) - button_size) * ui_scale
	overview_button.size = button_size * ui_scale
	if overview:
		# In der Übersicht steht der Knopf über dem freien 3D-Bereich.
		overview_button.position.y = (stage_rect.position.y + 14.0) * ui_scale
	return cards_rect


## Karten in der Auswahl ordnen: Hochformat waagrechte Bildleiste, Querformat Liste.
func layout_cards(cards_rect: Rect2, ui_scale: float) -> void:
	var drawer := menu.choices.get_parent() as ScrollContainer
	menu.choices.vertical = not _portrait
	drawer.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if _portrait else ScrollContainer.SCROLL_MODE_DISABLED
	)
	drawer.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED if _portrait else ScrollContainer.SCROLL_MODE_AUTO
	)
	menu.choices.add_theme_constant_override("separation", roundi(12 * ui_scale))
	var card_size: Vector2
	if _portrait:
		var height := cards_rect.size.y - 6.0
		card_size = Vector2(clampf((height - 80.0) * 16.0 / 9.0 + 16.0, 200.0, 300.0), height)
	else:
		card_size = Vector2(0, clampf(cards_rect.size.y / 4.6, 86.0, 112.0))
	for child in menu.choices.get_children():
		if child is CARD:
			child.set_tall(_portrait)
			child.size_flags_horizontal = (
				Control.SIZE_FILL if _portrait else Control.SIZE_EXPAND_FILL
			)
			child.custom_minimum_size = card_size * ui_scale
			child.apply_size(ui_scale)


## Beim Verlassen des Abschnitts: Auswahl wieder als senkrechte Liste.
func release_drawer() -> void:
	if menu == null:
		return
	var drawer := menu.choices.get_parent() as ScrollContainer
	menu.choices.vertical = true
	drawer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and player != null:
		player.stop()
