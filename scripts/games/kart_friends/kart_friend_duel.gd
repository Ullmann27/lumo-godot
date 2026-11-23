extends RefCounted
## Geister-Duell mit Freunden: Ein Freund schickt seine beste Fahrt als „Lumo-Geist“;
## Lumo fährt gegen diesen Geist (Name + Kart des Freundes) und kann den eigenen Geist
## zurückschicken. Kein Chat, kein Konto, kein Server – nur eine kleine, geprüfte Datei.
##
## Andockstellen in kart_island.gd (örtlich begrenzt):
##   _ready → attach(); Zeitfahren-Aufbau → build_ghost(); Ergebnis → add_result_rows().
## Der Freundes-Geist verändert nie die eigenen Bestzeiten: er ersetzt nur die
## Abspiel-Liste dieses einen Rennens; gespeichert wird weiterhin nur die eigene Fahrt.

const CODEC = preload("res://scripts/games/kart_friends/kart_ghost_codec.gd")
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const RESULT_WIDGETS = preload("res://scripts/games/kart_result_widgets.gd")
const MODAL_STYLE = preload("res://scripts/games/kart_modal_style.gd")
const UI = preload("res://scripts/games/kart_ui_theme.gd")
const EXPORT_DIR: String = "user://kart_geister"
const LAN_RACE = preload("res://scripts/games/kart_friends/kart_lan_race.gd")
const ONLINE_RACE = preload("res://scripts/games/online/kart_online_race.gd")
const FRIEND_TINT := Color(1.0, 0.8, 0.36, 0.42)

## Geladener Freundes-Geist ({} wenn keiner) und Grund, falls die Datei abgelehnt wurde.
var friend: Dictionary = {}
var rejected: String = ""
var player_name: String = "Freund"
## Ergebnis des laufenden Duells: "" (kein Duell), "racing", "old_track".
var race_state: String = ""
var last_share_note: String = ""
var invitation: Control
## „Zusammen fahren“ im WLAN – nur mit Elternfreigabe (Startoption friendsLan).
var lan: Node
## Separate parent permission for Internet racing, never inherited from local WLAN consent.
var online: Node
## Elternfreigabe „Geister-Duell erlauben“ (Startoption friendsGhostShare, Vorgabe aus):
## ohne sie kein Freundes-Geist, kein Teilen-Knopf und keine Geist-Datei zum Verschicken.
var share_allowed: bool = false


## Liest Startoptionen (App: kartFriendGhost = Textform, playerName = Vorname).
func load_options(options: Dictionary) -> void:
	# Leerer Vorname (keine Freigabe) → Anzeigename „Freund“, nie ein Fehler.
	player_name = CODEC.clean_name(str(options.get("playerName", "")))
	share_allowed = options.get("friendsGhostShare", false) == true
	friend = {}
	rejected = ""
	var raw: String = str(options.get("kartFriendGhost", ""))
	if raw.is_empty() or not share_allowed:
		return
	var result: Dictionary = CODEC.decode(CODEC.bytes_from_text(raw))
	if not bool(result.ok):
		rejected = str(result.message)
		push_warning("[KartFriends] Geist abgelehnt: " + str(result.error))
		return
	if not _is_track(str(result.meta.track)):
		rejected = CODEC.message("unknown_track")
		push_warning("[KartFriends] Geist abgelehnt: unknown_track")
		return
	friend = result
	print(
		(
			"[KartFriends] Geist von %s geladen: %s, %.2f s, %d Bilder"
			% [
				friend_name(),
				result.meta.track,
				float(result.meta.time),
				int(result.meta.frame_count)
			]
		)
	)


func attach(island: Node) -> void:
	var options: Dictionary = SceneRouter.launch_options.duplicate(true)
	options.merge(HostBridge.launch_options(), true)
	load_options(options)
	if options.get("friendsLan", false) == true and lan == null:
		lan = LAN_RACE.new()
		lan.name = "KartLanRace"
		island.add_child(lan)
		lan.setup(island, player_name)
	if options.get("friendsOnline", false) == true and online == null:
		online = ONLINE_RACE.new()
		online.name = "KartOnlineRace"
		island.add_child(online)
		online.setup(island, str(options.get("kartOnlineEndpoint", "")), str(options.get("childKey", "standalone")))
	# Die App hat die Einladung schon gezeigt und das Kind hat „Gegen Mia fahren“ getippt.
	if has_friend() and options.get("kartFriendStart", false) == true:
		(func(): _start_duel(island)).call_deferred()
	elif not friend.is_empty() or not rejected.is_empty():
		show_invitation(island)


func has_friend() -> bool:
	return not friend.is_empty()


func friend_name() -> String:
	return str(friend.get("meta", {}).get("name", "Freund"))


func friend_track() -> String:
	return str(friend.get("meta", {}).get("track", ""))


func friend_time() -> float:
	return float(friend.get("meta", {}).get("time", 0.0))


## Einladung über dem Kart-Menü: „Mia fordert dich heraus!“ bzw. freundliche Ablehnung.
func show_invitation(island: Node) -> void:
	if not is_instance_valid(island.safe_ui):
		return
	if is_instance_valid(invitation):
		invitation.queue_free()
	var panel := PanelContainer.new()
	panel.name = "KartFriendInvitation"
	panel.add_theme_stylebox_override("panel", MODAL_STYLE.panel(1.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title := _text(column, "", 34, UI.HEADING)
	var detail := _text(column, "", 24)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	column.add_child(buttons)
	if has_friend():
		title.text = "%s fordert dich heraus!" % friend_name()
		detail.text = (
			"Strecke %s · Zeit %s\n%s fährt als goldener Geist mit. Schaffst du es schneller?"
			% [_track_name(friend_track()), format_time(friend_time()), friend_name()]
		)
		buttons.add_child(
			_button("Gegen %s fahren" % friend_name(), func(): _start_duel(island), true)
		)
		buttons.add_child(_button("Später", func(): panel.queue_free(), false))
	else:
		title.text = "Dieser Geist passt nicht"
		detail.text = rejected
		buttons.add_child(_button("Verstanden", func(): panel.queue_free(), true))
	island.safe_ui.add_child(panel)
	invitation = panel


func _start_duel(island: Node) -> void:
	if is_instance_valid(invitation):
		invitation.queue_free()
	if not has_friend() or not is_instance_valid(island.garage):
		return
	var setup: Dictionary = island.garage.setup.duplicate(true)
	setup["mode"] = "time_trial"
	setup["track"] = friend_track()
	island._hide_reference_landing()
	island._start_selected_race(setup)


## Zeitfahren-Aufbau: Passt der Freundes-Geist zu dieser Strecke, wird er der Geist
## dieses Rennens. Rückgabe: der Geist (LumoRaceKart) oder null (dann gilt der eigene).
func build_ghost(island: Node) -> LumoRaceKart:
	race_state = ""
	if online != null:
		var online_remote: LumoRaceKart = online.build_remote(island)
		if online_remote != null:
			return online_remote
	if lan != null:
		var remote: LumoRaceKart = lan.build_remote(island)
		if remote != null:
			return remote
	if not has_friend() or str(island.track_id) != friend_track():
		return null
	var here: String = CODEC.track_version(
		island.world, str(island.track_id), float(island.track_length)
	)
	if here != str(friend.meta.track_version):
		race_state = "old_track"
		_say_later(island, "Dieser Geist kennt die neue Strecke noch nicht – du fährst allein.")
		print(
			(
				"[KartFriends] Strecken-Version passt nicht: %s != %s"
				% [here, friend.meta.track_version]
			)
		)
		return null
	island.records.replay = friend.frames.duplicate()
	island.records.replay_index = 0
	race_state = "racing"
	var driver: String = str(friend.meta.driver)
	if not _known(CATALOG.DRIVERS, driver):
		driver = "fox"
	var kart: String = str(friend.meta.kart)
	if not _known(CATALOG.KARTS, kart):
		kart = "comet"
	var ghost: LumoRaceKart = VEHICLE.new()
	ghost.set_animated_lumo_enabled(driver == "fox")
	ghost.configure(driver, Color("ffd36b"), kart)
	ghost.name = "FriendGhost"
	ghost.reduced_motion = bool(island.reduced_motion)
	ghost.set_graphics_quality("low")
	island.race_root.add_child(ghost)
	_tint(ghost)
	var tag := Label3D.new()
	tag.name = "FriendNameTag"
	tag.text = friend_name()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0022
	tag.font_size = 44
	tag.outline_size = 14
	tag.modulate = Color("ffe08a")
	tag.outline_modulate = Color(0.12, 0.06, 0.0, 0.9)
	tag.position = Vector3(0, 2.1, 0)
	ghost.add_child(tag)
	_say_later(island, "Fahr gegen den Geist von %s!" % friend_name())
	print("[KartFriends] Duell gegen %s auf %s" % [friend_name(), friend_track()])
	return ghost


## Die Rennvorbereitung schreibt die Steuerhilfe erst nach dem Aufbau; danach melden.
func _say_later(island: Node, text: String) -> void:
	var label: Label = island.message
	if is_instance_valid(label):
		label.set_deferred("text", text)


func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = FRIEND_TINT
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint(child)


## Jedes Rennbild im Zeitfahren (nach dem eigenen Geist): WLAN-Freund bewegen.
func tick(island: Node, delta: float) -> void:
	if online != null:
		online.tick(island, delta)
	if lan != null:
		lan.tick(island, delta)


## Ziellinie im Zeitfahren: Zeit an den WLAN-Freund melden.
func on_finish(island: Node) -> void:
	if online != null:
		online.on_finish(island)
	if lan != null:
		lan.on_finish(island)


## Satz für die Ergebnistafel, z. B. „Du warst 1,2 s schneller als Mia!“.
static func compare_text(own: float, other: float, name: String) -> String:
	var diff: float = other - own
	if absf(diff) < 0.05:
		return "Gleichstand mit %s – genau gleich schnell!" % name
	var seconds: String = ("%.1f" % absf(diff)).replace(".", ",")
	if diff > 0.0:
		return "Du warst %s s schneller als %s!" % [seconds, name]
	return "%s war %s s schneller. Noch ein Versuch?" % [name, seconds]


static func format_time(seconds: float) -> String:
	var minutes: int = int(seconds) / 60
	var rest: float = seconds - minutes * 60
	return ("%d:%04.1f" % [minutes, rest]).replace(".", ",")


## Ergebnis Zeitfahren: Duell-Satz und der Knopf zum Verschicken des eigenen Geists.
func add_result_rows(island: Node, column: Control) -> void:
	if online != null:
		online.add_result_rows(column)
	if lan != null:
		lan.add_result_rows(column)
	if race_state == "racing":
		var row := RESULT_WIDGETS.Row.new().setup(
			"record",
			compare_text(float(island.elapsed), friend_time(), friend_name()),
			"",
			0,
			Color("ffc23d")
		)
		row.name = "FriendDuelResult"
		column.add_child(row)
	elif race_state == "old_track":
		var old := RESULT_WIDGETS.Row.new().setup("notice", CODEC.message("old_track"))
		old.name = "FriendDuelOldTrack"
		column.add_child(old)
	# Nur mit Elternfreigabe; im App-Rahmen zusätzlich nur, wenn er das Teilen-Menü anbietet
	# (sonst landete die Datei unerreichbar im Spielordner: ein Knopf ohne Wirkung für das Kind).
	# Ohne Rahmen (Desktop/Test): Datei.
	if not share_allowed or (HostBridge.is_embedded() and not HostBridge.can_share_file()):
		return
	var caption: String = (
		"Meinen Geist an %s zurückschicken" % friend_name()
		if race_state == "racing"
		else "Geist an einen Freund schicken"
	)
	var share := RESULT_WIDGETS.Action.new().setup(
		caption, func(): share_best(island), "secondary", "next"
	)
	share.name = "FriendGhostShare"
	share.mouse_filter = Control.MOUSE_FILTER_PASS
	var share_row := BoxContainer.new()
	share_row.name = "FriendGhostShareRow"
	share_row.add_child(share)
	column.add_child(share_row)
	if not last_share_note.is_empty():
		var note := RESULT_WIDGETS.Row.new().setup("notice", last_share_note)
		note.name = "FriendGhostShareNote"
		column.add_child(note)


## Baut die Datei aus der gespeicherten Bestfahrt dieser Strecke/dieses Karts.
func export_best(island: Node) -> Dictionary:
	var records = island.records
	var frames: Variant = records.config.get_value("ghosts", records.record_key, [])
	var time: float = float(records.config.get_value("times", records.record_key, 0.0))
	if not frames is Array or (frames as Array).size() < 2 or time <= 0.0:
		return {"ok": false, "error": "no_ride", "message": CODEC.message("no_ride")}
	var result: Dictionary = (
		CODEC
		. encode(
			frames,
			{
				"track": str(island.track_id),
				"track_version":
				CODEC.track_version(island.world, str(island.track_id), float(island.track_length)),
				"driver": str(island.selected_driver),
				"kart": str(island.selected_kart),
				"difficulty": str(island.difficulty),
				"name": player_name,
				"time": time,
			}
		)
	)
	if not bool(result.ok):
		result["message"] = CODEC.message(str(result.error))
	return result


func share_best(island: Node) -> void:
	if not share_allowed:
		return
	var result: Dictionary = export_best(island)
	if not bool(result.ok):
		_note(island, str(result.message))
		return
	var bytes: PackedByteArray = result.bytes
	var file_name: String = (
		"Lumo-Geist_%s_%s.lumogeist" % [player_name.replace(" ", "-"), str(island.track_id)]
	)
	var title: String = (
		"%s fordert dich in Lumo Kart heraus: %s in %s"
		% [
			player_name,
			_track_name(str(island.track_id)),
			format_time(
				float(island.records.config.get_value("times", island.records.record_key, 0.0))
			)
		]
	)
	if HostBridge.share_file(Marshalls.raw_to_base64(bytes), file_name, title):
		_note(island, "Wähle, wem du deinen Geist schickst (%d KB)." % ceili(bytes.size() / 1024.0))
		print("[KartFriends] Geist geteilt: %d Byte" % bytes.size())
		return
	# Ohne Android-Host (Desktop/Test): als Datei im Spielordner ablegen.
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	var path: String = EXPORT_DIR.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_note(island, "Der Geist konnte nicht gespeichert werden.")
		return
	file.store_buffer(bytes)
	file.close()
	_note(
		island,
		(
			"Geist gespeichert (%d KB): %s"
			% [ceili(bytes.size() / 1024.0), ProjectSettings.globalize_path(path)]
		)
	)
	print("[KartFriends] Geist gespeichert: %s (%d Byte)" % [path, bytes.size()])


func _note(island: Node, text: String) -> void:
	last_share_note = text
	var column: Node = island.modal_column
	if not is_instance_valid(column):
		return
	var existing: Node = column.get_node_or_null("FriendGhostShareNote")
	if existing != null:
		existing.label.text = text
		return
	var note := RESULT_WIDGETS.Row.new().setup("notice", text)
	note.name = "FriendGhostShareNote"
	var share: Node = column.get_node_or_null("FriendGhostShareRow")
	column.add_child(note)
	if share != null:
		column.move_child(note, share.get_index() + 1)
	if island.has_method("_apply_responsive_layout"):
		island.call_deferred("_apply_responsive_layout")


static func _known(items: Array, id: String) -> bool:
	for entry in items:
		if str(entry.id) == id:
			return true
	return false


static func _is_track(id: String) -> bool:
	for entry in CATALOG.TRACKS:
		if str(entry.id) == id:
			return true
	return false


static func _track_name(id: String) -> String:
	for entry in CATALOG.TRACKS:
		if str(entry.id) == id:
			return str(entry.name)
	return id


func _text(parent: Control, text: String, size: int, font: Variant = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f4fbff"))
	if font is Font:
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label


func _button(caption: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(250, 76)
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
