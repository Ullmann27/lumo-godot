extends SceneTree
## Capture both PCM channels after Godot's native mixer. Requires a ticking audio
## driver, e.g. --headless --audio-driver Dummy. Other race audio stays on Master.
const STEP := 1.0 / 60.0
# Spatial playback needs moving emitters and a real listener, but no rival meshes.
class RivalEmitter extends LumoRaceKart:
	func _ready() -> void:
		set_process(false)


var failures: Array[String] = []
var game
var tap := AudioEffectCapture.new()
var recording := PackedByteArray()
var measurements := {}


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error(description)


func _tap(voice, enabled: bool) -> void:
	for source in [voice.body, voice.induction, voice.road]:
		if source:
			source.bus = "MotorCapture" if enabled else "Master"


func _touch(pedal: Control, down: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pedal.size * .5
	event.pressed = down
	pedal._gui_input(event)


func _sample(label: String) -> Dictionary:
	# Scene timers measure simulated time. Wait for actual mixer frames, even
	# after the first expensive race frame or when the CI driver runs slowly.
	var count := roundi(AudioServer.get_mix_rate() * .18)
	for phase in 2:
		tap.clear_buffer()
		var deadline := Time.get_ticks_msec() + 2500
		while tap.get_frames_available() < count and Time.get_ticks_msec() < deadline:
			game.kart_audio.update_motors(game, 0.0)
			await process_frame
	var samples := tap.get_buffer(mini(tap.get_frames_available(), count))
	var left := 0.0
	var right := 0.0
	var variation := 0.0
	var previous := 0.0
	var peak := 0.0
	var raw := PackedByteArray()
	raw.resize(samples.size() * 4)
	for i in samples.size():
		var frame := samples[i]
		left += frame.x * frame.x
		right += frame.y * frame.y
		var mid := (frame.x + frame.y) * .5
		variation += (mid - previous) * (mid - previous)
		previous = mid
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		raw.encode_s16(i * 4, roundi(frame.x * 32767.0))
		raw.encode_s16(i * 4 + 2, roundi(frame.y * 32767.0))
	recording.append_array(raw)
	var rms := sqrt((left + right) / (2.0 * maxi(1, samples.size())))
	var metrics := {"rms": rms, "brightness": sqrt(variation / maxf(.000001, left + right)), "left": left, "right": right, "peak": peak}
	measurements[label] = metrics
	check(samples.size() > 256, "AudioServer delivered PCM for " + label)
	check(peak < .6, "Headroom for " + label)
	return metrics


func _tick(count: int) -> void:
	for i in count:
		game._physics_process(STEP)


func _run() -> void:
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "MotorCapture")
	tap.buffer_length = .6
	AudioServer.add_bus_effect(bus, tap)
	game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.graphics_profile = "low"
	game.lightweight = true
	game.auto_gas = false
	game.reduced_motion = true
	game._start_selected_race({"mode": "training", "track": "sonnenhafen", "kart": "comet", "difficulty": "flott"})
	var audio = game.kart_audio
	audio.set_muted(false)
	audio.set_volumes(0.0, 1.0)
	var player = audio.player_motor
	_tap(player, true)
	_tick(1)
	var idle := await _sample("countdown_idle")
	check(idle.rms > .001, "Actual grid idle is audible")
	check(not game.gas_button.disabled and game.gas_button.visible, "Gas pedal operates on the start grid")
	_touch(game.gas_button, true, 0)
	_tick(32)
	var rev := await _sample("countdown_manual_rev")
	check(game.speed == 0.0 and rev.brightness > idle.brightness * 1.5, "Pedal raises pitch while the grid holds the kart")
	_touch(game.gas_button, false, 0)
	game.countdown = .001
	_touch(game.gas_button, true, 0)
	_tick(32)
	var launch := await _sample("launch")
	check(game.speed > 3.0 and launch.rms > idle.rms * 1.2, "Real launch increases motor load")
	_touch(game.gas_button, false, 0)
	_tick(4)
	var lift := await _sample("lift")
	check(lift.rms < launch.rms * .94, "Lifting unloads the motor")
	_touch(game.brake_button, true, 1)
	_touch(game.gas_button, true, 0)
	_tick(60)
	var held := await _sample("brake_held_rev")
	check(absf(game.speed) < .1 and held.brightness > idle.brightness * 1.5, "Gas against full brake revs at rest")
	_touch(game.gas_button, false, 0)
	_touch(game.brake_button, false, 1)
	# Same load and speed, change only one mounted value or the chassis.
	for setup in [
		["stock", "comet", {}], ["twin", "comet", {"exhaust": "doppel"}],
		["rocket", "comet", {"exhaust": "rakete"}], ["electric", "zuri_volt", {}],
		["heavy", "koloss", {}], ["hybrid", "comet", {"engine": "hybrid"}],
		["short_gear", "comet", {"gearbox": "kurz"}],
	]:
		player.configure(setup[1], setup[2])
		game.gas_held = true
		game.speed = 24.0
		for i in 60:
			audio.update_motors(game, STEP)
		await _sample(setup[0])
	for key in ["twin", "rocket", "electric", "heavy", "hybrid", "short_gear"]:
		check(absf(measurements[key].brightness / measurements.stock.brightness - 1.0) > .045, key + " changes measured spectrum at identical speed")
	_tap(player, false)
	for style in ["boru_rally", "zuri_volt"]:
		var kart := RivalEmitter.new()
		kart.kart_style = style
		game.race_root.add_child(kart)
		game.opponents.append(kart)
	audio.configure_motors(game.player, game.opponents)
	var rival = game.opponents[0]
	for i in game.opponents.size():
		game.opponents[i].global_position = game.player.global_position + Vector3(0, 0, 110 + i)
		_tap(audio.rival_motors[i], true)
	game.camera.global_position = game.player.global_position + Vector3(0, 2, 4)
	game.camera.look_at(game.player.global_position)
	rival.global_position = game.player.global_position + Vector3(-4, 0, 0)
	rival.motion_speed = 14.0
	audio.update_motors(game, STEP)
	var left := await _sample("rival_left")
	rival.global_position += Vector3(8, 0, 0)
	audio.update_motors(game, STEP)
	var right := await _sample("rival_right")
	check(left.rms > .001 and left.left > left.right * 1.3 and right.right > right.left * 1.3, "Nearby motor crosses the actual stereo field")
	game.opponents[1].global_position = game.player.global_position + Vector3(-1, 0, 0)
	audio.update_motors(game, STEP)
	check(not audio.rival_motors[0].body.playing and audio.rival_motors[1].body.playing, "Low budget gives the closest rival the available voice")
	for kart in game.opponents:
		kart.global_position += Vector3(0, 0, 150)
	audio.update_motors(game, STEP)
	check((await _sample("rivals_distant")).peak < .0001, "Distant rivals leave the mix")
	_tap(player, true)
	audio.set_volumes(1.0, 0.0)
	check((await _sample("effects_off")).peak < .0001, "Effects slider silences every motor")
	audio.set_volumes(1.0, 1.0)
	for pause in [true, false]:
		audio.set_paused(pause)
		audio.update_motors(game, STEP)
		var level := await _sample("paused" if pause else "resumed")
		check(level.peak < .0001 if pause else level.rms > .001, "Pause/resume reaches mixer")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = roundi(AudioServer.get_mix_rate())
	wav.data = recording
	wav.save_to_wav("user://kart_motor_capture.wav")
	print("[KartMotorAudio] ", JSON.stringify(measurements))
	print("[KartMotorAudio] ", "PASS" if failures.is_empty() else str(failures), " ", ProjectSettings.globalize_path("user://kart_motor_capture.wav"))
	game.abandoned = true
	game.queue_free()
	await process_frame
	await create_timer(.12).timeout
	AudioServer.remove_bus(bus)
	quit(0 if failures.is_empty() else 1)
