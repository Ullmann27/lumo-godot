extends PanelContainer
## Verbände-Tafel im Bereich „Schützen“: eine große Tafel statt eines kleinen Fensters.
## Je Truppenart eine Karte mit gerendertem Bild (Blender-Soldat), echter Zahl,
## Stärke und Gegenstück in einem Satz, Kosten und Knöpfen +1 / +10 / +100;
## darunter die Tore mit ihren Verbänden (Antippen wählt, „hierher“ verlegt).
## Liest nur echte Zahlen aus build_village_guards.gd / build_village_troops.gd;
## jede Handlung geht über host.troop_board_action(...).
## Bedienflächen mindestens TOUCH (dp) hoch: ≥ 126 px am offenen Fold (2,625 px je dp).
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const TROOPS = preload("res://scripts/creative/build_village_troops.gd")
const VHUD = preload("res://scripts/creative/build_village_hud.gd")
const HUD = preload("res://scripts/creative/build_hud_style.gd")
const TOUCH := 52.0
const STRENGTH := {
	"schild": "Hält Tor und Mauer. Stark gegen Belagerer, schwach gegen Flieger.",
	"bogen": "Schießt von Mauer und Turm. Stark gegen Flieger, Türme machen sie besser.",
	"speer": "Bildet eine Speerwand. Stark gegen Reiter und Sturmangriffe.",
	"reiter": "Schnell zur Stelle. Fängt Plünderer ab, frisst 1 Essen mehr am Tag.",
}
var host
var selected_unit := -1
var columns := 2
var _content: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _close: Button


func setup(village_host) -> void:
	host = village_host
	name = "TroopBoard"
	add_theme_stylebox_override("panel", VHUD.panel("glass", 14))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	_title = VHUD.label("Deine Truppen", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	_close = _button("Schließen", close, 120.0, "cream", 18)
	_close.name = "TroopBoardClose"
	head.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.name = "TroopBoardScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)


func close() -> void:
	hide()
	if host != null and host.has_method("troop_board_closed"):
		host.troop_board_closed()


## Breite bestimmt die Spalten: schmal 1 Karte, Fold hoch 2, quer 4.
func fit(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	custom_minimum_size = Vector2.ZERO
	var wanted := 4 if rect.size.x >= 1150.0 else (2 if rect.size.x >= 560.0 else 1)
	if wanted != columns:
		columns = wanted
		refresh()


func _button(
	text: String, action: Callable, width := 120.0, variant := "cream", font := 20
) -> Button:
	var control := VHUD.button(text, action, maxf(width, TOUCH), variant, font)
	control.custom_minimum_size.y = TOUCH
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.clip_text = false
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control


func _text(text: String, font := 17, color := VHUD.INK_LIGHT) -> Label:
	var label := VHUD.label(text, font, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _act(action: String, argument: String, number: int) -> void:
	if host == null:
		return
	if action == "select":
		selected_unit = number if selected_unit != number else -1
		refresh()
		return
	host.troop_board_action(action, argument, number)
	if GUARDS.find(host.raids, selected_unit).is_empty():
		selected_unit = -1
	refresh()


func refresh() -> void:
	if host == null or not is_instance_valid(_content):
		return
	var raids = host.raids
	var model = host.model
	if raids == null or model == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var info: Dictionary = GUARDS.overview(model, raids)
	_title.text = "Deine Truppen · %d Soldaten" % int(info.total)
	var summary := (
		"%d Soldaten in %d Verbänden · Platz für %d weitere."
		% [int(info.total), int(info.units), int(info.room)]
	)
	_content.add_child(_text(summary + " Höchstens die halbe Bevölkerung kann Soldat sein.", 18))
	var food := (
		"Soldaten essen wie alle Bewohner, Pferde 1 mehr: %d Portionen am Tag."
		% [int(info.food_per_day)]
	)
	_content.add_child(_text(food + " " + str(info.reserve_text), 16))
	if not raids.pending.is_empty():
		var view: Dictionary = raids.forecast()
		_lumo(
			(
				("%s %s" % [GUARDS.advice(str(raids.pending.threat)), str(view.get("army", ""))])
				. strip_edges()
			)
		)
	_post_picker()
	var grid := GridContainer.new()
	grid.name = "TroopCards"
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for kind in TROOPS.KINDS:
		grid.add_child(_card(kind, info))
	_gates(info)


func _lumo(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var face := TextureRect.new()
	face.texture = VHUD.texture("lumo_portrait")
	face.custom_minimum_size = Vector2(56, 56)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(face)
	row.add_child(_text("Lumo: " + text, 17, VHUD.GOLD))
	_content.add_child(row)


func _post_picker() -> void:
	_content.add_child(_text("Neue Soldaten stellen sich hier auf:", 18))
	var posts := HFlowContainer.new()
	posts.name = "TroopPosts"
	posts.add_theme_constant_override("h_separation", 10)
	posts.add_theme_constant_override("v_separation", 10)
	_content.add_child(posts)
	for post in GUARDS.POST_ORDER:
		var chosen: bool = post == str(host.guard_post)
		var button := _button(
			str(GUARDS.POSTS[post]),
			_act.bind("post", post, 0),
			150.0,
			"primary" if chosen else "cream"
		)
		button.name = "TroopPost_" + post
		posts.add_child(button)


func _card(kind: String, info: Dictionary) -> Control:
	var raids = host.raids
	var model = host.model
	var card := PanelContainer.new()
	card.name = "TroopCard_" + kind
	card.add_theme_stylebox_override("panel", VHUD.panel("parchment", 12))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	var picture := TextureRect.new()
	picture.name = "TroopPicture"
	picture.texture = VHUD.texture("troop_" + kind)
	picture.custom_minimum_size = Vector2(112, 112)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(picture)
	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	var ink := HUD.INK
	facts.add_child(_text(TROOPS.title(kind, 2), 21, ink))
	var count := _text("%d" % int(info.kinds[kind]), 30, Color("1d4f8a"))
	count.name = "TroopCount"
	facts.add_child(count)
	facts.add_child(_text(str(STRENGTH[kind]), 16, ink))
	box.add_child(_text("Je Soldat: " + host._cost_text(TROOPS.cost(kind, 1)), 16, ink))
	var site := TROOPS.site_needed(kind)
	if not site.is_empty() and not GUARDS.has_site(raids, kind):
		var spec: Dictionary = TROOPS.SITES[site]
		var build := _button(
			"%s bauen: %s" % [str(spec.title), host._cost_text(spec.cost)],
			_act.bind("site", site, 0),
			200.0,
			"teal"
		)
		build.name = "TroopSite_" + site
		build.disabled = not model._affords(model._player, spec.cost)
		build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(build)
		box.add_child(_text("Danach stehen sie auf der Karte und du kannst ausbilden.", 16, ink))
		return card
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var hint := ""
	for step in GUARDS.STEPS:
		var error := GUARDS.train_error(model, raids, int(step), str(host.guard_post), kind)
		var plus := _button(
			"+%d" % int(step), _act.bind("train_" + kind, "", int(step)), 80.0, "leaf", 20
		)
		plus.name = "TroopTrain_%s_%d" % [kind, int(step)]
		plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plus.disabled = not error.is_empty()
		row.add_child(plus)
		if not error.is_empty() and hint.is_empty():
			hint = error
	if not hint.is_empty():
		box.add_child(_text(hint, 15, Color("7a3b1c")))
	return card


func _gates(info: Dictionary) -> void:
	var raids = host.raids
	_content.add_child(_text("Tore und Verbände", 21))
	_content.add_child(
		_text("Tipp einen Verband an und dann „hierher“ beim Tor, an das er gehen soll.", 16)
	)
	var chosen := GUARDS.find(raids, selected_unit)
	if not chosen.is_empty():
		var tools := HFlowContainer.new()
		tools.name = "TroopUnitTools"
		tools.add_theme_constant_override("h_separation", 10)
		tools.add_theme_constant_override("v_separation", 10)
		_content.add_child(tools)
		var split := _button("Teilen", _act.bind("split", "", selected_unit), 150.0, "sky")
		split.disabled = int(chosen.size) < 2
		tools.add_child(split)
		tools.add_child(
			_button("1 entlassen", _act.bind("dismiss", "", selected_unit), 170.0, "rose")
		)
	for post in GUARDS.POST_ORDER:
		var block := PanelContainer.new()
		block.name = "TroopGate_" + post
		block.add_theme_stylebox_override("panel", VHUD.panel("glass", 10))
		_content.add_child(block)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		block.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		head.add_child(
			_text("%s · %d Soldaten" % [str(GUARDS.POSTS[post]), int(info.posts[post])], 18)
		)
		if not chosen.is_empty() and str(chosen.post) != post:
			var here := _button("hierher", _act.bind("move", post, selected_unit), 150.0, "primary")
			here.name = "TroopMoveTo_" + post
			head.add_child(here)
		var units := HFlowContainer.new()
		units.add_theme_constant_override("h_separation", 10)
		units.add_theme_constant_override("v_separation", 10)
		box.add_child(units)
		for unit in raids.units:
			if str(unit.post) != post:
				continue
			var id := int(unit.id)
			var text := (
				"%s · %d %s"
				% [
					str(unit.name),
					int(unit.size),
					TROOPS.title(str(unit.get("type", "schild")), int(unit.size))
				]
			)
			var pick := _button(
				text,
				_act.bind("select", "", id),
				230.0,
				"primary" if id == selected_unit else "cream",
				16
			)
			pick.name = "TroopUnit_%d" % id
			units.add_child(pick)
	if raids.units.size() > 1:
		var regroup := _button(
			"Verbände je Tor zusammenlegen", _act.bind("regroup", "", 0), 260.0, "sky"
		)
		regroup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(regroup)
