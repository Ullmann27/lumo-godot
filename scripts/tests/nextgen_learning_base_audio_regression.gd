extends SceneTree
## Exercises the original Base/Fox path independently of the Next subclass.
const BASE := "res://scripts/learning/learning_world.gd"
const ORIGINAL_FOX := "res://scripts/characters/lumo/lumo_rigged_actor.gd"
const ROUTE_REVIEW = preload("res://scripts/tests/nextgen_learning_route_review.gd")
const FRAME_PROBE = preload("res://scripts/learning/learning_frame_probe.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[NextgenBaseAudio] " + message)


func _run() -> void:
	root.size = Vector2i(412, 915)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var source := load(BASE) as GDScript
	_check(source != null and source.can_instantiate(), "the original Base script compiles")
	if source == null or not source.can_instantiate():
		_finish()
		return
	var game = source.new()
	var host = ROUTE_REVIEW.SpeechHost.new()
	game.capture_options = {
		"learning":
		{
			"kind": "syllables",
			"word": "Banane",
			"syllables": ["Ba", "na", "ne"],
			"protocolVersion": 1,
			"sessionId": "base-qa",
			"taskId": "banane",
			"revision": 1,
			"cancelEpoch": 0,
			"stepId": "word",
			"allowedActions": ["explain", "repeat", "stop"]
		},
		"reduceAnimations": false,
		"learningVoiceEnabled": true,
		"localVoiceLicenseAccepted": true,
		"learningAutoRead": false
	}
	game._speech_host = host
	root.add_child(game)
	for index in range(4):
		await process_frame
	game.set_process(false)
	_check(game.get_script().resource_path == BASE, "the test uses the unextended Base")
	_check(game.fox.get_script().resource_path == ORIGINAL_FOX, "the original shared Fox is used")
	_check(game.fox.is_usable(), "the original Fox imports successfully")
	game._turn_id = 7
	game._speak_syllables()
	for segment in range(4):
		_check(
			host.request.text == ["Banane", "Ba", "na", "ne"][segment],
			"Base owns the next real segment request"
		)
		_check(
			game._speech_state == "preparing" and not game.fox.audio_active,
			"Base prepares each segment without fake mouth activity"
		)
		host.measured_playing()
		var valid: Dictionary = host.packet.duplicate(true)
		for bad in [0, -1, float(host.request.id) + 0.5, str(host.request.id)]:
			host.packet = valid.duplicate(true)
			host.packet.id = bad
			game._tick_speech(0.06)
			_check(
				game._speech_state == "preparing" and not game.fox.audio_active,
				"invalid native IDs cannot mutate original Base/Fox"
			)
		for key: String in ["stepId", "sessionId", "taskId", "turnId", "utteranceId"]:
			host.packet = valid.duplicate(true)
			host.packet[key] = 6 if key == "turnId" else "stale"
			game._tick_speech(0.06)
			_check(
				game._speech_state == "preparing" and not game.fox.audio_active,
				"mismatched " + key + " cannot mutate Base/Fox"
			)
		host.packet = valid
		game._tick_speech(0.06)
		_check(
			game._speech_state == "playing" and game.fox.audio_active and game._speech_audible,
			"valid JSON numbers retain the original speech path"
		)
		_check(
			is_equal_approx(game.fox.last_audio_envelope, 0.85),
			"original Fox receives the measured envelope"
		)
		if segment > 0:
			_check(
				game._focus_id == "syllable_%d" % (segment - 1),
				"Base cue corresponds to the audible syllable"
			)
		host.packet.state = "completed"
		host.packet.audible = false
		game._tick_speech(0.06)
		_check(
			not game.fox.audio_active and not game._speech_audible,
			"completion closes original speech state"
		)
	var complete_snapshot: Dictionary = host.packet.duplicate(true)
	var starts: int = host.starts
	game._explicit_stop()
	host.packet = complete_snapshot
	game._tick_speech(0.06)
	_check(
		host.starts == starts and game._speech_segments.is_empty(),
		"late completed status cannot restart stopped Base audio"
	)
	_check(
		game.fox.current_behavior == "idle" and not game.fox.teacher_pose.has_target,
		"common Stop neutralizes the original teacher"
	)
	var probe = game._frame_probe
	probe.reset()
	probe.sample(game, "syllables", false, false, false)
	await process_frame
	probe.sample(game, "syllables", false, false, false)
	_check(
		probe.get("_frames").size() == 1 and probe.get("_frames")[0] > 0.0,
		"probe records an actual monotonic interval"
	)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(
		probe.get("_frames").is_empty() and probe.get("_last_usec") == 0,
		"background discards the partial measurement window"
	)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(
		probe.get("_frames").is_empty() and probe.get("_last_usec") == 0,
		"resume starts a fresh measurement window"
	)
	var series := PackedFloat64Array()
	for number in range(1, 101):
		series.append(float(number))
	var summary: Dictionary = FRAME_PROBE.statistics(series)
	_check(
		summary == {"mean": 50.5, "p50": 50.0, "p95": 95.0, "p99": 99.0, "max": 100.0},
		"nearest-rank percentiles and arithmetic mean have known values"
	)
	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print(
		(
			"[NextgenBaseAudio] %s checks=%d failures=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
