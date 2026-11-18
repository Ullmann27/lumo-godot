extends RefCounted
## Reiter „Fahrer“ und „Tempo & Gegner“ als große bebilderte Karten (Auftrag 18.11., Abschnitt 4).
## Alle Aussagen kommen aus echten Werten: Fahrer und Freischalt-Sterne aus dem Katalog,
## Stufen aus CATALOG.DIFFICULTIES (speed, rival) und der Lenkhilfe-Regel des Rennens
## (kart_island.gd hilft nur auf „Entdecken“ am Fahrbahnrand nach).
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const CARD = preload("res://scripts/games/kart_showcase_card.gd")
const DRIVER_ART := "res://assets/kart/menu/drivers/%s.webp"
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


## Ersetzt die schmalen Zeilen des Reiters durch große Karten in einem Raster.
## `select` wird mit (Schlüssel, ID) aufgerufen wie bei den übrigen Auswahlkarten.
static func build(menu: Control, step: int, select: Callable) -> void:
	if step not in [1, 4]:
		return
	var choices: BoxContainer = menu.choices
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.name = "ShowcaseCards"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(grid)
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
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func(): select.call(key, id))
		grid.add_child(card)


## Raster an die Fläche anpassen: nebeneinander, wenn es breit genug ist, sonst untereinander.
static func layout(menu: Control, area_dp: Vector2, scale_factor: float, short_view: bool) -> void:
	var grid := menu.choices.get_node_or_null("ShowcaseCards") as GridContainer
	if grid == null:
		return
	var count := grid.get_child_count()
	var columns := count if area_dp.x >= 150.0 * count else 1
	grid.columns = columns
	var gap := 8.0
	grid.add_theme_constant_override("h_separation", roundi(gap * scale_factor))
	grid.add_theme_constant_override("v_separation", roundi(gap * scale_factor))
	var rows := ceili(float(count) / columns)
	var height := maxf((area_dp.y - gap * (rows - 1)) / rows, 96.0 if short_view else 120.0)
	if columns == 1:
		height = maxf(height, 116.0)
	for card in grid.get_children():
		card.custom_minimum_size = Vector2(0, floorf(height * scale_factor))
		card.apply_size(scale_factor)
		if columns == 1 and card.chevrons == 0:
			card.art_share = 0.6
