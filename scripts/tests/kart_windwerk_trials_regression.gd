extends SceneTree
## Gleiche Torlinien für Fahrer und KI; danach echte Fahrphysik in der Rennszene.

const TRIALS = preload("res://scripts/games/kart_windwerk_trials.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0

var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		failures += 1


func sweep(model, driver: int, at: float, x: float, seconds: float) -> String:
	model.cross(driver, at - 1, x, seconds - .05, .05, 40.0)
	return model.cross(driver, at + 1, x, seconds + .05, .10, 40.0)


func run() -> void:
	var model := TRIALS.new()
	for driver in [-1, 2]:
		for lap in 2:
			var offset := lap * 3000
			verify(sweep(model, driver, 720 + offset, TRIALS.SAFE, 3) == "safe", "Linke Spur bleibt frei")
			var x := TRIALS.slider_lane(1, 4)
			verify(sweep(model, driver, 810 + offset, x, 4) == "bump", "Bewegliche Platte reagiert auf Überfahrt")
			verify(model.speed_factor(driver, 4.1) < 1 and model.speed_factor(driver, 5) == 1, "Kurzer Kontakt löst sich")
			verify(sweep(model, driver, 910 + offset, TRIALS.LANE, 0.57) == "draft", "Freies Turbofenster")
			for i in TRIALS.GATES.size():
				verify(sweep(model, driver, TRIALS.GATES[i] + offset, TRIALS.TARGETS[i], 5 + i) == ("combo" if i == 2 else "gate"), "Windzeichenfolge")
			verify(sweep(model, driver, 2420 + offset, TRIALS.TARGETS[2], 8).is_empty(), "Kein doppelter Torbonus")
	verify(sweep(model, 7, 2205, 0, 1) == "neutral", "Mitte bleibt ohne Aufgabe befahrbar")
	verify(sweep(model, 8, 2205, 3.8, 1) == "neutral", "Anderes Zeichen nimmt keinen Turbo")
	model.free()
	if "--rules-only" in OS.get_cmdline_user_args():
		finish()
		return
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.lightweight = true
	game._start_selected_race({"mode":"training", "kart":"comet", "driver":"fox", "track":"windwerk_3000", "difficulty":"flott"})
	game._end_preview()
	await physics_frame
	await physics_frame
	game.countdown = 0
	game.racing = true
	game.auto_gas = true
	var trials = game.windwerk_trials
	verify(is_instance_valid(trials) and trials.sliders.size() == 3, "Normaler Rennstart erzeugt drei Schieber")
	if is_instance_valid(trials):
		drive_line(game, TRIALS.SLIDERS[0], TRIALS.SAFE)
		verify(trials.speed_factor(-1, game.elapsed) == 1.0, "Sicherer Weg durch den bewegten Schieber")
		# Beim Überfahren der zweiten Platte liegt diese an ihrem rechten Umkehrpunkt.
		game.elapsed = (PI * .5 + TAU - 2.0) / 1.25 - .45
		drive_line(game, TRIALS.SLIDERS[1], TRIALS.LANE)
		verify(trials.speed_factor(-1, game.elapsed) < 1.0 and game.speed > 10, "Schieberkontakt bei fahrendem Kart")
		for i in TRIALS.GATES.size():
			drive_line(game, TRIALS.GATES[i], TRIALS.TARGETS[i])
			verify(game.boost_time > (1.0 if i == 2 else .1), "Normale Rennphysik fährt Tor %d mit Windschub" % i)
	verify(await TEARDOWN.release_scene(self, game, "[WindwerkTrials]"), "Rennszene schließt")
	finish()


func drive_line(game, at: float, x: float) -> void:
	var d := at - 16.0
	game.distance = d
	game.previous_road_distance = d
	game.player.transform = game.world.reset_transform(d, x)
	game.player_heading = game._heading(d)
	game.speed = 35.0
	game.physical_velocity = -(game.world.frame(d) as Basis).z * game.speed
	game.boost_time = 0.0
	for frame in 100:
		var aim: Vector3 = game.world.position_at(game.previous_road_distance + 9, x) - game.player.position
		game.steering = clampf(-angle_difference(game.player_heading, atan2(-aim.x, -aim.z)) * 2.6, -1, 1)
		game._physics_process(STEP)
		if game.distance > at:
			break


func finish() -> void:
	print("WINDWERK_TRIALS_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
