extends SceneTree
## Netzbasis mit ECHTEN Godot-Prozessen über ENet auf 127.0.0.1 (kopflos).
## Start: scripts/tests/lumo_net_multi_process.sh – Rollen:
##   host <port> <ordner>              Autorität + Fahrer, 4 Plätze (2 Gäste + KI)
##   guest <port> <ordner> <name>      Gast fährt bis zum Ergebnis
##   drop <port> <ordner> <name>       Gast fährt 5 s, schreibt Platzkarte, Prozess endet hart
##   resume <port> <ordner> <name>     NEUER Prozess mit der Platzkarte: gleicher Platz, Rest
## Jeder Prozess schreibt <ordner>/<name>.json (Ereignisse, Buchungen, Messwerte); das
## Shell-Skript vergleicht sie. Uhren laufen echt (wie im Spiel); geprüft wird nur, was nicht
## von der Last abhängt (Ereignisse, Plätze, Buchung) – Glätte mit großzügigem 95-%-Maß.
## Zwei Geräte im WLAN prüft das NICHT.

const SESSION = preload("res://scripts/games/net/lumo_net_session.gd")
const LAP: float = 200.0
const CPS: int = 8
const LAPS: int = 2
const ZONES: int = 3

var role: String = ""
var port: int = 0
var dir: String = ""
var who: String = "host"
var session: Node
var events: Array = []
var booked: Array = []
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("[LumoNetMP:%s] FAIL: %s" % [who, label])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	role = args[0]
	port = int(args[1])
	dir = args[2]
	who = args[3] if args.size() > 3 else "host"
	Engine.max_fps = 60
	session = SESSION.new()
	session.auto_poll = false
	root.add_child(session)
	session.game_event.connect(func(ev: Dictionary): events.append(ev))
	session.result_confirmed.connect(
		func(eid: String, place: int, time: float): booked.append([eid, place, time])
	)
	var speed: float = 20.0
	var resume: Dictionary = {}
	if role == "host":
		var config := {
			"laps": LAPS,
			"cps": CPS,
			"zones": ZONES,
			"min_gap": 0.8,
			"countdown": 1.5,
			"grace": 45.0,
			"ai_cp_seconds": [1.3, 1.3, 1.3, 1.3]
		}
		_check(
			session.host_room({"ps": "Kluger Luchs 4", "drv": "fox"}, config, port), "Raum offen"
		)
		session.pose_provider = func(seat: int, rt: float) -> Array:
			var d: float = clampf(rt, 0.0, 99.0) * LAP / CPS / 1.3
			return _circle(d) + [6.0 * seat, 15.0]
		print("[LumoNetMP:host] Raum offen auf Port %d" % port)
		if not await _until(func(): return session.match_state.human_count() >= 3, 120.0):
			return _finish("Gäste kamen nicht (%d)" % session.match_state.human_count())
		await _frames(30)
		_check(session.start_race(), "Start")
	else:
		var ps: String = "Mutiger Biber 1" if who == "a" else "Wilder Hase 7"
		speed = 21.0 if who == "a" else 22.0
		var token: String = ""
		var last: int = 0
		if role == "resume":
			resume = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("drop.json")))
			token = str(resume.tok)
			last = int(resume.last)
			events = resume.events
		_check(
			session.join_room(
				"127.0.0.1", {"ps": ps, "drv": "otter"}, port, Callable(), token, last
			),
			"Beitritt"
		)
		if not await _until(func(): return session.state in ["racing", "done"], 120.0):
			return _finish("kein Start (Zustand %s)" % session.state)
		if role == "resume":
			_check(int(session.my_seat) == int(resume.seat), "gleicher Platz nach Neustart")
	var next_cp: int = int(resume.get("next_cp", 0))
	var next_zone: int = int(resume.get("next_zone", 0))
	var held: int = 0
	var held_since: float = 0.0
	var used := {}
	var reached_done: bool = false
	var speeds: Array[float] = []
	var last_seen := Vector3.INF
	var last_clock: float = 0.0
	var ticks: int = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var delta: float = (now - ticks) / 1000000.0
		ticks = now
		var rt: float = session.race_time()
		var d: float = clampf(rt, 0.0, 999.0) * speed
		d = minf(d, LAP * LAPS)
		var pose: Array = _circle(d)
		session.update_own(Vector3(pose[0], pose[1], pose[2]), pose[3], speed)
		while next_cp < CPS * LAPS and d >= LAP / CPS * float(next_cp + 1):
			var at: float = LAP / CPS * float(next_cp + 1) / speed
			session.claim_checkpoint(next_cp / CPS, next_cp % CPS, at)
			next_cp += 1
		var lap: int = mini(int(d / LAP), LAPS - 1)
		var zone_at: float = lap * LAP + (float(next_zone % ZONES) + 0.5) * LAP / ZONES
		if next_zone < ZONES * LAPS and next_zone / ZONES == lap and d >= zone_at:
			session.pick_item("%d:%d" % [lap, next_zone % ZONES])
			next_zone += 1
		for ev in events:
			var n: int = int(ev.n)
			if ev.kind == "item" and int(ev.seat) == session.my_seat and not used.has(n):
				if held != n:
					held = n
					held_since = rt
		if held > 0 and rt - held_since > 1.0:
			session.use_item(held)  # jedes Item genau einmal einsetzen
			used[held] = true
			held = 0
		session.poll(delta)
		if role == "drop" and rt > 5.0:
			var drop := {
				"tok": session.token,
				"last": session.last_event,
				"seat": session.my_seat,
				"next_cp": next_cp,
				"next_zone": next_zone,
				"events": events
			}
			var file := FileAccess.open(dir.path_join("drop.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify(drop))
			file.close()
			print("[LumoNetMP:%s] Prozess endet hart bei Rennzeit %.1f s" % [who, rt])
			quit(0)  # ohne Abmeldung, wie App weggewischt
			return
		# Glätte: wie zeigt dieser Prozess den Gastgeber (Platz 0) bzw. Gast a?
		var watch: int = _watched()
		var shown: Dictionary = session.pose_of(watch)
		if not shown.is_empty() and rt > 1.0 and rt < 18.0:
			if last_seen == Vector3.INF:
				last_seen = shown.p
				last_clock = session.clock
			elif session.clock - last_clock >= 0.1:
				speeds.append(
					(shown.p as Vector3).distance_to(last_seen) / (session.clock - last_clock)
				)
				last_seen = shown.p
				last_clock = session.clock
		reached_done = reached_done or session.state == "done"
		if session.state == "done" and rt > 0.0:
			await _frames(60)
			break
		if session.state == "closed":
			break
	speeds.sort()
	var p95: float = speeds[int(speeds.size() * 0.95)] if not speeds.is_empty() else -1.0
	var top: float = speeds[-1] if not speeds.is_empty() else -1.0
	var interp: RefCounted = session.interpolator(_watched())
	print(
		(
			"[LumoNetMP:%s] Platz %d, Ereignisse %d, Buchungen %d, Glätte 95 %% %.1f m/s, max %.1f"
			% [who, session.my_seat, events.size(), booked.size(), p95, top]
		)
	)
	if interp != null:
		print(
			(
				"[LumoNetMP:%s] Glättung: vorausgeschätzt %d Bilder, Aufholen %d, Neueinrasten %d"
				% [who, interp.extrapolated_frames, interp.glides, interp.relocks]
			)
		)
	_check(reached_done, "Ergebnis erreicht (%s)" % session.state)
	_check(booked.size() == 1, "genau eine Buchung (%d)" % booked.size())
	if role != "resume":  # der Neustart kommt je nach Last erst nach dem Messfenster
		_check(speeds.size() > 40, "Fahrdaten kommen an (%d Fenster)" % speeds.size())
		# Echt höchstens 21 m/s; Nachführung ±10 % + begrenztes Aufholen nach Rucklern.
		_check(p95 > 0.0 and p95 < 21.0 * 1.3, "flüssig (95 %% ≤ %.1f m/s)" % p95)
	if role == "host":
		_check(int(session.match_state.rejects.get("order", 0)) == 0, "keine falsche Reihenfolge")
		print("[LumoNetMP:host] Abgelehnt: %s" % str(session.match_state.rejects))
	var out := {
		"who": who,
		"seat": session.my_seat,
		"events": events.map(func(ev: Dictionary) -> String: return "%s:%s" % [ev.eid, ev.kind]),
		"booked": booked,
		"p95": p95
	}
	var file := FileAccess.open(dir.path_join("%s.json" % who), FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	_finish("")


## Gastgeber beobachtet Gast a (fährt durch), alle Gäste beobachten den Gastgeber.
func _watched() -> int:
	if role != "host":
		return 0
	for seat in session.seats:
		if str(seat.ps) == "Mutiger Biber 1":
			return int(seat.seat)
	return 1


static func _circle(d: float) -> Array:
	var angle: float = d / LAP * TAU
	var radius: float = LAP / TAU
	return [sin(angle) * radius, 0.0, cos(angle) * radius, angle + PI * 0.5]


func _frames(count: int) -> void:
	var ticks: int = Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now: int = Time.get_ticks_usec()
		session.poll((now - ticks) / 1000000.0)
		ticks = now


func _until(condition: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var ticks: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
		var now: int = Time.get_ticks_usec()
		session.poll((now - ticks) / 1000000.0)
		ticks = now
	return false


func _finish(error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		print("[LumoNetMP:%s] FAIL: %s" % [who, error])
	session.leave()
	await create_timer(0.3).timeout
	if failures.is_empty():
		print("[LumoNetMP:%s] PASS: %d Prüfungen" % [who, checks])
		quit(0)
	else:
		print("[LumoNetMP:%s] FAIL: %d von %d" % [who, failures.size(), checks])
		quit(1)
