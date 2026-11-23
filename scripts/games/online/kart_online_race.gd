extends Node
## Live Internet race adapter. The existing local/WLAN/ghost modes stay independent.
## Online uses the normal kart physics and two laps; the other kart is a real
## interpolated opponent, with no invented AI replacement after a disconnect.

const SESSION = preload("res://scripts/games/online/kart_online_session.gd")
const CODEC = preload("res://scripts/games/kart_friends/kart_ghost_codec.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const RESULT_WIDGETS = preload("res://scripts/games/kart_result_widgets.gd")
const MODAL_STYLE = preload("res://scripts/games/kart_modal_style.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")

var island: Node
var session: Node
var active: bool = false
var remote: Node3D
var entry: Button
var overlay: Control
var panel: PanelContainer
var column: VBoxContainer
var status_label: Label
var alias_edit: LineEdit
var target_edit: LineEdit
var result_row: Control
var pending_invites: Array[Dictionary] = []
var _start_pending: bool = false
var _race_result_id: String = ""
var _configured: bool = false
var _refresh_queued: bool = false
var _ready_ids: Array = []


func setup(owner_island: Node, url: String) -> void:
	island = owner_island
	session = SESSION.new()
	session.name = "KartOnlineSession"
	add_child(session)
	session.status_changed.connect(_on_status)
	session.invitation_received.connect(_on_invitation)
	session.invitation_expired.connect(_on_invitation_expired)
	session.room_joined.connect(func(_room: Dictionary): pending_invites.clear(); _queue_refresh())
	session.ready_changed.connect(func(ids: Array): _ready_ids = ids; _queue_refresh())
	session.race_prepare.connect(_on_prepare)
	session.race_start.connect(_on_start)
	session.friend_finished.connect(func(_time: float): _refresh_result())
	session.result_received.connect(func(_result: Dictionary): _refresh_result())
	session.friend_left.connect(_on_friend_left)
	_configured = session.configure(url)
	entry = Button.new()
	entry.name = "KartOnlineEntry"
	entry.text = "Online-Rennen"
	entry.custom_minimum_size = Vector2(280, 64)
	entry.add_theme_font_size_override("font_size", 24)
	MODAL_STYLE.dress_button(entry, 1.0)
	entry.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	entry.offset_left = -800.0
	entry.offset_right = -520.0
	entry.offset_top = 18.0
	entry.offset_bottom = 82.0
	entry.pressed.connect(open_lobby)
	island.safe_ui.add_child(entry)


func _process(_delta: float) -> void:
	if not is_instance_valid(island):
		return
	if is_instance_valid(entry):
		var landing: Variant = island.get("reference_landing")
		entry.visible = bool(island.menu_active) and not is_instance_valid(overlay) and is_instance_valid(landing) and bool(landing.visible)
		entry.text = "Einladung (%d)" % pending_invites.size() if not pending_invites.is_empty() else "Online-Rennen"
	if active and bool(island.menu_active):
		leave_race()
	if active and not bool(island.menu_active):
		# Pausing the local controls cannot pause the shared race clock.
		if session.start_server_ms > 0 and not str(session.room_id).is_empty() and bool(island.racing) and not bool(island.finished):
			island.elapsed = session.race_seconds()
		if bool(island.finished) or bool(island.paused):
			_update_remote()


func _info() -> Dictionary:
	var selection: Dictionary = island.garage.setup if is_instance_valid(island.garage) else island.setup_snapshot
	var kart: String = str(selection.get("kart", "comet"))
	var look: Dictionary = {}
	var full_look: Dictionary = island._ensure_workshop().look(kart)
	var pattern := RegEx.create_from_string("^[a-z0-9_]{1,40}$")
	for key in full_look:
		var value: Variant = full_look[key]
		if value is String and pattern.search(str(key)) != null and pattern.search(value) != null:
			look[str(key)] = value
	return {"driver": str(selection.get("driver", "fox")), "kart": kart, "look": look}


func _stop_lan() -> void:
	var lan: Variant = island.friend_duel.lan
	if is_instance_valid(lan):
		lan.close_lobby()
		lan.session.close("")
		lan.active = false


func _selected_track() -> String:
	if is_instance_valid(island.garage):
		return str(island.garage.setup.get("track", "sonnenhafen"))
	return str(island.setup_snapshot.get("track", "sonnenhafen"))


func open_lobby() -> void:
	if is_instance_valid(overlay):
		return
	_stop_lan()
	overlay = Control.new()
	overlay.name = "KartOnlineLobby"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	island.safe_ui.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.005, 0.015, 0.045, 0.9)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MODAL_STYLE.panel(1.0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 28
	panel.offset_bottom = -28
	overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	_refresh_lobby()


func close_lobby() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	panel = null
	column = null


func _queue_refresh() -> void:
	if _refresh_queued or not is_instance_valid(column):
		return
	_refresh_queued = true
	_refresh_lobby.call_deferred()


func _refresh_lobby() -> void:
	_refresh_queued = false
	if not is_instance_valid(column):
		return
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	_text("Online-Rennen", 34, true)
	_text("Fahre live mit einem Freund: Name eingeben, Einladung annehmen, beide bereit – los!", 22)
	_text("Dein Spielername: " + str(session.username), 24, true)
	status_label = _text(str(session.status_text), 23)
	status_label.name = "KartOnlineStatus"
	if not _configured:
		_text("Der Server wird in den Eltern-Einstellungen eingerichtet.", 22)
	elif session.state in ["offline", "closed"]:
		alias_edit = LineEdit.new()
		alias_edit.name = "KartOnlineAlias"
		alias_edit.text = session.alias
		alias_edit.placeholder_text = "Dein Fantasiename"
		alias_edit.max_length = 16
		alias_edit.custom_minimum_size = Vector2(0, 68)
		alias_edit.add_theme_font_size_override("font_size", 26)
		column.add_child(alias_edit)
		_text("3–16 Buchstaben, Ziffern oder Unterstriche. Die Kennung nach # bleibt auf diesem Gerät gleich.", 20)
		_button("Verbinden", _connect)
	elif session.state == "connecting":
		_button("Verbindung abbrechen", func(): session.disconnect_online())
	elif session.state == "lobby":
		_text("Strecke: " + _track_name(str(session.track)), 26, true)
		_text("Mit " + str(session.friend.get("handle", "")), 23)
		_text("Online sind zwei echte Fahrer unterwegs. Eure eigenen Bauteile wirken wie im Einzelrennen.", 21)
		var ready_button := _button("Ich bin bereit", func(): session.ready_for_race())
		ready_button.name = "KartOnlineReady"
		ready_button.disabled = session.my_id in _ready_ids
		if ready_button.disabled:
			ready_button.text = "Bereit – warte auf deinen Freund"
		_button("Raum verlassen", func(): session.leave_room())
	elif not pending_invites.is_empty() and session.state in ["online", "inviting"]:
		var invitation: Dictionary = pending_invites[0]
		_text(str(invitation.get("from", "")) + " lädt dich ein.", 26, true)
		_text("Strecke: " + _track_name(str(invitation.get("track", ""))), 24)
		var invite_id: String = str(invitation.get("invite", ""))
		var accept_button := _button("Einladung annehmen", func(): session.accept(invite_id, _info()))
		accept_button.name = "KartOnlineAccept"
		_button("Jetzt nicht", func(): session.decline(invite_id); _on_invitation_expired(invite_id))
	else:
		_text("Gewählte Strecke: " + _track_name(_selected_track()), 25, true)
		target_edit = LineEdit.new()
		target_edit.name = "KartOnlineFriendName"
		target_edit.placeholder_text = "Name#Kennung deines Freundes"
		target_edit.max_length = 33
		target_edit.custom_minimum_size = Vector2(0, 68)
		target_edit.add_theme_font_size_override("font_size", 25)
		column.add_child(target_edit)
		var invite_button := _button("Zum Rennen einladen", _invite_typed)
		invite_button.name = "KartOnlineInvite"
		if not session.friends.is_empty():
			_text("Deine verknüpften Freunde", 24, true)
			for handle in session.friends:
				var friend_handle: String = str(handle)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 12)
				column.add_child(row)
				var invite_friend := _make_button(friend_handle, func(): session.invite(friend_handle, _selected_track(), _info()))
				invite_friend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(invite_friend)
				var remove_friend := _make_button("Entfernen", func(): session.forget_friend(friend_handle); _queue_refresh())
				row.add_child(remove_friend)
		_text("Beide bleiben hier online. Nur wer deinen vollständigen Namen kennt, kann dich einladen. Kein Chat.", 20)
		_button("Verbindung trennen", func(): session.disconnect_online())
	_button("Zurück zu Lumo Kart", close_lobby)


func _connect() -> void:
	if not is_instance_valid(alias_edit):
		return
	if not session.set_alias(alias_edit.text.strip_edges()):
		status_label.text = "Dieser Name passt nicht oder konnte nicht gespeichert werden."
		return
	session.connect_online()


func _invite_typed() -> void:
	if is_instance_valid(target_edit):
		session.invite(target_edit.text.strip_edges(), _selected_track(), _info())


func _on_status(_state: String, text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text
	_queue_refresh()


func _on_invitation(invitation: Dictionary) -> void:
	if pending_invites.size() < 8:
		pending_invites.append(invitation.duplicate(true))
	_queue_refresh()


func _on_invitation_expired(invite_id: String) -> void:
	for i in range(pending_invites.size() - 1, -1, -1):
		if str(pending_invites[i].get("invite", "")) == invite_id:
			pending_invites.remove_at(i)
	_queue_refresh()


func _on_prepare(selected_track: String) -> void:
	_stop_lan()
	if not is_instance_valid(island.garage):
		session.leave_room()
		return
	if not _known(CATALOG.TRACKS, selected_track):
		session.leave_room()
		return
	close_lobby()
	active = true
	_start_pending = true
	result_row = null
	var selection: Dictionary = island.garage.setup.duplicate(true)
	selection["mode"] = "time_trial"
	selection["track"] = selected_track
	# Same assist setting on both clients; their selected parts remain their own.
	selection["difficulty"] = "flott"
	island._hide_reference_landing()
	island._start_selected_race(selection)
	island.preview_left = 0.0
	island.preview_total = 0.0
	island.countdown = 3600.0
	island.racing = false
	island.message.text = "Warte, bis beide Karts an der Startlinie stehen …"
	var version: String = CODEC.track_version(island.world, str(island.track_id), float(island.track_length))
	session.course_loaded(version, float(island.track_length), int(island.TOTAL_LAPS))


func _on_start(_start_ms: int) -> void:
	if not active or not is_instance_valid(island.player):
		return
	var delay: float = (float(session.start_server_ms) - float(session.server_time_ms())) / 1000.0
	island.preview_left = 0.0
	island.preview_total = 0.0
	island.countdown = maxf(0.05, delay)
	island.elapsed = session.race_seconds()
	island.message.text = "Gemeinsamer Start gegen " + _friend_alias() + "!"


func build_remote(race_island: Node) -> LumoRaceKart:
	var current_result: String = str(race_island.result_id)
	if not _start_pending and (not active or current_result != _race_result_id):
		if active:
			leave_race()
		return null
	_start_pending = false
	active = true
	_race_result_id = current_result
	var info: Dictionary = session.friend
	var driver: String = str(info.get("driver", "fox"))
	var kart_id: String = str(info.get("kart", "comet"))
	if not _known(CATALOG.DRIVERS, driver):
		driver = "fox"
	if not _known(CATALOG.KARTS, kart_id):
		kart_id = "comet"
	var kart: LumoRaceKart = VEHICLE.new()
	if info.get("look") is Dictionary:
		kart.set_look(info.look)
	kart.set_animated_lumo_enabled(driver == "fox")
	kart.configure(driver, Color("8fd3ff"), kart_id)
	kart.name = "OnlineFriendKart"
	kart.reduced_motion = bool(race_island.reduced_motion)
	kart.set_graphics_quality("low")
	race_island.race_root.add_child(kart)
	var tag := Label3D.new()
	tag.name = "OnlineFriendName"
	tag.text = _friend_alias()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = 0.0022
	tag.font_size = 36
	tag.outline_size = 12
	tag.modulate = Color("c4f3ff")
	tag.position = Vector3(0, 2.2, 0)
	kart.add_child(tag)
	kart.visible = false
	remote = kart
	return kart


func tick(race_island: Node, delta: float) -> void:
	if not active:
		return
	if bool(race_island.racing) and not bool(race_island.paused):
		_send_pose(race_island, delta, false)
	_update_remote()


func _send_pose(race_island: Node, delta: float, force: bool) -> void:
	session.send_state(delta, race_island.player.position,
		race_island.player.basis.get_rotation_quaternion(), float(race_island.speed),
		float(race_island.steering), float(race_island.distance),
		int(race_island.checkpoint_index), force)


func _update_remote() -> void:
	if not is_instance_valid(remote):
		return
	var pose: Dictionary = session.friend_pose()
	remote.visible = not pose.is_empty() and not str(session.room_id).is_empty()
	if remote.visible:
		remote.position = pose.p
		remote.basis = Basis(pose.q)
		remote.set_motion(float(pose.v), float(pose.st), false, false)


func on_finish(race_island: Node) -> void:
	if active:
		_send_pose(race_island, 1.0, true)
		session.send_finish()


func add_result_rows(column_control: Control) -> void:
	if not active:
		return
	result_row = RESULT_WIDGETS.Row.new().setup("record", _result_text(), "", 0, Color("8fd3ff"))
	result_row.name = "OnlineRaceResult"
	column_control.add_child(result_row)


func _result_text() -> String:
	if str(session.room_id).is_empty():
		return "Online-Verbindung beendet. Deine lokale Fahrt bleibt erhalten."
	if float(session.friend_time) > 0.0 and float(session.own_time) > 0.0:
		var difference: float = float(session.friend_time) - float(session.own_time)
		if absf(difference) < 0.05:
			return "Online-Gleichstand mit %s! %.2f s / %.2f s" % [_friend_alias(), session.own_time, session.friend_time]
		var winner: String = "Du gewinnst" if difference > 0.0 else _friend_alias() + " gewinnt"
		return "%s! Online-Zeit %.2f s · %s %.2f s" % [winner, session.own_time, _friend_alias(), session.friend_time]
	if float(session.own_time) < 0.0:
		return "Dein Online-Ziel wird bestätigt …"
	return "%s fährt noch. Deine Online-Zeit: %.2f s" % [_friend_alias(), session.own_time]


func _refresh_result() -> void:
	if is_instance_valid(result_row):
		result_row.label.text = _result_text()


func _on_friend_left(text: String) -> void:
	if active and is_instance_valid(island.message):
		island.message.text = text
		if float(island.countdown) > 10.0:
			island.countdown = 3.5
	if is_instance_valid(remote):
		remote.visible = false
	_refresh_result()


func leave_race() -> void:
	active = false
	_start_pending = false
	remote = null
	_ready_ids.clear()
	if not str(session.room_id).is_empty():
		session.leave_room()


func _friend_alias() -> String:
	return str(session.friend.get("handle", "Freund")).get_slice("#", 0)


static func _known(items: Array, id: String) -> bool:
	for item in items:
		if str(item.id) == id:
			return true
	return false


static func _track_name(id: String) -> String:
	for item in CATALOG.TRACKS:
		if str(item.id) == id:
			return str(item.name)
	return id


func _text(value: String, size: int, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f4fbff"))
	if heading:
		label.add_theme_font_override("font", UI.HEADING)
	column.add_child(label)
	return label


func _make_button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(180, 72)
	button.add_theme_font_size_override("font_size", 23)
	MODAL_STYLE.dress_button(button, 1.0)
	button.pressed.connect(callback)
	return button


func _button(caption: String, callback: Callable) -> Button:
	var button := _make_button(caption, callback)
	column.add_child(button)
	return button


func _exit_tree() -> void:
	if is_instance_valid(session):
		session.disconnect_online("")
