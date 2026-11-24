extends VBoxContainer
## Read-only atlas for Lumo World. Map focus never moves the player or changes
## a mission, an economy save, a portal, or the camera in the playable world.

const INK := Color("e9f9f5")
const MUTED := Color("b7d8da")
const OCEAN := Color("123f58")
const LAND := Color("62845d")
const PLAYER_COLOR := Color("ffb76b")
const TARGET_COLOR := Color("c4ff98")
const PORTAL_COLOR := Color("8ceaf1")
const KART_COLOR := Color("ffe48a")
const MIN_TOUCH := 48.0

class AtlasCanvas extends Control:

	var atlas: Control


	func _draw() -> void:
		if is_instance_valid(atlas):
			atlas.draw_atlas(self)


var world_bounds := Rect2(-36, -238, 992, 476)
var view_bounds := Rect2(-36, -102, 316, 186)
var focus_id := "player"
var player_at := Vector3.ZERO
var player_heading := 0.0
var kart_at := Vector3.ZERO
var kart_available := false
var active_mission: Dictionary = {}
var completed: Array = []
var missions: Array = []
var game_portals: Array = []
var reduced_motion := false
var canvas: Control
var focus_buttons: Dictionary = {}
var place_buttons: Dictionary = {}
var location_label: Label
var objective_label: Label
var focus_label: Label
var places_grid: GridContainer
var _built := false
var _places: Array[Dictionary] = []


func configure(bounds: Rect2, at: Vector3, heading: float, current_mission: Dictionary, completed_missions: Array, all_missions: Array, portals: Array, reduce_motion := false) -> void:
	if bounds.size.x > 0 and bounds.size.y > 0:
		world_bounds = bounds
	player_at = at
	player_heading = heading
	kart_available = false
	active_mission = current_mission.duplicate(true)
	completed = completed_missions.duplicate(true)
	missions = all_missions.duplicate(true)
	game_portals = portals.duplicate(true)
	reduced_motion = reduce_motion
	_places = [
		{"id": "island", "title": "Schatzinsel", "at": Vector3(0, 0, -43), "view": Rect2(-36, -82, 105, 112)},
		{"id": "village", "title": "Sonnendorf", "at": Vector3(115, 0, -79), "view": Rect2(64, -90, 111, 136)},
		{"id": "city", "title": "Sternenstadt", "at": Vector3(220, 0, -84), "view": Rect2(173, -100, 105, 146)}
	]
	for portal in game_portals:
		if portal is Dictionary and str(portal.get("game", "")) == "settlement":
			_places.append({"id": "own_village", "title": "Dein Dorf", "at": portal.get("at", Vector3(600, 0, 6)), "view": Rect2(280, -238, 640, 476)})
			break
	_build_ui()
	_refresh_places()
	location_label.text = "Du bist hier: " + location_name(player_at)
	objective_label.text = "Dein nächstes Ziel: " + str(active_mission.get("title", "")) if not active_mission.is_empty() else "Alle Aufträge geschafft. Entdecke deine Lieblingsorte!"
	(focus_buttons["objective"] as Button).disabled = active_mission.is_empty()
	(focus_buttons["kart"] as Button).disabled = true
	focus_player()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _built:
		return
	_built = true
	name = "LumoWorldMap"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	location_label = _label("Deine Welt", 18, INK)
	location_label.name = "WorldMapLocation"
	add_child(location_label)
	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 8)
	add_child(focus_row)
	var specs := [
		["player", "Bei mir", "Deinen Standort auf der Karte zeigen", focus_player],
		["objective", "Ziel", "Deinen nächsten Auftrag auf der Karte zeigen", focus_objective],
		["world", "Welt", "Die ganze Lumo World auf der Karte zeigen", focus_world]
	]
	for spec in specs:
		var button := _button(str(spec[1]), spec[3])
		button.name = "WorldMapFocus_" + str(spec[0])
		button.tooltip_text = str(spec[2])
		button.toggle_mode = true
		focus_buttons[spec[0]] = button
		focus_row.add_child(button)
	var kart_button := _button("Mein Kart zeigen", focus_kart)
	kart_button.name = "WorldMapFocus_kart"
	kart_button.tooltip_text = "Den aktuellen Parkplatz deines Karts auf der Karte zeigen"
	kart_button.toggle_mode = true
	kart_button.disabled = not kart_available
	focus_buttons["kart"] = kart_button
	add_child(kart_button)
	focus_label = _label("In deiner Nähe", 15, MUTED)
	focus_label.name = "WorldMapViewLabel"
	add_child(focus_label)
	var atlas_canvas := AtlasCanvas.new()
	atlas_canvas.atlas = self
	canvas = atlas_canvas
	canvas.name = "WorldMapCanvas"
	canvas.custom_minimum_size = Vector2(0, 238)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.resized.connect(canvas.queue_redraw)
	add_child(canvas)
	var legend := HFlowContainer.new()
	legend.name = "WorldMapLegend"
	legend.add_theme_constant_override("h_separation", 16)
	legend.add_theme_constant_override("v_separation", 5)
	add_child(legend)
	for item in [["Du", PLAYER_COLOR], ["Dein Ziel", TARGET_COLOR], ["Spielort", PORTAL_COLOR], ["Dein Kart", KART_COLOR]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.color = item[1]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch)
		var legend_text := _label(str(item[0]), 14, MUTED)
		legend_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(legend_text)
		legend.add_child(line)
	objective_label = _label("", 16, TARGET_COLOR)
	objective_label.name = "WorldMapObjective"
	add_child(objective_label)
	add_child(_label("Orte auf der Karte", 15, MUTED))
	places_grid = GridContainer.new()
	places_grid.name = "WorldMapPlaces"
	places_grid.columns = 2
	places_grid.add_theme_constant_override("h_separation", 8)
	places_grid.add_theme_constant_override("v_separation", 8)
	add_child(places_grid)


func _refresh_places() -> void:
	for child in places_grid.get_children():
		places_grid.remove_child(child)
		child.queue_free()
	place_buttons.clear()
	for place in _places:
		var id: String = str(place.id)
		var button := _button(str(place.title), focus_place.bind(id))
		button.name = "WorldMapPlace_" + id
		button.tooltip_text = str(place.title) + " auf der Karte ansehen"
		button.toggle_mode = true
		places_grid.add_child(button)
		place_buttons[id] = button


func _label(text: String, size_px: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size_px)
	result.add_theme_color_override("font_color", color)
	return result


func _button(text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, MIN_TOUCH)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_size_override("font_size", 15)
	result.add_theme_color_override("font_color", INK)
	result.add_theme_color_override("font_hover_color", INK)
	result.add_theme_color_override("font_pressed_color", INK)
	result.add_theme_color_override("font_disabled_color", Color("8ba9ad"))
	result.add_theme_stylebox_override("normal", _panel(Color("174457"), Color("4d8490"), 12))
	result.add_theme_stylebox_override("hover", _panel(Color("20566a"), PORTAL_COLOR, 12))
	result.add_theme_stylebox_override("pressed", _panel(Color("235d53"), TARGET_COLOR, 12))
	result.add_theme_stylebox_override("disabled", _panel(Color("173746"), Color("365867"), 12))
	result.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, Color("fff1b4"), 12, 3))
	result.pressed.connect(action)
	return result


func _panel(fill: Color, stroke: Color, radius: int, border := 1) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = fill
	panel.border_color = stroke
	panel.set_border_width_all(border)
	panel.set_corner_radius_all(radius)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	return panel


func focus_player() -> void:
	# A neighbourhood view keeps the original island and both towns legible.
	# The saved village has its own local view rather than shrinking everything.
	var extent := Rect2(-36, -102, 316, 186)
	if player_at.x >= 280:
		extent = Rect2(Vector2(player_at.x, player_at.z) - Vector2(160, 115), Vector2(320, 230))
	_set_view(extent, "player", "In deiner Nähe")


func focus_objective() -> void:
	if active_mission.is_empty():
		return
	var at: Vector3 = active_mission.get("at", player_at)
	var extent := Rect2(Vector2(at.x, at.z) - Vector2(80, 60), Vector2(160, 120))
	_set_view(extent, "objective", "Dein Ziel: " + str(active_mission.get("title", "Auftrag")))


func focus_world() -> void:
	_set_view(world_bounds, "world", "Die ganze Lumo World")


func set_kart_position(at: Vector3) -> void:
	kart_available = at.is_finite() and world_bounds.has_point(Vector2(at.x, at.z))
	if kart_available:
		kart_at = at
	_build_ui()
	(focus_buttons["kart"] as Button).disabled = not kart_available
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func focus_kart() -> void:
	if kart_available:
		var extent := Rect2(Vector2(kart_at.x, kart_at.z) - Vector2(80, 60), Vector2(160, 120))
		_set_view(extent, "kart", "Dein Kart: " + location_name(kart_at))


func focus_place(id: String) -> void:
	for place in _places:
		if str(place.id) == id:
			_set_view(place.view, id, str(place.title))
			return


func _set_view(requested: Rect2, id: String, title: String) -> void:
	var extent := Vector2(minf(requested.size.x, world_bounds.size.x), minf(requested.size.y, world_bounds.size.y))
	var origin := Vector2(
		clampf(requested.position.x, world_bounds.position.x, world_bounds.end.x - extent.x),
		clampf(requested.position.y, world_bounds.position.y, world_bounds.end.y - extent.y))
	view_bounds = Rect2(origin, extent)
	focus_id = id
	if is_instance_valid(focus_label):
		focus_label.text = title
	for key in focus_buttons:
		(focus_buttons[key] as Button).set_pressed_no_signal(str(key) == id)
	for key in place_buttons:
		(place_buttons[key] as Button).set_pressed_no_signal(str(key) == id)
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func location_name(at: Vector3) -> String:
	if at.x >= 280:
		return "Dein Dorf"
	if at.x >= 173:
		return "Sternenstadt"
	if at.x >= 64:
		return "Sonnendorf"
	if at.x >= 34:
		return "Inselbrücke"
	return "Schatzinsel"


func atlas_rect(viewport_size: Vector2) -> Rect2:
	var available := (viewport_size - Vector2(24, 24)).max(Vector2.ONE)
	var scale := minf(available.x / view_bounds.size.x, available.y / view_bounds.size.y)
	var extent := view_bounds.size * scale
	return Rect2((viewport_size - extent) * 0.5, extent)


func project_position(at: Vector3, viewport_size: Vector2) -> Vector2:
	var rect := atlas_rect(viewport_size)
	return rect.position + (Vector2(at.x, at.z) - view_bounds.position) / view_bounds.size * rect.size


func _inside(at: Vector3) -> bool:
	return view_bounds.has_point(Vector2(at.x, at.z))


func draw_atlas(surface: Control) -> void:
	var full := Rect2(Vector2.ZERO, surface.size)
	surface.draw_style_box(_panel(Color("0b2b3b"), Color("528b95"), 16), full)
	var rect := atlas_rect(surface.size)
	surface.draw_rect(rect, OCEAN)
	_draw_grid(surface, rect)
	_draw_land(surface, Rect2(-35, -72, 72, 86), Color("6e9b64"))
	_draw_land(surface, Rect2(62, -98, 214, 174), Color("789568"))
	_draw_land(surface, Rect2(280, -238, 640, 476), LAND)
	_draw_road(surface, Vector3(34, 0, 6), Vector3(64, 0, 6), 5)
	_draw_road(surface, Vector3(68, 0, 0), Vector3(270, 0, 0), 4)
	_draw_road(surface, Vector3(271, 0, 6), Vector3(497.2, 0, 6), 3)
	for x in [90.0, 110.0, 135.0, 192.0, 218.0, 239.0]:
		_draw_road(surface, Vector3(x, 0, -65), Vector3(x, 0, -7), 2)
	_draw_road(surface, Vector3(73, 0, 18), Vector3(147, 0, 18), 2)
	_draw_road(surface, Vector3(182, 0, -45), Vector3(254, 0, -45), 2)
	_draw_place_names(surface, rect)
	for mission in missions:
		if not mission is Dictionary or str(mission.get("id", "")) == str(active_mission.get("id", "")):
			continue
		var at: Vector3 = mission.get("at", Vector3.ZERO)
		if _inside(at):
			var point := project_position(at, surface.size)
			var done: bool = str(mission.get("id", "")) in completed
			surface.draw_circle(point, 3.5, Color("bad795") if done else Color("ead6a0"))
	for portal in game_portals:
		if portal is Dictionary:
			var at: Vector3 = portal.get("at", Vector3.ZERO)
			if _inside(at):
				var point := project_position(at, surface.size)
				var diamond := PackedVector2Array([point + Vector2(0, -6), point + Vector2(6, 0), point + Vector2(0, 6), point + Vector2(-6, 0)])
				surface.draw_colored_polygon(diamond, Color("073749"))
				surface.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), PORTAL_COLOR, 2, true)
	if not active_mission.is_empty():
		var at: Vector3 = active_mission.get("at", player_at)
		_draw_marker(surface, at, TARGET_COLOR, true)
	if kart_available and _inside(kart_at):
		_draw_kart_marker(surface)
	_draw_marker(surface, player_at, PLAYER_COLOR, false)
	_draw_north(surface, rect)
	_draw_scale(surface, rect)


func _draw_grid(surface: Control, rect: Rect2) -> void:
	var stride := 100.0 if view_bounds.size.x > 500 else 50.0
	var x := ceilf(view_bounds.position.x / stride) * stride
	while x < view_bounds.end.x:
		var point := project_position(Vector3(x, 0, 0), surface.size)
		surface.draw_line(Vector2(point.x, rect.position.y), Vector2(point.x, rect.end.y), Color(0.55, 0.82, 0.85, 0.09), 1)
		x += stride
	var z := ceilf(view_bounds.position.y / stride) * stride
	while z < view_bounds.end.y:
		var point := project_position(Vector3(0, 0, z), surface.size)
		surface.draw_line(Vector2(rect.position.x, point.y), Vector2(rect.end.x, point.y), Color(0.55, 0.82, 0.85, 0.09), 1)
		z += stride


func _draw_land(surface: Control, land: Rect2, color: Color) -> void:
	var clipped := land.intersection(view_bounds)
	if not clipped.has_area():
		return
	var first := project_position(Vector3(clipped.position.x, 0, clipped.position.y), surface.size)
	var last := project_position(Vector3(clipped.end.x, 0, clipped.end.y), surface.size)
	var mapped := Rect2(first, last - first)
	surface.draw_rect(mapped, color)
	surface.draw_rect(mapped, Color("b5c698"), false, 1)


func _draw_road(surface: Control, from: Vector3, to: Vector3, width: float) -> void:
	var rect := atlas_rect(surface.size)
	var segment := _clip_segment(project_position(from, surface.size), project_position(to, surface.size), rect)
	if segment.size() == 2:
		surface.draw_line(segment[0], segment[1], Color("455c50"), width + 2, true)
		surface.draw_line(segment[0], segment[1], Color("e7d5ac"), width, true)


func _draw_place_names(surface: Control, rect: Rect2) -> void:
	var font := surface.get_theme_default_font()
	var font_size := 13
	var occupied: Array[Rect2] = [Rect2(Vector2(rect.end.x - 30, rect.position.y + 2), Vector2(30, 30))]
	for place in _places:
		var at: Vector3 = place.at
		if not _inside(at):
			continue
		var title: String = str(place.title)
		var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var position := project_position(at, surface.size)
		var label_rect := Rect2(position - Vector2(text_size.x * 0.5 + 5, text_size.y + 11), text_size + Vector2(10, 6))
		label_rect.position.x = clampf(label_rect.position.x, rect.position.x + 2, maxf(rect.position.x + 2, rect.end.x - label_rect.size.x - 2))
		label_rect.position.y = clampf(label_rect.position.y, rect.position.y + 2, maxf(rect.position.y + 2, rect.end.y - label_rect.size.y - 2))
		var collides := true
		for attempt in range(3):
			collides = false
			for used in occupied:
				if label_rect.intersects(used.grow(3)):
					collides = true
					break
			if not collides:
				break
			label_rect.position.y += label_rect.size.y + 3
			if label_rect.end.y > rect.end.y - 4:
				break
		if collides or label_rect.size.x > rect.size.x - 4:
			continue
		occupied.append(label_rect)
		surface.draw_style_box(_panel(Color("163e49"), Color("9fc2a7"), 6), label_rect)
		surface.draw_string(font, label_rect.position + Vector2(5, font.get_ascent(font_size) + 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)


func _draw_marker(surface: Control, at: Vector3, color: Color, target: bool) -> void:
	var rect := atlas_rect(surface.size).grow(-10)
	var projected := project_position(at, surface.size)
	var point := projected
	var outside := not _inside(at)
	if outside:
		var clipped := _clip_segment(rect.get_center(), projected, rect)
		if clipped.size() != 2:
			return
		point = clipped[1]
	surface.draw_circle(point, 10, Color("092a36"))
	surface.draw_arc(point, 10, 0, TAU, 24, color, 2, true)
	if target:
		var star := PackedVector2Array()
		for index in range(10):
			var angle := -PI * 0.5 + float(index) * PI / 5.0
			star.append(point + Vector2(cos(angle), sin(angle)) * (7.0 if index % 2 == 0 else 3.2))
		surface.draw_colored_polygon(star, color)
	else:
		var direction := Vector2(sin(player_heading), cos(player_heading))
		var side := Vector2(-direction.y, direction.x)
		var arrow := PackedVector2Array([point + direction * 7, point - direction * 5 + side * 5, point - direction * 3, point - direction * 5 - side * 5])
		surface.draw_colored_polygon(arrow, color)
	if outside:
		var direction := (projected - point).normalized()
		var side := Vector2(-direction.y, direction.x)
		var tip := point + direction * 17
		surface.draw_polyline(PackedVector2Array([tip - direction * 5 + side * 4, tip, tip - direction * 5 - side * 4]), color, 2, true)


func _draw_kart_marker(surface: Control) -> void:
	var point := project_position(kart_at, surface.size)
	surface.draw_circle(point, 10, Color("092a36"))
	surface.draw_arc(point, 10, 0, TAU, 24, KART_COLOR, 2, true)
	surface.draw_rect(Rect2(point - Vector2(4, 7), Vector2(8, 14)), KART_COLOR)
	for side in [-1.0, 1.0]:
		for axle in [-4.0, 4.0]:
			surface.draw_rect(Rect2(point + Vector2(side * 6 - 1.5, axle - 2), Vector2(3, 4)), KART_COLOR)


func _draw_north(surface: Control, rect: Rect2) -> void:
	var font := surface.get_theme_default_font()
	var point := Vector2(rect.end.x - 16, rect.position.y + 18)
	surface.draw_circle(point, 12, Color("103747"))
	surface.draw_string(font, point + Vector2(-4.5, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


func _draw_scale(surface: Control, rect: Rect2) -> void:
	var units := 100.0 if view_bounds.size.x > 500 else 25.0
	var length := units * rect.size.x / view_bounds.size.x
	var point := rect.position + Vector2(9, rect.size.y - 12)
	surface.draw_rect(Rect2(point - Vector2(5, 17), Vector2(maxf(length, 29) + 10, 25)), Color("103747"))
	surface.draw_line(point, point + Vector2(length, 0), INK, 2)
	surface.draw_line(point - Vector2(0, 3), point + Vector2(0, 3), INK, 2)
	surface.draw_line(point + Vector2(length, -3), point + Vector2(length, 3), INK, 2)
	surface.draw_string(surface.get_theme_default_font(), point - Vector2(0, 5), "%d m" % int(units), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)


func _clip_segment(first: Vector2, last: Vector2, rect: Rect2) -> PackedVector2Array:
	# Liang–Barsky clipping keeps roads and edge indicators within the atlas.
	var direction := last - first
	var lower := 0.0
	var upper := 1.0
	var p := [-direction.x, direction.x, -direction.y, direction.y]
	var q := [first.x - rect.position.x, rect.end.x - first.x, first.y - rect.position.y, rect.end.y - first.y]
	for index in range(4):
		if is_zero_approx(float(p[index])):
			if float(q[index]) < 0:
				return PackedVector2Array()
			continue
		var ratio := float(q[index]) / float(p[index])
		if float(p[index]) < 0:
			lower = maxf(lower, ratio)
		else:
			upper = minf(upper, ratio)
		if lower > upper:
			return PackedVector2Array()
	return PackedVector2Array([first + lower * direction, first + upper * direction])


## Text-only context for an unsolved delivery; never creates a target marker.
func set_objective_note(message: String) -> void:
	if is_instance_valid(objective_label) and not message.strip_edges().is_empty():
		objective_label.text = message
