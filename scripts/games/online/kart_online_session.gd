extends Node
## Internet transport for a consented two-player race. No cloud account, chat or profile data.
## The full device key never leaves this file except in the first TLS-authenticated packet.

signal status_changed(state: String, text: String)
signal invitation_received(invitation: Dictionary)
signal friends_changed
signal friend_requests_changed
signal invitation_expired(invite_id: String)
signal room_joined(room: Dictionary)
signal ready_changed(ids: Array)
signal race_prepare(track: String)
signal race_start(start_ms: int)
signal friend_finished(time: float)
signal result_received(result: Dictionary)
signal friend_left(text: String)

const PROTOCOL: int = 1
const MAX_PACKET: int = 4096
const SEND_HZ: float = 20.0
const IDENTITY_FILE: String = "user://lumo_kart_online_identity.cfg"
const FRIENDS_FILE: String = "user://lumo_kart_online_friends.cfg"
const ERROR_TEXT: Dictionary = {
	"invalid_identity": "Der Spielername passt nicht. Nutze 3–20 Buchstaben, Ziffern oder Unterstriche.",
	"invalid_username": "Bitte gib den Spielernamen deines Freundes ein.",
	"username_taken": "Dieser Spielername ist schon vergeben. Wähle einen anderen Namen.",
	"username_not_found": "Dieser Spielername wurde noch nicht angelegt. Dein Freund verbindet sich zuerst einmal mit Lumo.",
	"not_friends": "Nehmt zuerst eure Freundschaftsanfrage an.",
	"already_friends": "Ihr seid bereits Freunde.",
	"friends_full": "Die Freundeliste ist voll.",
	"friend_requests_full": "Es sind noch zu viele Freundschaftsanfragen offen.",
	"friend_request_expired": "Diese Freundschaftsanfrage ist nicht mehr offen.",
	"registration_limited": "Heute wurden gerade zu viele neue Spieler angelegt. Versuche es später erneut.",
	"registration_unavailable": "Ein neuer Spieler kann gerade nicht angelegt werden.",
	"identity_already_online": "Dieser Spieler ist bereits verbunden. Schließe zuerst die andere Verbindung.",
	"friend_offline": "Dieser Freund ist gerade nicht online. Beide öffnen zuerst Online-Rennen.",
	"friend_busy": "Dein Freund ist gerade in einem anderen Rennen.",
	"cannot_invite_self": "Das ist dein eigener Spielername.",
	"invite_pending": "Die Einladung ist schon unterwegs.",
	"invite_limit": "Warte einen Moment, bevor du wieder einlädst.",
	"invitation_expired": "Die Einladung ist abgelaufen. Lade deinen Freund noch einmal ein.",
	"already_in_room": "Verlasse zuerst den aktuellen Rennraum.",
	"course_mismatch": "Eure Strecken unterscheiden sich. Aktualisiert beide Lumo.",
	"finish_not_verified": "Das Online-Ziel konnte nicht bestätigt werden. Deine lokale Fahrt bleibt erhalten.",
	"rate_limited": "Zu viele Anfragen. Verbinde dich in einem Moment erneut.",
	"room_expired": "Der Rennraum ist abgelaufen.",
}

var state: String = "offline"
var status_text: String = "Noch nicht verbunden."
var endpoint: String = ""
var username: String = ""
var alias: String = ""
var my_id: String = ""
var friend: Dictionary = {}
var room_id: String = ""
var track: String = ""
var friend_time: float = -1.0
var friend_distance: float = 0.0
var friend_checkpoint: int = 0
var own_time: float = -1.0
var result: Dictionary = {}
var friends: Array[Dictionary] = []
var friend_requests: Array[Dictionary] = []
var registered: bool = false
var start_server_ms: int = 0
## QA can only opt into local loopback, never clear-text Internet transport.
var allow_loopback_for_tests: bool = false
var identity_path: String = IDENTITY_FILE
var friends_path: String = FRIENDS_FILE
var _key: String = ""
var _socket: WebSocketPeer
var _hello_sent: bool = false
var _connect_started_ms: int = 0
var _last_received_ms: int = 0
var _last_ping_ms: int = 0
var _server_offset_ms: float = 0.0
var _best_rtt_ms: float = INF
var _send_clock: float = 0.0
var _sequence: int = 0
var _samples: Array[Dictionary] = []
var _last_snapshot_sequence: int = -1


static func valid_alias(value: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z][A-Za-z0-9_]{2,19}$").search(value) != null


static func valid_handle(value: String) -> bool:
	return valid_alias(value)


static func id_for_key(value: String) -> String:
	if RegEx.create_from_string("^[0-9a-f]{64}$").search(value) == null:
		return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(value.hex_decode())
	return hash.finish().hex_encode()


func configure(url: String, child_key: String = "standalone") -> bool:
	endpoint = url.strip_edges()
	var scope: String = child_key.sha256_text()
	if identity_path == IDENTITY_FILE:
		identity_path = "user://lumo_kart_online_identity_" + scope + ".cfg"
	if friends_path == FRIENDS_FILE:
		friends_path = "user://lumo_kart_online_friends_" + scope + ".cfg"
	_load_friends()
	if not _load_identity():
		_set_status("offline", "Der Online-Spieler konnte auf diesem Gerät nicht gespeichert werden.")
		return false
	if endpoint.is_empty():
		_set_status("offline", "Der Online-Server ist noch nicht eingerichtet. Deine Offline-Rennen bleiben verfügbar.")
		return false
	if not _valid_endpoint(endpoint):
		_set_status("offline", "Der Online-Server braucht eine sichere WSS-Adresse.")
		return false
	return true


func _valid_endpoint(value: String) -> bool:
	if RegEx.create_from_string("^wss://[A-Za-z0-9.-]+(:[0-9]{1,5})?/ws$").search(value) != null:
		return true
	if allow_loopback_for_tests:
		return RegEx.create_from_string("^ws://(127\\.0\\.0\\.1|localhost):[0-9]{1,5}/ws$").search(value) != null
	return false


func _load_identity() -> bool:
	var config := ConfigFile.new()
	var loaded: Error = config.load(identity_path)
	if loaded == OK:
		_key = str(config.get_value("identity", "key", ""))
		alias = str(config.get_value("identity", "alias", ""))
		registered = config.get_value("identity", "registered", false) == true
		if id_for_key(_key).is_empty() or (registered and not valid_alias(alias)):
			return false
	elif loaded == ERR_FILE_NOT_FOUND:
		_key = Crypto.new().generate_random_bytes(32).hex_encode()
		my_id = id_for_key(_key)
		alias = ""
		registered = false
		if not _save_identity():
			return false
	else:
		return false
	my_id = id_for_key(_key)
	username = alias
	return not my_id.is_empty()


func _save_identity() -> bool:
	var config := ConfigFile.new()
	config.set_value("identity", "key", _key)
	config.set_value("identity", "alias", alias)
	config.set_value("identity", "registered", registered)
	var staging: String = identity_path + ".new"
	if config.save(staging) != OK:
		return false
	return DirAccess.rename_absolute(staging, identity_path) == OK


func set_alias(value: String) -> bool:
	if _socket != null or not valid_alias(value) or (registered and value != alias):
		return false
	var previous: String = alias
	alias = value
	if not _save_identity():
		alias = previous
		return false
	username = alias
	return true


func _load_friends() -> void:
	friends.clear()
	var config := ConfigFile.new()
	if config.load(friends_path) != OK:
		return
	var saved: Variant = config.get_value("friends", "entries", [])
	if saved is Array:
		for item in saved:
			if item is Dictionary and valid_alias(str(item.get("username", ""))) and str(item.get("uid", "")).length() == 64:
				if friends.size() < 64:
					friends.append({"uid": str(item.uid), "username": str(item.username), "online": false})


func _save_friends() -> void:
	var config := ConfigFile.new()
	var cache: Array[Dictionary] = []
	for entry in friends:
		cache.append({"uid": str(entry.uid), "username": str(entry.username)})
	config.set_value("friends", "entries", cache)
	if config.save(friends_path + ".new") == OK:
		DirAccess.rename_absolute(friends_path + ".new", friends_path)


func request_friend(value: String) -> void:
	if state not in ["online", "inviting"] or not valid_alias(value):
		_set_status(state, "Gib den festen Spielernamen deines Freundes ein.")
		return
	_send({"t": "friend_request", "username": value})


func accept_friend(request_id: String) -> void:
	_send({"t": "friend_accept", "request": request_id})


func decline_friend(request_id: String) -> void:
	_send({"t": "friend_decline", "request": request_id})


func forget_friend(uid: String) -> void:
	_send({"t": "friend_remove", "id": uid})


func connect_online() -> bool:
	if not _valid_endpoint(endpoint) or my_id.is_empty() or not valid_alias(alias):
		_set_status("offline", "Online ist noch nicht eingerichtet.")
		return false
	disconnect_online("")
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = 32768
	_socket.outbound_buffer_size = 16384
	_hello_sent = false
	_connect_started_ms = Time.get_ticks_msec()
	_last_received_ms = _connect_started_ms
	_last_ping_ms = 0
	_best_rtt_ms = INF
	var error: Error = _socket.connect_to_url(endpoint)
	if error != OK:
		_socket = null
		_set_status("offline", "Der Online-Server ist nicht erreichbar. Versuche es später erneut.")
		return false
	_set_status("connecting", "Verbinde … Ein ruhender Server braucht beim ersten Start etwas länger.")
	return true


func disconnect_online(message: String = "Verbindung beendet.") -> void:
	if _socket != null:
		if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_send({"t": "leave"})
		_socket.close(1000, "player left")
	_socket = null
	for entry in friends:
		entry.online = false
	_clear_room()
	if not message.is_empty():
		_set_status("offline", message)
	else:
		state = "offline"


func leave_room() -> void:
	_send({"t": "leave"})
	_clear_room()
	_set_status("online", "Du bist online. Lade einen Freund ein.")


func _clear_room() -> void:
	room_id = ""
	friend = {}
	track = ""
	friend_time = -1.0
	friend_distance = 0.0
	friend_checkpoint = 0
	own_time = -1.0
	result = {}
	start_server_ms = 0
	_samples.clear()
	_last_snapshot_sequence = -1
	_send_clock = 0.0
	_sequence = 0


func invite(uid: String, selected_track: String, info: Dictionary) -> void:
	if state not in ["online", "inviting"] or uid.length() != 64:
		_set_status(state, "Wähle einen verbundenen Freund aus deiner Liste.")
		return
	_send({"t": "invite", "to": uid, "track": selected_track, "info": info})


func accept(invite_id: String, info: Dictionary) -> void:
	if state in ["online", "inviting"]:
		_send({"t": "accept", "invite": invite_id, "info": info})


func decline(invite_id: String) -> void:
	_send({"t": "decline", "invite": invite_id})


func ready_for_race() -> void:
	if state == "lobby":
		_send({"t": "ready"})


func course_loaded(version: String, length: float, laps: int) -> void:
	if state == "loading":
		_send({"t": "loaded", "version": version, "length": length, "laps": laps})


func server_time_ms() -> float:
	return float(Time.get_ticks_msec()) + _server_offset_ms


func race_seconds() -> float:
	if start_server_ms <= 0:
		return 0.0
	return maxf(0.0, (server_time_ms() - float(start_server_ms)) / 1000.0)


func send_state(delta: float, position: Vector3, orientation: Quaternion, speed: float,
		steer: float, distance: float, checkpoint: int, force: bool = false) -> void:
	if state not in ["countdown", "racing"] or server_time_ms() < start_server_ms:
		return
	state = "racing"
	_send_clock += delta
	if not force and _send_clock < 1.0 / SEND_HZ:
		return
	_send_clock = 0.0
	_sequence += 1
	var q: Quaternion = orientation.normalized()
	_send({"t": "state", "seq": _sequence, "p": [position.x, position.y, position.z],
		"q": [q.x, q.y, q.z, q.w], "speed": speed, "steer": steer,
		"distance": distance, "checkpoint": checkpoint})


func send_finish() -> void:
	if state == "racing":
		_send({"t": "finish"})


func _send(message: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var encoded: String = JSON.stringify(message)
	if encoded.to_utf8_buffer().size() <= MAX_PACKET:
		_socket.send_text(encoded)


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	if _socket == null:
		return
	_socket.poll()
	var ready: int = _socket.get_ready_state()
	var now: int = Time.get_ticks_msec()
	if ready == WebSocketPeer.STATE_CLOSED:
		_lost("Die Online-Verbindung ist unterbrochen. Du kannst allein weiterfahren.")
		return
	if ready == WebSocketPeer.STATE_CONNECTING:
		if now - _connect_started_ms > 75000:
			_lost("Der Online-Server antwortet nicht. Versuche es später erneut.")
		return
	if ready != WebSocketPeer.STATE_OPEN:
		return
	if not _hello_sent:
		_hello_sent = true
		_send({"t": "hello", "v": PROTOCOL, "alias": alias, "key": _key})
	if now - _last_ping_ms >= 2000 and state != "connecting":
		_last_ping_ms = now
		_send({"t": "ping", "client_ms": now})
	var count: int = 0
	while _socket != null and _socket.get_available_packet_count() > 0 and count < 48:
		count += 1
		var packet: PackedByteArray = _socket.get_packet()
		if packet.size() > MAX_PACKET:
			_lost("Der Online-Server hat ungültige Daten gesendet.")
			return
		var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if message is Dictionary:
			_last_received_ms = now
			_handle(message)
	if _socket != null and now - _last_received_ms > 45000 and state != "connecting":
		_lost("Die Online-Verbindung ist unterbrochen. Du kannst allein weiterfahren.")


func _handle(message: Dictionary) -> void:
	match str(message.get("t", "")):
		"welcome":
			if str(message.get("id", "")) != my_id or int(message.get("v", 0)) != PROTOCOL:
				_lost("Die Online-Anmeldung konnte nicht bestätigt werden.")
				return
			var confirmed_name: String = str(message.get("handle", ""))
			if not valid_alias(confirmed_name):
				_lost("Der Online-Spielername konnte nicht bestätigt werden.")
				return
			alias = confirmed_name
			username = confirmed_name
			registered = true
			if not _save_identity():
				_lost("Dein Online-Spieler konnte auf diesem Gerät nicht gespeichert werden.")
				return
			_server_offset_ms = float(message.get("server_ms", 0)) - Time.get_ticks_msec()
			_set_status("online", "Du bist online. Lade einen Freund ein.")
		"pong":
			var sent: float = _number(message.get("client_ms"), -1.0)
			var stamp: float = _number(message.get("server_ms"), -1.0)
			var now: float = float(Time.get_ticks_msec())
			var rtt: float = now - sent
			if sent >= 0.0 and stamp >= 0.0 and rtt >= 0.0 and rtt < 10000.0 and rtt <= _best_rtt_ms + 5.0:
				_best_rtt_ms = minf(_best_rtt_ms, rtt)
				_server_offset_ms = stamp + rtt * 0.5 - now
		"friends":
			var entries: Variant = message.get("friends", [])
			if entries is Array and entries.size() <= 64:
				friends.clear()
				for item in entries:
					if item is Dictionary and valid_alias(str(item.get("username", ""))) and str(item.get("uid", "")).length() == 64:
						friends.append({"uid": str(item.uid), "username": str(item.username), "online": item.get("online", false) == true})
				_save_friends()
				friends_changed.emit()
		"friend_requests":
			var requests: Variant = message.get("requests", [])
			if requests is Array and requests.size() <= 32:
				friend_requests.clear()
				for item in requests:
					if item is Dictionary and valid_alias(str(item.get("username", ""))) and str(item.get("request_id", "")).length() == 32:
						friend_requests.append(item.duplicate(true))
				friend_requests_changed.emit()
		"friend_request_sent":
			_set_status(state, "Freundschaftsanfrage an %s gesendet." % str(message.get("username", "")))
		"invitation":
			var incoming: Dictionary = message.duplicate(true)
			if valid_handle(str(incoming.get("from", ""))) and str(incoming.get("invite", "")).length() == 32:
				invitation_received.emit(incoming)
		"invitation_expired":
			invitation_expired.emit(str(message.get("invite", "")))
			if state == "inviting":
				_set_status("online", "Die Einladung ist abgelaufen.")
		"invite_sent":
			_set_status("inviting", "Einladung gesendet. Dein Freund kann sie jetzt annehmen.")
		"declined":
			_set_status("online", "Dein Freund möchte gerade nicht fahren.")
		"room":
			_on_room(message)
		"ready":
			var ids: Variant = message.get("ids", [])
			if ids is Array:
				ready_changed.emit(ids)
		"prepare":
			if str(message.get("room", "")) == room_id and not room_id.is_empty():
				_set_status("loading", "Beide Karts werden an den Start gestellt …")
				race_prepare.emit(track)
		"start":
			if str(message.get("room", "")) == room_id and state == "loading":
				start_server_ms = int(_number(message.get("start_ms"), 0))
				if start_server_ms <= 0:
					return
				_set_status("countdown", "Gemeinsamer Start!")
				race_start.emit(start_server_ms)
		"state":
			_on_snapshot(message)
		"finish":
			var finish_time: float = _number(message.get("time"), -1.0)
			if finish_time <= 0.0 or finish_time > 1200.0:
				return
			if str(message.get("id", "")) == my_id:
				own_time = finish_time
				state = "finished"
			elif str(message.get("id", "")) == str(friend.get("id", "")):
				friend_time = finish_time
				friend_finished.emit(finish_time)
		"result":
			if str(message.get("room", "")) == room_id:
				result = message.duplicate(true)
				state = "finished"
				result_received.emit(result)
		"room_closed":
			if str(message.get("room", "")) != room_id:
				return
			var reason: String = str(message.get("reason", "connection_lost"))
			room_id = ""
			_samples.clear()
			var text: String = str(ERROR_TEXT.get(reason, "Der Freund hat den Raum verlassen. Du kannst allein weiterfahren."))
			_set_status("online", text)
			friend_left.emit(text)
		"error":
			var code: String = str(message.get("code", ""))
			var text: String = str(ERROR_TEXT.get(code, "Diese Online-Aktion konnte nicht ausgeführt werden."))
			if code in ["username_taken", "invalid_identity", "identity_already_online", "registration_limited", "registration_unavailable"]:
				disconnect_online(text)
			else:
				_set_status("online" if state == "inviting" else state, text)


func _on_room(message: Dictionary) -> void:
	var players: Variant = message.get("players", [])
	if not players is Array or players.size() != 2:
		return
	var other: Dictionary = {}
	var found_me: bool = false
	for participant in players:
		if not participant is Dictionary:
			return
		if str(participant.get("id", "")) == my_id:
			found_me = true
		else:
			other = participant
	if not found_me or not valid_handle(str(other.get("handle", ""))):
		return
	_clear_room()
	room_id = str(message.get("room", ""))
	track = str(message.get("track", ""))
	friend = other.duplicate(true)
	_set_status("lobby", "Dein Freund ist da. Wenn beide bereit sind, startet das Rennen.")
	room_joined.emit(message)


func _on_snapshot(message: Dictionary) -> void:
	if str(message.get("id", "")) != str(friend.get("id", "")) or room_id.is_empty():
		return
	var sequence: int = int(_number(message.get("seq"), -1.0))
	var stamp: float = _number(message.get("k"), -1.0)
	var p: Variant = message.get("p")
	var q: Variant = message.get("q")
	if sequence <= _last_snapshot_sequence or stamp < 0.0 or stamp > 1200.0:
		return
	if not p is Array or p.size() != 3 or not q is Array or q.size() != 4:
		return
	var position := Vector3()
	for i in range(3):
		position[i] = _number(p[i], INF)
	if not position.is_finite() or position.length() > 35000.0:
		return
	var orientation := Quaternion(_number(q[0], INF), _number(q[1], INF), _number(q[2], INF), _number(q[3], INF))
	if not orientation.is_finite() or orientation.length_squared() < 0.9 or orientation.length_squared() > 1.1:
		return
	_last_snapshot_sequence = sequence
	friend_distance = _number(message.get("distance"), friend_distance)
	friend_checkpoint = int(_number(message.get("checkpoint"), friend_checkpoint))
	_samples.append({"k": stamp, "p": position, "q": orientation.normalized(),
		"v": clampf(_number(message.get("speed"), 0.0), -80.0, 180.0),
		"st": clampf(_number(message.get("steer"), 0.0), -1.0, 1.0)})
	while _samples.size() > 32:
		_samples.pop_front()


func friend_pose() -> Dictionary:
	if _samples.is_empty():
		return {}
	var target: float = race_seconds() - 0.12
	if target <= float(_samples[0].k):
		return _samples[0]
	for i in range(_samples.size() - 1):
		var a: Dictionary = _samples[i]
		var b: Dictionary = _samples[i + 1]
		if target <= float(b.k):
			var fraction: float = clampf((target - float(a.k)) / maxf(0.001, float(b.k) - float(a.k)), 0.0, 1.0)
			return {"p": (a.p as Vector3).lerp(b.p, fraction),
				"q": (a.q as Quaternion).slerp(b.q, fraction),
				"v": lerpf(float(a.v), float(b.v), fraction),
				"st": lerpf(float(a.st), float(b.st), fraction)}
	var last: Dictionary = _samples[-1].duplicate()
	if _samples.size() >= 2:
		var before: Dictionary = _samples[-2]
		var span: float = maxf(0.001, float(last.k) - float(before.k))
		var velocity: Vector3 = ((last.p as Vector3) - (before.p as Vector3)) / span
		last.p += velocity.limit_length(180.0) * clampf(target - float(last.k), 0.0, 0.15)
	return last


func _lost(text: String) -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	for entry in friends:
		entry.online = false
	room_id = ""
	_samples.clear()
	_set_status("offline", text)
	friend_left.emit(text)


func _set_status(next: String, text: String) -> void:
	state = next
	status_text = text
	status_changed.emit(next, text)


func _exit_tree() -> void:
	disconnect_online("")


static func _number(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var number: float = float(value)
		if is_finite(number):
			return number
	return fallback
