extends Node3D
## Lumo Schach: Startbildschirm mit drei Wegen, Schachschule, geführtes
## Probespiel und Partien gegen Lumo – am Tisch im Spielzimmer (3D) oder in
## der klaren Draufsicht. Lumo (das echte geriggte Modell) sitzt gegenüber.
##
## Regeln: chess_rules.gd · Gegner: chess_ai.gd · Lehrer: chess_coach.gd ·
## Schule und Probespiel: chess_school.gd · Brett: chess_set.gd /
## chess_board_2d.gd · Spielstand je Kind: chess_session.gd.
## Ergebnisse gehen genau einmal an HostBridge.reward (Spiel "chess").

signal settled(payload: Dictionary)
signal screen_changed(screen: String)

const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const AI = preload("res://scripts/games/chess/chess_ai.gd")
const COACH = preload("res://scripts/games/chess/chess_coach.gd")
const SCHOOL = preload("res://scripts/games/chess/chess_school.gd")
const SESSION = preload("res://scripts/games/chess/chess_session.gd")
const SET = preload("res://scripts/games/chess/chess_set.gd")
const BOARD2D = preload("res://scripts/games/chess/chess_board_2d.gd")
const ROOM = preload("res://scripts/games/cards/cards_room.gd")
const SEAT = preload("res://scripts/games/cards/cards_seat.gd")
const ICONS := "res://assets/chess/icons/%s.webp"
const LUMO_ANGLE := 180.0
## Das Brett ist größer als ein Spielbrett am Kartentisch: Figuren bleiben am
## Handy gut greifbar, und Lumo sitzt trotzdem sichtbar gegenüber.
const BOARD_SCALE := 1.4
const LEVEL_STARS := [1, 2, 3, 4]
## Kurzbeschreibung je Stufe (ehrlich: was Lumo auf dieser Stufe tut).
const LEVEL_TEXT := [
	"sieht Schlagzüge, macht noch Fehler", "rechnet drei Halbzüge voraus",
	"rechnet bis 2 s, kennt Eröffnungen", "volle Bedenkzeit (bis 7 s), die schwerste Stufe",
]
const LEVEL_ICONS := ["w_pawn", "w_knight", "w_queen", "w_king"]
const GOLD := Color("ffd166")
const NAVY := Color("16284a")
const CREAM := Color("fff4dc")

var session: RefCounted
var rules: RefCounted
var room: Node3D
var camera: Camera3D
var chess: Node3D
var board2d: Control
var lumo: Node3D
var ai: RefCounted
var rng := RandomNumberGenerator.new()
var reduced_motion := false
var sound_enabled := true
var time_scale := 1.0
## Nur für Prüfungen: simulierte Safe-Area (links, oben, rechts, unten).
var safe_override := Rect2(-1, -1, -1, -1)

## "home", "path", "levels", "lesson", "trial", "match"
var screen := ""
var mode := "kids"  # kids · play · pro
var level := 0
var view := "3d"
var hints := true
var coords := true
var lesson_id := ""
var step_index := 0
var mistakes := 0
var collect_moves := 0
var collect_cap := 3
var stars_left: Array[int] = []
var trial_id := ""
var result_id := ""
var finished := false
var selected := -1
var busy := false
var thinking := false
var last_explain := ""
var overlay_kind := ""
var _generation := 0
var _press_square := -1
var _press_point := Vector2.ZERO
var _dragging := false
var _pending_warn := -1
var _danger_sq := -1
var _previous_window: Dictionary = {}
var _density := 1.0
var _board_rect := Rect2()
var _closed := false

var ui: Control
var bubble: PanelContainer
var bubble_text: Label
var bubble_title: Label
var bar: GridContainer
var overlay: PanelContainer
var overlay_box: VBoxContainer
var buttons: Dictionary = {}
var _theme: Theme


func _ready() -> void:
	var window := get_window()
	_previous_window = {"scale": window.content_scale_size, "quit": get_tree().quit_on_go_back,
		"orientation": DisplayServer.screen_get_orientation()}
	window.content_scale_size = Vector2i.ZERO
	get_tree().quit_on_go_back = false
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	var options: Dictionary = HostBridge.launch_options()
	for key: String in SceneRouter.launch_options:
		if not options.has(key):
			options[key] = SceneRouter.launch_options[key]
	reduced_motion = bool(options.get("reduceAnimations", false))
	sound_enabled = bool(options.get("soundEnabled", true))
	rng.randomize()
	session = SESSION.new(SESSION.path_for(str(options.get("childKey", ""))))
	session.load_file()
	hints = bool(session.pref("hints", true))
	coords = bool(session.pref("coords", true))
	view = str(session.pref("view", "3d"))
	level = int(session.pref("level", 0))
	room = ROOM.new()
	room.name = "Room"
	add_child(room)
	camera = room.camera
	_tune_room()
	chess = SET.new()
	chess.name = "ChessSet"
	chess.position = Vector3(0, ROOM.TABLE_Y, 0)
	chess.scale = Vector3.ONE * BOARD_SCALE
	add_child(chess)
	chess.reduced_motion = reduced_motion
	_build_lumo()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	MobileRuntime.safe_area_changed.connect(_layout)
	ai = AI.new(int(rng.randi() & 0xFFFF) + 1)
	open_home()
	_layout()
	_greet.call_deferred()


func _exit_tree() -> void:
	_closed = true
	_generation += 1
	if ai != null:
		ai.stopped = true
	if MobileRuntime.safe_area_changed.is_connected(_layout):
		MobileRuntime.safe_area_changed.disconnect(_layout)
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	if not _previous_window.is_empty():
		get_window().content_scale_size = _previous_window.scale
		get_tree().quit_on_go_back = _previous_window.quit
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(_previous_window.orientation)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		_store()


func _process(delta: float) -> void:
	if is_instance_valid(lumo):
		lumo.advance(delta)


## Spielzimmer fürs Schach: Licht etwas weicher (helles Ahorn soll nicht
## ausbrennen), der Sternenkreis im Filz bleibt ruhig, kein Staub vor der Linse.
func _tune_room() -> void:
	if room.key_light != null:
		room.key_light.light_energy = 2.1
		room.key_light.spot_angle = 64.0
	if room.table_glow_material != null:
		var felt: StandardMaterial3D = room.table_glow_material
		room.table_glow_material = null
		felt.emission_energy_multiplier = 0.25
	var dust := room.get_node_or_null("LampDust")
	if dust != null:
		dust.queue_free()
	if room.environment != null:
		room.environment.tonemap_exposure = 1.0


func _sfx(name: String) -> void:
	if sound_enabled:
		AudioManager.play_sfx(name)


# ======================================================================= Lumo


func _build_lumo() -> void:
	lumo = SEAT.new()
	lumo.name = "SeatLumo"
	add_child(lumo)
	lumo.setup("lumo", ROOM.seat_transform(LUMO_ANGLE, ROOM.LUMO_RADIUS), 0)
	lumo.set_reduced_motion(reduced_motion)
	room.add_stool(LUMO_ANGLE, lumo.tint, ROOM.LUMO_RADIUS, false, ROOM.LUMO_LIFT)


func _greet() -> void:
	if is_instance_valid(lumo) and not _closed:
		lumo.look_at_point(camera.global_position)
		lumo.react("wave")


func _lumo_look_board(sq: int = -1) -> void:
	if not is_instance_valid(lumo):
		return
	var at := Vector3(0, ROOM.TABLE_Y, 0)
	if sq >= 0:
		at = chess.to_global(SET.square_center(sq))
	lumo.look_at_point(at)


# ====================================================================== Bilder


func _icon(key: String) -> Texture2D:
	var path := ICONS % key
	return load(path) if ResourceLoader.exists(path) else null


func _style(face: Color, edge: Color, radius: int = 18, border: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = edge
	style.set_border_width_all(int(border * _density))
	style.set_corner_radius_all(int(radius * _density))
	style.set_content_margin_all(10.0 * _density)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = int(4 * _density)
	style.shadow_offset = Vector2(0, 2 * _density)
	return style


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = int(19 * _density)
	theme.set_stylebox("normal", "Button", _style(Color("2c4a7c"), GOLD.darkened(0.15)))
	theme.set_stylebox("hover", "Button", _style(Color("365b96"), GOLD))
	theme.set_stylebox("pressed", "Button", _style(Color("1f3760"), GOLD))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", _style(Color("3a4458"), Color("59647a")))
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("9aa3b5"))
	theme.set_color("font_color", "Label", CREAM)
	theme.set_constant("h_separation", "Button", int(10 * _density))
	theme.set_constant("icon_max_width", "Button", int(46 * _density))
	theme.set_stylebox("panel", "PanelContainer", _style(Color(0.07, 0.11, 0.22, 0.92), GOLD.darkened(0.25), 22))
	return theme


# ========================================================================== UI


func _build_ui() -> void:
	_density = MobileRuntime.get_ui_density()
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)
	ui = Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_theme = _make_theme()
	ui.theme = _theme
	board2d = BOARD2D.new()
	board2d.name = "TopView"
	board2d.visible = false
	ui.add_child(board2d)
	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bubble)
	var bubble_box := VBoxContainer.new()
	bubble_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(bubble_box)
	bubble_title = Label.new()
	bubble_title.add_theme_color_override("font_color", GOLD)
	bubble_box.add_child(bubble_title)
	bubble_text = Label.new()
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_box.add_child(bubble_text)
	bar = GridContainer.new()
	bar.name = "Bar"
	ui.add_child(bar)
	for spec: Array in [["Hint", "Tipp", _on_hint], ["Why", "Warum?", _on_why], ["Undo", "Zurück", _on_undo],
			["Next", "Weiter", _on_next], ["Show", "Zeig es mir", _on_show_me], ["View", "Von oben", _on_view],
			["Pause", "Pause", _on_pause]]:
		var button := _button(str(spec[1]), spec[2])
		button.name = str(spec[0])
		bar.add_child(button)
		buttons[str(spec[0])] = button
	overlay = PanelContainer.new()
	overlay.name = "Overlay"
	overlay.visible = false
	ui.add_child(overlay)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	overlay_box = VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", int(10 * _density))
	scroll.add_child(overlay_box)


func _button(text: String, callback: Callable, icon_key: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56 * _density)
	button.focus_mode = Control.FOCUS_NONE
	if not icon_key.is_empty():
		button.icon = _icon(icon_key)
		button.expand_icon = false
	button.pressed.connect(func() -> void:
		_sfx("ui_click")
		callback.call())
	return button


func find_button(id: String) -> Button:
	if buttons.has(id) and is_instance_valid(buttons[id]):
		return buttons[id]
	return null


func say(text: String, title: String = "Lumo") -> void:
	bubble_title.text = title
	bubble_text.text = text
	bubble.visible = not text.is_empty()


func _safe_insets() -> Rect2:
	if safe_override.position.x >= 0.0:
		return safe_override
	if OS.has_feature("mobile"):
		return MobileRuntime.get_safe_area_insets()
	return Rect2()


func safe_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var insets := _safe_insets()
	return Rect2(insets.position, size - insets.position - insets.size)


func _layout() -> void:
	if _closed or not is_instance_valid(ui):
		return
	var safe := safe_rect()
	var gap := 10.0 * _density
	var portrait := safe.size.y >= safe.size.x
	var rows := 1
	var shown := 0
	for b: Node in bar.get_children():
		shown += 1 if (b as Button).visible else 0
	var bar_width := safe.size.x - 2 * gap if portrait else clampf(safe.size.x * 0.34, 240.0 * _density, 380.0 * _density)
	var per_row := clampi(int((bar_width + 6 * _density) / (124.0 * _density)), 1, maxi(shown, 1))
	rows = int(ceil(float(maxi(shown, 1)) / per_row))
	var bar_h := (56.0 * rows + 6.0 * (rows - 1)) * _density
	for id: String in buttons:
		var b: Button = buttons[id]
		b.custom_minimum_size = Vector2(0, 56 * _density)
	bar.add_theme_constant_override("h_separation", int(6 * _density))
	bar.add_theme_constant_override("v_separation", int(6 * _density))
	var board_area := safe.grow(-gap)
	var in_game := screen in ["lesson", "trial", "match"]
	if portrait:
		bubble.size = Vector2(safe.size.x - 2 * gap, 0)
		bubble.custom_minimum_size = Vector2(safe.size.x - 2 * gap, 0)
		bubble.reset_size()
		var bubble_h := maxf(bubble.size.y, 92.0 * _density) if bubble.visible else 0.0
		_wrap_bar(safe.size.x - 2 * gap)
		bar_h = bar.size.y if in_game else 0.0
		bar.position = Vector2(safe.position.x + gap, safe.end.y - bar_h - gap)
		if in_game:
			# Im Spiel steht Lumos Sprechblase unten über den Knöpfen: oben bleibt
			# Platz für Lumo, das Brett füllt die Breite.
			bubble.position = Vector2(safe.position.x + gap, bar.position.y - bubble_h - gap)
			board_area = Rect2(safe.position.x + gap, safe.position.y + gap,
				safe.size.x - 2 * gap, safe.size.y - bubble_h - bar_h - 4 * gap)
		else:
			bubble.position = safe.position + Vector2(gap, gap)
			board_area = Rect2(safe.position.x + gap, safe.position.y + bubble_h + 2 * gap,
				safe.size.x - 2 * gap, safe.size.y - bubble_h - bar_h - 4 * gap)
	else:
		var side := clampf(safe.size.x * 0.34, 240.0 * _density, 380.0 * _density)
		bubble.position = Vector2(safe.end.x - side - gap, safe.position.y + gap)
		bubble.custom_minimum_size = Vector2(side, 0)
		bubble.size = Vector2(side, 0)
		bubble.reset_size()
		bar.position = Vector2(safe.end.x - side - gap, safe.end.y - bar_h - gap)
		bar.size = Vector2(side, bar_h)
		board_area = Rect2(safe.position.x + gap, safe.position.y + gap, safe.size.x - side - 3 * gap, safe.size.y - 2 * gap)
		_wrap_bar(side)
	board_area.size = board_area.size.max(Vector2(8, 8))
	_board_rect = board_area
	var square := minf(board_area.size.x, board_area.size.y)
	board2d.position = board_area.position + (board_area.size - Vector2(square, square)) * 0.5
	board2d.size = Vector2(square, square)
	# Überlagerung: mittig, nie über die Safe-Area hinaus.
	var ow := minf(safe.size.x - 2 * gap, 560.0 * _density)
	var oh := minf(safe.size.y - 2 * gap, 760.0 * _density)
	overlay.custom_minimum_size = Vector2(ow, 0)
	overlay.size = Vector2(ow, 0)
	overlay.reset_size()
	var scroll: ScrollContainer = overlay.get_node("Scroll")
	scroll.custom_minimum_size = Vector2(ow - 24 * _density, minf(overlay_box.get_combined_minimum_size().y, oh - 24 * _density))
	overlay.reset_size()
	overlay.position = safe.position + (safe.size - overlay.size) * 0.5
	_frame_camera()


## Knöpfe der Leiste: so viele Spalten, wie mit lesbarer Breite passen.
func _wrap_bar(width: float) -> void:
	var visible_buttons: Array[Button] = []
	for b: Node in bar.get_children():
		if (b as Button).visible:
			visible_buttons.append(b)
	if visible_buttons.is_empty():
		return
	var gap := 6 * _density
	var columns := clampi(int((width + gap) / (118.0 * _density + gap)), 1, visible_buttons.size())
	bar.columns = columns
	var each := (width - gap * (columns - 1)) / columns
	for b: Button in visible_buttons:
		b.add_theme_font_size_override("font_size", int(19 * _density))
		b.custom_minimum_size.x = each
		b.clip_text = true
	bar.size = Vector2(width, 0)
	bar.reset_size()


## Kamera so, dass das Brett die freie Fläche füllt und Lumo gegenüber sichtbar ist.
## Binäre Suche über den Abstand; je Abstand wird die Kamera seitlich und in der
## Höhe verschoben, bis die Hülle aller Punkte mittig in der freien Fläche liegt.
func _frame_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x < 2 or size.y < 2:
		return
	var aspect := size.x / size.y
	var in_game := screen in ["lesson", "trial", "match"]
	camera.fov = 40.0 if aspect < 1.0 else 34.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.v_offset = 0.0
	camera.h_offset = 0.0
	var tilt := deg_to_rad(48.0 if in_game else 30.0)
	var target := Vector3(0, ROOM.TABLE_Y, -0.2)
	var corners: Array[Vector3] = []
	for x: float in [-0.53, 0.53]:
		for z: float in [-0.53, 0.53]:
			corners.append(chess.to_global(Vector3(x, 0.0, z)))
	corners.append(chess.to_global(Vector3(0.0, 0.12, -0.38)))
	# Lumo gegenüber: Kopf und Ohren sollen im Bild sein.
	if is_instance_valid(lumo):
		corners.append(lumo.to_global(Vector3(0, 1.98, 0)))
	var area := _board_rect
	var lo := 0.4
	var hi := 12.0
	for i in 28:
		var mid := (lo + hi) * 0.5
		if _place_camera(target, tilt, mid, area, size, corners):
			hi = mid
		else:
			lo = mid
	_place_camera(target, tilt, hi, area, size, corners)


## Stellt die Kamera auf `distance` und zentriert die Punkte in `area`.
## Gibt zurück, ob alle Punkte hineinpassen.
func _place_camera(target: Vector3, tilt: float, distance: float, area: Rect2, size: Vector2,
		points: Array[Vector3]) -> bool:
	camera.position = target + Vector3(0, sin(tilt), cos(tilt)) * distance
	camera.look_at(target)
	var half_h := tan(deg_to_rad(camera.fov * 0.5)) * distance
	var px_to_world := 2.0 * half_h / size.y
	var shift := area.get_center() - size * 0.5
	camera.h_offset = -shift.x * px_to_world
	camera.v_offset = shift.y * px_to_world
	for _pass in 4:
		var box := _projected_box(points)
		if box.size.x < 0.0:
			return false
		var miss := box.get_center() - area.get_center()
		camera.h_offset += miss.x * px_to_world
		camera.v_offset -= miss.y * px_to_world
	return _fits(points, area)


func _projected_box(points: Array[Vector3]) -> Rect2:
	var box := Rect2()
	var first := true
	for p: Vector3 in points:
		if camera.is_position_behind(p):
			return Rect2(0, 0, -1, -1)
		var q := camera.unproject_position(p)
		if first:
			box = Rect2(q, Vector2.ZERO)
			first = false
		else:
			box = box.expand(q)
	return box


func _fits(points: Array[Vector3], area: Rect2) -> bool:
	for p: Vector3 in points:
		if camera.is_position_behind(p):
			return false
		if not area.has_point(camera.unproject_position(p)):
			return false
	return true


# ==================================================================== Bildschirme


func _clear_overlay() -> void:
	for child: Node in overlay_box.get_children():
		overlay_box.remove_child(child)
		child.queue_free()
	for key: String in buttons.keys():
		if str(key).begins_with("o_"):
			buttons.erase(key)


func _overlay_label(text: String, size: int = 19, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(size * _density))
	label.add_theme_color_override("font_color", color)
	overlay_box.add_child(label)
	return label


func _overlay_button(id: String, text: String, callback: Callable, icon_key: String = "", big: bool = false) -> Button:
	var button := _button(text, callback, icon_key)
	button.name = id
	button.custom_minimum_size = Vector2(0, (84 if big else 60) * _density)
	button.add_theme_font_size_override("font_size", int((22 if big else 19) * _density))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if not icon_key.is_empty() else HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(button)
	buttons["o_" + id] = button
	return button


func _show_overlay(kind: String) -> void:
	overlay_kind = kind
	overlay.visible = true
	overlay.get_node("Scroll").scroll_vertical = 0
	_layout()
	_layout.call_deferred()


func close_overlay() -> void:
	overlay_kind = ""
	overlay.visible = false
	_clear_overlay()
	_layout()


func _set_screen(value: String) -> void:
	screen = value
	var in_game := value in ["lesson", "trial", "match"]
	board2d.visible = in_game and view == "top"
	chess.visible = true
	for id: String in ["Hint", "Why", "Undo", "Next", "Show", "View", "Pause"]:
		(buttons[id] as Button).visible = false
	if in_game:
		buttons.View.visible = true
		buttons.Pause.visible = true
		(buttons.View as Button).text = "3D" if view == "top" else "Von oben"
	bar.visible = in_game
	screen_changed.emit(value)
	_layout()


func _update_view() -> void:
	var in_game := screen in ["lesson", "trial", "match"]
	board2d.visible = in_game and view == "top"
	(buttons.View as Button).text = "3D" if view == "top" else "Von oben"
	board2d.coords = coords
	chess.set_coords_visible(coords)
	board2d.queue_redraw()
	_layout()


## Startbildschirm: drei große Wege. Der Kinderweg steht oben (Vorgabe).
func open_home() -> void:
	_generation += 1
	_end_game_state()
	_set_screen("home")
	chess.show_board(RULES.new().board)
	chess.set_glow({})
	chess.set_props([], [])
	say("Hallo! Ich bin Lumo. Wollen wir Schach spielen?")
	_clear_overlay()
	_overlay_label("Lumo Schach", 30, GOLD)
	_overlay_button("Kids", "Schach lernen (für Kinder)", open_path, "w_pawn", true)
	_overlay_button("Play", "Gegen Lumo spielen", func() -> void: open_levels("play"), "w_knight", true)
	_overlay_button("Pro", "Für Große", func() -> void: open_levels("pro"), "w_king", true)
	_overlay_button("Rules", "Regeln ansehen", open_rules)
	_overlay_button("Leave", "Zur Spielewelt", leave)
	_show_overlay("home")


func _done(kind: String, id: String) -> bool:
	return session.lesson_stars(id) > 0 if kind == "lesson" else session.trial_done(id)


## Der Lernweg für Kinder: Lektionen und Probespiel-Stufen der Reihe nach.
func open_path() -> void:
	_generation += 1
	_end_game_state()
	mode = "kids"
	_set_screen("path")
	say("Wir lernen Schach Stück für Stück. Tippe auf das Leuchtende!")
	_clear_overlay()
	_overlay_label("Schach lernen", 26, GOLD)
	var first_open := -1
	for i in SCHOOL.PATH.size():
		var entry: Array = SCHOOL.PATH[i]
		var kind := str(entry[0])
		var id := str(entry[1])
		var open := SCHOOL.unlocked(i, _done)
		var done := _done(kind, id)
		if open and not done and first_open < 0:
			first_open = i
		var stars := ""
		if kind == "lesson" and done:
			stars = "  " + "★".repeat(session.lesson_stars(id))
		elif done:
			stars = "  ★"
		var prefix := "Probespiel: " if kind == "trial" else ""
		var caption := "%s%s%s" % [prefix, SCHOOL.title(kind, id), stars]
		var button := _overlay_button("Path_%s" % id, caption, func() -> void: _open_entry(kind, id), SCHOOL.icon(kind, id))
		button.disabled = not open
		if i == first_open:
			button.add_theme_stylebox_override("normal", _style(Color("3d7a4a"), GOLD, 18, 4))
	_overlay_button("Back", "Zurück", open_home)
	_show_overlay("path")
	if first_open >= 0:
		var target: Button = buttons.get("o_Path_%s" % str(SCHOOL.PATH[first_open][1]))
		if target != null:
			(overlay.get_node("Scroll") as ScrollContainer).ensure_control_visible.call_deferred(target)


func _open_entry(kind: String, id: String) -> void:
	if kind == "lesson":
		start_lesson(id)
	else:
		start_trial(id)


## Stufe wählen (Gegen Lumo / Für Große).
func open_levels(which: String) -> void:
	_generation += 1
	_end_game_state()
	mode = which
	_set_screen("levels")
	_clear_overlay()
	if which == "pro":
		_overlay_label("Für Große", 26, GOLD)
		_overlay_label("Volle Regeln, keine Hilfen, Züge in Schachschrift.", 17)
		say("Ich gebe mir richtig Mühe. Viel Glück!")
	else:
		_overlay_label("Gegen Lumo spielen", 26, GOLD)
		_overlay_label("Mit Tipp, Warum? und Zurück.", 17)
		say("Wie stark soll ich spielen?")
	var slot := _slot()
	if session.has_game(slot):
		_overlay_button("Resume", "Weiterspielen", func() -> void: start_match(-1, true), "w_queen", true)
	for i in 4:
		var lv := i
		var caption := "%s\n%s" % [AI.level_name(i), LEVEL_TEXT[i]]
		var button := _overlay_button("Level%d" % i, caption, func() -> void: start_match(lv, false), LEVEL_ICONS[i])
		button.custom_minimum_size.y = 92 * _density
		if i == 3:
			button.add_theme_stylebox_override("normal", _style(Color("5a2430"), GOLD, 18, 4))
	_overlay_button("Back", "Zurück", open_home)
	_show_overlay("levels")


func open_rules() -> void:
	_clear_overlay()
	_overlay_label("So ziehen die Figuren", 24, GOLD)
	for entry: Array in [
			["w_king", "König: ein Schritt in jede Richtung. Wird er gefangen, ist das Spiel aus."],
			["w_queen", "Dame: gerade und schräg, so weit sie will."],
			["w_rook", "Turm: gerade vor, zurück und zur Seite."],
			["w_bishop", "Läufer: schräg, bleibt immer auf seiner Farbe."],
			["w_knight", "Springer: springt wie ein L, auch über Figuren."],
			["w_pawn", "Bauer: ein Feld vor, am Anfang auch zwei. Schlägt schräg."],
			["", "Schach: Der König wird angegriffen. Matt: Er kann nicht entkommen."],
			["", "Patt: Wer am Zug ist, kann nicht ziehen und steht nicht im Schach. Unentschieden."],
			["", "Rochade, Umwandlung und Schlagen im Vorbeigehen lernst du in der Schachschule."]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(10 * _density))
		if not str(entry[0]).is_empty():
			var pic := TextureRect.new()
			pic.texture = _icon(str(entry[0]))
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(52, 52) * _density
			row.add_child(pic)
		var label := Label.new()
		label.text = str(entry[1])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x = 200 * _density
		row.add_child(label)
		overlay_box.add_child(row)
	var back_to := screen
	_overlay_button("RulesBack", "Verstanden", func() -> void:
		if back_to in ["lesson", "trial", "match"]:
			close_overlay()
		else:
			open_home())
	_show_overlay("rules")


func _on_pause() -> void:
	if screen not in ["lesson", "trial", "match"] or not overlay_kind.is_empty():
		return
	_store()
	if is_instance_valid(lumo):
		lumo.set_suspended(true)
	_clear_overlay()
	_overlay_label("Pause", 26, GOLD)
	_overlay_button("Resume", "Weiter", _resume)
	_overlay_button("Rules", "Regeln", open_rules)
	_overlay_button("Hints", "Felder leuchten: %s" % ("an" if hints else "aus"), func() -> void:
		hints = not hints
		session.set_pref("hints", hints)
		(buttons["o_Hints"] as Button).text = "Felder leuchten: %s" % ("an" if hints else "aus")
		_refresh_glow())
	_overlay_button("Coords", "Feldnamen: %s" % ("an" if coords else "aus"), func() -> void:
		coords = not coords
		session.set_pref("coords", coords)
		(buttons["o_Coords"] as Button).text = "Feldnamen: %s" % ("an" if coords else "aus")
		_update_view())
	_overlay_button("Menu", "Hauptmenü", func() -> void:
		_resume()
		if mode == "kids":
			open_path()
		else:
			open_home())
	_overlay_button("Leave", "Zur Spielewelt", leave)
	_show_overlay("pause")


func _resume() -> void:
	_pending_warn = -1
	if is_instance_valid(lumo):
		lumo.set_suspended(false)
	close_overlay()


func go_back() -> void:
	var in_game := screen in ["lesson", "trial", "match"]
	if in_game and overlay_kind in ["pause", "rules", "warn"]:
		_resume()
	elif in_game and overlay_kind.is_empty():
		_on_pause()
	elif screen in ["path", "levels"]:
		open_home()
	else:
		leave()


func leave() -> void:
	if _closed:
		return
	_store()
	_sfx("ui_back")
	if HostBridge.is_embedded():
		_closed = HostBridge.return_to_app("games")
	else:
		SceneRouter.goto("games")


func _on_view() -> void:
	view = "3d" if view == "top" else "top"
	session.set_pref("view", view)
	_update_view()


# ====================================================================== Brett


func _show_position() -> void:
	chess.show_board(rules.board)
	board2d.show_board(rules.board)
	_refresh_glow()


func _child_moves() -> PackedInt32Array:
	if rules == null or busy or finished:
		return PackedInt32Array()
	match screen:
		"lesson":
			var step := _step()
			if str(step.get("type", "")) in ["move", "collect"]:
				return SCHOOL.allowed_moves(rules, step)
			return PackedInt32Array()
		"trial", "match":
			if rules.side != 0:
				return PackedInt32Array()
			return rules.legal_moves()
	return PackedInt32Array()


func _refresh_glow() -> void:
	var glow := {}
	if rules == null:
		chess.set_glow(glow)
		board2d.set_glow(glow)
		return
	var last: int = rules.last_move() if screen != "lesson" else -1
	if last >= 0:
		glow[RULES.move_from(last)] = "last"
		glow[RULES.move_to(last)] = "last"
	var moves := _child_moves()
	var show_moves := hints and mode != "pro"
	if selected >= 0:
		glow[selected] = "select"
		if show_moves or screen == "lesson":
			for m: int in moves:
				if RULES.move_from(m) == selected:
					var to := RULES.move_to(m)
					glow[to] = "capture" if rules.board[to] != 0 or (RULES.move_flags(m) & RULES.F_EP) else "move"
	elif screen == "trial" and show_moves:
		# Probespiel: Lumo zeigt, welche Figuren ziehen können.
		for m: int in moves:
			if not glow.has(RULES.move_from(m)):
				glow[RULES.move_from(m)] = "can"
	if screen == "lesson":
		var step := _step()
		for name: Variant in step.get("glow", []):
			glow[RULES.square_from_name(str(name))] = "show"
		if step.has("glow_moves"):
			var from := RULES.square_from_name(str(step.glow_moves))
			glow[from] = "select"
			for m: int in rules.legal_moves():
				if RULES.move_from(m) == from:
					glow[RULES.move_to(m)] = "move"
		if str(step.get("goal", "")) == "reach" and selected < 0:
			for t: int in SCHOOL.squares(step.get("targets", [])):
				if rules.board[t] == 0:
					glow[t] = "hint"
	if _danger_sq >= 0 and selected < 0 and not glow.has(_danger_sq):
		glow[_danger_sq] = "danger"
	if _pending_warn >= 0:
		glow[_pending_warn] = "danger"
	chess.set_glow(glow)
	board2d.set_glow(glow)


func square_at_point(point: Vector2) -> int:
	if view == "top" and board2d.visible:
		return board2d.square_at(point)
	var sq: int = chess.pick(camera, point)
	# In 3D sind die hinteren Felder perspektivisch flacher: Ein Tipp knapp
	# daneben zählt für das nächste sinnvolle Feld (erlaubtes Ziel bzw. eigene
	# Figur), wenn es höchstens 24 dp entfernt ist.
	var wanted := {}
	for m: int in _child_moves():
		wanted[RULES.move_to(m) if selected >= 0 and RULES.move_from(m) == selected else RULES.move_from(m)] = true
	if selected >= 0:
		wanted[selected] = true
	if wanted.is_empty() or wanted.has(sq):
		return sq
	var best := sq
	var best_d := 24.0 * _density
	for cand: int in wanted:
		var d: float = chess.screen_point(camera, cand).distance_to(point)
		if d < best_d:
			best_d = d
			best = cand
	return best


## Bildschirmpunkt eines Feldes in der aktuellen Ansicht (Tests, Hinweise).
func square_point(sq: int) -> Vector2:
	if view == "top" and board2d.visible:
		return board2d.screen_point(sq)
	return chess.screen_point(camera, sq)


func _unhandled_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		point = event.position
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _press_square >= 0:
		point = event.position
		moved = true
	else:
		return
	if screen not in ["lesson", "trial", "match"] or not overlay_kind.is_empty() or rules == null:
		return
	if pressed:
		_on_press(point)
	elif moved:
		_on_drag(point)
	elif released:
		_on_release(point)


func _on_press(point: Vector2) -> void:
	var sq := square_at_point(point)
	_press_square = -1
	_dragging = false
	if sq < 0 or busy or finished:
		return
	_press_point = point
	var step := _step() if screen == "lesson" else {}
	if screen == "lesson" and str(step.get("type", "")) == "tap":
		_lesson_tap(sq)
		return
	var moves := _child_moves()
	if selected >= 0 and _has_move(moves, selected, sq):
		_try_move(selected, sq)
		return
	var own := false
	for m: int in moves:
		if RULES.move_from(m) == sq:
			own = true
			break
	if own:
		selected = sq
		_press_square = sq
		chess.lift(sq)
		_sfx("ui_click")
		_refresh_glow()
	elif selected >= 0:
		selected = -1
		chess.drop_back()
		_refresh_glow()
		if screen == "lesson" and str(step.get("type", "")) == "move":
			_lesson_wrong()


func _on_drag(point: Vector2) -> void:
	if _press_square < 0:
		return
	if point.distance_to(_press_point) > 10.0 * _density:
		_dragging = true
	if not _dragging:
		return
	if view == "top" and board2d.visible:
		board2d.drag_square = _press_square
		board2d.drag_point = point
		board2d.queue_redraw()
	else:
		var hit: Vector3 = chess.ray_to_board(camera, point)
		if hit.is_finite():
			chess.drag_to(hit)


func _on_release(point: Vector2) -> void:
	var from := _press_square
	_press_square = -1
	board2d.drag_square = -1
	board2d.queue_redraw()
	if from < 0:
		return
	var sq := square_at_point(point)
	if _dragging and sq >= 0 and sq != from and _has_move(_child_moves(), from, sq):
		_dragging = false
		_try_move(from, sq)
		return
	_dragging = false
	# Kurzer Tipp: Figur bleibt ausgewählt (angehoben), das Zielfeld wird getippt.
	if sq != from:
		chess.drop_back()
		chess.lift(from)


func _has_move(moves: PackedInt32Array, from: int, to: int) -> bool:
	for m: int in moves:
		if RULES.move_from(m) == from and RULES.move_to(m) == to:
			return true
	return false


func _try_move(from: int, to: int) -> void:
	var options: Array[int] = []
	for m: int in _child_moves():
		if RULES.move_from(m) == from and RULES.move_to(m) == to:
			options.append(m)
	selected = -1
	if options.is_empty():
		chess.drop_back()
		_refresh_glow()
		return
	if options.size() > 1 and not (screen == "trial" and str(SCHOOL.trial(trial_id).goal) == "race") and screen != "lesson":
		_ask_promotion(options)
		return
	var choice := options[0]
	for m: int in options:
		if RULES.move_promo(m) == RULES.QUEEN:
			choice = m
	_child_move(choice)


func _ask_promotion(options: Array[int]) -> void:
	chess.drop_back()
	_clear_overlay()
	_overlay_label("Dein Bauer ist hinten! Was soll er werden?", 20, GOLD)
	for t: int in [RULES.QUEEN, RULES.ROOK, RULES.BISHOP, RULES.KNIGHT]:
		for m: int in options:
			if RULES.move_promo(m) == t:
				var move := m
				var b := _overlay_button("Promo%d" % t, COACH.piece_name(t), func() -> void:
					close_overlay()
					_child_move(move), "w_" + SET.NAMES[t], t == RULES.QUEEN)
				if t == RULES.QUEEN:
					b.add_theme_stylebox_override("normal", _style(Color("3d7a4a"), GOLD, 18, 4))
	_show_overlay("promo")


# ==================================================================== Lektionen


func _step() -> Dictionary:
	var info := SCHOOL.lesson(lesson_id)
	var steps: Array = info.get("steps", [])
	if step_index < 0 or step_index >= steps.size():
		return {}
	return steps[step_index]


func start_lesson(id: String) -> void:
	_generation += 1
	close_overlay()
	lesson_id = id
	trial_id = ""
	step_index = 0
	mistakes = 0
	collect_cap = 3
	finished = false
	mode = "kids"
	_set_screen("lesson")
	_enter_step()


func _enter_step() -> void:
	var step := _step()
	selected = -1
	busy = false
	collect_moves = 0 if str(step.get("type", "")) == "collect" else collect_moves
	rules = SCHOOL.make_rules(str(step.get("fen", SCHOOL.EMPTY)))
	stars_left = SCHOOL.squares(step.get("stars", []))
	var star_list: Array = []
	for sq: int in stars_left:
		star_list.append(sq)
	for t: int in SCHOOL.squares(step.get("targets", [])):
		if str(step.get("goal", "")) in ["reach", "promote"] and rules.board[t] == 0:
			star_list.append(t)
	var walls: Array = []
	for sq: int in SCHOOL.squares(step.get("walls", [])):
		walls.append(sq)
	chess.set_props(star_list, walls)
	board2d.set_props(star_list, walls)
	_show_position()
	var info := SCHOOL.lesson(lesson_id)
	say(str(step.get("say", "")), "%s · %d/%d" % [info.get("title", ""), step_index + 1, (info.get("steps", []) as Array).size()])
	var type := str(step.get("type", ""))
	buttons.Next.visible = type == "show"
	buttons.Show.visible = type in ["move", "tap", "collect"]
	buttons.Undo.visible = type == "collect"
	_layout()
	_lumo_look_board(SCHOOL.squares(step.get("glow", ["d4"]))[0] if not (step.get("glow", []) as Array).is_empty() else -1)
	if is_instance_valid(lumo):
		lumo.react("point" if type == "show" else "nod")
	if step.has("demo"):
		_play_demo(str(step.demo))


func _play_demo(uci: String) -> void:
	var gen := _generation
	busy = true
	await get_tree().create_timer(0.6 / time_scale).timeout
	if gen != _generation or _closed:
		return
	var m: int = rules.move_from_uci(uci)
	if m >= 0:
		rules.make_move(m)
		_sfx("piece_drop")
		chess.animate_move(m, rules.board, 0.9)
		board2d.show_board(rules.board)
		await chess.move_animated
	busy = false


func _on_next() -> void:
	if screen != "lesson" or busy:
		return
	_advance_step()


func _advance_step() -> void:
	var steps: Array = SCHOOL.lesson(lesson_id).get("steps", [])
	step_index += 1
	if step_index >= steps.size():
		_finish_lesson()
	else:
		_enter_step()


func _lesson_tap(sq: int) -> void:
	var step := _step()
	if SCHOOL.tap_ok(step, sq):
		_sfx("answer_correct")
		chess.set_glow({sq: "hint"})
		board2d.set_glow({sq: "hint"})
		say(COACH.praise(rng))
		if is_instance_valid(lumo):
			lumo.react("happy")
		_next_after(0.9)
	else:
		_lesson_wrong()


func _lesson_wrong() -> void:
	mistakes += 1
	_sfx("answer_wrong")
	say(["Fast! Probier es nochmal.", "Schau genau hin. Du schaffst das!", "Noch nicht ganz. Versuch es weiter!"][mistakes % 3])
	if is_instance_valid(lumo):
		lumo.react("think")
		lumo.calm.call_deferred()


func _next_after(seconds: float) -> void:
	var gen := _generation
	busy = true
	await get_tree().create_timer(seconds / time_scale).timeout
	if gen != _generation or _closed:
		return
	busy = false
	_advance_step()


func _lesson_move(m: int) -> void:
	var step := _step()
	var type := str(step.get("type", ""))
	if type == "collect":
		var from := RULES.move_from(m)
		var to := RULES.move_to(m)
		collect_moves += 1
		rules.make_move(m)
		_sfx("piece_drop")
		chess.animate_move(m, rules.board)
		board2d.show_board(rules.board)
		if stars_left.has(to):
			stars_left.erase(to)
			chess.remove_star(to)
			var rest: Array = []
			for sq: int in stars_left:
				rest.append(sq)
			board2d.set_props(rest, board2d.walls)
			_sfx("star_collected")
		# Das Kind ist wieder dran: Stellung mit der Figur auf dem neuen Feld.
		var base: RefCounted = SCHOOL.make_rules(str(step.fen))
		var start_sq := -1
		for sq in 64:
			if base.board[sq] != 0:
				start_sq = sq
				break
		rules = SCHOOL.make_rules(SCHOOL.fen_with_piece(base, start_sq, to))
		if stars_left.is_empty():
			var par := int(step.get("par", 3))
			say("Alle Sterne! Du hast %d Züge gebraucht." % collect_moves)
			if is_instance_valid(lumo):
				lumo.react("happy")
			_sfx("celebrate")
			collect_cap = mini(collect_cap, SCHOOL.collect_stars(collect_moves, par))
			_next_after(1.2)
		else:
			say("Super! Noch %d Stern%s." % [stars_left.size(), "" if stars_left.size() == 1 else "e"])
		_refresh_glow()
		return
	if SCHOOL.move_ok(step, rules, m):
		rules.make_move(m)
		_sfx("piece_drop")
		chess.animate_move(m, rules.board)
		board2d.show_board(rules.board)
		chess.set_props([], [])
		board2d.set_props([], [])
		_sfx("answer_correct")
		say(COACH.praise(rng))
		if is_instance_valid(lumo):
			lumo.react("happy")
		_refresh_glow()
		_next_after(1.1)
	else:
		chess.drop_back()
		_lesson_wrong()
		_refresh_glow()


func _on_show_me() -> void:
	if screen != "lesson" or busy:
		return
	var step := _step()
	var solution: Array = SCHOOL.solution(step)
	if solution.is_empty():
		return
	mistakes += 1
	match str(step.get("type", "")):
		"tap":
			chess.set_glow({int(solution[0]): "hint"})
			board2d.set_glow({int(solution[0]): "hint"})
			say("Zum Beispiel dieses Feld. Tipp drauf!")
		"move":
			var m := int(solution[0])
			var glow := {RULES.move_from(m): "select", RULES.move_to(m): "hint"}
			chess.set_glow(glow)
			board2d.set_glow(glow)
			say("Nimm die leuchtende Figur und zieh sie aufs grüne Feld.")
		"collect":
			var first: Array = solution[0]
			var glow := {int(first[0]): "select", int(first[1]): "hint"}
			chess.set_glow(glow)
			board2d.set_glow(glow)
			say("Fang hier an. Dann weiter zum nächsten Stern!")


func _finish_lesson() -> void:
	finished = true
	var stars := mini(SCHOOL.stars_for(mistakes), collect_cap)
	var best_before: int = session.lesson_stars(lesson_id)
	session.finish_lesson(lesson_id, stars)
	var gained := maxi(0, stars - best_before)
	var payload := {}
	if gained > 0:
		payload = _settle("lesson:" + lesson_id, gained, "done", "chess-lesson-%s-%s" % [lesson_id, HostBridge.new_result_id()])
	_sfx("celebrate")
	if is_instance_valid(lumo):
		lumo.react("happy")
	_end_overlay("Geschafft: %s" % SCHOOL.title("lesson", lesson_id), "★".repeat(stars) + "☆".repeat(3 - stars),
		"Neue Sterne: +%d" % gained if gained > 0 else "Toll geübt!", payload)


# ================================================================ Probespiel / Partie


func _slot() -> String:
	if screen == "trial" or not trial_id.is_empty():
		return "trial:" + trial_id
	return "pro" if mode == "pro" else "play"


func start_trial(id: String) -> void:
	_generation += 1
	close_overlay()
	trial_id = id
	lesson_id = ""
	mode = "kids"
	level = AI.LEVEL_KIDS
	finished = false
	mistakes = 0
	_set_screen("trial")
	var saved: Dictionary = session.resume_game(_slot())
	if not saved.is_empty():
		rules = saved.rules
		result_id = str(saved.meta.get("result_id", ""))
	else:
		rules = SCHOOL.make_trial(id)
		result_id = "chess-trial-%s-%s" % [id, HostBridge.new_result_id()]
	chess.set_props([], [])
	board2d.set_props([], [])
	_show_game_buttons()
	_show_position()
	var info := SCHOOL.trial(id)
	say(str(info.get("say", "")), "Probespiel: %s" % info.get("title", ""))
	if is_instance_valid(lumo):
		lumo.react("wave")
	_store()
	if rules.side == 1:
		_lumo_turn()


func start_match(chosen_level: int, resume: bool) -> void:
	_generation += 1
	close_overlay()
	trial_id = ""
	lesson_id = ""
	finished = false
	mistakes = 0
	_set_screen("match")
	var saved: Dictionary = session.resume_game(_slot()) if resume else {}
	if not saved.is_empty():
		rules = saved.rules
		level = clampi(int(saved.meta.get("level", 0)), 0, 3)
		result_id = str(saved.meta.get("result_id", ""))
	else:
		level = clampi(chosen_level, 0, 3)
		rules = RULES.new()
		result_id = "chess-%s-%d-%s" % [mode, level, HostBridge.new_result_id()]
	session.set_pref("level", level)
	session.set_pref("mode", mode)
	chess.set_props([], [])
	board2d.set_props([], [])
	_show_game_buttons()
	_show_position()
	say("Du spielst Weiß und fängst an. Viel Spaß!" if mode != "pro" else "Weiß beginnt. Volle Regeln, keine Hilfen.",
		"Lumo · %s" % AI.level_name(level))
	_store()
	if rules.side == 1:
		_lumo_turn()


func _show_game_buttons() -> void:
	var helpers := mode != "pro"
	buttons.Hint.visible = helpers
	buttons.Why.visible = helpers
	buttons.Undo.visible = helpers
	buttons.Next.visible = false
	buttons.Show.visible = false
	_layout()


func _end_game_state() -> void:
	busy = false
	thinking = false
	selected = -1
	_pending_warn = -1
	_danger_sq = -1
	if ai != null:
		ai.stopped = true
	rules = null


func _child_move(m: int) -> void:
	if screen == "lesson":
		_lesson_move(m)
		return
	# Freundliche Warnung vor einem Fehler (nicht für Große).
	if mode != "pro" and hints and _pending_warn < 0:
		var warn: Dictionary = COACH.warning(rules, m)
		if not warn.is_empty():
			_pending_warn = int(warn.square)
			mistakes += 1
			chess.drop_back()
			_refresh_glow()
			say(str(warn.text))
			if is_instance_valid(lumo):
				lumo.react("think")
			_clear_overlay()
			_overlay_label(str(warn.text), 20, GOLD)
			var move := m
			_overlay_button("Rethink", "Nochmal überlegen", func() -> void:
				_pending_warn = -1
				close_overlay()
				if is_instance_valid(lumo):
					lumo.calm()
				_refresh_glow())
			_overlay_button("Anyway", "Trotzdem ziehen", func() -> void:
				close_overlay()
				_commit_child_move(move))
			_show_overlay("warn")
			return
	_commit_child_move(m)


func _commit_child_move(m: int) -> void:
	_pending_warn = -1
	_danger_sq = -1
	var before: RefCounted = rules.duplicate_state()
	if not rules.play(m):
		chess.drop_back()
		_refresh_glow()
		return
	_sfx("piece_drop")
	chess.animate_move(m, rules.board)
	board2d.show_board(rules.board)
	last_explain = COACH.explain(before, m, false)
	if screen == "trial" or mode == "play":
		# Lob für Versuche: oft ein kurzes „Gut gemacht!“ vor der Erklärung.
		var praise := COACH.praise(rng) + " " if mistakes == 0 or rng.randf() < 0.5 else ""
		say(praise + last_explain, "Du")
	_refresh_glow()
	_store()
	if _check_end():
		return
	_lumo_turn()


func _lumo_turn() -> void:
	var gen := _generation
	busy = true
	thinking = true
	_refresh_glow()
	if is_instance_valid(lumo):
		lumo.react("think")
		_lumo_look_board()
	var started := Time.get_ticks_msec()
	ai.stopped = false
	var race := screen == "trial" and str(SCHOOL.trial(trial_id).get("goal", "")) == "race"
	var result: Dictionary = await ai.think(rules, level, {"race": race})
	if gen != _generation or _closed or rules == null:
		return
	# Kurz nachdenken lassen, auch wenn es schnell ging.
	var waited := (Time.get_ticks_msec() - started) / 1000.0
	var pause := (0.7 - waited) / time_scale
	if pause > 0.0 and not reduced_motion:
		await get_tree().create_timer(pause).timeout
		if gen != _generation or _closed or rules == null:
			return
	thinking = false
	var m := int(result.get("move", -1))
	if m < 0:
		busy = false
		_check_end()
		return
	var before: RefCounted = rules.duplicate_state()
	rules.play(m)
	if is_instance_valid(lumo):
		lumo.calm()
		_lumo_look_board(RULES.move_to(m))
		lumo.react("play")
	_sfx("piece_drop")
	chess.animate_move(m, rules.board, 0.75)
	board2d.show_board(rules.board)
	last_explain = COACH.explain(before, m, true)
	_danger_sq = -1
	var danger: Dictionary = {} if mode == "pro" or not hints else COACH.danger(rules)
	var tail := " Jetzt du!"
	if not danger.is_empty():
		_danger_sq = int(danger.square)
		tail = " " + str(danger.text)
	if mode == "pro":
		say("Ich ziehe %s." % before.to_san(m, true), "Lumo · %s" % AI.level_name(level))
	elif screen == "trial":
		say(last_explain + tail, "Lumo")
	else:
		say(last_explain + tail, "Lumo · %s" % AI.level_name(level))
	await chess.move_animated
	if gen != _generation or _closed:
		return
	busy = false
	_refresh_glow()
	_store()
	_check_end()


## Prüft das Spielende; gibt true zurück, wenn die Partie vorbei ist.
func _check_end() -> bool:
	if rules == null or finished:
		return finished
	var outcome := ""
	var status: String = rules.status()
	if screen == "trial":
		var winner := SCHOOL.trial_result(trial_id, rules)
		if winner.is_empty():
			return false
		outcome = "win" if winner == "white" else ("loss" if winner == "black" else "draw")
	else:
		if status == "playing":
			return false
		if status == "checkmate":
			outcome = "win" if rules.winner() == 0 else "loss"
		else:
			outcome = "draw"
	finished = true
	busy = false
	_finish_game(outcome, status)
	return true


func _finish_game(outcome: String, status: String) -> void:
	session.discard_game(_slot())
	var stars := 0
	var variant := ""
	if screen == "trial":
		variant = "trial:" + trial_id
		if outcome == "win":
			stars = 0 if session.trial_done(trial_id) else 2
			session.finish_trial(trial_id)
	else:
		variant = "%s:%s" % [mode, AI.level_id(level)]
		if outcome == "win":
			stars = LEVEL_STARS[level]
		elif outcome == "draw" and level >= 2:
			stars = 1
	var payload := {}
	if stars > 0:
		payload = _settle(variant, stars, outcome, result_id)
	else:
		session.book(result_id, variant, false)
	var title := "Gewonnen!" if outcome == "win" else ("Unentschieden" if outcome == "draw" else "Lumo hat gewonnen")
	var text := ""
	if screen == "trial":
		text = "Du hast das Ziel erreicht!" if outcome == "win" else (
			"Nochmal? Diesmal klappt es bestimmt!" if outcome == "loss" else "Keiner kam durch. Nochmal?")
	else:
		text = COACH.ending_text(status, outcome == "win")
	if is_instance_valid(lumo):
		lumo.react("happy" if outcome != "win" else "nod")
	_sfx("celebrate" if outcome == "win" else "turn_ping")
	say(text)
	_end_overlay(title, text, "+%d Stern%s" % [stars, "" if stars == 1 else "e"] if stars > 0 else "", payload)


## Bucht ein Ergebnis genau einmal und meldet es der App.
func _settle(variant: String, stars: int, outcome: String, id: String) -> Dictionary:
	if id.is_empty() or not session.book(id, variant.get_slice(":", 0), outcome in ["win", "done"]):
		return {}
	var payload := {
		"resultId": id,
		"game": "chess",
		"variant": variant,
		"sessionId": str(HostBridge.launch_options().get("sessionId", SceneRouter.launch_options.get("sessionId", ""))),
		"status": "completed",
		"outcome": outcome,
		"stars": stars,
		"xp": stars * 10,
		"level": level if variant.begins_with("play") or variant.begins_with("pro") else -1,
	}
	HostBridge.reward(payload)
	settled.emit(payload)
	return payload


func _end_overlay(title: String, line: String, reward: String, _payload: Dictionary) -> void:
	_clear_overlay()
	_overlay_label(title, 28, GOLD)
	_overlay_label(line, 20)
	if not reward.is_empty():
		_overlay_label(reward, 22, GOLD)
	if screen == "lesson":
		_overlay_button("Again", "Nochmal üben", func() -> void: start_lesson(lesson_id))
		_overlay_button("Continue", "Weiter lernen", open_path, "", true)
	elif screen == "trial":
		_overlay_button("Again", "Nochmal spielen", func() -> void: start_trial(trial_id))
		_overlay_button("Continue", "Weiter lernen", open_path, "", true)
	else:
		var lv := level
		_overlay_button("Again", "Neue Partie", func() -> void: start_match(lv, false), "", true)
		_overlay_button("Menu", "Hauptmenü", open_home)
	_show_overlay("end")


func _store() -> void:
	if rules == null or finished or screen not in ["trial", "match"]:
		return
	session.store_game(_slot(), rules, {"level": level, "result_id": result_id, "mode": mode})


# ================================================================= Lehrer-Knöpfe


func _on_hint() -> void:
	if screen not in ["trial", "match"] or busy or finished or rules == null or rules.side != 0:
		return
	var gen := _generation
	busy = true
	say("Moment, ich schaue mal …")
	var hint: Dictionary = await COACH.hint(rules, rng.randi() & 0xFFFF)
	if gen != _generation or _closed:
		return
	busy = false
	if hint.is_empty():
		return
	selected = int(hint.from)
	_refresh_glow()
	var glow: Dictionary = chess.glow_squares()
	glow[int(hint.to)] = "hint"
	chess.set_glow(glow)
	board2d.set_glow(glow)
	say(str(hint.text))


func _on_why() -> void:
	if last_explain.is_empty():
		say("Wir haben noch nicht gezogen. Fang einfach an!")
	else:
		say(last_explain)


func _on_undo() -> void:
	if busy or rules == null:
		return
	if screen == "lesson":
		_enter_step()
		return
	if screen not in ["trial", "match"] or finished:
		return
	# Zurück bis das Kind wieder dran ist (Lumos Antwort und den eigenen Zug).
	var taken := 0
	while rules.played.size() > 0 and taken < 2:
		rules.take_back()
		taken += 1
		if rules.side == 0:
			break
	if taken == 0:
		say("Wir sind schon am Anfang.")
		return
	selected = -1
	last_explain = ""
	_danger_sq = -1
	_show_position()
	_store()
	say("Zurückgenommen. Probier etwas anderes!")


# ===================================================================== Prüfhilfen


func is_idle() -> bool:
	return not busy and not thinking and not chess.is_animating()
