extends Node
## „Zusammen fahren“ im selben WLAN: zwei Geräte, ein Raumcode, kein Server, kein Chat.
##
## Raumcode (4 Ziffern) = letztes Byte der WLAN-Adresse von Gerät A (3 Ziffern) + Prüfziffer.
## Gerät B verbindet sich im eigenen /24-Netz mit dieser Adresse (UDP, ENet, Port 47630).
## Es gibt keine Suche im Netz (kein Broadcast/Multicast), also keine weitere Berechtigung.
## Übertragen werden nur: Vorname, Fahrer, Kart, Strecke + Version, Fahrposition, Zielzeit.
## Jedes ankommende Paket wird streng geprüft; Unbekanntes wird verworfen.

signal status_changed(state: String, text: String)
signal friend_joined(info: Dictionary)
signal race_start(track: String, delay: float)
signal friend_finished(time: float)
signal friend_left(text: String)

const PORT: int = 47630
const PROTOCOL: int = 1
const MAX_PACKET: int = 512
const STATE_HZ: float = 15.0
## Großzügig: beim Streckenaufbau kann das andere Gerät einige Sekunden stumm sein.
const TIMEOUT_S: float = 10.0
const MAX_COORD: float = 5000.0
const CODEC = preload("res://scripts/games/kart_friends/kart_ghost_codec.gd")
## Glättung aus der Netzbasis (lastfest: Min-Filter-Uhr, ±10 % Nachführung, begrenztes Aufholen).
const INTERP = preload("res://scripts/games/net/lumo_net_interpolator.gd")

## "idle", "hosting", "joining", "lobby", "racing", "finished", "closed"
var state: String = "idle"
var is_host: bool = false
var room_code: String = ""
var me: Dictionary = {}
var friend: Dictionary = {}
var friend_time: float = -1.0
## Strecken-Version, die der Freund nach dem Aufbau seiner Strecke meldet ("" = noch offen).
var friend_track_version: String = ""
## Nur für Tests: Netzanfang statt der eigenen WLAN-Adresse (z. B. "127.0.0.").
var network_prefix_override: String = ""
var peer: ENetMultiplayerPeer
var _interp: RefCounted = INTERP.new()
var _send_clock: float = 0.0
var _quiet: float = 0.0
var _clock: float = 0.0
var _ping_clock: float = 0.0


## Prüfziffer: gewichtete Summe, damit Zahlendreher auffallen.
static func check_digit(octet: int) -> int:
	var digits: String = "%03d" % octet
	return (int(digits[0]) * 3 + int(digits[1]) * 7 + int(digits[2]) * 9) % 10


static func code_for_octet(octet: int) -> String:
	return "%03d%d" % [octet, check_digit(octet)]


## Raumcode → letztes Byte (1–254) oder -1 bei Tippfehler.
static func octet_for_code(code: String) -> int:
	if code.length() != 4 or not code.is_valid_int():
		return -1
	var octet: int = int(code.substr(0, 3))
	if octet < 1 or octet > 254 or check_digit(octet) != int(code[3]):
		return -1
	return octet


## Eigene private IPv4-Adresse im WLAN (192.168/16, 10/8, 172.16/12), sonst "".
static func local_address() -> String:
	var best: String = ""
	for address in IP.get_local_addresses():
		var parts: PackedStringArray = str(address).split(".")
		if parts.size() != 4:
			continue
		var a: int = int(parts[0])
		var b: int = int(parts[1])
		if a == 192 and b == 168:
			return address
		if a == 10 or (a == 172 and b >= 16 and b <= 31):
			best = address
	return best


func _prefix() -> String:
	if not network_prefix_override.is_empty():
		return network_prefix_override
	var own: String = local_address()
	if own.is_empty():
		return ""
	return own.substr(0, own.rfind(".") + 1)


## Gerät A: Raum öffnen. info = {name, driver, kart, track, track_version}.
func host(info: Dictionary) -> bool:
	close("")
	me = _clean_info(info)
	var address: String = (
		network_prefix_override + "1" if not network_prefix_override.is_empty() else local_address()
	)
	if address.is_empty():
		_set_state("closed", "Kein WLAN gefunden. Bitte mit dem WLAN verbinden.")
		return false
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 1) != OK:
		peer = null
		_set_state("closed", "Der Raum konnte nicht geöffnet werden. Bitte noch einmal versuchen.")
		return false
	# Geht das andere Gerät ordentlich (oder bemerkt ENet den Abbruch), sofort melden.
	peer.peer_disconnected.connect(_on_peer_disconnected)
	is_host = true
	room_code = code_for_octet(int(address.substr(address.rfind(".") + 1)))
	_set_state("hosting", "Dein Raumcode: %s" % room_code)
	return true


## Gerät B: Raum mit Code betreten.
func join(code: String, info: Dictionary) -> bool:
	close("")
	me = _clean_info(info)
	var octet: int = octet_for_code(code)
	if octet < 0:
		_set_state("closed", "Dieser Raumcode stimmt nicht. Bitte noch einmal ablesen.")
		return false
	var prefix: String = _prefix()
	if prefix.is_empty():
		_set_state("closed", "Kein WLAN gefunden. Bitte mit dem WLAN verbinden.")
		return false
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(prefix + str(octet), PORT) != OK:
		peer = null
		_set_state("closed", "Verbindung nicht möglich. Seid ihr im selben WLAN?")
		return false
	is_host = false
	room_code = code
	_quiet = 0.0
	_set_state("joining", "Verbinde mit Raum %s …" % code)
	return true


## Gerät A startet das Rennen auf seiner Strecke; beide zählen gemeinsam herunter.
func start_race(delay: float = 1.0) -> void:
	if not is_host or state not in ["lobby", "finished"] or friend.is_empty():
		return
	_send({"t": "start", "track": str(me.track), "delay": delay})
	_begin_race(str(me.track), delay)


## Während des Rennens: eigene Fahrt (15-mal pro Sekunde wird gesendet).
func send_state(
	delta: float, race_time: float, position: Vector3, rotation: Vector3, speed: float, steer: float
) -> void:
	if state != "racing":
		return
	_send_clock += delta
	if _send_clock < 1.0 / STATE_HZ:
		return
	_send_clock = 0.0
	_send(
		{
			"t": "s",
			"k": race_time,
			"p": [position.x, position.y, position.z],
			"r": [rotation.x, rotation.y, rotation.z],
			"v": speed,
			"st": steer
		},
		false
	)


## Nach dem Streckenaufbau: eigene Strecken-Version melden (alte Strecke → beide fahren allein).
func send_track_version(version: String) -> void:
	if state == "racing":
		_send({"t": "ver", "v": version})


func send_finish(time: float) -> void:
	if state in ["racing", "finished"]:
		_send({"t": "finish", "time": time})
		state = "finished"


## Geglättete Position des Freundes ({k, p, r, v, st}; {} solange nichts da ist).
## (race_time bleibt für Aufrufer erhalten, die keine eigene Uhr haben.)
func friend_pose(_race_time: float) -> Dictionary:
	return _interp.sample(_clock)


func close(text: String = "Verbindung beendet.") -> void:
	if peer != null:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_send({"t": "bye"})
			peer.poll()
		peer.close()
	peer = null
	_interp.clear()
	friend = {}
	friend_time = -1.0
	if not text.is_empty():
		_set_state("closed", text)
	else:
		state = "idle"


func _process(delta: float) -> void:
	poll(delta)


func poll(delta: float) -> void:
	if peer == null:
		return
	_clock += delta
	peer.poll()
	if peer == null:
		return
	var status: int = peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if state in ["joining", "joining_hello"]:
			close("Kein Raum %s gefunden. Seid ihr im selben WLAN?" % room_code)
		else:
			_lost()
		return
	if state == "joining" and status == MultiplayerPeer.CONNECTION_CONNECTED and friend.is_empty():
		_send({"t": "hello", "v": PROTOCOL, "info": me})
		state = "joining_hello"
	# Lebenszeichen einmal pro Sekunde (im Raum und nach dem Ziel kommen sonst keine Daten).
	_ping_clock += delta
	if _ping_clock >= 1.0 and not friend.is_empty():
		_ping_clock = 0.0
		_send({"t": "p"}, false)
	while peer != null and peer.get_available_packet_count() > 0:
		var sender: int = peer.get_packet_peer()
		var packet: PackedByteArray = peer.get_packet()
		if packet.size() > MAX_PACKET:
			continue
		_quiet = 0.0
		_handle(packet, sender)
	if peer == null:
		return
	# Stille nur in Bildern zählen, in denen wir selbst zugehört haben: ein langes eigenes
	# Ladebild (Streckenaufbau) ist kein Abbruch. Echte Abbrüche meldet zusätzlich ENet.
	_quiet += minf(delta, 0.25)
	var quiet: float = _quiet
	if state in ["joining", "joining_hello"]:
		if quiet > 6.0:
			close("Kein Raum %s gefunden. Seid ihr im selben WLAN?" % room_code)
	elif state in ["lobby", "racing", "finished"] and not friend.is_empty():
		if quiet > TIMEOUT_S:
			_lost()


func _handle(packet: PackedByteArray, _sender: int) -> void:
	var message: Variant = bytes_to_var(packet)
	if not message is Dictionary:
		return
	match str(message.get("t", "")):
		"hello":
			_on_hello(message)
		"start":
			_on_start(message)
		"s":
			_on_state(message)
		"finish":
			_on_finish(message)
		"ver":
			var version: String = str(message.get("v", ""))
			if (
				state in ["racing", "finished"]
				and RegEx.create_from_string("^[a-z0-9_:.-]{1,48}$").search(version) != null
			):
				friend_track_version = version
		"bye":
			_lost()


func _on_hello(message: Dictionary) -> void:
	if _num(message.get("v"), 0.0) != PROTOCOL or not message.get("info") is Dictionary:
		return
	var info: Dictionary = _clean_info(message.info)
	if is_host:
		if not friend.is_empty() or state != "hosting":
			return
		friend = info
		_send({"t": "hello", "v": PROTOCOL, "info": me})
	else:
		if state != "joining_hello":
			return
		friend = info
	var track: String = str((me if is_host else friend).track)
	_set_state("lobby", "%s ist da! Strecke: %s" % [friend.name, _track_name(track)])
	friend_joined.emit(friend)


func _on_start(message: Dictionary) -> void:
	if is_host or state not in ["lobby", "finished"]:
		return
	var track: String = str(message.get("track", ""))
	if track != str(friend.get("track", "")):
		return
	_begin_race(track, clampf(_num(message.get("delay"), 1.0), 0.0, 3.0))


func _on_state(message: Dictionary) -> void:
	if state not in ["racing", "finished"]:
		return
	var snap: Variant = _clean_state(message)
	if not snap is Dictionary:
		return
	_interp.push(
		float(snap.k), _clock, snap.p, float(snap.r.y), float(snap.v), snap.r, float(snap.st)
	)


func _on_finish(message: Dictionary) -> void:
	var time: float = _num(message.get("time"), -1.0)
	if state in ["racing", "finished"] and time > 0.0 and time < 3600.0 and friend_time < 0.0:
		friend_time = time
		friend_finished.emit(time)


func _on_peer_disconnected(_id: int) -> void:
	if not friend.is_empty():
		_lost()


func _lost() -> void:
	var name: String = str(friend.get("name", "deinem Freund"))
	var racing: bool = state in ["racing", "finished"]
	if peer != null:
		peer.close()
	peer = null
	_interp.clear()
	var text: String = (
		"Die Verbindung zu %s ist unterbrochen – du fährst allein weiter." % name
		if racing
		else "Die Verbindung zu %s ist unterbrochen." % name
	)
	_set_state("closed", text)
	friend_left.emit(text)


func _begin_race(track: String, delay: float) -> void:
	_interp.clear()
	friend_track_version = ""
	friend_time = -1.0
	_send_clock = 0.0
	_quiet = 0.0
	state = "racing"
	status_changed.emit(state, "Los geht's!")
	race_start.emit(track, delay)


func _send(message: Dictionary, reliable: bool = true) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.transfer_mode = (
		MultiplayerPeer.TRANSFER_MODE_RELIABLE
		if reliable
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	)
	peer.transfer_channel = 0
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	peer.put_packet(var_to_bytes(message))


func _set_state(next: String, text: String) -> void:
	state = next
	status_changed.emit(next, text)


static func _clean_info(raw: Variant) -> Dictionary:
	var info: Dictionary = raw if raw is Dictionary else {}
	var pattern := RegEx.create_from_string("^[a-z0-9_]{1,40}$")
	var version := RegEx.create_from_string("^[a-z0-9_:.-]{1,48}$")
	var out := {"name": CODEC.clean_name(str(info.get("name", "")))}
	for key in ["driver", "kart", "track"]:
		var value: String = str(info.get(key, ""))
		out[key] = value if pattern.search(value) != null else ""
	var tv: String = str(info.get("track_version", ""))
	out["track_version"] = tv if version.search(tv) != null else ""
	return out


static func _clean_state(message: Dictionary) -> Variant:
	var k: Variant = message.get("k")
	var p: Variant = message.get("p")
	var r: Variant = message.get("r")
	if (
		not (k is float or k is int)
		or not p is Array
		or not r is Array
		or p.size() != 3
		or r.size() != 3
	):
		return null
	var position := Vector3()
	var rotation := Vector3()
	for i in range(3):
		if not (p[i] is float or p[i] is int) or not (r[i] is float or r[i] is int):
			return null
		position[i] = float(p[i])
		rotation[i] = float(r[i])
	if not position.is_finite() or not rotation.is_finite() or not is_finite(float(k)):
		return null
	if absf(position.x) > MAX_COORD or absf(position.y) > MAX_COORD or absf(position.z) > MAX_COORD:
		return null
	return {
		"k": float(k),
		"p": position,
		"r": rotation,
		"v": clampf(_num(message.get("v"), 0.0), -80.0, 80.0),
		"st": clampf(_num(message.get("st"), 0.0), -1.0, 1.0)
	}


## Nur echte, endliche Zahlen; alles andere ergibt den Ersatzwert (nie ein Laufzeitfehler).
static func _num(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var number: float = float(value)
		return number if is_finite(number) else fallback
	return fallback


static func _track_name(id: String) -> String:
	var catalog: Script = load("res://scripts/games/kart_catalog.gd")
	for entry in catalog.TRACKS:
		if str(entry.id) == id:
			return str(entry.name)
	return id
