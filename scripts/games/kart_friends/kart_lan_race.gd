extends Node
## „Zusammen fahren“ im Kart: Knopf im Menü (nur mit Elternfreigabe friendsLan), Raum mit
## vierstelligem Code, gemeinsamer Start, das Kart des Freundes fährt sichtbar mit.
## Nur das eigene Kart wird gesteuert; das andere zeigt die übertragene Fahrt (geglättet).
## Bricht die Verbindung ab, fährt das Kind allein weiter.

const SESSION = preload("res://scripts/games/kart_friends/kart_lan_session.gd")
const CODEC = preload("res://scripts/games/kart_friends/kart_ghost_codec.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const RESULT_WIDGETS = preload("res://scripts/games/kart_result_widgets.gd")
const MODAL_STYLE = preload("res://scripts/games/kart_modal_style.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")

var island: Node
var session: Node
var player_name: String = "Freund"
## true, solange ein gemeinsames Rennen läuft oder sein Ergebnis gezeigt wird.
var active: bool = false
var version_checked: bool = false
var remote: Node3D
var entry: Button
var panel: PanelContainer
var status_label: Label
var code_label: Label
var typed: String = ""
var start_button: Button
var result_row: Control
var _start_pending: bool = false
var _entry_skin_scale := -1.0


func setup(owner_island: Node, name: String) -> void:
	island = owner_island
	player_name = name
	session = SESSION.new()
	session.name = "LanSession"
	add_child(session)
	session.status_changed.connect(_on_status)
	session.race_start.connect(_on_race_start)
	session.friend_finished.connect(func(_time: float): _refresh_result())
	session.friend_left.connect(_on_friend_left)
	entry = Button.new()
	entry.name = "KartLanEntry"
	entry.text = "Zusammen fahren"
	entry.set_anchors_preset(Control.PRESET_TOP_LEFT)
	entry.hide()
	entry.pressed.connect(open_lobby)
	island.safe_ui.add_child(entry)


func _process(_delta: float) -> void:
	if is_instance_valid(entry):
		var landing: Variant = island.get("reference_landing")
		var entry_rect := Rect2()
		if is_instance_valid(landing) and landing.has_method("set_friends_available"):
			landing.set_friends_available(true)
			entry_rect = landing.friends_entry_rect()
		entry.visible = (
			bool(island.menu_active)
			and not is_instance_valid(panel)
			and is_instance_valid(landing)
			and (landing as Control).visible
			and entry_rect.has_area()
		)
		if entry.visible:
			var parent_canvas := entry.get_parent() as CanvasItem
			var local_rect: Rect2 = parent_canvas.get_global_transform().affine_inverse() * entry_rect
			var scale := maxf(float(landing._layout_scale), 0.25)
			if not is_equal_approx(scale, _entry_skin_scale):
				MODAL_STYLE.dress_button(entry, scale)
				entry.add_theme_font_size_override("font_size", roundi(17.0 * scale))
				_entry_skin_scale = scale
			entry.position = local_rect.position
			entry.size = local_rect.size


func _info() -> Dictionary:
	var setup: Dictionary = island.garage.setup if is_instance_valid(island.garage) else {}
	return {
		"name": player_name,
		"driver": str(setup.get("driver", "fox")),
		"kart": str(setup.get("kart", "comet")),
		"track": str(setup.get("track", "sonnenhafen")),
		"track_version": ""
	}


## Raum-Fenster: Raum öffnen oder mit Code beitreten.
func open_lobby() -> void:
	if is_instance_valid(panel):
		panel.queue_free()
	panel = PanelContainer.new()
	panel.name = "KartLanLobby"
	panel.add_theme_stylebox_override("panel", MODAL_STYLE.panel(1.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(660, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	island.safe_ui.add_child(panel)
	_show_choice()


func _column() -> VBoxContainer:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	return column


func _show_choice() -> void:
	var column := _column()
	_text(column, "Zusammen fahren", 34, true)
	_text(
		column,
		"Beide Geräte im selben WLAN. Ein Gerät öffnet den Raum, das andere tippt den Code ein.",
		22
	)
	var row := _row(column)
	row.add_child(_button("Raum öffnen", _host, true))
	row.add_child(_button("Raum beitreten", _show_keypad, false))
	var close_row := _row(column)
	close_row.add_child(_button("Schließen", close_lobby, false))
	if session.state in ["lobby", "finished"] and not session.friend.is_empty():
		_show_room()


func _host() -> void:
	session.host(_info())
	_show_room()


## Gastgeber: großer Code, Warten auf den Freund, dann „Los!“. Gast: Warten auf den Start.
func _show_room() -> void:
	var column := _column()
	if session.is_host:
		_text(column, "Dein Raumcode", 26, true)
		code_label = _text(column, " ".join(session.room_code.split("")), 76, true)
		code_label.name = "KartLanCode"
	else:
		_text(column, "Raum %s" % session.room_code, 26, true)
	status_label = _text(column, "", 23)
	status_label.name = "KartLanStatus"
	var row := _row(column)
	if session.is_host:
		start_button = _button("Los!", func(): session.start_race(1.0), true)
		start_button.name = "KartLanStart"
		row.add_child(start_button)
	row.add_child(_button("Abbrechen", func(): _leave(), false))
	_on_status(session.state, _status_text())


func _status_text() -> String:
	match session.state:
		"hosting":
			return "Warte auf deinen Freund … Er tippt den Code in seinem Lumo ein."
		"joining", "joining_hello":
			return "Verbinde …"
		"lobby", "finished":
			if session.is_host:
				return "%s ist da! Tippe auf „Los!“." % session.friend.get("name", "Dein Freund")
			return (
				"Verbunden mit %s. Gleich geht's los!" % session.friend.get("name", "deinem Freund")
			)
	return ""


func _show_keypad() -> void:
	typed = ""
	var column := _column()
	_text(column, "Raumcode eingeben", 30, true)
	code_label = _text(column, "_ _ _ _", 70, true)
	code_label.name = "KartLanTyped"
	status_label = _text(column, "", 22)
	status_label.name = "KartLanStatus"
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "←", "0", "OK"]:
		var button := _button(key, _on_key.bind(key), key == "OK")
		button.name = "Key" + ("Back" if key == "←" else key)
		button.custom_minimum_size = Vector2(120, 78)
		grid.add_child(button)
	var row := _row(column)
	row.add_child(_button("Zurück", _show_choice, false))


func _on_key(key: String) -> void:
	if key == "←":
		typed = typed.substr(0, maxi(0, typed.length() - 1))
	elif key == "OK":
		if typed.length() == 4 and session.join(typed, _info()):
			_show_room()
			return
	elif typed.length() < 4:
		typed += key
	var shown: Array[String] = []
	for i in range(4):
		shown.append(typed[i] if i < typed.length() else "_")
	if is_instance_valid(code_label):
		code_label.text = " ".join(shown)


func _on_status(state: String, text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text if state == "closed" else _status_text()
	if is_instance_valid(start_button):
		start_button.disabled = state not in ["lobby", "finished"]


func _leave() -> void:
	session.close("")
	_show_choice()


func close_lobby() -> void:
	if session.state in ["hosting", "joining", "joining_hello"]:
		session.close("")
	if is_instance_valid(panel):
		panel.queue_free()


func _on_race_start(track: String, delay: float) -> void:
	if not is_instance_valid(island.garage):
		island._leave_race_for_menu()
	if is_instance_valid(panel):
		panel.queue_free()
	active = true
	_start_pending = true
	version_checked = false
	result_row = null
	var setup: Dictionary = island.garage.setup.duplicate(true)
	setup["mode"] = "time_trial"
	setup["track"] = track
	island._hide_reference_landing()
	island._start_selected_race(setup)
	# Beide Geräte zählen gleich herunter: keine Kamerafahrt vorab.
	island.preview_left = 0.0
	island.preview_total = 0.0
	island.countdown = 3.5 + delay
	var name: String = str(session.friend.get("name", "deinem Freund"))
	island.message.set_deferred("text", "Fahr mit %s um die Wette!" % name)
	print("[KartLan] gemeinsames Rennen auf %s" % track)


## Zeitfahren-Aufbau (über kart_friend_duel.build_ghost): das Kart des Freundes.
func build_remote(race_island: Node) -> LumoRaceKart:
	# Nur das Rennen, das der gemeinsame Start ausgelöst hat; „Noch einmal“ fährt allein.
	active = _start_pending
	_start_pending = false
	if not active:
		return null
	var info: Dictionary = session.friend
	var kart: LumoRaceKart = VEHICLE.new()
	var driver: String = str(info.get("driver", "fox"))
	kart.set_animated_lumo_enabled(driver == "fox")
	kart.configure(driver, Color("8fd3ff"), str(info.get("kart", "comet")))
	kart.name = "LanFriendKart"
	kart.reduced_motion = bool(race_island.reduced_motion)
	kart.set_graphics_quality("low")
	race_island.race_root.add_child(kart)
	var tag := Label3D.new()
	tag.name = "FriendNameTag"
	tag.text = str(info.get("name", "Freund"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0022
	tag.font_size = 44
	tag.outline_size = 14
	tag.modulate = Color("bfe9ff")
	tag.outline_modulate = Color(0.0, 0.08, 0.2, 0.9)
	tag.position = Vector3(0, 2.1, 0)
	kart.add_child(tag)
	kart.visible = false
	remote = kart
	var version: String = CODEC.track_version(
		race_island.world, str(race_island.track_id), float(race_island.track_length)
	)
	session.send_track_version(version)
	set_meta("own_version", version)
	return kart


## Jedes Rennbild: eigene Fahrt senden, Freund zeigen, Strecken-Version vergleichen.
func tick(race_island: Node, delta: float) -> void:
	if not active:
		return
	if race_island.racing:
		session.send_state(
			delta,
			float(race_island.elapsed),
			race_island.player.position,
			race_island.player.rotation,
			float(race_island.speed),
			float(race_island.steering)
		)
	if not version_checked and not session.friend_track_version.is_empty():
		version_checked = true
		if session.friend_track_version != str(get_meta("own_version", "")):
			race_island.message.text = (
				"Eure Strecken sind verschieden alt – bitte beide Lumo aktualisieren. "
				+ "Du fährst allein."
			)
			session.close("")
	if not is_instance_valid(remote):
		return
	var pose: Dictionary = session.friend_pose(float(race_island.elapsed))
	remote.visible = not pose.is_empty() and session.state in ["racing", "finished"]
	if remote.visible:
		remote.position = pose.p
		remote.rotation = pose.r
		remote.set_motion(float(pose.v), float(pose.st), false, false)


func on_finish(race_island: Node) -> void:
	if active:
		session.send_finish(float(race_island.elapsed))


func _on_friend_left(text: String) -> void:
	if active and is_instance_valid(island.message):
		island.message.text = text
	if is_instance_valid(remote):
		remote.visible = false
	_refresh_result()


## Ergebnistafel: Vergleich mit dem Freund (aktualisiert sich, wenn er später ankommt).
func add_result_rows(column: Control) -> void:
	if not active:
		return
	result_row = RESULT_WIDGETS.Row.new().setup("record", _result_text(), "", 0, Color("8fd3ff"))
	result_row.name = "LanResult"
	column.add_child(result_row)


func _result_text() -> String:
	var name: String = str(session.friend.get("name", "Dein Freund"))
	if session.friend_time > 0.0:
		var duel: Script = load("res://scripts/games/kart_friends/kart_friend_duel.gd")
		return duel.compare_text(float(island.elapsed), session.friend_time, name)
	if session.state == "closed":
		return "Die Verbindung ist unterbrochen – deine Zeit zählt trotzdem."
	return "%s ist noch unterwegs …" % name


func _refresh_result() -> void:
	if is_instance_valid(result_row):
		result_row.label.text = _result_text()


## Nach dem Ergebnis: zurück ins Menü; der Raum bleibt für eine Revanche offen.
func leave_race() -> void:
	active = false
	remote = null


func _text(parent: Control, text: String, size: int, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f4fbff"))
	if heading:
		label.add_theme_font_override("font", UI.HEADING)
	parent.add_child(label)
	return label


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	return row


func _button(caption: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(240, 76)
	button.add_theme_font_size_override("font_size", 25)
	MODAL_STYLE.dress_button(button, 1.0)
	if primary:
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(
				state, MODAL_STYLE.button_skin(MODAL_STYLE.GOLD, 1.0, state, true)
			)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color("2a1600"))
	button.pressed.connect(callback)
	return button
