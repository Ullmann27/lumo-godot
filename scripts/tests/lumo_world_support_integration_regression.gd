extends SceneTree
## Production World methods: persistent crossing controls and sidequest save hooks.
const POST = preload("res://scripts/creative/lumo_world_errands_ui.gd")
var checks := 0
var failures: Array[String] = []

class FriendSpy extends Node3D:
	var calls := 0
	func interact(_at: Vector3) -> bool:
		calls += 1
		return true

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("[WorldSupport] " + label)

func _run() -> void:
	var world = load("res://scripts/creative/lumo_world.gd").new()
	world.player = CharacterBody3D.new()
	world.add_child(world.player)
	world.status_label = Label.new()
	world.add_child(world.status_label)
	world.friend_post = POST.new()
	world.add_child(world.friend_post)
	_check(world.friend_post.setup(world, {}), "older World saves start an empty optional delivery state")
	for at in [Vector3(110, 0.2, 7), Vector3(110, 0.2, -7), Vector3(110, 0.2, 4.6), Vector3(110, 0.2, -4.6)]:
		_check(world._near_crossing_button(at), "crossing button is reachable at both waiting curbs")
	for at in [Vector3.ZERO, Vector3(110, 0, 0), Vector3(110, 8, 7), Vector3(INF, 0, 7)]:
		_check(not world._near_crossing_button(at), "crossing request cannot be made remotely or from the road")
	world.model.completed.assign(["meet_nelli", "safe_crossing", "school_numbers", "garden_delivery", "city_parcels", "friendship_picnic"])
	world.player.position = Vector3(110, 0.2, 7)
	world._request_crossing()
	_check(world.signal_requested, "crossing remains usable after all six main missions")
	world.signal_clock = 0.9
	world._request_crossing()
	_check(is_equal_approx(world.signal_clock, 0.9), "repeated presses do not postpone the pending green phase")
	world.signal_requested = false
	world.player.position = Vector3(110, 0.2, -7)
	world._request_crossing()
	_check(world.signal_requested, "free exploration can request a crossing from the opposite side")
	world.signal_requested = false
	world.driving = true
	world._request_crossing()
	_check(not world.signal_requested, "a driver cannot press a pedestrian button")
	world.driving = false
	world.save_blocked = true
	world._request_crossing()
	_check(not world.signal_requested, "a blocked original save cannot change crossing state")
	world.save_blocked = false
	var real_post: Node3D = world.friend_post
	var spy := FriendSpy.new()
	world.add_child(spy)
	world.friend_post = spy
	world.player.position = Vector3(90, 0.1, 20)
	world._interact()
	_check(spy.calls == 1, "normal World interaction reaches optional residents after the main chapter")
	world.paused = true
	world._interact()
	world.paused = false
	world.driving = true
	world._interact()
	world.driving = false
	_check(spy.calls == 1, "pause and driving prevent hidden delivery interactions")
	world.friend_post = real_post
	var path := "user://lumo_team_b_support_test_%d.json" % Time.get_ticks_usec()
	world.save_path = path
	world.player.position = Vector3(90, 0.1, 20)
	_check(world.friend_post.model.pickup(world.player.position, true), "an actual parcel can enter the original World save")
	_check(world._save(), "World atomically saves the main chapter and optional delivery together")
	var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(restored.has("friendPost") and restored.friendPost.active == "seeds_for_bruno", "saved World envelope contains the carried parcel")
	_check(restored.completed.size() == 6, "optional delivery preserves all main mission records")
	_check(not world.save_pending, "successful save clears the pending retry")
	var original: Variant = {"version": 99, "completed": ["future-delivery"], "futurePayload": {"keep": "unchanged"}}
	original = JSON.parse_string(JSON.stringify(original))
	_check(not world.friend_post.setup(world, original), "unknown sidequest format is unavailable")
	world.friend_post_original = original
	_check(world._save(), "valid main-world progress still saves beside an unknown sidequest version")
	restored = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(restored.friendPost == original, "unknown sidequest data is preserved instead of replaced by a fresh game")
	world.save_path = "user://lumo_team_b_missing_%d/world.json" % Time.get_ticks_usec()
	_check(not world._save(), "a real file-open failure does not report a saved world")
	_check(world.save_pending, "failed saving remains pending even without further walking")
	world.save_path = path
	_check(world._save() and not world.save_pending, "retry saves the retained state and clears the pending flag")
	DirAccess.remove_absolute(path)
	world.free()
	print("[WorldSupport] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
