extends SceneTree
## Save compatibility of Sonnenhafen in the production World:
## 1. a Build-2082 World save without a "sonnenhafen" section opens unchanged,
##    gains a fresh region and keeps every older section byte-for-byte;
## 2. new region progress (missions, purse, basket, crates, delivery, learning
##    request, resident memory) survives save and re-entry exactly;
## 3. damaged or future region data is rejected as a whole, the World stays
##    playable and the stored section is kept unchanged.
const STATE = preload("res://scripts/creative/lumo_world_state.gd")
const PROFILE := "lumo_c12_sonnenhafen_saves"
var checks := 0
var failures: Array[String] = []
var scene: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[SonnenhafenSaves] " + label)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _path() -> String:
	return "user://lumo_world_" + PROFILE.sha256_text().substr(0, 32) + ".json"


func _write(data: Dictionary) -> void:
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read() -> Dictionary:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	return raw if raw is Dictionary else {}


## JSON numbers come back as floats: compare both sides after one round trip.
func _norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _enter() -> bool:
	var router: Node = root.get_node("SceneRouter")
	router.launch_options = {"childKey": PROFILE, "grade": 3, "reduceAnimations": true}
	router.goto("world")
	await _frames(40)
	scene = current_scene
	return is_instance_valid(scene) and scene.name == "LumoWorld"


## A World save exactly as Build 2082 wrote it: chapter one, kart, Freundepost
## and open-world progress, but no Sonnenhafen section.
func _legacy() -> Dictionary:
	var model = STATE.new()
	model.completed.assign(["meet_nelli", "safe_crossing"])
	model.position = Vector3(112, 0.2, -10)
	model.result_id = "legacy-2082-result"
	var data: Dictionary = model.to_data()
	data["friendPost"] = {}
	data["openWorld"] = {
		"version": 1,
		"progress": {"flaschenpost": 2, "kartenclub": 0, "kart_kurier": 0, "markt_aepfel": 1},
		"tracked": "flaschenpost",
		"visited": ["hafensteg", "markt"],
		"cards": []
	}
	return data


func _run() -> void:
	root.size = Vector2i(2176, 1812)
	# --- 1 Legacy save ---------------------------------------------------------
	var legacy := _legacy()
	_write(legacy)
	_check(await _enter(), "legacy World save opens the production World")
	_check(not scene.save_blocked, "legacy save is not blocked")
	_check(scene.model.completed == ["meet_nelli", "safe_crossing"], "chapter-one progress is kept")
	_check(
		(
			int(scene.open_world.model.progress.flaschenpost) == 2
			and scene.open_world.model.tracked == "flaschenpost"
		),
		"open-world progress is kept"
	)
	var harbour: Node = scene.sonnenhafen
	_check(
		harbour.save_valid and harbour.unlocked(), "Sonnenhafen starts fresh for a legacy profile"
	)
	_check(
		harbour.wallet == harbour.START_SHELLS and harbour.model.cards().is_empty(),
		"no invented region progress for a legacy profile"
	)
	for mission_id in harbour.model.mission_ids():
		_check(
			harbour.model.state(mission_id) == "available",
			"region mission starts available: " + mission_id
		)
	_check(scene._save(), "legacy profile saves again")
	var upgraded := _read()
	for key in ["version", "completed", "pendingLesson", "resultId"]:
		_check(
			_norm(upgraded.get(key)) == _norm(legacy.get(key)),
			"older field stays identical after save: " + key
		)
	for key in ["progress", "tracked"]:
		_check(
			_norm(upgraded.openWorld.get(key)) == _norm(legacy.openWorld.get(key)),
			"open-world progress stays identical: " + key
		)
	for place in legacy.openWorld.visited:
		_check(place in upgraded.openWorld.visited, "discovered place is kept: " + str(place))
	_check(
		upgraded.get("kart") is Dictionary and upgraded.get("friendPost") is Dictionary,
		"kart and Freundepost sections are still written"
	)
	_check(
		upgraded.get("sonnenhafen") is Dictionary and int(upgraded.sonnenhafen.version) == 1,
		"the save gains a versioned Sonnenhafen section"
	)

	# --- 2 New progress round trip ----------------------------------------------
	var model = harbour.model
	var ida: Vector3 = harbour.crowd.position_of("ida")
	_check(
		model.complete("hafen_willkommen", "meet_ida", ida, false).ok,
		"first region step completes at Ida"
	)
	harbour.wallet = 23
	harbour.inventory = {"fisch": 2, "seil": 1}
	harbour.fish_crates = 2
	harbour.carrying = {"kind": "delivery", "order": 3}
	harbour.delivery_index = 3
	harbour.deliveries_done = 4
	harbour.pending_lesson = {
		"version": 1,
		"id": "school_numbers",
		"requestId": "harbour_roundtrip_1234",
		"subject": "Mathematik",
		"grade": 3,
		"returnGame": "world"
	}
	harbour.crowd.brain_of("jonte").remember("delivered", "Jonte", "blaue Bootsfarbe")
	harbour.crowd.brain_of("ida").remember("heard", "Jonte", "")
	var expected: Dictionary = harbour.to_data()
	_check(scene._save(), "new progress saves")
	_check(await _enter(), "World reopens after saving region progress")
	harbour = scene.sonnenhafen
	_check(harbour.save_valid, "saved region progress is valid")
	var restored: Dictionary = harbour.to_data()
	for key in [
		"quests",
		"wallet",
		"inventory",
		"fishCrates",
		"carry",
		"deliveryIndex",
		"deliveriesDone",
		"pendingLesson",
		"rewarded"
	]:
		_check(
			_norm(restored.get(key)) == _norm(expected.get(key)),
			"region field survives re-entry: " + key
		)
	_check(
		(
			harbour.crowd.brain_of("jonte").knows("delivered")
			and harbour.crowd.brain_of("ida").knows("heard", "Jonte")
		),
		"resident memories survive re-entry"
	)
	_check(
		int(scene.open_world.model.progress.flaschenpost) == 2,
		"older open-world progress is still intact"
	)

	# --- 3 Damaged and future sections ----------------------------------------------
	for damage in [
		{"wallet": -5},
		{"wallet": 5000},
		{"inventory": {"goldbarren": 1}},
		{"inventory": {"fisch": 1.5}},
		{"carry": {"kind": "teleport"}},
		{"rewarded": ["frischer_fang"]},
		{"version": 2},
		{
			"pendingLesson":
			{
				"version": 1,
				"id": "school_numbers",
				"requestId": "x",
				"subject": "Mathematik",
				"grade": 2,
				"returnGame": "world"
			}
		},
		{"quests": {"version": 1, "progress": {"hafen_willkommen": 99}}}
	]:
		var data := _read()
		var section: Dictionary = data.sonnenhafen.duplicate(true)
		section.merge(damage, true)
		data["sonnenhafen"] = section
		_write(data)
		_check(await _enter(), "World opens with damaged region data " + JSON.stringify(damage))
		_check(
			not scene.save_blocked and not scene.sonnenhafen.save_valid,
			"damaged region data is rejected as a whole " + JSON.stringify(damage)
		)
		_check(
			scene.status_label.text.contains("Sonnenhafen"),
			"the child is told calmly that Sonnenhafen could not load"
		)
		_check(scene._save(), "the rest of the World still saves")
		_check(
			_norm(_read().sonnenhafen) == _norm(section),
			"damaged region section is kept unchanged " + JSON.stringify(damage)
		)
		_check(
			int(_read().openWorld.progress.flaschenpost) == 2, "other sections keep saving normally"
		)
		data["sonnenhafen"] = expected
		_write(data)
	_finish()


func _finish() -> void:
	print("[SonnenhafenSaves] %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
