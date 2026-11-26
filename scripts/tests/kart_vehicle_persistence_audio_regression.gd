extends SceneTree
## Actual garage/race scene, durable workshop, profile separation and audible
## motor state through the real race audio path. No user data is touched.
const TUNING = preload("res://scripts/games/kart_tuning.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const GLOBAL_TEARDOWN = preload("res://scripts/tests/lumo_scene_teardown.gd")
const SCENE = "res://scenes/games/kart_island.tscn"
const CHILD_A := "regression-kart-a"
const CHILD_B := "regression-kart-b"
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var checks := 0
var game


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		printerr("[KartContinuity] FAIL: " + description)


func _open(child: String) -> void:
	root.get_node("HostBridge")._options = {"childKey": child, "soundEnabled": true}
	game = load(SCENE).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for i in 8:
		await process_frame


func _close() -> void:
	game.abandoned = true
	_check(await TEARDOWN.release_scene(self, game, "[KartContinuity]"), "scene and audio released")
	game = null
	for i in 8:
		await process_frame


func _run() -> void:
	var bridge := root.get_node("HostBridge")
	var prior: Dictionary = bridge._options.duplicate(true)
	for child in [CHILD_A, CHILD_B]:
		DirAccess.remove_absolute(TUNING.path_for(child))
	# A legacy workshop without selection metadata is not a lost vehicle.
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 1)
	legacy.set_value("meta", "lifetime", 200)
	legacy.set_value("kart_gecko_velo", "paint", "feuer")
	legacy.set_value("owned", "items", ["paint:feuer"])
	_check(legacy.save(TUNING.path_for(CHILD_A)) == OK, "legacy fixture saved")
	await _open(CHILD_A)
	_check(game.garage.setup.kart == "gecko_velo", "single legacy customized chassis restored")
	var shop = game.workshop
	_check(shop.chosen("gecko_velo", "paint") == "feuer", "legacy paint preserved")
	_check(shop.unlock_parts({"engine": "sprint", "exhaust": "doppel"}), "parts purchased")
	_check(shop.mount_parts("gecko_velo", {"engine": "sprint", "exhaust": "doppel"}), "parts mounted")
	_check(shop.upgrade("gecko_velo", "motor"), "motor upgrade saved")
	_check(shop.buy_and_choose("gecko_velo", "paint", "minze"), "purchase and installation saved together")
	game.garage.step = 2
	game.garage._select("kart", "comet")
	game.garage._select("kart", "gecko_velo")
	_check(shop.saved_kart == "gecko_velo", "actual selection committed before leaving")
	var balance: int = shop.available()
	await _close()
	await _open(CHILD_A)
	_check(game.garage.setup.kart == "gecko_velo", "reopened garage selects last chassis")
	_check(game.workshop.chosen("gecko_velo", "paint") == "minze", "chosen paint survives scene recreation")
	_check(game.workshop.chosen("gecko_velo", "engine") == "sprint", "mounted engine survives scene recreation")
	_check(game.workshop.chosen("gecko_velo", "exhaust") == "doppel", "mounted exhaust survives scene recreation")
	_check(game.workshop.level("gecko_velo", "motor") == 1 and game.workshop.available() == balance, "level and budget retained")
	game.graphics_profile = "low"
	game.lightweight = true
	game._start_selected_race({"mode": "training", "track": "sonnenhafen", "kart": "gecko_velo", "driver": "fox", "difficulty": "flott"})
	_check(is_instance_valid(game.player) and game.player.kart_style == "gecko_velo", "real race uses saved kart")
	_check(game.player.look.get("engine") == "sprint" and game.player.look.get("exhaust") == "doppel", "real race uses saved motor and exhaust")
	game._end_preview()
	game.racing = true
	game.countdown = 0
	game.paused = false
	game.auto_gas = true
	var audio = game.kart_audio
	audio.set_muted(false)
	audio.set_paused(false)
	audio.set_volumes(0.0, 1.0)
	var voice = audio.player_motor
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "KartContinuityCapture")
	AudioServer.add_bus_effect(bus, capture)
	capture.buffer_length = 0.5
	voice.body.bus = "KartContinuityCapture"
	voice.induction.bus = "KartContinuityCapture"
	var thresholds: Array[float] = [0.26, 0.50, 0.76]
	for i in thresholds.size():
		var threshold: float = thresholds[i] * 43.0 / voice.gear_ratio
		game.speed = threshold - 0.4
		for tick in 60:
			audio.update_motors(game, STEP)
		var before: float = voice.body.pitch_scale
		var shifts_before: int = voice.shifts
		game.speed = threshold + 0.4
		var lowest := before
		for tick in 8:
			audio.update_motors(game, STEP)
			lowest = minf(lowest, float(voice.body.pitch_scale))
		_check(voice.shifts == shifts_before + 1 and voice.gear == i + 1, "real motor enters gear %d" % (i + 2))
		_check(lowest < before * 0.90, "upshift drops actual playback pitch at least 10 percent")
		game._update_hud()
		_check(game.hud.get_parent().get_node("KartRaceBar").values.get("gear") == "G%d" % (i + 2), "HUD follows actual audible gear")
		for tick in 60:
			audio.update_motors(game, STEP)
	_check(voice.body.playing, "real race motor player active")
	capture.clear_buffer()
	var deadline := Time.get_ticks_msec() + 2500
	while capture.get_frames_available() < 2048 and Time.get_ticks_msec() < deadline:
		audio.update_motors(game, STEP)
		await process_frame
	var frames := capture.get_buffer(mini(2048, capture.get_frames_available()))
	var energy := 0.0
	for sample in frames:
		energy += sample.length_squared()
	_check(frames.size() >= 2048 and energy / maxf(1.0, float(frames.size()) * 2.0) > 0.000001, "actual mixer receives non-silent motor PCM")
	audio.set_volumes(0.0, 0.0)
	_check(not voice.body.playing and not voice.induction.playing, "effects mute respected")
	voice.body.bus = "Master"
	voice.induction.bus = "Master"
	AudioServer.remove_bus(bus)
	game._leave_race_for_menu()
	_check(game.garage.setup.kart == "gecko_velo" and game.workshop.chosen("gecko_velo", "engine") == "sprint", "return to garage retains configuration")
	await _close()
	await _open(CHILD_B)
	_check(game.garage.setup.kart == "comet" and game.workshop.chosen("gecko_velo", "engine") == "serie", "other profile receives no parts or selection")
	await _close()
	# A structurally readable but incompatible save must not be replaced.
	# This tests the rejection path without intentionally issuing a parser error
	# that the strict CI engine-error monitor would treat as a crash.
	var damaged := ConfigFile.new()
	damaged.set_value("meta", "version", 999)
	damaged.set_value("kart_comet", "paint", "feuer")
	_check(damaged.save(TUNING.path_for(CHILD_B)) == OK, "incompatible fixture saved")
	var raw := FileAccess.get_file_as_string(TUNING.path_for(CHILD_B))
	var blocked = TUNING.new(CHILD_B, 200)
	_check(not blocked.remember_vehicle("gecko_velo", "fox"), "unreadable save rejects replacement")
	_check(not blocked.buy_and_choose("comet", "paint", "minze"), "failed purchase not acknowledged")
	_check(FileAccess.get_file_as_string(TUNING.path_for(CHILD_B)) == raw, "damaged bytes remain untouched")
	for child in [CHILD_A, CHILD_B]:
		DirAccess.remove_absolute(TUNING.path_for(child))
	bridge._options = prior
	_check(await GLOBAL_TEARDOWN.release(self, "[KartContinuity]"), "global audio released")
	print("[KartContinuity] %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
