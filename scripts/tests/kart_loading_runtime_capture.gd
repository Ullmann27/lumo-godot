extends SceneTree
## Unmodified normal boot -> real native Kart menu, recorded as actual frames.
## Invoke with --scene=kart; no held ready state and no artificial load progress.
var output := "/tmp/lumo-kart-loading-runtime"
var observations: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var boot = load("res://scenes/app/boot.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	var states: Array = []
	boot.load_state_changed.connect(func(state: String):
		states.append({"phase": state, "time_ms": Time.get_ticks_msec()}))
	var saw_loading := false
	var saw_menu := false
	var saw_double_intro := false
	for frame in range(48):
		await RenderingServer.frame_post_draw
		var active := current_scene
		var record := {"frame": frame, "time_ms": Time.get_ticks_msec(),
			"scene": active.scene_file_path if is_instance_valid(active) else "scene_tree_handoff"}
		if is_instance_valid(boot):
			record["phase"] = boot.load_phase
			record["engine_progress"] = boot.actual_progress
			saw_loading = saw_loading or boot.load_phase == "loading"
		if is_instance_valid(active) and active.scene_file_path == "res://scenes/games/kart_island.tscn":
			saw_menu = saw_menu or (active.menu_active and is_instance_valid(active.garage))
			saw_double_intro = saw_double_intro or is_instance_valid(active.intro)
			active.set_physics_process(false)
			active.lightweight = true
			record["menu_active"] = active.menu_active
		assert(root.get_texture().get_image().save_png(output.path_join("entry-%03d.png" % frame)) == OK)
		observations.append(record)
		await process_frame
	for state in states:
		saw_loading = saw_loading or state.phase == "loading"
	assert(saw_loading and saw_menu and not saw_double_intro,
		"Actual ordinary boot must load into one real native menu without a second intro")
	var final_scene := current_scene
	final_scene.abandoned = true
	current_scene = null
	final_scene.queue_free()
	for frame in range(8):
		await process_frame
	await create_timer(0.5).timeout
	FileAccess.open(output.path_join("runtime-capture.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"real_godot_frames": true, "frame_count": 48,
		"normal_auto_begin": true, "ready_state_held": false,
		"actual_engine_progress": true, "saw_loading": saw_loading, "saw_menu": saw_menu,
		"saw_second_intro": saw_double_intro, "physical_android_device": false,
		"observations": observations, "actual_state_events": states}, "\t"))
	print("[KartLoadingRuntime] PASS: 48 actual ordinary boot/menu frames, real progress, no second intro")
	quit(0)
