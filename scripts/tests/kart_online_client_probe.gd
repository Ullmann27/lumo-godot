extends SceneTree
## QA only: one real Godot WebSocket client. The Python harness starts two OS
## processes and a real relay, then restarts the server against the same DB.

const SESSION = preload("res://scripts/games/online/kart_online_session.gd")
var client: Node
var role: String = ""
var invitation: Dictionary = {}
var requests_seen: bool = false
var friends_seen: bool = false
var prepare_seen: bool = false
var remote_moved: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	role = OS.get_environment("LUMO_ONLINE_QA_ROLE")
	var key: String = OS.get_environment("LUMO_ONLINE_QA_KEY")
	var directory: String = OS.get_environment("LUMO_ONLINE_QA_DIR")
	var alias: String = "QaAlpha" if role == "alpha" else "QaBeta"
	var other: String = "QaBeta" if role == "alpha" else "QaAlpha"
	var identity: String = directory.path_join(role + "_identity.cfg")
	if not FileAccess.file_exists(identity):
		var config := ConfigFile.new()
		config.set_value("identity", "key", key)
		config.set_value("identity", "alias", alias)
		config.set_value("identity", "registered", false)
		if config.save(identity) != OK:
			_fail("identity fixture save")
			return
	client = SESSION.new()
	client.identity_path = identity
	client.friends_path = directory.path_join(role + "_friends.cfg")
	client.allow_loopback_for_tests = true
	client.friends_changed.connect(func(): friends_seen = true)
	client.friend_requests_changed.connect(func(): requests_seen = true)
	client.invitation_received.connect(func(value: Dictionary): invitation = value)
	client.race_prepare.connect(func(_track: String): prepare_seen = true)
	root.add_child(client)
	if not client.configure(OS.get_environment("LUMO_ONLINE_QA_URL"), role):
		_fail("session configure")
		return
	if not client.connect_online():
		_fail("socket connect")
		return
	if not await _until(func(): return client.state == "online" and friends_seen and requests_seen, "welcome and social snapshot"):
		return
	if str(client.username) != alias:
		_fail("stable username")
		return
	print("LUMO_ONLINE_QA_READY " + role)
	var friend_info: Dictionary = _find_friend(other)
	if friend_info.is_empty():
		if role == "alpha":
			client.request_friend(other)
		else:
			if not await _until(func(): return not client.friend_requests.is_empty(), "friend request"):
				return
			if str(client.friend_requests[0].username) != other:
				_fail("friend request name")
				return
			client.accept_friend(str(client.friend_requests[0].request_id))
		if not await _until(func(): return not _find_friend(other).is_empty(), "mutually accepted friendship"):
			return
		friend_info = _find_friend(other)
	if not await _until(func(): return bool(_find_friend(other).get("online", false)), "friend online presence"):
		return
	var info: Dictionary = {"driver": "fox", "kart": "comet", "look": {"engine": "serie"}}
	if role == "alpha":
		client.invite(str(friend_info.uid), "sonnenhafen", info)
	else:
		if not await _until(func(): return not invitation.is_empty(), "separate race invitation"):
			return
		client.accept(str(invitation.invite), info)
	if not await _until(func(): return client.state == "lobby", "race room"):
		return
	client.ready_for_race()
	if not await _until(func(): return prepare_seen, "both drivers ready"):
		return
	client.course_loaded("qa:route:1", 200.0, 1)
	if not await _until(func(): return client.start_server_ms > 0, "server countdown"):
		return
	if not await _until(func(): return client.race_seconds() > 0.05, "shared start"):
		return
	var speed: float = 65.0 if role == "alpha" else 52.0
	var distance: float = 0.0
	while distance < 200.0:
		distance = minf(200.0, client.race_seconds() * speed)
		var orientation := Quaternion(Vector3.FORWARD, TAU * distance / 200.0)
		client.send_state(0.06, Vector3(distance, 1.0, 0.0), orientation,
			speed, 0.2, distance, mini(8, int(distance / 25.0)), true)
		var pose: Dictionary = client.friend_pose()
		if not pose.is_empty() and float(pose.p.x) > 5.0:
			remote_moved = true
		await create_timer(0.06).timeout
	client.send_state(0.1, Vector3(200.0, 1.0, 0.0), Quaternion.IDENTITY,
		speed, 0.0, 200.0, 8, true)
	client.send_finish()
	if not await _until(func(): return not client.result.is_empty(), "server result"):
		return
	if not remote_moved:
		_fail("opponent live position did not move")
		return
	var alpha_id: String = str(client.my_id) if role == "alpha" else str(friend_info.uid)
	if str(client.result.get("winner", "")) != alpha_id:
		_fail("winner or elapsed clock")
		return
	print("LUMO_ONLINE_QA_PASS " + JSON.stringify({
		"role": role, "username": client.username, "registered": client.registered,
		"friends": client.friends.size(), "remote_moved": remote_moved,
		"own_time": client.own_time, "friend_time": client.friend_time,
		"result": client.result, "transport": "real_loopback_websocket",
	}))
	client.disconnect_online("")
	quit(0)


func _find_friend(username: String) -> Dictionary:
	for entry in client.friends:
		if str(entry.username) == username:
			return entry
	return {}


func _until(condition: Callable, label: String, seconds: float = 20.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	_fail(label + " timed out: " + str(client.status_text))
	return false


func _fail(message: String) -> void:
	push_error("LUMO_ONLINE_QA_FAIL " + role + ": " + message)
	quit(1)
