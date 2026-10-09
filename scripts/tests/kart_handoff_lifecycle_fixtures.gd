extends RefCounted


class Host:
	extends Node
	var return_ack := 1
	var reward_ack := 1
	var reward_calls := 0
	var returns: Array[Dictionary] = []

	func reward(_value: String) -> int:
		reward_calls += 1
		return reward_ack

	# gdlint: disable=function-name
	func returnToApp(_destination: String, value: String) -> int:
		returns.append(JSON.parse_string(value))
		return return_ack


const SESSION := "user://kart_sonnenhafen_session.cfg"
var scene: PackedScene
var tree: SceneTree
var root: Window
var game
var host: Host
var checks: Array[Dictionary] = []


func run(tree_value: SceneTree) -> Dictionary:
	tree = tree_value
	root = tree.root
	scene = load("res://scenes/games/kart_island.tscn")
	return await _run()


func _check(ok: bool, name: String, expected: Variant, actual: Variant) -> void:
	checks.append(
		{
			"name": name,
			"passed": ok,
			"expected":
			expected.duplicate(true) if expected is Dictionary or expected is Array else expected,
			"actual": actual.duplicate(true) if actual is Dictionary or actual is Array else actual
		}
	)
	if not ok:
		print("[KartHandoffLifecycle] FAIL: " + name)


func _new(mode: String = "race") -> void:
	DirAccess.remove_absolute(SESSION)
	var bridge = root.get_node("HostBridge")
	bridge._return_pending = false
	bridge._result_ids.clear()
	bridge._pending_rewards.clear()
	host.reward_calls = 0
	host.returns.clear()
	host.return_ack = 1
	host.reward_ack = 1
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	game.graphics_profile = "low"
	await tree.process_frame
	game._start_selected_race(
		{
			"mode": mode,
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "flott"
		}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true


func _finish_fixture() -> void:
	game.elapsed = 50.0
	game.checkpoint_index = 16
	game.distance = game.track_length * 2.0
	game._finish(false)


func _natural_free() -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	root.world_3d.fallback_environment = null
	game.queue_free()
	game = null
	await tree.process_frame
	await tree.process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _run() -> Dictionary:
	root.world_3d.fallback_environment = null
	host = Host.new()
	root.add_child(host)
	root.get_node("HostBridge")._host = host
	root.get_node("HostBridge")._options = {
		"sessionId": "natural-ack-state-fixture", "soundEnabled": false
	}
	await _new()
	_finish_fixture()
	var expected_id: String = game.result_id
	game._return_to_app("games")
	_check(
		not FileAccess.file_exists(SESSION),
		"accepted completed return initially removes the session",
		false,
		FileAccess.file_exists(SESSION)
	)
	_check(
		(
			host.reward_calls == 1
			and host.returns.size() == 1
			and host.returns[0].resultId == expected_id
		),
		"accepted return retains one reward and original result ID",
		{"reward_calls": 1, "returns": 1, "resultId": expected_id},
		{
			"reward_calls": host.reward_calls,
			"returns": host.returns.size(),
			"resultId": host.returns[0].resultId
		}
	)
	await _natural_free()
	_check(
		not FileAccess.file_exists(SESSION),
		"natural scene teardown cannot recreate an accepted completed session",
		false,
		FileAccess.file_exists(SESSION)
	)
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await tree.process_frame
	_check(
		not game.saved_session_available,
		"fresh garage cannot offer an already handed-off result",
		false,
		game.saved_session_available
	)
	await _natural_free()
	await _new()
	_finish_fixture()
	host.return_ack = 0
	game._return_to_app("games")
	await _natural_free()
	_check(
		FileAccess.file_exists(SESSION),
		"failed host return retains a durable completed session after teardown",
		true,
		FileAccess.file_exists(SESSION)
	)
	await _new()
	game.elapsed = 14.0
	game._pause()
	game._return_to_app("games")
	await _natural_free()
	_check(
		FileAccess.file_exists(SESSION),
		"accepted unfinished paused return retains resumable progress",
		true,
		FileAccess.file_exists(SESSION)
	)
	await _new("cup")
	_finish_fixture()
	game._return_to_app("games")
	await _natural_free()
	_check(
		FileAccess.file_exists(SESSION),
		"accepted cup result retains continuation state",
		true,
		FileAccess.file_exists(SESSION)
	)
	await _new()
	_finish_fixture()
	game._return_to_app("games")
	var completed_id: String = game.result_id
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "flott"
		}
	)
	_check(
		game.result_id != completed_id and not game.finished and FileAccess.file_exists(SESSION),
		"new race after handoff can persist its fresh identity",
		true,
		game.result_id != completed_id and not game.finished and FileAccess.file_exists(SESSION)
	)
	await _natural_free()
	await _new()
	_finish_fixture()
	root.get_node("HostBridge")._host = null
	root.get_node("SceneRouter").current_scene_id = "kart"
	tree.current_scene = game
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	root.world_3d.fallback_environment = null
	game._return_to_app("games")
	for frame in range(8):
		await tree.process_frame
	var routed_path: String = (
		tree.current_scene.scene_file_path if is_instance_valid(tree.current_scene) else ""
	)
	_check(
		routed_path == "res://scenes/games/game_hub.tscn",
		"standalone return performs the real SceneRouter transition",
		"res://scenes/games/game_hub.tscn",
		routed_path
	)
	_check(
		not FileAccess.file_exists(SESSION),
		"standalone accepted route teardown cannot recreate its completed session",
		false,
		FileAccess.file_exists(SESSION)
	)
	if is_instance_valid(tree.current_scene):
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		root.world_3d.fallback_environment = null
		tree.current_scene.queue_free()
		await tree.process_frame
		await tree.process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
	game = null
	var failures := 0
	for check in checks:
		if not check.passed:
			failures += 1
	var report := {
		"status": "PASS" if failures == 0 else "FAIL",
		"checks": checks,
		"fixture_scope":
		(
			"Assigned elapsed/checkpoint/distance state; real _finish, return, "
			+ "natural queue_free and fresh garage; no driven-lap claim"
		),
		"source_sha256": FileAccess.get_sha256("res://scripts/games/kart_island.gd"),
		"probe_sha256": FileAccess.get_sha256(tree.get_script().resource_path),
		"probe_path": tree.get_script().resource_path,
		"helper_sha256": FileAccess.get_sha256(get_script().resource_path),
		"engine": Engine.get_version_info(),
		"display_server": DisplayServer.get_name()
	}
	var output: String = "res://exports/race-bridge"
	DirAccess.make_dir_recursive_absolute(output)
	(
		FileAccess
		. open(output.path_join("handoff-lifecycle-evidence.json"), FileAccess.WRITE)
		. store_string(JSON.stringify(report, "  "))
	)
	scene = null
	host.queue_free()
	host = null
	for frame in range(8):
		await tree.process_frame
	await tree.create_timer(0.8).timeout
	print(
		(
			"[KartHandoffLifecycle] %s: %d checks, %d failures"
			% [report.status, checks.size(), failures]
		)
	)
	return report
