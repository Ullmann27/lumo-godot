extends SceneTree
## Drive each opening from its real grid using keyboard events, including steering
## back onto the high mushroom line and jumping the actual harbour wave.
const ROUTES = preload("res://scripts/games/run/run_courses.gd")
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var shots := OS.get_environment("LUMO_RUN_SHOTS")
var left := false
var right := false


func _initialize() -> void:
	call_deferred("_run")


func _key(code: Key, on: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func steer(offset: float) -> void:
	if left != (offset < -.2):
		left = not left
		_key(KEY_LEFT, left)
	if right != (offset > .2):
		right = not right
		_key(KEY_RIGHT, right)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("[RunRelay] " + label)


func _run() -> void:
	# Headless starts at 64 x 64; lay out the actual race HUD at a usable size.
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
		await process_frame
		await process_frame
	if not shots.is_empty():
		root.msaa_3d = Viewport.MSAA_DISABLED
		RenderingServer.render_loop_enabled = false
	var router := root.get_node("SceneRouter")
	for i in range(3):
		router.launch_options = {"childKey": "relay_%d" % Time.get_ticks_usec(), "grade": 1}
		var game = load(router.SCENES.run).instantiate()
		root.add_child(game)
		game.lightweight = true
		game.set_process(false)
		await game.start_course(i, false)
		var relay = game.relay
		var hits := 0
		var released_at := -1
		var seen: Array[String] = []
		relay.feedback.connect(func(kind: String, words: String):
			if kind != "cue":
				seen.append(kind)
				print("[RunRelay] %s %.1fm %s" % [ROUTES.course(i).id, game.player.s, words]))
		var handled := {}
		var snapped := false
		for tick in range(1000):
			game.advance(STEP)
			if game.phase != game.Phase.RUNNING:
				continue
			if released_at == tick:
				_key(KEY_SPACE, false)
			if relay.cursor >= 3:
				break
			var mark: Dictionary = relay.marks[relay.cursor]
			var lead: float = float(mark.s) - game.player.s
			steer(float(mark.lat) - game.player.lat)
			if not shots.is_empty() and not snapped and ((i == 0 and relay.cursor == 1) or (i != 0 and lead < 12.0)):
				snapped = true
				RenderingServer.render_loop_enabled = true
				for frame in range(3):
					await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(shots.path_join("lauf-%s.png" % ROUTES.course(i).id)) == OK, "viewport capture")
				RenderingServer.render_loop_enabled = false
			if handled.has(relay.cursor):
				continue
			if str(mark.kind) == "dash" and lead <= 2.6:
				_key(KEY_X, true)
				_key(KEY_X, false)
				handled[relay.cursor] = true
			elif (str(mark.kind) == "vault" or (str(mark.kind) == "ring" and
					((i == 0 and relay.cursor == 1) or i == 2))) and lead <= 5.1:
				_key(KEY_SPACE, true)
				released_at = tick + 18
				handled[relay.cursor] = true
		for item in seen:
			if item in ["hit", "triple"]:
				hits += 1
		check(game.actor.uses_original, "visible original rig")
		check(hits == 3 and seen.has("triple"), "all three ordered actions give the boost in %s, events %s" % [ROUTES.course(i).name, seen])
		print("[RunRelay] %s %.2fs, %.2fm, marks=%d, chain=%d" % [ROUTES.course(i).id, game.elapsed, game.player.s, relay.marks.size(), relay.chain])
		steer(0)
		_key(KEY_SPACE, false)
		game.abandoned = true
		game.queue_free()
		await process_frame
		await process_frame
	root.get_node("GameSoundscape").release_audio()
	var deadline := Time.get_ticks_msec() + 850
	while Time.get_ticks_msec() < deadline:
		await process_frame
	print("[RunRelay] ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
