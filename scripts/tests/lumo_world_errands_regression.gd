extends SceneTree
## Real delivery rules, finite-distance checks, optional hints and atomic save
## restoration. This test does not claim rendered World or Android evidence.

const STATE = preload("res://scripts/creative/lumo_world_errands.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error("[LumoWorldErrands] " + description)


func _run() -> void:
	var first = STATE.new()
	var source: Vector3 = STATE.FRIENDS.nelli.at
	var recipient: Vector3 = STATE.FRIENDS.bruno.at
	_check(not first.pickup(source, false), "chapter completion is required to collect post")
	_check(first.guidance(false).is_empty() and first.summary(1, false).is_empty(), "locked errands do not replace chapter guidance")
	_check(not first.deliver(recipient, true), "visiting a destination before pickup earns no stamp")
	_check(not first.pickup(recipient, true), "only the current sender can hand over a parcel")
	_check(not first.pickup(source + Vector3(0, 10, 0), true), "vertical teleport is not a nearby pickup")
	_check(not first.pickup(source + Vector3(4.6, 0, 0), true), "outside the interaction radius cannot collect")
	for invalid_position in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0), Vector3(90, NAN, 20), Vector3(90, 0, INF)]:
		_check(STATE.friend_at(invalid_position).is_empty(), "non-finite position has no nearby resident")
	_check(first.pickup(source + Vector3(0, 0.1, 0), true), "normal grounded position can collect")
	_check(not first.deliver(recipient, false), "loading an unfinished chapter cannot bypass the unlock")
	var immutable_route: Dictionary = first.current(2)
	immutable_route.clues[0] = "changed outside the model"
	_check(first.clue(1) != "changed outside the model", "returned route data does not mutate authored clues")
	_check(first.current().kind == "friend_post" and first.current().at == recipient, "route exposes consistent World metadata")
	_check(not first.clue(-10).is_empty() and first.clue(99) == first.clue(4), "grade boundaries are clamped")
	for grade in range(1, 5):
		_run_round(grade)
	_corrupt_saves()
	_profile_state_isolation()
	print("[LumoWorldErrands] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _run_round(grade: int) -> void:
	var model = STATE.new()
	for index in range(STATE.ERRANDS.size()):
		var delivery: Dictionary = model.current(grade)
		var from: Vector3 = STATE.FRIENDS[str(delivery.sender)].at
		var to: Vector3 = STATE.FRIENDS[str(delivery.recipient)].at
		_check(not str(delivery.lead).is_empty() and not model.clue(grade).is_empty(), "grade %d route %d has a clue" % [grade, index])
		_check(model.guidance(true).at == from, "uncollected parcel guides to its actual sender")
		_check(model.pickup(from, true), "correct sender accepts the current pickup")
		_check(not model.pickup(from, true), "double pickup cannot replace the current parcel")
		_check(model.guidance(true).is_empty(), "default marker does not reveal the clue's destination")
		_check(not model.deliver(from, true), "returning to the sender does not deliver the parcel")
		for id in STATE.FRIENDS:
			if id != str(delivery.recipient):
				_check(not model.deliver(STATE.FRIENDS[id].at, true), "wrong recipient cannot consume the parcel")
		_check(model.carrying() and model.completed.size() == index, "wrong attempts keep parcel and existing stamps")
		var restored = STATE.new()
		_check(restored.restore(JSON.parse_string(JSON.stringify(model.to_data()))), "carried parcel survives an actual JSON round trip")
		_check(restored.active_id == model.active_id and restored.completed == model.completed, "restore preserves exact delivery progress")
		_check(restored.show_destination(true), "explicit help is available without penalty")
		_check(restored.guidance(true).at == to, "help marks the actual recipient")
		var helped = STATE.new()
		_check(helped.restore(JSON.parse_string(JSON.stringify(restored.to_data()))) and helped.destination_shown, "requested guidance survives restart")
		_check(not helped.deliver(to + Vector3(0, 5.0, 0), true), "delivery requires actual proximity in three dimensions")
		_check(helped.deliver(to, true), "arrival and handover award exactly one stamp")
		_check(not helped.deliver(to, true), "duplicate handover cannot award another stamp")
		_check(helped.stamps().size() == index + 1 and not helped.carrying(), "handover stores a stamp and clears the carried parcel")
		model = helped
	_check(model.is_complete() and model.current().is_empty(), "three deliveries finish the optional route")
	_check(model.stamps() == ["Gartenfreund", "Brückenbauer", "Guter Nachbar"], "three distinct friendship stamps retain their order")
	_check(not model.pickup(STATE.FRIENDS.nelli.at, true) and not model.show_destination(true), "finished post cannot restart or grant repeats")
	_check(model.guidance(true).is_empty(), "completed post leaves no stale destination marker")
	var completed = STATE.new()
	_check(completed.restore(JSON.parse_string(JSON.stringify(model.to_data()))) and completed.is_complete(), "finished stamp album survives restart")


func _corrupt_saves() -> void:
	var model = STATE.new()
	model.pickup(STATE.FRIENDS.nelli.at, true)
	var before := JSON.stringify(model.to_data())
	var corrupt: Array = [
		null, [], "invalid", {"version": 1},
		{"version": true, "completed": []},
		{"version": 1.5, "completed": []},
		{"version": 2, "completed": []},
		{"version": 1, "completed": "seeds_for_bruno"},
		{"version": 1, "completed": ["picnic_for_nelli"]},
		{"version": 1, "completed": ["seeds_for_bruno", "seeds_for_bruno"]},
		{"version": 1, "completed": ["seeds_for_bruno", "invitation_for_tilda", "picnic_for_nelli", "extra"]},
		{"version": 1, "completed": [], "active": "invitation_for_tilda"},
		{"version": 1, "completed": [], "active": 0},
		{"version": 1, "completed": [], "active": "", "destinationShown": true},
		{"version": 1, "completed": [], "active": "seeds_for_bruno", "destinationShown": "true"},
		{"version": 1, "completed": ["seeds_for_bruno", "invitation_for_tilda", "picnic_for_nelli"], "active": "seeds_for_bruno"}
	]
	for raw in corrupt:
		_check(not model.restore(raw), "malformed or out-of-order post save is rejected")
		_check(JSON.stringify(model.to_data()) == before, "rejected restore leaves the original state intact")
	_check(model.restore({}), "older World save without post section is supported")
	_check(not model.carrying() and model.completed.is_empty(), "older profile starts with an empty post album")


func _profile_state_isolation() -> void:
	var first = STATE.new()
	first.pickup(STATE.FRIENDS.nelli.at, true)
	first.deliver(STATE.FRIENDS.bruno.at, true)
	var saved: Dictionary = first.to_data()
	var second = STATE.new()
	_check(second.completed.is_empty() and not second.carrying(), "new profile has its own empty progress")
	_check(second.restore(saved), "independent model can restore a profile snapshot")
	saved.completed.clear()
	_check(first.completed.size() == 1 and second.completed.size() == 1, "mutable save payload cannot corrupt either profile model")
	second.pickup(STATE.FRIENDS.bruno.at, true)
	_check(second.carrying() and not first.carrying(), "independent instances never share active delivery state")
