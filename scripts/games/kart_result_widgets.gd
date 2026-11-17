extends RefCounted
## Bausteine der Ergebnistafel: Wertzeile, Zeilenblock, Knopf, Cup-Wertung und
## Schlusszeile. Jeder Baustein kennt seine Entwurfsmaße und setzt sie über
## apply_result_scale(maßstab, dp) um; `dp` sichert Mindestgrößen (48 dp Tastfläche,
## lesbare Schrift). Formen und Farben kommen aus kart_result_kit.gd.
const KIT = preload("res://scripts/games/kart_result_kit.gd")


## Eine dunkle Glaszeile: Icon, Beschriftung links, Wert rechtsbündig, dazu
## optional verdiente Sterne. Ohne Wert wird der Text umbrochen (Hinweiszeile).
class Row:
	extends PanelContainer
	var icon_kind: String = ""
	var accent: Color = KIT.CYAN
	var star_count: int = 0
	var label: Label
	var value: Label
	var _icon: Control
	var _stars: Control
	var _box: HBoxContainer
	var _scale: float = 1.0
	var _dp: float = 1.0

	func setup(kind: String, caption: String, shown_value: String = "", stars: int = 0, tint: Color = KIT.CYAN) -> Row:
		icon_kind = kind
		accent = tint
		star_count = clampi(stars, 0, 5)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box = HBoxContainer.new()
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_box)
		_icon = Control.new()
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.draw.connect(func(): KIT.draw_icon(_icon, icon_kind, _icon.size * 0.5, minf(_icon.size.x, _icon.size.y)))
		_box.add_child(_icon)
		label = Label.new()
		label.text = caption
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", KIT.UI.HEADING)
		label.add_theme_color_override("font_color", KIT.ROW_TEXT)
		if shown_value == "" and star_count == 0:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_box.add_child(label)
		value = Label.new()
		value.text = shown_value
		value.visible = shown_value != ""
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_override("font", KIT.display_font())
		value.add_theme_color_override("font_color", KIT.VALUE_TEXT)
		value.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.1, 0.7))
		_box.add_child(value)
		_stars = Control.new()
		_stars.visible = star_count > 0
		_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stars.draw.connect(_draw_stars)
		_box.add_child(_stars)
		apply_result_scale(1.0, 1.0)
		return self

	func is_note() -> bool:
		return not value.visible and star_count == 0

	func apply_result_scale(factor: float, dp: float) -> void:
		_scale = factor
		_dp = dp
		add_theme_stylebox_override("panel", KIT.row_style(factor, accent))
		custom_minimum_size.y = (40.0 if is_note() else 50.0) * factor
		_box.add_theme_constant_override("separation", roundi(11.0 * factor))
		var icon_size: float = (26.0 if is_note() else 32.0) * factor
		_icon.custom_minimum_size = Vector2.ONE * icon_size
		label.add_theme_font_size_override("font_size", KIT.font_size(17.0 if is_note() else 21.0, factor, dp))
		value.add_theme_font_size_override("font_size", KIT.font_size(26.0, factor, dp, 13.0))
		value.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(2.0 * factor)))
		var star: float = 28.0 * factor
		_stars.custom_minimum_size = Vector2(star * float(star_count) + 2.0 * factor * float(maxi(0, star_count - 1)), star)
		_icon.queue_redraw()
		_stars.queue_redraw()
		queue_redraw()

	## Höhe bei gegebener Breite; umbrochene Hinweise wachsen mit ihrem Text.
	func result_height(width: float) -> float:
		if not is_note():
			return custom_minimum_size.y
		var style: StyleBox = get_theme_stylebox("panel")
		var text_width: float = maxf(
			1.0, width - style.get_minimum_size().x - _icon.custom_minimum_size.x - 11.0 * _scale
		)
		var font: Font = label.get_theme_font("font")
		var text_height: float = font.get_multiline_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, label.get_theme_font_size("font_size")
		).y
		return maxf(custom_minimum_size.y, ceilf(text_height) + style.get_minimum_size().y + 4.0 * _scale)

	func _draw_stars() -> void:
		var star: float = _stars.size.y
		for index in range(star_count):
			KIT.draw_star(_stars, Vector2(star * 0.5 + float(index) * (star + 2.0 * _scale), star * 0.5), star * 0.44)

	func _draw() -> void:
		var replacement: Texture2D = KIT.texture("row")
		if replacement != null:
			draw_texture_rect(replacement, Rect2(Vector2.ZERO, size), false)
			return
		var inset: float = maxf(1.0, 2.0 * _scale)
		var gloss := Rect2(Vector2(inset, inset), Vector2(size.x - inset * 2.0, size.y * 0.48))
		KIT.draw_gradient_box(self, gloss, 11.0 * _scale, Color(0.55, 0.8, 1.0, 0.16), Color(0.55, 0.8, 1.0, 0.0))
		draw_line(
			Vector2(14.0 * _scale, size.y - inset), Vector2(size.x - 14.0 * _scale, size.y - inset),
			Color(accent.r, accent.g, accent.b, 0.35), maxf(1.0, 1.5 * _scale), true
		)


## Die Wertzeilen des Rennens. `text` ist die eine Quelle: dieselben Zeilen wie
## _result_stats_text() („Name   Wert“), jede wird zu einer sichtbaren Zeile.
class Stats:
	extends VBoxContainer
	const ICONS: Dictionary = {
		"Gesamtzeit": "time", "Beste Runde": "lap", "Sterne gesammelt": "token", "Belohnung": "reward"
	}
	var text: String = "":
		set(value):
			text = value
			_rebuild()
	var _scale: float = 1.0
	var _dp: float = 1.0

	func _init() -> void:
		name = "ResultStats"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _rebuild() -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		for line in text.split("\n", false):
			var cut: int = line.find("   ")
			var caption: String = line.substr(0, cut).strip_edges() if cut >= 0 else line
			var shown: String = line.substr(cut + 3).strip_edges() if cut >= 0 else ""
			var stars: int = 0
			var tint: Color = KIT.CYAN
			if caption == "Belohnung" and shown.ends_with(" Sterne") and shown.begins_with("+"):
				# Die verdienten Sterne stehen als Zahl und als echte Sternsymbole da.
				stars = maxi(0, int(shown.trim_prefix("+").trim_suffix(" Sterne")))
				shown = "+%d" % stars
				tint = KIT.TIERS.gold.mid
			add_child(Row.new().setup(str(ICONS.get(caption, "token")), caption, shown, stars, tint))
		apply_result_scale(_scale, _dp)

	func apply_result_scale(factor: float, dp: float) -> void:
		_scale = factor
		_dp = dp
		add_theme_constant_override("separation", roundi(7.0 * factor))
		for child in get_children():
			child.apply_result_scale(factor, dp)

	func result_height(width: float) -> float:
		var height: float = 0.0
		for child in get_children():
			height += child.result_height(width)
		return height + float(maxi(0, get_child_count() - 1)) * get_theme_constant("separation")


## Cup-Gesamtwertung als kompakte Tafel in drei Spalten; das Kind ist golden markiert.
class Standings:
	extends PanelContainer
	var _title: Label
	var _grid: GridContainer
	var _cells: Array[Label] = []
	var _scale: float = 1.0

	func setup(entries: Array) -> Standings:
		name = "ResultCupStandings"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var column := VBoxContainer.new()
		add_child(column)
		_title = Label.new()
		_title.text = "GESAMTWERTUNG · PUNKTE"
		_title.add_theme_font_override("font", KIT.spaced_font())
		_title.add_theme_color_override("font_color", Color("9fdcff"))
		column.add_child(_title)
		_grid = GridContainer.new()
		_grid.columns = 3
		column.add_child(_grid)
		for index in range(entries.size()):
			var cell := Label.new()
			var mine: bool = bool(entries[index].get("me", false))
			cell.text = "%d. %s  %d%s" % [
				index + 1, str(entries[index].name), int(entries[index].points), "  ← DU" if mine else ""
			]
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.clip_text = true
			cell.add_theme_font_override("font", KIT.UI.HEADING)
			cell.add_theme_color_override("font_color", KIT.TIERS.gold.mid if mine else KIT.ROW_TEXT)
			_grid.add_child(cell)
			_cells.append(cell)
		apply_result_scale(1.0, 1.0)
		return self

	func apply_result_scale(factor: float, dp: float) -> void:
		_scale = factor
		add_theme_stylebox_override("panel", KIT.row_style(factor))
		_title.add_theme_font_size_override("font_size", KIT.font_size(13.0, factor, dp, 10.0))
		_grid.add_theme_constant_override("h_separation", roundi(14.0 * factor))
		_grid.add_theme_constant_override("v_separation", roundi(1.0 * factor))
		for cell in _cells:
			cell.add_theme_font_size_override("font_size", KIT.font_size(16.0, factor, dp, 11.0))

	func result_height(_width: float) -> float:
		return get_combined_minimum_size().y


## Plastischer Knopf: gelb (primary), blau (secondary) oder flaches Glas (small).
class Action:
	extends Button
	var kind: String = "small"
	var icon_kind: String = ""
	var _plate: Control
	var _scale: float = 1.0
	var _dp: float = 1.0
	var _wanted_font: int = 20

	func setup(caption: String, callback: Callable, style: String = "small", icon: String = "") -> Action:
		text = caption
		kind = style
		icon_kind = icon
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		add_theme_font_override("font", KIT.display_font() if kind != "small" else KIT.UI.HEADING)
		var face: Color = KIT.NAVY_TEXT if kind == "primary" else Color("f7fbff")
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(state, face)
		_plate = Control.new()
		_plate.show_behind_parent = true
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_plate.draw.connect(_draw_plate)
		add_child(_plate)
		for change in [button_down, button_up, mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
			change.connect(_plate.queue_redraw)
		resized.connect(_fit_font)
		pressed.connect(callback)
		apply_result_scale(1.0, 1.0)
		return self

	func _lip() -> float:
		return (0.0 if kind == "small" else 5.0) * _scale

	func apply_result_scale(factor: float, dp: float) -> void:
		_scale = factor
		_dp = dp
		# Tastfläche nie unter 48 dp, auch wenn die Tafel stark verkleinert ist.
		# Die beiden Hauptknöpfe bleiben auch auf kleinen Telefonen höher als die Nebenreihe.
		var floor_dp: float = 48.0 if kind == "small" else 54.0
		custom_minimum_size = Vector2(48.0 * dp, maxf(floor_dp * dp, (48.0 if kind == "small" else 66.0) * factor))
		_wanted_font = KIT.font_size(17.0 if kind == "small" else 24.0, factor, dp, 13.0)
		var pad: float = (10.0 if kind == "small" else 14.0) * factor
		var icon_room: float = _icon_size() + 8.0 * factor if icon_kind != "" else 0.0
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			var box := StyleBoxEmpty.new()
			box.content_margin_left = pad + icon_room
			box.content_margin_right = pad
			box.content_margin_top = 2.0 * factor
			box.content_margin_bottom = 2.0 * factor + _lip()
			add_theme_stylebox_override(state, box)
		_fit_font()
		_plate.queue_redraw()

	func _icon_size() -> float:
		return 30.0 * _scale

	## Der ganze Text bleibt lesbar: Die Schrift schrumpft, bis er in den Knopf passt.
	func _fit_font() -> void:
		var font: Font = get_theme_font("font")
		var style: StyleBox = get_theme_stylebox("normal")
		var room: float = size.x - style.get_minimum_size().x
		var fitted: int = _wanted_font
		if room > 8.0:
			var floor_size: int = maxi(8, roundi(11.0 * _dp))
			while fitted > floor_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > room:
				fitted -= 1
		if get_theme_font_size("font_size") != fitted:
			add_theme_font_size_override("font_size", fitted)

	func _draw_plate() -> void:
		var held: bool = get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED]
		var lit: bool = get_draw_mode() == DRAW_HOVER or has_focus()
		var lip: float = _lip()
		var sink: float = lip * 0.7 if held else 0.0
		var face := Rect2(Vector2(0, sink), Vector2(size.x, size.y - lip))
		var radius: float = (12.0 if kind == "small" else 15.0) * _scale
		var replacement: Texture2D = KIT.texture("button_" + kind)
		if replacement != null:
			_plate.draw_texture_rect(replacement, Rect2(Vector2(0, sink), size - Vector2(0, sink)), false)
		else:
			var top := Color("17386f")
			var bottom := Color("0b1f47")
			var rim := Color(0.45, 0.82, 1.0, 0.75)
			var base := Color("06122c")
			var glow := Color(0.2, 0.6, 1.0, 0.0)
			if kind == "primary":
				top = Color("ffe878")
				bottom = Color("ffb21f")
				rim = Color("fff6c4")
				base = Color("a85a00")
				glow = Color(1.0, 0.72, 0.1, 0.4)
			elif kind == "secondary":
				top = Color("3c8cff")
				bottom = Color("143a9c")
				rim = Color("8fe0ff")
				base = Color("081c57")
				glow = Color(0.25, 0.6, 1.0, 0.38)
			if lit:
				top = top.lightened(0.12)
				bottom = bottom.lightened(0.1)
			if glow.a > 0.0:
				var halo := StyleBoxFlat.new()
				halo.bg_color = Color(glow.r, glow.g, glow.b, 0.0)
				halo.set_corner_radius_all(roundi(radius))
				halo.shadow_color = glow
				halo.shadow_size = roundi(9.0 * _scale)
				_plate.draw_style_box(halo, Rect2(Vector2.ZERO, size))
			if lip > 0.0:
				KIT.draw_gradient_box(_plate, Rect2(Vector2(0, lip), face.size), radius, base, base.darkened(0.25))
			KIT.draw_gradient_box(_plate, face, radius, top, bottom, rim, maxf(1.0, 1.6 * _scale))
			var inset: float = 3.0 * _scale
			KIT.draw_gradient_box(
				_plate, Rect2(face.position + Vector2(inset, inset), Vector2(face.size.x - inset * 2.0, face.size.y * 0.44)),
				radius - inset, Color(1, 1, 1, 0.34 if kind == "primary" else 0.2), Color(1, 1, 1, 0.02)
			)
		if icon_kind != "":
			var font: Font = get_theme_font("font")
			var style: StyleBox = get_theme_stylebox("normal")
			var text_width: float = minf(
				font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x,
				size.x - style.get_minimum_size().x
			)
			var content_left: float = style.get_margin(SIDE_LEFT)
			var content_width: float = size.x - style.get_minimum_size().x
			var text_left: float = content_left + (content_width - text_width) * 0.5
			var centre := Vector2(text_left - 8.0 * _scale - _icon_size() * 0.5, face.position.y + face.size.y * 0.5)
			KIT.draw_icon(_plate, icon_kind, centre, _icon_size())


## Kleine Schlusszeile in Sperrschrift zwischen zwei feinen Linien.
class Tagline:
	extends Control
	var text: String = ""
	var _scale: float = 1.0
	var _dp: float = 1.0

	func setup(caption: String) -> Tagline:
		name = "ResultCheer"
		text = caption
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)
		apply_result_scale(1.0, 1.0)
		return self

	func apply_result_scale(factor: float, dp: float) -> void:
		_scale = factor
		_dp = dp
		custom_minimum_size.y = maxf(14.0 * dp, 20.0 * factor)
		queue_redraw()

	func result_height(_width: float) -> float:
		return custom_minimum_size.y

	func _draw() -> void:
		var font: Font = KIT.spaced_font()
		var shown: String = text.to_upper()
		var font_size: int = KIT.font_size(13.0, _scale, _dp, 10.0)
		var room: float = size.x - 24.0 * _scale
		var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		while width > room and font_size > 7:
			font_size -= 1
			width = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var left: float = (size.x - width) * 0.5
		var baseline: float = size.y * 0.5 + font_size * 0.36
		draw_string_outline(font, Vector2(left, baseline), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(1, roundi(3.0 * _scale)), Color(0.0, 0.03, 0.12, 0.75))
		draw_string(font, Vector2(left, baseline), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("d6eaff"))
		var gap: float = 10.0 * _scale
		var rule := Color(0.72, 0.9, 1.0, 0.6)
		if left - gap > 6.0:
			draw_line(Vector2(0, size.y * 0.5), Vector2(left - gap, size.y * 0.5), rule, maxf(1.0, 1.2 * _scale), true)
			draw_line(Vector2(left + width + gap, size.y * 0.5), Vector2(size.x, size.y * 0.5), rule, maxf(1.0, 1.2 * _scale), true)
