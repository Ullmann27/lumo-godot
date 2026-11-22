extends SceneTree
## Weltwahl → Rennen zu dritt → echte Kart- und Fußsteuerung → gemeinsames Ziel.
const PILOT = preload("res://scripts/games/parcours/parcours_bot.gd")
const WORLDS = preload("res://scripts/games/parcours/parcours_worlds.gd")
const TEARDOWN = preload("res://scripts/tests/helpers/kart_scene_teardown.gd")
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var shots := OS.get_environment("LUMO_PARCOURS_SHOTS")
var game


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	if not condition:
		printerr("[ParcoursRace] FAIL ", label)
		failures.append(label)


func capture(label: String) -> void:
	if shots.is_empty():
		return
	RenderingServer.render_loop_enabled = true
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(shots.path_join(label + ".png")) == OK, label)
	RenderingServer.render_loop_enabled = false


func _touch(control: Control, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 4
	touch.position = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	touch.pressed = down
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


func _run() -> void:
	var size := root.size
	if not shots.is_empty():
		RenderingServer.render_loop_enabled = false
		root.msaa_3d = Viewport.MSAA_DISABLED
	root.get_node("SceneRouter").launch_options = {"childKey": "parcours-race-%d" % Time.get_ticks_usec()}
	game = load("res://scenes/games/kart_parcours.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	root.size = size
	await process_frame
	for id in WORLDS.playable_ids():
		var filter := OS.get_environment("LUMO_PARCOURS_WORLD")
		if not filter.is_empty() and filter != id:
			continue
		game.hud.choice.find_child("Style_rennen", true, false).pressed.emit()
		game.hud.choice.find_child("World_" + id, true, false).pressed.emit()
		await process_frame
		check(game.play_style == "rennen" and game.race.racers.size() == 2, id + " grid")
		game.auto_gas = false
		while game.countdown > 0.0:
			game._physics_process(STEP)
		if DisplayServer.get_name() == "headless":
			game.hud.gas_button.button_down.emit()
		else:
			_touch(game.hud.gas_button, true)
		check(game.gas_held, id + " gas")
		var bot = PILOT.new(3, 0.30, 0.10)
		var places := {}
		var saved_rivals := false
		for frame in range(24000):
			var run = game.run
			if run.on_foot:
				var action: Dictionary = bot.foot_input(run)
				if action.jump:
					game.jump_pressed(true)
				if action.lever or run.can_enter_kart():
					game.context_action()
					if not run.on_foot:
						bot.foot_target = 0
						if not game.gas_held:
							game.hud.gas_button.button_down.emit()
				var move: Vector2 = action.move
				var local: Vector3 = Basis(Vector3.UP, game.camera_yaw).inverse() * Vector3(move.x, 0.0, move.y)
				game.hud.joystick.axis_changed.emit(Vector2(local.x, local.z))
				game._physics_process(STEP)
				if action.jump:
					game.jump_pressed(false)
			else:
				if run.can_leave_kart():
					game.context_action()
				var input: Dictionary = bot.drive_input(run, STEP)
				game.hud.joystick.axis_changed.emit(Vector2(float(input.axis), 0))
				game.brake_held = float(input.brake)
				# Give both competitors time to cross. The player still drives the entire route.
				if frame > 80 and frame < 1180:
					game.brake_held = 1.0
				game._physics_process(STEP)
			places[game.race.place] = true
			if frame == 65:
				await capture(id + "-rennstart")
			if frame == 1500:
				game.pause_game()
				var saved: Dictionary = game.progress.load_session()
				saved_rivals = saved.get("rivals", []).size() == 2
				var clock: float = game.race.racers[0].run.t
				game._physics_process(STEP)
				check(is_equal_approx(clock, game.race.racers[0].run.t), id + " pause")
				game.resume_game()
			if frame % 600 == 0:
				await process_frame
			if game.finished:
				break
		var summary := []
		for racer in game.race.racers:
			summary.append([racer.kart.name, racer.run.finished, racer.run.checkpoint, racer.run.reached.size(), snappedf(racer.run.elapsed, 0.1), racer.run.resets, racer.pilot.target, racer.run.drive.position.snapped(Vector3.ONE)])
			check(racer.run.finished and racer.run.finish_order_ok, id + " AI " + str(racer.kart.name))
		check(game.finished and game.run.finish_order_ok, id + " player")
		check(saved_rivals, id + " rivals persisted")
		check(game.result_payload.get("place", 0) == 3 and int(game.result_payload.get("racers", 0)) == 3, id + " classification")
		print("[ParcoursRace] ", id, " ranks=", places.keys(), " player=", game.run.elapsed, " AIs=", summary)
		await capture(id + "-ziel")
		if DisplayServer.get_name() != "headless":
			_touch(game.hud.gas_button, false)
		game.show_world_choice()
		await process_frame
	check(await TEARDOWN.release_scene(self, game, "[ParcoursRace]"), "release scene and mixer")
	root.get_node("GameSoundscape").release_audio()
	var until := Time.get_ticks_msec() + 650
	while Time.get_ticks_msec() < until:
		await process_frame
	print("[ParcoursRace] ", "PASS" if failures.is_empty() else failures)
	quit(failures.size())
