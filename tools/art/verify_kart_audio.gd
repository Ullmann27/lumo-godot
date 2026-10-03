extends SceneTree
## Headless regression of the real controller: all originals decode, mute/pause
## and application focus do not accidentally resume blocked music.
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)

func _run() -> void:
	var controller: Node = load("res://scripts/games/kart_audio.gd").new()
	root.add_child(controller)
	controller.set_muted(true)
	controller.play_menu()
	await process_frame
	_check(controller.get_child_count() == 6, "bounded two-music/four-effect pool")
	for key in ["garage", "sonnenhafen", "zauberwald", "bergwelt", "holo_city"]:
		var stream: AudioStreamOggVorbis = controller._load_stream(key, true)
		_check(stream != null and stream.get_length() > 10.0, "music decodes: " + key)
		_check(stream.loop, "music loops: " + key)
	for key in controller.EFFECTS:
		var stream: AudioStreamOggVorbis = controller._load_stream(key, false)
		_check(stream != null and stream.get_length() > 0.1, "effect decodes: " + key)
		_check(not stream.loop, "effect never loops: " + key)
	_check(controller._music[controller._active].stream_paused, "initial mute silences music")
	controller.set_muted(false)
	controller.set_paused(true)
	_check(controller._music[controller._active].stream_paused, "pause silences music")
	controller.set_paused(false)
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(controller._music[controller._active].stream_paused, "focus loss silences music")
	controller.set_muted(true)
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_check(controller._music[controller._active].stream_paused, "focus restore retains user mute")
	controller.set_muted(false)
	controller._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(controller._music[controller._active].stream_paused, "Android background silences music")
	controller._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(not controller._music[controller._active].stream_paused, "resume restores permitted playback")
	controller.play_track("arena")
	_check(controller._current == "holo_city", "arena maps to its score")
	controller.set_paused(true)
	controller.effect("start")
	for player in controller._effects:
		_check(not player.playing, "blocked effects do not play")
	controller.queue_free()
	await process_frame
	print("KART_AUDIO_CHECK failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
