extends SceneTree
## Zwei echte Godot-Prozesse fahren über localhost ein Rennen zu Ende (kopflos).
## Start: scripts/tests/kart_lan_two_process.sh  (Rollen: host | client | client_drop)
## Prüft: Raumcode, Begrüßung, gemeinsamer Start, 15 Hz Fahrdaten mit Glättung,
## faire Zielzeiten auf beiden Seiten, Abbruch → „du fährst allein weiter“.

const TRACK_LENGTH: float = 260.0

var session: Node
var role: String = "host"
var checks: int = 0
var failures: Array[String] = []
var poses: int = 0
var max_step: float = 0.0
## Gezeigtes Tempo je Messfenster (für das 95-%-Maß; einzelne Aufholfenster nach
## Rucklern zählen dort nicht).
var window_speeds: Array[float] = []
var last_pose := Vector3.INF
var lost_text: String = ""
var window: float = 0.0
var last_clock: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("[KartLan:%s] FAIL: %s" % [role, label])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	var code: String = args[1] if args.size() > 1 else ""
	session = load("res://scripts/games/kart_friends/kart_lan_session.gd").new()
	session.network_prefix_override = "127.0.0."
	root.add_child(session)
	session.friend_left.connect(func(text: String): lost_text = text)
	var info := {
		"name": "Lena" if role == "host" else "Mia",
		"driver": "fox" if role == "host" else "rabbit",
		"kart": "comet",
		"track": "sonnenhafen",
		"track_version": "p1:0aba97599e"
	}
	_check(
		session.octet_for_code("0013") == -1 or session.code_for_octet(1) != "0013",
		"Prüfziffer wirkt"
	)
	_check(session.octet_for_code(session.code_for_octet(37)) == 37, "Raumcode hin und zurück")
	_check(
		session.octet_for_code("12a4") == -1 and session.octet_for_code("2550") == -1,
		"falsche Codes"
	)
	if role == "host":
		_check(session.host(info), "Raum geöffnet")
		print("[KartLan:host] Raumcode ", session.room_code)
		_check(session.room_code == session.code_for_octet(1), "Code aus Adresse")
		if not await _until(func(): return session.state == "lobby", 90.0):
			_finish("kein Freund gekommen")
			return
		_check(
			str(session.friend.name) == "Mia" and str(session.friend.driver) == "rabbit",
			"Freund begrüßt"
		)
		await create_timer(0.3).timeout
		session.start_race(0.5)
	else:
		# Erst die Prüfziffer: ein Tippfehler darf nichts verbinden.
		_check(not session.join("0012", info), "Tippfehler abgelehnt")
		_check(
			session.join(session.code_for_octet(1) if code.is_empty() else code, info),
			"Beitritt gestartet"
		)
		if not await _until(func(): return session.state == "racing", 90.0):
			_finish("kein Start empfangen (Zustand %s)" % session.state)
			return
		_check(str(session.friend.name) == "Lena", "Gastgeber erkannt")
	_check(session.state == "racing", "Rennen läuft")
	# Fahren: Gastgeber 20 m/s, Gast 22 m/s; Mia ist schneller.
	var speed: float = 20.0 if role == "host" else 22.0
	var race_time: float = 0.0
	var distance: float = 0.0
	var finished_at: float = -1.0
	Engine.max_fps = 60
	var step: float = 0.0
	var ticks: int = Time.get_ticks_usec()
	while race_time < 30.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		step = (now - ticks) / 1000000.0
		ticks = now
		race_time += step
		if finished_at < 0.0:
			distance += speed * step
		var angle: float = distance / TRACK_LENGTH * TAU
		var pos := Vector3(sin(angle) * 41.4, 0.0, cos(angle) * 41.4)
		session.send_state(
			step,
			race_time,
			pos,
			Vector3(0, angle + PI * 0.5, 0),
			speed if finished_at < 0.0 else 0.0,
			0.2
		)
		if finished_at < 0.0 and distance >= TRACK_LENGTH:
			# Genau an der Linie (wie im Kart), nicht erst beim nächsten Bild.
			finished_at = race_time - (distance - TRACK_LENGTH) / speed
			session.send_finish(finished_at)
			if role == "client_drop":
				break
		var pose: Dictionary = session.friend_pose(race_time)
		if not pose.is_empty():
			poses += 1
			# Geschwindigkeit, mit der sich der gezeigte Freund bewegt (Sprünge = Ruckeln),
			# gemessen über Fenster von mindestens 0,1 s.
			# Uhr der Wiedergabe (Sitzung), nicht die Wanduhr des Tests.
			window += session._clock - last_clock
			last_clock = session._clock
			if last_pose == Vector3.INF:
				last_pose = pose.p
				window = 0.0
			elif window >= 0.1:
				var shown: float = (pose.p as Vector3).distance_to(last_pose) / window
				max_step = maxf(max_step, shown)
				window_speeds.append(shown)
				last_pose = pose.p
				window = 0.0
		if role == "client_drop" and race_time > 5.0:
			break
		if finished_at > 0.0 and session.friend_time > 0.0 and race_time > finished_at + 0.5:
			break
		if not lost_text.is_empty() and finished_at > 0.0:
			break
	if role == "client_drop":
		print("[KartLan:client_drop] verlässt das Rennen nach %.1f s" % race_time)
		session.peer.close()  # hart weg, ohne Abschied (wie WLAN aus)
		session.peer = null
		_finish("")
		return
	print(
		(
			"[KartLan:%s] eigene Zeit %.2f s, Freund %.2f s, Posen %d, schnellste gezeigte Bewegung %.1f m/s"
			% [role, finished_at, session.friend_time, poses, max_step]
		)
	)
	if code == "drop":
		_check(lost_text.contains("allein weiter"), "Abbruch freundlich gemeldet: " + lost_text)
		_check(finished_at > 0.0, "Rennen allein zu Ende gefahren")
	else:
		_check(finished_at > 0.0 and session.friend_time > 0.0, "beide im Ziel")
		# Zielzeit = erstes Bild über der Linie (Bildtakt 60/s → höchstens ~2 Bilder später).
		var expected_own: float = TRACK_LENGTH / speed
		var expected_friend: float = TRACK_LENGTH / (22.0 if role == "host" else 20.0)
		_check(absf(finished_at - expected_own) < 0.02, "eigene Zeit fair (%.3f)" % finished_at)
		_check(absf(session.friend_time - expected_friend) < 0.02, "Zeit des Freundes übertragen")
		_check(poses > 200, "Fahrdaten kommen an (%d)" % poses)
		# Echtes Tempo höchstens 22 m/s; ein Sprung würde als viel höheres Tempo erscheinen.
		# Glättung der Netzbasis: Uhr höchstens ±10 % nachgeführt, nach Rucklern (Last, WLAN-Pause)
		# gleitet die Anzeige mit höchstens 1 × Tempo zusätzlich hinterher (→ ≤ 2 × 22 + 2 m/s).
		# Lastunabhängig geprüft: 95 % der Fenster unter 28 m/s, kein Fenster über 2,5 × 22 m/s.
		var sorted: Array[float] = window_speeds.duplicate()
		sorted.sort()
		var p95: float = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else INF
		_check(p95 < 28.0, "Freund fährt flüssig (95 %% der Fenster ≤ %.1f m/s)" % p95)
		_check(max_step < 55.5, "kein Sprung (höchstens %.1f m/s gezeigt)" % max_step)
	_finish("")


func _until(condition: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _finish(error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		print("[KartLan:%s] FAIL: %s" % [role, error])
	if role != "client_drop" and is_instance_valid(session):
		session.close("")
	await create_timer(0.3).timeout
	if failures.is_empty():
		print("[KartLan:%s] PASS: %d Prüfungen" % [role, checks])
		quit(0)
	else:
		print("[KartLan:%s] FAIL: %d von %d" % [role, failures.size(), checks])
		quit(1)
