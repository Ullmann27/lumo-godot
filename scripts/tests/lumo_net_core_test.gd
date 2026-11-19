extends SceneTree
## Netzbasis in EINEM Prozess (kopflos, feste Schritte – lastunabhängig, keine Wanduhr):
## Leitungsformat, Spielstand der Autorität, Glättung, Raum mit Autorität + 2 Gästen + KI über
## ein Speicher-Netz mit Verzögerung, Zittern und Paketverlust, Wiederverbinden, Fälschungen,
## einmalige Buchung. Ergebnis: „[LumoNet] PASS: n Prüfungen“.

const STEP: float = 1.0 / 60.0
const LAP: float = 200.0

const WIRE = preload("res://scripts/games/net/lumo_net_wire.gd")
const MATCH = preload("res://scripts/games/net/lumo_net_match.gd")
const INTERP = preload("res://scripts/games/net/lumo_net_interpolator.gd")
const TRANSPORT = preload("res://scripts/games/net/lumo_net_transport.gd")
const SESSION = preload("res://scripts/games/net/lumo_net_session.gd")
const LEDGER = preload("res://scripts/games/net/lumo_net_ledger.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("[LumoNet] FAIL: ", label)


func _run() -> void:
	_test_wire()
	_test_match()
	_test_interpolator()
	_test_ledger()
	_test_room_full()
	_test_session_race()
	if failures.is_empty():
		print("[LumoNet] PASS: %d Prüfungen" % checks)
		quit(0)
	else:
		print("[LumoNet] FAIL: %d von %d Prüfungen" % [failures.size(), checks])
		quit(1)


func _test_wire() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ps: String = WIRE.make_pseudonym(rng)
	_check(WIRE.clean_pseudonym(ps) == ps, "Pseudonym aus Wortliste bleibt: " + ps)
	_check(WIRE.clean_pseudonym("Lena") == "Flinker Fuchs 1", "Vorname wird nie übertragen")
	_check(WIRE.clean_pseudonym("Flinker Fuchs 07") == "Flinker Fuchs 1", "nur kanonische Zahl")
	var join := {"t": "join", "v": WIRE.PROTOCOL, "ps": ps, "drv": "otter", "kart": "comet"}
	var back: Dictionary = WIRE.decode(WIRE.encode(join), false)
	_check(back.get("ps") == ps and back.get("drv") == "otter", "join hin und zurück")
	_check(WIRE.decode(WIRE.encode(join), true).is_empty(), "join von der Autorität verworfen")
	var forged := {"t": "ev", "n": 9, "kind": "result", "eid": "rx_9", "seat": 1, "standings": []}
	_check(WIRE.decode(WIRE.encode(forged), false).is_empty(), "Gast kann kein Ereignis senden")
	_check(not WIRE.decode(WIRE.encode(forged), true).is_empty(), "Autorität darf Ereignisse")
	var pose := {"t": "pose", "s": [1, 2.5, 1.0, 0.0, -3.0, 0.4, 21.0]}
	_check(WIRE.decode(WIRE.encode(pose), false).has("s"), "Fahrdaten angenommen")
	for bad in [
		[1.5, 2.5, 1, 0, 0, 0, 0],
		[7, 2.5, 1, 0, 0, 0, 0],
		[1, 2.5, 99999.0, 0, 0, 0, 0],
		[1, 2.5, 1, 0, 0, 0],
		[1, "x", 1, 0, 0, 0, 0]
	]:
		_check(
			WIRE.decode(WIRE.encode({"t": "pose", "s": bad}), false).is_empty(),
			"kaputte Fahrdaten verworfen %s" % str(bad)
		)
	var umlaut: Dictionary = WIRE.decode(
		WIRE.encode({"t": "roster", "seats": [{"seat": 0, "kind": "human", "ps": "Äpfel"}]}), true
	)
	_check(not umlaut.is_empty() and umlaut.seats[0].ps == "Flinker Fuchs 1", "Nicht-ASCII sicher")
	# 300 Zufallspakete: nie ein Fehler, nie eine Nachricht.
	var accepted: int = 0
	for i in range(300):
		var junk := PackedByteArray()
		junk.resize(rng.randi_range(0, 1600))
		for j in range(junk.size()):
			junk[j] = rng.randi_range(0, 255)
		if i % 3 == 0 and junk.size() > 0:
			junk[0] = 123
		if not WIRE.decode(junk, i % 2 == 0).is_empty():
			accepted += 1
	_check(accepted == 0, "300 Zufallspakete verworfen (%d angenommen)" % accepted)
	var big := {"t": "ping", "c": 1.0, "pad": "x".repeat(2000)}
	_check(WIRE.decode(WIRE.encode(big), false).is_empty(), "Übergröße verworfen")
	_check(
		WIRE.decode(WIRE.encode({"t": "join", "v": 1, "ps": ps}), false).has("bad_protocol"),
		"alter Protokollstand erkannt"
	)


func _test_match() -> void:
	var drawn: Array = []
	var game: RefCounted = MATCH.new({"laps": 1, "cps": 4, "zones": 2, "min_gap": 1.0}, 5)
	game.drawer = func(seat: int, place: int, _progress: float) -> String:
		drawn.append([seat, place])
		return "shield"
	var a: Dictionary = game.join({"ps": "Heller Igel 3"}, "", 0.0)
	var b: Dictionary = game.join({"ps": "Wilder Hase 9"}, "", 0.0)
	_check(bool(a.ok) and bool(b.ok) and int(b.seat) == 1, "zwei Plätze vergeben")
	_check(str(a.tok).length() == 32 and a.tok != b.tok, "eigene Platzkarten")
	_check(game.claim_checkpoint(0, 0, 0, 2.0, 2.0).is_empty(), "vor dem Start nichts")
	_check(game.start(10.0), "Start")
	_check(game.seats[2].kind == "ai" and game.seats[3].kind == "ai", "KI füllt freie Plätze")
	_check(not bool(game.join({}, "", 11.0).ok), "kein Neuzugang nach dem Start")
	_check(
		str(game.join({}, "ffffffffffffffffffffffffffffffff", 11.0).why) == "token", "fremde Karte"
	)
	var now: float = 13.0 + 1.5  # Rennzeit 1,5 s
	_check(game.claim_checkpoint(0, 0, 1, 1.5, now).is_empty(), "Checkpoint überspringen verboten")
	_check(not game.claim_checkpoint(0, 0, 0, 1.5, now).is_empty(), "erster Checkpoint")
	_check(game.claim_checkpoint(0, 0, 1, 2.0, now + 0.5).is_empty(), "zu schnell verworfen")
	var cp: Dictionary = game.claim_checkpoint(0, 0, 1, 99.0, now + 1.2)
	_check(not cp.is_empty() and absf(float(cp.t) - 2.7) < 0.001, "Zeit aus der Zukunft gekappt")
	var early: Dictionary = game.claim_checkpoint(1, 0, 0, 0.1, now + 1.2)
	_check(
		not early.is_empty() and absf(float(early.t) - 2.2) < 0.001, "Zeit-Rückdatierung gekappt"
	)
	var item: Dictionary = game.pick_item(0, "0:1", now + 1.3)
	_check(not item.is_empty() and item.item == "shield", "Ziehung durch die Autorität")
	_check(game.pick_item(0, "0:1", now + 1.4).is_empty(), "dieselbe Zone nicht zweimal")
	_check(game.pick_item(0, "0:0", now + 1.4).is_empty(), "volles Item-Feld: keine Ziehung")
	_check(game.pick_item(0, "1:0", now + 1.4).is_empty(), "Zone der falschen Runde")
	_check(drawn.size() == 1, "genau eine Ziehung (%d)" % drawn.size())
	_check(game.use_item(1, int(item.n), now + 1.5).is_empty(), "fremdes Item nicht nutzbar")
	_check(not game.use_item(0, int(item.n), now + 1.5).is_empty(), "eigenes Item genutzt")
	_check(game.use_item(0, int(item.n), now + 1.6).is_empty(), "Item nicht zweimal")
	# Bis ins Ziel: Mensch 0 fährt, Mensch 1 verliert die Verbindung → nach grace fährt die KI.
	game.disconnect_seat(1, now + 2.0)
	var t: float = now + 2.0
	var ci: int = 2
	while game.phase == "racing" and t < 200.0:
		t += 0.25
		if ci < 4 and t - 13.0 >= 1.2 * float(ci + 2):
			game.claim_checkpoint(0, 0, ci, t - 13.0, t)
			ci += 1
		game.tick(t)
	_check(game.phase == "done", "Rennen fertig (Zeit %.1f)" % t)
	_check(game.seats[1].kind == "ai", "KI hat verwaisten Platz übernommen")
	var kinds: Array = []
	for event in game.events:
		kinds.append(event.kind)
	_check(kinds.count("result") == 1, "genau ein Ergebnis")
	_check(kinds.count("finish") == 4, "vier Zieleinläufe")
	_check(kinds.count("takeover") == 1 and kinds.count("away") == 1, "Abwesend + Übernahme")
	var last: Dictionary = game.events[-1]
	var places: Array = []
	for row in last.standings:
		places.append(int(row.place))
	_check(places == [1, 2, 3, 4], "Plätze 1–4")
	var ids := {}
	for event in game.events:
		ids[event.eid] = true
	_check(ids.size() == game.events.size(), "Ereignis-Kennungen eindeutig")


func _test_interpolator() -> void:
	# Sender 20 m/s, 15 Hz; Laufzeit 30–180 ms zufällig, 10 % Verlust; Empfänger-Bilder
	# zwischen 1/60 und 1/8 s (simulierte Last). Alles in simulierter Zeit.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var interp: RefCounted = INTERP.new()
	var in_flight: Array = []
	var local: float = 0.0
	var next_send: float = 0.0
	var speeds: Array[float] = []
	var last_p := Vector3.INF
	var last_local: float = 0.0
	var worst_error: float = 0.0
	while local < 40.0:
		var dt: float = 1.0 / 60.0 if rng.randf() < 0.8 else rng.randf_range(0.03, 0.125)
		local += dt
		# Sender-Uhr = lokale Uhr − 7 s (unbekannter Versatz); Pause 2 s bei 25–27 s.
		var sender: float = local - 7.0
		while next_send <= sender:
			if not (next_send > 18.0 and next_send < 20.0) and rng.randf() > 0.1:
				in_flight.append([local + rng.randf_range(0.03, 0.18), next_send])
			next_send += 1.0 / 15.0
		var keep: Array = []
		for packet in in_flight:
			if float(packet[0]) <= local:
				var k: float = float(packet[1])
				interp.push(k, local, Vector3(k * 20.0, 0, 0), 0.0, 20.0)
			else:
				keep.append(packet)
		in_flight = keep
		var shown: Dictionary = interp.sample(local)
		if shown.is_empty():
			continue
		if not bool(shown.extrapolated) and float(shown.smoothing) == 0.0:
			worst_error = maxf(worst_error, absf((shown.p as Vector3).x - float(shown.k) * 20.0))
		if last_p == Vector3.INF:
			last_p = shown.p
			last_local = local
		elif local - last_local >= 0.1:
			speeds.append((shown.p as Vector3).distance_to(last_p) / (local - last_local))
			last_p = shown.p
			last_local = local
	speeds.sort()
	var p95: float = speeds[int(speeds.size() * 0.95)]
	print(
		(
			"[LumoNet] Glättung: 95 %% ≤ %.1f m/s, max %.1f m/s, Neueinrasten %d, Fehler %.3f m"
			% [p95, speeds[-1], interp.relocks, worst_error]
		)
	)
	_check(p95 <= 23.0, "flüssig: 95 %% der Fenster ≤ 1,15 × Tempo (%.2f)" % p95)
	_check(speeds[-1] < 50.0, "kein Sprung über 2,5 × Tempo (%.1f)" % speeds[-1])
	_check(interp.relocks <= 1, "höchstens ein Neueinrasten nach 2-s-Pause (%d)" % interp.relocks)
	_check(worst_error < 0.01, "auf der echten Linie (%.4f m)" % worst_error)


func _test_ledger() -> void:
	var path: String = "user://lumo_net_ledger_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var book: RefCounted = LEDGER.new(path)
	_check(book.book("r1_5") and not book.book("r1_5"), "Buchung genau einmal")
	_check(not book.book(""), "leere Kennung nie")
	_check(LEDGER.new(path).has("r1_5"), "Buchung übersteht Neustart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_room_full() -> void:
	var hub: RefCounted = TRANSPORT.MemoryHub.new()
	var make := func() -> RefCounted: return TRANSPORT.MemoryTransport.new(hub)
	var host: Node = SESSION.new()
	root.add_child(host)
	host.auto_poll = false
	host.host_room({"ps": "Kluger Luchs 4"}, {}, 9000, make)
	var guests: Array = []
	for i in range(4):
		var guest: Node = SESSION.new()
		root.add_child(guest)
		guest.auto_poll = false
		guest.join_room("mem", {"ps": "Froher Otter %d" % (i + 1)}, 9000, make)
		guests.append(guest)
	for i in range(60):
		hub.step += 1
		host.poll(STEP)
		for guest in guests:
			guest.poll(STEP)
	# Wer zuerst ankommt, sitzt (Laufzeiten zittern): genau drei Gäste, einer abgewiesen.
	var seated: int = 0
	var refused: int = 0
	var names: Array = []
	for guest in guests:
		if guest.state == "lobby" and guest.my_seat > 0:
			seated += 1
		elif guest.state == "closed":
			refused += 1
	for seat in host.seats:
		names.append(str(seat.ps))
	_check(seated == 3, "drei Gäste sitzen (%d)" % seated)
	_check(refused == 1, "fünfter Spieler: Raum voll (%d abgewiesen)" % refused)
	var otters: int = 0
	for name in names:
		otters += 1 if str(name).begins_with("Froher Otter ") else 0
	_check(names.has("Kluger Luchs 4") and otters == 3, "Pseudonyme in der Liste")
	for node in [host] + guests:
		node.close("")
		node.queue_free()


## Autorität + 2 Gäste + 1 KI über ein Netz mit Verzögerung, Zittern, 10 % Verlust (unzuverl.).
func _test_session_race() -> void:
	var hub: RefCounted = TRANSPORT.MemoryHub.new()
	hub.loss = 0.1
	hub.rng.seed = 21
	var make := func() -> RefCounted: return TRANSPORT.MemoryTransport.new(hub)
	var catalog: Script = load("res://scripts/games/kart_items/kart_item_catalog.gd")
	var draws: Array = [0]
	var draw_rng := RandomNumberGenerator.new()
	draw_rng.seed = 99
	var host: Node = SESSION.new()
	root.add_child(host)
	host.auto_poll = false
	var config := {
		"laps": 2,
		"cps": 8,
		"zones": 3,
		"min_gap": 0.8,
		"countdown": 1.0,
		"ai_cp_seconds": [1.25, 1.25, 1.25, 1.3]
	}
	_check(host.host_room({"ps": "Starker Dachs 5", "drv": "fox"}, config, 9100, make), "Raum")
	# Echte Ziehung des Karts (kart_item_catalog.roll), genau einmal je Annahme.
	host.match_state.drawer = func(_seat: int, place: int, _progress: float) -> String:
		draws[0] += 1
		return catalog.roll(place, draw_rng, 0.0)
	host.pose_provider = func(seat: int, rt: float) -> Array:
		var x: float = clampf(rt, 0.0, 99.0) * 6.4
		return [x, 0.0, float(seat), 0.0, 6.4]
	var guests: Array = []
	for i in range(2):
		var guest: Node = SESSION.new()
		root.add_child(guest)
		guest.auto_poll = false
		guest.grace = 20.0
		guest.join_room("mem", {"ps": "Mutiger Biber %d" % (i + 1), "drv": "otter"}, 9100, make)
		guests.append(guest)
	var all: Array = [host] + guests
	var logs: Array = [[], [], []]
	var confirmed: Array = [[], [], []]
	for i in range(3):
		var index: int = i
		all[i].game_event.connect(func(ev: Dictionary): logs[index].append(ev))
		all[i].result_confirmed.connect(
			func(eid: String, place: int, _t: float): confirmed[index].append([eid, place])
		)
	_steps(all, hub, 60)
	_check(host.seats[1].kind == "human" and host.seats[2].kind == "human", "zwei Gäste im Raum")
	_check(host.start_race(), "Autorität startet")
	_check(host.seats[3].kind == "ai", "KI auf Platz 4")
	# Fahrmodell: Platz s fährt (20 + s) m/s; Checkpoints alle LAP/8, Zonen bei (z+0.5)·LAP/3.
	var progress: Array = [0.0, 0.0, 0.0]
	var next_cp: Array = [0, 0, 0]
	var next_zone: Array = [0, 0, 0]
	var held: Array = [0, 0, 0]
	var held_since: Array = [0.0, 0.0, 0.0]
	var vanished: bool = false
	var seat_before: int = -1
	var reconnected_at: int = -1
	var forged_sent: bool = false
	var smooth: Array[float] = []
	var last_seen := Vector3.INF
	var last_seen_clock: float = 0.0
	for step in range(60 * 60):
		hub.step += 1
		for i in range(3):
			var session: Node = all[i]
			if session.state not in ["racing", "done"]:
				session.poll(STEP)
				continue
			var rt: float = session.race_time()
			var seat: int = session.my_seat
			if rt > 0.0 and next_cp[i] < 16:
				progress[i] = rt * (20.0 + seat)
			var pos := Vector3(progress[i], 0.0, float(seat))
			session.update_own(pos, 0.0, 20.0 + seat)
			var segment: float = LAP / 8.0
			# Auch ohne Netz fährt das Kind weiter; Durchfahrt mit der Zeit an der Linie.
			while next_cp[i] < 16 and progress[i] >= segment * float(next_cp[i] + 1):
				var at: float = segment * float(next_cp[i] + 1) / (20.0 + seat)
				session.claim_checkpoint(next_cp[i] / 8, next_cp[i] % 8, at)
				next_cp[i] += 1
			var lap: int = int(progress[i] / LAP)
			var zone_at: float = lap * LAP + (float(next_zone[i] % 3) + 0.5) * LAP / 3.0
			if next_zone[i] < 6 and next_zone[i] / 3 == lap and progress[i] >= zone_at:
				session.pick_item("%d:%d" % [lap, next_zone[i] % 3])
				next_zone[i] += 1
			if held[i] > 0 and rt - float(held_since[i]) > 1.0:
				session.use_item(held[i])
				held[i] = 0
			for ev in logs[i]:
				if ev.kind == "item" and int(ev.seat) == seat and int(ev.n) > held[i]:
					held[i] = int(ev.n)
					held_since[i] = rt
				elif ev.kind == "use" and int(ev.e) == held[i]:
					held[i] = 0
			session.poll(STEP)
		# Glättung auf Gast 2: Fahrer auf Platz 0 (Autorität).
		var shown: Dictionary = guests[1].pose_of(0)
		if not shown.is_empty() and host.race_time() > 0.5:
			if last_seen == Vector3.INF:
				last_seen = shown.p
				last_seen_clock = guests[1].clock
			elif guests[1].clock - last_seen_clock >= 0.1:
				smooth.append(
					(
						(shown.p as Vector3).distance_to(last_seen)
						/ (guests[1].clock - last_seen_clock)
					)
				)
				last_seen = shown.p
				last_seen_clock = guests[1].clock
		# Fälschungen von Gast 2: fremder Platz bewegt, Ergebnis gemeldet, Checkpoint übersprungen.
		if not forged_sent and host.race_time() > 3.0:
			forged_sent = true
			var transport: RefCounted = guests[1].transport
			var fake_result := {
				"t": "ev",
				"n": 999,
				"kind": "result",
				"eid": "fake_1",
				"seat": -1,
				"standings": [{"seat": 2, "place": 1, "time": 1.0}]
			}
			transport.send(1, WIRE.encode(fake_result), true)
			transport.send(1, WIRE.encode({"t": "pose", "s": [0, 3.0, 999, 0, 0, 0, 0]}), false)
			transport.send(1, WIRE.encode({"t": "cp", "lap": 1, "i": 7, "k": 3.0}), true)
		# Gast 1 verliert bei Rennzeit 6 s das Netz (ohne Abmeldung) für 2 s, verbindet neu.
		if not vanished and reconnected_at < 0 and host.race_time() > 6.0:
			vanished = true
			seat_before = guests[0].my_seat
			guests[0].transport.vanish()
			hub.listening[9100].links.erase(guests[0].transport.my_id)
		elif vanished and host.race_time() > 8.0:
			vanished = false
			reconnected_at = step
		if host.state == "done" and guests[0].state == "done" and guests[1].state == "done":
			break
	_steps(all, hub, 30)
	print(
		(
			"[LumoNet] Rennen: Ereignisse %d/%d/%d, Ziehungen %d, Abgelehnt %s, Wiederverbunden %d"
			% [
				logs[0].size(),
				logs[1].size(),
				logs[2].size(),
				draws[0],
				str(host.match_state.rejects),
				guests[0].reconnects
			]
		)
	)
	_check(host.state == "done", "Autorität: Ergebnis (%s)" % host.state)
	_check(guests[0].state == "done" and guests[1].state == "done", "Gäste: Ergebnis")
	_check(guests[0].reconnects == 1, "Gast 1 wiederverbunden (%d)" % guests[0].reconnects)
	_check(
		seat_before > 0 and guests[0].my_seat == seat_before, "derselbe Platz nach Wiederverbinden"
	)
	var ids: Array = []
	for log in logs:
		var list: Array = []
		for ev in log:
			list.append("%s:%s:%s" % [ev.eid, ev.kind, ev.get("item", "")])
		ids.append(list)
	_check(ids[0] == ids[1] and ids[0] == ids[2], "alle drei sehen dieselben Ereignisse")
	var items: int = 0
	var finishes: int = 0
	for ev in logs[0]:
		items += 1 if ev.kind == "item" else 0
		finishes += 1 if ev.kind == "finish" else 0
	_check(items == draws[0] and items >= 9, "jede Ziehung genau ein Item-Ereignis (%d)" % items)
	_check(finishes == 4, "vier Zieleinläufe (3 Menschen + KI)")
	_check(
		int(host.match_state.rejects.get("order", 0)) >= 1, "übersprungener Checkpoint verworfen"
	)
	var fake_seen: bool = false
	for log in logs:
		for ev in log:
			fake_seen = fake_seen or str(ev.eid) == "fake_1"
	_check(not fake_seen, "gefälschtes Ergebnis nirgends angekommen")
	_check(not host._poses.has(0), "fremder Platz nicht bewegt")
	for i in range(3):
		_check(
			confirmed[i].size() == 1, "Gerät %d bucht genau einmal (%d)" % [i, confirmed[i].size()]
		)
	# Erneutes Ergebnis (wie nach Wiederverbinden nachgeschickt) bucht nichts.
	var result: Dictionary = logs[1][-1]
	guests[0].last_event = 0
	guests[0]._apply_event(result)
	_check(confirmed[1].size() == 1, "nachgeschicktes Ergebnis nicht doppelt gebucht")
	smooth.sort()
	if not smooth.is_empty():
		var p95: float = smooth[int(smooth.size() * 0.95)]
		print("[LumoNet] Gast sieht Autorität: 95 %% ≤ %.1f m/s (echt 20)" % p95)
		_check(p95 <= 22.5, "Autorität auf Gast flüssig (%.1f)" % p95)
	for node in all:
		node.close("")
		node.queue_free()


func _steps(all: Array, hub: RefCounted, count: int) -> void:
	for i in range(count):
		hub.step += 1
		for node in all:
			node.poll(STEP)
