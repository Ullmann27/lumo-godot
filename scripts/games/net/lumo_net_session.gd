extends Node
## Privater Spielraum der LUMO-Netzbasis (2–4 Plätze, KI füllt freie Plätze).
##
## Eine Rolle je Gerät:
##  - Autorität (im WLAN: das Gerät, das den Raum öffnet; später ein Server): führt den
##    Spielstand (`lumo_net_match.gd`), prüft jede Meldung, zieht Items, bucht Checkpoints,
##    Zieleinlauf und Ergebnis und verteilt Ereignisse mit fortlaufender Nummer.
##  - Gast: schickt nur eigene Fahrdaten und Wünsche (Checkpoint, Prisma, Item-Einsatz) und
##    nimmt Ereignisse ausschließlich von der Autorität an. Ein Gast kann kein Ergebnis melden.
##
## Wiederverbinden: Jeder Platz hat eine zufällige Platzkarte (Sitzung, kein Profil). Reißt die
## Verbindung, versucht der Gast es `grace` Sekunden lang erneut; die Autorität hält den Platz
## frei und schickt nach der Rückkehr alle verpassten Ereignisse nach. Danach fährt die KI.
##
## Alle Zeiten laufen über `poll(delta)`; Tests können feste Schritte geben.

signal state_changed(state: String, text: String)
signal roster_changed(seats: Array)
signal race_started(room: Dictionary, t0: float)
signal game_event(event: Dictionary)
## Genau einmal je Ergebnis-Kennung für den eigenen Platz (hier bucht das Spiel die Belohnung).
signal result_confirmed(eid: String, place: int, time: float)

const WIRE = preload("res://scripts/games/net/lumo_net_wire.gd")
const MATCH = preload("res://scripts/games/net/lumo_net_match.gd")
const INTERP = preload("res://scripts/games/net/lumo_net_interpolator.gd")
const TRANSPORT = preload("res://scripts/games/net/lumo_net_transport.gd")
const LEDGER = preload("res://scripts/games/net/lumo_net_ledger.gd")

const PORT: int = 47631
const SNAP_HZ: float = 15.0
const PING_S: float = 0.5
const GUEST_QUIET_S: float = 6.0
const RETRY_S: float = 1.0

var role: String = ""  # "authority" | "guest"
## idle | connecting | lobby | racing | done | reconnecting | closed
var state: String = "idle"
var my_seat: int = -1
var token: String = ""
var room: Dictionary = {}
var t0: float = 0.0
var seats: Array = []
var match_state: RefCounted
var clock: float = 0.0
var me: Dictionary = {}
var ledger: RefCounted = LEDGER.new()
## Autorität: Callable(seat: int, race_time: float) -> [x, y, z, gier, tempo] für KI-Plätze.
var pose_provider: Callable
## Gast: wie lange nach einem Abbruch neu verbunden wird (danach übernimmt die KI).
var grace: float = 20.0
## false: der Aufrufer ruft poll(delta) selbst (Tests mit festen Schritten). Hinweis: Godot
## schaltet _process beim Eintritt in den Baum wieder ein, set_process(false) reicht nicht.
var auto_poll: bool = true
var last_event: int = 0
var reconnects: int = 0
var transport: RefCounted
var _make_transport: Callable
var _address: String = ""
var _port: int = PORT
var _clock_offset: float = 0.0
var _pings: Array = []  # [[rtt, offset]]
var _interp: Dictionary = {}
var _own_pose: Array = []
var _poses: Dictionary = {}
var _peer_seat: Dictionary = {}
var _quiet: Dictionary = {}
var _snap_clock: float = 0.0
var _ping_clock: float = 0.0
var _retry_clock: float = 0.0
var _lost_at: float = -1.0
var _roster_key: String = ""
var _joined_sent: bool = false
## Gast: Wünsche (Checkpoint, Prisma, Item), die noch kein Ereignis bestätigt hat. Nach einem
## Wiederverbinden werden sie erneut geschickt (Doppeltes verwirft die Autorität).
var _unconfirmed: Array = []
var _last_heard: Dictionary = {}


## Autorität: Raum öffnen. `config` siehe lumo_net_match.gd; `info` = {ps, drv, kart}.
## `info` leer ({}) = Autorität ohne eigenen Platz (späterer Server); dann bis zu 4 Gäste.
func host_room(
	info: Dictionary, config: Dictionary, port: int = PORT, make_transport: Callable = Callable()
) -> bool:
	close("")
	_make_transport = make_transport
	transport = _new_transport()
	if not transport.listen(port, WIRE.MAX_SEATS - (0 if info.is_empty() else 1)):
		transport = null
		_set_state("closed", "Der Raum konnte nicht geöffnet werden. Bitte noch einmal versuchen.")
		return false
	role = "authority"
	_port = port
	match_state = MATCH.new(config)
	my_seat = -1
	if not info.is_empty():
		me = _clean_me(info)
		var joined: Dictionary = match_state.join(me, "", clock)
		my_seat = int(joined.seat)
		token = str(joined.tok)
	room = match_state.room()
	seats = match_state.roster()
	_set_state("lobby", "Raum offen. Warte auf Mitspieler …")
	_broadcast_roster_if_changed()
	return true


## Gast: Raum betreten (im WLAN Adresse aus dem Raumcode; Test: 127.0.0.1).
func join_room(
	address: String,
	info: Dictionary,
	port: int = PORT,
	make_transport: Callable = Callable(),
	resume_token: String = "",
	resume_last: int = 0
) -> bool:
	close("")
	_make_transport = make_transport
	role = "guest"
	me = _clean_me(info)
	token = resume_token
	last_event = resume_last
	_address = address
	_port = port
	if not _connect():
		_set_state("closed", "Verbindung nicht möglich. Seid ihr im selben WLAN?")
		return false
	_set_state("connecting", "Verbinde …")
	return true


func start_race() -> bool:
	if role != "authority" or state != "lobby":
		return false
	if not match_state.start(clock):
		return false
	t0 = match_state.t0
	room = match_state.room()
	_broadcast({"t": "start", "room": room, "t0": t0}, true)
	_broadcast_roster_if_changed()
	_set_state("racing", "Los geht's!")
	race_started.emit(room, t0)
	return true


## Uhr der Autorität (Gast: geschätzt über Ping/Pong mit kleinster Laufzeit).
func host_clock() -> float:
	return clock + (_clock_offset if role == "guest" else 0.0)


func race_time() -> float:
	return host_clock() - t0


## Eigene Fahrdaten (jedes Bild aufrufen; gesendet wird 15-mal pro Sekunde).
func update_own(position: Vector3, yaw: float, speed: float) -> void:
	_own_pose = [my_seat, race_time(), position.x, position.y, position.z, yaw, speed]


## Durchfahrt melden. `at` = Rennzeit der Durchfahrt (genau an der Linie); NAN = jetzt.
func claim_checkpoint(lap: int, index: int, at: float = NAN) -> void:
	var k: float = race_time() if is_nan(at) else at
	if role == "authority":
		match_state.claim_checkpoint(my_seat, lap, index, k, clock)
	else:
		_request({"t": "cp", "lap": lap, "i": index, "k": k})


func pick_item(zone: String) -> void:
	if role == "authority":
		match_state.pick_item(my_seat, zone, clock)
	else:
		_request({"t": "pick", "z": zone})


func use_item(item_event: int) -> void:
	if role == "authority":
		match_state.use_item(my_seat, item_event, clock)
	else:
		_request({"t": "use", "e": item_event})


func _request(message: Dictionary) -> void:
	_unconfirmed.append([clock, message])
	while _unconfirmed.size() > 64:
		_unconfirmed.pop_front()
	if state in ["lobby", "racing", "done"]:
		_send(message, true)


## Ein Ereignis der Autorität bestätigt einen offenen Wunsch des eigenen Platzes.
func _confirm(ev: Dictionary) -> void:
	if int(ev.seat) != my_seat:
		return
	var keep: Array = []
	for entry in _unconfirmed:
		var m: Dictionary = entry[1]
		var done: bool = (
			(
				ev.kind == "cp"
				and m.t == "cp"
				and int(m.lap) == int(ev.lap)
				and int(m.i) == int(ev.i)
			)
			or (ev.kind == "item" and m.t == "pick" and str(m.z) == str(ev.get("z", "")))
			or (ev.kind == "use" and m.t == "use" and int(m.e) == int(ev.get("e", -1)))
		)
		if not done and clock - float(entry[0]) < grace + 10.0:
			keep.append(entry)
	_unconfirmed = keep


## Geglätteter Zustand eines anderen Platzes ({} wenn unbekannt).
func pose_of(seat: int) -> Dictionary:
	if seat == my_seat:
		return {}
	if role == "authority" and _seat_kind(seat) == "ai" and pose_provider.is_valid():
		var raw: Array = pose_provider.call(seat, race_time())
		return {"k": race_time(), "p": Vector3(raw[0], raw[1], raw[2]), "yaw": raw[3], "v": raw[4]}
	var interp: RefCounted = _interp.get(seat)
	return interp.sample(clock) if interp != null else {}


func interpolator(seat: int) -> RefCounted:
	return _interp.get(seat)


func leave() -> void:
	if transport != null:
		if role == "authority":
			_broadcast({"t": "bye"}, true)
		else:
			_send({"t": "bye"}, true)
		transport.poll()
	close("Du hast den Raum verlassen.")


func close(text: String = "Verbindung beendet.") -> void:
	if transport != null:
		transport.close()
	transport = null
	_interp.clear()
	_peer_seat.clear()
	_quiet.clear()
	_poses.clear()
	_lost_at = -1.0
	if not text.is_empty():
		_set_state("closed", text)
	else:
		state = "idle"


func _process(delta: float) -> void:
	if auto_poll:
		poll(delta)


func poll(delta: float) -> void:
	clock += delta
	if role == "guest" and state == "reconnecting":
		_try_reconnect(delta)
	if transport == null:
		return
	for event in transport.poll():
		match str(event.type):
			"connect":
				_on_connect(int(event.peer))
			"disconnect":
				_on_disconnect(int(event.peer))
			"data":
				_on_data(int(event.peer), event.data)
		if transport == null:
			return
	if role == "authority":
		_authority_step(delta)
	else:
		_guest_step(delta)


func _authority_step(delta: float) -> void:
	# Stille nur in Bildern zählen, in denen wir selbst zugehört haben (Ladebild ≠ Abbruch).
	for peer in _quiet.keys():
		_quiet[peer] = float(_quiet[peer]) + minf(delta, 0.25)
		if float(_quiet[peer]) > GUEST_QUIET_S:
			transport.kick(int(peer))
			_on_disconnect(int(peer))
	match_state.tick(clock)
	_flush_events()
	_broadcast_roster_if_changed()
	if state not in ["racing", "done"]:
		return
	_snap_clock += delta
	if _snap_clock < 1.0 / SNAP_HZ:
		return
	_snap_clock = 0.0
	var list: Array = []
	if not _own_pose.is_empty():
		list.append(_own_pose)  # Zeitstempel bleibt der der Position (nicht der Sendezeit)
	for seat in range(seats.size()):
		if seat == my_seat:
			continue
		if _seat_kind(seat) == "ai" and pose_provider.is_valid():
			var raw: Array = pose_provider.call(seat, race_time())
			list.append([seat, race_time(), raw[0], raw[1], raw[2], raw[3], raw[4]])
		elif _poses.has(seat):
			list.append(_poses[seat])
	_broadcast({"t": "snap", "s": list}, false)


func _guest_step(delta: float) -> void:
	_ping_clock += delta
	if _ping_clock >= PING_S and state != "connecting":
		_ping_clock = 0.0
		_send({"t": "ping", "c": clock}, false)
	var quiet: float = float(_quiet.get(TRANSPORT.AUTHORITY_PEER, 0.0)) + minf(delta, 0.25)
	_quiet[TRANSPORT.AUTHORITY_PEER] = quiet
	if quiet > GUEST_QUIET_S:
		_lose_connection()
		return
	if state in ["racing", "done"] and not _own_pose.is_empty():
		_snap_clock += delta
		if _snap_clock >= 1.0 / SNAP_HZ:
			_snap_clock = 0.0
			_send({"t": "pose", "s": _own_pose}, false)


func _on_connect(peer: int) -> void:
	_quiet[peer] = 0.0
	if role == "guest":
		_send(
			{
				"t": "join",
				"v": WIRE.PROTOCOL,
				"ps": me.ps,
				"drv": me.drv,
				"kart": me.kart,
				"tok": token,
				"last": last_event
			},
			true
		)
		_joined_sent = true


func _on_disconnect(peer: int) -> void:
	_quiet.erase(peer)
	if role == "authority":
		if _peer_seat.has(peer):
			match_state.disconnect_seat(
				int(_peer_seat[peer]), clock, float(_last_heard.get(peer, clock))
			)
			_peer_seat.erase(peer)
	else:
		_lose_connection()


func _on_data(peer: int, data: PackedByteArray) -> void:
	var message: Dictionary = WIRE.decode(data, role == "guest")
	if message.is_empty():
		return
	if role == "guest" and peer != TRANSPORT.AUTHORITY_PEER:
		return
	_quiet[peer] = 0.0
	_last_heard[peer] = clock
	if role == "authority":
		_authority_message(peer, message)
	else:
		_guest_message(message)


func _authority_message(peer: int, m: Dictionary) -> void:
	var kind: String = str(m.t)
	if kind == "join":
		_authority_join(peer, m)
		return
	if kind == "ping":
		_send_to(peer, {"t": "pong", "c": m.c, "h": clock}, false)
		return
	if not _peer_seat.has(peer):
		return  # ohne Platz zählt nichts
	var seat: int = int(_peer_seat[peer])
	match kind:
		"pose":
			# Nur die eigenen Fahrdaten: ein Gast kann keinen fremden Platz bewegen.
			if int(m.s[0]) != seat:
				return
			var pose: Array = m.s
			if _poses.has(seat) and float(pose[1]) <= float(_poses[seat][1]):
				return
			_poses[seat] = pose
			_push_pose(pose)
		"cp":
			match_state.claim_checkpoint(seat, int(m.lap), int(m.i), float(m.k), clock)
		"pick":
			match_state.pick_item(seat, str(m.z), clock)
		"use":
			match_state.use_item(seat, int(m.e), clock)
		"bye":
			match_state.disconnect_seat(seat, clock)
			_peer_seat.erase(peer)
			_quiet.erase(peer)
	_flush_events()


func _authority_join(peer: int, m: Dictionary) -> void:
	if _peer_seat.has(peer):
		return
	if m.has("bad_protocol"):
		_send_to(peer, {"t": "reject", "why": "protocol"}, true)
		return
	var result: Dictionary = match_state.join(m, str(m.tok), clock)
	if not bool(result.ok):
		_send_to(peer, {"t": "reject", "why": result.why}, true)
		return
	var seat: int = int(result.seat)
	# Platzkarte wird noch von einer alten (halb toten) Verbindung gehalten → die alte geht.
	for other in _peer_seat.keys():
		if int(_peer_seat[other]) == seat:
			_peer_seat.erase(other)
			_quiet.erase(other)
			transport.kick(int(other))
	_peer_seat[peer] = seat
	_send_to(
		peer,
		{
			"t": "welcome",
			"seat": seat,
			"tok": result.tok,
			"seats": match_state.roster(),
			"room": match_state.room(),
			"h": clock
		},
		true
	)
	if match_state.phase != "lobby":
		_send_to(peer, {"t": "start", "room": match_state.room(), "t0": match_state.t0}, true)
		# Verpasstes nachschicken (der Gast verwirft schon Bekanntes über die Nummer).
		for event in match_state.events_after(int(m.last)):
			_send_to(peer, _event_message(event), true)
	_broadcast_roster_if_changed()


func _guest_message(m: Dictionary) -> void:
	match str(m.t):
		"welcome":
			my_seat = int(m.seat)
			token = str(m.tok)
			room = m.room
			seats = m.seats
			_clock_offset = float(m.h) - clock
			_pings.clear()
			if _lost_at >= 0.0:
				reconnects += 1
			_lost_at = -1.0
			_set_state("lobby", "Du bist im Raum.")
			roster_changed.emit(seats)
			for entry in _unconfirmed:
				_send(entry[1], true)
		"reject":
			var texts := {
				"full": "Der Raum ist schon voll (4 Plätze).",
				"started": "Das Rennen hat schon begonnen.",
				"token": "Dein Platz ist nicht mehr frei – die KI fährt für dich zu Ende.",
				"protocol": "Bitte beide Geräte auf denselben Lumo-Stand bringen.",
			}
			var why: String = str(m.why)
			close(str(texts.get(why, "Der Raum ist geschlossen.")))
		"roster":
			seats = m.seats
			roster_changed.emit(seats)
		"start":
			room = m.room
			t0 = float(m.t0)
			if state != "racing":
				_set_state("racing", "Los geht's!")
				race_started.emit(room, t0)
		"snap":
			for pose in m.s:
				if int(pose[0]) != my_seat:
					_push_pose(pose)
		"pong":
			var rtt: float = clock - float(m.c)
			if rtt < 0.0 or rtt > 5.0:
				return
			_pings.append([rtt, float(m.h) + rtt * 0.5 - clock])
			while _pings.size() > 12:
				_pings.pop_front()
			var best: Array = _pings[0]
			for sample in _pings:
				if float(sample[0]) < float(best[0]):
					best = sample
			_clock_offset = float(best[1])
		"ev":
			_apply_event(m)
		"bye":
			close("Der Raum wurde geschlossen.")


func _push_pose(pose: Array) -> void:
	var seat: int = int(pose[0])
	if not _interp.has(seat):
		_interp[seat] = INTERP.new()
	_interp[seat].push(
		float(pose[1]), clock, Vector3(pose[2], pose[3], pose[4]), float(pose[5]), float(pose[6])
	)


func _flush_events() -> void:
	if match_state == null:
		return
	for event in match_state.take_new():
		var message: Dictionary = _event_message(event)
		_broadcast(message, true)
		# Auch die Autorität nimmt ihre Ereignisse über denselben Prüfweg an.
		_apply_event(WIRE.decode(WIRE.encode(message), true))


func _apply_event(m: Dictionary) -> void:
	if m.is_empty() or int(m.n) <= last_event:
		return  # schon bekannt (Nachholen nach Wiederverbinden)
	last_event = int(m.n)
	if role == "guest":
		_confirm(m)
	game_event.emit(m)
	if str(m.kind) == "result":
		_set_state("done", "Ziel!")
		for row in m.get("standings", []):
			if int(row.seat) == my_seat and ledger.book(str(m.eid)):
				result_confirmed.emit(str(m.eid), int(row.place), float(row.time))


static func _event_message(event: Dictionary) -> Dictionary:
	var out: Dictionary = event.duplicate(true)
	out["t"] = "ev"
	return out


func _broadcast_roster_if_changed() -> void:
	if match_state == null:
		return
	var roster: Array = match_state.roster()
	var key: String = JSON.stringify(roster)
	if key == _roster_key:
		return
	_roster_key = key
	seats = roster
	_broadcast({"t": "roster", "seats": roster}, true)
	roster_changed.emit(seats)


func _lose_connection() -> void:
	if transport != null:
		transport.close()
	transport = null
	_quiet.clear()
	if state in ["lobby", "racing", "done"] and not token.is_empty():
		_lost_at = clock
		_retry_clock = RETRY_S
		_set_state("reconnecting", "Verbindung weg – ich versuche es weiter …")
	elif state != "reconnecting":
		close("Kein Raum gefunden. Seid ihr im selben WLAN?")


func _try_reconnect(delta: float) -> void:
	if clock - _lost_at > grace:
		close("Die Verbindung ist weg. Die KI fährt für dich zu Ende.")
		return
	if transport != null:
		return
	_retry_clock += delta
	if _retry_clock < RETRY_S:
		return
	_retry_clock = 0.0
	_connect()


## Neuer Verbindungsversuch; bleibt er stumm, wird er nach GUEST_QUIET_S verworfen.
func _connect() -> bool:
	transport = _new_transport()
	if not transport.connect_to(_address, _port):
		transport = null
		return false
	_quiet[TRANSPORT.AUTHORITY_PEER] = 0.0
	return true


func _new_transport() -> RefCounted:
	if _make_transport.is_valid():
		return _make_transport.call()
	return TRANSPORT.ENetTransport.new()


func _send(message: Dictionary, reliable: bool) -> void:
	if transport != null:
		transport.send(TRANSPORT.AUTHORITY_PEER, WIRE.encode(message), reliable)


func _send_to(peer: int, message: Dictionary, reliable: bool) -> void:
	if transport != null:
		transport.send(peer, WIRE.encode(message), reliable)


func _broadcast(message: Dictionary, reliable: bool) -> void:
	if transport == null:
		return
	var data: PackedByteArray = WIRE.encode(message)
	for peer in _peer_seat.keys():
		transport.send(int(peer), data, reliable)


func _seat_kind(seat: int) -> String:
	return str(seats[seat].kind) if seat >= 0 and seat < seats.size() else "open"


func _set_state(next: String, text: String) -> void:
	state = next
	state_changed.emit(next, text)


static func _clean_me(info: Dictionary) -> Dictionary:
	return {
		"ps": WIRE.clean_pseudonym(info.get("ps")),
		"drv": WIRE.clean_id(info.get("drv"), "fox"),
		"kart": WIRE.clean_id(info.get("kart"), "comet")
	}
