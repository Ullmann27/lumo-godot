extends RefCounted
## Reiter „Fahrer“ und „Tempo & Gegner“ als große bebilderte Karten (Auftrag 18.11., Abschnitt 4).
## Alle Aussagen kommen aus echten Werten: Fahrer und Freischalt-Sterne aus dem Katalog,
## Stufen aus CATALOG.DIFFICULTIES (speed, rival) und der Lenkhilfe-Regel des Rennens
## (kart_island.gd hilft nur auf „Entdecken“ am Fahrbahnrand nach).
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const CARD = preload("res://scripts/games/kart_showcase_card.gd")
const KIT = preload("res://scripts/games/kart_ui3d.gd")
const DRIVER_ART := "res://assets/kart/menu/drivers/%s.webp"
## Rennarten (Reiter „Rennen“): Reihenfolge wie bisher, Symbol und Farbe wie im Hauptmenü.
const MODE_ORDER: Array[String] = ["race", "time_trial", "arena", "cup", "training"]
const MODE_LOOK := {
	"race": ["icon_flag", Color("ffa91f"), "Dein schneller Start"],
	"time_trial": ["icon_stopwatch", Color("21ccff"), "Du gegen deinen Geist"],
	"arena": ["icon_star_crystal", Color("b760ed"), "90 Sekunden Abenteuer"],
	"cup": ["icon_trophy", Color("8a5cff"), "Alle Welten · ein Pokal"],
	"training": ["icon_route", Color("37e0a0"), "Entdecken ohne Druck"],
}
## Stufe, auf der das Rennen am Fahrbahnrand sanft mitlenkt (siehe kart_island.gd, _drive_player).
const ASSIST_LEVEL := "gemuetlich"
const LEVEL_COLORS := {
	"gemuetlich": Color("37e0a0"), "flott": Color("21ccff"), "pro": Color("ff6a3d")
}


static func driver_art_path(driver_id: String) -> String:
	return DRIVER_ART % driver_id


static func driver_art(driver_id: String) -> Texture2D:
	var path := driver_art_path(driver_id)
	return load(path) if ResourceLoader.exists(path, "Texture2D") else null


## Vier kurze Aussagen je Stufe, ausschließlich aus Katalog und Rennregeln.
static func level_facts(entry: Dictionary) -> PackedStringArray:
	var top := 0.0
	for level in CATALOG.DIFFICULTIES:
		top = maxf(top, float(level.speed))
	var own := float(entry.speed)
	var own_text := (
		"Dein Kart: volles Tempo"
		if is_equal_approx(own, top)
		else "Dein Kart: %d %% Tempo" % roundi(own / top * 100.0)
	)
	var rival := float(entry.rival)
	var behaviour := (
		"Sie lassen dir Platz"
		if rival < 0.9
		else ("Sie fahren stark" if rival < 0.99 else "Sie geben alles")
	)
	var rival_text := "Rivalen: %d %% Kraft" % roundi(rival * 100.0)
	var assist := "Lenkhilfe: an" if str(entry.id) == ASSIST_LEVEL else "Lenkhilfe: aus"
	return PackedStringArray([own_text, rival_text, behaviour, assist])


## Ersetzt die schmalen Zeilen des Reiters durch große Karten. Die Karten bleiben direkte
## Kinder der Auswahl (wie die bisherigen Zeilen); `layout` stellt sie neben- oder untereinander.
## `select` wird mit (Schlüssel, ID) aufgerufen wie bei den übrigen Auswahlkarten.
static func build(menu: Control, step: int, select: Callable) -> void:
	if step == 0:
		_build_modes(menu, select)
		return
	if step not in [1, 4]:
		return
	var choices: BoxContainer = menu.choices
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var key := "driver" if step == 1 else "difficulty"
	var entries: Array[Dictionary] = CATALOG.DRIVERS if step == 1 else CATALOG.DIFFICULTIES
	for index in range(entries.size()):
		var item: Dictionary = entries[index]
		var id := str(item.id)
		var card = CARD.new()
		card.name = ("DriverCard_" if step == 1 else "LevelCard_") + id
		card.title = str(item.name)
		card.selected = str(menu.setup[key]) == id
		if step == 1:
			var open: bool = CATALOG.unlocked(item, int(menu.stars), menu.unlocked_ids)
			card.art = driver_art(id)
			card.accent = Color(item.get("color", Color("53ddfd")))
			var tag := str(item.tag).to_lower()
			card.lines = PackedStringArray([tag.left(1).to_upper() + tag.substr(1)])
			card.disabled = not open
			if not open:
				card.locked_text = "Noch %d ★" % maxi(0, int(item.unlock) - int(menu.stars))
			card.art_share = 0.72
		else:
			card.accent = LEVEL_COLORS.get(id, Color("53ddfd"))
			card.chevrons = index + 1
			card.lines = level_facts(item)
			card.art_share = 0.26
		card.set_meta("showcase_card", true)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func(): select.call(key, id))
		choices.add_child(card)


## Rennarten als Bildkarten in einem Raster (wie bisher das erste Kind der Auswahl).
static func _build_modes(menu: Control, select: Callable) -> void:
	var choices: BoxContainer = menu.choices
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.name = "ModeCards"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(grid)
	for id in MODE_ORDER:
		var item: Dictionary = CATALOG.entry(CATALOG.MODES, id)
		var look: Array = MODE_LOOK[id]
		var card = CARD.new()
		card.name = "ModeCard_" + id
		card.title = str(item.name)
		card.art = KIT.texture(str(look[0]))
		card.accent = look[1]
		card.lines = PackedStringArray([str(look[2])])
		card.selected = str(menu.setup.mode) == id
		card.art_share = 0.5
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func(): select.call("mode", id))
		grid.add_child(card)


static func cards(menu: Control) -> Array:
	var result: Array = []
	for child in menu.choices.get_children():
		if child.has_meta("showcase_card") and not child.is_queued_for_deletion():
			result.append(child)
	return result


## Nebeneinander, wenn jede Karte mindestens 150 dp breit wird, sonst untereinander.
## Muss nach der Streckenwahl-Anordnung laufen (die setzt die Auswahl auf senkrecht zurück).
static func layout(menu: Control, area_dp: Vector2, scale_factor: float, short_view: bool) -> void:
	var grid := menu.choices.get_node_or_null("ModeCards") as GridContainer
	if grid != null and not grid.is_queued_for_deletion():
		_layout_modes(grid, area_dp, scale_factor)
		return
	var shown := cards(menu)
	if shown.is_empty():
		return
	var count := shown.size()
	var side_by_side := area_dp.x >= 150.0 * count
	var gap := 8.0
	menu.choices.vertical = not side_by_side
	menu.choices.add_theme_constant_override("separation", roundi(gap * scale_factor))
	var height := area_dp.y
	if not side_by_side:
		height = maxf((area_dp.y - gap * (count - 1)) / count, 96.0 if short_view else 116.0)
	for card in shown:
		card.custom_minimum_size = Vector2(0, floorf(height * scale_factor))
		card.apply_size(scale_factor)
		if not side_by_side and card.chevrons == 0:
			card.art_share = 0.6


## Fünf Rennarten: drei bzw. zwei Spalten; alle passen ohne Blättern, solange 64 dp reichen.
static func _layout_modes(grid: GridContainer, area_dp: Vector2, scale_factor: float) -> void:
	var count := grid.get_child_count()
	var columns := 3 if area_dp.x >= 420.0 else (2 if area_dp.x >= 260.0 else 1)
	grid.columns = columns
	var gap := 8.0
	grid.add_theme_constant_override("h_separation", roundi(gap * scale_factor))
	grid.add_theme_constant_override("v_separation", roundi(gap * scale_factor))
	var rows := ceili(float(count) / columns)
	var height := clampf((area_dp.y - gap * (rows - 1)) / rows, 64.0, 170.0)
	for card in grid.get_children():
		card.custom_minimum_size = Vector2(0, floorf(height * scale_factor))
		card.art_share = 0.5 if height >= 110.0 else 0.0
		card.apply_size(scale_factor)
