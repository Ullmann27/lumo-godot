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


func _touch(control: Control, down: bool, finger: int = 4) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = finger
	touch.position = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	touch.pressed = down
	Input.parse_input_event(touch)
	Input.flush_buffered_events()


func _steer(value: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		game.hud.joystick.axis_changed.emit(value)
		return
	var stick: Control = game.hud.joystick
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	var at := stick.get_global_rect().get_center() + value * stick.size.x * 0.31
	drag.position = at * Vector2(root.size) / root.get_visible_rect().size
	Input.parse_input_event(drag)
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
	var rival_passes := 0
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
			_touch(game.hud.joystick, true, 2)
			_touch(game.hud.gas_button, true)
			check(game.hud.joystick.touch_id == 2, id + " steering finger captured")
		check(game.gas_held, id + " gas")
		var bot = PILOT.new(3, 0.30, 0.10)
		var places := {}
		var rival_ahead := -1
		var fork_slabs := {}
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
				_steer(Vector2(local.x, local.z))
				game._physics_process(STEP)
				if action.jump:
					game.jump_pressed(false)
			else:
				if run.can_leave_kart():
					game.context_action()
				var input: Dictionary = bot.drive_input(run, STEP)
				_steer(Vector2(float(input.axis), 0))
				game.brake_held = float(input.brake)
				# Give both competitors time to cross. The player still drives the entire route.
				var waiting_at_finish: bool = (
					run.checkpoint == run.course.checkpoints.size() - 1
					and run.drive.position.distance_to(run.course.finish.pos) < 30.0
					and (not game.race.racers[0].run.finished or not game.race.racers[1].run.finished)
				)
				if (frame > 80 and frame < 1180) or waiting_at_finish:
					game.brake_held = 1.0
				game._physics_process(STEP)
			places[game.race.place] = true
			var nova: Dictionary = game.race.racers[0]
			var milo: Dictionary = game.race.racers[1]
			var slab := int(nova.run.drive.hit.get("slab", -1))
			if slab >= 0 and bool(game.course.slabs[slab].get("race_fork", false)):
				fork_slabs[slab] = true
			var lead := float(nova.rank_m) - float(milo.rank_m)
			if frame > 12 and absf(lead) > 1.5 and not nova.run.finished and not milo.run.finished:
				var ahead := 0 if lead > 0.0 else 1
				if rival_ahead >= 0 and rival_ahead != ahead:
					rival_passes += 1
				rival_ahead = ahead
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
			summary.append([racer.kart.name, racer.run.finished, racer.run.checkpoint, racer.run.reached.size(), snappedf(racer.run.elapsed, 0.1), racer.run.resets, racer.pilot.target, racer.run.on_foot, racer.run.drive.position.snapped(Vector3.ONE)])
			check(racer.run.finished and racer.run.finish_order_ok, id + " AI " + str(racer.kart.name))
		check(game.finished and game.run.finish_order_ok, id + " player")
		check(saved_rivals, id + " rivals persisted")
		check(fork_slabs.size() >= 4, id + " AI drove physical branch")
		check(game.result_payload.get("place", 0) == 3 and int(game.result_payload.get("racers", 0)) == 3, id + " classification")
		print("[ParcoursRace] ", id, " ranks=", places.keys(), " alternative slabs=", fork_slabs.size(), " rival passes=", rival_passes, " player=", game.run.elapsed, " AIs=", summary)
		await capture(id + "-ziel")
		if DisplayServer.get_name() != "headless":
			_touch(game.hud.gas_button, false)
			_touch(game.hud.joystick, false, 2)
		game.show_world_choice()
		await process_frame
	if OS.get_environment("LUMO_PARCOURS_WORLD").is_empty():
		check(rival_passes > 0, "rivals overtook one another")
	check(await TEARDOWN.release_scene(self, game, "[ParcoursRace]"), "release scene and mixer")
	root.get_node("GameSoundscape").release_audio()
	var until := Time.get_ticks_msec() + 650
	while Time.get_ticks_msec() < until:
		await process_frame
	print("[ParcoursRace] ", "PASS" if failures.is_empty() else failures)
	quit(failures.size())
