extends SceneTree
# gdlint: disable=function-name
# The explicit fixture implements the existing Android bridge method names.
## Real process/render timing of the routed scene; software audio uses a PCM
## fixture through AudioStreamPlayer. Dummy output is not physical Android TTS.

const WORLD := "res://scenes/learning/learning_world.tscn"
const SAMPLE_RATE := 16000
var capture_directory := ""


class MeasuredAudioHost:
	extends Node
	var source := AudioStreamPlayer.new()
	var request: Dictionary = {}
	var samples := PackedByteArray()
	var state := "idle"

	func _ready() -> void:
		# A deterministic, real 12-second PCM signal; no guessed speech timing.
		samples.resize(16000 * 12)
		for index in range(samples.size()):
			var value := int(45.0 * sin(TAU * 440.0 * float(index) / 16000.0))
			samples[index] = value & 255
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_8_BITS
		stream.mix_rate = 16000
		stream.data = samples
		source.stream = stream
		add_child(source)
		source.finished.connect(func(): state = "completed")

	func speakLearning(wire: String) -> int:
		request = JSON.parse_string(wire)
		state = "playing"
		source.play()
		return 1

	func stopLearningSpeech() -> void:
		state = "idle"
		source.stop()

	func getLearningSpeechStatus() -> String:
		var packet := request.duplicate(true)
		packet.erase("text")
		var position := maxf(0.0, source.get_playback_position())
		var energy := 0.0
		var begin := mini(samples.size() - 256, int(position * 16000.0))
		for index in range(begin, begin + 256):
			var value := (
				float(samples[index] if samples[index] < 128 else samples[index] - 256) / 128.0
			)
			energy += value * value
		var envelope := sqrt(energy / 256.0)
		var playing := source.playing and not source.stream_paused
		var audible := playing and not AudioServer.is_bus_mute(0) and envelope > 0.0
		packet.merge(
			{
				"state": "playing" if playing else state,
				"positionMs": position * 1000.0,
				"audible": audible,
				"envelopeAvailable": playing,
				"envelope": envelope if audible else 0.0
			},
			true
		)
		return JSON.stringify(packet)


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_directory = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(412, 915)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var host := MeasuredAudioHost.new()
	root.add_child(host)
	var game = (load(WORLD) as PackedScene).instantiate()
	game.capture_options = {
		"learning":
		{
			"kind": "bridge_ten",
			"a": 8,
			"b": 5,
			"protocolVersion": 1,
			"sessionId": "software-perf-fixture",
			"taskId": "eight-plus-five",
			"revision": 1,
			"cancelEpoch": 0,
			"stepId": "start",
			"allowedActions": ["explain", "repeat", "hint", "point", "stop"]
		},
		"learningVoiceEnabled": true,
		"localVoiceLicenseAccepted": true,
		"learningAutoRead": false,
		"reduceAnimations": false
	}
	game._speech_host = host
	root.add_child(game)
	await process_frame
	if not game.fox.is_usable():
		push_error("[NextgenPerfCapture] actual routed actor is not usable")
		quit(1)
		return
	print(
		(
			"LUMO_PERF_FIXTURE "
			+ JSON.stringify(
				{
					"audio": "generated_440_hz_pcm_through_AudioStreamPlayer",
					"output_driver": "Dummy",
					"physical_android_audio": false,
					"duration_seconds": 12.0,
					"sample_rate_hz": SAMPLE_RATE
				}
			)
		)
	)
	game._speak(game.explanation.text)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 22000 and game._frame_probe.get("_window_index") < 3:
		await process_frame
		if game._speech_state == "completed":
			game._voice_action()
	var windows: int = game._frame_probe.get("_window_index")
	game._explicit_stop()
	if not capture_directory.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_directory)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			capture_directory.path_join("bridge_ten_perf_412x915.png")
		)
	game.queue_free()
	host.queue_free()
	await process_frame
	print(
		"[NextgenPerfCapture] %s actual_windows=%d" % ["PASS" if windows >= 3 else "FAIL", windows]
	)
	quit(0 if windows >= 3 else 1)
