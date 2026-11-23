extends SceneTree
## Real kart_island + two real relay sockets: social flow, remote rendered kart,
## username tags, quaternion pose, live place/2 HUD, disconnect. This probes the
## integration/rendering contract, not a complete physically driven race.

const SESSION = preload("res://scripts/games/online/kart_online_session.gd")
const CODEC = preload("res://scripts/games/kart_friends/kart_ghost_codec.gd")
var game: Node
var friend: Node
var online: Node
var checks: int = 0
var failures: Array[String] = []
var invitation: Dictionary = {}
var output: String = ""
var shots: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("[KartOnlineScene] FAIL: " + label)


func _settle(frames: int = 3) -> void:
	for i in range(frames):
		await process_frame


func _until(condition: Callable, seconds: float = 20.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _run() -> void:
	output = OS.get_environment("LUMO_ONLINE_QA_OUTPUT")
	shots = OS.get_environment("LUMO_ONLINE_QA_SHOTS") == "1"
	var url: String = OS.get_environment("LUMO_ONLINE_QA_URL")
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": "online-qa-alina", "playerName": "Lernprofil"}
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await _settle()
	_check(game.friend_duel.online == null, "no Internet adapter without parent permission")
	_check(game.safe_ui.get_node_or_null("KartOnlineEntry") == null, "no Internet button without permission")
	router.launch_options = {"childKey": "online-qa-alina", "playerName": "Lernprofil", "friendsOnline": true, "kartOnlineEndpoint": ""}
	game.friend_duel.attach(game)
	router.launch_options = {}
	online = game.friend_duel.online
	_check(is_instance_valid(online), "adapter appears with separate online permission")
	online.session.allow_loopback_for_tests = true
	online._configured = online.session.configure(url, "online-qa-alina")
	_check(online._configured, "actual relay endpoint accepted only with loopback QA opt-in")
	_check(str(online.session.username).is_empty(), "learning profile name was not reused")
	game._show_reference_landing()
	online.open_lobby()
	await _settle()
	_check(online.alias_edit != null and online.alias_edit.editable, "first-time own username input")
	online.alias_edit.text = "QaAlina"
	online._connect()
	friend = SESSION.new()
	friend.name = "QaOtherRealSocket"
	friend.allow_loopback_for_tests = true
	friend.invitation_received.connect(func(value: Dictionary): invitation = value)
	root.add_child(friend)
	_check(friend.configure(url, "online-qa-zoe"), "second profile session configured")
	_check(str(friend.identity_path) != str(online.session.identity_path), "profile identities are separate")
	_check(friend.set_alias("QaZoe"), "second independent username saved")
	friend.connect_online()
	if not await _until(func(): return online.session.state == "online" and friend.state == "online"):
		_check(false, "two authenticated clients online")
		await _complete()
		return
	_check(online.session.username == "QaAlina" and friend.username == "QaZoe", "exact chosen names confirmed")
	await _settle()
	online.target_edit.text = "QaZoe"
	var request_button: Button = online.column.find_child("KartOnlineFriendRequest", true, false)
	_check(request_button != null, "friendship request button is wired")
	request_button.pressed.emit()
	if not await _until(func(): return not friend.friend_requests.is_empty()):
		_check(false, "separate friendship request arrives")
		await _complete()
		return
	_check(str(friend.friend_requests[0].username) == "QaAlina", "request shows sender username")
	_check(str(online.session.room_id).is_empty(), "friendship request does not start race room")
	friend.decline_friend(str(friend.friend_requests[0].request_id))
	if not await _until(func(): return friend.friend_requests.is_empty()):
		_check(false, "friendship decline is independent of a race")
		await _complete()
		return
	online.close_lobby()
	friend.request_friend("QaAlina")
	if not await _until(func(): return online.session.friend_requests.size() == 1):
		_check(false, "incoming friendship request reaches the kart main menu")
		await _complete()
		return
	await _settle(3)
	_check(online.entry.visible and online.entry.text.contains("Anfragen"), "incoming request is visible in the kart main menu")
	_check(not is_instance_valid(online.overlay), "incoming request does not cover the kart menu")
	online.open_lobby()
	await _settle(3)
	var accept_friend_button: Button = online.column.find_child("KartOnlineAcceptFriend", true, false)
	_check(accept_friend_button != null, "incoming friendship has explicit accept button")
	accept_friend_button.pressed.emit()
	if not await _until(func(): return online.session.friends.size() == 1 and friend.friends.size() == 1):
		_check(false, "accepted friendship on both clients")
		await _complete()
		return
	await _settle(4)
	_check(online.session.friends[0].username == "QaZoe" and online.session.friends[0].online, "friend is named and online")
	await _shot("01_online_freunde")
	var invite_button: Button = online.column.find_child("KartOnlineInviteFriend", true, false)
	_check(invite_button != null and not invite_button.disabled, "online friend has separate race invitation")
	invite_button.pressed.emit()
	if not await _until(func(): return not invitation.is_empty()):
		_check(false, "race invitation arrives after friendship")
		await _complete()
		return
	friend.accept(str(invitation.invite), {"driver": "cat", "kart": "comet", "look": {"engine": "axial"}})
	if not await _until(func(): return online.session.state == "lobby" and friend.state == "lobby"):
		_check(false, "both clients in race room")
		await _complete()
		return
	await _settle(4)
	await _shot("02_online_rennraum")
	var ready_button: Button = online.column.find_child("KartOnlineReady", true, false)
	_check(ready_button != null, "ready button exists")
	ready_button.pressed.emit()
	friend.ready_for_race()
	if not await _until(func(): return online.active and friend.state == "loading" and is_instance_valid(game.world), 60.0):
		_check(false, "real course built after both ready")
		await _complete()
		return
	var version: String = CODEC.track_version(game.world, str(game.track_id), float(game.track_length))
	friend.course_loaded(version, float(game.track_length), int(game.TOTAL_LAPS))
	if not await _until(func(): return online.session.start_server_ms > 0 and friend.start_server_ms > 0):
		_check(false, "same course barrier releases server start")
		await _complete()
		return
	_check(online.session.start_server_ms == friend.start_server_ms, "same server countdown target")
	_check(game.preview_total == 0.0, "online start has no independent camera flyover")
	var remote: Node3D = game.ghost
	_check(is_instance_valid(remote) and remote.name == "OnlineFriendKart", "remote is actual 3D race kart")
	_check(remote.get_node_or_null("OnlineFriendName").text == "QaZoe", "remote 3D name tag")
	_check(game.player.get_node_or_null("OwnOnlineName").text == "QaAlina", "own 3D name tag")
	if not await _until(func(): return online.session.race_seconds() > 0.1):
		_check(false, "online countdown reaches shared start")
		await _complete()
		return
	game.countdown = 0.0
	game.racing = true
	var beginning: float = friend.race_seconds()
	var observed: int = 0
	var friend_distance: float = 20.0
	while friend.race_seconds() - beginning < 3.5:
		var elapsed: float = friend.race_seconds() - beginning
		friend_distance = 20.0 + elapsed * 14.0
		var xf: Transform3D = game.world.reset_transform(friend_distance, 1.6)
		friend.send_state(0.06, xf.origin + Vector3(0, 0.035, 0), xf.basis.get_rotation_quaternion(),
			14.0, 0.0, friend_distance, int(friend_distance / (game.track_length / 8.0)), true)
		game.distance = maxf(0.0, friend_distance - 12.0)
		game.player.transform = game.world.reset_transform(game.distance, -1.6)
		game.player.position.y += 0.035
		game.player_heading = game._heading(game.distance)
		game.speed = 14.0
		game.friend_duel.tick(game, 0.06)
		if remote.visible:
			observed += 1
		await create_timer(0.06).timeout
	_check(observed >= (1 if shots else 12), "live remote kart repeatedly visible")
	# Hold the last real network pose until even a slow software-rendered frame
	# receives it. The separate headless run covers continuous movement cadence.
	var stationary: Transform3D = game.world.reset_transform(friend_distance, 1.6)
	var hold_deadline: int = Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < hold_deadline:
		friend.send_state(0.06, stationary.origin + Vector3(0, 0.035, 0), stationary.basis.get_rotation_quaternion(),
			0.0, 0.0, friend_distance, int(friend_distance / (game.track_length / 8.0)), true)
		game.friend_duel.tick(game, 0.06)
		if remote.visible and remote.position.distance_to(stationary.origin) < 2.0 and absf(float(online.session.friend_distance) - friend_distance) < 1.0:
			break
		await create_timer(0.06).timeout
	_check(remote.position.distance_to(stationary.origin) < 2.0, "remote reaches transmitted stationary world position")
	game._update_camera(1.0, true)
	online._push_online_hud()
	var bar: Node = game.hud.get_parent().get_node("KartRaceBar")
	_check(int(bar.values.field) == 2 and int(bar.values.place) == 2, "real HUD displays place two of two")
	_check(online.online_caption.text.contains("QaZoe") and online.online_caption.text.contains("vor dir"), "opponent name and gap visible")
	await _settle(3)
	await _shot("03_online_zwei_karts")
	friend.disconnect_online("")
	_check(await _until(func(): return str(online.session.room_id).is_empty()), "disconnect closes online room")
	_check(await _until(func(): return online.session.friends.size() == 1 and not bool(online.session.friends[0].online)), "accepted friend retained with offline presence")
	_check(not remote.visible, "no AI opponent masquerades as disconnected friend")
	online.session.disconnect_online("")
	await _settle(4)
	online._configured = online.session.configure(url, "online-qa-alina")
	_check(online.session.registered and online.session.username == "QaAlina", "fixed username reloads from the profile identity")
	online.connect_if_registered()
	_check(await _until(func(): return online.session.state == "online"), "returning registered player connects without a connect button")
	_check(await _until(func(): return online.session.friends.size() == 1), "accepted friendship reloads after reconnection")
	await _complete()


func _shot(name: String) -> void:
	if not shots or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))


func _complete() -> void:
	var report: Dictionary = {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"checks": checks, "failures": failures,
		"scope": "real kart scene and two relay sockets; controlled route poses for integration/rendering",
		"complete_driven_race": false, "internet_deployment": false,
	}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("online-scene.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ") + "\n")
			file.close()
	if is_instance_valid(friend):
		friend.disconnect_online("")
		friend.queue_free()
	if is_instance_valid(game):
		game.abandoned = true
		game.queue_free()
	await _settle(6)
	print("[KartOnlineScene] " + str(report.status) + ": " + str(checks) + " checks")
	quit(0 if failures.is_empty() else 1)
