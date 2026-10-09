extends SceneTree
## Rival items must be readable and dodgeable, not invisible instant AI hits.

var scene: PackedScene
var game


func _initialize() -> void:
	call_deferred("_run")


func _has_property(object: Object, property_name: String) -> bool:
	for info in object.get_property_list():
		if str(info.name) == property_name:
			return true
	return false


func _start_race() -> void:
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "gemuetlich",
		}
	)
	game.countdown = 0.0
	game.racing = true
	await process_frame


func _gap(index: int) -> Vector3:
	return game.player.position - game.opponents[index].position


func _run() -> void:
	scene = load("res://scenes/games/kart_island.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	await _start_race()

	assert(
		_has_property(game, "opponent_pulse_warning_times"),
		"Rival pulse needs an explicit warning window before it can hit the player."
	)
	assert(
		_has_property(game, "opponent_item_fx"),
		"Rival items need visible world-space feedback, not HUD text alone."
	)
	assert(game.opponent_item_fx.size() == game.opponents.size())

	# A nearby rival pulse starts a warning and does not hit on the same frame.
	game.hit_timer = 0.0
	game.shield_time = 0.0
	game.opponents[0].position = game.player.position + Vector3.RIGHT * 4.0
	game.opponent_items[0] = "pulse"
	game._update_rival_item_tactics(0, _gap(0), 0.01)
	assert(game.opponent_pulse_warning_times[0] > 0.0)
	assert(game.hit_timer == 0.0, "AI pulse must never be an invisible instant hit.")
	var warning_state: Dictionary = game.opponent_item_fx[0].visual_state()
	assert(bool(warning_state.warning_visible))
	assert(not bool(warning_state.pulse_visible))

	# Moving away during the warning must dodge the pulse.
	game.opponents[0].position = game.player.position + Vector3.RIGHT * 18.0
	game._update_rival_item_tactics(0, _gap(0), 1.0)
	assert(game.hit_timer == 0.0, "Leaving the pulse radius during telegraph must avoid the hit.")
	var fired_state: Dictionary = game.opponent_item_fx[0].visual_state()
	assert(bool(fired_state.pulse_visible))

	# A shield also blocks a completed rival pulse.
	game.hit_timer = 0.0
	game.shield_time = 4.0
	game.opponents[0].position = game.player.position + Vector3.RIGHT * 4.0
	game.opponent_items[0] = "pulse"
	game.opponent_pulse_warning_times[0] = 0.0
	game._update_rival_item_tactics(0, _gap(0), 0.01)
	assert(game.opponent_pulse_warning_times[0] > 0.0)
	game._update_rival_item_tactics(0, _gap(0), 1.0)
	assert(game.hit_timer == 0.0, "Player shield must block a rival pulse after its warning.")

	# Rival shield has visible feedback and a bounded duration.
	game.shield_time = 0.0
	game.opponent_items[0] = "shield"
	game.opponents[0].position = game.player.position + Vector3.RIGHT * 3.0
	game._update_rival_item_tactics(0, _gap(0), 0.01)
	assert(game.opponent_shield_times[0] > 0.0 and game.opponent_shield_times[0] <= 5.0)
	var shield_state: Dictionary = game.opponent_item_fx[0].visual_state()
	assert(bool(shield_state.shield_visible))

	# Boost remains bounded and the held-item indicator disappears when consumed.
	game.distance = 12.0
	game.opponent_distances[0] = 0.0
	game.opponent_items[0] = "boost"
	game._update_rival_item_tactics(0, _gap(0), 0.01)
	assert(game.opponent_boost_times[0] > 0.0 and game.opponent_boost_times[0] <= 2.2)
	var boost_state: Dictionary = game.opponent_item_fx[0].visual_state()
	assert(str(boost_state.held_item).is_empty())

	game.abandoned = true
	game.queue_free()
	await process_frame
	print("[KartRivalFeedback] PASS: telegraph, dodge, shield block, visible rival shield, bounded boost")
	await create_timer(0.1).timeout
	quit(0)
