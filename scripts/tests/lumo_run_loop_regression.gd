extends "res://scripts/tests/lumo_run_regression.gd"
## Fast shared-world integration gate. Reuses the unchanged obstacle/loop
## assertions, then checks both safe entry edges and actual scene continuity.
## Optional GL captures: LUMO_RUN_LOOP_PROOF_DIR=/absolute/output/directory

const SHARED_LOOP = preload("res://scripts/games/kart_physical_loop.gd")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/games/lumo_run.tscn")
	bridge = root.get_node("HostBridge")
	router = root.get_node("SceneRouter")
	_clean()
	await _test_obstacles_and_gaps()
	await _test_branch_adapter()
	_finish_run()


func _test_branch_adapter() -> void:
	var game = await _open(2)
	var player = game.player
	var data: Dictionary = game.plan.loop
	_check(bool(data.get("branch", false)), "Run adopts the exterior shared loop")
	_check(is_equal_approx(float(data.exit_s) - float(data.start), 63.0), "Run returns after the complete 63-metre branch")
	_check(float(data.tolerance) + TUNING.BODY_RADIUS < SHARED_LOOP.half_width_of(data.layout), "whole runner fits inside the entry deck")
	for checkpoint in game.plan.checkpoints:
		_check(float(checkpoint.s) < float(data.start) or float(checkpoint.s) > float(data.exit_s), "no learning stop interrupts the loop branch")
	var captures: Dictionary = {}
	for entry_offset in [0.0, -float(data.tolerance) * 0.9, float(data.tolerance) * 0.9]:
		_teleport(game, float(data.start) - 12.0, float(data.lane) + entry_offset, TUNING.CRUISE)
		game._update_view(STEP, true)
		var previous: Vector3 = game.feet_transform().origin
		var base_y: float = previous.y
		var entered: bool = false
		var exited: bool = false
		var largest_step: float = 0.0
		var highest: float = 0.0
		var widest: float = 0.0
		var behind: int = 0
		var outside: int = 0
		for frame in range(650):
			game.advance(STEP)
			var feet: Transform3D = game.feet_transform()
			largest_step = maxf(largest_step, previous.distance_to(feet.origin))
			highest = maxf(highest, feet.origin.y - base_y)
			previous = feet.origin
			if player.loop_u >= 0.0:
				entered = true
				widest = maxf(widest, absf(player.lat))
				var body: Vector3 = feet.origin + feet.basis.y * TUNING.BODY_CENTRE
				behind += 1 if game.camera.is_position_behind(body) else 0
				outside += 0 if game.camera.is_position_in_frustum(body) else 1
				if is_zero_approx(entry_offset):
					for shot in [["entry", 0.08], ["crest", 0.50], ["return", 0.92]]:
						if player.loop_u >= float(shot[1]) and not captures.has(shot[0]):
							captures[shot[0]] = true
							await _capture_loop(game, str(shot[0]))
			elif entered:
				exited = true
				break
		_check(entered and exited and player.grounded, "entry %.3f completes the full exterior loop" % entry_offset)
		_check(largest_step < 0.8, "entry %.3f has continuous entrance and road return (%.3f m/tick)" % [entry_offset, largest_step])
		_check(highest > 10.0 and widest > 15.0, "entry %.3f follows the high exterior ring" % entry_offset)
		_check(player.s >= float(data.exit_s) and player.s < float(data.exit_s) + 0.8, "entry %.3f hands over at the actual exit" % entry_offset)
		_check(absf(player.lat - float(data.exit_lane)) < 0.01, "entry %.3f returns to the actual road lane" % entry_offset)
		_check(behind == 0 and outside == 0, "entry %.3f stays in the real gameplay camera (behind=%d outside=%d)" % [entry_offset, behind, outside])
		print("[RunLoopAdapter] offset=%.3f max_step=%.3f height=%.3f outer_lane=%.3f behind=%d outside=%d" % [entry_offset, largest_step, highest, widest, behind, outside])
	await _free_game(game)


func _capture_loop(game, label: String) -> void:
	var output: String = OS.get_environment("LUMO_RUN_LOOP_PROOF_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output.path_join("lumo-run-loop-" + label + ".png")
	var result: Error = game.get_viewport().get_texture().get_image().save_png(path)
	_check(result == OK, "actual loop screenshot saved: " + label)
	print("[RunLoopAdapter] capture=" + path)
