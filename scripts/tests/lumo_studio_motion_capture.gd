extends SceneTree
## Real Godot-rendered baseline/new motion comparison on the original mesh.
## This is a pose studio; jump_nextgen_capture.gd separately proves gameplay.
const ACTOR = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const CURRENT_POSE = preload("res://scripts/characters/lumo/lumo_platform_pose.gd")
const EVIDENCE: String = "res://docs/evidence/studio-character-20261113/"
var output: String
var rows: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("[LumoStudioCapture] " + message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LumoStudioCapture] Native renderer required; refusing headless capture")
		quit(1)
		return
	output = OS.get_environment("LUMO_CAPTURE_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("[LumoStudioCapture] Set a writable LUMO_CAPTURE_DIR")
		quit(1)
		return
	var before_source: String = FileAccess.get_file_as_string(EVIDENCE + "before_platform_pose.gd.txt")
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE + "before_pose_provenance.json"))
	_check(before_source.sha256_text() == str(provenance.sha256), "frozen baseline hash matches recorded Git revision")
	var before_script := GDScript.new()
	before_script.source_code = before_source
	_check(before_script.reload() == OK, "exact baseline pose compiles")
	if not failures.is_empty():
		quit(1)
		return
	root.size = Vector2i(720, 840)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("25394c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8e8ff")
	environment.environment.ambient_light_energy = 0.60
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -35, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	stage.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 135, 0)
	fill.light_energy = 0.35
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.position.y = -0.004
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("344d62")
	material.roughness = 0.86
	ground.material_override = material
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(2.6, 2.0, 4.6), Vector3(0, 0.88, 0))
	var actor = ACTOR.new()
	stage.add_child(actor)
	await process_frame
	_check(actor.is_usable(), "original imported fox is present")
	actor.set_process(false)
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for variant in ["before", "after"]:
		for sample in ["walk", "sprint", "jump_rise", "land"]:
			actor.player.play("idle", 0.0)
			actor.player.seek(0.0, true)
			actor.player.advance(0.0)
			actor.player.pause()
			actor.skeleton.force_update_all_bone_transforms()
			var pose = before_script.new() if variant == "before" else CURRENT_POSE.new()
			_check(pose.bind(actor.skeleton), "original skeleton accepts pose owner")
			var speed: float = 5.5 if sample == "sprint" else 1.4
			for _frame in range(30):
				pose.advance(Vector3(0, 0, speed), true, 1.0 / 60.0)
			if sample == "jump_rise":
				for _frame in range(12):
					pose.advance(Vector3(0, 4.2, 1.4), false, 1.0 / 60.0)
			elif sample == "land":
				for _frame in range(12):
					pose.advance(Vector3(0, -7.5, 0), false, 1.0 / 60.0)
				for _frame in range(6):
					pose.advance(Vector3.ZERO, true, 1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = root.get_texture().get_image()
			var filename: String = variant + "_" + sample + ".png"
			_check(frame != null and frame.get_size() == root.size, "real renderer pixels: " + filename)
			if frame != null:
				_check(frame.save_png(output.path_join(filename)) == OK, "saved: " + filename)
			rows.append({"file": filename, "variant": variant, "sample": sample, "state": pose.state, "stride_phase": pose.phase, "display": DisplayServer.get_name(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
			pose.stop()
	var file := FileAccess.open(output.path_join("studio-motion-capture.json"), FileAccess.WRITE)
	_check(file != null, "capture receipt writable")
	if file != null:
		file.store_string(JSON.stringify({"baseline": provenance, "captures": rows, "failures": failures, "source_fox_unchanged": true, "capture_kind": "native Godot pose studio, separate from gameplay capture", "physical_device_fps_measured": false}, "  "))
		file.close()
	stage.free()
	await process_frame
	print("[LumoStudioCapture] %s %d real renderer frames; frozen baseline and current IK clips" % ["PASS" if failures.is_empty() else "FAIL", rows.size()])
	quit(0 if failures.is_empty() else 1)
