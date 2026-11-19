extends SceneTree
## „Zusammen fahren“ im echten Kart (ein Prozess, zweites Gerät als Sitzung über localhost):
## Knopf nur mit Elternfreigabe, Raumcode, Tastenfeld, gemeinsamer Start, Freundes-Kart mit
## Namensschild folgt der übertragenen Fahrt, Ergebnis-Vergleich, Abbruch → allein weiter.
## Optional mit Bild: -- --shots <ordner>

var game: Node
var friend: Node
var checks: int = 0
var failures: Array[String] = []
var shots: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("[KartLanRace] FAIL: ", label)


func _settle(frames: int = 2) -> void:
	for i in range(frames):
		await process_frame


func _until(condition: Callable, seconds: float) -> bool:
	# Mit Bild (Software-Grafik) dauert ein Bild Sekunden: dann länger warten.
	var factor: float = 1.0 if DisplayServer.get_name() == "headless" else 12.0
	var deadline: int = Time.get_ticks_msec() + int(seconds * factor * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--shots")
	if at >= 0 and at + 1 < args.size():
		shots = args[at + 1]
		DirAccess.make_dir_recursive_absolute(shots)
	var router: Node = root.get_node("SceneRouter")
	# Ohne Elternfreigabe: kein Knopf, keine Sitzung.
	router.launch_options = {"playerName": "Lena"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle(3)
	_check(game.friend_duel.lan == null, "ohne Freigabe kein WLAN-Spiel")
	_check(game.safe_ui.get_node_or_null("KartLanEntry") == null, "ohne Freigabe kein Knopf")
	# Mit Freigabe (wie aus dem Elternbereich).
	router.launch_options = {"playerName": "Lena", "friendsLan": true}
	game.friend_duel.attach(game)
	router.launch_options = {}
	var lan: Node = game.friend_duel.lan
	_check(lan != null, "WLAN-Spiel mit Freigabe")
	lan.session.network_prefix_override = "127.0.0."
	game._show_reference_landing()
	await _settle(3)
	var entry: Button = game.safe_ui.get_node_or_null("KartLanEntry")
	_check(entry != null and entry.visible, "Knopf „Zusammen fahren“ im Menü")
	await _shot("09_menue_zusammen_fahren")
	# Ohne zweites Gerät: Raum öffnen, niemand kommt, „Abbrechen“ und „Schließen“ führen sauber
	# ins Menü zurück (Sitzung zu, Port frei, Knopf wieder da, kein „Los!“ ohne Freund).
	lan.open_lobby()
	await _settle()
	lan._host()
	await _settle(4)
	_check(lan.session.state == "hosting", "allein: Raum offen")
	_check(lan.start_button.disabled, "allein: kein „Los!“ ohne Freund")
	lan._leave()
	await _settle()
	_check(
		lan.session.state == "idle" and lan.session.peer == null,
		"allein: Abbrechen schließt den Raum"
	)
	lan.close_lobby()
	await _settle(3)
	_check(not is_instance_valid(lan.panel) and entry.visible, "allein: zurück im Menü")
	lan.open_lobby()
	await _settle()
	lan._host()
	await _settle(2)
	_check(lan.session.state == "hosting", "allein: Raum lässt sich wieder öffnen")
	lan.close_lobby()
	await _settle(3)
	_check(
		lan.session.state == "idle" and lan.session.peer == null and entry.visible,
		"allein: Schließen schließt den Raum"
	)
	# Tastenfeld: Tippfehler wird abgelehnt (bevor ein Raum offen ist).
	lan.open_lobby()
	await _settle()
	lan._show_keypad()
	await _settle()
	for key in ["0", "0", "1", "3", "OK"]:
		lan._on_key(key)
	_check(
		lan.session.state == "closed" and lan.status_label.text.contains("stimmt nicht"),
		"Tippfehler-Code"
	)
	await _shot("10_tastenfeld")
	lan._show_choice()
	await _settle()
	lan._host()
	await _settle(2)
	_check(
		lan.session.state == "hosting" and lan.session.room_code == "0019", "Raum offen, Code 0019"
	)
	_check(
		is_instance_valid(lan.code_label) and lan.code_label.text == "0 0 1 9", "Code groß sichtbar"
	)
	await _shot("11_raumcode")
	# Zweites Gerät: Mia tritt bei.
	friend = load("res://scripts/games/kart_friends/kart_lan_session.gd").new()
	friend.network_prefix_override = "127.0.0."
	root.add_child(friend)
	_check(
		friend.join(
			"0019", {"name": "Mia", "driver": "rabbit", "kart": "comet", "track": "sonnenhafen"}
		),
		"Mia tritt bei"
	)
	_check(
		await _until(func(): return lan.session.state == "lobby" and friend.state == "lobby", 10.0),
		"beide im Raum"
	)
	_check(lan.status_label.text.contains("Mia ist da"), "Gastgeber sieht Mia")
	_check(not lan.start_button.disabled, "„Los!“ freigegeben")
	await _shot("12_mia_ist_da")
	lan.start_button.pressed.emit()
	_check(await _until(func(): return friend.state == "racing", 5.0), "Start kommt bei Mia an")
	await _settle(3)
	_check(
		str(game.mode) == "time_trial" and str(game.track_id) == "sonnenhafen",
		"gemeinsames Rennen läuft"
	)
	var remote: Node3D = game.ghost
	_check(is_instance_valid(remote) and remote.name == "LanFriendKart", "Mias Kart im Rennen")
	_check(
		is_instance_valid(remote) and remote.get_node_or_null("FriendNameTag") != null,
		"Namensschild Mia"
	)
	_check(game.preview_total == 0.0, "keine Kamerafahrt vor dem gemeinsamen Start")
	# Mia fährt 12 m vor Lena auf der Strecke; Lena steht (Bild) und bekommt Mias Fahrt.
	game.countdown = 0.0
	game.racing = true
	var mia_d: float = 30.0
	var worst: float = 0.0
	var samples: int = 0
	var race_clock: float = 0.0
	var ticks: int = Time.get_ticks_usec()
	friend.send_track_version(lan.get_meta("own_version"))
	# Mit Bild laufen die Bilder langsamer: mindestens 4 s und 30 Messbilder.
	var rendering: bool = DisplayServer.get_name() != "headless"
	while race_clock < 4.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = (now - ticks) / 1000000.0
		ticks = now
		race_clock += dt
		mia_d += 14.0 * dt
		var xf: Transform3D = game.world.reset_transform(mia_d, 1.6)
		friend.send_state(
			dt, race_clock, xf.origin + Vector3(0, 0.035, 0), xf.basis.get_euler(), 14.0, 0.0
		)
		game.elapsed = race_clock
		game.friend_duel.tick(game, dt)
		# Bilder nach einem Hänger der (ausgelasteten) Testmaschine zählen nicht: dort springt die
		# Sendeposition in einem Schritt um dt × 14 m/s, das sagt nichts über die Glättung.
		if race_clock > 1.0 and remote.visible and dt <= 0.05:
			# Gezeigt wird Mias Fahrt 0,12 s verzögert: Abstand zur aktuellen Position ≈ 1,7 m.
			worst = maxf(worst, remote.position.distance_to(xf.origin))
			samples += 1
	print(
		(
			"[KartLanRace] Mias Kart: %d Bilder, größter Abstand zur Sendeposition %.2f m"
			% [samples, worst]
		)
	)
	# Mit Bild (Software-Grafik im Container, wenige Bilder pro Sekunde) wird nur das Bild
	# gemacht; die Fahrprüfung gilt im kopflosen Lauf.
	if not rendering:
		_check(samples > 30, "Mias Kart sichtbar")
		_check(worst < 4.0, "Mias Kart folgt ihrer Fahrt (%.2f m)" % worst)
	# Für das Bild: Mia hält kurz an derselben Stelle, bis ihr Kart dort steht.
	for hold in range(40):
		await process_frame
		race_clock += 0.1
		var still: Transform3D = game.world.reset_transform(mia_d, 1.6)
		friend.send_state(
			0.1, race_clock, still.origin + Vector3(0, 0.035, 0), still.basis.get_euler(), 0.0, 0.0
		)
		game.elapsed = race_clock
		game.friend_duel.tick(game, 0.1)
		if hold > 4 and remote.visible and remote.position.distance_to(still.origin) < 1.0:
			break
	_check(not str(game.message.text).contains("verschieden alt"), "gleiche Strecken-Version")
	game.player.transform = game.world.reset_transform(mia_d - 10.0, -1.6)
	game.player.position.y += 0.035
	game.distance = mia_d - 10.0
	game.player_heading = game._heading(game.distance)
	game._update_camera(1.0, true)
	await _settle(4)
	await _shot("13_rennen_mit_mia")
	# Ziel: Lena 61,8 s, Mia 63,0 s.
	game.elapsed = 61.8
	game.ghost_valid = false
	game._finish(false)
	await _settle(3)
	var row: Node = game.modal_column.get_node_or_null("LanResult")
	_check(row != null and row.label.text == "Mia ist noch unterwegs …", "Mia noch unterwegs")
	friend.send_finish(63.0)
	_check(
		await _until(func(): return lan.session.friend_time > 0.0, 5.0), "Mias Zielzeit kommt an"
	)
	await _settle(2)
	_check(row != null and row.label.text == "Du warst 1,2 s schneller als Mia!", "Ergebnis-Satz")
	await _shot("14_ergebnis")
	# Abbruch: Mias Gerät verschwindet ohne Abschied → freundliche Meldung.
	if friend.peer != null:
		friend.peer.close()
	friend.peer = null
	_check(await _until(func(): return lan.session.state == "closed", 15.0), "Abbruch erkannt")
	_check(str(game.message.text).contains("allein weiter"), "freundliche Meldung")
	game.abandoned = true
	game.queue_free()
	friend.queue_free()
	await _settle(6)
	await create_timer(1.0).timeout
	if failures.is_empty():
		print("[KartLanRace] PASS: %d Prüfungen" % checks)
		quit(0)
	else:
		print("[KartLanRace] FAIL: %d von %d Prüfungen" % [failures.size(), checks])
		quit(1)


func _shot(name: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("[KartLanRace] Bild: ", shots.path_join(name + ".png"))
