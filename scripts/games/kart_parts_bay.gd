extends Control
## „Teile wechseln“ direkt beim gewählten Kart (Garage, Schritt „Karts“) – schon bei 0 Sternen.
##
## Ablauf wie ein kindgerechter Fahrzeugkonfigurator:
##   „Teile wechseln“ → Steckplatz (Motor, Reifen, Flügel, Turbo, Fahrwerk, Radkappe,
##   Auspuff) → Kamera fährt kurz ans Teil → gerenderte Teilebilder (Serie immer dabei) →
##   Antippen zeigt die Variante sofort am Kart und auf dem Prüfstand den gemessenen
##   Unterschied (vorher → nachher, kart_dyno.gd) → „Montieren“ speichert (pro Kinderprofil
##   und Kart, kart_tuning.gd), „Zurück“ verwirft die offene Vorschau. Gesperrte Teile zeigen
##   ihren Sternpreis und lassen sich mit verdienten Sternen freischalten (kein Kauf).
##   Radkappe und Auspuff sind reine Optik: „Aussehen“.
## Dazu „Werte“: die fünf vollständigen, beschrifteten Fahrwerte des gewählten Karts.
## Die Knöpfe sind mindestens 48 dp groß; nichts blinkt.

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
## Breite eines Steckplatz-Knopfs in dp (Höhe 52 dp).
const SLOT_WIDTH := 92.0
const THUMBS := "res://assets/kart/production/parts/thumbs/%s.png"
const ACCENT := Color("ff9a3c")

var menu
var open_button: Button
var stats_button: Button
var panel: PanelContainer
var stats_panel: PanelContainer
var stats_bars
var stats_title: Label
var title_label: Label
var slot_buttons: Dictionary = {}
var slot_row: HFlowContainer
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
var _drawer := Rect2()
var _stage := Rect2()


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


func _style(fill: Color, border: Color, radius: int = 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0.02, 0.08, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _action(text: String, callback: Callable, fill: Color, ink: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UI.HEADING)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	var normal := _style(fill, fill.lightened(0.45))
	var hover := _style(fill.lightened(0.12), Color.WHITE)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)
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
		"panel", _style(Color(0.03, 0.09, 0.22, 0.96), Color(1.0, 0.7, 0.3, 0.9), 26)
	)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	title_label = _label("Teile wechseln", 20, Color("ffe7a8"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
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
	# Sieben Steckplätze; sie brechen in eine zweite Reihe um, statt abgeschnitten zu werden.
	slot_row = HFlowContainer.new()
	slot_row.name = "PartsSlotRow"
	slot_row.add_theme_constant_override("h_separation", 8)
	slot_row.add_theme_constant_override("v_separation", 8)
	column.add_child(slot_row)
	for id in TUNING.PART_SLOTS:
		var button := _action(
			str(TUNING.SLOT_NAMES[id]),
			_on_slot.bind(id),
			Color(0.05, 0.25, 0.45, 0.95),
			Color.WHITE
		)
		button.name = "PartsSlot_" + id
		button.toggle_mode = true
		slot_row.add_child(button)
		slot_buttons[id] = button
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	tile_row = HBoxContainer.new()
	tile_row.add_theme_constant_override("separation", 10)
	tile_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(tile_row)
	_build_dyno(column)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body_scroll.get_parent().add_child(actions)
	back_button = _action("← Zurück", _on_back, Color(0.06, 0.16, 0.32, 0.96), Color.WHITE)
	back_button.name = "PartsBackButton"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back_button)
	mount_button = _action("Montieren", _on_mount, Color("ffd645"), Color("2b1a00"))
	mount_button.name = "PartsMountButton"
	mount_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(mount_button)
	panel.hide()


func _build_dyno(column: VBoxContainer) -> void:
	var frame := PanelContainer.new()
	frame.name = "PartsDyno"
	frame.add_theme_stylebox_override(
		"panel", _style(Color(0.01, 0.05, 0.13, 0.9), Color(0.4, 0.88, 1.0, 0.45), 16)
	)
	column.add_child(frame)
	dyno_box = VBoxContainer.new()
	dyno_box.add_theme_constant_override("separation", 4)
	frame.add_child(dyno_box)
	dyno_title = _label("Prüfstand", 15, Color("9fe8ff"))
	dyno_title.clip_text = true
	dyno_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dyno_box.add_child(dyno_title)
	dyno_grid = GridContainer.new()
	dyno_grid.name = "PartsDynoGrid"
	dyno_grid.columns = 5
	dyno_grid.add_theme_constant_override("h_separation", 10)
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
	_open = true
	pending = {}
	stats_panel.hide()
	_on_slot(slot)
	_sync()
	menu._apply_responsive_layout.call_deferred()


func _on_stats() -> void:
	if menu.workshop == null:
		return
	stats_title.text = "Fahrwerte · %s" % str(FLEET.entry(_kart_id()).get("name", ""))
	stats_bars.set_values(FLEET.base_stats(_kart_id()), menu.workshop.bonus(_kart_id()), true)
	stats_panel.visible = not stats_panel.visible


func _on_slot(slot_id: String) -> void:
	slot = slot_id
	for id in slot_buttons:
		slot_buttons[id].set_pressed_no_signal(id == slot)
	_build_tiles()
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
		tile.focus_mode = Control.FOCUS_NONE
		tile.set_pressed_no_signal(id == current)
		var chosen := id == current
		tile.add_theme_stylebox_override(
			"normal", _style(Color(0.05, 0.13, 0.27, 0.95), Color(0.4, 0.7, 0.95, 0.5), 18)
		)
		tile.add_theme_stylebox_override(
			"hover", _style(Color(0.08, 0.2, 0.38, 0.97), Color(0.7, 0.95, 1.0, 0.9), 18)
		)
		tile.add_theme_stylebox_override(
			"pressed", _style(Color(0.35, 0.22, 0.05, 0.97), Color("ffd645"), 18)
		)
		tile.add_theme_stylebox_override(
			"hover_pressed", _style(Color(0.35, 0.22, 0.05, 0.97), Color("ffd645"), 18)
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
		var path := THUMBS % (node_name if not node_name.is_empty() else ("Serie_" + slot))
		if ResourceLoader.exists(path):
			picture.texture = load(path)
		box.add_child(picture)
		var name_label := _label(str(option.name), 14, Color.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var tag := _label(_tag_text(option, id), 11, _tag_colour(id))
		tag.name = "PartTag"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tag)
		tile_row.add_child(tile)
		tiles[id] = tile
	_apply_tile_size()
	_refresh_dyno()


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
	var text: String = "Aussehen" if _is_look_slot(slot) else str(option.get("short", ""))
	return text + ("  ✓" if mounted else "")


func _tag_colour(id: String) -> Color:
	return Color("ffd645") if not _owned(slot, id) else Color("9fe8ff")


func _current(slot_id: String) -> String:
	return str(pending.get(slot_id, _saved(slot_id)))


func _on_tile(id: String) -> void:
	pending[slot] = id
	for key in tiles:
		tiles[key].set_pressed_no_signal(key == id)
	var vehicle = _vehicle()
	if vehicle != null:
		vehicle.apply_parts(preview_look())
	_refresh_dyno()
	_focus_camera()


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
	if _is_look_slot(slot) or workshop == null:
		dyno_title.text = "Aussehen"
		dyno_text.text = "Nur fürs Aussehen – fährt genau wie vorher."
		_sync_action()
		return
	var saved_id: String = _saved(slot)
	var before: Dictionary = DYNO.measure(workshop.multipliers(_kart_id()))
	var after: Dictionary = DYNO.measure(workshop.multipliers_with(_kart_id(), {slot: id}))
	dyno_title.text = (
		"Prüfstand: %s → %s" % [str(TUNING.option(slot, saved_id).name), str(option.name)]
		if id != saved_id
		else "Prüfstand: %s (montiert)" % str(option.name)
	)
	for metric in PART_CATALOG.SLOT_METRICS[slot]:
		var old_value: float = float(before[metric])
		var new_value: float = float(after[metric])
		dyno_values[metric] = [old_value, new_value]
		var verdict: int = DYNO.verdict(metric, old_value, new_value)
		var colour: Color = BETTER if verdict > 0 else (WORSE if verdict < 0 else SAME)
		var name_label := _label(str(DYNO.LABELS[metric].name), 14, Color("d8ecff"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dyno_grid.add_child(name_label)
		var before_label := _label(DYNO.format_value(metric, old_value), 14, SAME)
		before_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dyno_grid.add_child(before_label)
		dyno_grid.add_child(_label("→", 14, SAME))
		var after_label := _label(DYNO.format_value(metric, new_value), 15, colour)
		after_label.name = "DynoAfter_" + metric
		after_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dyno_grid.add_child(after_label)
		var word := _label(
			"besser" if verdict > 0 else ("weniger" if verdict < 0 else "gleich"), 12, colour
		)
		dyno_grid.add_child(word)
	dyno_text.text = str(option.get("text", ""))
	_apply_dyno_font()
	_sync_action()


## „Montieren“ wird zu „Freischalten · n ★“, wenn das angetippte Teil noch gesperrt ist.
func _sync_action() -> void:
	if mount_button == null:
		return
	var id: String = _current(slot)
	var workshop = _workshop()
	mount_button.disabled = false
	if _owned(slot, id) or workshop == null:
		mount_button.text = "Montieren"
		return
	var price: int = int(TUNING.option(slot, id).get("cost", 0))
	if workshop.can_buy_option(slot, id):
		mount_button.text = "Freischalten · %d ★" % price
	else:
		mount_button.text = "Noch %d ★ sammeln" % maxi(1, price - int(workshop.available()))
		mount_button.disabled = true


func _apply_dyno_font() -> void:
	if dyno_grid == null:
		return
	_set_dyno_font(1.0)
	var width: float = panel.size.x
	if _drawer.has_area():
		# Querformat (Konfigurator in der linken Spalte): für eine lesbare Prüfstand-Tabelle darf
		# er etwas in die Bühne wachsen (höchstens ein Viertel ihrer Breite).
		width = _drawer.size.x
		var beside: bool = _stage.has_area() and _drawer.position.y <= _stage.get_center().y
		if beside:
			var want: float = dyno_grid.get_combined_minimum_size().x + 56.0 * _scale
			width = clampf(want, _drawer.size.x, _drawer.size.x + _stage.size.x * 0.25)
		panel.size.x = width
	# Umbrechender Satz braucht eine feste Breite, sonst rechnet er sich unendlich hoch.
	dyno_text.custom_minimum_size = Vector2(maxf(80.0, width - 60.0 * _scale), 0)
	# Reicht auch das nicht, wird die Tabelle kleiner gesetzt, statt den Konfigurator weiter zu
	# verbreitern. Innenbreite: Rand des Konfigurators, Rahmen des Prüfstands, Rollbalken.
	var room: float = width - 56.0 * _scale
	var need: float = dyno_grid.get_combined_minimum_size().x
	if need > room:
		_set_dyno_font(maxf(0.6, room / need))


func _set_dyno_font(factor: float) -> void:
	for label in dyno_grid.get_children():
		var size: int = 15 if str(label.name).begins_with("DynoAfter") else 14
		if label.get_index() % 5 == 4:
			size = 12
		label.add_theme_font_size_override("font_size", roundi(size * _scale * factor))
	dyno_title.add_theme_font_size_override("font_size", roundi(15 * _scale))
	dyno_text.add_theme_font_size_override("font_size", roundi(15 * _scale))


func _on_mount() -> void:
	var workshop = _workshop()
	var id: String = _current(slot)
	if workshop != null and not workshop.has_option(slot, id):
		# Erst freischalten (verdiente Sterne, kein Kauf), dann bleibt der Konfigurator offen.
		if workshop.buy_option(slot, id):
			_build_tiles()
			if menu.has_method("_refresh_star_label"):
				menu._refresh_star_label()
		return
	if workshop != null:
		for key in pending:
			# Gesperrte Vorschauen anderer Steckplätze werden nicht gespeichert.
			workshop.choose(_kart_id(), key, str(pending[key]))
	pending = {}
	_close()
	parts_mounted.emit(_kart_id())


func _on_back() -> void:
	pending = {}
	var vehicle = _vehicle()
	if vehicle != null:
		vehicle.apply_parts(preview_look())
	_close()


func _close() -> void:
	_open = false
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


## Kurze Kamerafahrt ans Vorderrad (Räder) bzw. ans Heck (Auspuff) des echten Karts.
func _focus_camera() -> void:
	var vehicle = _vehicle()
	if vehicle == null or not menu.has_method("_move_preview_camera"):
		return
	var kart: Node3D = menu.preview_kart
	var centre: Vector3 = kart.global_position + Vector3(0, 0.45, 0)
	var target: Vector3
	var outward: Vector3
	var at_wheel: bool = slot in ["wheel_cover", "tires", "suspension"]
	if at_wheel and not vehicle.wheel_rotors.is_empty():
		var wheel: Node3D = vehicle.wheel_rotors[0]
		var eye: Vector3 = menu.preview_camera.global_position
		for rotor in vehicle.wheel_rotors:
			# Vorderrad auf der Kameraseite (das der Kamera nächste der beiden vorderen Räder).
			var front := str(rotor.name).ends_with("FL") or str(rotor.name).ends_with("FR")
			if (
				front
				and (
					not str(wheel.name).ends_with("FL") and not str(wheel.name).ends_with("FR")
					or (
						rotor.global_position.distance_to(eye)
						< wheel.global_position.distance_to(eye)
					)
				)
			):
				wheel = rotor
		target = wheel.global_position
		outward = (target - centre)
		outward.y = 0.0
		outward = outward.normalized() * 1.7 + kart.global_basis.z * -0.75 + Vector3(0, 0.42, 0)
	else:
		var marker := vehicle.asset_root.find_child("Boost_R", true, false) as Node3D
		target = marker.global_position if marker != null else centre
		if slot in ["engine", "wing", "booster"] and vehicle.has_method("_anchor"):
			target = vehicle.asset_root.to_global(vehicle._anchor(slot))
		if slot in ["engine", "wing", "booster"]:
			# Schräg von hinten oben: Heckdeck, Flügel und Turbo über dem Sitz sichtbar.
			outward = kart.global_basis.z * 2.1 + kart.global_basis.x * 1.2 + Vector3(0, 1.25, 0)
		else:
			outward = kart.global_basis.z * 1.25 + kart.global_basis.x * 0.6 + Vector3(0, 0.38, 0)
	menu.preview_camera.h_offset = 0.0
	menu.preview_camera.v_offset = 0.0
	# Blickpunkt etwas unter dem Teil: es steht dann in der freien Bühne über dem Konfigurator.
	var look_at: Vector3 = target - Vector3(0, 0.24 if at_wheel else 0.12, 0)
	menu._move_preview_camera(
		target + outward, look_at, Vector3.UP, 40.0, 2.8, true, Camera3D.PROJECTION_PERSPECTIVE
	)


func _sync() -> void:
	var garage_page: bool = (
		menu != null and int(menu.step) == 2 and not bool(menu.get("_landing_active"))
	)
	open_button.visible = garage_page and not _open
	stats_button.visible = garage_page and not _open
	panel.visible = garage_page and _open
	if not garage_page:
		stats_panel.hide()
	if is_instance_valid(menu.get("_selection_surface")):
		menu._selection_surface.visible = menu._selection_surface.visible and not _open
	if is_instance_valid(menu.get("setup_left")):
		menu.setup_left.visible = not _open


## Lage aus dem Garage-Layout: Knöpfe unten in der freien Bühne, der Konfigurator über der
## Auswahl-Fläche (dort, wo sonst die Kartkarten liegen).
func relayout(ui_scale: float, stage: Rect2, drawer: Rect2) -> void:
	_scale = ui_scale
	var button_height: float = 52.0 * ui_scale
	var gap: float = 10.0 * ui_scale
	for button in [open_button, stats_button, mount_button, back_button]:
		button.add_theme_font_size_override("font_size", roundi(17 * ui_scale))
		button.custom_minimum_size.y = button_height
	var compact_drawer := drawer.size.x < 320.0 * ui_scale
	for id in slot_buttons:
		var tab: Button = slot_buttons[id]
		tab.add_theme_font_size_override(
			"font_size", roundi((14 if compact_drawer else 16) * ui_scale)
		)
		tab.custom_minimum_size = Vector2((78 if compact_drawer else 104) * ui_scale, button_height)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
	title_label.visible = not compact_drawer
	title_label.add_theme_font_size_override("font_size", roundi(20 * ui_scale))
	stats_title.add_theme_font_size_override("font_size", roundi(18 * ui_scale))
	stats_bars.row_height = 26.0 * ui_scale
	stats_bars.font_scale = ui_scale
	var open_width: float = 230.0 * ui_scale
	var stats_width: float = 110.0 * ui_scale
	# Die Bühne für die Kamera endet über den Knöpfen; sie liegen direkt darunter.
	# Direkt über der Kartauswahl, ganz in der Bühne (nicht auf dem Rand der Auswahl).
	var y: float = stage.end.y + gap * 0.5
	# Hochformat: Auswahl liegt unter der Bühne, die Knöpfe bleiben darüber. Quer liegt die
	# Auswahl links neben der Bühne (oben bündig); ihre Oberkante darf die Knöpfe nicht über
	# die Abschnitts-Reiter schieben (800×480: „Werte“ lag auf dem Reiter „Strecke“).
	if drawer.position.y > stage.get_center().y:
		y = minf(y, drawer.position.y - button_height - gap * 0.6)
	else:
		# Querformat: Die Auswahl steht neben der Bühne. Die Knöpfe sitzen unten IN der
		# Bühne – darunter beginnt die Fußleiste („Rennen starten“ lag sonst verdeckt).
		y = stage.end.y - button_height - gap
	# Die Knopfzeile bleibt in der Bühne: auf sehr flachen Querformaten (640×320) war sie
	# breiter als die Bühne und lag über den Kartkarten links daneben.
	var row_width: float = open_width + stats_width + gap
	if stage.size.x > 0.0 and row_width > stage.size.x:
		var fit: float = stage.size.x / row_width
		open_width *= fit
		stats_width *= fit
		gap *= fit
		row_width = stage.size.x
	for button in [open_button, stats_button]:
		# Schmaler als ihr Text: kürzen statt über die Nachbarn hinauswachsen.
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var x: float = maxf(stage.position.x, stage.get_center().x - row_width * 0.5)
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
	_stage = stage
	_apply_tile_size()
	_sync()


## Reihen der Steckplatz-Knöpfe bei der Breite des Konfigurators.
func _slot_rows(width: float) -> int:
	var inner: float = width - 20.0 * _scale
	# Gleiche Knopfbreite wie in relayout() (schmaler Konfigurator: 78, sonst 104).
	var slot_w: float = SLOT_WIDTH * _scale
	if not slot_buttons.is_empty():
		slot_w = maxf(1.0, (slot_buttons.values()[0] as Button).custom_minimum_size.x)
	var per_row: int = maxi(1, floori((inner + 8.0 * _scale) / (slot_w + 8.0 * _scale)))
	return ceili(float(slot_buttons.size()) / float(per_row))


## Konfigurator: liegt auf der Auswahl-Fläche und wächst, wo nötig, in die Bühne hinein
## (höchstens bis 40 % ihrer Höhe), damit Teilebilder, Prüfstand und Knöpfe Platz haben.
## Die Teilebilder bekommen, was übrig bleibt; nichts ragt über die Fußleiste.
func _apply_tile_size() -> void:
	var drawer: Rect2 = _drawer if _drawer.has_area() else Rect2(panel.position, panel.size)
	var gap: float = 8.0 * _scale
	var slots_h: float = _slot_rows(drawer.size.x) * (52.0 + 8.0) * _scale - gap
	var dyno_h: float = 4.0 * 24.0 * _scale + 50.0 * _scale
	var fixed: float = 20.0 * _scale + 30.0 * _scale + slots_h + 52.0 * _scale + dyno_h + gap * 4.0
	var wanted_edge: float = 150.0 * _scale
	var top: float = drawer.position.y
	var below_stage: bool = _stage.has_area() and drawer.position.y > _stage.get_center().y
	if below_stage:
		top = minf(top, drawer.end.y - fixed - wanted_edge)
		top = maxf(top, _stage.position.y + _stage.size.y * 0.4)
	var rect := Rect2(drawer.position.x, top, drawer.size.x, drawer.end.y - top)
	var edge: float = clampf(rect.size.y - fixed, 64.0 * _scale, 170.0 * _scale)
	for id in tiles:
		tiles[id].custom_minimum_size = Vector2(edge * 0.95, edge)
		for label in tiles[id].find_children("*", "Label", true, false):
			label.add_theme_font_size_override(
				"font_size", roundi((14 if label.get_index() == 1 else 11) * _scale)
			)
	panel.reset_size()
	panel.position = rect.position
	panel.size = rect.size
	_apply_dyno_font()
