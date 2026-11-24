extends SceneTree
## Exercise the real native polling/action path; only the Android host is a fixture.
const SCENE := "res://scenes/games/connect_four_table.tscn"
const TOKEN := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var checks := 0
var failures := 0


class HostFixture:
	extends RefCounted
	# Keep the exact Java host method names at this one test boundary.
	# gdlint: disable=function-name
	var state: Dictionary
	var actions: Array[Dictionary] = []
	var returns: Array[Dictionary] = []
	var allow_return := false

	func getConnectFourState() -> String:
		return JSON.stringify(state)

	func submitConnectFourAction(payload: String) -> bool:
		actions.append(JSON.parse_string(payload))
		return true

	func returnToApp(destination: String, payload: String) -> bool:
		returns.append({"destination": destination, "payload": payload})
		return allow_return


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("[ConnectFourReturn] FAIL " + message)


func _initial_state() -> Dictionary:
	var board: Array[int] = []
	board.resize(42)
	board.fill(0)
	return {
		"schema": 1,
		"game": "connect_four",
		"token": TOKEN,
		"owner": "b".repeat(64),
		"roundId": "c".repeat(32),
		"revision": 1,
		"recordRevision": 1,
		"ack": 0,
		"rejected": 0,
		"paused": false,
		"canDrop": true,
		"phase": "playing",
		"turn": 1,
		"twoPlayers": true,
		"level": "mittel",
		"columns": [],
		"board": board,
		"winningLine": [],
		"rewarded": false,
		"exit": false,
		"reduceMotion": true,
		"validColumns": [0, 1, 2, 3, 4, 5, 6],
		"error": null,
	}


func _run() -> void:
	root.size = Vector2i(960, 540)
	var bridge := root.get_node("HostBridge")
	var original_options: Dictionary = bridge._options.duplicate(true)
	bridge._options["connectFourToken"] = TOKEN
	var host := HostFixture.new()
	host.state = _initial_state()
	var table = (load(SCENE) as PackedScene).instantiate()
	table._host = host
	root.add_child(table)
	table.set_process(false)
	for frame in range(3):
		await process_frame
	_check(table._state.token == TOKEN, "real scene consumes the matching host session")
	table._process(0.1)
	_check(host.returns.is_empty(), "ordinary repeated state cannot leave the game")
	_check(table._send("exit"), "real action path submits one exit request")
	_check(host.actions.size() == 1, "exactly one action reaches the host")
	var sequence: int = host.actions[0].sequence
	_check(table._pending == sequence, "accepted request still awaits durable host state")
	host.state["revision"] = 2
	host.state["exit"] = true
	host.state["paused"] = true
	host.state["canDrop"] = false
	table._process(0.1)
	_check(host.returns.is_empty(), "exit flag cannot bypass the pending acknowledgement")
	host.state["revision"] = 3
	host.state["ack"] = sequence
	table._process(0.1)
	_check(host.returns.size() == 1, "first acknowledged exit reaches Android once")
	_check(not table._closed, "rejected Android return leaves the native scene open")
	_check(table._pending == 0, "host acknowledgement is retained across Android refusal")
	var accepted_state: Dictionary = table._state.duplicate(true)
	var before_geometry: int = table._discs.size()
	var before_layout: int = table._layout_sequence
	var invalid: Dictionary = accepted_state.duplicate(true)
	invalid["token"] = "d".repeat(32)
	_check(not table.apply_state(invalid), "foreign session cannot trigger an exit retry")
	invalid = accepted_state.duplicate(true)
	invalid["revision"] = 2
	_check(not table.apply_state(invalid), "older state cannot trigger an exit retry")
	_check(host.returns.size() == 1, "rejected state has no Android side effect")
	host.allow_return = true
	table._process(0.1)
	_check(host.returns.size() == 2, "unchanged acknowledged state retries refused Android return")
	_check(table._closed, "successful retry closes the native session")
	_check(table._state == accepted_state, "retry preserves the exact acknowledged game state")
	_check(table._discs.size() == before_geometry, "retry does not rebuild or replay game geometry")
	_check(table._layout_sequence == before_layout, "retry does not invent a new layout sequence")
	table._process(0.1)
	table.apply_state(accepted_state)
	_check(host.returns.size() == 2, "successful return is never duplicated")
	_check(host.actions.size() == 1, "retry does not submit another game or reward action")
	for request in host.returns:
		_check(
			request == {"destination": "games", "payload": ""},
			"return carries no unrelated pending reward payload"
		)
	table.queue_free()
	await process_frame
	bridge._options = original_options
	print("CONNECT_FOUR_RETURN_%s checks=%d" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
