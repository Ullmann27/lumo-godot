extends SceneTree
## Prüft die drei Wasserbögen in der Rennszene. Mit --out=<Ordner> entstehen
## zusätzlich Spielbilder beider Runden in der per --resolution gesetzten Fenstergröße.
const EVENTS = preload("res://scripts/games/garden/kart_garden_events.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
var failures: Array[String] = []
var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr(label)


func capture(lap: int) -> void:
	if out.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out)
	check(frame.save_png(out.path_join("garten_%dx%d_runde%d.png" % [
		frame.get_width(), frame.get_height(), lap])) == OK, "Spielbild speichern")


func _run() -> void:
	var requested_size := root.size
	var game = load("res://scenes/games/kart_island.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	root.size = requested_size
	await process_frame
	await process_frame
	game._start_selected_race({"mode": "race", "driver": "fox", "kart": "comet",
		"track": "riesengarten_2400", "difficulty": "flott"})
	game._end_preview()
	game.countdown = 0.0
	game.racing = true
	game.distance = 175.0
	game.previous_road_distance = game.distance
	game.player.transform = game.world.reset_transform(game.distance)
	game.player_heading = game._heading(game.distance)
	game._update_vehicles(1.0 / 60.0)
	game._update_camera(1.0, true)
	game._update_hud()
	var garden = game.world.get_node("RiesengartenEnvironment")
	var sprinklers: Array = garden.parts.sprinklers
	check(sprinklers.size() == 3, "Drei Sprenger im Rennen")
	game._advance_garden_world(5.0)
	check(is_equal_approx(garden.environment.fog_density, EVENTS.MORNING_DENSITY), "Morgendunst")
	for sprinkler in sprinklers:
		check(not sprinkler.arc.visible and not sprinkler.rainbow.visible, "Runde eins bleibt trocken")
	await capture(1)
	game.distance += game.track_length
	game.paused = true
	game._advance_garden_world(2.0)
	check(is_equal_approx(garden.environment.fog_density, EVENTS.MORNING_DENSITY), "Pause friert Ereignis ein")
	game.paused = false
	game._advance_garden_world(1.0)
	check(garden.environment.fog_density < EVENTS.MORNING_DENSITY
		and garden.environment.fog_density > EVENTS.CLEAR_DENSITY, "Sanfter Übergang")
	game._advance_garden_world(4.0)
	game._update_hud()
	for sprinkler in sprinklers:
		check(sprinkler.arc.visible and is_equal_approx(
			sprinkler.arc.material_override.get_shader_parameter("amount"), 1.0), "Wasser fließt")
		check(sprinkler.rainbow.visible == (not garden.low()), "Regenbogen nach Profil")
	check(is_equal_approx(garden.environment.fog_density, EVENTS.CLEAR_DENSITY), "Klare Sicht")
	await capture(2)
	check(await TEARDOWN.release_scene(self, game, "[GardenLap]"), "Rennszene freigegeben")
	print("[GardenLap] ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
