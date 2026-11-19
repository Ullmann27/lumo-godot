extends RefCounted
## Bebilderte Inhalte der Hauptmenü-Fenster (Auftrag 18.11., Abschnitt 4):
## - Turniere: der Sternen-Cup zeigt alle Strecken mit Bild in Fahrreihenfolge vor dem Start.
## - Belohnungen: jede echte Freischaltung als Karte mit Bild des Fahrers bzw. Karts.
## - Saison: der Sternenpfad als Weg mit Stationen (erreicht / nächste / später).
## Alle Zahlen aus echten Sternen und den Freischalt-Schwellen (kart_star_path.gd).
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const PATH = preload("res://scripts/games/kart_star_path.gd")
const CARD = preload("res://scripts/games/kart_showcase_card.gd")
const SECTIONS = preload("res://scripts/games/kart_menu_sections.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const TRACK_ART := "res://assets/kart/track_stage/cards/%s.webp"
const TRACK_ART_FALLBACK := "res://assets/kart/neon_previews/%s.webp"
const KART_ART := "res://assets/kart/fleet/%s.png"
const GOLD := Color("ffc23d")
const NEON := Color("21ccff")
const VIOLET := Color("8a5cff")


static func _texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path, "Texture2D") else null


static func track_art(id: String) -> Texture2D:
	var art := _texture(TRACK_ART % id)
	return art if art != null else _texture(TRACK_ART_FALLBACK % id)


static func milestone_art(entry: Dictionary) -> Texture2D:
	if str(entry.kind) == "Fahrer":
		return SECTIONS.driver_art(str(entry.id))
	return _texture(KART_ART % str(entry.id))


static func _grid(list: VBoxContainer, grid_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.set_meta("overlay_grid", true)
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	return grid


## Sternen-Cup: alle Strecken des Katalogs in der Reihenfolge, in der der Cup sie fährt.
static func build_cup(list: VBoxContainer) -> void:
	var grid := _grid(list, "CupTracks")
	grid.set_meta("card_ratio", 0.78)
	for index in range(CATALOG.TRACKS.size()):
		var track: Dictionary = CATALOG.TRACKS[index]
		var card = CARD.new()
		card.name = "CupTrack_" + str(track.id)
		card.title = "%d · %s" % [index + 1, str(track.name)]
		card.art = track_art(str(track.id))
		card.accent = Color(track.get("color", NEON))
		card.art_share = 0.70
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.set_meta("cover_art", true)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)


## Belohnungen: jede echte Freischaltung mit Bild; gesperrte nennen die fehlenden Sterne.
static func build_rewards(list: VBoxContainer, stars: int) -> void:
	var grid := _grid(list, "RewardCards")
	grid.set_meta("card_ratio", 1.22)
	var next := PATH.next_milestone(stars)
	for entry in PATH.milestones():
		var done := stars >= int(entry.stars)
		var card = CARD.new()
		card.name = "Reward_" + str(entry.id)
		card.title = str(entry.name)
		card.art = milestone_art(entry)
		card.accent = GOLD if done else (NEON if entry == next else Color("6a7fa6"))
		card.selected = done
		card.lines = PackedStringArray(["%s · frei ab %d ★" % [entry.kind, int(entry.stars)]])
		if not done:
			card.disabled = true
			card.locked_text = "%s · noch %d ★" % [entry.kind, int(entry.stars) - stars]
		card.art_share = 0.52
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)


## Saison: Sternenpfad als senkrechter Weg; jede Station mit Bild, Name und Schwelle.
## Liefert die nächste noch offene Station (oder null), damit das Fenster dorthin blättert.
static func build_season(list: VBoxContainer, stars: int) -> Control:
	var path := VBoxContainer.new()
	path.name = "StarPathRoute"
	path.set_meta("overlay_path", true)
	path.add_theme_constant_override("separation", 0)
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(path)
	var all := PATH.milestones()
	var next := PATH.next_milestone(stars)
	var target: Control = null
	for index in range(all.size()):
		var entry: Dictionary = all[index]
		var station := Station.new()
		station.name = "Station_" + str(entry.id)
		station.entry = entry
		station.reached = stars >= int(entry.stars)
		station.is_next = entry == next
		station.first = index == 0
		station.last = index == all.size() - 1
		station.art = milestone_art(entry)
		station.stars = stars
		path.add_child(station)
		if station.is_next:
			target = station
	return target


## Größe der Karten und Stationen im dp-Maßstab `k` bei `width_dp` Innenbreite.
static func scale(list: VBoxContainer, k: float, width_dp: float) -> void:
	for child in list.get_children():
		if child.has_meta("overlay_grid"):
			var grid := child as GridContainer
			var columns := clampi(int(width_dp / 150.0), 2, 5)
			grid.columns = columns
			grid.add_theme_constant_override("h_separation", roundi(8 * k))
			grid.add_theme_constant_override("v_separation", roundi(8 * k))
			var w := (width_dp - 8.0 * (columns - 1)) / columns
			var h := w * float(grid.get_meta("card_ratio", 1.0))
			for card in grid.get_children():
				card.custom_minimum_size = Vector2(floorf(w * k * 0.9), roundf(h * k))
				card.apply_size(k)
		elif child.has_meta("overlay_path"):
			for station in child.get_children():
				station.ui_scale = k
				station.custom_minimum_size = Vector2(0, roundf(92.0 * k))
				station.queue_redraw()


## Eine Station des Sternenpfads: Wegstück mit Sternenknoten links, Bild und Text rechts.
class Station:
	extends Control
	var entry: Dictionary = {}
	var reached := false
	var is_next := false
	var first := false
	var last := false
	var art: Texture2D
	var stars := 0
	var ui_scale := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var k := ui_scale
		var x := 34.0 * k
		var cy := size.y * 0.5
		var lit := GOLD
		var dim := Color(1, 1, 1, 0.18)
		var line_w := 8.0 * k
		if not first:
			draw_line(Vector2(x, 0), Vector2(x, cy), lit if reached or is_next else dim, line_w)
		if not last:
			draw_line(Vector2(x, cy), Vector2(x, size.y), lit if reached else dim, line_w)
		var r := 25.0 * k
		draw_circle(Vector2(x, cy), r + 3.0 * k, Color("08133a"))
		draw_circle(Vector2(x, cy), r, lit if reached else (NEON if is_next else Color("2a3a5c")))
		var font: Font = UI.HEADING
		var number := str(int(entry.stars))
		var px := roundi((17.0 if number.length() < 3 else 14.0) * k)
		var nw := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(
			font,
			Vector2(x - nw * 0.5, cy + font.get_ascent(px) * 0.36),
			number,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			px,
			Color("2a1600") if reached else Color.WHITE
		)
		# Bild der Belohnung.
		var box := Rect2(
			Vector2(x + r + 14.0 * k, 6.0 * k), Vector2(size.y * 1.25, size.y - 12.0 * k)
		)
		var plate := StyleBoxFlat.new()
		plate.set_corner_radius_all(roundi(12 * k))
		plate.bg_color = Color("0b2a66", 0.9) if reached or is_next else Color("101a33", 0.9)
		plate.border_color = lit if reached else (NEON if is_next else Color("33476b"))
		plate.set_border_width_all(maxi(1, roundi((3.0 if is_next else 1.5) * k)))
		draw_style_box(plate, box)
		if art != null:
			var tex := Vector2(art.get_size())
			var fit := minf(box.size.x / tex.x, box.size.y / tex.y) * 0.94
			var drawn := tex * fit
			draw_texture_rect(
				art,
				Rect2(box.position + (box.size - drawn) * 0.5, drawn),
				false,
				Color.WHITE if reached or is_next else Color(0.5, 0.56, 0.68)
			)
		# Text.
		var tx := box.end.x + 14.0 * k
		var width := size.x - tx - 6.0 * k
		var title := str(entry.name)
		var title_px := roundi(21.0 * k)
		while (
			title_px > roundi(13.0 * k)
			and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > width
		):
			title_px -= 1
		draw_string(
			font,
			Vector2(tx, cy - 4.0 * k),
			title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			title_px,
			Color.WHITE
		)
		var status := (
			"%s · frei" % entry.kind
			if reached
			else ("%s · noch %d ★" % [entry.kind, int(entry.stars) - stars])
		)
		var body: Font = UI.BODY
		var body_px := roundi(16.0 * k)
		while (
			body_px > roundi(11.0 * k)
			and body.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, body_px).x > width
		):
			body_px -= 1
		draw_string(
			body,
			Vector2(tx, cy + body.get_ascent(body_px) + 2.0 * k),
			status,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			body_px,
			Color("ffd56a") if reached else (NEON if is_next else Color("b8c8e8"))
		)
