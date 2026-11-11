extends SceneTree
## Matched real-render fixture, usable unchanged against the original adapter.
## It supplies explicit vehicle states to the production kart/model. It is not
## a claim of a completed race or measured GPU performance.
const VEHICLE = preload("res://scripts/games/kart_vehicle.gd")
const STAGE = preload("res://scripts/games/kart_stage.gd")
const STEP := 1.0 / 30.0
const FRAME_COUNT := 114
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LumoAttentionCapture] A real renderer is required")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://exports/lumo-attention"
	var source_commit := args[1] if args.size() > 1 else "unrecorded"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1000, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var stage := Node3D.new()
	root.add_child(stage)
	var built: Dictionary = STAGE.build(stage)
	for child in stage.get_children():
		if child is WorldEnvironment:
			child.environment.background_mode = Environment.BG_COLOR
			child.environment.background_color = Color("101b30")
	var camera: Camera3D = built.camera
	# PerformanceManager adjusts the first WorldEnvironment after startup.
	# This isolated comparison needs identical lighting on both source trees;
	# use a camera-owned copy that the global profile cannot mutate later.
	for child in stage.get_children():
		if child is WorldEnvironment:
			camera.environment = child.environment.duplicate(true)
	camera.fov = 37
	camera.look_at_from_position(Vector3(0.85, 1.90, -3.75), Vector3(0, 1.0, -0.10))
	camera.current = true
	var kart = VEHICLE.new()
	kart.configure("fox", Color("357cba"), "comet")
	stage.add_child(kart)
	kart.set_process(false)
	kart.set_animated_lumo_enabled(true)
	kart.set_graphics_quality("medium")
	kart.set_motion(0.0, 0.0, false, false)
	kart.set_driver_runtime_state(false, false, false)
	var adapter = kart.lumo_animation
	if not is_instance_valid(adapter) or not adapter.actor.is_usable():
		push_error("[LumoAttentionCapture] Original rig unavailable")
		stage.free()
		quit(1)
		return
	var attention_supported: bool = adapter.has_method("set_attention_target")
	print("[LumoAttentionCapture] original vehicle ready, attention=", attention_supported)
	var snapshots := {12: "rest", 30: "gaze-left", 45: "gaze-right", 59: "forward",
		63: "airborne", 66: "landing", 73: "settled", 84: "selection-nod", 112: "restored"}
	for frame in range(FRAME_COUNT):
		if frame == 18 and attention_supported:
			adapter.set_attention_target(adapter.actor.to_global(Vector3(-4, 1.5, 4)))
		if frame == 33 and attention_supported:
			adapter.set_attention_target(adapter.actor.to_global(Vector3(4, 1.5, 4)))
		if frame == 48 and attention_supported:
			adapter.clear_attention_target()
		if frame == 60:
			kart.set_driver_runtime_state(true, false, false)
		if frame == 65:
			kart.set_driver_runtime_state(false, false, false)
		if frame == 75:
			adapter.play_menu_behavior("agree_nod")
		kart._process(STEP)
		kart._process(STEP)
		if frame == 0:
			print("[LumoAttentionCapture] first pose ready")
		# A timed-out capture may resume deterministically from the start of
		# the pose timeline, preserving already written matching frames.
		if args.has("--resume") and FileAccess.file_exists(output.path_join("frame-%04d.png" % frame)):
			continue
		await process_frame
		if frame == 0:
			print("[LumoAttentionCapture] first process frame ready")
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		if rendered.save_png(output.path_join("frame-%04d.png" % frame)) != OK:
			failures += 1
		if snapshots.has(frame):
			if rendered.save_png(output.path_join(str(snapshots[frame]) + ".png")) != OK:
				failures += 1
	var report := {
		"source_commit": source_commit, "capture_script": "lumo_attention_capture.gd",
		"capture_kind": "production vehicle and original model, explicit state fixture",
		"frame_count": FRAME_COUNT, "playback_frame_rate": 15, "duration_seconds": 7.6,
		"resolution": [1000, 800], "quality": "medium", "camera_position": [0.85, 1.90, -3.75],
		"camera_target": [0, 1.0, -0.10], "camera_fov": 37,
		"lighting": "original kart_stage lights and camera-owned environment copy",
		"attention_supported": attention_supported,
		"model_sha256": FileAccess.get_sha256(adapter.actor.MODEL),
		"godot": Engine.get_version_info().string, "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "failures": failures,
		"android_test": false, "fps_measured": false,
		"timeline": ["rest", "left attention", "right attention", "forward",
			"airborne vehicle sample", "grounded vehicle sample", "settle", "selection nod", "restored"]
	}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	stage.free()
	await process_frame
	await process_frame
	print("[LumoAttentionCapture] ", JSON.stringify(report))
	quit(0 if failures == 0 else 1)
