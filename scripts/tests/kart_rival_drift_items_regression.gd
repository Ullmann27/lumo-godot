extends SceneTree
## Production driving earns the drift charge used by resonance, then item
## tactics affect nearby rivals as well as the player with the same warning.
const STEP: float = 1.0 / 60.0
var game
var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("[KartRivalDrift] " + message)


func _run() -> void:
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.lightweight = true
	await process_frame
	game._start_selected_race(
		{
			"mode": "race",
			"driver": "fox",
			"kart": "comet",
			"track": "sonnenhafen",
			"difficulty": "pro"
		}
	)
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	await process_frame
	game.item_box_distances.clear()
	game.distance = 1200.0
	game.player.transform = game.world.reset_transform(game.distance, 0.0)
	game.speed = 0.0
	var maximum_charge: float = 0.0
	var frames: int = 0
	for frame in range(2400):
		game.elapsed += STEP
		game._drive_opponents(STEP)
		frames = frame + 1
		maximum_charge = maxf(
			maximum_charge, float(game.opponents[0].get_meta("racecraft_drift_charge", 0.0))
		)
		if maximum_charge >= 1.0:
			break
	_check(maximum_charge >= 1.0, "Actual road driving must earn a sustained drift charge")
	print(
		(
			"[KartRivalDrift] charge %.3f earned after %.2fs of production driving"
			% [maximum_charge, frames * STEP]
		)
	)
	# A resonance gate is placed on the observed driven line. It is crossed
	# through the same production pickup geometry and scoring path as all gates;
	# no item or charge is injected into the racer.
	var road: Dictionary = game.world.sample_road(
		game.opponents[0].position, fposmod(game.opponent_distances[0], game.track_length)
	)
	game.item_box_distances.append(float(road.distance))
	game.item_box_laterals[0] = float(road.lateral)
	game.item_boxes[0].position = game.opponents[0].position + Vector3.UP
	game.opponent_items[0] = ""
	game.opponent_item_cooldowns[0] = 0.0
	# Move the other racers away so the newly earned item is held for inspection.
	for i in range(1, game.opponents.size()):
		game.opponents[i].position += Vector3(100.0, 0.0, 100.0)
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, STEP)
	_check(
		game.opponent_items[0] == "pulse",
		"Controlled real drift must be able to earn gold resonance"
	)
	game.item_box_distances.clear()
	# The item is used against another rival even while the human is far away.
	game.opponents[1].position = game.opponents[0].position + Vector3.RIGHT * 4.0
	game.opponent_shield_times[1] = 0.0
	game.opponent_stuns[1] = 0.0
	game.opponents[2].position = game.opponents[0].position + Vector3.LEFT * 4.0
	game.opponent_shield_times[2] = 2.0
	game.opponent_stuns[2] = 0.0
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, STEP)
	_check(
		game.opponent_pulse_warning_times[0] > 0.0,
		"Rival versus rival pulse must warn before impact"
	)
	_check(game.opponent_stuns[1] == 0.0, "Warning must not apply an instant hit")
	game._update_rival_item_tactics(0, game.player.position - game.opponents[0].position, 0.70)
	_check(game.opponent_stuns[1] > 0.0, "Earned pulse must affect a nearby unshielded opponent")
	_check(game.opponent_stuns[2] == 0.0, "Opponent shield must block the same pulse")
	# Continue real driving until the drift is released. A mini-turbo is earned
	# by leaving the actual corner; this does not require an item or player lead.
	var boosted: bool = false
	for _frame in range(900):
		game.elapsed += STEP
		game._drive_opponents(STEP)
		if game.opponent_boost_times[0] > 0.0:
			boosted = true
			break
	_check(boosted, "Controlled drift release must grant an actual mini-turbo")
	var playbacks: Array[WeakRef] = []
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	game.abandoned = true
	game.queue_free()
	await process_frame
	game = null
	_check(await _release_audio(playbacks), "Audio playback retained after scene teardown")
	if not failed:
		print("[KartRivalDrift] PASS: earned drift, gold pickup, fair pulse, shield and mini-turbo")
	quit(1 if failed else 0)


func _release_audio(playbacks: Array[WeakRef]) -> bool:
	# Scene destruction stops audio, but mixer-side fadeout retires later.
	# Observe actual playbacks without retaining them or ignoring exit errors.
	var started := Time.get_ticks_msec()
	while true:
		var pending := 0
		for playback: WeakRef in playbacks:
			if playback.get_ref() != null:
				pending += 1
		if pending == 0:
			print(
				"[KartRivalDrift] audio_release tracked=%d elapsed_ms=%d"
				% [playbacks.size(), Time.get_ticks_msec() - started]
			)
			return true
		if Time.get_ticks_msec() - started >= 2000:
			printerr("[KartRivalDrift] retained_audio_playbacks=", pending)
			return false
		OS.delay_msec(2)
		await process_frame
	return false
