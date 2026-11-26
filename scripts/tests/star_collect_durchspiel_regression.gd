extends SceneTree
## Durchspiel Sternenjagd (Team B3b): Pause per Knopf, Zurück-Geste und App im
## Hintergrund hält Uhr, Sterne, Sternschnuppe und Wellenwechsel an; Weiter,
## Neu starten, ganze Jagd per Tipp bis zum Ergebnis, Bestzeit je Kind nach
## dem erneuten Öffnen, keine Lern-Sterne an die App (so gewollt).
## Bilder: -- --capture=/absoluter/ordner (2176x1812, 1080x2340).

const SCENE := "res://scenes/games/star_collect.tscn"
const SIZES: Array[Vector2i] = [Vector2i(2176, 1812), Vector2i(1080, 2340)]
const CHILD := "sternenjagd-durchspiel"

var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var shots: Array[String] = []
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[StarDurchspiel] " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _tap(view_point: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform() * view_point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await _frames(1)


func _press(button: Button) -> void:
	_check(
		button != null and button.is_visible_in_tree() and not button.disabled, "Knopf bedienbar"
	)
	if button == null:
		return
	await _tap(button.get_global_transform_with_canvas() * (button.size * 0.5))
	await _frames(2)


func _shot(label: String) -> void:
	if capture_dir.is_empty():
		return
	var back := root.size
	for size: Vector2i in SIZES:
		root.size = size
		await _frames(8)
		await RenderingServer.frame_post_draw
		var path := capture_dir.path_join("%s_%dx%d.jpg" % [label, size.x, size.y])
		_check(root.get_texture().get_image().save_jpg(path, 0.86) == OK, "Bild " + path)
		shots.append(path)
	root.size = back
	await _frames(4)


func _open() -> void:
	game = load(SCENE).instantiate()
	root.add_child(game)
	await _frames(8)


func _catch_wave() -> void:
	var guard := 0
	while not game.stars.is_empty() and guard < 30:
		guard += 1
		var star: Node3D = game.stars[0]
		await _tap(game.camera.unproject_position(star.global_position))
		await _frames(2)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_dir = argument.trim_prefix("--capture=")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var bridge: Node = root.get_node("HostBridge")
	var rewards: Array[Dictionary] = []
	bridge.reward_reported.connect(func(payload: Dictionary) -> void: rewards.append(payload))
	root.get_node("SceneRouter").launch_options = {"childKey": CHILD}
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lumo_sternenjagd.cfg"))
	root.size = Vector2i(720, 600) if not capture_dir.is_empty() else SIZES[1]
	await _open()
	_check(game.pause_button.visible and not game.paused, "Pause-Knopf sichtbar")
	# Pause per Knopf: Uhr und Sterne stehen still, Tippen fängt nichts.
	await _frames(20)
	await _press(game.pause_button)
	_check(game.paused and game.pause_panel.visible, "Pause öffnet das Pausenfeld")
	var held_time: float = game.elapsed
	var star: Node3D = game.stars[0]
	var held_position: Vector3 = star.position
	await _frames(40)
	_check(is_equal_approx(game.elapsed, held_time), "Pause: Uhr steht")
	_check(star.position.is_equal_approx(held_position), "Pause: Sterne stehen")
	await _tap(game.camera.unproject_position(star.global_position))
	_check(game.caught_total == 0, "Pause: Tippen fängt keinen Stern")
	await _shot("sternenjagd_pause")
	await _press(game.pause_panel.find_child("ResumeButton", true, false))
	_check(not game.paused and not game.pause_panel.visible, "Weiter setzt fort")
	await _frames(10)
	_check(game.elapsed > held_time, "Uhr läuft wieder")
	# Zwischen den Wellen: App im Hintergrund hält den Wellenwechsel an.
	await _catch_wave()
	_check(game.wave == 0 and game._next_wave_in > 0.0, "Welle 1 geschafft, Wechsel läuft")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.paused, "App im Hintergrund pausiert")
	var countdown: float = game._next_wave_in
	await _frames(240)
	_check(
		game.wave == 0 and is_equal_approx(game._next_wave_in, countdown),
		"Pause hält den Wellenwechsel"
	)
	game.set_paused(false)
	var guard := 0
	while game.wave == 0 and guard < 600:
		guard += 1
		await process_frame
	_check(game.wave == 1 and game.stars.size() == 7, "Welle 2 kommt nach dem Fortsetzen")
	# Zurück-Geste: erst Pause, dann „Neu starten“.
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(game.paused and game.is_inside_tree(), "Zurück-Geste pausiert zuerst")
	await _press(game.pause_panel.find_child("RestartButton", true, false))
	_check(
		not game.paused and game.wave == 0 and game.caught_total == 0,
		"Neu starten beginnt bei Welle 1"
	)
	# Ganze Jagd mit Sternschnuppe.
	for wave in 3:
		await _catch_wave()
		if wave < 2:
			guard = 0
			while game.wave == wave and guard < 600:
				guard += 1
				await process_frame
	guard = 0
	while not game.result_panel.visible and guard < 1200:
		guard += 1
		if is_instance_valid(game.shooting_star):
			await _tap(game.camera.unproject_position(game.shooting_star.global_position))
		await process_frame
	_check(game.result_panel.visible and game.caught_total == 21, "Ergebnis nach 21 Sternen")
	_check(not game._can_pause(), "Ergebnis braucht keine Pause")
	game.set_paused(true)
	_check(not game.paused, "Pause im Ergebnis wird ignoriert")
	var best: float = game.best_seconds
	_check(best > 0.0, "Bestzeit gemessen (%.1f s)" % best)
	_check(rewards.is_empty(), "keine Lern-Sterne an die App (so gewollt)")
	await _shot("sternenjagd_ergebnis")
	game.queue_free()
	await _frames(4)
	await _open()
	_check(is_equal_approx(game.best_seconds, best), "Bestzeit nach erneutem Öffnen")
	game.queue_free()
	await _frames(4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lumo_sternenjagd.cfg"))
	print(
		(
			"STAR_DURCHSPIEL_%s checks=%d failures=%d shots=%d"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), shots.size()]
		)
	)
	for failure in failures:
		print("  FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
