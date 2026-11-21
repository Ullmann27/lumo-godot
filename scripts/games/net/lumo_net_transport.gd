extends RefCounted
## Übertragungsweg der Netzbasis. Zwei Ausführungen mit derselben Schnittstelle:
##  - ENet (UDP) im WLAN bzw. über 127.0.0.1 im Zwei-Prozess-Test,
##  - Speicher (MemoryHub) für Ein-Prozess-Tests mit festen Schritten, Verzögerung und Verlust.
## Ein späterer Internet-Relay-Weg wäre eine dritte Ausführung (WebSocket/TLS) – NICHT gebaut.
##
## Gemeinsame Schnittstelle (Duck-Typing): listen, connect_to, poll, send, kick, close, is_open.
## poll() liefert Ereignisse: {"type": "connect"|"disconnect"|"data", "peer": int, "data": Bytes}.
## Die Autorität hat immer peer 1; Gäste bekommen Nummern ab 2.

const AUTHORITY_PEER: int = 1


class ENetTransport:
	extends RefCounted
	var is_authority: bool = false
	var peer: ENetMultiplayerPeer
	var _events: Array = []
	var _was_connected: bool = false

	func listen(port: int, max_guests: int) -> bool:
		close()
		peer = ENetMultiplayerPeer.new()
		if peer.create_server(port, max_guests) != OK:
			peer = null
			return false
		is_authority = true
		peer.peer_connected.connect(func(id: int): _events.append({"type": "connect", "peer": id}))
		peer.peer_disconnected.connect(
			func(id: int): _events.append({"type": "disconnect", "peer": id})
		)
		return true

	func connect_to(address: String, port: int) -> bool:
		close()
		peer = ENetMultiplayerPeer.new()
		if peer.create_client(address, port) != OK:
			peer = null
			return false
		is_authority = false
		_was_connected = false
		return true

	func poll() -> Array:
		if peer == null:
			return []
		peer.poll()
		if peer == null:
			return []
		if not is_authority:
			var status: int = peer.get_connection_status()
			if status == MultiplayerPeer.CONNECTION_CONNECTED and not _was_connected:
				_was_connected = true
				# Abbruch schneller erkennen als ENet-Vorgabe (bis 30 s): 3–8 s.
				var server: ENetPacketPeer = peer.get_peer(AUTHORITY_PEER)
				if server != null:
					server.set_timeout(32, 3000, 8000)
				_events.append({"type": "connect", "peer": AUTHORITY_PEER})
			elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
				_events.append({"type": "disconnect", "peer": AUTHORITY_PEER})
				peer.close()
				peer = null
		while peer != null and peer.get_available_packet_count() > 0:
			var from: int = peer.get_packet_peer()
			_events.append({"type": "data", "peer": from, "data": peer.get_packet()})
		var out: Array = _events
		_events = []
		return out

	func send(target: int, data: PackedByteArray, reliable: bool) -> void:
		if peer == null:
			return
		if not is_authority and not _was_connected:
			return
		peer.transfer_mode = (
			MultiplayerPeer.TRANSFER_MODE_RELIABLE
			if reliable
			else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		)
		peer.transfer_channel = 0 if reliable else 1
		peer.set_target_peer(target)
		peer.put_packet(data)

	func kick(target: int) -> void:
		if peer != null and is_authority:
			peer.disconnect_peer(target)

	func close() -> void:
		if peer != null:
			peer.close()
		peer = null
		_events.clear()

	func is_open() -> bool:
		return peer != null


## Netz im Speicher: alle Teilnehmer teilen einen Hub; `step` zählt feste Schritte.
class MemoryHub:
	extends RefCounted
	var step: int = 0
	var latency_steps: int = 3
	var jitter_steps: int = 2
	var loss: float = 0.0
	var rng := RandomNumberGenerator.new()
	var listening: Dictionary = {}  # port -> MemoryTransport (Autorität)
	var _next_id: int = 2

	func new_id() -> int:
		_next_id += 1
		return _next_id - 1

	func deliver(to: Variant, from: int, data: PackedByteArray, reliable: bool) -> void:
		if to == null:
			return
		if not reliable and rng.randf() < loss:
			return
		var delay: int = latency_steps + rng.randi_range(0, jitter_steps)
		if reliable:
			# Zuverlässig heißt auch: in Reihenfolge (wie ENet-Kanal 0).
			delay = maxi(delay, int(to.last_reliable_due.get(from, 0)) - step)
			to.last_reliable_due[from] = step + delay
		to.inbox.append({"due": step + delay, "from": from, "data": data})


class MemoryTransport:
	extends RefCounted
	var is_authority: bool = false
	var hub: MemoryHub
	var my_id: int = 0
	var inbox: Array = []
	var last_reliable_due: Dictionary = {}
	var links: Dictionary = {}  # peer id -> MemoryTransport
	var _events: Array = []
	var _open: bool = false

	func _init(shared: MemoryHub) -> void:
		hub = shared

	func listen(port: int, _max_guests: int) -> bool:
		if hub.listening.has(port):
			return false
		hub.listening[port] = self
		is_authority = true
		my_id = AUTHORITY_PEER
		_open = true
		return true

	func connect_to(_address: String, port: int) -> bool:
		var server: MemoryTransport = hub.listening.get(port)
		if server == null:
			return false
		close()
		_open = true
		is_authority = false
		my_id = hub.new_id()
		links = {AUTHORITY_PEER: server}
		server.links[my_id] = self
		server._events.append({"type": "connect", "peer": my_id})
		_events.append({"type": "connect", "peer": AUTHORITY_PEER})
		return true

	func poll() -> Array:
		var keep: Array = []
		for packet in inbox:
			if int(packet.due) <= hub.step:
				if _open and links.has(int(packet.from)):
					_events.append({"type": "data", "peer": packet.from, "data": packet.data})
			else:
				keep.append(packet)
		inbox = keep
		var out: Array = _events
		_events = []
		return out

	func send(target: int, data: PackedByteArray, reliable: bool) -> void:
		if _open:
			hub.deliver(links.get(target), my_id, data, reliable)

	## Harte Trennung wie „WLAN aus“: die Gegenseite merkt es (wie ENet) als disconnect.
	func kick(target: int) -> void:
		var other: MemoryTransport = links.get(target)
		links.erase(target)
		if other != null:
			other.links.erase(my_id)
			other._events.append({"type": "disconnect", "peer": my_id})
			if not other.is_authority:
				other._open = false

	func close() -> void:
		for id in links.keys():
			kick(int(id))
		if is_authority:
			for port in hub.listening.keys():
				if hub.listening[port] == self:
					hub.listening.erase(port)
		_open = false
		inbox.clear()

	## Nur Test: Verbindung still verlieren (keine Abmeldung) – wie Funkloch.
	func vanish() -> void:
		links.clear()
		inbox.clear()
		_open = false

	func is_open() -> bool:
		return _open
