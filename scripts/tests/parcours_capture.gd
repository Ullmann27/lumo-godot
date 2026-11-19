extends SceneTree
## Belegbilder aus einem echt gespielten Parcours-Lauf (Bot fährt mit den echten Eingaben):
## Start, Geschicklichkeitsstellen, Fußabschnitt, Ziel und Ergebnis, dazu Dreiecke und
## Draw-Calls je Bild (Container-Messung, Software-Renderer, kein Handywert).
## xvfb-run … --rendering-method gl_compatibility --resolution 1812x2176 --script
##   res://scripts/tests/parcours_capture.gd -- --world=wolkenwerkstatt --out=/abs/dir

const STEP: float = 1.0 / 60.0
var out_dir: String = ""
var world_id: String = "wolkenwerkstatt"
var shots: Array[String] = []
var game: Node
var frames_since: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _shot(label: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	var info := (
		"%s: %d Dreiecke, %d Draw-Calls, %d Objekte"
		% [
			label,
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			),
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			),
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
			)
		]
	)
	var width: int = 1000
	if image.get_width() > width:
		image.resize(
			width,
			roundi(image.get_height() * float(width) / image.get_width()),
			Image.INTERPOLATE_LANCZOS
		)
	var path: String = out_dir.path_join("%s_%02d_%s.jpg" % [world_id, shots.size(), label])
	image.save_jpg(path, 0.88)
	shots.append(path)
	print("[ParcoursCapture] ", info, " -> ", path)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world="):
			world_id = arg.trim_prefix("--world=")
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var router = root.get_node("SceneRouter")
	router.launch_options = {
		"childKey": "parcours_capture", "parcoursWorld": world_id, "soundEnabled": false
	}
	game = load("res://scenes/games/kart_parcours.tscn").instantiate()
	root.add_child(game)
	for i in range(4):
		await process_frame
	game.set_physics_process(false)
	game.auto_gas = true
	game.countdown = 0.0
	var bot = load("res://scripts/games/parcours/parcours_bot.gd").new(3, 0.3, 0.1)
	for i in range(50):
		game.step_game(STEP, 0.0, 0.0, true, Vector2.ZERO)
		if i % 10 == 0:
			await process_frame
	await _shot("start")
	# Messung nur der Welt (ohne Kart/Lumo), gleiche Kamera.
	game.kart.visible = false
	await process_frame
	await process_frame
	print(
		(
			"[ParcoursCapture] nur Welt: %d Dreiecke, %d Draw-Calls"
			% [
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
				),
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			]
		)
	)
	game.kart.visible = true
	var pending: Array[Dictionary] = []
	var foot_shots: int = 0
	var finish_near: bool = false
	var frames: int = 0
	while not game.finished and frames < 60 * 300:
		var run = game.run
		if run.on_foot:
			var f: Dictionary = bot.foot_input(run)
			if bool(f.jump):
				game.jump_pressed(true)
			if bool(f.lever) or run.can_enter_kart():
				game.context_action()
				if not run.on_foot:
					bot.foot_target = 0
			game.step_game(STEP, 0.0, 0.0, false, f.move)
			if bool(f.jump):
				game.jump_pressed(false)
		else:
			if run.can_leave_kart():
				game.context_action()
			var input: Dictionary = bot.drive_input(run, STEP)
			game.steer = Vector2(float(input.axis), 0.0)
			game.step_game(STEP, float(input.axis), float(input.brake), true, Vector2.ZERO)
		for e in game.event_log:
			if e.has("_seen"):
				continue
			e["_seen"] = true
			match str(e.kind):
				"skill":
					pending.append(
						{
							"label": "stelle_%s" % str(run.course.skills[run.last_skill].id),
							"at": frames + 70
						}
					)
				"leave":
					pending.append({"label": "zu_fuss", "at": frames + 100})
				"lever":
					pending.append({"label": "hebel", "at": frames + 50})
		if (
			not finish_near
			and run.drive.position.distance_to(run.course.finish.pos) < 26.0
			and not run.on_foot
		):
			finish_near = true
			pending.append({"label": "ziel", "at": frames + 1})
		frames += 1
		for p in pending.duplicate():
			if frames >= int(p.at):
				pending.erase(p)
				await _shot(str(p.label))
		if frames % 20 == 0:
			await process_frame
	for i in range(30):
		await process_frame
	await _shot("ergebnis")
	print(
		(
			"[ParcoursCapture] fertig: %d Bilder, Ziel=%s, %.1f s"
			% [shots.size(), game.finished, game.run.elapsed]
		)
	)
	print("[ParcoursCapture] Szene: ", game.builder.stats)
	var done: bool = game.finished
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if done else 1)
