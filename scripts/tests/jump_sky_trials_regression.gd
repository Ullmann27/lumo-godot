extends SceneTree
## Keyboard events travel through the viewport into the production controller.
var failures: Array[String] = []
var capture_dir := OS.get_environment("LUMO_JUMP_SHOTS")


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr(label)


func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, label)


func _run() -> void:
	# Sample only requested frames on software-rendered CI. Physics and input
	# continue to tick normally between snapshots.
	if not capture_dir.is_empty():
		root.msaa_3d = Viewport.MSAA_DISABLED
		LumoQuality.set_tier("low")
		RenderingServer.render_loop_enabled = false
	for course in range(3):
		root.get_node("SceneRouter").launch_options = {
			"jumpCourse": course, "childKey": "trials_%d" % Time.get_ticks_usec()
		}
		var scene := load("res://scenes/games/jump_islands.tscn") as PackedScene
		var game = scene.instantiate()
		root.add_child(game)
		for i in range(12):
			await physics_frame
		await capture("course_%d_start" % course)
		key(KEY_UP, true)
		var jumped := false
		var lift := 0.0
		var speed := 0.0
		var boost := false
		var takeoff := [-1.3, -1.3, .95]
		for i in range(70):
			if not jumped and game.actor.position.z < takeoff[course]:
				key(KEY_SPACE, true)
				jumped = true
			await physics_frame
			lift = maxf(lift, game.actor.velocity.y)
			speed = maxf(speed, -game.actor.velocity.z)
			boost = boost or game.trials.boost > 0
			if game.trials.stamps.size() > 0:
				await capture("course_%d_contact" % course)
				break
		key(KEY_UP, false)
		key(KEY_SPACE, false)
		check(game.trials.stamps.size() == 1, "Course %d first challenge reached by keyboard" % course)
		check(lift > (10.0 if course == 1 else 7.5), "Course %d physical takeoff" % course)
		check(boost == (course != 2), "Course %d appropriate effect" % course)
		check(speed > 7.5, "Course %d reaches full sprint" % course)
		print("[SkyTrials] course %d peak launch %.2f speed %.2f marks %s" % [course, lift, speed, game.trials.stamps])
		var saved: Dictionary = game.trials.stamps.duplicate()
		var path: String = game.session_path
		game.abandoned = true
		game.queue_free()
		await process_frame
		game = scene.instantiate()
		root.add_child(game)
		await physics_frame
		check(game.paused and game.trials.stamps == saved, "Course %d marks restored" % course)
		game.abandoned = true
		game.queue_free()
		await process_frame
		DirAccess.remove_absolute(path)
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		await process_frame
	if failures.is_empty():
		print("[SkyTrials] PASS three distinct first challenges via native keys, full sprint and save/resume")
	quit(0 if failures.is_empty() else 1)
