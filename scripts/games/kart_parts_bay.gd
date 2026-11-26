extends Control
## Parts are previewed together on the selected kart and compared to its installed build.
## The configurator and the live product view use separate, measured layout rectangles.

signal parts_mounted(kart_id: String)

const TUNING = preload("res://scripts/games/kart_tuning.gd")
const BARS = preload("res://scripts/games/kart_stat_bars.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const DYNO = preload("res://scripts/games/kart_dyno.gd")
const PART_CATALOG = preload("res://scripts/games/kart_part_catalog.gd")
const BETTER := Color("7dff9a")
const WORSE := Color("ffb26b")
const SAME := Color("c9d6e6")
const THUMBS := "res://assets/kart/production/parts/thumbs/%s.png"
const STAGE = preload("res://scripts/games/kart_garage_interior.gd")
const LIFT_SLOTS := ["tires", "wheel_cover", "brakes", "suspension"]
const LIFT_HEIGHT := 0.42
const COMPACT_WIDTH_DP := 470.0
const INK := Color("f3f6fa")
const ACCENT := Color("78dbbf")
const PANEL := Color("13212e")

var menu
var open_button: Button
var stats_button: Button
var panel: PanelContainer
var stats_panel: PanelContainer
var stats_bars
var stats_title: Label
var title_label: Label
var category: OptionButton
var part_title: Label
var tile_scroll: ScrollContainer
var body_scroll: ScrollContainer
var tile_row: HBoxContainer
## Prüfstand: gemessene Werte vorher → nachher für das angetippte Teil.
var dyno_box: VBoxContainer
var dyno_title: Label
var dyno_grid: GridContainer
var dyno_text: Label
## Letzte Prüfstand-Messung (Tests lesen sie): {metric: [vorher, nachher]}.
var dyno_values: Dictionary = {}
var mount_button: Button
var back_button: Button
var tiles: Dictionary = {}
## Offene Auswahl: Steckplatz -> Teil-ID (noch nicht gespeichert).
var pending: Dictionary = {}
var slot: String = "engine"
var _open := false
var _scale := 1.0
var _inspection: Node3D
var _drawer := Rect2()
var _angle_before := 0.0
var _focused := false
var _compact_portrait := false
var _lift: Node3D
var _lift_kart: Node3D
var _lift_rest := Vector3.ZERO


func setup(owner_menu) -> void:
	menu = owner_menu
	name = "KartPartsBay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	open_button = _action("Teile wechseln", _on_open, Color("ffb13c"), Color("4a2300"))
	open_button.name = "PartsOpenButton"
	add_child(open_button)
	stats_button = _action("Werte", _on_stats, Color(0.03, 0.16, 0.34, 0.94), Color("f2fbff"))
	stats_button.name = "PartsStatsButton"
	add_child(stats_button)
	_build_stats_panel()
	_build_panel()
	_sync()


func is_open() -> bool:
	return _open


func uses_compact_inspection(width_dp: float) -> bool:
	return _focused and width_dp < COMPACT_WIDTH_DP


func _style(fill: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0.02, 0.08, 0.45)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	return style


func _action(text: String, callback: Callable, fill: Color, ink: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(48.0, 48.0)
	button.add_theme_font_override("font", UI.HEADING)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	var normal := _style(fill, fill.lightened(0.45))
	var hover := _style(fill.lightened(0.12), Color.WHITE)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", _style(Color("24394f"), Color("58738c")))
	button.add_theme_color_override("font_disabled_color", Color("cfdae4"))
	button.pressed.connect(callback)
	return button


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI.HEADING)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_stats_panel() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.name = "KartFullStats"
	stats_panel.add_theme_stylebox_override(
		"panel", _style(Color(0.02, 0.08, 0.2, 0.94), Color(0.4, 0.88, 1.0, 0.8))
	)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stats_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	stats_panel.add_child(column)
	stats_title = _label("Fahrwerte", 18, Color("ffe7a8"))
	column.add_child(stats_title)
	stats_bars = BARS.new()
	stats_bars.name = "KartFullStatBars"
	stats_bars.show_labels = true
	stats_bars.show_numbers = true
	stats_bars.label_names = {
		"speed": "Tempo",
		"accel": "Beschleunigung",
		"brake": "Bremsen",
		"handling": "Lenkung",
		"turbo": "Turbo",
	}
	stats_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(stats_bars)
	var close := _action(
		"Schließen", func(): stats_panel.hide(), Color(0.05, 0.3, 0.5, 0.95), Color.WHITE
	)
	close.name = "KartFullStatsClose"
	column.add_child(close)
	stats_panel.hide()


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "PartsConfigurator"
	panel.add_theme_stylebox_override(
		"panel", _style(PANEL, Color("3c5364"), 16)
	)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	title_label = _label("Teilewerkstatt", 20, INK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	category = OptionButton.new()
	category.name = "PartsCategory"
	category.tooltip_text = "Teile-Kategorie wählen"
	category.fit_to_longest_item = false
	category.add_theme_font_override("font", UI.HEADING)
	category.add_theme_stylebox_override("normal", _style(Color("243846"), Color("567a83"), 10))
	category.add_theme_stylebox_override("hover", _style(Color("284855"), ACCENT, 10))
	category.add_theme_stylebox_override("pressed", _style(Color("284855"), ACCENT, 10))
	for id in TUNING.PART_SLOTS:
		category.add_item(TUNING.SLOT_NAMES[id])
	category.item_selected.connect(func(index: int): _on_slot(TUNING.PART_SLOTS[index]))
	head.add_child(category)
	part_title = _label("", 24, INK)
	part_title.name = "InspectedPart"
	part_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(part_title)
	# Steckplätze, Teilebilder und Prüfstand rollen senkrecht, wenn der Konfigurator flach ist
	# (Querformat: linke Spalte); „Zurück“ und „Montieren“ bleiben immer unten sichtbar.
	body_scroll = ScrollContainer.new()
	body_scroll.name = "PartsBodyScroll"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body)
	column = body
	tile_scroll = ScrollContainer.new()
	tile_scroll.name = "PartVariants"
	tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tile_scroll.follow_focus = true
	column.add_child(tile_scroll)
	tile_row = HBoxContainer.new()
	tile_row.add_theme_constant_override("separation", 10)
	tile_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_scroll.add_child(tile_row)
	tile_row.sort_children.connect(_reveal_current_tile, CONNECT_DEFERRED)
	_build_dyno(column)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body_scroll.get_parent().add_child(actions)
	back_button = _action("Zurück", _on_back, Color("253846"), INK)
	back_button.name = "PartsBackButton"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back_button)
	mount_button = _action("Montieren", _on_mount, Color("ffd16b"), Color("30210e"))
	mount_button.name = "PartsMountButton"
	mount_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(mount_button)
	panel.hide()


func _build_dyno(column: VBoxContainer) -> void:
	var frame := PanelContainer.new()
	frame.name = "PartsDyno"
	frame.add_theme_stylebox_override(
		"panel", _style(Color("192c38"), Color("365561"), 12)
	)
	column.add_child(frame)
	dyno_box = VBoxContainer.new()
	dyno_box.add_theme_constant_override("separation", 4)
	frame.add_child(dyno_box)
	dyno_title = _label("Prüfstand", 15, ACCENT)
	dyno_title.clip_text = true
	dyno_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dyno_box.add_child(dyno_title)
	dyno_grid = GridContainer.new()
	dyno_grid.name = "PartsDynoGrid"
	dyno_grid.columns = 3
	dyno_grid.add_theme_constant_override("h_separation", 6)
	dyno_grid.add_theme_constant_override("v_separation", 2)
	dyno_box.add_child(dyno_grid)
	dyno_text = _label("", 15, Color.WHITE)
	dyno_text.name = "PartsDynoText"
	dyno_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dyno_box.add_child(dyno_text)


func _kart_id() -> String:
	return str(menu.setup.kart)


func _vehicle():
	if not is_instance_valid(menu.preview_kart):
		return null
	var production = menu.preview_kart.get("production_vehicle")
	return production if is_instance_valid(production) else null


func _saved(slot_id: String) -> String:
	return menu.workshop.chosen(_kart_id(), slot_id) if menu.workshop != null else "serie"


## Look für die Vorschau: gespeicherter Look plus offene Auswahl.
func preview_look() -> Dictionary:
	var look: Dictionary = menu.workshop.look(_kart_id()) if menu.workshop != null else {}
	for key in pending:
		look[key] = pending[key]
	return look


func _on_open() -> void:
	if _open:
		return
	_angle_before = menu.preview_angle
	menu._choose_preview_view(0, false)
	_open = true
	_focused = false
	pending = {}
	stats_panel.hide()
	_on_slot(slot)
	_sync()
	menu._apply_responsive_layout.call_deferred()


func _on_stats() -> void:
	if menu.workshop == null:
		return
	stats_title.text = "Grundprofil · %s" % str(FLEET.entry(_kart_id()).get("name", ""))
	stats_bars.set_values(FLEET.base_stats(_kart_id()), menu.workshop.bonus(_kart_id()), true)
	stats_panel.visible = not stats_panel.visible


func _on_slot(slot_id: String) -> void:
	slot = slot_id
	_focused = false
	category.select(TUNING.PART_SLOTS.find(slot))
	tile_scroll.scroll_horizontal = 0
	body_scroll.scroll_vertical = 0
	_build_tiles()
	_sync_focus()
	_focus_camera()


func _build_tiles() -> void:
	for child in tile_row.get_children():
		tile_row.remove_child(child)
		child.queue_free()
	tiles.clear()
	var current: String = str(pending.get(slot, _saved(slot)))
	for option in TUNING.options(slot):
		var id: String = str(option.id)
		var tile := Button.new()
		tile.name = "PartTile_%s_%s" % [slot, id]
		tile.toggle_mode = true
		tile.focus_mode = Control.FOCUS_ALL
		tile.set_pressed_no_signal(id == current)
		tile.add_theme_stylebox_override(
			"normal", _style(Color("21333f"), Color("465f6b"), 12)
		)
		tile.add_theme_stylebox_override(
			"hover", _style(Color("28434e"), ACCENT, 12)
		)
		tile.add_theme_stylebox_override(
			"pressed", _style(Color("30483f"), ACCENT, 12)
		)
		tile.add_theme_stylebox_override(
			"hover_pressed", _style(Color("30483f"), ACCENT, 12)
		)
		tile.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 18))
		tile.pressed.connect(_on_tile.bind(id))
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(box)
		var picture := TextureRect.new()
		picture.name = "PartPicture"
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var node_name: String = str(option.get("node", ""))
		var path: String = str(option.get("thumb", THUMBS % (node_name if not node_name.is_empty() else ("Serie_" + slot))))
		if ResourceLoader.exists(path):
			picture.texture = load(path)
		box.add_child(picture)
		var name_label := _label(str(option.name), 14, Color.WHITE)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tile.tooltip_text = str(option.name)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var tag := _label(_tag_text(option, id), 12, _tag_colour(id))
		tag.name = "PartTag"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tag)
		tile_row.add_child(tile)
		tiles[id] = tile
	_apply_tile_size()
	_reveal_current_tile.call_deferred()
	_refresh_dyno()


func _reveal_current_tile() -> void:
	var tile: Button = tiles.get(_current(slot))
	if _open and is_instance_valid(tile) and tile.is_visible_in_tree():
		tile_scroll.ensure_control_visible(tile)


func _is_look_slot(slot_id: String) -> bool:
	return TUNING.LOOK_SLOTS.has(slot_id)


func _workshop():
	return menu.workshop if menu != null else null


func _owned(slot_id: String, id: String) -> bool:
	var workshop = _workshop()
	return workshop == null or workshop.has_option(slot_id, id)


func _tag_text(option: Dictionary, id: String) -> String:
	var mounted: bool = id == _saved(slot)
	if not _owned(slot, id):
		return "★ %d" % int(option.get("cost", 0))
	return "Montiert" if mounted else "Verfügbar"


func _tag_colour(id: String) -> Color:
	return Color("ffd645") if not _owned(slot, id) else Color("9fe8ff")


func _current(slot_id: String) -> String:
	return str(pending.get(slot_id, _saved(slot_id)))


func _on_tile(id: String) -> void:
	if id == _current(slot):
		tiles[id].set_pressed_no_signal(true)
		_enter_focus()
		return
	if id == _saved(slot):
		pending.erase(slot)
	else:
		pending[slot] = id
	for key in tiles:
		tiles[key].set_pressed_no_signal(key == id)
	_reveal_current_tile.call_deferred()
	var vehicle = _vehicle()
	if vehicle != null:
		vehicle.apply_parts(preview_look(), "" if menu.reduced_motion else slot)
	_refresh_dyno()
	_enter_focus()


func _enter_focus() -> void:
	_focused = true
	_sync_focus()
	_focus_camera()
	menu._apply_responsive_layout.call_deferred()


func _sync_focus() -> void:
	var close_view := _compact_portrait and _focused
	category.visible = not close_view
	tile_scroll.visible = not close_view
	part_title.visible = close_view
	if close_view:
		part_title.text = str(TUNING.option(slot, _current(slot)).name)


## Prüfstand: misst das montierte Kart und das Kart mit dem angetippten Teil (kart_dyno.gd,
## dieselben Formeln wie im Rennen) und zeigt die Werte des Steckplatzes vorher → nachher.
func _refresh_dyno() -> void:
	if dyno_grid == null:
		return
	for child in dyno_grid.get_children():
		dyno_grid.remove_child(child)
		child.queue_free()
	dyno_values = {}
	var id: String = _current(slot)
	var option: Dictionary = TUNING.option(slot, id)
	var workshop = _workshop()
	var defaults: Array = PART_CATALOG.SLOT_METRICS.get(slot, [])
	var has_performance_change := false
	for key in pending:
		has_performance_change = has_performance_change or PART_CATALOG.is_slot(key)
	if workshop == null or (defaults.is_empty() and not has_performance_change):
		dyno_title.text = str(option.name)
		dyno_text.text = "Ändert das Aussehen. Die Fahrwerte bleiben gleich."
		_sync_action()
		return
	var before: Dictionary = DYNO.measure(workshop.multipliers(_kart_id()))
	var after: Dictionary = DYNO.measure(workshop.multipliers_with(_kart_id(), pending))
	dyno_title.text = "Prüfstand · Montiert → Vorschau" if has_performance_change else "Prüfstand · Montiert"
	var metrics: Array[String] = []
	# The full combination stays inspectable; significant changes come first.
	for metric in DYNO.display_metrics(defaults, before, after, DYNO.METRICS.size()) + DYNO.METRICS:
		if not metrics.has(metric):
			metrics.append(metric)
	for metric in metrics:
		var old_value := float(before[metric])
		var new_value := float(after[metric])
		dyno_values[metric] = [old_value, new_value]
		var verdict := DYNO.verdict(metric, old_value, new_value)
		var colour := BETTER if verdict > 0 else (WORSE if verdict < 0 else SAME)
		var metric_name := _label(DYNO.LABELS[metric].name, 14, Color("d8ecff"))
		metric_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metric_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dyno_grid.add_child(metric_name)
		var reading := DYNO.format_value(metric, new_value)
		if verdict != 0:
			reading = DYNO.format_value(metric, old_value).get_slice(" ", 0) + " → " + reading
		var value_label := _label(reading, 14, colour)
		value_label.name = "DynoAfter_" + metric
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dyno_grid.add_child(value_label)
		var difference := DYNO.change_word(metric, old_value, new_value)
		if verdict != 0 and absf(old_value) > 0.00001:
			difference = ("%+.1f %%" % ((new_value / old_value - 1.0) * 100.0)).replace(".", ",")
		dyno_grid.add_child(_label(difference, 13, colour))
	dyno_text.text = str(option.name) + " · " + str(option.get("text", "Ändert nur das Aussehen."))
	var combination: Dictionary = workshop.mounted(_kart_id())
	combination.merge(pending, true)
	var notes := PART_CATALOG.limit_notes(combination, TUNING.FINE.changes(workshop.tune(_kart_id())), workshop.multipliers_stock(_kart_id()))
	if not notes.is_empty():
		dyno_text.text += "\n" + "\n".join(notes)
	dyno_text.text += "\nAlle Werte gelten für die ganze Kombination, einschließlich Ausbaustufen und Feineinstellung."
	_apply_dyno_font()
	_sync_action()


func _pending_price() -> int:
	var price := 0
	for key in pending:
		if not _owned(key, pending[key]):
			price += int(TUNING.option(key, pending[key]).cost)
	return price


func _sync_action() -> void:
	title_label.text = "%d Teile gewählt" % pending.size() if pending.size() > 1 else "Teilewerkstatt"
	var price := _pending_price()
	var workshop = _workshop()
	mount_button.text = "Fertig" if pending.is_empty() else "Montieren"
	mount_button.disabled = false
	if price <= 0 or workshop == null:
		return
	if price <= workshop.available():
		mount_button.text = "Freischalten · %d ★" % price
	else:
		mount_button.text = "Noch %d ★ sammeln" % (price - workshop.available())
		mount_button.disabled = true


func _apply_dyno_font() -> void:
	dyno_grid.add_theme_constant_override("h_separation", roundi(8 * _scale))
	dyno_grid.add_theme_constant_override("v_separation", roundi(3 * _scale))
	for label in dyno_grid.get_children():
		label.add_theme_font_size_override("font_size", roundi((13 if label.get_index() % 3 == 2 else 14) * _scale))
	dyno_title.add_theme_font_size_override("font_size", roundi(15 * _scale))
	dyno_text.add_theme_font_size_override("font_size", roundi(14 * _scale))


func _on_mount() -> void:
	var workshop = _workshop()
	if workshop == null:
		return
	if _pending_price() > 0:
		if workshop.unlock_parts(pending):
			_build_tiles()
			if menu.has_method("_refresh_star_label"):
				menu._refresh_star_label()
		return
	if not workshop.mount_parts(_kart_id(), pending):
		return
	pending = {}
	_close()
	parts_mounted.emit(_kart_id())


func _on_back() -> void:
	if _compact_portrait and _focused:
		_focused = false
		_sync_focus()
		_focus_camera()
		menu._apply_responsive_layout.call_deferred()
		return
	pending = {}
	var vehicle = _vehicle()
	if vehicle != null:
		vehicle.apply_parts(preview_look())
	_close()


func _close() -> void:
	_clear_inspection()
	_clear_lift()
	_focused = false
	_open = false
	menu.preview_angle = _angle_before
	menu.preview_pivot.rotation.y = _angle_before
	_sync()
	if menu.has_method("_choose_preview_view"):
		menu._choose_preview_view(0)
	if menu.has_method("_refresh"):
		menu._refresh()


func handle_back() -> bool:
	if stats_panel.visible:
		stats_panel.hide()
		return true
	if _open:
		_on_back()
		return true
	return false


func _clear_inspection() -> void:
	if is_instance_valid(_inspection):
		_inspection.free()
	_inspection = null


## Im eingebauten Zustand verdecken Verkleidung und Reifen diese Teile.
## Die Werkstattansicht zeigt dasselbe Blender-Modell neben dem Kart.
func _inspect_internal(vehicle, kart: Node3D) -> bool:
	var node_name := str(TUNING.option(slot, _current(slot)).get("node", ""))
	if node_name.is_empty():
		return false
	var part := vehicle.asset_root.find_child("Mount_" + node_name, true, false) as Node3D
	if part == null:
		return false
	var sources: Array[Node3D] = [part]
	if slot == "brakes":
		var disc := vehicle.asset_root.find_child("Mount_" + node_name + "Disc", true, false) as Node3D
		if disc != null:
			sources.append(disc)
	_inspection = Node3D.new()
	_inspection.name = "Teileansicht"
	kart.add_child(_inspection)
	var bounds := AABB()
	for source in sources:
		var copy := source.duplicate(0) as Node3D
		_inspection.add_child(copy)
		copy.global_transform = source.global_transform
		for mesh in copy.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if not bounds.has_surface() else bounds.merge(box)
	if not bounds.has_surface():
		_clear_inspection()
		return false
	var offset := Vector3(-1.22, 0.80, -0.76) if _focused and slot in LIFT_SLOTS else Vector3(1.78, 0.73, -1.12)
	var target := kart.to_global(offset)
	_inspection.global_position += target - bounds.get_center()
	return true


func _focus_camera() -> void:
	_clear_inspection()
	var vehicle = _vehicle()
	if vehicle == null:
		return
	# Turn the kart on its plinth. The camera always stays inside the studio.
	var rear := slot in ["engine", "wing", "booster", "exhaust"]
	menu.preview_angle = PI * 0.86 if rear else -0.25
	menu.preview_pivot.rotation.y = menu.preview_angle
	menu._camera_zoom = 1.0
	_sync_lift(menu.preview_kart)
	if slot in ["steering", "brakes", "gearbox", "ballast"] or (_focused and slot == "suspension"):
		_inspect_internal(vehicle, menu.preview_kart)
	menu._fit_welcome_camera.call_deferred()


func _sync_lift(kart: Node3D) -> void:
	if not _focused or slot not in LIFT_SLOTS or not is_instance_valid(kart):
		_clear_lift()
		return
	if is_instance_valid(_lift) and _lift_kart == kart:
		return
	_clear_lift()
	_lift_kart = kart
	_lift_rest = kart.position
	kart.position.y += LIFT_HEIGHT
	_lift = Node3D.new()
	_lift.name = "WorkshopInspectionLift"
	menu.preview_pivot.add_child(_lift)
	_lift.position = _lift_rest
	var materials: Dictionary = menu.garage_interior.showroom.materials
	var frame: Material = materials.dark
	var steel: Material = materials.chrome
	var safety: Material = materials.yellow
	STAGE._box(_lift, "LiftBasePlate", Vector3(0.90, 0.05, 1.32), Vector3(0, 0.05, 0), frame, false)
	STAGE._box(_lift, "LiftTopPlate", Vector3(0.92, 0.07, 1.28), Vector3(0, 0.48, 0), safety, false)
	for side in [-0.32, 0.32]:
		for slope in [-1.0, 1.0]:
			var arm := STAGE._box(_lift, "ScissorArm", Vector3(0.07, 0.07, 0.86), Vector3(side + slope * 0.04, 0.27, 0), safety, false)
			arm.rotation.x = slope * 0.48
		STAGE._cylinder(_lift, "ScissorPivot", 0.045, 0.23, Vector3(side, 0.27, 0), steel).rotation.z = PI * 0.5
		STAGE._box(_lift, "FrameContact", Vector3(0.20, 0.08, 0.83), Vector3(side, 0.54, 0), frame, false)


func _clear_lift() -> void:
	if is_instance_valid(_lift_kart):
		_lift_kart.position = _lift_rest
	_lift_kart = null
	if is_instance_valid(_lift):
		_lift.queue_free()
		_lift.hide()
	_lift = null


func _selected_bounds(kart: Node3D, projection: Transform3D) -> AABB:
	var vehicle = _vehicle()
	if vehicle == null:
		return AABB()
	var subject: Node3D = _inspection
	if not is_instance_valid(subject):
		var node_name := str(TUNING.option(slot, _current(slot)).get("node", ""))
		if not node_name.is_empty():
			subject = vehicle.asset_root.find_child("Mount_" + node_name, true, false) as Node3D
	var bounds := AABB()
	if is_instance_valid(subject):
		for mesh in subject.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = projection * mesh.global_transform * mesh.get_aabb()
			bounds = box if not bounds.has_surface() else bounds.merge(box)
	var focus := Vector3(0, 0.64, 0.10)
	if slot in LIFT_SLOTS and not vehicle.wheel_pivots.is_empty():
		focus = vehicle.wheel_pivots[0].position
		# Include the exposed corner and the scissor arms below it.
		var wheel_section := projection * kart.global_transform * AABB(
			focus + Vector3(-0.46, -0.70, -0.50), Vector3(1.50, 1.28, 1.26)
		)
		return wheel_section.merge(bounds) if bounds.has_surface() else wheel_section
	if bounds.has_surface():
		return bounds.grow(0.29)
	if slot in ["engine", "wing", "booster", "exhaust", "gearbox"]:
		focus.z = 0.92
	elif slot == "steering":
		focus.z = -0.55
	return projection * kart.global_transform * AABB(focus - Vector3(0.68, 0.37, 0.48), Vector3(1.36, 0.74, 0.96))


## A product camera can frame the silhouette exactly without moving behind a studio wall
## on a narrow Fold screen. Include the exploded component when present.
func fit_camera(region: Rect2) -> void:
	var kart: Node3D = menu.preview_kart
	if not is_instance_valid(kart) or not region.has_area():
		return
	var camera: Camera3D = menu.preview_camera
	_sync_lift(kart)
	var aspect := Vector2(menu.preview_viewport.size).aspect()
	var direction := Vector3(-2.45, 1.65, -3.8).normalized()
	if _focused and slot in LIFT_SLOTS:
		direction = Vector3(-2.6, 0.79, -3.6).normalized()
	var basis := Basis.looking_at(-direction)
	var projection := Transform3D(basis.inverse(), Vector3.ZERO)
	var bounds := AABB()
	var found := false
	for mesh in kart.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.skin != null or mesh == kart.far_mesh:
			continue
		var box: AABB = projection * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found:
		return
	var seated = kart.get("lumo_animation")
	if is_instance_valid(seated) and seated.is_visible_in_tree():
		var skeleton: Skeleton3D = seated.actor.skeleton
		var head := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin)
		for side in [-0.5, 0.5]:
			bounds = bounds.expand(basis.inverse() * (head + Vector3(side, 0.50, 0)))
	if _focused:
		var selected := _selected_bounds(kart, projection)
		if selected.has_surface():
			bounds = selected
	var centre := bounds.get_center()
	var span := maxf(bounds.size.y / region.size.y, bounds.size.x / (region.size.x * aspect)) * 1.12
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = span * clampf(menu._camera_zoom, 1.0, 1.25)
	var optical_centre := Vector3(
		centre.x - (region.get_center().x - 0.5) * camera.size * aspect,
		centre.y + (region.get_center().y - 0.5) * camera.size,
		bounds.end.z + 1.0)
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.global_transform = Transform3D(basis, basis * optical_centre)
	menu._camera_focus = basis * centre


func _sync() -> void:
	var garage_page: bool = (
		menu != null and int(menu.step) == 2 and not bool(menu.get("_landing_active"))
	)
	if not garage_page and _open:
		_clear_inspection()
		_clear_lift()
		pending.clear()
		_focused = false
		_open = false
	open_button.visible = garage_page and not _open
	stats_button.visible = garage_page and not _open
	panel.visible = garage_page and _open
	if not garage_page:
		stats_panel.hide()
	if is_instance_valid(menu.get("_selection_surface")):
		menu._selection_surface.visible = menu._selection_surface.visible and not _open
	if is_instance_valid(menu.get("setup_left")):
		menu.setup_left.visible = not _open


## Im Querformat teilen sich die Aktionen eine Werkzeugleiste mit der Ansicht.
## Auf schmalen Bildschirmen sitzen sie zwischen freier Bühne und Kartauswahl.
func relayout(ui_scale: float, stage: Rect2, drawer: Rect2, actions: Rect2) -> void:
	_scale = ui_scale
	_compact_portrait = menu.size.x < menu.size.y and menu.size.x / ui_scale < COMPACT_WIDTH_DP
	_sync_focus()
	var button_height: float = 52.0 * ui_scale
	var gap: float = 10.0 * ui_scale
	for button in [open_button, stats_button, mount_button, back_button]:
		button.add_theme_font_size_override("font_size", roundi(17 * ui_scale))
		button.custom_minimum_size.y = button_height
	var compact := drawer.size.x < 380.0 * ui_scale
	category.custom_minimum_size = Vector2((108 if compact else 150) * ui_scale, 48 * ui_scale)
	category.add_theme_font_size_override("font_size", roundi(16 * ui_scale))
	var popup := category.get_popup()
	var popup_font_size := roundi(17 * ui_scale)
	popup.add_theme_font_size_override("font_size", popup_font_size)
	var font_height := popup.get_theme_font("font").get_height(popup_font_size)
	# Popup rows include the actual font height plus vertical separation.
	# Keep every category reachable at >=48 dp, including high-density screens.
	var item_padding := maxi(roundi(16 * ui_scale), ceili(48.0 * ui_scale - font_height))
	popup.add_theme_constant_override("v_separation", item_padding + item_padding % 2)
	title_label.add_theme_font_size_override("font_size", roundi((18 if compact else 21) * ui_scale))
	part_title.add_theme_font_size_override("font_size", roundi(24 * ui_scale))
	title_label.clip_text = true
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.text = "Zurück"
	back_button.custom_minimum_size.x = 65 * ui_scale
	for action in [back_button, mount_button]:
		action.add_theme_font_size_override("font_size", roundi((14 if compact else 16) * ui_scale))
	stats_title.add_theme_font_size_override("font_size", roundi(18 * ui_scale))
	stats_bars.row_height = 26.0 * ui_scale
	stats_bars.font_scale = ui_scale
	var open_width: float = 230.0 * ui_scale
	var stats_width: float = 110.0 * ui_scale
	# Without a side toolbar the measured camera stage already ends above the action row.
	var y := stage.end.y + gap * 0.5
	var row := stage
	if actions.has_area():
		row = actions
		y = actions.position.y
		button_height = actions.size.y
		gap = 4.0 * ui_scale
		for button in [open_button, stats_button]:
			button.custom_minimum_size.y = button_height
			button.add_theme_font_size_override("font_size", roundi(14.0 * ui_scale))
		# "Werte" keeps its full word; "Teile wechseln" takes the rest of the row.
		stats_width = maxf(56.0 * ui_scale, _text_width(stats_button))
		open_width = actions.size.x - stats_width - gap
		if open_width < _text_width(open_button):
			for button in [open_button, stats_button]:
				button.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
			stats_width = maxf(56.0 * ui_scale, _text_width(stats_button))
			open_width = actions.size.x - stats_width - gap
	var row_width := open_width + stats_width + gap
	if row.size.x > 0.0 and row_width > row.size.x:
		var fit := row.size.x / row_width
		open_width *= fit
		stats_width *= fit
		gap *= fit
		row_width = row.size.x
	for button in [open_button, stats_button]:
		# Schmaler als ihr Text: kürzen statt über die Nachbarn hinauswachsen.
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var x: float = maxf(row.position.x, row.get_center().x - row_width * 0.5)
	open_button.position = Vector2(x, y)
	open_button.size = Vector2(open_width, button_height)
	stats_button.position = Vector2(x + open_width + gap, y)
	stats_button.size = Vector2(stats_width, button_height)
	var stats_size := Vector2(
		minf(420.0 * ui_scale, stage.size.x - gap * 2.0), 26.0 * ui_scale * 5.0 + 120.0 * ui_scale
	)
	stats_panel.position = Vector2(
		stage.get_center().x - stats_size.x * 0.5,
		maxf(stage.position.y + gap, y - stats_size.y - gap)
	)
	stats_panel.size = stats_size
	_drawer = drawer
	_apply_tile_size()
	_sync()


## Width of the whole label plus the button's own padding (style margins).
func _text_width(button: Button) -> float:
	var font_size := button.get_theme_font_size("font_size")
	var font := button.get_theme_font("font")
	var text := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var style := button.get_theme_stylebox("normal")
	return text.x + style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) + 10.0 * _scale


func _apply_tile_size() -> void:
	if not _drawer.has_area():
		return
	var tile_width := clampf(_drawer.size.x / _scale * 0.29, 108.0, 152.0)
	var tile_height := clampf(_drawer.size.y / _scale * 0.27, 84.0, 132.0)
	for tile in tiles.values():
		tile.custom_minimum_size = Vector2(tile_width, tile_height) * _scale
		for label in tile.find_children("*", "Label", true, false):
			label.add_theme_font_size_override("font_size", roundi((14 if label.get_index() == 1 else 12) * _scale))
	tile_scroll.custom_minimum_size.y = tile_height * _scale + tile_scroll.get_h_scroll_bar().get_combined_minimum_size().y
	panel.position = _drawer.position
	panel.size = _drawer.size
	_apply_dyno_font()
