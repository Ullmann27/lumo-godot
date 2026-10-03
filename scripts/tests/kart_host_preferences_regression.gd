extends SceneTree
## Native app preferences are an upper bound, while local choices remain durable.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var preferences := ConfigFile.new()
	preferences.set_value("race", "muted", false)
	preferences.set_value("race", "reduced_motion", false)
	preferences.save("user://kart_preferences.cfg")
	var bridge = root.get_node("HostBridge")
	bridge._options = {"soundEnabled": false, "reduceAnimations": true}
	var scene: PackedScene = load("res://scenes/games/kart_island.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(game.reduced_motion and not game.preferred_reduced_motion)
	assert(not game.muted and not game.host_sound_enabled)
	assert(game.kart_audio._muted and not game.engine_player.playing)
	assert(game.garage.reduced_motion)
	game._save_preferences()
	preferences.load("user://kart_preferences.cfg")
	assert(not bool(preferences.get_value("race", "muted")))
	assert(not bool(preferences.get_value("race", "reduced_motion")), "Host preferences must not overwrite a local preference")
	game.abandoned = true
	game.queue_free()
	await process_frame
	bridge._options = {"soundEnabled": true, "reduceAnimations": false}
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	assert(not game.reduced_motion and not game.kart_audio._muted)
	game.lightweight = true
	game._start_selected_race({"mode": "training", "track": "sonnenhafen"})
	game.countdown = 0
	game.racing = true
	game._update_audio()
	assert(game.engine_player.playing)
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(game.paused and not game.engine_player.playing and game.kart_audio._paused)
	game._resume()
	assert(not game.paused and game.engine_player.playing)
	game.abandoned = true
	game.queue_free()
	await process_frame
	bridge._options = {}
	print("[KartHostPreferences] PASS: native mute/motion constraints, preserved local settings, all audio stops on focus loss")
	# AudioServer releases stopped stream playbacks on its asynchronous mix thread.
	await create_timer(0.12).timeout
	quit(0)
