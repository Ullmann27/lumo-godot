extends SceneTree

const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var entries := ROSTER.all()
	var expected := ["lion", "owl", "rabbit", "squirrel", "turtle", "frog", "otter", "badger", "cat"]
	_check(entries.size() == expected.size(), "Nine shared production opponents are registered.")
	for index in range(mini(entries.size(), expected.size())):
		var entry: Dictionary = entries[index]
		_check(entry.id == expected[index], "Stable canonical identity " + str(index))
		if entry.has("reference"):
			_check(FileAccess.file_exists("res://assets/characters/rivals/reference/originals/" + str(entry.reference)), "Original reference exists.")
		if entry.has("geometryInput"):
			_check(FileAccess.file_exists("res://assets/characters/rivals/" + str(entry.geometryInput)), "Single-character geometry input exists.")
		if entry.has("materialInput"):
			_check(FileAccess.file_exists("res://assets/characters/rivals/" + str(entry.materialInput)), "Material reference exists.")
		if entry.has("flutterPortrait"):
			_check(str(entry.flutterPortrait).begins_with("assets/rivals/portraits/"), "Shared portrait path.")
		_check(str(entry.godotModel) == "res://assets/kart/production/drivers/%s/driver.glb" % str(entry.id), "Bounded production model path.")
		_check(ROSTER.can_use_racing_model(str(entry.id)), "All three production LODs are imported: " + str(entry.id))
		for level in range(3):
			_check(ROSTER.racing_model_path(str(entry.id), level) == str(entry.godotLods[level]), "Stable authored LOD path.")
	var expected_counts := {"kart": 9, "lumo_cards": 9, "connect_four": 5}
	for game in expected_counts:
		var count: int = int(expected_counts[game])
		_check(ROSTER.for_game(game).size() == count, game + " has the expected roster size.")
		for round_index in range(-2, 9):
			var order := ROSTER.rotation(game, round_index)
			_check(order.size() == count, "Rotation preserves count.")
			var seen: Dictionary = {}
			for item in order:
				seen[item.id] = true
			_check(seen.size() == count, "Rotation has no duplicated opponent.")
	_check(ROSTER.for_game("writing_coach").is_empty(), "No invented enemies in a learning exercise.")
	_check(not ROSTER.can_use_racing_model("unknown"), "Unknown model is not usable.")
	_check(ROSTER.racing_model_path("unknown").is_empty(), "Unknown identity cannot select a driver resource.")
	_check(ROSTER.ready_for_race(), "All nine validated production opponents are ready for the race.")
	_check(ROSTER.all()[2].id == "rabbit" and ROSTER.all()[2].name == "Nova", "Existing Nova identity is preserved.")
	print("[OpponentRoster] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
