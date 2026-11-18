extends Control
## Oberfläche des Kartentischs: Kopfzeile, Namensschilder, Hinweis, Aktionsknopf
## und alle Tafeln (Auswahl, Einstellungen, Pause, Regeln, Wertung, Einführung).
## Kennt keine Regeln; der Tisch füllt sie mit Daten und hört auf `chosen`.

signal chosen(id: String, payload: Dictionary)

const KIT = preload("res://scripts/games/cards/cards_ui_kit.gd")
const ART = preload("res://scripts/games/cards/cards_deck_art.gd")
const PORTRAITS := "res://assets/cards_table/portraits/%s.webp"
const SUIT_ICONS := "res://assets/cards_table/ui/suit_%s.webp"
const ICONS := "res://assets/kart/ui3d/"
const TILE_PLATES := {"stich": "plate_hero_amber.webp", "leiter": "plate_hero_teal.webp", "quartett": "plate_hero_violet.webp"}

var density := 1.0
var compact := false
var wide := false
var safe: Control
var top_bar: HBoxContainer
var pause_button: Button
var title_label: Label
var round_label: Label
var star_label: Label
var trump_chip: PanelContainer
var trump_icon: TextureRect
var trump_label: Label
var hint_panel: PanelContainer
var hint_label: Label
var action_button: Button
var me_plate: Button
var plates: Array[Button] = []
var overlay: Control
var overlay_kind := ""
var bubble: PanelContainer
var _plate_data: Array = []
var _hint_text := ""
var _action_text := ""
var _trump := -1
var _title := ""
var _round := ""
var _stars := 0
var _bubble_state: Dictionary = {}
var _overlay_state: Dictionary = {}
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_pulse += delta
	var glow := 0.82 + 0.18 * sin(_pulse * 5.0)
	for index in range(plates.size()):
		if index < _plate_data.size() and bool(_plate_data[index].get("target", false)):
			plates[index].modulate = Color(glow, 1.0, 1.0)
		elif plates[index].modulate != Color.WHITE:
			plates[index].modulate = Color.WHITE


## Baut alles neu für diese Dichte und Fläche. `insets`: links, oben, rechts,
## unten in Bildpunkten des Fensters.
func rebuild(new_density: float, insets: Rect2) -> void:
	density = new_density
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	plates.clear()
	safe = Control.new()
	safe.name = "Safe"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.offset_left = insets.position.x
	safe.offset_top = insets.position.y
	safe.offset_right = -insets.size.x
	safe.offset_bottom = -insets.size.y
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var area := size - insets.position - insets.size
	compact = area.y / density < 520.0 and area.x > area.y
	wide = area.x / density >= 600.0
	_build_top()
	_build_play()
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(overlay)
	set_game(_title, _round)
	set_stars(_stars)
	set_trump(_trump)
	set_hint(_hint_text)
	set_action(_action_text)
	set_plates(_plate_data)
	if not _bubble_state.is_empty():
		show_bubble(_bubble_state.text, _bubble_state.buttons, _bubble_state.get("anchor", Vector2.ZERO))
	if not _overlay_state.is_empty():
		_reopen_overlay()


func dp(value: float) -> float:
	return value * density


func _build_top() -> void:
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = dp(10)
	top_bar.offset_right = -dp(10)
	top_bar.offset_top = dp(8)
	top_bar.offset_bottom = dp(64)
	top_bar.add_theme_constant_override("separation", int(dp(8)))
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(top_bar)
	pause_button = KIT.button("II", "blue", density, 56.0, 22.0)
	pause_button.name = "Pause"
	pause_button.pressed.connect(func() -> void: chosen.emit("pause", {}))
	top_bar.add_child(pause_button)
	var middle := KIT.panel("row_stat.webp", density, 8.0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(middle)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(column)
	title_label = KIT.label("", 18, density, KIT.WHITE, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	column.add_child(title_label)
	round_label = KIT.label("", 12, density, KIT.CYAN)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(round_label)
	var stars := KIT.panel("row_stat.webp", density, 8.0)
	stars.name = "Stars"
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(stars)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(dp(4)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_child(row)
	row.add_child(KIT.picture(ICONS + "icon_star_gold.webp", 28, density))
	star_label = KIT.label("0", 18, density, KIT.GOLD, true)
	row.add_child(star_label)


func _build_play() -> void:
	trump_chip = KIT.panel("row_stat.webp", density, 6.0)
	trump_chip.name = "Trump"
	trump_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(trump_chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(dp(6)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trump_chip.add_child(row)
	trump_icon = KIT.picture("", 26, density)
	row.add_child(trump_icon)
	trump_label = KIT.label("", 13, density, KIT.WHITE, true)
	row.add_child(trump_label)
	trump_chip.hide()
	hint_panel = KIT.panel("row_stat.webp", density, 8.0)
	hint_panel.name = "Hint"
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(hint_panel)
	hint_label = KIT.wrapped("", 15 if not compact else 13, density)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)
	hint_panel.hide()
	action_button = KIT.button("", "gold", density, 132.0, 20.0)
	action_button.name = "Action"
	action_button.pressed.connect(func() -> void: chosen.emit("action", {}))
	safe.add_child(action_button)
	action_button.hide()
	me_plate = _make_plate(0)
	me_plate.name = "PlateMe"
	me_plate.custom_minimum_size.x = dp(150)
	me_plate.hide()


func _make_plate(player: int) -> Button:
	var plate := Button.new()
	plate.focus_mode = Control.FOCUS_NONE
	plate.custom_minimum_size = Vector2(118, 52) * density
	plate.clip_contents = false
	plate.set_meta("player", player)
	plate.pressed.connect(func() -> void: chosen.emit("seat", {"player": int(plate.get_meta("player"))}))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = dp(8)
	row.offset_right = -dp(8)
	row.add_theme_constant_override("separation", int(dp(6)))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var face := KIT.picture("", 38, density)
	face.name = "Face"
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var column := VBoxContainer.new()
	column.name = "Text"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -int(dp(2)))
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := KIT.label("", 14, density, KIT.WHITE, true)
	name_label.name = "Name"
	name_label.clip_text = true
	column.add_child(name_label)
	var info := KIT.label("", 12, density, KIT.CYAN)
	info.name = "Info"
	info.clip_text = true
	column.add_child(info)
	safe.add_child(plate)
	return plate


func _style_plate(plate: Button, active: bool) -> void:
	var box := KIT.slice("plate_nav_active.webp" if active else "row_stat.webp", density, 6.0)
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		plate.add_theme_stylebox_override(state, box)


# ----------------------------------------------------------------- Spielanzeige


func set_game(title: String, round_text: String) -> void:
	_title = title
	_round = round_text
	if is_instance_valid(title_label):
		title_label.text = title
		round_label.text = round_text
		round_label.visible = not round_text.is_empty()


func set_stars(count: int) -> void:
	_stars = count
	if is_instance_valid(star_label):
		star_label.text = str(count)


func set_trump(suit: int) -> void:
	_trump = suit
	if not is_instance_valid(trump_chip):
		return
	trump_chip.visible = suit >= 0
	if suit >= 0:
		var keys := ["stern", "mond", "blatt", "welle"]
		var names := ["Stern", "Mond", "Blatt", "Welle"]
		trump_icon.texture = KIT.texture(SUIT_ICONS % keys[suit])
		trump_label.text = "Trumpf: " + names[suit]
	_place_fixed()


func set_hint(text: String) -> void:
	_hint_text = text
	if not is_instance_valid(hint_panel):
		return
	hint_label.text = text
	hint_panel.visible = not text.is_empty() and overlay_kind.is_empty()
	_place_fixed()


func set_action(text: String) -> void:
	_action_text = text
	if not is_instance_valid(action_button):
		return
	action_button.text = text
	action_button.visible = not text.is_empty() and overlay_kind.is_empty()
	_place_fixed()


## Je Spieler: name, portrait, info, active, target, visible.
func set_plates(data: Array) -> void:
	_plate_data = data
	if not is_instance_valid(safe):
		return
	while plates.size() < maxi(0, data.size() - 1):
		var plate := _make_plate(plates.size() + 1)
		plate.name = "Plate%d" % (plates.size() + 1)
		safe.move_child(plate, 1)
		plates.append(plate)
	for index in range(plates.size()):
		plates[index].visible = index + 1 < data.size() and overlay_kind in ["", "bubble"]
	me_plate.visible = not data.is_empty() and overlay_kind in ["", "bubble"]
	for player in range(data.size()):
		var plate: Button = me_plate if player == 0 else plates[player - 1]
		var entry: Dictionary = data[player]
		plate.get_node("Row/Face").texture = KIT.texture(PORTRAITS % str(entry.get("portrait", "lumo")))
		plate.get_node("Row/Text/Name").text = str(entry.get("name", ""))
		plate.get_node("Row/Text/Info").text = str(entry.get("info", ""))
		_style_plate(plate, bool(entry.get("active", false)))
		plate.disabled = not bool(entry.get("target", false))
		plate.mouse_filter = Control.MOUSE_FILTER_STOP if bool(entry.get("target", false)) else Control.MOUSE_FILTER_IGNORE
	_place_fixed()


## Setzt ein Namensschild an einen Bildpunkt (über dem Kopf der Figur).
func place_plate(player: int, at: Vector2) -> void:
	if player <= 0 or player - 1 >= plates.size():
		return
	var plate := plates[player - 1]
	var local := at - safe.global_position
	var extent := plate.size
	var top_limit := dp(70)
	var target := Vector2(local.x - extent.x * 0.5, local.y - extent.y)
	target.x = clampf(target.x, dp(6), maxf(dp(6), safe.size.x - extent.x - dp(6)))
	target.y = clampf(target.y, top_limit, maxf(top_limit, safe.size.y - extent.y - dp(6)))
	plate.position = target


## Untere Zone: Höhe der eigenen Hand in Bildpunkten (vom Tisch gesetzt).
var hand_height := 160.0


func _place_fixed() -> void:
	if not is_instance_valid(safe):
		return
	var area := safe.size
	if area.x <= 0.0:
		area = size
	var above_hand := area.y - hand_height - dp(8)
	if is_instance_valid(me_plate):
		me_plate.size = me_plate.custom_minimum_size
		me_plate.position = Vector2(dp(8), above_hand - me_plate.size.y)
	if is_instance_valid(action_button):
		action_button.size = action_button.get_combined_minimum_size()
		action_button.position = Vector2(area.x - action_button.size.x - dp(10), above_hand - action_button.size.y)
	if is_instance_valid(hint_panel):
		var left := dp(8) + (me_plate.size.x + dp(8) if is_instance_valid(me_plate) else 0.0)
		var right := area.x - dp(10) - (action_button.size.x + dp(8) if action_button.visible else 0.0)
		var width := maxf(dp(120), right - left)
		hint_panel.custom_minimum_size = Vector2(width, dp(52))
		hint_panel.size = Vector2(width, 0)
		var height := maxf(dp(52), hint_panel.get_combined_minimum_size().y)
		hint_panel.size = Vector2(width, height)
		hint_panel.position = Vector2(left, above_hand - height)
	if is_instance_valid(trump_chip):
		trump_chip.size = trump_chip.get_combined_minimum_size()
		trump_chip.position = Vector2(area.x - trump_chip.size.x - dp(10), dp(72))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_fixed.call_deferred()


# ------------------------------------------------------------------- Tafeln


func _open(kind: String, dim: float) -> VBoxContainer:
	close_overlay(false)
	overlay_kind = kind
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.01, 0.03, 0.12, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = -4000
	shade.offset_top = -4000
	shade.offset_right = 4000
	shade.offset_bottom = 4000
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var area := safe.size if safe.size.x > 0 else size
	var panel := KIT.panel("panel_glass_navy.webp", density, 18.0)
	panel.name = "Panel"
	var width := minf(area.x - dp(24), dp(430 if not wide else 520))
	var max_height := area.y - dp(24)
	overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - dp(36), 0)
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", int(dp(10)))
	scroll.add_child(column)
	panel.set_meta("width", width)
	panel.set_meta("max_height", max_height)
	hint_panel.hide()
	action_button.hide()
	for plate: Button in plates:
		plate.hide()
	me_plate.hide()
	_fit_panel.call_deferred()
	return column


func _fit_panel() -> void:
	if not is_instance_valid(overlay) or not overlay.has_node("Panel"):
		return
	var panel: PanelContainer = overlay.get_node("Panel")
	var scroll: ScrollContainer = panel.get_node("Scroll")
	var column: VBoxContainer = scroll.get_node("Column")
	var area := safe.size if safe.size.x > 0 else size
	var width: float = panel.get_meta("width")
	var wanted := column.get_combined_minimum_size().y + dp(36)
	var height := minf(wanted, float(panel.get_meta("max_height")))
	scroll.custom_minimum_size = Vector2(width - dp(36), height - dp(36))
	panel.size = Vector2(width, height)
	panel.position = ((area - panel.size) * 0.5).round()


func close_overlay(restore: bool = true) -> void:
	if not is_instance_valid(overlay):
		return
	for child: Node in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_kind = ""
	if restore:
		_overlay_state.clear()
		set_hint(_hint_text)
		set_action(_action_text)
		set_plates(_plate_data)


func _reopen_overlay() -> void:
	var state := _overlay_state.duplicate(true)
	match str(state.get("kind", "")):
		"select":
			show_select(state.data)
		"setup":
			show_setup(state.data)
		"pause":
			show_pause(state.data)
		"rules":
			show_rules(state.data)
		"round":
			show_round(state.data)
		"final":
			show_final(state.data)
		"confirm":
			show_confirm(state.data)


func _emit(id: String, payload: Dictionary = {}) -> Callable:
	return func() -> void: chosen.emit(id, payload)


func _heading(column: VBoxContainer, text: String, size: float = 26.0, color: Color = KIT.GOLD) -> Label:
	var node := KIT.label(text, size, density, color, true)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(node)
	return node


func _text(column: VBoxContainer, text: String, size: float = 15.0, color: Color = KIT.WHITE) -> Label:
	var node := KIT.wrapped(text, size, density, color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(node)
	return node


func _button(column: Container, text: String, kind: String, id: String, payload: Dictionary = {}) -> Button:
	var node := KIT.button(text, kind, density, 120.0, 19.0)
	node.name = "Button_" + id
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(_emit(id, payload))
	column.add_child(node)
	return node


## Auswahl der drei Spiele. data: games [{id,title,text,resume,cards}], stars.
func show_select(data: Dictionary) -> void:
	_overlay_state = {"kind": "select", "data": data}
	close_overlay(false)
	overlay_kind = "select"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.13, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = -4000
	shade.offset_top = -4000
	shade.offset_right = 4000
	shade.offset_bottom = 4000
	overlay.add_child(shade)
	hint_panel.hide()
	action_button.hide()
	me_plate.hide()
	for plate: Button in plates:
		plate.hide()
	top_bar.hide()
	trump_chip.hide()
	var area := safe.size if safe.size.x > 0 else size
	var column := VBoxContainer.new()
	column.name = "Select"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = dp(14)
	column.offset_right = -dp(14)
	column.offset_top = dp(10)
	column.offset_bottom = -dp(10)
	column.add_theme_constant_override("separation", int(dp(8 if compact else 12)))
	overlay.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(dp(8)))
	column.add_child(head)
	var back := KIT.button("Zurück", "blue", density, 104.0, 17.0)
	back.name = "Button_leave"
	back.pressed.connect(_emit("leave"))
	head.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", -int(dp(3)))
	head.add_child(titles)
	var logo := KIT.label("Lumo Karten", 26 if not compact else 22, density, KIT.GOLD, true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(logo)
	var sub := KIT.label("Drei Spiele am Sternentisch", 13, density, KIT.CYAN)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(sub)
	var stars := KIT.panel("row_stat.webp", density, 8.0)
	head.add_child(stars)
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", int(dp(4)))
	stars.add_child(star_row)
	star_row.add_child(KIT.picture(ICONS + "icon_star_gold.webp", 26, density))
	star_row.add_child(KIT.label(str(int(data.get("stars", 0))), 17, density, KIT.GOLD, true))
	# Platz für den Blick auf den Tisch, dann die drei Kacheln.
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 0.9 if not compact else 0.2
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var sideways := compact or area.x / density >= 700.0
	var tiles: BoxContainer = HBoxContainer.new() if sideways else VBoxContainer.new()
	tiles.name = "Tiles"
	tiles.add_theme_constant_override("separation", int(dp(12)))
	tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiles.size_flags_stretch_ratio = 2.2
	column.add_child(tiles)
	for game: Dictionary in data.get("games", []):
		tiles.add_child(_tile(game, sideways))
	var foot := KIT.label("Tippe ein Spiel an – Lumo zeigt dir, wie es geht.", 13, density, KIT.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(foot)


func _tile(game: Dictionary, sideways: bool) -> Button:
	var tile := Button.new()
	tile.name = "Tile_" + str(game.id)
	tile.focus_mode = Control.FOCUS_NONE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(140, 96) * density
	var box := KIT.slice(TILE_PLATES.get(str(game.id), "plate_feature_navy.webp"), density, 10.0)
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		tile.add_theme_stylebox_override(state, box)
	tile.pressed.connect(_emit("game", {"game": str(game.id)}))
	var stack_vertical := sideways and not compact
	var body: BoxContainer = VBoxContainer.new() if stack_vertical else HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = dp(12)
	body.offset_right = -dp(12)
	body.offset_top = dp(8)
	body.offset_bottom = -dp(10)
	body.add_theme_constant_override("separation", int(dp(10)))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(body)
	var fan := CardFan.new()
	fan.cards = game.get("cards", [])
	fan.custom_minimum_size = Vector2(108, 84) * density if not compact else Vector2(84, 64) * density
	fan.size_flags_vertical = Control.SIZE_EXPAND_FILL if stack_vertical else Control.SIZE_SHRINK_CENTER
	if stack_vertical:
		fan.size_flags_stretch_ratio = 1.4
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(fan)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", int(dp(1)))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(text)
	var name_label := KIT.label(str(game.title), 21 if not compact else 18, density, KIT.WHITE, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	if not compact:
		text.add_child(KIT.wrapped(str(game.text), 13.5, density, Color("eaf4ff")))
	var resume: String = str(game.get("resume", ""))
	var status := KIT.label(resume if not resume.is_empty() else str(game.get("skill", "")), 12.5, density,
		KIT.GOLD if not resume.is_empty() else KIT.CYAN, true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(status)
	return tile


## Einstellungen vor der Partie. data: game, title, text, players, difficulty,
## rounds, resume (Text oder "").
func show_setup(data: Dictionary) -> void:
	_overlay_state = {"kind": "setup", "data": data}
	var column := _open("setup", 0.5)
	top_bar.hide()
	_heading(column, str(data.title))
	_text(column, str(data.text), 14.0, Color("d5e6ff"))
	if not str(data.get("resume", "")).is_empty():
		_button(column, str(data.resume), "gold", "resume", {"game": data.game})
	for row: Array in [
		["Mitspieler", "players", [[2, "1"], [3, "2"], [4, "3"]]],
		["Stärke", "difficulty", [[0, "Leicht"], [1, "Mittel"], [2, "Schwer"]]],
		["Runden", "rounds", [[1, "1"], [3, "3"], [5, "5"]]],
	]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", int(dp(6)))
		column.add_child(line)
		var caption := KIT.label(str(row[0]), 15, density, KIT.CYAN, true)
		caption.custom_minimum_size.x = dp(96)
		line.add_child(caption)
		for option: Array in row[2]:
			var selected := int(data.get(row[1], -1)) == int(option[0])
			var pick := KIT.choice(str(option[1]), selected, density, 56.0)
			pick.name = "Pick_%s_%d" % [row[1], option[0]]
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pick.pressed.connect(_emit("pref", {"key": row[1], "value": int(option[0])}))
			line.add_child(pick)
	var start_text := "Neue Partie" if not str(data.get("resume", "")).is_empty() else "Los geht's!"
	_button(column, start_text, "blue" if not str(data.get("resume", "")).is_empty() else "gold", "start", {"game": data.game})
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(dp(8)))
	column.add_child(foot)
	_button(foot, "Zurück", "blue", "back")
	_button(foot, "So geht's", "blue", "intro", {"game": data.game})


func show_pause(data: Dictionary) -> void:
	_overlay_state = {"kind": "pause", "data": data}
	var column := _open("pause", 0.6)
	_heading(column, "Pause")
	_text(column, str(data.get("text", "Deine Partie wartet auf dich.")), 14.0, Color("d5e6ff"))
	_button(column, "Weiterspielen", "gold", "continue")
	_button(column, "Regeln", "blue", "rules")
	_button(column, "Neu starten", "blue", "restart")
	_button(column, "Beenden", "blue", "quit")


## data: title, lines (Array[String]), back (id des Rück-Knopfs).
func show_rules(data: Dictionary) -> void:
	_overlay_state = {"kind": "rules", "data": data}
	var column := _open("rules", 0.6)
	_heading(column, "So geht " + str(data.title), 22.0)
	var number := 1
	for line: String in data.get("lines", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(dp(8)))
		column.add_child(row)
		var badge := KIT.label(str(number), 17, density, KIT.GOLD, true)
		badge.custom_minimum_size.x = dp(22)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(badge)
		row.add_child(KIT.wrapped(line, 14.5, density))
		number += 1
	_button(column, "Verstanden", "gold", str(data.get("back", "rules_done")))


## data: text, yes (id), no (id), yes_text, no_text.
func show_confirm(data: Dictionary) -> void:
	_overlay_state = {"kind": "confirm", "data": data}
	var column := _open("confirm", 0.6)
	_heading(column, str(data.get("title", "Sicher?")), 22.0)
	_text(column, str(data.text))
	_button(column, str(data.get("yes_text", "Ja")), "gold", str(data.yes))
	_button(column, str(data.get("no_text", "Nein")), "blue", str(data.no))


func _score_rows(column: VBoxContainer, rows: Array) -> void:
	for row: Dictionary in rows:
		var line := KIT.panel("plate_nav_active.webp" if bool(row.get("winner", false)) else "row_stat.webp", density, 8.0)
		column.add_child(line)
		var items := HBoxContainer.new()
		items.add_theme_constant_override("separation", int(dp(8)))
		line.add_child(items)
		items.add_child(KIT.picture(PORTRAITS % str(row.portrait), 40, density))
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", -int(dp(2)))
		items.add_child(names)
		names.add_child(KIT.label(str(row.name), 16, density, KIT.WHITE, true))
		names.add_child(KIT.label(str(row.detail), 12.5, density, KIT.CYAN))
		if bool(row.get("winner", false)):
			items.add_child(KIT.picture(ICONS + "icon_crown.webp", 30, density))
		var points := KIT.label(str(row.points), 20, density, KIT.GOLD, true)
		points.custom_minimum_size.x = dp(54)
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		items.add_child(points)


## Rundenwertung. data: title, text, rows, next_text.
func show_round(data: Dictionary) -> void:
	_overlay_state = {"kind": "round", "data": data}
	var column := _open("round", 0.5)
	_heading(column, str(data.title), 24.0)
	_text(column, str(data.text), 14.0, Color("d5e6ff"))
	_score_rows(column, data.rows)
	_button(column, str(data.get("next_text", "Nächste Runde")), "gold", "next_round")


## Endstand. data: title, text, place, rows, stars, saved.
func show_final(data: Dictionary) -> void:
	_overlay_state = {"kind": "final", "data": data}
	var column := _open("final", 0.55)
	var place := clampi(int(data.get("place", 1)), 1, 4)
	var badge_file := "badge_place_%d.webp" % place if place <= 3 else "badge_place_other.webp"
	var badge := KIT.picture(ICONS + badge_file, 104 if not compact else 64, density)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(badge)
	_heading(column, str(data.title), 24.0)
	_text(column, str(data.text), 14.0, Color("d5e6ff"))
	_score_rows(column, data.rows)
	var reward := HBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_theme_constant_override("separation", int(dp(6)))
	column.add_child(reward)
	reward.add_child(KIT.picture(ICONS + "icon_star_gold.webp", 34, density))
	reward.add_child(KIT.label(str(data.get("reward", "")), 18, density, KIT.GOLD, true))
	if not str(data.get("warning", "")).is_empty():
		_text(column, str(data.warning), 13.0, Color("ffb39a"))
	_button(column, "Nochmal spielen", "gold", "again")
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(dp(8)))
	column.add_child(foot)
	_button(foot, "Anderes Spiel", "blue", "menu")
	_button(foot, "Spielewelt", "blue", "leave")


func show_top(value: bool) -> void:
	if is_instance_valid(top_bar):
		top_bar.visible = value


# ---------------------------------------------------------------- Einführung


## Lumos Sprechblase. buttons: [[id, Text, "gold"|"blue"], ...]
func show_bubble(text: String, buttons: Array, anchor: Vector2 = Vector2.ZERO) -> void:
	hide_bubble()
	_bubble_state = {"text": text, "buttons": buttons, "anchor": anchor}
	bubble = KIT.panel("plate_feature_navy.webp", density, 14.0)
	bubble.name = "Bubble"
	safe.add_child(bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(dp(8)))
	bubble.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(dp(8)))
	column.add_child(head)
	head.add_child(KIT.picture(PORTRAITS % "lumo", 46, density))
	var words := KIT.wrapped(text, 15.5 if not compact else 14.0, density)
	head.add_child(words)
	if not buttons.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(dp(8)))
		column.add_child(row)
		for entry: Array in buttons:
			var node := KIT.button(str(entry[1]), str(entry[2]), density, 96.0, 17.0)
			node.name = "Button_" + str(entry[0])
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.pressed.connect(_emit(str(entry[0])))
			row.add_child(node)
	var area := safe.size if safe.size.x > 0 else size
	var width := minf(area.x - dp(20), dp(400))
	bubble.custom_minimum_size = Vector2(width, 0)
	bubble.size = Vector2(width, 0)
	_place_bubble.call_deferred()


func _place_bubble() -> void:
	if not is_instance_valid(bubble):
		return
	var area := safe.size if safe.size.x > 0 else size
	bubble.size = Vector2(bubble.custom_minimum_size.x, bubble.get_combined_minimum_size().y)
	var top := dp(74)
	if compact:
		bubble.position = Vector2(area.x - bubble.size.x - dp(10), top)
	else:
		bubble.position = Vector2((area.x - bubble.size.x) * 0.5, top)


func hide_bubble() -> void:
	_bubble_state.clear()
	if is_instance_valid(bubble):
		bubble.get_parent().remove_child(bubble)
		bubble.queue_free()
	bubble = null


## Sichtbare Knöpfe (für Bedien- und Safe-Area-Prüfungen).
func visible_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in find_children("*", "Button", true, false):
		if node.is_visible_in_tree():
			found.append(node)
	return found


func find_button(id: String) -> Button:
	for node: Button in visible_buttons():
		if node.name == "Button_" + id or node.name == id:
			return node
	return null


## Kleiner Kartenfächer als Bild auf den Spielkacheln.
class CardFan:
	extends Control
	var cards: Array = []

	func _draw() -> void:
		if cards.is_empty():
			return
		var card_height := minf(size.y * 0.92, size.x * 0.95)
		var card_width := card_height * 0.711
		var count := cards.size()
		var centre := Vector2(size.x * 0.5, size.y * 0.5 + card_height * 0.5)
		for index in range(count):
			var offset := float(index) - float(count - 1) * 0.5
			var angle := offset * 0.24
			draw_set_transform(centre + Vector2(offset * card_width * 0.42, 0), angle, Vector2.ONE)
			var rect := Rect2(-card_width * 0.5, -card_height, card_width, card_height)
			draw_rect(rect.grow(1.0).abs(), Color(0, 0, 0, 0.25))
			draw_texture_rect(ART.face_texture(int(cards[index])), rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
