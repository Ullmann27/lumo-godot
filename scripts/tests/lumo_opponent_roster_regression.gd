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
	_check(entries.size() == 5, "Exactly five reference opponents, not the track image.")
	var expected := ["lion", "owl", "rabbit", "squirrel", "turtle"]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		_check(entry.id == expected[index], "Stable canonical identity " + str(index))
		_check(FileAccess.file_exists("res://assets/characters/rivals/reference/originals/" + str(entry.reference)), "Original reference exists.")
		_check(FileAccess.file_exists("res://assets/characters/rivals/" + str(entry.geometryInput)), "Single-character geometry input exists.")
		_check(FileAccess.file_exists("res://assets/characters/rivals/" + str(entry.materialInput)), "Material reference exists.")
		_check(str(entry.godotModel).begins_with("res://assets/characters/rivals/"), "Bounded local model path.")
		_check(str(entry.flutterPortrait).begins_with("assets/rivals/portraits/"), "Shared portrait path.")
	for game in ["kart", "lumo_cards", "connect_four"]:
		_check(ROSTER.for_game(game).size() == 5, game + " reuses the same five identities.")
		for round_index in range(-2, 9):
			var order := ROSTER.rotation(game, round_index)
			_check(order.size() == 5, "Rotation preserves count.")
			var seen: Dictionary = {}
			for item in order:
				seen[item.id] = true
			_check(seen.size() == 5, "Rotation has no duplicated opponent.")
	_check(ROSTER.for_game("writing_coach").is_empty(), "No invented enemies in a learning exercise.")
	_check(not ROSTER.can_use_racing_model("unknown"), "Unknown model is not usable.")
	_check(ROSTER.all()[2].id == "rabbit" and ROSTER.all()[2].name == "Nova", "Existing Nova identity is preserved.")
	print("[OpponentRoster] checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
