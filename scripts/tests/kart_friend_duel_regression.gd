extends SceneTree
## Geister-Duell im echten Kart: Freundes-Geist fährt dieselbe Linie, Namensschild,
## Ergebnis-Satz, Rückspiel-Datei; alter Streckenstand → freundliche Meldung.
## Optional mit Bild: -- --shots <ordner>

var game: Node
var checks: int = 0
var failures: Array[String] = []
var shots: String = ""
var codec: Script
var duel_script: Script


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("[KartFriendDuel] FAIL: ", label)


func _settle(frames: int = 2) -> void:
	for i in range(frames):
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--shots")
	if at >= 0 and at + 1 < args.size():
		shots = args[at + 1]
		DirAccess.make_dir_recursive_absolute(shots)
	codec = load("res://scripts/games/kart_friends/kart_ghost_codec.gd")
	duel_script = load("res://scripts/games/kart_friends/kart_friend_duel.gd")
	_check(
		duel_script.compare_text(80.0, 81.2, "Mia") == "Du warst 1,2 s schneller als Mia!",
		"Satz schneller"
	)
	_check(
		duel_script.compare_text(82.5, 81.0, "Mia") == "Mia war 1,5 s schneller. Noch ein Versuch?",
		"Satz langsamer"
	)
	_check(
		duel_script.compare_text(81.0, 81.02, "Mia").begins_with("Gleichstand"), "Satz Gleichstand"
	)
	_check(
		duel_script.format_time(83.45) == "1:23,5" or duel_script.format_time(83.45) == "1:23,4",
		"Zeitformat"
	)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle(3)
	var setup := {
		"mode": "time_trial",
		"driver": "fox",
		"kart": "comet",
		"track": "sonnenhafen",
		"difficulty": "gemuetlich"
	}
	# 1. Freund fährt: Fahrlinie entlang der echten Strecke, 0,08-s-Takt.
	game._start_selected_race(setup)
	await _settle()
	var version: String = codec.track_version(game.world, "sonnenhafen", float(game.track_length))
	_check(
		version == codec.track_version(game.world, "sonnenhafen", float(game.track_length)),
		"Strecken-Version stabil"
	)
	var frames: Array = []
	var t: float = 0.0
	var d: float = 0.0
	while d < float(game.track_length) * 0.5:
		var xf: Transform3D = game.world.reset_transform(d, sin(d * 0.03) * 1.5)
		frames.append(
			[t, xf.origin + Vector3(0, 0.035, 0), xf.basis.get_euler(), sin(d * 0.03), 26.0]
		)
		t += 0.08
		d += 26.0 * 0.08
	var meta := {
		"track": "sonnenhafen",
		"track_version": version,
		"driver": "rabbit",
		"kart": "comet",
		"difficulty": "flott",
		"name": "Mia",
		"time": t
	}
	var file: Dictionary = codec.encode(frames, meta)
	_check(bool(file.ok), "Freundes-Geist verpackt")
	print(
		(
			"[KartFriendDuel] Geist halbe Runde Sonnenhafen: %d Bilder, %d Byte"
			% [frames.size(), file.bytes.size()]
		)
	)
	# 1b. Alter Streckenstand: freundliche Meldung, kein Freundes-Geist.
	var old_meta: Dictionary = _with(meta, "track_version", "p1:aaaaaaaaaa")
	game.friend_duel.load_options(
		{
			"kartFriendGhost": codec.to_text(codec.encode(frames, old_meta).bytes),
			"friendsGhostShare": true
		}
	)
	game._start_selected_race(setup)
	await _settle(3)
	_check(game.friend_duel.race_state == "old_track", "alter Streckenstand erkannt")
	_check(
		not is_instance_valid(game.ghost) or game.ghost.name != "FriendGhost",
		"kein Freundes-Geist auf neuer Strecke"
	)
	_check(str(game.message.text).contains("neue Strecke"), "freundliche Meldung im Rennen")
	# 2. Kind öffnet ihn: Einladung, dann Rennen.
	game.friend_duel.load_options(
		{
			"kartFriendGhost": codec.to_text(file.bytes),
			"playerName": "Lena",
			"friendsGhostShare": true
		}
	)
	_check(game.friend_duel.has_friend(), "Geist angenommen")
	game._show_garage()
	await _settle()
	game.friend_duel.show_invitation(game)
	await _settle(3)
	var invite: Node = game.safe_ui.get_node_or_null("KartFriendInvitation")
	_check(invite != null, "Einladung sichtbar")
	if invite != null:
		_check(_all_text(invite).contains("Mia fordert dich heraus!"), "Einladungstext")
	await _shot("01_einladung")
	# Wie aus der App nach „Gegen Mia fahren“: Startoption kartFriendStart startet sofort.
	var router: Node = root.get_node("SceneRouter")
	var saved_options: Dictionary = router.launch_options.duplicate(true)
	router.launch_options = {
		"kartFriendGhost": codec.to_text(file.bytes),
		"kartFriendStart": true,
		"playerName": "Lena",
		"friendsGhostShare": true
	}
	game.friend_duel.attach(game)
	router.launch_options = saved_options
	await _settle(2)
	_check(
		game.safe_ui.get_node_or_null("KartFriendInvitation") == null,
		"Einladung nach Start geschlossen"
	)
	await _settle(3)
	_check(
		str(game.mode) == "time_trial" and str(game.track_id) == "sonnenhafen",
		"Duell startet Zeitfahren"
	)
	var ghost: Node3D = game.ghost
	_check(is_instance_valid(ghost) and ghost.name == "FriendGhost", "Freundes-Geist im Rennen")
	_check(
		is_instance_valid(ghost) and ghost.get_node_or_null("FriendNameTag") != null, "Namensschild"
	)
	_check(game.friend_duel.race_state == "racing", "Duell-Zustand")
	# 3. Dieselbe Linie: an 40 Zeitpunkten Geist-Position gegen Original.
	var worst: float = 0.0
	for k in range(40):
		var idx: int = 1 + k * (frames.size() - 3) / 40
		game.elapsed = float(frames[idx][0]) + 0.0001
		game._update_ghost()
		worst = maxf(worst, ghost.position.distance_to(frames[idx][1]))
	print("[KartFriendDuel] größte Abweichung der Geist-Linie: %.4f m" % worst)
	_check(worst < 0.05, "Geist fährt dieselbe Linie (< 5 cm)")
	game.records.replay_index = 0  # Abspielen läuft sonst nur vorwärts
	game.elapsed = float(frames[frames.size() / 3][0])
	game._update_ghost()
	game.countdown = 0
	game.preview_left = 0
	# Für das Bild: Lumo fährt 8 m hinter Mias Geist auf der Nebenspur.
	game.player.transform = game.world.reset_transform(
		(frames.size() / 3) * 26.0 * 0.08 - 8.0, -2.2
	)
	game.player.position.y += 0.035
	game.distance = (frames.size() / 3) * 26.0 * 0.08 - 8.0
	game.player_heading = game._heading(game.distance)
	game._update_camera(1.0, true)
	await _settle(4)
	await _shot("02_rennen_gegen_geist")
	# 4. Ziel: eigene (schnellere) Fahrt wird gespeichert, Satz und Rückspiel-Knopf.
	game.records.recording = frames.slice(0, frames.size() - 20)
	game.elapsed = t - 1.2
	game.ghost_valid = true
	game._finish(false)
	await _settle(3)
	var result_row: Node = game.modal_column.get_node_or_null("FriendDuelResult")
	_check(result_row != null, "Duell-Ergebnis auf der Tafel")
	if result_row != null:
		_check(
			result_row.label.text == "Du warst 1,2 s schneller als Mia!",
			"Ergebnis-Satz: " + result_row.label.text
		)
	var share: Node = game.modal_column.get_node_or_null("FriendGhostShareRow/FriendGhostShare")
	_check(share != null and share.text.contains("zurückschicken"), "Rückspiel-Knopf")
	game.friend_duel.share_best(game)
	await _settle(3)
	var note: Node = game.modal_column.get_node_or_null("FriendGhostShareNote")
	_check(note != null, "Hinweis nach dem Teilen")
	await _shot("03_ergebnis")
	var exported: Array = DirAccess.get_files_at("user://kart_geister")
	_check(exported.size() >= 1, "Rückspiel-Datei geschrieben")
	if exported.size() >= 1:
		var back: Dictionary = codec.decode(
			FileAccess.get_file_as_bytes("user://kart_geister".path_join(exported[0]))
		)
		_check(
			bool(back.ok) and str(back.meta.name) == "Lena", "Rückspiel-Geist trägt den Namen Lena"
		)
		_check(
			bool(back.ok) and str(back.meta.track_version) == version,
			"Rückspiel-Geist trägt Strecken-Version"
		)
	# 4b. Ohne Elternfreigabe „Geister-Duell erlauben“: kein Teilen-Knopf, keine Datei,
	# kein Freundes-Geist, keine Aufforderung – leerer Vorname ist kein Fehler.
	game.friend_duel.load_options({"kartFriendGhost": codec.to_text(file.bytes), "playerName": ""})
	_check(not game.friend_duel.share_allowed, "Vorgabe: Geister-Duell aus")
	_check(
		not game.friend_duel.has_friend() and game.friend_duel.rejected.is_empty(),
		"ohne Freigabe kein Freundes-Geist und kein Hinweis"
	)
	_check(game.friend_duel.player_name == "Freund", "leerer Vorname → Freund")
	var bare := VBoxContainer.new()
	game.friend_duel.race_state = ""
	game.friend_duel.add_result_rows(game, bare)
	_check(
		bare.get_node_or_null("FriendGhostShareRow/FriendGhostShare") == null,
		"ohne Freigabe kein FriendGhostShare-Knopf"
	)
	bare.free()
	var files_before: int = DirAccess.get_files_at("user://kart_geister").size()
	game.friend_duel.share_best(game)
	_check(
		DirAccess.get_files_at("user://kart_geister").size() == files_before,
		"ohne Freigabe teilt share_best nichts"
	)
	game.friend_duel.load_options({"friendsGhostShare": true, "playerName": "Lena"})
	# 5. Eigene Bestzeiten sind nicht die des Freundes.
	_check(
		(
			absf(
				(
					float(game.records.config.get_value("times", game.records.record_key, 0.0))
					- (t - 1.2)
				)
			)
			< 0.01
		),
		"eigene Bestzeit gespeichert"
	)
	# 7. Beschädigte Datei: Ablehnung im Menü, kein Rennen, nichts gespeichert.
	var before: float = float(game.records.config.get_value("times", game.records.record_key, 0.0))
	game.friend_duel.load_options(
		{"kartFriendGhost": "LUMOGEIST1:TEdTVAFmYWxzY2g", "friendsGhostShare": true}
	)
	_check(
		not game.friend_duel.has_friend() and not game.friend_duel.rejected.is_empty(),
		"kaputter Geist abgelehnt"
	)
	_check(
		float(game.records.config.get_value("times", game.records.record_key, 0.0)) == before,
		"Spielstand unverändert"
	)
	game.friend_duel.load_options(
		{
			"kartFriendGhost":
			codec.to_text(codec.encode(frames, _with(meta, "track", "mondbahn")).bytes),
			"friendsGhostShare": true
		}
	)
	_check(
		not game.friend_duel.has_friend() and game.friend_duel.rejected.contains("Strecke"),
		"unbekannte Strecke abgelehnt"
	)
	game.abandoned = true
	game.queue_free()
	await _settle(6)
	await create_timer(1.0).timeout
	if failures.is_empty():
		print("[KartFriendDuel] PASS: %d Prüfungen" % checks)
		quit(0)
	else:
		print("[KartFriendDuel] FAIL: %d von %d Prüfungen" % [failures.size(), checks])
		quit(1)


func _with(source: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy: Dictionary = source.duplicate()
	copy[key] = value
	return copy


func _all_text(node: Node) -> String:
	var out: String = ""
	if node is Label or node is Button:
		out += str(node.text) + "\n"
	for child in node.get_children():
		out += _all_text(child)
	return out


func _shot(name: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(shots.path_join(name + ".png"))
	print("[KartFriendDuel] Bild: ", shots.path_join(name + ".png"))
